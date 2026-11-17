import Foundation

/// Tot el que hi ha en aquest fitxer és càlcul pur (només Foundation), perquè es pugui
/// provar al Mac sense telèfon: `proves/prova.sh`.
enum Pitch {
    /// Notes que el detector busca: del la greu (55 Hz) fins més amunt del do agut.
    static let lowestFrequency = 55.0
    static let highestFrequency = 2100.0

    static func rms(_ samples: UnsafeBufferPointer<Float>) -> Float {
        guard !samples.isEmpty else { return 0 }
        var sum: Float = 0
        for value in samples { sum += value * value }
        return (sum / Float(samples.count)).squareRoot()
    }

    /// Algorisme YIN: troba la freqüència fonamental d'un so d'una sola nota.
    /// Retorna `nil` si el so no té una altura clara (soroll, parla, diverses notes).
    static func detect(_ samples: UnsafeBufferPointer<Float>, sampleRate: Double, threshold: Float = 0.15) -> Double? {
        let count = samples.count
        let maxTau = min(Int(sampleRate / lowestFrequency), count / 2)
        let minTau = max(2, Int(sampleRate / highestFrequency))
        let window = count - maxTau
        guard maxTau > minTau + 2, window > maxTau else { return nil }

        var difference = [Float](repeating: 0, count: maxTau + 1)
        for tau in 1...maxTau {
            var sum: Float = 0
            var index = 0
            while index < window {
                let delta = samples[index] - samples[index + tau]
                sum += delta * delta
                index += 1
            }
            difference[tau] = sum
        }

        // Diferència normalitzada acumulada.
        var running: Float = 0
        difference[0] = 1
        for tau in 1...maxTau {
            running += difference[tau]
            difference[tau] = running == 0 ? 1 : difference[tau] * Float(tau) / running
        }

        var tau = minTau
        while tau < maxTau {
            if difference[tau] < threshold {
                while tau + 1 < maxTau, difference[tau + 1] < difference[tau] { tau += 1 }
                let left = difference[tau - 1], center = difference[tau], right = difference[tau + 1]
                let divisor = left + right - 2 * center
                let refined = divisor == 0 ? Float(tau) : Float(tau) + (left - right) / (2 * divisor)
                return sampleRate / Double(refined)
            }
            tau += 1
        }
        return nil
    }
}

/// Converteix una successió de mesures (volum i altura) en notes tocades.
/// Una nota compta una sola vegada per cada atac, encara que soni molta estona.
struct NoteTracker {
    /// Per sota d'aquest volum es considera silenci.
    var silence: Float = 0.006
    /// Volum mínim perquè una pujada compti com un atac nou.
    var attackFloor: Float = 0.012
    /// Quant ha de créixer el volum d'una mesura a la següent per ser un atac nou.
    var attackRatio: Float = 1.35
    /// Mesures seguides amb la mateixa nota abans de donar-la per bona.
    var framesNeeded = 2

    private var candidate: Int?
    private var stable = 0
    private var armed = true
    private var previousLevel: Float = 0

    /// Rep una mesura i retorna la nota (MIDI) si se n'acaba de tocar una.
    mutating func feed(level: Float, frequency: Double?) -> Int? {
        defer { previousLevel = level }

        if level < silence {
            candidate = nil
            stable = 0
            armed = true
            return nil
        }

        // Un salt de volum és un atac nou: la mateixa nota pot tornar a comptar.
        if level > attackFloor, level > previousLevel * attackRatio {
            armed = true
            stable = 0
        }

        guard let frequency else { return nil }
        let midi = Music.midi(fromFrequency: frequency)

        if midi == candidate {
            stable += 1
        } else if let current = candidate, !armed, Music.pitchClass(current) == Music.pitchClass(midi) {
            // Mentre una nota s'apaga, el detector de vegades salta d'octava. No és una nota nova.
            return nil
        } else {
            candidate = midi
            stable = 1
            armed = true
        }

        if armed, stable >= framesNeeded {
            armed = false
            return midi
        }
        return nil
    }
}

/// So de piano senzill, fet amb harmònics que s'apaguen. Serveix per als exemples.
struct PianoTone {
    let frequency: Double
    /// Durada de la nota abans de deixar-la anar, en segons.
    let duration: Double
    let gain: Float

    static let release = 0.12

    var totalDuration: Double { duration + PianoTone.release }

    /// Valor del so `time` segons després de l'atac.
    func sample(at time: Double) -> Float {
        guard time >= 0, time < totalDuration else { return 0 }
        let phase = 2 * Double.pi * frequency * time
        // Els harmònics aguts s'apaguen abans, com en una corda.
        var value = sin(phase) * exp(-time * 1.6)
        value += 0.45 * sin(2 * phase) * exp(-time * 2.6)
        value += 0.22 * sin(3 * phase) * exp(-time * 3.8)
        value += 0.10 * sin(4 * phase) * exp(-time * 5.0)
        value += 0.05 * sin(5 * phase) * exp(-time * 6.5)

        let attack = min(1, time / 0.006)
        let tail = time > duration ? max(0, 1 - (time - duration) / PianoTone.release) : 1
        return Float(value * attack * tail) * gain
    }
}
