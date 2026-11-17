import Foundation

// MARK: - Model

/// Una nota d'un exemple: quina i quants temps dura.
struct Tone: Equatable {
    let midi: Int
    var beats: Double = 1
}

/// Què ha de tocar l'alumne perquè un pas compti.
enum Accept: Equatable {
    /// Qualsevol tecla.
    case any
    /// Qualsevol tecla d'aquest nom, a qualsevol altura (0 = do, 2 = re…).
    case named(Int)
    /// Aquesta tecla i cap altra.
    case exact(Int)

    func matches(_ midi: Int) -> Bool {
        switch self {
        case .any: return true
        case .named(let pitchClass): return Music.pitchClass(midi) == pitchClass
        case .exact(let wanted): return midi == wanted
        }
    }
}

/// Una nota que es demana a l'alumne.
struct Goal: Equatable {
    let accept: Accept
    /// El que es veu a la fitxa: «do», «dit 3», «negra»…
    let label: String
    /// Tecla que s'il·lumina al teclat dibuixat, si n'hi ha.
    var key: Int?

    /// Una nota pel seu nom, il·luminada al voltant del do del mig.
    static func note(_ midi: Int) -> Goal {
        Goal(accept: .named(Music.pitchClass(midi)), label: Music.name(midi), key: midi)
    }
}

/// El teclat dibuixat que acompanya un pas.
struct Keyboard: Equatable {
    var low = 60
    var high = 71
    /// Tecles marcades encara que no sonin.
    var marked: [Int] = []
    /// Nom escrit a sobre de la tecla.
    var names: [Int: String] = [:]
    /// Número de dit a sobre de la tecla.
    var fingers: [Int: Int] = [:]

    static let oneOctave = Keyboard()
    static let threeOctaves = Keyboard(low: 48, high: 83)
}

enum Picture: Equatable {
    case symbol(String)
    case keyboard(Keyboard)
}

enum Step: Equatable {
    /// Mira: una idea i un dibuix.
    case look(text: String, picture: Picture)
    /// Escolta: l'app toca.
    case listen(text: String, tones: [Tone], bpm: Double, keyboard: Keyboard)
    /// Toca: l'alumne toca i l'app escolta. `distinct` vol dir que no val repetir la mateixa tecla.
    case play(text: String, goals: [Goal], rounds: Int, keyboard: Keyboard, distinct: Bool)

    static func play(_ text: String, _ goals: [Goal], rounds: Int = 3, keyboard: Keyboard = .oneOctave, distinct: Bool = false) -> Step {
        .play(text: text, goals: goals, rounds: rounds, keyboard: keyboard, distinct: distinct)
    }
}

struct Lesson: Identifiable, Equatable {
    let id: String
    let number: Int
    let title: String
    /// Una ratlla per a la llista del curs.
    let summary: String
    let minutes: Int
    let steps: [Step]
    /// Les peces tenen un tracte diferent a la llista.
    var isPiece = false
}

struct Stage: Identifiable, Equatable {
    let id: Int
    let title: String
    let summary: String
    let lessons: [Lesson]
}

// MARK: - Contingut

enum Course {
    static let stages: [Stage] = [stage1]

    /// Etapes que encara no hi són, per ensenyar el camí.
    static let upcoming: [(title: String, summary: String)] = [
        ("El pols", "Notes llargues i curtes, comptar i silencis"),
        ("Llegir", "El pentagrama i la clau de sol"),
        ("La mà esquerra", "La clau de fa i melodies amb l'esquerra"),
        ("Les dues mans", "Baix i melodia, mans juntes"),
        ("Sortir dels cinc dits", "El pas del polze, l'escala i les tecles negres"),
        ("Acords", "Do, fa i sol, menors i acompanyar"),
    ]

    static var allLessons: [Lesson] { stages.flatMap(\.lessons) }

    static func lesson(after lesson: Lesson) -> Lesson? {
        let all = allLessons
        guard let index = all.firstIndex(of: lesson), index + 1 < all.count else { return nil }
        return all[index + 1]
    }

