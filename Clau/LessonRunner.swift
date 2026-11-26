import Combine
import Foundation
import QuartzCore
import os

/// Porta l'alumne pas a pas per una lliçó.
@MainActor
final class LessonRunner: ObservableObject {
    enum Mood { case neutral, good, wrong }

    let lesson: Lesson
    let instrument: Instrument
    let steps: [Step]

    @Published private(set) var stepIndex = 0
    @Published private(set) var finished = false

    // Pas d'escoltar.
    @Published private(set) var sounding: Int?
    /// Posició, dins l'exemple, de la nota que sona: per seguir-la a la partitura.
    @Published private(set) var soundingIndex: Int?
    /// La nota de l'altra mà, quan en sonen dues alhora.
    @Published private(set) var soundingAlso: Int?
    @Published private(set) var isPlaying = false
    @Published private(set) var hasListened = false

    // Pas de tocar.
    @Published private(set) var goalIndex = 0
    @Published private(set) var round = 0
    @Published private(set) var stepComplete = false
    @Published private(set) var message = ""
    @Published private(set) var mood: Mood = .neutral

    // Pols: exemples amb cops i passos de tocar a temps.
    enum RhythmPhase { case idle, countIn, playing }
    @Published private(set) var rhythmPhase: RhythmPhase = .idle
    /// Quin cop del compàs sona ara, de l'1 al 4.
    @Published private(set) var count: Int?
    /// Com ha anat cada nota del ritme.
    @Published private(set) var marks: [RhythmJudge.Mark] = []
    /// Tecla que toca ara en un ritme.
    @Published private(set) var rhythmTarget: Int?
    /// Quants cops del ritme o de l'exemple que sona han passat (0 al primer). Serveix per ensenyar per on va el pols.
    @Published private(set) var rhythmBeat: Double?
    /// La tecla de l'altra mà, quan toca tocar-ne dues alhora.
    @Published private(set) var rhythmTargetAlso: Int?
    /// Posició de la nota que toca ara en un ritme.
    @Published private(set) var rhythmIndex: Int?

    /// Hi ha un piano connectat per cable: diu totes les tecles que es toquen, i el micròfon no cal.
    @Published private(set) var cable = false
    /// L'alumne ha acabat de tocar un pas que l'app no pot comprovar i ha de dir com ha anat.
    @Published private(set) var awaitingVerdict = false

    /// Les notes arriben pel micròfon, que només en sent una cada vegada.
    var usesMicrophone: Bool { instrument == .real && !cable }

    /// Un pas amb dues notes que sonen alhora, tocat amb un piano que només se sent pel micròfon: l'app no el pot corregir.
    /// Pot ser que comencin alhora (`also`) o que la nota de sota encara soni quan entra la de dalt (`hold`): el micròfon
    /// només sent una nota i pot sentir la de sota. Marca el pols, l'alumne toca, s'escolta i diu ell si ha sortit bé.
    var selfChecked: Bool {
        guard usesMicrophone, case .rhythm(_, let tones, _, _, _) = step else { return false }
        return tones.contains { $0.also != nil || $0.written > $0.beats + 0.001 }
    }

    /// Al pas de tocar a temps, dues notes comencen alhora (i no només s'aguanta la de sota).
    var startsTogether: Bool {
        guard case .rhythm(_, let tones, _, _, _) = step else { return false }
        return tones.contains { $0.also != nil }
    }

    /// A quina velocitat van el pols i els exemples. Es recorda d'una lliçó a l'altra.
    enum Speed: Double, CaseIterable, Identifiable {
        case slowest = 0.6, slow = 0.8, normal = 1
        var id: Double { rawValue }
        var label: String {
            switch self {
            case .slowest: return "Molt lent"
            case .slow: return "Lent"
            case .normal: return "Normal"
            }
        }
        static let storageKey = "velocitat"
    }

