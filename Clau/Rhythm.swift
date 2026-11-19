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

        // La nota esperada més propera que encara no s'ha encertat.
        var nearest: Int?
        var distance = Double.infinity
        for index in notes.indices where marks[index] == .pending || marks[index] == .missed {
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
            if Music.pitchClass(midi) == notes[index].pitchClass {
                marks[index] = .hit
            } else {
                marks[index] = .wrong
                if firstWrong == nil { firstWrong = (midi, notes[index].pitchClass) }
            }
            presses.append((midi, time, marks[index] == .hit ? "nota \(index + 1)" : "nota \(index + 1), tecla equivocada"))
            return marks[index]
        }

        presses.append((midi, time, "fora de temps, a prop de la nota \(index + 1)"))
        // Si la nota d'abans era llarga i s'ha tocat la següent abans d'hora, és que no s'ha esperat.
        if cutShort == nil, time < notes[index].time, index > 0, notes[index - 1].beats >= 2, marks[index - 1] == .hit {
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

    /// Per al registre: què s'esperava i què s'ha tocat, amb els temps en segons.
    var report: String {
        let wanted = notes.enumerated().map { "\($0 + 1):\(Music.names[$1.pitchClass])@\(String(format: "%.2f", $1.time))" }.joined(separator: " ")
        let played = presses.map { "\(Music.name($0.midi))@\(String(format: "%.2f", $0.time)) (\($0.result))" }.joined(separator: "; ")
        return "cop=\(String(format: "%.3f", beat)) marge=\(String(format: "%.3f", tolerance))\n  esperat: \(wanted)\n  tocat: \(played.isEmpty ? "res" : played)\n  \(passed ? "BÉ" : "MAL: " + verdict)"
    }

    /// Què ha fallat, dit en una frase.
    var verdict: String {
        if missed == notes.count, extras == 0, wrong == 0 {
            return "No he sentit cap nota. Entra just després dels quatre cops."
        }
        if let shift = wholeShift {
            return shift < 0
                ? "El ritme és bo, però has entrat abans d'hora. Espera que acabin els quatre cops."
                : "El ritme és bo, però has entrat tard. La primera nota va just després dels quatre cops."
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