    // Notes al voltant del do del mig.
    private static let C = 60, D = 62, E = 64, F = 65, G = 67

    private static func tones(_ midis: [Int]) -> [Tone] { midis.map { Tone(midi: $0) } }
    private static func goals(_ midis: [Int]) -> [Goal] { midis.map(Goal.note) }

    /// Els cinc dits de la mà dreta, col·locats de do a sol.
    private static let fiveFingerKeyboard = Keyboard(
        marked: [C, D, E, F, G],
        names: [C: "do", D: "re", E: "mi", F: "fa", G: "sol"],
        fingers: [C: 1, D: 2, E: 3, F: 4, G: 5]
    )

    static let stage1 = Stage(
        id: 1,
        title: "El teclat",
        summary: "Seure, trobar el do i col·locar els cinc dits",
        lessons: [seure, negres, elDo, totsElsDos, dits, doReMi, cincDits, oda]
    )

    // 1
    static let seure = Lesson(
        id: "1-seure", number: 1,
        title: "Seure i deixar caure la mà",
        summary: "Com seure i quina forma té la mà",
        minutes: 2,
        steps: [
            .look(text: "Seu al mig del piano, a la punta de la banqueta. Els peus plans a terra i l'esquena llarga, sense tibar.",
                  picture: .symbol("chair.fill")),
            .look(text: "Deixa penjar el braç al costat del cos i mira't la mà: queda arrodonida, com si agafés una taronja. Aquesta és la forma.",
                  picture: .symbol("hand.raised.fill")),
            .look(text: "Puja la mà al teclat sense canviar-li la forma i deixa-la caure sobre una tecla. No l'empenyis: deixa que pesi.",
                  picture: .keyboard(.oneOctave)),
            .play("Deixa caure la mà sobre una tecla, la que vulguis. Tres vegades.",
                  [Goal(accept: .any, label: "una tecla")]),
        ]
    )

    // 2
    static let negres = Lesson(
        id: "1-negres", number: 2,
        title: "Les tecles negres",
        summary: "Van de dues en dues i de tres en tres",
        minutes: 2,
        steps: [
            .look(text: "Mira les tecles negres. No estan repartides igual: van en grups de dues i en grups de tres. Són el mapa del teclat.",
                  picture: .keyboard(Keyboard(low: 60, high: 83, marked: [61, 63, 73, 75]))),
            .play("Busca un grup de dues negres i toca-les, d'esquerra a dreta.",
                  [Goal(accept: .named(1), label: "negra", key: 61), Goal(accept: .named(3), label: "negra", key: 63)],
                  rounds: 2),
            .look(text: "Al costat hi ha el grup de tres.",
                  picture: .keyboard(Keyboard(low: 60, high: 83, marked: [66, 68, 70, 78, 80, 82]))),
            .play("Ara toca les tres negres d'un grup de tres, d'esquerra a dreta.",
                  [Goal(accept: .named(6), label: "negra", key: 66), Goal(accept: .named(8), label: "negra", key: 68), Goal(accept: .named(10), label: "negra", key: 70)],
                  rounds: 2),
        ]
    )

    // 3
    static let elDo = Lesson(
        id: "1-do", number: 3,
        title: "On és el do",
        summary: "A l'esquerra de les dues negres",
        minutes: 2,
        steps: [
            .look(text: "El do és la tecla blanca que hi ha just a l'esquerra del grup de dues negres.",
                  picture: .keyboard(Keyboard(marked: [C], names: [C: "do"]))),
            .listen(text: "Així sona un do.", tones: [Tone(midi: C, beats: 2)], bpm: 60,
                    keyboard: Keyboard(names: [C: "do"])),
            .play("Busca dues negres i toca el do que tenen a l'esquerra. Tres vegades.",
                  [.note(C)]),
        ]
    )

