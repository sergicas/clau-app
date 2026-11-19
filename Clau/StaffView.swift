import SwiftUI

/// Un pentagrama amb clau de sol i notes, dibuixat a mà perquè es vegi igual a tot arreu.
struct StaffView: View {
    let score: Score
    /// Nota que toca ara (posició dins de `score.tones`).
    var current: Int?
    /// Les notes d'abans d'aquesta posició ja s'han tocat bé.
    var done = 0
    /// Com ha anat cada nota en un ritme.
    var marks: [RhythmJudge.Mark] = []
    /// Distància entre dues ratlles.
    var spacing: CGFloat = 9.5

    /// Cops (o notes, si no hi ha compassos) que caben en un rengle.
    private let capacity = 8.0

    private struct Placed {
        let index: Int
        let tone: Tone
        /// On comença dins del rengle, en cops o en notes.
        let start: Double
        let size: Double
    }

    private struct System {
        var notes: [Placed] = []
        var total = 0.0
        var isFirst = false
        var isLast = false
    }

    private var s: CGFloat { spacing }
    private var topPad: CGFloat { 2.0 * s }
    private var bottomPad: CGFloat { (score.names || score.counts ? 3.9 : 2.2) * s }
    private var systemHeight: CGFloat { topPad + 4 * s + bottomPad }
    private var bottomLine: CGFloat { topPad + 4 * s }

    private var systems: [System] {
        var result: [System] = []
        var system = System(isFirst: true)
        for (index, tone) in score.tones.enumerated() {
            let size = score.bars ? tone.beats : 1
            if system.total + size > capacity + 0.001, !system.notes.isEmpty {
                result.append(system)
                system = System()
            }
            system.notes.append(Placed(index: index, tone: tone, start: system.total, size: size))
            system.total += size
        }
        system.isLast = true
        result.append(system)
        return result
    }

    var body: some View {
        VStack(spacing: 2) {
            ForEach(Array(systems.enumerated()), id: \.offset) { _, system in
                Canvas { context, size in
                    draw(system, in: &context, width: size.width)
                }
                .frame(height: systemHeight)
            }
        }
        .accessibilityElement()
        .accessibilityLabel(accessibilityText)
        .accessibilityIdentifier("pentagrama")
    }

    private var accessibilityText: String {
        let notes = score.tones.map { $0.rest ? "silenci" : Music.name($0.midi) }
        return notes.isEmpty ? "Pentagrama" : "Pentagrama: " + notes.joined(separator: ", ")
    }

    // MARK: Colors

    private func color(for index: Int) -> Color {
        if index < marks.count {
            switch marks[index] {
            case .hit: return Theme.sage
            case .wrong, .missed: return Theme.terra
            case .pending: break
            }
        }
        if index == current { return Theme.brass }
        if index < done { return Theme.sage }
        return Theme.ink
    }

    // MARK: Dibuix

    /// Graó de la nota comptant des de la primera ratlla (mi): 0 és la ratlla, 1 l'espai de sobre…
    private func step(of midi: Int) -> Int {
        let letters = [0, 0, 1, 1, 2, 3, 3, 4, 4, 5, 5, 6]
        let octave = midi / 12 - 1
        return (octave - 4) * 7 + letters[Music.pitchClass(midi)] - 2
    }

    private func y(ofStep step: Int) -> CGFloat { bottomLine - CGFloat(step) * s / 2 }