    @Published var speed: Speed = Speed(rawValue: UserDefaults.standard.double(forKey: Speed.storageKey)) ?? .normal {
        didSet { if !ClauApp.isTest { UserDefaults.standard.set(speed.rawValue, forKey: Speed.storageKey) } }
    }

    /// Durada d'un cop, en segons, a la velocitat triada.
    private func beatLength(_ bpm: Double) -> Double { 60 / (bpm * speed.rawValue) }

    private var judge: RhythmJudge?
    private var patternStart: CFTimeInterval = 0
    private var rhythmTask: Task<Void, Never>?
    /// El micròfon triga una mica a reconèixer una nota.
    private let microphoneDelay = 0.12

    /// Vegades que s'ha tocat una tecla de la pantalla. Les proves hi miren que un dit compti una sola vegada.
    @Published private(set) var pressCount = 0
    /// Notes que sonen perquè s'aguanta la tecla.
    private var heldVoices: [Int: Int] = [:]

    private var used: Set<Int> = []
    private var playback: Task<Void, Never>?
    private var advancing: Task<Void, Never>?
    private weak var audio: AudioEngine?
    private weak var midi: MIDIInput?
    private var cableWatch: AnyCancellable?

    init(lesson: Lesson, instrument: Instrument) {
        self.lesson = lesson
        self.instrument = instrument
        steps = lesson.steps(for: instrument)
    }

    var step: Step { steps[min(stepIndex, steps.count - 1)] }

    func begin(audio: AudioEngine, midi: MIDIInput) {
        self.audio = audio
        self.midi = midi
        if !ClauApp.isTest { midi.start() }
        cable = midi.connected
        midi.onNote = { [weak self] note, time in self?.cableNote(note, at: time) }
        midi.onRelease = { [weak self] note, time in self?.releasedInRhythm(note, at: time) }
        cableWatch = midi.$connected.receive(on: DispatchQueue.main).sink { [weak self] on in self?.cableChanged(on) }
        if !ClauApp.isTest { audio.start(microphone: usesMicrophone) }
        audio.onNote = { [weak self] midi in
            guard let self, self.usesMicrophone else { return }
            self.heard(midi)
        }
        enterStep()
    }

    /// S'ha endollat o desendollat el piano a mitja lliçó: es canvia de manera d'escoltar.
    private func cableChanged(_ on: Bool) {
        guard on != cable else { return }
        cable = on
        if !ClauApp.isTest { audio?.start(microphone: usesMicrophone) }
        if on {
            audio?.setListening(false)
        } else if usesMicrophone, case .play = step, !stepComplete {
            audio?.setListening(true)
        }
    }

    /// Una tecla del piano connectat per cable. El piano ja sona sol: l'app només en pren nota.
    private func cableNote(_ note: Int, at time: TimeInterval) {
        guard !isPlaying else { return }
        heard(note, at: time)
    }

    func end() {
        playback?.cancel()
        advancing?.cancel()
        rhythmTask?.cancel()
        heldVoices = [:]
        audio?.stopPlaying()
        audio?.setListening(false)
        audio?.onNote = nil
        midi?.onNote = nil
        midi?.onRelease = nil
        cableWatch = nil
    }

    // MARK: Avançar

    /// Passos que l'alumne ha saltat sense que l'app els hagi pogut comprovar.
    @Published private(set) var skipped = 0

    /// Salta el pas sense comprovar-lo: la lliçó continua, però al final no es dirà que s'ha tocat tot.
    func skip() {
        skipped += 1
        advance()
    }

    func advance() {
        playback?.cancel()
        advancing?.cancel()
        rhythmTask?.cancel()
        heldVoices = [:]
        audio?.stopPlaying()
        audio?.setListening(false)
        sounding = nil
        soundingAlso = nil
        soundingIndex = nil
        rhythmBeat = nil
        isPlaying = false

        if stepIndex + 1 < steps.count {
            stepIndex += 1
            enterStep()
        } else {
            finished = true
        }
    }

