import AVFoundation
import QuartzCore

/// Toca els exemples per l'altaveu i escolta el piano pel micròfon.
/// El so del micròfon s'analitza al moment i es llença: no es grava ni surt de l'aparell.
final class AudioEngine: ObservableObject {
    enum MicState { case unknown, granted, denied }

    @Published private(set) var micState: MicState = .unknown
    /// Volum que arriba al micròfon, de 0 a 1, per al mesurador.
    @Published private(set) var level: Float = 0

    /// S'avisa al fil principal cada vegada que se sent una nota nova.
    var onNote: ((Int) -> Void)?

    private let engine = AVAudioEngine()
    private var sourceNode: AVAudioSourceNode?
    private var outputReady = false
    private var tapInstalled = false
    private var wantsMicrophone = false

    // Veus que sonen (exemples). Les toca el fil d'àudio; cal pany.
    private struct Voice { let tone: PianoTone; let startSample: Int64 }
    private var voices: [Voice] = []
    private var renderSample: Int64 = 0
    private var voiceLock = os_unfair_lock_s()
    private var outputRate = 48_000.0

    // Escolta.
    private let windowSize = 4096
    private let hop = 2048
    private let attackSize = 1024
    private var pending: [Float] = []
    private var tracker = NoteTracker()
    private var listening = false
    /// Mentre l'app toca un exemple no s'escolta, perquè no se senti a si mateixa.
    private var muteUntil: CFTimeInterval = 0

    // MARK: Engegar

    /// Engega el so. Amb `microphone`, a més, demana permís i escolta el piano.
    /// Es pot tornar a cridar per canviar d'una manera de tocar a l'altra.
    func start(microphone: Bool) {
        wantsMicrophone = microphone
        if !outputReady {
            outputReady = true
            setSession(microphone: false)
            attachSource()
            startEngine()
        }

        if microphone, !tapInstalled {
            AVAudioApplication.requestRecordPermission { [weak self] granted in
                DispatchQueue.main.async {
                    guard let self else { return }
                    self.micState = granted ? .granted : .denied
                    if granted, self.wantsMicrophone { self.installTap() }
                }
            }
        } else if !microphone, tapInstalled {
            removeTap()
        }
    }

    private func setSession(microphone: Bool) {
        let session = AVAudioSession.sharedInstance()
        if microphone {
            try? session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
        } else {
            // Sense micròfon: només so, i que soni encara que el telèfon estigui en silenci.
            try? session.setCategory(.playback, mode: .default)
        }
        try? session.setActive(true)
    }

    private func attachSource() {
        let output = engine.outputNode.outputFormat(forBus: 0)
        outputRate = output.sampleRate > 0 ? output.sampleRate : 48_000
        guard let format = AVAudioFormat(standardFormatWithSampleRate: outputRate, channels: 1) else { return }

        let node = AVAudioSourceNode(format: format) { [weak self] _, _, frameCount, bufferList -> OSStatus in
            self?.render(frameCount: Int(frameCount), bufferList: bufferList)
            return noErr
        }
        sourceNode = node
        engine.attach(node)
        engine.connect(node, to: engine.mainMixerNode, format: format)
    }

    private func startEngine() {
        engine.prepare()
        try? engine.start()
    }

    private func installTap() {
        guard !tapInstalled else { return }
        engine.stop()
        setSession(microphone: true)
        let input = engine.inputNode
        let inputFormat = input.outputFormat(forBus: 0)
        if inputFormat.sampleRate > 0, inputFormat.channelCount > 0 {
            let rate = inputFormat.sampleRate
            input.installTap(onBus: 0, bufferSize: AVAudioFrameCount(hop), format: inputFormat) { [weak self] buffer, _ in
                self?.analyse(buffer, sampleRate: rate)
            }
            tapInstalled = true
        }
        startEngine()
    }

    private func removeTap() {
        guard tapInstalled else { return }
        engine.stop()
        engine.inputNode.removeTap(onBus: 0)
        tapInstalled = false
        setListening(false)
        setSession(microphone: false)
        startEngine()
    }