    // 4
    static let totsElsDos = Lesson(
        id: "1-dos", number: 4,
        title: "Tots els dos i el do del mig",
        summary: "N'hi ha un a cada grup de dues negres",
        minutes: 3,
        steps: [
            .look(text: "Hi ha un do a cada grup de dues negres. Tots es diuen do: els de l'esquerra sonen greus i els de la dreta, aguts.",
                  picture: .keyboard(Keyboard(low: 48, high: 83, marked: [48, 60, 72], names: [48: "do", 60: "do", 72: "do"]))),
            .listen(text: "Tres dos, del més greu al més agut.",
                    tones: [Tone(midi: 48, beats: 2), Tone(midi: 60, beats: 2), Tone(midi: 72, beats: 2)], bpm: 72,
                    keyboard: Keyboard(low: 48, high: 83, names: [48: "do", 60: "do", 72: "do"])),
            .play("Toca tres dos diferents, començant per l'esquerra.",
                  [Goal(accept: .named(0), label: "do"), Goal(accept: .named(0), label: "do"), Goal(accept: .named(0), label: "do")],
                  rounds: 1, keyboard: Keyboard(low: 48, high: 83, marked: [48, 60, 72]), distinct: true),
            .look(text: "El do del mig és el que et queda al davant quan seus al centre del piano. Sovint és a prop del nom de la marca.",
                  picture: .keyboard(Keyboard(low: 48, high: 83, marked: [60], names: [60: "do"]))),
            .play("Toca el do del mig. Tres vegades.",
                  [Goal(accept: .exact(C), label: "do del mig", key: C)],
                  keyboard: Keyboard(low: 48, high: 83)),
        ]
    )

    // 5
    static let dits = Lesson(
        id: "1-dits", number: 5,
        title: "Els dits tenen número",
        summary: "De l'1, el polze, al 5, el petit",
        minutes: 3,
        steps: [
            .look(text: "Els dits tenen número. El polze és l'1, l'índex el 2, el del mig el 3, l'anular el 4 i el petit el 5. Igual a les dues mans.",
                  picture: .symbol("hand.raised.fingers.spread.fill")),
            .look(text: "Posa el polze de la mà dreta sobre el do del mig i un dit a cada tecla blanca. La mà, arrodonida. Ja la tens col·locada.",
                  picture: .keyboard(Keyboard(marked: [C, D, E, F, G], fingers: [C: 1, D: 2, E: 3, F: 4, G: 5]))),
            .play("Sense moure la mà de lloc, toca amb el dit que et demano.",
                  [Goal(accept: .named(0), label: "dit 1", key: C), Goal(accept: .named(4), label: "dit 3", key: E), Goal(accept: .named(7), label: "dit 5", key: G)],
                  rounds: 2, keyboard: Keyboard(fingers: [C: 1, D: 2, E: 3, F: 4, G: 5])),
            .play("Ara els dos que falten.",
                  [Goal(accept: .named(2), label: "dit 2", key: D), Goal(accept: .named(5), label: "dit 4", key: F)],
                  rounds: 2, keyboard: Keyboard(fingers: [C: 1, D: 2, E: 3, F: 4, G: 5])),
        ]
    )

    // 6
    static let doReMi = Lesson(
        id: "1-doremi", number: 6,
        title: "Do, re, mi",
        summary: "Les tres primeres notes, amb els dits 1, 2 i 3",
        minutes: 3,
        steps: [
            .look(text: "Les tecles blanques que venen després del do es diuen re i mi. Les toquen els dits 1, 2 i 3.",
                  picture: .keyboard(Keyboard(marked: [C, D, E], names: [C: "do", D: "re", E: "mi"], fingers: [C: 1, D: 2, E: 3]))),
            .listen(text: "Do, re, mi.", tones: tones([C, D, E]), bpm: 66,
                    keyboard: Keyboard(names: [C: "do", D: "re", E: "mi"], fingers: [C: 1, D: 2, E: 3])),
            .play("Toca do, re, mi. Un dit per a cada tecla.", goals([C, D, E]),
                  keyboard: Keyboard(names: [C: "do", D: "re", E: "mi"], fingers: [C: 1, D: 2, E: 3])),
            .listen(text: "I ara cap avall: mi, re, do.", tones: tones([E, D, C]), bpm: 66,
                    keyboard: Keyboard(names: [C: "do", D: "re", E: "mi"], fingers: [C: 1, D: 2, E: 3])),
            .play("Toca mi, re, do.", goals([E, D, C]), rounds: 2,
                  keyboard: Keyboard(names: [C: "do", D: "re", E: "mi"], fingers: [C: 1, D: 2, E: 3])),
        ]
    )

