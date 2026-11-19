import Foundation

// MARK: - Model

/// Amb què toca l'alumne.
enum Instrument: String {
    /// El teclat que hi ha dibuixat a la pantalla.
    case screen
    /// Un piano o teclat de debò; l'app escolta amb el micròfon.
    case real

    static let storageKey = "instrument"
}

/// Una nota d'un exemple: quina i quants temps dura.
struct Tone: Equatable {
    let midi: Int
    var beats: Double = 1
    /// Un silenci: dura, però no sona.
    var rest = false

    static func rest(_ beats: Double = 1) -> Tone { Tone(midi: 60, beats: beats, rest: true) }
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

/// Notes escrites en un pentagrama.
struct Score: Equatable {
    var tones: [Tone] = []
    var clef = true
    /// El nom de cada nota, escrit a sota.
    var names = false
    /// Quants cops dura cada nota, escrit a sota.
    var counts = false
    /// Les ratlles numerades de l'1 al 5.
    var numbered = false
    /// Amb compassos: ratlles verticals, els dos quatres i les notes repartides segons el que duren.
    var bars = false
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
    /// Partitura que s'ensenya amb el pas, si es llegeix.
    var score: Score?

    static let oneOctave = Keyboard()
    static let threeOctaves = Keyboard(low: 48, high: 83)
}

enum Picture: Equatable {
    case symbol(String)
    case keyboard(Keyboard)
    case staff(Score)
}

enum Step: Equatable {
    /// Mira: una idea i un dibuix.
    case look(text: String, picture: Picture)
    /// Escolta: l'app toca.
    /// Amb `pulse`, sonen quatre cops abans i el pols segueix durant l'exemple.
    case listen(text: String, tones: [Tone], bpm: Double, keyboard: Keyboard, pulse: Bool = false)
    /// Toca: l'alumne toca i l'app escolta. `distinct` vol dir que no val repetir la mateixa tecla.
    case play(text: String, goals: [Goal], rounds: Int, keyboard: Keyboard, distinct: Bool)

    /// Toca a temps: l'app marca el pols i mira que cada nota caigui al seu cop.
    case rhythm(text: String, tones: [Tone], bpm: Double, rounds: Int, keyboard: Keyboard)

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
    /// Passos diferents per a qui toca a la pantalla, quan el text d'un piano de debò no hi escau.
    var screenSteps: [Step]?

    func steps(for instrument: Instrument) -> [Step] {
        instrument == .screen ? (screenSteps ?? steps) : steps
    }
}

struct Stage: Identifiable, Equatable {
    let id: Int
    let title: String
    let summary: String
    let lessons: [Lesson]
}

// MARK: - Contingut

enum Course {
    static let stages: [Stage] = [stage1, stage2, stage3]

