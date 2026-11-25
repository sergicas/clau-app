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
            if let also = tone.also { presses.append((time + offset, also)) }
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

// Afegits per la revisió 2026-11-21-2 (el provador): casos que el jutge nou no fa bé.
// Tecla veïna a temps, que és la de la nota següent (re on anava do, a do-re-mi): és una tecla equivocada, no un toc avançat.
let stepwise = [60, 62, 64, 65].map { Tone(midi: $0) }
let slip = perform(stepwise, beat: 1, wrongAt: [0])
verify("Tecla de la nota següent, a temps: un error i diu la tecla", slip.errors == 1 && slip.verdict.contains("Has tocat re on anava do"))
var slip22 = RhythmJudge(tones: compas, beat: 0.909)
var t22 = 0.0
for (index, tone) in compas.enumerated() {
    slip22.heard(midi: index == 1 ? 64 : tone.midi, at: t22)   // la nota 2 (re) amb el mi
    t22 += tone.beats * 0.909
}
slip22.close(upTo: .infinity)
verify("L22: una tecla veïna en dotze notes es perdona, com abans", slip22.errors == 1 && slip22.passed)
// Mentre toca, l'app marca la nota que ve. Després d'una relliscada no s'ha de saltar la nota que toca ara.
var hint = RhythmJudge(tones: stepwise, beat: 1)
hint.heard(midi: 62, at: 0)
hint.close(upTo: 1)
verify("Després de tocar re on anava do, al cop 2 l'app marca el re", hint.nextToneIndex == 1)
// Una sola nota avançada al final d'un ritme curt no és un tempo propi.
let unITresProva = [60, 64, 60, 64].map { Tone(midi: $0, beats: 2) }
var lastEarly = RhythmJudge(tones: unITresProva, beat: 1)
for (index, time) in [0.0, 2.0, 4.0, 5.3].enumerated() { lastEarly.heard(midi: unITresProva[index].midi, at: time) }
lastEarly.close(upTo: .infinity)
verify("Escurçar l'última blanca no es diu «vas més de pressa que el pols»", !lastEarly.verdict.contains("que el pols"))

// Revisió 2026-11-21-3: qui toca a cada cop la tecla de la nota següent s'ha perdut a la partitura; dir-li la tecla no l'ajuda.
let escala = [60, 62, 64, 65, 67, 65, 64, 62].map { Tone(midi: $0) }
var ahead = RhythmJudge(tones: escala, beat: 1)
for index in 0..<(escala.count - 1) { ahead.heard(midi: escala[index + 1].midi, at: Double(index)) }
ahead.close(upTo: .infinity)
verify("Una nota per davant tota l'estona: ho diu", !ahead.passed && ahead.verdict.contains("una nota per davant"))
// Una nota tocada quatre cops tard no és aquella nota: el marge per a les notes del costat és de dos cops com a molt.
let llarga = [Tone(midi: 62), Tone(midi: 60, beats: 4), Tone(midi: 64)]
var farLate = RhythmJudge(tones: llarga, beat: 1)
farLate.heard(midi: 60, at: 1)
farLate.heard(midi: 62, at: 5)   // el re de la nota 1, quatre cops tard, on anava el mi
farLate.close(upTo: .infinity)
verify("Una nota no es reconeix quatre cops després del seu moment", farLate.verdict.contains("Has tocat re on anava mi"))

