import Foundation

/// Mira si un ritme s'ha tocat a temps. Càlcul pur (només Foundation), perquè es pugui
/// provar al Mac: `proves/prova.sh`. Els temps són segons des del primer cop del ritme.
struct RhythmJudge {
    enum Mark: Equatable { case pending, hit, wrong, missed }

    private struct Note {
        let time: Double
        let beats: Double
        let pitchClass: Int
        /// Posició dins la llista de `tones`, comptant-hi els silencis.
        let toneIndex: Int
    }

    /// Fins a quants segons abans o després del moment just encara compta.
    let tolerance: Double
    /// Quant dura tot el ritme, amb l'última nota sencera.
    let length: Double

    private let notes: [Note]
    private let beat: Double
    private let toneCount: Int
    private let hasRests: Bool
    private var marks: [Mark]

    private var extras = 0
    private var early = 0
    private var late = 0
    private var strays = 0
    private var firstWrong: (heard: Int, wanted: Int)?
    /// Tot el que s'ha tocat, per poder explicar què ha passat.
    private var presses: [(midi: Int, time: Double, result: String)] = []
    /// La primera nota llarga que no s'ha esperat prou: quina és i quants cops dura.
    private var cutShort: (note: Int, beats: Double)?
    /// Notes que s'han tocat amb la tecla bona però a deshora.
    private var offTime: Set<Int> = []
    /// D'aquestes, les que s'han tocat abans d'hora: encara es poden tocar bé al seu moment.
    private var earlyClaims: Set<Int> = []
    /// Tecles equivocades seguides que són la de la nota de després (o la d'abans): qui s'ha perdut a la partitura.
    private var aheadRun = 0
    private var behindRun = 0
    private var lostAhead = false
    private var lostBehind = false
    /// On ha començat la tira que ha fet dir que anava per davant: si abans ja havia escurçat una nota llarga, és això el que cal dir.
    private var lostAheadFrom: Int?
    private var lostBehindFrom: Int?
    /// Quantes tecles equivocades s'expliquen per cada causa. Qui té la mà desplaçada una tecla toca, en una melodia que puja
    /// per graus, la tecla de la nota següent sense haver-se perdut: només es diu «per davant» si ho explica més que la mà.
    private var aheadKeys = 0
    private var behindKeys = 0
    private var upKeys = 0
    private var downKeys = 0

    /// `slack` afegeix marge, per quan les notes arriben pel micròfon.
    init(tones: [Tone], beat: Double, slack: Double = 0) {
        var time = 0.0
        var notes: [Note] = []
        for (index, tone) in tones.enumerated() {
            if !tone.rest {
                notes.append(Note(time: time, beats: tone.beats, pitchClass: Music.pitchClass(tone.midi), toneIndex: index))
            }
            time += tone.beats * beat
        }
        var gap = beat
        for (current, next) in zip(notes, notes.dropFirst()) { gap = min(gap, next.time - current.time) }

        self.notes = notes
        self.beat = beat
        length = time
        toneCount = tones.count
        hasRests = tones.contains(where: \.rest)
        // Ample per a qui comença, però mai tant que dues notes seguides es confonguin.
        tolerance = max(0.12, min(0.30 * beat, 0.45 * gap)) + slack
        marks = Array(repeating: .pending, count: notes.count)
    }

