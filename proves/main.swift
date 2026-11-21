import Foundation

// Prova del motor de Clau al Mac: fabrica so de piano i mira si el detector hi sent les notes bones.
// S'executa amb proves/prova.sh.

let sampleRate = 48_000.0
let windowSize = 4096
let hop = 2048
let attackSize = 1024

struct Played {
    let midi: Int
    let start: Double
    let hold: Double
    var gain: Float = 0.3
}

func render(_ notes: [Played], seconds: Double, noise: Float = 0) -> [Float] {
    var out = [Float](repeating: 0, count: Int(seconds * sampleRate))
    for note in notes {
        let tone = PianoTone(frequency: Music.frequency(note.midi), duration: note.hold, gain: note.gain)
        let first = Int(note.start * sampleRate)
        let last = min(out.count, first + Int(tone.totalDuration * sampleRate))
        guard first < last else { continue }
        for index in first..<last {
            out[index] += tone.sample(at: Double(index - first) / sampleRate)
        }
    }
    if noise > 0 {
        var generator = SystemRandomNumberGenerator()
        for index in out.indices { out[index] += Float.random(in: -noise...noise, using: &generator) }
    }
    return out
}

func listen(_ audio: [Float]) -> [Int] {
    var tracker = NoteTracker()
    var heard: [Int] = []
    var position = 0
    while position + windowSize <= audio.count {
        audio[position..<(position + windowSize)].withContiguousStorageIfAvailable { slice in
            // El volum es mira només al tros més nou; l'altura, a tota la finestra.
            let level = Pitch.rms(UnsafeBufferPointer(rebasing: slice[(windowSize - attackSize)...]))
            let frequency = level > 0.006 ? Pitch.detect(slice, sampleRate: sampleRate) : nil
            if let midi = tracker.feed(level: level, frequency: frequency) { heard.append(midi) }
        }
        position += hop
    }
    return heard
}

var failures = 0
func check(_ name: String, _ got: [Int], _ expected: [Int]) {
    if got == expected {
        print("  bé   \(name)")
    } else {
        failures += 1
        print("  MAL  \(name)\n        esperat \(expected.map(Music.name))\n        sentit  \(got.map { "\(Music.name($0))\($0 / 12 - 1)" })")
    }
}

func sequence(_ midis: [Int], every gap: Double, hold: Double) -> [Played] {
    midis.enumerated().map { Played(midi: $1, start: 0.3 + Double($0) * gap, hold: hold) }
}

print("Notes soltes, de greu a agut")
for midi in stride(from: 36, through: 96, by: 1) {
    let got = listen(render([Played(midi: midi, start: 0.3, hold: 0.8)], seconds: 1.6))
    if got != [midi] {
        failures += 1
        print("  MAL  \(Music.name(midi))\(midi / 12 - 1): sentit \(got)")
    }
}
print("  fet  61 notes, del do2 al do7")

print("Melodies")
let oda = [64, 64, 65, 67, 67, 65, 64, 62, 60, 60, 62, 64, 64, 62, 62]
check("Oda a l'alegria, notes separades", listen(render(sequence(oda, every: 0.6, hold: 0.45), seconds: 10)), oda)
check("Oda a l'alegria, notes que es trepitgen", listen(render(sequence(oda, every: 0.6, hold: 0.8), seconds: 10)), oda)
check("Oda a l'alegria, de pressa", listen(render(sequence(oda, every: 0.35, hold: 0.3), seconds: 7)), oda)
let fiveFingers = [60, 62, 64, 65, 67, 65, 64, 62, 60]
check("Cinc dits, lligat", listen(render(sequence(fiveFingers, every: 0.5, hold: 0.55), seconds: 6)), fiveFingers)
check("El mateix do tres vegades", listen(render(sequence([60, 60, 60], every: 0.7, hold: 0.5), seconds: 3)), [60, 60, 60])
check("Tres dos de tres octaves", listen(render(sequence([48, 60, 72], every: 0.8, hold: 0.6), seconds: 3.5)), [48, 60, 72])
check("Negres: do♯ i re♯", listen(render(sequence([61, 63], every: 0.7, hold: 0.5), seconds: 2.5)), [61, 63])

