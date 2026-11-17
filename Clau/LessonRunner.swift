import Foundation

/// Porta l'alumne pas a pas per una lliçó.
@MainActor
final class LessonRunner: ObservableObject {
    enum Mood { case neutral, good, wrong }

    let lesson: Lesson

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

    private var used: Set<Int> = []
    private var playback: Task<Void, Never>?
    private var advancing: Task<Void, Never>?
    private weak var audio: AudioEngine?

    init(lesson: Lesson) {
        self.lesson = lesson
    }

    var step: Step { lesson.steps[min(stepIndex, lesson.steps.count - 1)] }

    func begin(audio: AudioEngine) {
        self.audio = audio
        if !ClauApp.isTest { audio.start() }
        audio.onNote = { [weak self] midi in self?.heard(midi) }
        enterStep()
    }

    func end() {
        playback?.cancel()
        advancing?.cancel()
        audio?.stopPlaying()
        audio?.setListening(false)
        audio?.onNote = nil
    }

    // MARK: Avançar

    func advance() {
        playback?.cancel()
        advancing?.cancel()
        audio?.stopPlaying()
        audio?.setListening(false)
        sounding = nil
        isPlaying = false

        if stepIndex + 1 < lesson.steps.count {
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

        switch step {
        case .look:
            break
        case .listen:
            playExample(after: 0.6)
        case .play:
            audio?.setListening(true)
        }
    }

    // MARK: Escoltar

    func playExample(after delay: Double = 0) {
        guard case .listen(_, let tones, let bpm, _) = step else { return }
        playback?.cancel()
        audio?.stopPlaying()
        isPlaying = true
        let beat = 60 / bpm

        playback = Task { [weak self] in
            if delay > 0 { try? await Task.sleep(for: .seconds(delay)) }
            for tone in tones {
                guard !Task.isCancelled, let self else { return }
                let length = tone.beats * beat
                self.sounding = tone.midi
                self.audio?.play(midi: tone.midi, seconds: length * 0.92)
                try? await Task.sleep(for: .seconds(length))
            }
            guard !Task.isCancelled, let self else { return }
            self.sounding = nil
            self.isPlaying = false
            self.hasListened = true
        }
    }

    // MARK: Tocar

    private func heard(_ midi: Int) {
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
