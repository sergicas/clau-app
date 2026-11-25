import SwiftUI

struct CourseView: View {
    @EnvironmentObject private var progress: LessonProgress
    @State private var open: Lesson?
    @EnvironmentObject private var midi: MIDIInput
    @AppStorage(Instrument.storageKey) private var instrumentName = Instrument.screen.rawValue

    private var instrument: Instrument { Instrument(rawValue: instrumentName) ?? .screen }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                title
                instrumentPicker
                if let next = progress.next { continueCard(next) }
                ForEach(Course.stages) { stage in
                    stageSection(stage)
                }
                upcomingSection
                privacyNote
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 24)
            .frame(maxWidth: 640)
            .frame(maxWidth: .infinity)
        }
        .background(Theme.paper.ignoresSafeArea())
        .fullScreenCover(item: $open) { lesson in
            LessonView(lesson: lesson, instrument: instrument, onClose: { open = nil }, onNext: { open = $0 })
                .id(lesson.id)
        }
    }

    private var title: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Clau")
                .font(.system(size: 52, weight: .semibold, design: .serif))
                .foregroundStyle(Theme.ink)
            Text("Piano des de zero, una cosa cada vegada.")
                .font(Theme.serif(.title3))
                .foregroundStyle(Theme.soft)
        }
    }

    /// Amb què es toca: el teclat de la pantalla o un piano de debò.
    private var instrumentPicker: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Amb què toques?")
                .font(Theme.serif(.title3, weight: .semibold))
                .foregroundStyle(Theme.ink)
            HStack(spacing: 10) {
                instrumentOption(.screen, title: "La pantalla", symbol: "iphone")
                instrumentOption(.real, title: "Un piano", symbol: "pianokeys")
            }
            Text(instrument == .screen
                 ? "Toques al teclat dibuixat. Amb el telèfon de costat, les tecles són gairebé tan amples com les d'un piano."
                 : (midi.connected
                    ? "Piano connectat per cable. Clau sap exactament quines tecles toques, també quan en toques dues alhora."
                    : "Posa el telèfon al faristol, amb el volum alt. Clau t'escolta amb el micròfon mentre toques. Si tens un piano digital, el pots connectar amb un cable."))
                .font(.body)
                .lineSpacing(3)
                .foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 18))
    }

    private func instrumentOption(_ option: Instrument, title: String, symbol: String) -> some View {
        let selected = instrument == option
        return Button {
            instrumentName = option.rawValue
        } label: {
            Label(title, systemImage: symbol)
                .font(.body.weight(.semibold))
                .frame(maxWidth: .infinity, minHeight: 48)
                .foregroundStyle(selected ? Theme.card : Theme.ink)
                .background(selected ? Theme.ink : Theme.paper, in: RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.ink.opacity(selected ? 0 : 0.3), lineWidth: 1.5))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func continueCard(_ lesson: Lesson) -> some View {
        Button {
            open = lesson
        } label: {
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(progress.done.isEmpty ? "Comença" : "Continua")
                        .font(.subheadline.weight(.bold))
                        .textCase(.uppercase)
                        .kerning(1.2)
                        .opacity(0.75)
                    Text("\(lesson.number). \(lesson.title)")
                        .font(Theme.serif(.title2, weight: .semibold))
                        .multilineTextAlignment(.leading)
                }
                Spacer()
                Image(systemName: "play.fill").font(.title2)
            }
            .foregroundStyle(Theme.card)
            .padding(20)
            .background(Theme.ink, in: RoundedRectangle(cornerRadius: 20))
        }
        .buttonStyle(.plain)
    }

    private func stageSection(_ stage: Stage) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Etapa \(stage.id) · \(stage.title)")
                    .font(Theme.serif(.title2, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                Text(stage.summary)
                    .font(.body)
                    .foregroundStyle(Theme.soft)
            }
            VStack(spacing: 0) {
                ForEach(Array(stage.lessons.enumerated()), id: \.element.id) { index, lesson in
                    if index > 0 { Divider().overlay(Theme.line).padding(.leading, 58) }
                    lessonRow(lesson)
                }
            }
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 18))
        }
    }

    private func lessonRow(_ lesson: Lesson) -> some View {
        let done = progress.isDone(lesson)
        return Button {
            open = lesson
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(done ? Theme.sage : (lesson.isPiece ? Theme.brass.opacity(0.3) : Theme.paper))
                        .frame(width: 34, height: 34)
                    if done {
                        Image(systemName: "checkmark").font(.subheadline.weight(.bold)).foregroundStyle(Theme.card)
                    } else if lesson.isPiece {
                        Image(systemName: "music.note").font(.subheadline.weight(.bold)).foregroundStyle(Theme.ink)
                    } else {
                        Text("\(lesson.number)").font(.subheadline.weight(.bold)).foregroundStyle(Theme.ink)
                    }
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(lesson.title)
                        .font(Theme.serif(.title3, weight: .semibold))
                        .foregroundStyle(Theme.ink)
                        .multilineTextAlignment(.leading)
                    Text("\(lesson.summary) · \(lesson.minutes) min")
                        .font(.subheadline)
                        .foregroundStyle(Theme.soft)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 13)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Lliçó \(lesson.number), \(lesson.title)\(done ? ", feta" : "")")
    }

    private var upcomingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Més endavant")
                .font(Theme.serif(.title2, weight: .semibold))
                .foregroundStyle(Theme.ink)
            VStack(alignment: .leading, spacing: 12) {
                ForEach(Array(Course.upcoming.enumerated()), id: \.offset) { index, stage in
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Etapa \(index + Course.stages.count + 1) · \(stage.title)")
                            .font(Theme.serif(.headline, weight: .semibold))
                        Text(stage.summary).font(.subheadline)
                    }
                    .foregroundStyle(Theme.soft)
                }
            }
        }
    }

    private var privacyNote: some View {
        Text("Si toques amb un piano de debò, Clau fa servir el micròfon només per saber quina nota toques. No grava res i no envia res enlloc.")
            .font(.footnote)
            .foregroundStyle(Theme.soft)
            .padding(.top, 4)
    }
}