print("Casos difícils")
check("Una nota llarga compta una sola vegada", listen(render([Played(midi: 64, start: 0.3, hold: 3.5)], seconds: 4.2)), [64])
check("Nota fluixa", listen(render([Played(midi: 67, start: 0.3, hold: 0.8, gain: 0.05)], seconds: 1.6)), [67])
check("Amb soroll de fons", listen(render(sequence(fiveFingers, every: 0.6, hold: 0.5), seconds: 7, noise: 0.01)), fiveFingers)
check("Només soroll: no ha de sentir res", listen(render([], seconds: 3, noise: 0.05)), [])
check("Silenci: no ha de sentir res", listen(render([], seconds: 2)), [])

// MARK: Ritme

func verify(_ name: String, _ condition: Bool) {
    if condition {
        print("  bé   \(name)")
    } else {
        failures += 1
        print("  MAL  \(name)")
    }
}

/// Toca un ritme tal com és, amb cada nota desplaçada `offset` segons.
func perform(_ tones: [Tone], beat: Double, offset: Double = 0, skip: Set<Int> = [], extraAt: [Double] = [], wrongAt: Set<Int> = []) -> RhythmJudge {
    var judge = RhythmJudge(tones: tones, beat: beat)
    var presses: [(time: Double, midi: Int)] = []
    var time = 0.0
    for (index, tone) in tones.enumerated() {
        if !tone.rest, !skip.contains(index) {
            presses.append((time + offset, wrongAt.contains(index) ? tone.midi + 2 : tone.midi))
        }
        time += tone.beats * beat
    }
    for extra in extraAt { presses.append((extra, 60)) }
    for press in presses.sorted(by: { $0.time < $1.time }) { judge.heard(midi: press.midi, at: press.time) }
    judge.close(upTo: .infinity)
    return judge
}

print("Ritme")
let four = [Tone(midi: 60), Tone(midi: 60), Tone(midi: 60), Tone(midi: 60)]
verify("Quatre dos a temps", perform(four, beat: 1).passed)
verify("Una mica abans i una mica després encara val", perform(four, beat: 1, offset: 0.2).passed && perform(four, beat: 1, offset: -0.2).passed)
let lateJudge = perform(four, beat: 1, offset: 0.4)
verify("Massa tard no val, i ho diu", !lateJudge.passed && lateJudge.verdict.contains("tard"))
let earlyJudge = perform(four, beat: 1, offset: -0.4)
verify("Massa aviat no val, i ho diu", !earlyJudge.passed && earlyJudge.verdict.contains("avançat"))
verify("Una nota de menys no val", !perform(four, beat: 1, skip: [2]).passed)
verify("Una nota equivocada no val", !perform(four, beat: 1, wrongAt: [1]).passed)
verify("No tocar res no val", !perform(four, beat: 1, skip: [0, 1, 2, 3]).passed)
let withRest = [Tone(midi: 60), Tone(midi: 60), Tone.rest(), Tone(midi: 60)]
verify("Amb un silenci, a temps", perform(withRest, beat: 1).passed)
let inRest = perform(withRest, beat: 1, extraAt: [2.0])
verify("Tocar durant el silenci no val, i ho diu", !inRest.passed && inRest.verdict.contains("silenci"))
let longNotes = [Tone(midi: 60, beats: 2), Tone(midi: 60, beats: 2)]
verify("Tornar a tocar una nota llarga no val", !perform(longNotes, beat: 1, extraAt: [1.0]).passed)
let halves = [Tone(midi: 60), Tone(midi: 60, beats: 0.5), Tone(midi: 62, beats: 0.5), Tone(midi: 64, beats: 2)]
verify("Notes de mig cop a temps", perform(halves, beat: 1).passed)
verify("Notes de mig cop: el marge es fa estret", RhythmJudge(tones: halves, beat: 1).tolerance < 0.25)
verify("Marques: el silenci queda pendent", perform(withRest, beat: 1).toneMarks == [.hit, .hit, .pending, .hit])

// El cas d'en Sergi a la lliçó 21: negra, negra, blanca i rodona, tocant la rodona un cop abans.
let figures = [Tone(midi: 64), Tone(midi: 64), Tone(midi: 64, beats: 2), Tone(midi: 64, beats: 4)]
var hurried = RhythmJudge(tones: figures, beat: 1)
for time in [0.0, 1.0, 2.0, 3.0] { hurried.heard(midi: 64, at: time) }
hurried.close(upTo: .infinity)
verify("No esperar una blanca: diu quina nota i quants cops dura", !hurried.passed && hurried.verdict.contains("La nota 3 dura 2 cops"))