    private func enterStep() {
        goalIndex = 0
        round = 0
        used = []
        stepComplete = false
        message = ""
        mood = .neutral
        hasListened = false
        rhythmPhase = .idle
        count = nil
        judge = nil
        rhythmTarget = nil
        rhythmTargetAlso = nil
        rhythmIndex = nil
        rhythmBeat = nil
        awaitingVerdict = false
        marks = []

        switch step {
        case .look:
            break
        case .listen:
            playExample(after: 0.6)
        case .play:
            if usesMicrophone { audio?.setListening(true) }
        case .rhythm(_, let tones, _, _, _):
            marks = Array(repeating: .pending, count: tones.count)
        }
    }

    // MARK: Teclat de la pantalla

    /// L'alumne ha tocat una tecla del teclat dibuixat: sona i, si és un pas de tocar, compta.
    /// `time` és l'instant en què el dit ha tocat la pantalla.
    func keyPressed(_ midi: Int, at time: TimeInterval? = nil) {
        if let previous = heldVoices.removeValue(forKey: midi) { audio?.noteOff(previous) }
        if let audio { heldVoices[midi] = audio.noteOn(midi: midi) }
        pressCount += 1
        guard instrument == .screen, !isPlaying else { return }
        heard(midi, at: time)
    }

    func keyReleased(_ midi: Int) {
        if let voice = heldVoices.removeValue(forKey: midi) { audio?.noteOff(voice) }
        guard instrument == .screen else { return }
        releasedInRhythm(midi, at: nil)
    }

    // MARK: Escoltar

    /// L'exemple del pas. En un pas de tocar a temps també es pot tornar a sentir, mentre no s'hi estigui tocant.
    private var example: (tones: [Tone], bpm: Double, pulse: Bool)? {
        switch step {
        case .listen(_, let tones, let bpm, _, let pulse): return (tones, bpm, pulse)
        case .rhythm(_, let tones, let bpm, _, _): return rhythmPhase == .idle && !stepComplete ? (tones, bpm, true) : nil
        default: return nil
        }
    }

    func playExample(after delay: Double = 0) {
        guard let (tones, bpm, pulse) = example else { return }
        advancing?.cancel()
        playback?.cancel()
        audio?.stopPlaying()
        isPlaying = true
        count = nil
        rhythmBeat = nil
        let beat = beatLength(bpm)
        let lead = pulse ? 4 : 0
        let total = tones.reduce(0) { $0 + $1.beats }
        let ticks = pulse ? lead + Int(total.rounded(.up)) : 0
        let origin = CACurrentMediaTime() + delay + 0.05
        let first = origin + Double(lead) * beat

        // Cops i notes, ordenats pel moment en què han de sonar. A part, per on va la peça (`rhythmBeat`),
        // perquè els punts de sota les notes s'encenguin com quan toca l'alumne, amb pols o sense.
        var events: [(time: Double, tick: Int?, piece: Double?, tone: Tone?, index: Int)] = []
        for tick in 0..<ticks { events.append((origin + Double(tick) * beat, tick, nil, nil, 0)) }
        // De mig cop en mig cop, perquè també s'encenguin les corxeres que cauen entre dos cops.
        for half in 0..<Int((2 * total).rounded(.up)) {
            let piece = Double(half) / 2
            events.append((first + piece * beat, nil, piece, nil, 0))
        }
        var at = first
        for (index, tone) in tones.enumerated() {
            events.append((at, nil, nil, tone, index))
            at += tone.beats * beat
        }
        events.sort { $0.time < $1.time }
        let end = at

        playback = Task { [weak self] in
            for event in events {
                await LessonRunner.sleep(until: event.time)
                guard !Task.isCancelled, let self else { return }
                if let tick = event.tick {
                    self.audio?.click(accent: tick % 4 == 0)
                    self.count = tick % 4 + 1
                }
                if let piece = event.piece { self.rhythmBeat = piece }
                if let tone = event.tone {
                    self.sounding = tone.rest ? nil : tone.midi
                    self.soundingAlso = tone.rest ? nil : tone.also
                    self.soundingIndex = event.index
                    if !tone.rest {
                        self.audio?.play(midi: tone.midi, seconds: tone.written * beat * 0.92)
                        if let also = tone.also { self.audio?.play(midi: also, seconds: tone.alsoWritten * beat * 0.92) }
                    }
                }
            }
            await LessonRunner.sleep(until: end)
            guard !Task.isCancelled, let self else { return }
            self.sounding = nil
            self.soundingAlso = nil
            self.soundingIndex = nil
            self.count = nil
            self.rhythmBeat = nil
            self.isPlaying = false
            self.hasListened = true
        }
    }

