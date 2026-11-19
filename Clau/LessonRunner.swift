import Foundation
import QuartzCore

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

    private var judge: RhythmJudge?
    private var patternStart: CFTimeInterval = 0
    private var rhythmTask: Task<Void, Never>?
    /// El micròfon triga una mica a reconèixer una nota.
    private let microphoneDelay = 0.12

    private var used: Set<Int> = []
    private var playback: Task<Void, Never>?
    private var advancing: Task<Void, Never>?
    private weak var audio: AudioEngine?

    init(lesson: Lesson, instrument: Instrument) {
        self.lesson = lesson
        self.instrument = instrument
        steps = lesson.steps(for: instrument)
    }

    var step: Step { steps[min(stepIndex, steps.count - 1)] }

    func begin(audio: AudioEngine) {
        self.audio = audio
        if !ClauApp.isTest { audio.start(microphone: instrument == .real) }
        audio.onNote = instrument == .real ? { [weak self] midi in self?.heard(midi) } : nil
        enterStep()
    }

    func end() {
        playback?.cancel()
        advancing?.cancel()
        rhythmTask?.cancel()
        audio?.stopPlaying()
        audio?.setListening(false)
        audio?.onNote = nil
    }

    // MARK: Avançar

    func advance() {
        playback?.cancel()
        advancing?.cancel()
        rhythmTask?.cancel()
        audio?.stopPlaying()
        audio?.setListening(false)
        sounding = nil
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
        marks = []

        switch step {
        case .look:
            break
        case .listen:
            playExample(after: 0.6)
        case .play:
            if instrument == .real { audio?.setListening(true) }
        case .rhythm(_, let tones, _, _, _):
            marks = Array(repeating: .pending, count: tones.count)
        }
    }

    // MARK: Teclat de la pantalla

    /// L'alumne ha tocat una tecla del teclat dibuixat: sona i, si és un pas de tocar, compta.
    func keyPressed(_ midi: Int) {
        audio?.play(midi: midi, seconds: 0.9)
        guard instrument == .screen, !isPlaying else { return }
        heard(midi)
    }

    // MARK: Escoltar

    func playExample(after delay: Double = 0) {
        guard case .listen(_, let tones, let bpm, _, let pulse) = step else { return }
        playback?.cancel()
        audio?.stopPlaying()
        isPlaying = true
        count = nil
        let beat = 60 / bpm
        let lead = pulse ? 4 : 0
        let total = tones.reduce(0) { $0 + $1.beats }
        let ticks = pulse ? lead + Int(total.rounded(.up)) : 0
        let origin = CACurrentMediaTime() + delay + 0.05
        let first = origin + Double(lead) * beat

        // Cops i notes, ordenats pel moment en què han de sonar.
        var events: [(time: Double, tick: Int?, tone: Tone?)] = []
        for tick in 0..<ticks { events.append((origin + Double(tick) * beat, tick, nil)) }
        var at = first
        for tone in tones {
            events.append((at, nil, tone))
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
                if let tone = event.tone {
                    self.sounding = tone.rest ? nil : tone.midi
                    if !tone.rest { self.audio?.play(midi: tone.midi, seconds: tone.beats * beat * 0.92) }
                }
            }
            await LessonRunner.sleep(until: end)
            guard !Task.isCancelled, let self else { return }
            self.sounding = nil
            self.count = nil
            self.isPlaying = false
            self.hasListened = true
        }
    }

    private static func sleep(until time: CFTimeInterval) async {
        let wait = time - CACurrentMediaTime()
        if wait > 0 { try? await Task.sleep(for: .seconds(wait)) }
    }

    // MARK: Tocar a temps

    /// Compta quatre cops i després escolta el ritme sencer.
    func startRhythm() {
        guard case .rhythm(_, let tones, let bpm, _, _) = step, !stepComplete, rhythmPhase == .idle else { return }
        rhythmTask?.cancel()
        advancing?.cancel()
        let beat = 60 / bpm
        let judge = RhythmJudge(tones: tones, beat: beat, slack: instrument == .real ? 0.06 : 0)
        self.judge = judge
        marks = judge.toneMarks
        rhythmTarget = nil
        say("", .neutral)
        rhythmPhase = .countIn

        let origin = CACurrentMediaTime() + 0.5
        let start = origin + 4 * beat
        patternStart = start
        let ticks = 4 + Int((judge.length / beat).rounded(.up))

        rhythmTask = Task { [weak self] in
            for tick in 0..<ticks {
                await LessonRunner.sleep(until: origin + Double(tick) * beat)
                guard !Task.isCancelled, let self else { return }
                let counting = tick < 4
                // Amb un piano de debò el pols calla mentre toques, perquè el micròfon no el confongui amb una nota.
                if counting || self.instrument == .screen { self.audio?.click(accent: tick % 4 == 0) }
                self.count = tick % 4 + 1
                if tick == 3 {
                    if self.instrument == .real { self.audio?.setListening(true) }
                    self.showRhythmTarget()
                }
                if !counting {
                    self.rhythmPhase = .playing
                    self.judge?.close(upTo: CACurrentMediaTime() - start)
                    self.refreshRhythm()
                }
            }
            await LessonRunner.sleep(until: start + judge.length + judge.tolerance)
            guard !Task.isCancelled, let self else { return }
            self.finishRhythm()
        }
    }

    private func heardInRhythm(_ midi: Int) {
        guard rhythmPhase != .idle, var judge else { return }
        let beatLength: Double
        if case .rhythm(_, _, let bpm, _, _) = step { beatLength = 60 / bpm } else { return }
        var time = CACurrentMediaTime() - patternStart
        if instrument == .real { time -= microphoneDelay }
        // Mentre es compta no es jutja res, tret de qui entra massa aviat.
        guard time > -0.5 * beatLength else { return }
        judge.heard(midi: midi, at: time)
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
            return
        }
        rhythmTarget = tones[index].midi
    }

    private func finishRhythm() {
        guard case .rhythm(_, _, _, let rounds, _) = step, var judge else { return }
        judge.close(upTo: .infinity)
        self.judge = judge
        marks = judge.toneMarks
        rhythmTarget = nil
        rhythmPhase = .idle
        count = nil
        audio?.setListening(false)

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

    private func heard(_ midi: Int) {
        if case .rhythm = step {
            heardInRhythm(midi)
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