    // MARK: Tocar exemples

    /// Toca una nota ara mateix. `seconds` és el temps que es manté premuda.
    func play(midi: Int, seconds: Double, gain: Float = 0.32) {
        let tone = PianoTone(frequency: Music.frequency(midi), duration: seconds, gain: gain)
        os_unfair_lock_lock(&voiceLock)
        voices.append(Voice(tone: tone, startSample: renderSample))
        os_unfair_lock_unlock(&voiceLock)
        muteUntil = max(muteUntil, CACurrentMediaTime() + tone.totalDuration + 0.35)
    }

    /// Un cop del pols: curt i sec. El primer de cada quatre sona més agut.
    func click(accent: Bool) {
        let tone = PianoTone(frequency: accent ? 1568 : 1046.5, duration: 0.035, gain: accent ? 0.30 : 0.22)
        os_unfair_lock_lock(&voiceLock)
        voices.append(Voice(tone: tone, startSample: renderSample))
        os_unfair_lock_unlock(&voiceLock)
        // Prou per no sentir-se a si mateix, però sense tapar la nota que ve després.
        muteUntil = max(muteUntil, CACurrentMediaTime() + 0.2)
    }

    func stopPlaying() {
        os_unfair_lock_lock(&voiceLock)
        voices.removeAll()
        os_unfair_lock_unlock(&voiceLock)
        muteUntil = CACurrentMediaTime() + 0.25
    }

    private func render(frameCount: Int, bufferList: UnsafeMutablePointer<AudioBufferList>) {
        let buffers = UnsafeMutableAudioBufferListPointer(bufferList)
        guard let first = buffers.first, let raw = first.mData else { return }
        let out = raw.assumingMemoryBound(to: Float.self)

        os_unfair_lock_lock(&voiceLock)
        let base = renderSample
        for frame in 0..<frameCount {
            var value: Float = 0
            for voice in voices {
                value += voice.tone.sample(at: Double(base + Int64(frame) - voice.startSample) / outputRate)
            }
            out[frame] = max(-1, min(1, value))
        }
        renderSample = base + Int64(frameCount)
        let now = renderSample
        voices.removeAll { Double(now - $0.startSample) / outputRate > $0.tone.totalDuration }
        os_unfair_lock_unlock(&voiceLock)

        for buffer in buffers.dropFirst() {
            if let data = buffer.mData { memcpy(data, raw, Int(first.mDataByteSize)) }
        }
    }

    // MARK: Escoltar

    func setListening(_ on: Bool) {
        listening = on
        if !on {
            DispatchQueue.main.async { self.level = 0 }
        }
    }

    private func analyse(_ buffer: AVAudioPCMBuffer, sampleRate: Double) {
        guard let channel = buffer.floatChannelData?[0] else { return }
        let count = Int(buffer.frameLength)

        guard listening, CACurrentMediaTime() > muteUntil else {
            if !pending.isEmpty {
                pending.removeAll(keepingCapacity: true)
                tracker = NoteTracker()
            }
            return
        }

        pending.append(contentsOf: UnsafeBufferPointer(start: channel, count: count))

        var heard: [Int] = []
        var loudest: Float = 0
        var position = 0
        pending.withUnsafeBufferPointer { samples in
            while position + windowSize <= samples.count {
                let window = UnsafeBufferPointer(rebasing: samples[position..<(position + windowSize)])
                let newest = UnsafeBufferPointer(rebasing: window[(windowSize - attackSize)...])
                let level = Pitch.rms(newest)
                loudest = max(loudest, level)
                let frequency = level > tracker.silence ? Pitch.detect(window, sampleRate: sampleRate) : nil
                if let midi = tracker.feed(level: level, frequency: frequency) { heard.append(midi) }
                position += hop
            }
        }
        if position > 0 { pending.removeFirst(position) }
        guard position > 0 else { return }

        let shown = min(1, loudest * 6)
        DispatchQueue.main.async {
            guard self.listening else { return }
            self.level = shown
            for midi in heard { self.onNote?(midi) }
        }
    }
}