    /// S'ha tocat una nota. Retorna si ha comptat per a alguna de les que s'esperaven.
    @discardableResult
    mutating func heard(midi: Int, at time: Double) -> Mark? {
        close(upTo: time)
        let pitchClass = Music.pitchClass(midi)

        // Una nota que s'havia tocat massa aviat i ara es toca al seu moment: compta bé, i el toc d'abans queda com a toc de més.
        if let index = earlyClaims.first(where: { abs(time - notes[$0].time) <= tolerance && notes[$0].pitchClass == pitchClass }) {
            earlyClaims.remove(index)
            offTime.remove(index)
            marks[index] = .hit
            early -= 1
            extras += 1
            presses.append((midi, time, "nota \(index + 1)"))
            return .hit
        }

        // La nota esperada més propera que encara no s'ha tocat.
        var nearest: Int?
        var distance = Double.infinity
        for index in notes.indices where isOpen(index) {
            let gap = abs(time - notes[index].time)
            if gap < distance {
                nearest = index
                distance = gap
            }
        }

        guard let index = nearest else {
            extras += 1
            strays += 1
            presses.append((midi, time, "de més"))
            return nil
        }

        if marks[index] == .pending, distance <= tolerance {
            if pitchClass == notes[index].pitchClass {
                marks[index] = .hit
                aheadRun = 0
                behindRun = 0
                presses.append((midi, time, "nota \(index + 1)"))
                return .hit
            }
            // És la tecla d'una nota d'abans que encara no ha sonat: va endarrerit, no s'ha equivocat de tecla.
            // La de la nota següent no compta així: quan cau just al cop, el més normal és haver relliscat a la tecla del costat.
            if let neighbour = neighbour(of: index, pitchClass: pitchClass, at: time, behindOnly: true) {
                playedOffTime(neighbour, midi: midi, at: time)
                return nil
            }
            marks[index] = .wrong
            if firstWrong == nil { firstWrong = (midi, notes[index].pitchClass) }
            // Tres o més seguides amb la tecla de la nota següent (o de l'anterior): no és una relliscada, és que s'ha perdut.
            let next = index + 1 < notes.count && notes[index + 1].pitchClass == pitchClass
            let previous = index > 0 && notes[index - 1].pitchClass == pitchClass
            aheadRun = next ? aheadRun + 1 : 0
            behindRun = previous ? behindRun + 1 : 0
            if next { aheadKeys += 1 }
            if previous { behindKeys += 1 }
            if pitchClass == Self.whiteKey(from: notes[index].pitchClass, step: 1) { upKeys += 1 }
            if pitchClass == Self.whiteKey(from: notes[index].pitchClass, step: -1) { downKeys += 1 }
            if aheadRun >= 3, !lostAhead { lostAhead = true; lostAheadFrom = index - 2 }
            if behindRun >= 3, !lostBehind { lostBehind = true; lostBehindFrom = index - 2 }
            presses.append((midi, time, "nota \(index + 1), tecla equivocada"))
            return .wrong
        }

        // Fora del marge. Si és la tecla d'aquesta nota (o de la del costat) i no queda lluny, és aquella nota tocada a deshora:
        // compta com un sol error, no com una nota perduda més un toc de més.
        if distance < beat, pitchClass == notes[index].pitchClass {
            playedOffTime(index, midi: midi, at: time)
            return nil
        }
        if let neighbour = neighbour(of: index, pitchClass: pitchClass, at: time) {
            playedOffTime(neighbour, midi: midi, at: time)
            return nil
        }

        presses.append((midi, time, "fora de temps, a prop de la nota \(index + 1)"))
        // Si la nota d'abans era llarga i s'ha tocat la següent abans d'hora, és que no s'ha esperat.
        if cutShort == nil, time < notes[index].time, index > 0, notes[index - 1].beats >= 2,
           marks[index - 1] == .hit || offTime.contains(index - 1) {
            cutShort = (index, notes[index - 1].beats)
        }
        extras += 1
        if distance < 0.5 * beat {
            if time < notes[index].time { early += 1 } else { late += 1 }
        } else {
            strays += 1
        }
        return nil
    }

    /// La tecla blanca del costat (amunt o avall) d'una nota blanca; nil si la nota és negra.
    private static func whiteKey(from pitchClass: Int, step: Int) -> Int? {
        let white = [0, 2, 4, 5, 7, 9, 11]
        guard let position = white.firstIndex(of: pitchClass) else { return nil }
        return white[(position + step + white.count) % white.count]
    }

    /// Una nota que encara es pot tocar: no ha sonat, o s'ha donat per perduda però ningú l'ha tocat a deshora.
    private func isOpen(_ index: Int) -> Bool {
        marks[index] == .pending || (marks[index] == .missed && !offTime.contains(index))
    }