let lateEntry = perform(four, beat: 1, offset: 1.0)
verify("Entrar un cop tard: ho diu", !lateEntry.passed && lateEntry.verdict.contains("has entrat tard"))
let earlyEntry = perform(four, beat: 1, offset: -1.0)
verify("Entrar un cop abans: ho diu", !earlyEntry.passed && earlyEntry.verdict.contains("abans d'hora"))

// Els casos de la revisió del 21-11: la lliçó 22, que en Sergi tocava al seu propi tempo.
let compas = [60, 62, 64, 65].map { Tone(midi: $0) } + [Tone(midi: 67, beats: 2), Tone(midi: 64, beats: 2)]
    + [65, 65, 64, 64].map { Tone(midi: $0) } + [Tone(midi: 62, beats: 2), Tone(midi: 60, beats: 2)]
func ownTempo(_ tones: [Tone], beat: Double, played: Double) -> RhythmJudge {
    var judge = RhythmJudge(tones: tones, beat: beat)
    var time = 0.0
    for tone in tones where !tone.rest {
        judge.heard(midi: tone.midi, at: time * played)
        time += tone.beats
    }
    judge.close(upTo: .infinity)
    return judge
}
let slower = ownTempo(compas, beat: 0.909, played: 1.0)
verify("Tempo propi més lent: diu que va més a poc a poc, no que s'equivoca de tecla", !slower.passed && slower.verdict.contains("més a poc a poc que el pols"))
let faster = ownTempo(compas, beat: 1.136, played: 1.0)
verify("Tempo propi més ràpid: diu que va més de pressa", !faster.passed && faster.verdict.contains("més de pressa que el pols"))
var behind = RhythmJudge(tones: compas, beat: 0.909)
var at = 0.0
for (index, tone) in compas.enumerated() {
    // Cada nota sona quan tocava la de després: s'ha quedat una nota enrere.
    if index > 0 { behind.heard(midi: compas[index - 1].midi, at: at) }
    at += tone.beats * 0.909
}
behind.close(upTo: .infinity)
verify("Anar una nota enrere no es diu tecla equivocada", !behind.passed && !behind.verdict.contains("Has tocat"))
let oneLate = perform(compas, beat: 0.909, offset: 0, skip: [3], extraAt: [])
var lateOnce = RhythmJudge(tones: compas, beat: 0.909)
var t = 0.0
for (index, tone) in compas.enumerated() {
    lateOnce.heard(midi: tone.midi, at: t + (index == 3 ? 0.35 : 0))
    t += tone.beats * 0.909
}
lateOnce.close(upTo: .infinity)
verify("Una sola nota tard en dotze compta com un error, i es perdona", lateOnce.errors == 1 && lateOnce.passed && oneLate.errors == 1)
var corrected = RhythmJudge(tones: four, beat: 1)
for time in [0.0, 1.0, 1.6, 2.0, 3.0] { corrected.heard(midi: 60, at: time) }
corrected.close(upTo: .infinity)
verify("Tocar massa aviat i després al seu moment: un sol error", corrected.errors == 1 && corrected.toneMarks == [.hit, .hit, .hit, .hit])

print("Curs")
for lesson in Course.allLessons {
    for step in lesson.steps {
        guard case .rhythm(_, let tones, let bpm, _, _) = step else { continue }
        let beats = tones.reduce(0) { $0 + $1.beats }
        if beats.truncatingRemainder(dividingBy: 4) != 0 {
            failures += 1
            print("  MAL  lliçó \(lesson.number): un ritme dura \(beats) cops i no fa compassos sencers")
        }
        if !perform(tones, beat: 60 / bpm).passed {
            failures += 1
            print("  MAL  lliçó \(lesson.number): un ritme tocat perfecte no passa")
        }
        let allowed = tones.filter { !$0.rest }.count / 8
        if allowed > 0, !perform(tones, beat: 60 / bpm, skip: [0]).passed {
            failures += 1
            print("  MAL  lliçó \(lesson.number): un ritme llarg no perdona una nota")
        }
    }
}
let numbers = Course.allLessons.map(\.number)
verify("\(numbers.count) lliçons numerades seguides", numbers == Array(1...numbers.count))
verify("Cap lliçó repeteix identificador", Set(Course.allLessons.map(\.id)).count == numbers.count)

print(failures == 0 ? "\nTot bé." : "\n\(failures) proves han fallat.")
exit(failures == 0 ? 0 : 1)