    private static func sleep(until time: CFTimeInterval) async {
        let wait = time - CACurrentMediaTime()
        // Sense marge: el pols ha de sonar al seu moment, no «més o menys».
        if wait > 0 { try? await Task.sleep(for: .seconds(wait), tolerance: .zero) }
    }

    // MARK: Tocar a temps

    /// Compta quatre cops i després escolta el ritme sencer.
    func startRhythm() {
        guard case .rhythm(_, let tones, let bpm, _, _) = step, !stepComplete, rhythmPhase == .idle, !isPlaying else { return }
        rhythmTask?.cancel()
        advancing?.cancel()
        let beat = beatLength(bpm)
        let microphone = usesMicrophone
        // Dues notes alhora pel micròfon: no es jutja res. Només es marca el pols i després l'alumne diu com ha anat.
        let own = selfChecked
        // La pantalla i el cable saben quina tecla és: quan hi ha notes de la mà esquerra, l'octava també compta.
        // Pel micròfon, no: de vegades salta d'octava, i n'hi ha prou amb el nom.
        let leftHand = tones.contains { !$0.rest && ($0.midi < 60 || ($0.also ?? 60) < 60) }
        let judge = RhythmJudge(tones: tones, beat: beat, slack: microphone ? 0.06 : 0, exact: !microphone && leftHand)
        self.judge = own ? nil : judge
        marks = own ? Array(repeating: .pending, count: tones.count) : judge.toneMarks
        awaitingVerdict = false
        rhythmTarget = nil
        rhythmTargetAlso = nil
        say("", .neutral)
        rhythmBeat = nil
        rhythmPhase = .countIn

        let origin = CACurrentMediaTime() + 0.5
        let start = origin + 4 * beat
        patternStart = start
        let ticks = 4 + Int((judge.length / beat).rounded(.up))
        let lag = inputDelay

        rhythmTask = Task { [weak self] in
            for half in 0..<(2 * ticks) {
                await LessonRunner.sleep(until: origin + Double(half) / 2 * beat)
                guard !Task.isCancelled, let self else { return }
                // Al mig del cop només avança per on va la peça, perquè s'encenguin les corxeres que hi cauen.
                if half % 2 == 1 {
                    if half > 8 { self.rhythmBeat = Double(half) / 2 - 4 }
                    continue
                }
                let tick = half / 2
                let counting = tick < 4
                // Amb un piano de debò el pols calla mentre toques, perquè el micròfon no el confongui amb una nota.
                if counting || !microphone || own { self.audio?.click(accent: tick % 4 == 0) }
                self.count = tick % 4 + 1
                if tick == 3 {
                    if microphone, !own { self.audio?.setListening(true) }
                    self.showRhythmTarget()
                }
                if !counting {
                    self.rhythmBeat = Double(tick - 4)
                    self.rhythmPhase = .playing
                    // Amb el mateix rellotge que els tocs: un toc que arriba tard pel retard del so o del micròfon
                    // encara pot entrar dins del marge, i la nota no s'ha de donar per perduda abans d'hora.
                    self.judge?.close(upTo: CACurrentMediaTime() - start - lag)
                    self.refreshRhythm()
                }
            }
            await LessonRunner.sleep(until: start + judge.length + (own ? 0 : judge.tolerance + lag))
            guard !Task.isCancelled, let self else { return }
            if own { self.askVerdict() } else { self.finishRhythm() }
        }
    }