    private func draw(_ system: System, in context: inout GraphicsContext, width: CGFloat) {
        let lineColor = Theme.soft
        var left: CGFloat = 0.4 * s

        // Les cinc ratlles, i el número de cadascuna a la primera lliçó.
        if score.numbered {
            for line in 0..<5 {
                let text = Text("\(line + 1)").font(.system(size: 0.95 * s, weight: .bold)).foregroundColor(Theme.brass)
                context.draw(text, at: CGPoint(x: 0.9 * s, y: bottomLine - CGFloat(line) * s))
            }
            left = 2.2 * s
        }
        for line in 0..<5 {
            let lineY = bottomLine - CGFloat(line) * s
            var path = Path()
            path.move(to: CGPoint(x: left, y: lineY))
            path.addLine(to: CGPoint(x: width - 0.2 * s, y: lineY))
            context.stroke(path, with: .color(lineColor), lineWidth: max(1, s * 0.09))
        }

        if score.clef {
            drawClef(in: &context, x: left + 0.3 * s)
            left += 3.5 * s
        } else {
            left += 0.8 * s
        }

        if score.bars, system.isFirst {
            for (number, line) in [(4, 3), (4, 1)] {
                let text = Text("\(number)").font(.system(size: 2.5 * s, weight: .bold, design: .serif)).foregroundColor(Theme.ink)
                context.draw(text, at: CGPoint(x: left + 0.6 * s, y: bottomLine - CGFloat(line) * s))
            }
            left += 2.0 * s
        }

        let right = width - 1.0 * s
        let room = max(right - left, 1)
        let total = score.bars ? capacity : max(system.total, 5)

        for note in system.notes {
            let slot = CGFloat(note.size / total) * room
            let x = left + CGFloat(note.start / total) * room + min(slot * 0.5, 1.7 * s)
            let tint = color(for: note.index)

            if score.bars, note.start > 0, note.start.truncatingRemainder(dividingBy: 4) == 0 {
                barline(in: &context, x: left + CGFloat(note.start / total) * room - 0.1 * s, width: max(1, s * 0.11))
            }

            if note.tone.rest {
                drawRest(note.tone.beats, in: &context, x: x, color: tint)
            } else {
                if note.index == current {
                    let halo = CGRect(x: x - 1.5 * s, y: y(ofStep: step(of: note.tone.midi)) - 1.5 * s, width: 3 * s, height: 3 * s)
                    context.fill(Path(ellipseIn: halo), with: .color(Theme.brass.opacity(0.22)))
                }
                drawNote(note.tone, in: &context, x: x, color: tint)
            }

            var caption: String?
            if score.names, !note.tone.rest { caption = Music.name(note.tone.midi) }
            if score.counts { caption = note.tone.beats == 0.5 ? "½" : String(Int(note.tone.beats)) }
            if let caption {
                let text = Text(caption).font(.system(size: 1.3 * s, weight: .semibold)).foregroundColor(tint == Theme.ink ? Theme.soft : tint)
                context.draw(text, at: CGPoint(x: x, y: bottomLine + 2.9 * s))
            }
        }

        if score.bars, !system.notes.isEmpty {
            let end = left + CGFloat(system.total / total) * room
            if system.isLast {
                barline(in: &context, x: end - 0.55 * s, width: max(1, s * 0.11))
                barline(in: &context, x: end, width: s * 0.38)
            } else {
                barline(in: &context, x: end, width: max(1, s * 0.11))
            }
        }
    }

    private func barline(in context: inout GraphicsContext, x: CGFloat, width: CGFloat) {
        var path = Path()
        path.move(to: CGPoint(x: x, y: bottomLine - 4 * s))
        path.addLine(to: CGPoint(x: x, y: bottomLine))
        context.stroke(path, with: .color(Theme.ink), lineWidth: width)
    }

    /// La clau de sol surt de la lletra «Apple Symbols». El cargol queda centrat a la segona ratlla.
    private func drawClef(in context: inout GraphicsContext, x: CGFloat) {
        let fontSize = s * 9.1
        let text = context.resolve(Text("\u{1D11E}").font(.custom("Apple Symbols", size: fontSize)).foregroundColor(Theme.ink))
        let box = CGSize(width: fontSize * 2, height: fontSize * 3)
        let baseline = text.firstBaseline(in: box)
        // El centre del cargol és 0,19 vegades la mida de la lletra per sobre de la línia de base.
        let baselineY = (bottomLine - s) + 0.19 * fontSize
        context.draw(text, at: CGPoint(x: x, y: baselineY - baseline), anchor: .topLeading)
    }