// Revisió 2026-11-22: qui té la mà una tecla desplaçada toca a temps, però cada nota una tecla amunt (o avall).
// En una melodia que puja o baixa per graus és la tecla de la nota següent (o de l'anterior), però no s'ha perdut a la partitura.
let odaGraus = [64, 64, 65, 67, 67, 65, 64, 62].map { Tone(midi: $0) }
let tecla = [60: 62, 62: 64, 64: 65, 65: 67, 67: 69]
var shifted = RhythmJudge(tones: odaGraus, beat: 1)
for (index, tone) in odaGraus.enumerated() { shifted.heard(midi: tecla[tone.midi]!, at: Double(index)) }
shifted.close(upTo: .infinity)
verify("Mà una tecla amunt, a temps: no es diu «vas una nota endarrerit»", !shifted.verdict.contains("una nota"))
verify("Mà una tecla amunt, a temps: diu que toca una tecla més amunt", shifted.verdict.contains("una tecla més amunt"))
var shiftedDown = RhythmJudge(tones: odaGraus, beat: 1)
let teclaAvall = [62: 60, 64: 62, 65: 64, 67: 65]
for (index, tone) in odaGraus.enumerated() { shiftedDown.heard(midi: teclaAvall[tone.midi]!, at: Double(index)) }
shiftedDown.close(upTo: .infinity)
verify("Mà una tecla avall, a temps: diu que toca una tecla més avall", shiftedDown.verdict.contains("una tecla més avall"))
// Do, re, mi, fa, sol amb la mà amunt: el la de l'última nota no és de cap nota següent, i la mà ho explica tot.
let escalaCinc = [60, 62, 64, 65, 67].map { Tone(midi: $0) }
var ambigu = RhythmJudge(tones: escalaCinc, beat: 1)
for (index, tone) in escalaCinc.enumerated() { ambigu.heard(midi: tecla[tone.midi]!, at: Double(index)) }
ambigu.close(upTo: .infinity)
verify("Do re mi fa sol una tecla amunt: és la mà, no que vagi per davant", ambigu.verdict.contains("una tecla més amunt"))
// Qui escurça les blanques i després va un cop avançat: el que ha passat és la blanca, no que s'hagi perdut.
let blanques = [Tone(midi: 64, beats: 2), Tone(midi: 67, beats: 2), Tone(midi: 65), Tone(midi: 64), Tone(midi: 62, beats: 2),
                Tone(midi: 60), Tone(midi: 62), Tone(midi: 64), Tone(midi: 65), Tone(midi: 64, beats: 4)]
var rushed = RhythmJudge(tones: blanques, beat: 1)
for (midi, time) in [(64, 0.0), (67, 1.5), (65, 3), (64, 4), (62, 5), (60, 7), (62, 8), (64, 9), (65, 10), (64, 11)] { rushed.heard(midi: midi, at: time) }
rushed.close(upTo: .infinity)
verify("Blanques escurçades i després un cop avançat: es parla de la blanca", rushed.verdict.contains("dura 2 cops"))

// Revisió 2026-11-23: a do, re, mi, fa, sol, qui va una nota per davant no toca res a l'últim cop (o hi toca el sol, que és bo);
// qui té la mà desplaçada hi toca el la. L'última nota les separa: amb la mà, una tecla amunt més que tecles «de la nota següent».
var aheadCinc = RhythmJudge(tones: escalaCinc, beat: 1)
for index in 0..<(escalaCinc.count - 1) { aheadCinc.heard(midi: escalaCinc[index + 1].midi, at: Double(index)) }
aheadCinc.close(upTo: .infinity)
verify("Do re mi fa sol una nota per davant (re mi fa sol i res): diu «per davant», no la mà", aheadCinc.verdict.contains("una nota per davant"))
// Qui corre (tempo un 6 % més ràpid) i escurça la blanca: de debò, l'últim pas de la L24 (dues vegades seguides) a velocitat lenta, de l'alumne simulat «ritme propi».
// Va avançat tota l'estona, però com que ha escurçat la blanca abans de perdre's, el «per davant» calla i surt «endarrerit».
let l24 = Course.allLessons.first { $0.number == 24 }!
guard case .rhythm(_, let tones24, let bpm24, _, _) = l24.steps.last else { fatalError("L'últim pas de la L24 ja no és de ritme") }
do {
    var corre = RhythmJudge(tones: tones24, beat: 60 / (bpm24 * 0.8))
    let tocat: [(Int, Double)] = [(60, 0.12), (60, 0.91), (60, 1.93), (62, 2.74), (64, 3.76), (62, 5.60), (60, 7.42), (64, 8.35), (62, 9.35),
                                  (62, 10.26), (60, 11.21), (60, 14.94), (60, 15.86), (60, 16.76), (62, 17.68), (64, 18.51), (62, 19.77),
                                  (60, 21.06), (64, 21.85), (62, 22.97), (62, 23.77), (60, 24.76)]
    for (midi, time) in tocat { corre.heard(midi: midi, at: time) }
    corre.close(upTo: .infinity)
    verify("Qui corre i escurça la blanca no rep «vas una nota endarrerit»", !corre.verdict.contains("endarrerit"))
}

