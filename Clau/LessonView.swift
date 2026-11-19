import SwiftUI
import UIKit

struct LessonView: View {
    let lesson: Lesson
    let onClose: () -> Void
    let onNext: (Lesson) -> Void

    @EnvironmentObject private var audio: AudioEngine
    @EnvironmentObject private var progress: LessonProgress
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @StateObject private var runner: LessonRunner

    init(lesson: Lesson, instrument: Instrument, onClose: @escaping () -> Void, onNext: @escaping (Lesson) -> Void) {
        self.lesson = lesson
        self.onClose = onClose
        self.onNext = onNext
        _runner = StateObject(wrappedValue: LessonRunner(lesson: lesson, instrument: instrument))
    }

    /// Telèfon apaïsat: hi ha poca alçada.
    private var compact: Bool { verticalSizeClass == .compact }
    private var onScreen: Bool { runner.instrument == .screen }

    var body: some View {
        VStack(spacing: 0) {
            header
            if runner.finished {
                finishedView
            } else if onScreen {
                screenLayout
            } else {
                realLayout
            }
        }
        .background(Theme.paper.ignoresSafeArea())
        .overlay(alignment: .topTrailing) {
            // Només a les proves: quantes vegades ha comptat una tecla.
            if ClauApp.isTest {
                Text("premudes \(runner.pressCount)")
                    .font(.caption2)
                    .foregroundStyle(Theme.soft)
                    .padding(.trailing, 60)
                    .accessibilityIdentifier("premudes")
            }
        }
        .onAppear {
            UIApplication.shared.isIdleTimerDisabled = true
            runner.begin(audio: audio)
        }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
            runner.end()
        }
        .onChange(of: runner.finished) { _, finished in
            if finished { progress.complete(lesson) }
        }
    }

    // MARK: Capçalera

    private var header: some View {
        let layout = compact ? AnyLayout(HStackLayout(spacing: 10)) : AnyLayout(VStackLayout(spacing: 12))
        return layout {
            HStack {
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(Theme.ink)
                        .frame(width: 44, height: compact ? 36 : 44)
                }
                .accessibilityLabel("Tanca la lliçó")
                if !compact { Spacer() }
                Text("Lliçó \(lesson.number)")
                    .font(Theme.serif(.headline, weight: .semibold))
                    .foregroundStyle(Theme.soft)
                    .fixedSize()
                if !compact {
                    Spacer()
                    Color.clear.frame(width: 44, height: 44)
                }
            }
            HStack(spacing: 5) {
                ForEach(runner.steps.indices, id: \.self) { index in
                    Capsule()
                        .fill(index < runner.stepIndex || runner.finished ? Theme.ink : (index == runner.stepIndex ? Theme.brass : Theme.line))
                        .frame(height: 5)
                }
            }
            .accessibilityElement()
            .accessibilityLabel("Pas \(min(runner.stepIndex + 1, runner.steps.count)) de \(runner.steps.count)")
        }
        .padding(.horizontal, 14)
        .padding(.bottom, compact ? 4 : 10)
    }

    // MARK: Tocant en un piano de debò

    private var realLayout: some View {
        VStack(spacing: 0) {
            ScrollView {
                realContent
                    .padding(.horizontal, 22)
                    .padding(.top, 18)
                    .padding(.bottom, 24)
                    .frame(maxWidth: compact ? 900 : 640)
                    .frame(maxWidth: .infinity)
            }
            footer
        }
    }

    /// Apaïsat al faristol: el text va a un costat i el teclat a l'altre.
    @ViewBuilder
    private var realContent: some View {
        if compact {
            HStack(alignment: .top, spacing: 24) {
                VStack(alignment: .leading, spacing: 14) {
                    stepWords
                    stepStatus
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                stepPicture
                    .frame(maxWidth: .infinity)
            }
        } else {
            VStack(alignment: .leading, spacing: 20) {
                if isPlayStep {
                    stepWords
                    stepPicture
                    stepStatus
                } else {
                    stepHeading
                    stepPicture
                    stepText
                    stepChips
                    stepStatus
                }
            }
        }
    }

    // MARK: Tocant a la pantalla

    /// El teclat va a baix i ocupa tota l'amplada, perquè les tecles siguin tan grans com es pugui.
    @ViewBuilder
    private var screenLayout: some View {
        if compact {
            HStack(alignment: .top, spacing: 16) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 10) {
                        stepWords
                        stepStatus
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                VStack(spacing: 8) { footerButtons }
                    .frame(width: 230)
            }
            .padding(.horizontal, 22)
            .padding(.top, 2)
            touchKeyboard
                .frame(height: 178)
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    stepHeading
                    if case .look(_, .symbol(let name)) = runner.step { symbolPicture(name) }
                    stepText
                    stepChips
                    stepStatus
                }
                .padding(.horizontal, 22)
                .padding(.top, 18)
                .padding(.bottom, 12)
                .frame(maxWidth: 640, alignment: .leading)
                .frame(maxWidth: .infinity)
            }
            touchKeyboard
                .frame(height: 240)
            footer
        }
    }

    private var touchKeyboard: some View {
        KeyboardView(
            keyboard: stepKeyboard,
            target: stepTarget,
            sounding: runner.sounding,
            onPress: { runner.keyPressed($0, at: $1) },
            onRelease: { runner.keyReleased($0) },
            fills: true,
            pages: isPlayStep
        )
        .id(runner.stepIndex)
        .padding(.horizontal, 6)
        .padding(.top, 6)
    }

    // MARK: Peces d'un pas

    /// Un pas en què toca l'alumne, amb pols o sense.
    private var isPlayStep: Bool {
        switch runner.step {
        case .play, .rhythm: return true
        default: return false
        }
    }

    private var stepKeyboard: Keyboard {
        switch runner.step {
        case .look(_, .keyboard(let keyboard)): return keyboard
        case .look: return .oneOctave
        case .listen(_, _, _, let keyboard, _): return keyboard
        case .play(_, _, _, let keyboard, _): return keyboard
        case .rhythm(_, _, _, _, let keyboard): return keyboard
        }
    }

    /// La partitura del pas, si n'hi ha.
    private var stepScore: Score? {
        if case .look(_, .staff(let score)) = runner.step { return score }
        return stepKeyboard.score
    }

    private var stepTarget: Int? {
        // Quan es llegeix sense noms, el teclat no diu quina tecla toca.
        if let score = stepScore, !score.names { return nil }
        if case .rhythm = runner.step { return runner.rhythmTarget }
        guard case .play(_, let goals, _, _, _) = runner.step, !runner.stepComplete else { return nil }
        return goals[min(runner.goalIndex, goals.count - 1)].key
    }

    @ViewBuilder
    private var stepHeading: some View {
        switch runner.step {
        case .look: stepLabel("Mira", "eye")
        case .listen: stepLabel("Escolta", "ear")
        case .play: stepLabel("Toca", "pianokeys")
        case .rhythm: stepLabel("Toca a temps", "metronome")
        }
    }

    @ViewBuilder
    private var stepText: some View {
        switch runner.step {
        case .look(let text, _): bodyText(text)
        case .listen(let text, _, _, _, _): bodyText(text)
        case .play(let text, _, _, _, _): bodyText(text)
        case .rhythm(let text, _, _, _, _): bodyText(text)
        }
    }

    /// Tot el que es llegeix d'un pas.
    @ViewBuilder
    private var stepWords: some View {
        stepHeading
        stepText
        stepChips
    }

    /// Les notes que cal tocar, una fitxa per a cadascuna.
    @ViewBuilder
    private var stepChips: some View {
        if let score = stepScore {
            staff(score)
        } else {
            noteChips
        }
    }

    /// La partitura, amb la nota que toca ara marcada.
    private func staff(_ score: Score) -> some View {
        let count = max(score.tones.count, 1)
        var current: Int?
        var done = 0
        var marks: [RhythmJudge.Mark] = []
        switch runner.step {
        case .look:
            break
        case .listen:
            current = runner.soundingIndex.map { $0 % count }
        case .play:
            done = runner.stepComplete ? count : runner.goalIndex
            current = runner.stepComplete ? nil : runner.goalIndex
        case .rhythm:
            // Si el ritme repeteix la partitura, s'ensenya la volta en què s'està.
            let position = runner.rhythmIndex ?? max(runner.marks.count - 1, 0)
            let lap = position / count
            marks = Array(runner.marks.dropFirst(lap * count).prefix(count))
            current = runner.rhythmPhase == .idle ? nil : runner.rhythmIndex.map { $0 % count }
        }
        var beat: Double?
        if case .rhythm = runner.step { beat = runner.rhythmBeat.map(Double.init) }
        return StaffView(score: score, current: current, done: done, marks: marks, beat: beat, spacing: compact ? 9 : 13)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 16))
    }

    @ViewBuilder
    private var noteChips: some View {
        switch runner.step {
        case .play(_, let goals, _, _, _):
            if showsChips(goals) { goalChips(goals) }
        case .rhythm(_, let tones, _, _, _):
            rhythmChips(tones)
        default:
            EmptyView()
        }
    }

    private func showsChips(_ goals: [Goal]) -> Bool {
        goals.count > 1 || goals.first?.accept != .any
    }

    /// Quantes vegades falten i què ha sentit l'app.
    @ViewBuilder
    private var stepStatus: some View {
        switch runner.step {
        case .play(_, _, let rounds, _, _):
            if rounds > 1 { roundDots(rounds) }
            if onScreen { screenStatus } else { listeningRow }
        case .rhythm(_, _, _, let rounds, _):
            if compact && onScreen {
                // Apaïsat hi ha poca alçada: tot en una ratlla, i el missatge en lloc del rètol del pols.
                HStack(spacing: 14) {
                    pulseDots
                    if rounds > 1 { roundDots(rounds) }
                }
                if runner.message.isEmpty {
                    Text(pulseText.isEmpty ? " " : pulseText)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Theme.soft)
                } else {
                    screenStatus
                }
            } else {
                if rounds > 1 { roundDots(rounds) }
                pulseRow
                if onScreen { screenStatus } else { listeningRow }
            }
        case .listen(_, _, _, _, let pulse):
            if pulse { pulseRow }
        case .look:
            EmptyView()
        }
    }

    /// Els quatre cops del compàs; s'encén el que sona.
    private var pulseRow: some View {
        HStack(spacing: 10) {
            pulseDots
            Text(pulseText)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Theme.soft)
                .padding(.leading, 4)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(pulseText.isEmpty ? "Pols" : pulseText)
        .accessibilityIdentifier("pols")
    }

    private var pulseDots: some View {
        HStack(spacing: 10) {
            ForEach(1...4, id: \.self) { beat in
                Circle()
                    .fill(runner.count == beat ? (beat == 1 ? Theme.terra : Theme.brass) : Theme.line)
                    .frame(width: compact ? 16 : 22, height: compact ? 16 : 22)
                    .scaleEffect(runner.count == beat ? 1.25 : 1)
                    .animation(.easeOut(duration: 0.12), value: runner.count)
            }
        }
        .accessibilityHidden(true)
    }

    private var pulseText: String {
        switch runner.rhythmPhase {
        case .countIn: return "Escolta els quatre cops"
        case .playing: return "Ara tu"
        case .idle: return runner.isPlaying && runner.sounding == nil && runner.count != nil ? "Quatre cops abans" : ""
        }
    }

    /// Cada nota amb el seu nom i, a sota, quants cops dura.
    private func rhythmChips(_ tones: [Tone]) -> some View {
        let small = compact && onScreen
        return Flow(spacing: 6) {
            ForEach(Array(tones.enumerated()), id: \.offset) { index, tone in
                let mark = index < runner.marks.count ? runner.marks[index] : .pending
                let start = tones.prefix(index).reduce(0) { $0 + $1.beats }
                let now = runner.rhythmBeat.map { Double($0) >= start && Double($0) < start + tone.beats } ?? false
                VStack(spacing: 1) {
                    Text(tone.rest ? "–" : Music.name(tone.midi))
                        .font(Theme.serif(small ? .body : .title3, weight: .semibold))
                    Text(beatsLabel(tone.beats))
                        .font(.caption2.weight(.semibold))
                        .opacity(0.75)
                }
                .frame(minWidth: (small ? 30 : 38) * max(0.75, min(CGFloat(tone.beats), 2.6)))
                .padding(.horizontal, small ? 5 : 7)
                .padding(.vertical, small ? 3 : 6)
                .foregroundStyle(mark == .pending ? (tone.rest ? Theme.soft : Theme.ink) : Theme.card)
                .background(chipFill(mark), in: RoundedRectangle(cornerRadius: 12))
                // La vora gruixuda diu per on va el pols: mentre hi és, aquesta nota encara dura.
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(now ? Theme.brass : Theme.line, lineWidth: now ? 3 : (mark == .pending ? 1 : 0)))
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Ritme: " + tones.map { ($0.rest ? "silenci" : Music.name($0.midi)) + " " + beatsLabel($0.beats) }.joined(separator: ", "))
    }

    private func chipFill(_ mark: RhythmJudge.Mark) -> Color {
        switch mark {
        case .pending: return Theme.card
        case .hit: return Theme.sage
        case .wrong, .missed: return Theme.terra
        }
    }

    private func beatsLabel(_ beats: Double) -> String {
        if beats == 0.5 { return "½" }
        if beats == 1.5 { return "1½" }
        return String(Int(beats))
    }

    @ViewBuilder
    private var stepPicture: some View {
        switch runner.step {
        case .look(_, .symbol(let name)):
            symbolPicture(name)
        case .look(_, .staff):
            // La partitura ja surt amb el text. Apaïsat, al costat hi va el teclat.
            if compact { KeyboardView(keyboard: .oneOctave) }
        default:
            KeyboardView(keyboard: stepKeyboard, target: stepTarget, sounding: runner.sounding)
        }
    }

    private func stepLabel(_ title: String, _ symbol: String) -> some View {
        Label(title, systemImage: symbol)
            .font(.subheadline.weight(.bold))
            .textCase(.uppercase)
            .kerning(1.2)
            .foregroundStyle(Theme.brass)
    }

    private func bodyText(_ text: String) -> some View {
        Text(text)
            .font(Theme.serif(compact && onScreen ? .title3 : .title2))
            .foregroundStyle(Theme.ink)
            .lineSpacing(compact && onScreen ? 3 : 5)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func symbolPicture(_ name: String) -> some View {
        Image(systemName: name)
            .font(.system(size: 92))
            .foregroundStyle(Theme.brass)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 26)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 20))
            .accessibilityHidden(true)
    }

    private func goalChips(_ goals: [Goal]) -> some View {
        Flow(spacing: 7) {
            ForEach(Array(goals.enumerated()), id: \.offset) { index, goal in
                let done = index < runner.goalIndex || runner.stepComplete
                let current = index == runner.goalIndex && !runner.stepComplete
                Text(goal.label)
                    .font(Theme.serif(compact && onScreen ? .body : .title3, weight: .semibold))
                    .padding(.horizontal, compact && onScreen ? 10 : 13)
                    .padding(.vertical, compact && onScreen ? 5 : 8)
                    .foregroundStyle(done ? Theme.card : Theme.ink)
                    .background(done ? Theme.sage : (current ? Theme.brass.opacity(0.35) : Theme.card), in: Capsule())
                    .overlay(Capsule().stroke(current ? Theme.brass : Theme.line, lineWidth: current ? 2 : 1))
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Notes: " + goals.map(\.label).joined(separator: ", "))
    }

    private func roundDots(_ rounds: Int) -> some View {
        HStack(spacing: 8) {
            ForEach(0..<rounds, id: \.self) { index in
                Circle()
                    .fill(index < runner.round ? Theme.sage : Theme.line)
                    .frame(width: 14, height: 14)
            }
            Text("\(runner.round) de \(rounds)")
                .font(.subheadline)
                .foregroundStyle(Theme.soft)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(runner.round) de \(rounds) vegades")
    }

    /// A la pantalla no cal micròfon: només es diu com va.
    @ViewBuilder
    private var screenStatus: some View {
        if !runner.message.isEmpty {
            Label(runner.message, systemImage: runner.mood == .wrong ? "arrow.uturn.backward" : "checkmark")
                .font(.body.weight(.medium))
                .foregroundStyle(runner.mood == .wrong ? Theme.terra : Theme.sage)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("estat")
        }
    }

    @ViewBuilder
    private var listeningRow: some View {
        if audio.micState == .denied {
            VStack(alignment: .leading, spacing: 12) {
                Text("Clau no té permís per fer servir el micròfon i no et pot sentir. L'hi pots donar a Configuració, o continuar sense que t'escolti.")
                    .font(.body)
                    .foregroundStyle(Theme.ink)
                Button("Obre Configuració") {
                    if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                }
                .font(.body.weight(.semibold))
                .foregroundStyle(Theme.terra)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 16))
        } else {
            HStack(spacing: 14) {
                Image(systemName: runner.stepComplete ? "checkmark.circle.fill" : "mic.fill")
                    .font(.title2)
                    .foregroundStyle(runner.stepComplete ? Theme.sage : Theme.ink)
                VStack(alignment: .leading, spacing: 7) {
                    Text(listeningText)
                        .font(.body.weight(.medium))
                        .foregroundStyle(runner.mood == .wrong ? Theme.terra : Theme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Theme.line)
                            Capsule().fill(Theme.sage)
                                .frame(width: geometry.size.width * CGFloat(audio.level))
                        }
                    }
                    .frame(height: 6)
                    .animation(.linear(duration: 0.08), value: audio.level)
                    .accessibilityHidden(true)
                }
            }
            .padding(16)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 16))
        }
    }

    private var listeningText: String {
        if !runner.message.isEmpty { return runner.message }
        if case .rhythm = runner.step {
            switch runner.rhythmPhase {
            case .idle: return "Prem «Comença» quan estiguis a punt."
            case .countIn: return "Encara no. Escolta els quatre cops."
            case .playing: return "T'escolto."
            }
        }
        return runner.goalIndex == 0 && runner.round == 0 ? "T'escolto. Quan vulguis." : "T'escolto."
    }

    // MARK: Peu

    @ViewBuilder
    private var footerButtons: some View {
        switch runner.step {
        case .look:
            Button("Continua") { runner.advance() }
                .buttonStyle(PrimaryButton())
        case .listen:
            Button {
                runner.playExample()
            } label: {
                Label(runner.isPlaying ? "Sonant…" : "Torna-ho a escoltar", systemImage: "play.fill")
            }
            .buttonStyle(SecondaryButton())
            .disabled(runner.isPlaying)
            Button(nextIsPlay ? "Ara jo" : "Continua") { runner.advance() }
                .buttonStyle(PrimaryButton())
        case .play:
            if !runner.stepComplete {
                Button(onScreen ? "Salta aquest pas" : "Continua sense comprovar") { runner.advance() }
                    .font(.body)
                    .foregroundStyle(Theme.soft)
                    .frame(minHeight: 44)
            }
        case .rhythm:
            if !runner.stepComplete {
                Button {
                    runner.startRhythm()
                } label: {
                    Label(rhythmButtonText, systemImage: "metronome")
                }
                .buttonStyle(PrimaryButton())
                .disabled(runner.rhythmPhase != .idle)
                Button(onScreen ? "Salta aquest pas" : "Continua sense comprovar") { runner.advance() }
                    .font(.body)
                    .foregroundStyle(Theme.soft)
                    .frame(minHeight: 44)
            }
        }
    }

    private var rhythmButtonText: String {
        if runner.rhythmPhase != .idle { return "Sonant…" }
        return runner.mood == .wrong ? "Torna-hi" : "Comença"
    }

    private var footer: some View {
        let layout = compact ? AnyLayout(HStackLayout(spacing: 12)) : AnyLayout(VStackLayout(spacing: 10))
        return layout { footerButtons }
            .padding(.horizontal, 22)
            .padding(.top, compact ? 4 : 10)
            .padding(.bottom, compact ? 6 : 14)
            .frame(maxWidth: compact ? 900 : 640)
            .frame(maxWidth: .infinity)
            .background(Theme.paper)
    }

    private var nextIsPlay: Bool {
        let next = runner.stepIndex + 1
        guard next < runner.steps.count else { return false }
        switch runner.steps[next] {
        case .play, .rhythm: return true
        default: return false
        }
    }

    // MARK: Final

    private var finishedView: some View {
        VStack(spacing: compact ? 10 : 22) {
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: compact ? 48 : 76))
                .foregroundStyle(Theme.sage)
                .accessibilityHidden(true)
            Text(lesson.isPiece ? (lesson.number == 8 ? "Has tocat la teva primera peça." : "Has tocat la peça sencera.") : "Lliçó acabada.")
                .font(Theme.serif(compact ? .title : .largeTitle, weight: .semibold))
                .foregroundStyle(Theme.ink)
                .multilineTextAlignment(.center)
            Text(lesson.title)
                .font(Theme.serif(.title3))
                .foregroundStyle(Theme.soft)
            Spacer()
            let layout = compact ? AnyLayout(HStackLayout(spacing: 12)) : AnyLayout(VStackLayout(spacing: 10))
            layout {
                if let next = Course.lesson(after: lesson) {
                    Button("Torna al curs", action: onClose)
                        .buttonStyle(SecondaryButton())
                    Button("Següent: \(next.title)") { onNext(next) }
                        .buttonStyle(PrimaryButton())
                } else {
                    Button("Torna al curs", action: onClose)
                        .buttonStyle(PrimaryButton())
                }
            }
        }
        .padding(.horizontal, 22)
        .padding(.bottom, 14)
        .frame(maxWidth: compact ? 900 : 640)
        .frame(maxWidth: .infinity)
    }
}
