import Foundation

/// Notes com a números MIDI: el do del mig és el 60.
enum Music {
    static let names = ["do", "do♯", "re", "re♯", "mi", "fa", "fa♯", "sol", "sol♯", "la", "la♯", "si"]

    static func pitchClass(_ midi: Int) -> Int { ((midi % 12) + 12) % 12 }

    /// Les tecles negres escrites amb bemoll: la tecla de l'esquerra de la blanca següent.
    static let flatNames = ["do", "re♭", "re", "mi♭", "mi", "fa", "sol♭", "sol", "la♭", "la", "si♭", "si"]

    static func name(_ midi: Int) -> String { names[pitchClass(midi)] }

    /// El nom tal com s'escriu: amb `flat`, una tecla negra es diu pel bemoll (mi♭) i no pel sostingut (re♯).
    static func name(_ midi: Int, flat: Bool) -> String { (flat ? flatNames : names)[pitchClass(midi)] }

    static func isBlack(_ midi: Int) -> Bool { [1, 3, 6, 8, 10].contains(pitchClass(midi)) }

    static func frequency(_ midi: Int) -> Double { 440 * pow(2, Double(midi - 69) / 12) }

    static func midi(fromFrequency frequency: Double) -> Int {
        Int((69 + 12 * log2(frequency / 440)).rounded())
    }

    static let middleC = 60
}