    /// S'ha acabat el pols d'un pas que l'app no pot comprovar: ara li toca dir-ho a l'alumne.
    private func askVerdict() {
        rhythmPhase = .idle
        rhythmBeat = nil
        count = nil
        awaitingVerdict = true
        say("", .neutral)
    }

    /// L'alumne diu si el que ha tocat ha sonat com l'exemple.
    func selfVerdict(_ good: Bool) {
        guard awaitingVerdict, case .rhythm(_, _, _, let rounds, _) = step else { return }
        awaitingVerdict = false
        guard good else {
            say("Cap problema. Si vols, escolta l'exemple i torna-hi.", .wrong)
            return
        }
        LessonRunner.log("lliçó \(lesson.number), pas \(stepIndex + 1), piano, l'alumne s'escolta: diu que ha sortit bé")
        round += 1
        if round >= rounds {
            completeStep()
            return
        }
        say(rounds - round == 1 ? "Bé. Una vegada més." : "Bé. Torna-hi.", .good)
        advancing = Task { [weak self] in
            try? await Task.sleep(for: .seconds(1.6))
            guard !Task.isCancelled else { return }
            self?.startRhythm()
        }
    }

    private static let diary = Logger(subsystem: "cat.sergicastillo.clau", category: "ritme")

    /// Registre dels ritmes tocats, per poder mirar què ha passat quan alguna cosa no quadra.
    /// Es queda a l'aparell (Documents/ritme.txt) i no s'envia enlloc.
    private static func log(_ text: String) {
        // Fora de l'app (les proves al Mac) no s'escriu res enlloc.
        guard Bundle.main.bundleIdentifier != nil else { return }
        // També al registre del sistema, que al Mac es pot llegir amb l'eina `log`.
        for line in text.split(separator: "\n") { diary.notice("\(String(line), privacy: .public)") }
        guard let folder = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
        let file = folder.appendingPathComponent("ritme.txt")
        var all = (try? String(contentsOf: file, encoding: .utf8)) ?? ""
        if all.count > 60_000 { all = String(all.suffix(30_000)) }
        all += "\(Date().formatted(date: .numeric, time: .standard)) \(text)\n"
        try? all.write(to: file, atomically: true, encoding: .utf8)
    }

    /// El màxim que es resta a un toc per comparar-lo amb el pols: el retard del so i, amb micròfon, el de sentir-lo.
    private var inputDelay: Double {
        (audio?.outputDelay ?? 0) + (usesMicrophone ? microphoneDelay : 0)
    }

    private func heardInRhythm(_ midi: Int, at moment: TimeInterval?) {
        guard rhythmPhase != .idle, var judge else { return }
        let beatLength: Double
        if case .rhythm(_, _, let bpm, _, _) = step { beatLength = self.beatLength(bpm) } else { return }
        // El dit es compara amb el pols tal com se sent, que surt una mica més tard del que s'ha demanat.
        var time = (moment ?? CACurrentMediaTime()) - patternStart - (audio?.outputDelay ?? 0)
        if usesMicrophone, moment == nil { time -= microphoneDelay }
        // Mentre es compta no es jutja res, tret de qui entra massa aviat: l'últim cop d'entrada ja compta.
        guard time > -1.5 * beatLength else { return }
        judge.heard(midi: midi, at: time)
        self.judge = judge
        refreshRhythm()
    }

    /// S'ha deixat anar una tecla (pantalla o cable) mentre es toca a temps: el jutge mira si s'ha aguantat prou la nota.
    private func releasedInRhythm(_ midi: Int, at moment: TimeInterval?) {
        guard rhythmPhase != .idle, !usesMicrophone, var judge else { return }
        judge.released(midi: midi, at: (moment ?? CACurrentMediaTime()) - patternStart - (audio?.outputDelay ?? 0))
        self.judge = judge
        refreshRhythm()
    }