// Una sola nota repetida, tota una tecla amunt: es diu quina tecla tocava, que és el que no sap qui tot just ha après el do.
let dos = Array(repeating: Tone(midi: 60), count: 6)
var dosAmunt = RhythmJudge(tones: dos, beat: 1)
for index in dos.indices { dosAmunt.heard(midi: 62, at: Double(index)) }
dosAmunt.close(upTo: .infinity)
verify("Tot el do amb el re: diu «Has tocat re on anava do»", dosAmunt.verdict.contains("Has tocat re on anava do"))

// Escurça una blanca al principi, es refà i toca bé un bon tros, i més tard es perd una nota per davant: això és el que cal dir.
let refet = [Tone(midi: 64), Tone(midi: 64), Tone(midi: 64, beats: 2)] + [60, 62, 64, 65, 67, 65, 64, 62, 60, 62, 64, 65, 67, 65, 64, 62].map { Tone(midi: $0) }
var refetJudge = RhythmJudge(tones: refet, beat: 1)
var refetTime = 0.0
for (index, tone) in refet.enumerated() {
    if index == 3 {
        refetJudge.heard(midi: tone.midi, at: refetTime - 0.5)   // el do, mig cop abans: la blanca escurçada
    } else if index < 11 || index + 1 >= refet.count {
        refetJudge.heard(midi: tone.midi, at: refetTime)
    } else {
        refetJudge.heard(midi: refet[index + 1].midi, at: refetTime)   // ja va una nota per davant
    }
    refetTime += tone.beats
}
refetJudge.close(upTo: .infinity)
verify("Blanca escurçada al principi, refet, i perdut més tard: diu «per davant»", refetJudge.verdict.contains("una nota per davant"))

// Dues mans alhora: dues notes al mateix moment.
print("Dues notes alhora")
let junts = [Tone(midi: 60, also: 48), Tone(midi: 62, also: 50), Tone(midi: 64, beats: 2, also: 52)]
var totesDues = RhythmJudge(tones: junts, beat: 1)
for (midi, at) in [(48, 0.02), (60, -0.03), (62, 1.0), (50, 1.04), (52, 2.0), (64, 2.01)] { totesDues.heard(midi: midi, at: at) }
totesDues.close(upTo: .infinity)
verify("Les dues mans a cada cop: passa", totesDues.passed)
verify("Les dues mans: totes les marques bones", totesDues.toneMarks == [.hit, .hit, .hit])
verify("Dues notes alhora no estrenyen el marge", RhythmJudge(tones: junts, beat: 1).tolerance >= 0.29)
var unaMa = RhythmJudge(tones: junts, beat: 1)
for (midi, at) in [(60, 0.0), (62, 1.0), (64, 2.0)] { unaMa.heard(midi: midi, at: at) }
unaMa.close(upTo: .infinity)
verify("Només una mà: no passa", !unaMa.passed)
verify("Només una mà: les marques diuen que falta l'altra", unaMa.toneMarks == [.missed, .missed, .missed])
let mirall = [Tone(midi: 60, also: 55), Tone(midi: 62, also: 53)]
var creuat = RhythmJudge(tones: mirall, beat: 1)
for (midi, at) in [(55, 0.0), (60, 0.02), (53, 1.0), (62, 1.01)] { creuat.heard(midi: midi, at: at) }
creuat.close(upTo: .infinity)
verify("Notes diferents alhora, primer l'esquerra: passa", creuat.passed)
let junts4 = [Tone(midi: 60, also: 48), Tone(midi: 62, also: 50), Tone(midi: 64, also: 52), Tone(midi: 65, also: 53), Tone(midi: 67, beats: 4, also: 55), Tone(midi: 65, also: 53)]
var tallat = RhythmJudge(tones: junts4, beat: 1)
for (midi, at) in [(60, 0.0), (48, 0.0), (62, 1.0), (50, 1.0), (64, 2.0), (52, 2.0), (65, 3.0), (53, 3.0), (67, 4.0), (55, 4.0), (65, 6.0), (53, 6.0)] { tallat.heard(midi: midi, at: at) }
tallat.close(upTo: .infinity)
verify("Sol llarg escurçat amb les dues mans: diu la nota 5", tallat.verdict.contains("La nota 5 dura 4 cops"))
print(tallat.verdict)

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