    /// Una nota de prop (fins a dues abans o després), si és d'aquesta tecla i encara es pot tocar: qui va avançat o endarrerit
    /// dins de la melodia. Com a molt, a la distància que hi ha entre les dues notes, i mai més de dos cops (més el marge):
    /// una nota tocada quatre cops tard no és aquella nota. Primer les més properes.
    private func neighbour(of index: Int, pitchClass: Int, at time: Double, behindOnly: Bool = false) -> Int? {
        (behindOnly ? [index - 1, index - 2] : [index - 1, index + 1, index - 2, index + 2]).first { other in
            notes.indices.contains(other) && isOpen(other) && notes[other].pitchClass == pitchClass
                && abs(time - notes[other].time) <= min(abs(notes[other].time - notes[index].time), 2 * beat) + tolerance
        }
    }

    /// La tecla bona, però a deshora: la nota queda fallada i es recorda si anava avançat o endarrerit.
    private mutating func playedOffTime(_ index: Int, midi: Int, at time: Double) {
        marks[index] = .missed
        offTime.insert(index)
        let ahead = time < notes[index].time
        if ahead { early += 1; earlyClaims.insert(index) } else { late += 1 }
        presses.append((midi, time, "nota \(index + 1), \(ahead ? "abans" : "després") d'hora"))
        // Si la nota d'abans era llarga i aquesta ha arribat abans d'hora, és que no s'ha esperat.
        if cutShort == nil, ahead, index > 0, notes[index - 1].beats >= 2,
           marks[index - 1] == .hit || offTime.contains(index - 1) {
            cutShort = (index, notes[index - 1].beats)
        }
    }

    /// Dona per perdudes les notes que ja haurien d'haver sonat.
    mutating func close(upTo time: Double) {
        for index in notes.indices where marks[index] == .pending && notes[index].time + tolerance < time {
            marks[index] = .missed
        }
    }

    /// Una marca per cada element de `tones`; els silencis queden sempre pendents.
    var toneMarks: [Mark] {
        var result = Array(repeating: Mark.pending, count: toneCount)
        for (index, note) in notes.enumerated() { result[note.toneIndex] = marks[index] }
        return result
    }

    /// Posició, dins de `tones`, de la propera nota que cal tocar.
    var nextToneIndex: Int? {
        marks.firstIndex(of: .pending).map { notes[$0].toneIndex }
    }

    private var missed: Int { marks.filter { $0 == .missed }.count }
    private var wrong: Int { marks.filter { $0 == .wrong }.count }

    var errors: Int { missed + wrong + extras }

    /// En un ritme curt han de sortir totes; en un de llarg es perdona una nota de cada vuit.
    var passed: Bool { errors <= notes.count / 8 }

    /// Si s'han tocat totes les notes amb el ritme bo però totes desplaçades igual, quant (en cops).
    private var wholeShift: Double? {
        guard presses.count == notes.count, notes.count > 1 else { return nil }
        let shifts = zip(presses, notes).map { $0.time - $1.time }
        let mean = shifts.reduce(0, +) / Double(shifts.count)
        guard abs(mean) > 0.5 * beat, shifts.allSatisfy({ abs($0 - mean) <= tolerance }) else { return nil }
        return mean / beat
    }

    /// Si s'han tocat les notes seguides, però a un tempo propi diferent del pols: quant més llarg és cada cop (1,1 = un 10 % més lent).
    /// Ha de passar a gairebé tots els intervals: escurçar una sola blanca no és portar un altre tempo.
    var ownTempo: Double? {
        let count = min(presses.count, notes.count)
        guard count >= 5, abs(presses.count - notes.count) <= 1 else { return nil }
        var ratios: [Double] = []
        for i in 1..<count {
            let wanted = notes[i].time - notes[i - 1].time
            let played = presses[i].time - presses[i - 1].time
            if wanted > 0 { ratios.append(played / wanted) }
        }
        guard ratios.count >= 4 else { return nil }
        let median = ratios.sorted()[ratios.count / 2]
        guard abs(median - 1) > 0.08 else { return nil }
        let sameSide = ratios.filter { median > 1 ? $0 > 1.04 : $0 < 0.96 }.count
        guard Double(sameSide) >= 0.7 * Double(ratios.count) else { return nil }
        return median
    }

