import SwiftUI

/// Un pentagrama (o dos, per a les dues mans) amb clau i notes, dibuixat a mà perquè es vegi igual a tot arreu.
struct StaffView: View {
    let score: Score
    /// Nota que toca ara (posició dins de `score.tones`).
    var current: Int?
    /// Les notes d'abans d'aquesta posició ja s'han tocat bé.
    var done = 0
    /// Com ha anat cada nota en un ritme.
    var marks: [RhythmJudge.Mark] = []
    /// Quants cops del ritme han passat. Amb `score.counts`, encén els punts de sota les notes.
    var beat: Double?
    /// Distància entre dues ratlles.
    var spacing: CGFloat = 9.5

    /// Cops (o notes, si no hi ha compassos) que caben en un rengle. Amb dues mans, més, perquè cada rengle ocupa el doble d'alçada.
    private var capacity: Double { score.grand ? 16 : 8 }

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

    /// Un pentagrama dins d'un rengle: quina clau porta i on és la seva ratlla de sota.
    private struct Staff {
        let bass: Bool
        let bottom: CGFloat
    }

    private var s: CGFloat { spacing }
    private var topPad: CGFloat { 2.0 * s }
    private var bottomPad: CGFloat { (score.names || score.counts ? 3.9 : 2.8) * s }
    /// Espai entre els dos pentagrames de les dues mans.
    private var gap: CGFloat { 4.2 * s }
    /// Ratlla de sota del pentagrama de més avall.
    private var bottomLine: CGFloat { topPad + 4 * s + (score.grand ? gap + 4 * s : 0) }
    private var systemHeight: CGFloat { bottomLine + bottomPad }

    private var staves: [Staff] {
        if score.grand {
            return [Staff(bass: false, bottom: topPad + 4 * s), Staff(bass: true, bottom: bottomLine)]
        }
        return [Staff(bass: score.bass, bottom: bottomLine)]
    }

    /// Amb dues mans, del do del mig cap amunt va la dreta (clau de sol) i cap avall l'esquerra (clau de fa).
    private func staff(for tone: Tone) -> Staff {
        guard score.grand, !tone.rest else { return staves[0] }
        return tone.midi >= 60 ? staves[0] : staves[1]
    }

    /// Amb compassos o amb punts de cop, cada nota ocupa el que dura; si no, totes igual.
    private func size(of tone: Tone) -> Double { score.bars || score.counts ? tone.beats : 1 }

    /// Fins on s'omple un rengle. Sense compassos, els rengles es reparteixen iguals: millor 5 i 4 que 8 i 1.
    private var rowLimit: Double {
        if score.bars { return capacity }
        let whole = score.tones.reduce(0) { $0 + size(of: $1) }
        let rows = max(1, (whole / capacity).rounded(.up))
        return (whole / rows).rounded(.up)
    }