    /// Etapes que encara no hi són, per ensenyar el camí.
    static let upcoming: [(title: String, summary: String)] = [
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
        ],
        screenSteps: [
            .look(text: "Deixa el telèfon pla sobre una taula i gira'l de costat. Així les tecles són gairebé tan amples com les d'un piano.",
                  picture: .symbol("rectangle.landscape.rotate")),
            .look(text: "Deixa penjar el braç al costat del cos i mira't la mà: queda arrodonida, com si agafés una taronja. Aquesta és la forma.",
                  picture: .symbol("hand.raised.fill")),
            .look(text: "Posa la mà sobre el teclat sense canviar-li la forma. Es toca amb la punta del dit, no amb el dit pla.",
                  picture: .keyboard(.oneOctave)),
            .play("Toca una tecla, la que vulguis. Tres vegades.",
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

    private static func totsElsDosSteps(middleText: String) -> [Step] {
        [
        .look(text: "Hi ha un do a cada grup de dues negres. Tots es diuen do: els de l'esquerra sonen greus i els de la dreta, aguts.",
              picture: .keyboard(Keyboard(low: 48, high: 83, marked: [48, 60, 72], names: [48: "do", 60: "do", 72: "do"]))),
        .listen(text: "Tres dos, del més greu al més agut.",
                tones: [Tone(midi: 48, beats: 2), Tone(midi: 60, beats: 2), Tone(midi: 72, beats: 2)], bpm: 72,
                keyboard: Keyboard(low: 48, high: 83, names: [48: "do", 60: "do", 72: "do"])),
        .play("Toca tres dos diferents, començant per l'esquerra.",
              [Goal(accept: .named(0), label: "do"), Goal(accept: .named(0), label: "do"), Goal(accept: .named(0), label: "do")],
              rounds: 1, keyboard: Keyboard(low: 48, high: 83, marked: [48, 60, 72]), distinct: true),
        .look(text: middleText,
              picture: .keyboard(Keyboard(low: 48, high: 83, marked: [60], names: [60: "do"]))),
        .play("Toca el do del mig. Tres vegades.",
              [Goal(accept: .exact(C), label: "do del mig", key: C)],
              keyboard: Keyboard(low: 48, high: 83)),
        ]
    }

    // 4
    static let totsElsDos = Lesson(
        id: "1-dos", number: 4,
        title: "Tots els dos i el do del mig",
        summary: "N'hi ha un a cada grup de dues negres",
        minutes: 3,
        steps: totsElsDosSteps(middleText: "El do del mig és el que et queda al davant quan seus al centre del piano. Sovint és a prop del nom de la marca."),
        screenSteps: totsElsDosSteps(middleText: "El do del mig és el que queda al centre del teclat. Aquí és el segon dels tres.")
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

    // MARK: Etapa 2 · El pols

    private static func long(_ midi: Int, _ beats: Double) -> Tone { Tone(midi: midi, beats: beats) }
    /// Dues notes dins d'un sol cop.
    private static func pair(_ first: Int, _ second: Int) -> [Tone] { [Tone(midi: first, beats: 0.5), Tone(midi: second, beats: 0.5)] }

    private static let doKeyboard = Keyboard(marked: [C], names: [C: "do"], fingers: [C: 1])

    static let stage2 = Stage(
        id: 2,
        title: "El pols",
        summary: "Tocar a temps: notes llargues i curtes, comptar i callar",
        lessons: [pulsacio, llarguesICurtes, comptar, silenci, duesPerCop, lentaIDePressa, jingle]
    )

    // 9
    static let pulsacio = Lesson(
        id: "2-pulsacio", number: 9,
        title: "La pulsació",
        summary: "Tocar un do seguint el pols",
        minutes: 3,
        steps: [
            .look(text: "Tota la música té un pols, com el cor: uns cops iguals, sempre a la mateixa distància. Tocar bé vol dir tocar amb el pols.",
                  picture: .symbol("metronome.fill")),
            .listen(text: "Primer sonen quatre cops sols, per agafar el pols. Després, un do a cada cop.",
                    tones: tones([C, C, C, C]), bpm: 60, keyboard: doKeyboard, pulse: true),
            .look(text: "Ara tu. Quan premis «Comença» sonaran quatre cops: escolta'ls sense tocar i entra just al cinquè.",
                  picture: .keyboard(doKeyboard)),
            .rhythm(text: "Un do a cada cop. Quatre dos.", tones: tones([C, C, C, C]), bpm: 60, rounds: 2, keyboard: doKeyboard),
            .rhythm(text: "Ara vuit dos seguits, sense perdre el pols.", tones: tones([C, C, C, C, C, C, C, C]), bpm: 66, rounds: 2, keyboard: doKeyboard),
        ]
    )

    // 10
    private static let llargues: [Tone] = [long(C, 2), long(C, 2)] + tones([C, C, C, C])
    private static let llarguesMelodia: [Tone] = tones([C, D]) + [long(E, 2)] + tones([E, D]) + [long(C, 2)]

    static let llarguesICurtes = Lesson(
        id: "2-llargues", number: 10,
        title: "Notes llargues i curtes",
        summary: "Una nota pot durar un cop, o dos",
        minutes: 4,
        steps: [
            .look(text: "No totes les notes duren igual. Una nota pot durar un cop o més d'un. Una nota llarga es toca al primer cop i s'aguanta la tecla, sense tornar-la a tocar.",
                  picture: .symbol("metronome.fill")),
            .listen(text: "Dos dos llargs, de dos cops cadascun, i quatre de curts.",
                    tones: llargues, bpm: 60, keyboard: doKeyboard, pulse: true),
            .rhythm(text: "Dos dos de dos cops i quatre d'un cop. La xifra diu quants cops dura cada nota, i la vora gruixuda, per on va el pols: mentre hi és, aguanta.",
                    tones: llargues, bpm: 60, rounds: 2, keyboard: doKeyboard),
            .listen(text: "Ara amb tres notes: do, re i un mi llarg. Després torna: mi, re i un do llarg.",
                    tones: llarguesMelodia, bpm: 66, keyboard: fiveFingerKeyboard, pulse: true),
            .rhythm(text: "Do, re, mi llarg. Mi, re, do llarg.", tones: llarguesMelodia, bpm: 66, rounds: 2, keyboard: fiveFingerKeyboard),
        ]
    )

    // 11
    private static let compasSencer: [Tone] = [long(C, 4), long(C, 4)]
    private static let unITres: [Tone] = [long(C, 2), long(E, 2), long(C, 2), long(E, 2)]
    private static let quatreIUnaLlarga: [Tone] = tones([C, D, E, F]) + [long(G, 4)]

    static let comptar = Lesson(
        id: "2-comptar", number: 11,
        title: "Comptar fins a quatre",
        summary: "Els cops van de quatre en quatre",
        minutes: 4,
        steps: [
            .look(text: "Els cops es compten de quatre en quatre: u, dos, tres, quatre, u, dos, tres, quatre. L'u sona una mica més agut, perquè no et perdis.",
                  picture: .symbol("4.circle.fill")),
            .listen(text: "Compta en veu alta mentre sona. Hi ha un do a cada u, i dura els quatre cops.",
                    tones: compasSencer, bpm: 66, keyboard: doKeyboard, pulse: true),
            .rhythm(text: "Toca un do només a l'u i aguanta'l fins al quatre. Dues vegades seguides.",
                    tones: compasSencer, bpm: 66, rounds: 2, keyboard: doKeyboard),
            .rhythm(text: "Ara a l'u i al tres: do a l'u, mi al tres.",
                    tones: unITres, bpm: 66, rounds: 2, keyboard: Keyboard(marked: [C, E], names: [C: "do", E: "mi"], fingers: [C: 1, E: 3])),
            .rhythm(text: "Puja de do a fa, una nota a cada cop, i acaba amb un sol de quatre cops.",
                    tones: quatreIUnaLlarga, bpm: 66, rounds: 2, keyboard: fiveFingerKeyboard),
        ]
    )

    // 12
    private static let ambSilenci: [Tone] = tones([C, C]) + [.rest()] + tones([C]) + tones([C, C]) + [.rest()] + tones([C])
    private static let silencisMelodia: [Tone] = [Tone(midi: C), .rest(), Tone(midi: E), .rest()] + tones([G, G, G]) + [.rest()]

    static let silenci = Lesson(
        id: "2-silenci", number: 12,
        title: "El silenci també compta",
        summary: "Callar un cop sense perdre el pols",
        minutes: 4,
        steps: [
            .look(text: "De vegades toca callar. Un silenci dura igual que una nota: el pols continua, però tu no toques. Aixeca el dit i espera el cop següent.",
                  picture: .symbol("hand.raised.fill")),
            .listen(text: "Do, do, silenci, do. Al tercer cop no sona res.",
                    tones: ambSilenci, bpm: 60, keyboard: doKeyboard, pulse: true),
            .rhythm(text: "Do, do, silenci, do. Dues vegades seguides. La ratlla és el silenci.",
                    tones: ambSilenci, bpm: 60, rounds: 2, keyboard: doKeyboard),
            .listen(text: "Ara els silencis van entre nota i nota: do, silenci, mi, silenci, i tres sols.",
                    tones: silencisMelodia, bpm: 66, keyboard: fiveFingerKeyboard, pulse: true),
            .rhythm(text: "Do, silenci, mi, silenci. Sol, sol, sol, silenci.",
                    tones: silencisMelodia, bpm: 66, rounds: 2, keyboard: fiveFingerKeyboard),
        ]
    )

    // 13
    private static let duesNotes: [Tone] = tones([C, C]) + pair(C, C) + tones([C])
    private static let duesNotesMelodia: [Tone] = pair(C, D) + pair(E, F) + [long(G, 2)]
    private static let duesNotesBarreja: [Tone] = tones([E, E]) + pair(E, E) + tones([E]) + pair(D, D) + pair(D, D) + [long(C, 2)]

    static let duesPerCop = Lesson(
        id: "2-dues", number: 13,
        title: "Dues notes per cop",
        summary: "Notes la meitat de llargues",
        minutes: 4,
        steps: [
            .look(text: "En un cop hi caben dues notes, si cadascuna dura la meitat. Compta «u i, dos i»: una nota cau sobre el cop i l'altra, just al mig.",
                  picture: .symbol("metronome.fill")),
            .listen(text: "Do, do, do-do, do. Al tercer cop n'hi ha dues.",
                    tones: duesNotes, bpm: 60, keyboard: doKeyboard, pulse: true),
            .rhythm(text: "Do, do, do-do, do. Les notes petites duren mig cop.",
                    tones: duesNotes, bpm: 60, rounds: 2, keyboard: doKeyboard),
            .listen(text: "Pujant de dues en dues: do-re, mi-fa, i un sol llarg.",
                    tones: duesNotesMelodia, bpm: 60, keyboard: fiveFingerKeyboard, pulse: true),
            .rhythm(text: "Do-re, mi-fa, sol llarg.", tones: duesNotesMelodia, bpm: 60, rounds: 2, keyboard: fiveFingerKeyboard),
            .rhythm(text: "Tot barrejat: notes d'un cop, de mig cop i de dos.",
                    tones: duesNotesBarreja, bpm: 63, rounds: 2, keyboard: fiveFingerKeyboard),
        ]
    )

    // 14
    static let lentaIDePressa = Lesson(
        id: "2-tempo", number: 14,
        title: "Lenta i de pressa",
        summary: "La mateixa melodia a tres velocitats",
        minutes: 5,
        steps: [
            .look(text: "El pols pot anar lent o de pressa. La melodia no canvia: cada nota dura els mateixos cops, però els cops passen més lents o més ràpids.",
                  picture: .symbol("metronome.fill")),
            .listen(text: "El començament de l'Oda a l'alegria, ben lent.",
                    tones: odaA, bpm: 56, keyboard: fiveFingerKeyboard, pulse: true),
            .rhythm(text: "Toca-la lenta. No corris: espera cada cop.", tones: odaA, bpm: 56, rounds: 1, keyboard: fiveFingerKeyboard),
            .listen(text: "La mateixa, a pas de caminar.",
                    tones: odaA, bpm: 76, keyboard: fiveFingerKeyboard, pulse: true),
            .rhythm(text: "Ara a pas de caminar.", tones: odaA, bpm: 76, rounds: 1, keyboard: fiveFingerKeyboard),
            .listen(text: "I de pressa.",
                    tones: odaA, bpm: 100, keyboard: fiveFingerKeyboard, pulse: true),
            .rhythm(text: "De pressa. Si no surt, no passa res: torna-hi.", tones: odaA, bpm: 100, rounds: 1, keyboard: fiveFingerKeyboard),
        ]
    )

    // 15
    private static let jingleA: [Tone] = tones([E, E]) + [long(E, 2)] + tones([E, E]) + [long(E, 2)]
    private static let jingleB: [Tone] = tones([E, G, C, D]) + [long(E, 4)]
    private static let jingleC: [Tone] = tones([F, F, F, F]) + tones([F, E, E]) + pair(E, E)
    private static let jingleD: [Tone] = tones([E, D, D, E]) + [long(D, 2), long(G, 2)]
    private static let jingleE: [Tone] = tones([G, G, F, D]) + [long(C, 4)]
    private static let jingleWhole: [Tone] = jingleA + jingleB + jingleC + jingleD + jingleA + jingleB + jingleC + jingleE

    static let jingle = Lesson(
        id: "2-jingle", number: 15,
        title: "Jingle Bells",
        summary: "Una cançó sencera, amb el seu ritme",
        minutes: 8,
        steps: [
            .look(text: "Amb el que saps ja pots tocar una cançó amb el seu ritme: Jingle Bells. Té notes d'un cop, de dos, de quatre i de mig cop. La farem a trossos.",
                  picture: .keyboard(fiveFingerKeyboard)),
            .listen(text: "Escolta-la sencera.", tones: jingleWhole, bpm: 104, keyboard: fiveFingerKeyboard, pulse: true),
            .listen(text: "Primer tros. Tot són mis: curt, curt, llarg.", tones: jingleA, bpm: 80, keyboard: fiveFingerKeyboard, pulse: true),
            .rhythm(text: "Toca el primer tros.", tones: jingleA, bpm: 80, rounds: 2, keyboard: fiveFingerKeyboard),
            .listen(text: "Segon tros. Acaba amb un mi de quatre cops.", tones: jingleB, bpm: 80, keyboard: fiveFingerKeyboard, pulse: true),
            .rhythm(text: "Toca el segon tros.", tones: jingleB, bpm: 80, rounds: 2, keyboard: fiveFingerKeyboard),
            .listen(text: "Tercer tros. Comença amb el fa, el dit 4, i al final hi ha dos mis de mig cop.", tones: jingleC, bpm: 80, keyboard: fiveFingerKeyboard, pulse: true),
            .rhythm(text: "Toca el tercer tros.", tones: jingleC, bpm: 80, rounds: 2, keyboard: fiveFingerKeyboard),
            .listen(text: "Quart tros. Acaba amb un re i un sol llargs.", tones: jingleD, bpm: 80, keyboard: fiveFingerKeyboard, pulse: true),
            .rhythm(text: "Toca el quart tros.", tones: jingleD, bpm: 80, rounds: 2, keyboard: fiveFingerKeyboard),
            .look(text: "La segona meitat és igual que la primera fins a l'últim tros, que canvia per acabar en el do.",
                  picture: .keyboard(fiveFingerKeyboard)),
            .listen(text: "L'últim tros.", tones: jingleE, bpm: 80, keyboard: fiveFingerKeyboard, pulse: true),
            .rhythm(text: "Toca l'últim tros.", tones: jingleE, bpm: 80, rounds: 2, keyboard: fiveFingerKeyboard),
            .rhythm(text: "Ara tota sencera, sense pressa. Es perdona alguna nota.", tones: jingleWhole, bpm: 80, rounds: 1, keyboard: fiveFingerKeyboard),
        ],
        isPiece: true
    )

    // MARK: Etapa 3 · Llegir

    private static let A = 69, B = 71

    /// Els cinc dits col·locats, sense el nom de les tecles: aquí es llegeix.
    private static let readingKeyboard = Keyboard(marked: [C, D, E, F, G], fingers: [C: 1, D: 2, E: 3, F: 4, G: 5])

    private static func keyboard(_ score: Score) -> Keyboard {
        var keyboard = score.names ? fiveFingerKeyboard : readingKeyboard
        keyboard.score = score
        return keyboard
    }

    /// Tocar llegint, sense pols. No hi pot haver silencis.
    private static func read(_ text: String, _ tones: [Tone], rounds: Int = 2, names: Bool = false, clef: Bool = true, bars: Bool = false) -> Step {
        let score = Score(tones: tones, clef: clef, names: names, bars: bars)
        let goals = tones.map { Goal(accept: .named(Music.pitchClass($0.midi)), label: Music.name($0.midi), key: names ? $0.midi : nil) }
        return .play(text: text, goals: goals, rounds: rounds, keyboard: keyboard(score), distinct: false)
    }

    static let stage3 = Stage(
        id: 3,
        title: "Llegir",
        summary: "El pentagrama, la clau de sol i les cinc notes escrites",
        lessons: [cincRatlles, clauDeSol, doReMiEscrits, faSolEscrits, dibuix, figures, compas, melodiaNova, lluna]
    )

    // 16
    static let cincRatlles = Lesson(
        id: "3-ratlles", number: 16,
        title: "Les cinc ratlles",
        summary: "On s'escriu la música",
        minutes: 3,
        steps: [
            .look(text: "La música s'escriu sobre cinc ratlles. Es compten de baix a dalt: la primera és la de sota i la cinquena, la de dalt.",
                  picture: .staff(Score(clef: false, numbered: true))),
            .look(text: "Les notes són boletes. Una pot anar sobre una ratlla, que la travessa pel mig, o en un espai, entre dues ratlles.",
                  picture: .staff(Score(tones: tones([E, F, G, A, B]), clef: false))),
            .look(text: "Com més amunt està escrita una nota, més aguda sona. Com més avall, més greu.",
                  picture: .staff(Score(tones: tones([C, D, E, F, G]), clef: false))),
            .listen(text: "Escolta com puja: cada nota, un graó més amunt.", tones: tones([C, D, E, F, G]), bpm: 66,
                    keyboard: keyboard(Score(tones: tones([C, D, E, F, G]), clef: false, names: true))),
            read("Toca-les tu, de do a sol. A sota hi ha el nom de cada una.", tones([C, D, E, F, G]), names: true, clef: false),
        ]
    )

    // 17
    static let clauDeSol = Lesson(
        id: "3-clau", number: 17,
        title: "La clau de sol",
        summary: "El dibuix que diu on és el sol",
        minutes: 3,
        steps: [
            .look(text: "El dibuix que hi ha al començament de les ratlles és la clau de sol. Diu quina nota va a cada ratlla.",
                  picture: .staff(Score())),
            .look(text: "El cargol de la clau envolta la segona ratlla. La nota que s'escriu sobre aquesta ratlla és el sol: per això es diu clau de sol.",
                  picture: .staff(Score(tones: tones([G]), names: true))),
            .listen(text: "Així sona el sol. El toques amb el dit 5.", tones: [long(G, 2)], bpm: 60,
                    keyboard: keyboard(Score(tones: tones([G]), names: true))),
            read("Toca el sol escrit. Tres vegades.", tones([G, G, G]), rounds: 1, names: true),
            .look(text: "Des del sol es troben les altres. Cada pas cap avall, de ratlla a espai o d'espai a ratlla, és una tecla blanca cap a l'esquerra: el fa i després el mi.",
                  picture: .staff(Score(tones: tones([G, F, E]), names: true))),
            read("Baixa del sol al mi i torna a pujar.", tones([G, F, E, F, G]), names: true),
        ]
    )

    // 18
    static let doReMiEscrits = Lesson(
        id: "3-doremi", number: 18,
        title: "Do, re i mi escrits",
        summary: "Les tres notes de més avall",
        minutes: 4,
        steps: [
            .look(text: "El do del mig queda per sota de les cinc ratlles i porta una ratlleta pròpia. El re penja de la primera ratlla. El mi és sobre la primera ratlla.",
                  picture: .staff(Score(tones: tones([C, D, E]), names: true))),
            .listen(text: "Do, re, mi. Mira com pugen a mesura que sonen.", tones: tones([C, D, E]), bpm: 66,
                    keyboard: keyboard(Score(tones: tones([C, D, E]), names: true))),
            read("Toca do, re, mi mirant les notes escrites.", tones([C, D, E]), names: true),
            read("Ara sense els noms. Mira on és cada nota.", tones([C, D, E, D, C])),
            read("I desordenades.", tones([E, C, D, E, C])),
        ]
    )

    // 19
    static let faSolEscrits = Lesson(
        id: "3-fasol", number: 19,
        title: "Fa i sol escrits",
        summary: "Les cinc notes, de do a sol",
        minutes: 4,
        steps: [
            .look(text: "El fa s'escriu al primer espai, entre la primera ratlla i la segona. El sol, ja ho saps, sobre la segona ratlla.",
                  picture: .staff(Score(tones: tones([F, G]), names: true))),
            .listen(text: "Les cinc notes, escrites i tocades.", tones: tones([C, D, E, F, G]), bpm: 72,
                    keyboard: keyboard(Score(tones: tones([C, D, E, F, G]), names: true))),
            read("Mi, fa, sol, fa, mi.", tones([E, F, G, F, E]), names: true),
            read("Sense noms: de do a sol.", tones([C, D, E, F, G])),
            read("I barrejades. No corris.", tones([G, E, F, D, C])),
        ]
    )

    // 20
    static let dibuix = Lesson(
        id: "3-dibuix", number: 20,
        title: "Pujar, baixar i repetir",
        summary: "Llegir el dibuix, no els noms",
        minutes: 5,
        steps: [
            .look(text: "No cal dir el nom de cada nota. Mira el dibuix: si la següent és més amunt, toca el dit següent; si és més avall, l'anterior; si és a la mateixa altura, repeteix.",
                  picture: .staff(Score(tones: tones([E, E, F, G])))),
            read("Comença en el mi, amb el dit 3, i segueix el dibuix. La reconeixeràs.", odaA, rounds: 1),
            .look(text: "De vegades la nota salta: de ratlla a ratlla, o d'espai a espai. Llavors et saltes una tecla i un dit.",
                  picture: .staff(Score(tones: tones([C, E, G])))),
            read("De ratlla en ratlla: dits 1, 3 i 5.", tones([C, E, G, E, C])),
            read("D'espai en espai, i acaba en el mi.", tones([D, F, D, F, E])),
            read("Passos i salts barrejats.", tones([C, D, E, C, E, G, F, D, C]), rounds: 1),
        ]
    )

    // 21
    private static let figuresExemple: [Tone] = tones([E, E]) + [long(E, 2), long(E, 4)]
    private static let figuresBarreja: [Tone] = tones([C, C]) + pair(D, D) + tones([E]) + [Tone(midi: E), .rest(), long(C, 2)]

    static let figures = Lesson(
        id: "3-figures", number: 21,
        title: "Llargues i curtes, escrites",
        summary: "La forma de la nota diu quant dura",
        minutes: 5,
        steps: [
            .look(text: "La forma de la nota diu quant dura. Negra i amb pal, un cop: és la negra. Blanca i amb pal, dos cops: la blanca. Blanca i sense pal, quatre cops: la rodona.",
                  picture: .staff(Score(tones: [Tone(midi: E), long(E, 2), long(E, 4)], counts: true))),
            .listen(text: "Dues negres, una blanca i una rodona.", tones: figuresExemple, bpm: 63,
                    keyboard: keyboard(Score(tones: figuresExemple, counts: true)), pulse: true),
            .rhythm(text: "Toca-ho llegint. A sota de cada nota hi ha un punt per cada cop que dura: s'encenen amb el pols. La blanca s'aguanta dos cops i la rodona, quatre.", tones: figuresExemple, bpm: 63, rounds: 2,
                    keyboard: keyboard(Score(tones: figuresExemple, counts: true))),
            .look(text: "La que porta un ganxo al pal dura mig cop: és la corxera. Dues corxeres fan un cop.",
                  picture: .staff(Score(tones: pair(E, E) + tones([E]), counts: true))),
            .look(text: "I el silenci d'un cop s'escriu amb aquest senyal.",
                  picture: .staff(Score(tones: [Tone(midi: E), .rest(), Tone(midi: E), .rest()], counts: true))),
            .rhythm(text: "Tot junt, i sense els números.", tones: figuresBarreja, bpm: 63, rounds: 2,
                    keyboard: keyboard(Score(tones: figuresBarreja))),
        ]
    )

    // 22
    private static let compasA: [Tone] = tones([C, D, E, F]) + [long(G, 2), long(E, 2)] + tones([F, F, E, E]) + [long(D, 2), long(C, 2)]
    private static let compasB: [Tone] = [long(E, 2), long(G, 2)] + tones([F, E]) + [long(D, 2)] + tones([C, D, E, F]) + [long(E, 4)]

    static let compas = Lesson(
        id: "3-compas", number: 22,
        title: "El compàs",
        summary: "Les ratlles verticals i els dos quatres",
        minutes: 5,
        steps: [
            .look(text: "Les ratlles verticals parteixen la música en compassos. Els dos quatres del començament diuen que a cada compàs hi caben quatre cops.",
                  picture: .staff(Score(tones: Array(compasA.prefix(6)), bars: true))),
            .look(text: "Per comptar, torna a començar a cada ratlla vertical: u, dos, tres, quatre. La ratlla doble del final vol dir que s'ha acabat.",
                  picture: .staff(Score(tones: compasA, bars: true))),
            .listen(text: "Segueix-la amb la vista mentre sona.", tones: compasA, bpm: 69,
                    keyboard: keyboard(Score(tones: compasA, bars: true)), pulse: true),
            .rhythm(text: "Toca-la llegint i comptant.", tones: compasA, bpm: 66, rounds: 1,
                    keyboard: keyboard(Score(tones: compasA, bars: true))),
            .rhythm(text: "Aquesta no l'has sentida. Llegeix-la.", tones: compasB, bpm: 66, rounds: 1,
                    keyboard: keyboard(Score(tones: compasB, bars: true))),
        ]
    )

    // 23
    private static let novaA: [Tone] = tones([E, F, G, E]) + [long(F, 2), long(D, 2)] + tones([E, D, C, D]) + [long(E, 2), long(C, 2)]
    private static let novaB: [Tone] = tones([G, E, F, D]) + tones([E, C]) + [long(D, 2)] + tones([G, E, F, D]) + tones([E, D]) + [long(C, 2)]

    static let melodiaNova = Lesson(
        id: "3-nova", number: 23,
        title: "Una melodia que no has sentit mai",
        summary: "Llegir sense escoltar abans",
        minutes: 6,
        steps: [
            .look(text: "Ara una melodia que no has sentit mai. Abans de tocar, mira-la: on comença, on puja, on baixa i on hi ha notes llargues.",
                  picture: .staff(Score(tones: novaA, bars: true))),
            read("Primer només les notes, sense pols. Comença en el mi.", novaA, rounds: 1, bars: true),
            .rhythm(text: "Ara amb el pols, comptant.", tones: novaA, bpm: 63, rounds: 1,
                    keyboard: keyboard(Score(tones: novaA, bars: true))),
            .listen(text: "Escolta-la: era així?", tones: novaA, bpm: 76,
                    keyboard: keyboard(Score(tones: novaA, bars: true)), pulse: true),
            .look(text: "Una altra. Mira-la sencera abans de començar: comença en el sol, amb el dit 5.",
                  picture: .staff(Score(tones: novaB, bars: true))),
            .rhythm(text: "Directament amb el pols.", tones: novaB, bpm: 63, rounds: 1,
                    keyboard: keyboard(Score(tones: novaB, bars: true))),
        ]
    )

    // 24
    private static let llunaA: [Tone] = tones([C, C, C, D]) + [long(E, 2), long(D, 2)]
    private static let llunaB: [Tone] = tones([C, E, D, D]) + [long(C, 4)]
    private static let llunaTota: [Tone] = llunaA + llunaB

    static let lluna = Lesson(
        id: "3-lluna", number: 24,
        title: "Au clair de la lune",
        summary: "Una peça llegida, sense sentir-la abans",
        minutes: 7,
        steps: [
            .look(text: "La peça d'aquesta etapa no l'escoltaràs abans: la llegiràs. És el començament d'Au clair de la lune, una cançó francesa molt antiga.",
                  picture: .staff(Score(tones: llunaTota, bars: true))),
            read("Els dos primers compassos, només les notes.", llunaA, bars: true),
            read("Els dos últims.", llunaB, bars: true),
            .rhythm(text: "Ara sencera, amb el pols.", tones: llunaTota, bpm: 66, rounds: 2,
                    keyboard: keyboard(Score(tones: llunaTota, bars: true))),
            .listen(text: "Escolta-la. Ho has llegit bé?", tones: llunaTota, bpm: 84,
                    keyboard: keyboard(Score(tones: llunaTota, bars: true)), pulse: true),
            .rhythm(text: "Per acabar, dues vegades seguides i una mica més de pressa.", tones: llunaTota + llunaTota, bpm: 84, rounds: 1,
                    keyboard: keyboard(Score(tones: llunaTota, bars: true))),
        ],
        isPiece: true
    )
}