    /// Per al registre: què s'esperava i què s'ha tocat, amb els temps en segons.
    var report: String {
        let wanted = notes.enumerated().map { "\($0 + 1):\(Music.names[$1.pitchClass])@\(String(format: "%.2f", $1.time))" }.joined(separator: " ")
        let played = presses.map { "\(Music.name($0.midi))@\(String(format: "%.2f", $0.time)) (\($0.result))" }.joined(separator: "; ")
        return "cop=\(String(format: "%.3f", beat)) marge=\(String(format: "%.3f", tolerance))\n  esperat: \(wanted)\n  tocat: \(played.isEmpty ? "res" : played)\n  \(passed ? "BÉ" : "MAL: " + verdict)"
    }

    /// Què ha fallat, dit en una frase.
    var verdict: String {
        if missed == notes.count, extras == 0, wrong == 0, offTime.isEmpty {
            return "No he sentit cap nota. Entra just després dels quatre cops."
        }
        if let shift = wholeShift {
            return shift < 0
                ? "El ritme és bo, però has entrat abans d'hora. Espera que acabin els quatre cops."
                : "El ritme és bo, però has entrat tard. La primera nota va just després dels quatre cops."
        }
        if let ratio = ownTempo {
            return ratio < 1
                ? "Vas més de pressa que el pols. Segueix el pols: cada nota just quan toca el cop."
                : "Vas més a poc a poc que el pols. Segueix el pols: cada nota just quan toca el cop."
        }
        // La mà desplaçada fa equivocar gairebé totes les notes, i sempre per la tecla del costat cap al mateix cantó.
        let handKeys = max(upKeys, downKeys)
        // Amb una sola nota repetida, «has tocat re on anava do» diu més: quina és la tecla bona.
        let melody = Set(notes.map(\.pitchClass)).count >= 3
        if melody, handKeys >= 3, 2 * handKeys >= notes.count, handKeys > aheadKeys, handKeys > behindKeys {
            return upKeys > downKeys
                ? "Toques cada nota una tecla més amunt. Mira on ha d'anar la mà i torna-hi."
                : "Toques cada nota una tecla més avall. Mira on ha d'anar la mà i torna-hi."
        }
        // Si abans de perdre's ja havia escurçat una nota llarga, el que cal corregir és la nota llarga.
        let cutFirst = cutShort.map { cut in lostAheadFrom.map { cut.note <= $0 } ?? false } ?? false
        if lostAhead, !cutFirst {
            return "Vas una nota per davant de la partitura. Toca la nota que s'encén, just amb el cop."
        }
        let cutBeforeBehind = cutShort.map { cut in lostBehindFrom.map { cut.note <= $0 } ?? false } ?? false
        if lostBehind, !cutBeforeBehind {
            return "Vas una nota endarrerit. Toca la nota que s'encén, just amb el cop."
        }
        if let cutShort {
            let beats = Int(cutShort.beats)
            return "La nota \(cutShort.note) dura \(beats) cops. Aguanta-la fins que hagin passat tots \(beats) i llavors toca la següent."
        }
        if let firstWrong {
            return "Has tocat \(Music.names[Music.pitchClass(firstWrong.heard)]) on anava \(Music.names[firstWrong.wanted])."
        }
        if early > 0, early >= late { return "Vas avançat. Espera el cop abans de tocar." }
        if late > 0 { return "Vas tard. Toca just quan sona el cop." }
        if strays > 0, hasRests { return "Has tocat durant un silenci. Allà no es toca." }
        if missed > 0 { return "T'has deixat alguna nota." }
        return "Hi ha hagut notes de més."
    }
}
