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

print(failures == 0 ? "\nTot bé." : "\n\(failures) proves han fallat.")
exit(failures == 0 ? 0 : 1)