    private func drawNote(_ tone: Tone, in context: inout GraphicsContext, x: CGFloat, color: Color) {
        let position = step(of: tone.midi)
        let centerY = y(ofStep: position)
        let rx = 0.64 * s, ry = 0.44 * s

        // El do del mig porta una ratlleta pròpia.
        if position <= -2 {
            var ledger = Path()
            ledger.move(to: CGPoint(x: x - 1.1 * s, y: y(ofStep: -2)))
            ledger.addLine(to: CGPoint(x: x + 1.1 * s, y: y(ofStep: -2)))
            context.stroke(ledger, with: .color(Theme.soft), lineWidth: max(1, s * 0.09))
        }

        let transform = CGAffineTransform(translationX: x, y: centerY).rotated(by: -0.38)
        let head = Path(ellipseIn: CGRect(x: -rx, y: -ry, width: 2 * rx, height: 2 * ry)).applying(transform)
        if tone.beats >= 2 {
            let inner = Path(ellipseIn: CGRect(x: -rx * 0.74, y: -ry * 0.52, width: 2 * rx * 0.74, height: 2 * ry * 0.52)).applying(transform)
            context.fill(head.subtracting(inner), with: .color(color))
        } else {
            context.fill(head, with: .color(color))
        }

        if tone.beats < 4 {
            let stemX = x + rx * 0.93
            let top = centerY - 3.2 * s
            var stem = Path()
            stem.move(to: CGPoint(x: stemX, y: centerY - 0.12 * s))
            stem.addLine(to: CGPoint(x: stemX, y: top))
            context.stroke(stem, with: .color(color), lineWidth: max(1, s * 0.13))

            if tone.beats < 1 {
                var flag = Path()
                flag.move(to: CGPoint(x: stemX, y: top))
                flag.addCurve(to: CGPoint(x: stemX + 0.75 * s, y: top + 2.0 * s),
                              control1: CGPoint(x: stemX + 0.1 * s, y: top + 0.9 * s),
                              control2: CGPoint(x: stemX + 1.25 * s, y: top + 1.0 * s))
                context.stroke(flag, with: .color(color), style: StrokeStyle(lineWidth: s * 0.22, lineCap: .round))
            }
        }

        if tone.beats == 1.5 || tone.beats == 3 {
            let onLine = position % 2 == 0
            let dot = CGRect(x: x + rx + 0.35 * s, y: centerY - 0.17 * s - (onLine ? 0.25 * s : 0), width: 0.34 * s, height: 0.34 * s)
            context.fill(Path(ellipseIn: dot), with: .color(color))
        }
    }

    private func drawRest(_ beats: Double, in context: inout GraphicsContext, x: CGFloat, color: Color) {
        let middle = bottomLine - 2 * s
        if beats >= 4 {
            context.fill(Path(CGRect(x: x - 0.65 * s, y: middle - s, width: 1.3 * s, height: 0.5 * s)), with: .color(color))
        } else if beats >= 2 {
            context.fill(Path(CGRect(x: x - 0.65 * s, y: middle - 0.5 * s, width: 1.3 * s, height: 0.5 * s)), with: .color(color))
        } else {
            // El silenci d'un cop: una ziga-zaga amb una cua.
            var path = Path()
            path.move(to: CGPoint(x: x - 0.25 * s, y: middle - 1.35 * s))
            path.addLine(to: CGPoint(x: x + 0.32 * s, y: middle - 0.55 * s))
            path.addLine(to: CGPoint(x: x - 0.22 * s, y: middle + 0.05 * s))
            path.addLine(to: CGPoint(x: x + 0.35 * s, y: middle + 0.7 * s))
            path.addQuadCurve(to: CGPoint(x: x + 0.05 * s, y: middle + 1.4 * s), control: CGPoint(x: x - 0.75 * s, y: middle + 0.55 * s))
            context.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: s * 0.3, lineCap: .round, lineJoin: .round))
        }
    }
}
