import Foundation

// Alumne simulat: toca cada ritme del curs moltes vegades amb errors de persona i diu quantes vegades passa.
// No toca el telèfon ni l'app: fa servir el mateix jutge de ritme (RhythmJudge). proves/alumne.sh

/// Generador de nombres aleatoris amb llavor, perquè cada passada doni el mateix resultat.
struct Seeded: RandomNumberGenerator {
    var state: UInt64
    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
    mutating func normal() -> Double {
        let u = max(Double.random(in: 0..<1, using: &self), 1e-12), v = Double.random(in: 0..<1, using: &self)
        return sqrt(-2 * log(u)) * cos(2 * .pi * v)
    }
}

/// Com toca un tipus d'alumne.
struct Profile {
    let name: String
    /// Desviació (s) de cada nota respecte del moment just.
    let jitter: Double
    /// Quant arrossega l'error de la nota d'abans (0: es corregeix del tot amb el clic; 1: no es corregeix gens).
    let persistence: Double
    /// Si no escolta el clic i porta el seu propi tempo: desviació d'aquest tempo (0.06 = un 6 %).
    let ownTempo: Double?
    /// Probabilitat d'escurçar una nota llarga, i quant (fracció de la durada).
    let shortenChance: Double
    let shortenBy: Double
    /// Probabilitat de tocar una tecla equivocada.
    let wrongChance: Double
}

let profiles = [
    Profile(name: "segur", jitter: 0.04, persistence: 0.4, ownTempo: nil, shortenChance: 0, shortenBy: 0, wrongChance: 0),
    Profile(name: "normal", jitter: 0.07, persistence: 0.5, ownTempo: nil, shortenChance: 0.1, shortenBy: 0.3, wrongChance: 0.01),
    Profile(name: "principiant", jitter: 0.10, persistence: 0.6, ownTempo: nil, shortenChance: 0.3, shortenBy: 0.35, wrongChance: 0.03),
    Profile(name: "ritme propi", jitter: 0.06, persistence: 0, ownTempo: 0.08, shortenChance: 0.3, shortenBy: 0.35, wrongChance: 0.01),
]
let speeds: [(String, Double)] = [("molt lent", 0.6), ("lent", 0.8), ("normal", 1)]
let attempts = 400

func attempt(_ tones: [Tone], beat: Double, profile: Profile, rng: inout Seeded) -> Bool {
    var judge = RhythmJudge(tones: tones, beat: beat)
    var presses: [(Double, Int)] = []
    var time = 0.0
    if let spread = profile.ownTempo {
        // Toca al seu aire: un tempo una mica diferent del pols, sense corregir-lo.
        let ratio = 1 + spread * rng.normal()
        var at = 0.0
        for tone in tones {
            if !tone.rest {
                let wrong = Double.random(in: 0..<1, using: &rng) < profile.wrongChance
                presses.append((at + profile.jitter * rng.normal(), wrong ? tone.midi + 2 : tone.midi))
            }
            var length = tone.beats * beat * ratio
            if tone.beats >= 2, Double.random(in: 0..<1, using: &rng) < profile.shortenChance { length *= 1 - profile.shortenBy }
            at += length
        }
    } else {
        // Segueix el clic: cada nota té un petit error, que s'arrossega una mica a la següent.
        var error = 0.0
        var cut = 0.0
        for tone in tones {
            error = profile.persistence * error + profile.jitter * rng.normal() - cut
            cut = 0
            if !tone.rest {
                let wrong = Double.random(in: 0..<1, using: &rng) < profile.wrongChance
                presses.append((time + error, wrong ? tone.midi + 2 : tone.midi))
            }
            // Si no aguanta prou una nota llarga, la següent arriba abans d'hora.
            if tone.beats >= 2, !tone.rest, Double.random(in: 0..<1, using: &rng) < profile.shortenChance { cut = tone.beats * beat * profile.shortenBy }
            time += tone.beats * beat
        }
    }
    for (at, midi) in presses.sorted(by: { $0.0 < $1.0 }) { judge.heard(midi: midi, at: at) }
    judge.close(upTo: .infinity)
    return judge.passed
}

var flagged: [String] = []
print("Percentatge de vegades que passa cada ritme (\(attempts) intents per casella).")
print("Columnes: alumne segur / normal / principiant / ritme propi, a velocitat molt lenta · lenta · normal.")
print("Els tres primers segueixen el clic; «ritme propi» porta el seu tempo sense escoltar-lo.\n")
for lesson in Course.allLessons {
    for (index, step) in lesson.steps.enumerated() {
        guard case .rhythm(let text, let tones, let bpm, let rounds, _) = step else { continue }
        var rng = Seeded(state: UInt64(lesson.number * 100 + index))
        var cells: [String] = []
        var rates: [String: [Double]] = [:]
        for (_, factor) in speeds {
            let beat = 60 / (bpm * factor)
            for profile in profiles {
                var passed = 0
                for _ in 0..<attempts {
                    // Cal passar totes les voltes seguides.
                    var all = true
                    for _ in 0..<rounds where all { all = attempt(tones, beat: beat, profile: profile, rng: &rng) }
                    if all { passed += 1 }
                }
                let rate = Double(passed) / Double(attempts)
                rates[profile.name, default: []].append(rate)
                cells.append(String(format: "%3.0f", rate * 100))
            }
        }
        // Ordre de les cel·les: per velocitat, i dins de cada velocitat, per alumne.
        let bySpeed = stride(from: 0, to: cells.count, by: profiles.count).map { cells[$0..<$0 + profiles.count].joined(separator: " ") }
        let short = text.count > 32 ? String(text.prefix(31)) + "…" : text
        print(String(format: "L%02d pas %d %-34@ ", lesson.number, index + 1, short as NSString) + bySpeed.joined(separator: " · "))
        let safeAtNormal = rates["segur"]?[2] ?? 1
        let normalAtSlow = rates["normal"]?[1] ?? 1
        let beginnerAtSlowest = rates["principiant"]?[0] ?? 1
        if safeAtNormal < 0.9 { flagged.append("L\(lesson.number) pas \(index + 1): fins i tot un alumne segur només passa el \(Int(safeAtNormal * 100)) % a velocitat normal") }
        if normalAtSlow < 0.6 { flagged.append("L\(lesson.number) pas \(index + 1): un alumne normal només passa el \(Int(normalAtSlow * 100)) % a velocitat lenta") }
        if beginnerAtSlowest < 0.3 { flagged.append("L\(lesson.number) pas \(index + 1): un principiant només passa el \(Int(beginnerAtSlowest * 100)) % a velocitat molt lenta") }
    }
}
print("\nAvisos:")
if flagged.isEmpty { print("  cap") } else { for line in flagged { print("  - " + line) } }