    private var systems: [System] {
        var result: [System] = []
        var system = System(isFirst: true)
        let limit = rowLimit
        for (index, tone) in score.tones.enumerated() {
            let size = size(of: tone)
            if system.total + size > limit + 0.001, !system.notes.isEmpty {
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
        let name = score.grand ? "Pentagrama de les dues mans" : (score.bass ? "Pentagrama en clau de fa" : "Pentagrama")
        return notes.isEmpty ? name : name + ": " + notes.joined(separator: ", ")
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

    /// Graó de la nota comptant des de la ratlla de sota: 0 és la ratlla, 1 l'espai de sobre…
    /// En clau de sol la ratlla de sota és el mi; en clau de fa, el sol greu.
    private func step(of midi: Int, bass: Bool) -> Int {
        let letters = [0, 0, 1, 1, 2, 3, 3, 4, 4, 5, 5, 6]
        let octave = midi / 12 - 1
        let letter = letters[Music.pitchClass(midi)]
        return bass ? (octave - 2) * 7 + letter - 4 : (octave - 4) * 7 + letter - 2
    }

    private func y(ofStep step: Int, in staff: Staff) -> CGFloat { staff.bottom - CGFloat(step) * s / 2 }

    private func draw(_ system: System, in context: inout GraphicsContext, width: CGFloat) {
        let lineColor = Theme.soft
        var left: CGFloat = 0.4 * s

        // El número de cada ratlla, a la primera lliçó.
        if score.numbered, let only = staves.first {
            for line in 0..<5 {
                let text = Text("\(line + 1)").font(.system(size: 0.95 * s, weight: .bold)).foregroundColor(Theme.brass)
                context.draw(text, at: CGPoint(x: 0.9 * s, y: only.bottom - CGFloat(line) * s))
            }
            left = 2.2 * s
        }
        for staff in staves {
            for line in 0..<5 {
                let lineY = staff.bottom - CGFloat(line) * s
                var path = Path()
                path.move(to: CGPoint(x: left, y: lineY))
                path.addLine(to: CGPoint(x: width - 0.2 * s, y: lineY))
                context.stroke(path, with: .color(lineColor), lineWidth: max(1, s * 0.09))
            }
        }

        if score.grand {
            // La ratlla del començament lliga els dos pentagrames.
            var join = Path()
            join.move(to: CGPoint(x: left, y: topPad))
            join.addLine(to: CGPoint(x: left, y: bottomLine))
            context.stroke(join, with: .color(Theme.ink), lineWidth: max(1.5, s * 0.14))
        }

        if score.clef {
            for staff in staves { drawClef(for: staff, in: &context, x: left + 0.3 * s) }
            left += 3.8 * s
        } else {
            left += 0.8 * s
        }

        if score.bars, system.isFirst {
            for staff in staves {
                for line in [3, 1] {
                    let text = Text("4").font(.system(size: 2.5 * s, weight: .bold, design: .serif)).foregroundColor(Theme.ink)
                    context.draw(text, at: CGPoint(x: left + 0.6 * s, y: staff.bottom - CGFloat(line) * s))
                }
            }
            left += 2.0 * s
        }

        let right = width - 1.0 * s
        let room = max(right - left, 1)
        let total = score.bars ? capacity : max(rowLimit, 5)

        // Amb compassos, cada nota té un mínim d'espai a més del que li toca pel que dura, i abans de cada ratlla de compàs
        // hi ha un marge: si no, en un rengle ple les notes curtes i les ratlles es toquen. El que falta per omplir el rengle
        // compta com si fossin negres. Sense compassos, el repartiment de sempre.
        let perNote: CGFloat = score.bars ? 0.8 * s : 0
        let barPad: CGFloat = score.bars ? 0.9 * s : 0
        let quarters = max(0, total - system.total)
        let bars = score.bars ? max(0, Int((total / 4).rounded(.up)) - 1) : 0
        let beatWidth = max(room - CGFloat(Double(system.notes.count) + quarters) * perNote - CGFloat(bars) * barPad, room * 0.3) / CGFloat(total)
        /// On comença el cop `beat` dins del rengle. Si hi cau una ratlla de compàs, ja és després del seu marge.
        func xAt(_ beat: Double) -> CGFloat {
            let notesBefore = system.notes.filter { $0.start < beat - 0.001 }.count
            let past = max(0, beat - system.total)
            let crossed = score.bars ? min(Int(((beat + 0.001) / 4).rounded(.down)), bars) : 0
            return left + CGFloat(beat) * beatWidth + CGFloat(Double(notesBefore) + past) * perNote + CGFloat(crossed) * barPad
        }

        for note in system.notes {
            let start = xAt(note.start)
            let slot = CGFloat(note.size) * beatWidth + perNote
            let offset = min(slot * 0.42, 1.7 * s)
            let x = start + (score.bars ? max(offset, 0.85 * s) : offset)
            let tint = color(for: note.index)
            let home = staff(for: note.tone)

            if score.bars, note.start > 0, note.start.truncatingRemainder(dividingBy: 4) == 0 {
                barline(in: &context, x: start - barPad / 2 - 0.1 * s, width: max(1, s * 0.11))
            }

            if note.tone.rest {
                drawRest(note.tone.beats, in: &context, x: x, color: tint, staff: home)
            } else {
                if note.index == current {
                    let center = y(ofStep: step(of: note.tone.midi, bass: home.bass), in: home)
                    let halo = CGRect(x: x - 1.5 * s, y: center - 1.5 * s, width: 3 * s, height: 3 * s)
                    context.fill(Path(ellipseIn: halo), with: .color(Theme.brass.opacity(0.22)))
                }
                drawNote(note.tone, in: &context, x: x, color: tint, staff: home)
            }

            var caption: String?
            if score.names, !note.tone.rest { caption = Music.name(note.tone.midi) }
            if score.counts {
                drawPips(for: note.index, in: &context, x: x)
            } else if let caption {
                let text = Text(caption).font(.system(size: 1.3 * s, weight: .semibold)).foregroundColor(tint == Theme.ink ? Theme.soft : tint)
                context.draw(text, at: CGPoint(x: x, y: bottomLine + 2.9 * s))
            }
        }

        if score.grand, score.bars {
            // Els compassos on una mà no toca porten un silenci sencer.
            var bar = 0.0
            while bar < system.total - 0.001 {
                let inBar = system.notes.filter { $0.start >= bar - 0.001 && $0.start < bar + 4 - 0.001 && !$0.tone.rest }
                for staff in staves where !inBar.contains(where: { self.staff(for: $0.tone).bass == staff.bass }) {
                    drawRest(4, in: &context, x: (xAt(bar) + xAt(min(bar + 4, total)) - barPad) / 2, color: Theme.ink, staff: staff)
                }
                bar += 4
            }
        }

        if score.bars, !system.notes.isEmpty {
            // Al final d'un rengle curt no hi ha ratlla de compàs entremig: el marge sobra.
            let onBar = system.total < total - 0.001 && system.total.truncatingRemainder(dividingBy: 4) < 0.001
            let end = xAt(system.total) - (onBar ? barPad : 0)
            if system.isLast, score.ends || score.repeats {
                barline(in: &context, x: end - 0.55 * s, width: max(1, s * 0.11))
                barline(in: &context, x: end, width: s * 0.38)
                if score.repeats {
                    // Els dos punts de la repetició, als dos espais del mig de cada pentagrama.
                    for staff in staves {
                        for step in [3, 5] {
                            let dot = CGRect(x: end - 1.25 * s, y: y(ofStep: step, in: staff) - 0.22 * s, width: 0.44 * s, height: 0.44 * s)
                            context.fill(Path(ellipseIn: dot), with: .color(Theme.ink))
                        }
                    }
                }
            } else {
                barline(in: &context, x: end, width: max(1, s * 0.11))
            }
        }
    }

    /// Un punt gran per cada cop sencer que dura la nota, i un de petit per al mig cop
    /// (la negra amb punt: un de gran i un de petit). S'omplen a mesura que passa el pols.
    private func drawPips(for index: Int, in context: inout GraphicsContext, x: CGFloat) {
        let tone = score.tones[index]
        let start = score.tones.prefix(index).reduce(0) { $0 + $1.beats }
        let whole = Int(tone.beats + 0.001)
        let pips = tone.beats - Double(whole) > 0.01 ? whole + 1 : max(whole, 1)
        let gap = 0.85 * s
        let y = bottomLine + 2.9 * s
        let first = x - CGFloat(pips - 1) * gap / 2
        let total = score.tones.reduce(0) { $0 + $1.beats }
        // Si el ritme repeteix la partitura, es torna a començar.
        let now = beat.map { total > 0 ? $0.truncatingRemainder(dividingBy: total) : $0 }

        for pip in 0..<pips {
            let radius = (pip < whole ? 0.3 : 0.2) * s
            let rect = CGRect(x: first + CGFloat(pip) * gap - radius, y: y - radius, width: 2 * radius, height: 2 * radius)
            let path = Path(ellipseIn: rect)
            if let now, now >= start + Double(pip), now < start + tone.beats {
                // El cop que sona ara, i els que ja han passat dins d'aquesta nota.
                context.fill(path, with: .color(Theme.brass))
            } else if let now, now >= start + tone.beats {
                context.fill(path, with: .color(Theme.soft))
            } else {
                context.stroke(path, with: .color(Theme.soft), lineWidth: max(1, s * 0.11))
            }
        }
    }

    private func barline(in context: inout GraphicsContext, x: CGFloat, width: CGFloat) {
        var path = Path()
        path.move(to: CGPoint(x: x, y: topPad))
        path.addLine(to: CGPoint(x: x, y: bottomLine))
        context.stroke(path, with: .color(Theme.ink), lineWidth: width)
    }

    /// Les claus surten de la lletra «Apple Symbols» del sistema, centrades sobre la seva ratlla:
    /// la clau de sol envolta la segona ratlla (el sol) i la de fa, la quarta (el fa).
    private func drawClef(for staff: Staff, in context: inout GraphicsContext, x: CGFloat) {
        let fontSize = s * (staff.bass ? 5.2 : 9.1)
        let symbol = staff.bass ? "\u{1D122}" : "\u{1D11E}"
        let text = context.resolve(Text(symbol).font(.custom("Apple Symbols", size: fontSize)).foregroundColor(Theme.ink))
        let box = CGSize(width: fontSize * 2, height: fontSize * 3)
        let baseline = text.firstBaseline(in: box)
        // Alçada, sobre la línia de base de la lletra, del centre de la ratlla que envolta la clau.
        let centerLine = staff.bass ? staff.bottom - 3 * s : staff.bottom - s
        let rise = (staff.bass ? 0.454 : 0.19) * fontSize
        context.draw(text, at: CGPoint(x: x, y: centerLine + rise - baseline), anchor: .topLeading)
    }

    private func drawNote(_ tone: Tone, in context: inout GraphicsContext, x: CGFloat, color: Color, staff: Staff) {
        let position = step(of: tone.midi, bass: staff.bass)
        let centerY = y(ofStep: position, in: staff)
        let rx = 0.64 * s, ry = 0.44 * s

        // Fora de les cinc ratlles, la nota porta ratlletes pròpies.
        var ledgers: [Int] = []
        if position <= -2 { ledgers = Array(stride(from: -2, through: position, by: -2)) }
        if position >= 10 { ledgers = Array(stride(from: 10, through: position, by: 2)) }
        for ledger in ledgers {
            var path = Path()
            let ledgerY = y(ofStep: ledger, in: staff)
            path.move(to: CGPoint(x: x - 0.95 * s, y: ledgerY))
            path.addLine(to: CGPoint(x: x + 0.95 * s, y: ledgerY))
            context.stroke(path, with: .color(Theme.soft), lineWidth: max(1, s * 0.09))
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
            // De la ratlla del mig cap amunt, el pal va avall i a l'esquerra, com s'escriu.
            let down = position >= 4
            let direction: CGFloat = down ? 1 : -1
            let stemX = down ? x - rx * 0.93 : x + rx * 0.93
            let tip = centerY + direction * 3.2 * s
            var stem = Path()
            stem.move(to: CGPoint(x: stemX, y: centerY + direction * 0.12 * s))
            stem.addLine(to: CGPoint(x: stemX, y: tip))
            context.stroke(stem, with: .color(color), lineWidth: max(1, s * 0.13))

            if tone.beats < 1 {
                var flag = Path()
                flag.move(to: CGPoint(x: stemX, y: tip))
                flag.addCurve(to: CGPoint(x: stemX + 0.75 * s, y: tip - direction * 2.0 * s),
                              control1: CGPoint(x: stemX + 0.1 * s, y: tip - direction * 0.9 * s),
                              control2: CGPoint(x: stemX + 1.25 * s, y: tip - direction * 1.0 * s))
                context.stroke(flag, with: .color(color), style: StrokeStyle(lineWidth: s * 0.22, lineCap: .round))
            }
        }

        if tone.beats == 1.5 || tone.beats == 3 {
            let onLine = position % 2 == 0
            let dot = CGRect(x: x + rx + 0.35 * s, y: centerY - 0.17 * s - (onLine ? 0.25 * s : 0), width: 0.34 * s, height: 0.34 * s)
            context.fill(Path(ellipseIn: dot), with: .color(color))
        }
    }

    private func drawRest(_ beats: Double, in context: inout GraphicsContext, x: CGFloat, color: Color, staff: Staff) {
        let middle = staff.bottom - 2 * s
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