    private func refreshRhythm() {
        guard let judge else { return }
        marks = judge.toneMarks
        showRhythmTarget()
    }

    private func showRhythmTarget() {
        guard case .rhythm(_, let tones, _, _, _) = step, let index = judge?.nextToneIndex else {
            rhythmTarget = nil
            rhythmTargetAlso = nil
            rhythmIndex = nil
            return
        }
        rhythmTarget = tones[index].midi
        rhythmTargetAlso = tones[index].also
        rhythmIndex = index
    }

    private func finishRhythm() {
        guard case .rhythm(_, _, _, let rounds, _) = step, var judge else { return }
        judge.close(upTo: .infinity)
        self.judge = judge
        marks = judge.toneMarks
        rhythmTarget = nil
        rhythmTargetAlso = nil
        rhythmIndex = nil
        rhythmBeat = nil
        rhythmPhase = .idle
        count = nil
        audio?.setListening(false)

        LessonRunner.log("lliçó \(lesson.number), pas \(stepIndex + 1), \(instrument == .screen ? "pantalla" : (cable ? "piano per cable" : "piano")), velocitat \(speed.label), sortida de so \(String(format: "%.3f", audio?.outputDelay ?? 0)) s\n  \(judge.report)")

        guard judge.passed else {
            say(judge.verdict, .wrong)
            return
        }
        round += 1
        if round >= rounds {
            completeStep()
            return
        }
        say(rounds - round == 1 ? "Bé. Una vegada més." : "Bé. Torna-hi.", .good)
        advancing = Task { [weak self] in
            try? await Task.sleep(for: .seconds(1.6))
            guard !Task.isCancelled else { return }
            self?.startRhythm()
        }
    }

    // MARK: Tocar

    private func heard(_ midi: Int, at moment: TimeInterval? = nil) {
        if case .rhythm = step {
            heardInRhythm(midi, at: moment)
            return
        }
        guard case .play(_, let goals, let rounds, _, let distinct) = step, !stepComplete, !finished else { return }
        let goal = goals[goalIndex]

        if distinct, goal.accept.matches(midi), used.contains(midi) {
            say("Aquest ja l'has tocat. Busca'n un altre.", .wrong)
            return
        }

        guard goal.accept.matches(midi) else {
            say(wrongMessage(for: midi, goal: goal), .wrong)
            return
        }

        used.insert(midi)
        goalIndex += 1
        say("", .good)

        guard goalIndex == goals.count else { return }
        round += 1
        if round >= rounds {
            completeStep()
        } else {
            goalIndex = 0
            used = []
            say(rounds - round == 1 ? "Bé. Una vegada més." : "Bé. Torna-hi.", .good)
        }
    }

    private func wrongMessage(for midi: Int, goal: Goal) -> String {
        if case .exact(let wanted) = goal.accept, Music.pitchClass(wanted) == Music.pitchClass(midi) {
            return midi < wanted
                ? "Aquest \(Music.name(midi)) és més greu. Busca'l més a la dreta."
                : "Aquest \(Music.name(midi)) és més agut. Busca'l més a l'esquerra."
        }
        // A les dues primeres lliçons encara no se sap el nom de cap tecla.
        if lesson.number < 3 {
            return Music.isBlack(midi) ? "Has tocat una negra, però no és aquesta." : "Has tocat una tecla blanca. Busca la negra."
        }
        if Music.isBlack(midi) { return "Has tocat una tecla negra. Busca la blanca." }
        return "Has tocat \(Music.name(midi)). No és aquesta."
    }

    private func completeStep() {
        stepComplete = true
        audio?.setListening(false)
        say("Molt bé.", .good)
        advancing = Task { [weak self] in
            try? await Task.sleep(for: .seconds(1.3))
            guard !Task.isCancelled else { return }
            self?.advance()
        }
    }

    private func say(_ text: String, _ mood: Mood) {
        message = text
        self.mood = mood
    }
}
