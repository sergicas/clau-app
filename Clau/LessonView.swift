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

    init(lesson: Lesson, onClose: @escaping () -> Void, onNext: @escaping (Lesson) -> Void) {
        self.lesson = lesson
        self.onClose = onClose
        self.onNext = onNext
        _runner = StateObject(wrappedValue: LessonRunner(lesson: lesson))
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            if runner.finished {
                finishedView
            } else {
                ScrollView {
                    stepContent
                        .padding(.horizontal, 22)
                        .padding(.top, 18)
                        .padding(.bottom, 24)
                        .frame(maxWidth: verticalSizeClass == .compact ? 900 : 640)
                        .frame(maxWidth: .infinity)
                }
                footer
            }
        }
        .background(Theme.paper.ignoresSafeArea())
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
        VStack(spacing: 12) {
            HStack {
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(Theme.ink)
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel("Tanca la lliçó")
                Spacer()
                Text("Lliçó \(lesson.number)")
                    .font(Theme.serif(.headline, weight: .semibold))
                    .foregroundStyle(Theme.soft)
                Spacer()
                Color.clear.frame(width: 44, height: 44)
            }
            HStack(spacing: 5) {
                ForEach(lesson.steps.indices, id: \.self) { index in
                    Capsule()
                        .fill(index < runner.stepIndex || runner.finished ? Theme.ink : (index == runner.stepIndex ? Theme.brass : Theme.line))
                        .frame(height: 5)
                }
            }
            .accessibilityElement()
            .accessibilityLabel("Pas \(min(runner.stepIndex + 1, lesson.steps.count)) de \(lesson.steps.count)")
        }
        .padding(.horizontal, 14)
        .padding(.bottom, 10)
    }

    // MARK: Passos

    /// Amb el telèfon apaïsat al faristol hi ha poca alçada: el text va a un costat i el teclat a l'altre.
    @ViewBuilder
    private var stepContent: some View {
        if verticalSizeClass == .compact {
            HStack(alignment: .top, spacing: 24) {
                VStack(alignment: .leading, spacing: 14) { stepWords }
                    .frame(maxWidth: .infinity, alignment: .leading)
                stepPicture
                    .frame(maxWidth: .infinity)
            }
        } else {
            VStack(alignment: .leading, spacing: 20) {
                switch runner.step {
                case .look:
                    stepHeading
                    stepPicture
                    stepText
                case .listen:
                    stepHeading
                    stepPicture
                    stepText
                case .play:
                    stepWords
                    stepPicture
                    stepStatus
                }
            }
        }
    }

    @ViewBuilder
    private var stepHeading: some View {
        switch runner.step {
        case .look: stepLabel("Mira", "eye")
        case .listen: stepLabel("Escolta", "ear")
        case .play: stepLabel("Toca", "pianokeys")
        }
    }

    @ViewBuilder
    private var stepText: some View {
        switch runner.step {
        case .look(let text, _): bodyText(text)
        case .listen(let text, _, _, _): bodyText(text)
        case .play(let text, _, _, _, _): bodyText(text)
        }
    }

    /// Tot el que es llegeix d'un pas. En vertical, l'estat del micròfon va sota el teclat.
    @ViewBuilder
    private var stepWords: some View {
        stepHeading
        stepText
        if case .play(_, let goals, _, _, _) = runner.step {
            if goals.count > 1 || goals.first?.accept != .any {
                goalChips(goals)
            }
            if verticalSizeClass == .compact { stepStatus }
        }
    }

    @ViewBuilder
    private var stepStatus: some View {
        if case .play(_, _, let rounds, _, _) = runner.step {
            if rounds > 1 { roundDots(rounds) }
            listeningRow
        }
    }

    @ViewBuilder
    private var stepPicture: some View {
        switch runner.step {
        case .look(_, let picture):
            pictureView(picture)
        case .listen(_, _, _, let keyboard):
            KeyboardView(keyboard: keyboard, sounding: runner.sounding)
        case .play(_, let goals, _, let keyboard, _):
            KeyboardView(keyboard: keyboard, target: runner.stepComplete ? nil : goals[min(runner.goalIndex, goals.count - 1)].key)
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
            .font(Theme.serif(.title2))
            .foregroundStyle(Theme.ink)
            .lineSpacing(5)
            .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder
    private func pictureView(_ picture: Picture) -> some View {
        switch picture {
        case .symbol(let name):
            Image(systemName: name)
                .font(.system(size: 92))
                .foregroundStyle(Theme.brass)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 26)
                .background(Theme.card, in: RoundedRectangle(cornerRadius: 20))
                .accessibilityHidden(true)
        case .keyboard(let keyboard):
            KeyboardView(keyboard: keyboard)
        }
    }

    private func goalChips(_ goals: [Goal]) -> some View {
        Flow(spacing: 7) {
            ForEach(Array(goals.enumerated()), id: \.offset) { index, goal in
                let done = index < runner.goalIndex || runner.stepComplete
                let current = index == runner.goalIndex && !runner.stepComplete
                Text(goal.label)
                    .font(Theme.serif(.title3, weight: .semibold))
                    .padding(.horizontal, 13)
                    .padding(.vertical, 8)
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
                    Text(statusText)
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

    private var statusText: String {
        if !runner.message.isEmpty { return runner.message }
        return runner.goalIndex == 0 && runner.round == 0 ? "T'escolto. Quan vulguis." : "T'escolto."
    }

    // MARK: Peu

    @ViewBuilder
    private var footer: some View {
        let layout = verticalSizeClass == .compact ? AnyLayout(HStackLayout(spacing: 12)) : AnyLayout(VStackLayout(spacing: 10))
        layout {
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
                    Button("Continua sense comprovar") { runner.advance() }
                        .font(.body)
                        .foregroundStyle(Theme.soft)
                        .frame(minHeight: 44)
                }
            }
        }
        .padding(.horizontal, 22)
        .padding(.top, verticalSizeClass == .compact ? 4 : 10)
        .padding(.bottom, verticalSizeClass == .compact ? 6 : 14)
        .frame(maxWidth: verticalSizeClass == .compact ? 900 : 640)
        .frame(maxWidth: .infinity)
        .background(Theme.paper)
    }

    private var nextIsPlay: Bool {
        let next = runner.stepIndex + 1
        guard next < lesson.steps.count, case .play = lesson.steps[next] else { return false }
        return true
    }

    // MARK: Final

    private var finishedView: some View {
        VStack(spacing: 22) {
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 76))
                .foregroundStyle(Theme.sage)
                .accessibilityHidden(true)
            Text(lesson.isPiece ? "Has tocat la teva primera peça." : "Lliçó acabada.")
                .font(Theme.serif(.largeTitle, weight: .semibold))
                .foregroundStyle(Theme.ink)
                .multilineTextAlignment(.center)
            Text(lesson.title)
                .font(Theme.serif(.title3))
                .foregroundStyle(Theme.soft)
            Spacer()
            VStack(spacing: 10) {
                if let next = Course.lesson(after: lesson) {
                    Button("Següent: \(next.title)") { onNext(next) }
                        .buttonStyle(PrimaryButton())
                    Button("Torna al curs", action: onClose)
                        .buttonStyle(SecondaryButton())
                } else {
                    Button("Torna al curs", action: onClose)
                        .buttonStyle(PrimaryButton())
                }
            }
        }
        .padding(.horizontal, 22)
        .padding(.bottom, 14)
        .frame(maxWidth: 640)
        .frame(maxWidth: .infinity)
    }
}