    // 7
    static let cincDits = Lesson(
        id: "1-cincdits", number: 7,
        title: "Els cinc dits",
        summary: "De do a sol, pujant i baixant",
        minutes: 3,
        steps: [
            .look(text: "Després del mi venen el fa i el sol. Amb els cinc dits col·locats tens cinc notes sense moure la mà.",
                  picture: .keyboard(fiveFingerKeyboard)),
            .listen(text: "Do, re, mi, fa, sol.", tones: tones([C, D, E, F, G]), bpm: 72, keyboard: fiveFingerKeyboard),
            .play("Puja de do a sol.", goals([C, D, E, F, G]), rounds: 2, keyboard: fiveFingerKeyboard),
            .play("Baixa de sol a do.", goals([G, F, E, D, C]), rounds: 2, keyboard: fiveFingerKeyboard),
            .listen(text: "Pujar i baixar, sense aturar-se a dalt.", tones: tones([C, D, E, F, G, F, E, D, C]), bpm: 80, keyboard: fiveFingerKeyboard),
            .play("Puja i baixa d'una tirada.", goals([C, D, E, F, G, F, E, D, C]), rounds: 2, keyboard: fiveFingerKeyboard),
        ]
    )

    // 8
    private static let odaA: [Tone] = tones([E, E, F, G, G, F, E, D])
    private static let odaB: [Tone] = tones([C, C, D, E]) + [Tone(midi: E, beats: 1.5), Tone(midi: D, beats: 0.5), Tone(midi: D, beats: 2)]
    private static let odaD: [Tone] = tones([C, C, D, E]) + [Tone(midi: D, beats: 1.5), Tone(midi: C, beats: 0.5), Tone(midi: C, beats: 2)]
    private static let odaWhole: [Tone] = odaA + odaB + odaA + odaD

    static let oda = Lesson(
        id: "1-oda", number: 8,
        title: "Oda a l'alegria",
        summary: "La teva primera peça, amb la mà dreta",
        minutes: 6,
        steps: [
            .look(text: "Amb aquestes cinc notes ja pots tocar una melodia de Beethoven: l'Oda a l'alegria. La farem en quatre trossos.",
                  picture: .keyboard(fiveFingerKeyboard)),
            .listen(text: "Escolta-la sencera.", tones: odaWhole, bpm: 92, keyboard: fiveFingerKeyboard),
            .listen(text: "Primer tros. Comença en el mi, amb el dit 3.", tones: odaA, bpm: 80, keyboard: fiveFingerKeyboard),
            .play("Toca el primer tros.", odaA.map { Goal.note($0.midi) }, rounds: 2, keyboard: fiveFingerKeyboard),
            .listen(text: "Segon tros. Comença en el do.", tones: odaB, bpm: 80, keyboard: fiveFingerKeyboard),
            .play("Toca el segon tros.", odaB.map { Goal.note($0.midi) }, rounds: 2, keyboard: fiveFingerKeyboard),
            .look(text: "El tercer tros és igual que el primer. Ja el saps.", picture: .keyboard(fiveFingerKeyboard)),
            .listen(text: "Quart tros. S'assembla al segon, però acaba en el do.", tones: odaD, bpm: 80, keyboard: fiveFingerKeyboard),
            .play("Toca el quart tros.", odaD.map { Goal.note($0.midi) }, rounds: 2, keyboard: fiveFingerKeyboard),
            .play("Ara tota sencera, sense pressa.", odaWhole.map { Goal.note($0.midi) }, rounds: 1, keyboard: fiveFingerKeyboard),
        ],
        isPiece: true
    )
}
