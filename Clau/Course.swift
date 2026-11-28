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
    /// Una nota de sota que s'aguanta: sona i s'escriu així de llarga, però la següent comença al cap de `beats`,
    /// mentre aquesta encara sona. Pel micròfon l'app no ho pot corregir (només sent una nota): l'alumne s'escolta.
    var hold: Double?
    /// Una segona nota que comença alhora, amb l'altra mà. El micròfon no les sent totes dues: només es comproven
    /// amb el teclat de la pantalla o amb un piano connectat per cable; si no, l'alumne s'escolta.
    var also: Int?
    /// La nota de l'altra mà (`also`) s'aguanta més: sona i s'escriu així de llarga, mentre la primera mà continua.
    var alsoHold: Double?
    /// Si és una tecla negra, s'escriu amb bemoll (mi♭, a la ratlla del mi) i no amb sostingut (re♯, a la del re).
    var flat = false

    /// El que dura escrita i el que sona.
    var written: Double { hold ?? beats }
    /// El que dura la nota de l'altra mà.
    var alsoWritten: Double { alsoHold ?? written }
    /// El nom de la nota tal com s'escriu.
    var name: String { Music.name(midi, flat: flat) }

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
    /// Clau de fa, per a la mà esquerra.
    var bass = false
    /// La música s'acaba aquí: ratlla doble final. Si és un tros d'una peça més llarga, ratlla simple.
    var ends = true
    /// Es toca dues vegades: signe de repetició al final.
    var repeats = false
    /// Els dos pentagrames de les dues mans: del do del mig cap amunt, la clau de sol; cap avall, la de fa.
    var grand = false
    /// Cops a cada compàs: 4 (el quatre per quatre de sempre) o 3 (tres per quatre, com un vals).
    var meter = 4
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
    static let stages: [Stage] = [stage1, stage2, stage3, stage4, stage5, stage6]

    /// Etapes que encara no hi són, per ensenyar el camí.
    static let upcoming: [(title: String, summary: String)] = [
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
            .rhythm(text: "Primer, un do llarg i dos de curts. La xifra diu quants cops dura cada nota, i la vora gruixuda, per on va el pols: mentre hi és, aguanta.",
                    tones: [long(C, 2)] + tones([C, C]), bpm: 60, rounds: 2, keyboard: doKeyboard),
            .rhythm(text: "Ara dos dos de dos cops i quatre d'un cop.",
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
        summary: "Comptar els cops de quatre en quatre",
        minutes: 4,
        steps: [
            .look(text: "En aquests exercicis comptarem els cops de quatre en quatre: u, dos, tres, quatre, u, dos, tres, quatre. L'u sona una mica més agut, perquè no et perdis.",
                  picture: .symbol("4.circle.fill")),
            .listen(text: "Compta en veu alta mentre sona. Hi ha un do a cada u, i dura els quatre cops.",
                    tones: compasSencer, bpm: 66, keyboard: doKeyboard, pulse: true),
            .rhythm(text: "Toca un do només a l'u i aguanta'l fins al quatre. Dues vegades seguides.",
                    tones: compasSencer, bpm: 66, rounds: 2, keyboard: doKeyboard),
            .rhythm(text: "Puja de do a fa, una nota a cada cop, i acaba amb un sol de quatre cops.",
                    tones: quatreIUnaLlarga, bpm: 66, rounds: 2, keyboard: fiveFingerKeyboard),
            .rhythm(text: "Primer, un do de dos cops i dos mis d'un cop.",
                    tones: [long(C, 2)] + tones([E, E]), bpm: 66, rounds: 2, keyboard: Keyboard(marked: [C, E], names: [C: "do", E: "mi"], fingers: [C: 1, E: 3])),
            .rhythm(text: "Ara a l'u i al tres: do a l'u, mi al tres. Cada nota s'aguanta dos cops.",
                    tones: unITres, bpm: 66, rounds: 2, keyboard: Keyboard(marked: [C, E], names: [C: "do", E: "mi"], fingers: [C: 1, E: 3])),
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
            .rhythm(text: "Ara els dos primers trossos seguits.", tones: jingleA + jingleB, bpm: 80, rounds: 1, keyboard: fiveFingerKeyboard),
            .rhythm(text: "I el tercer i el quart seguits.", tones: jingleC + jingleD, bpm: 80, rounds: 1, keyboard: fiveFingerKeyboard),
            .rhythm(text: "Ara la primera meitat seguida: els quatre primers trossos.", tones: jingleA + jingleB + jingleC + jingleD, bpm: 80, rounds: 1, keyboard: fiveFingerKeyboard),
            .rhythm(text: "El tercer tros i l'últim seguits.", tones: jingleC + jingleE, bpm: 80, rounds: 1, keyboard: fiveFingerKeyboard),
            .rhythm(text: "I la segona meitat, que acaba en el do.", tones: jingleA + jingleB + jingleC + jingleE, bpm: 80, rounds: 1, keyboard: fiveFingerKeyboard),
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
    private static func read(_ text: String, _ tones: [Tone], rounds: Int = 2, names: Bool = false, clef: Bool = true, bars: Bool = false, ends: Bool = true) -> Step {
        let score = Score(tones: tones, clef: clef, names: names, bars: bars, ends: ends)
        let goals = tones.map { Goal(accept: .named(Music.pitchClass($0.midi)), label: $0.name, key: names ? $0.midi : nil) }
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
            .look(text: "No cal dir el nom de cada nota. Mira el dibuix: si la següent és un graó més amunt, toca el dit següent; si és un graó més avall, l'anterior; si és a la mateixa altura, repeteix.",
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
            .rhythm(text: "Toca-ho llegint. Sota cada nota, un punt per cop: s'encenen amb el pols.", tones: figuresExemple, bpm: 63, rounds: 2,
                    keyboard: keyboard(Score(tones: figuresExemple, counts: true))),
            .look(text: "La que porta un ganxo al pal dura mig cop: és la corxera. Dues corxeres fan un cop.",
                  picture: .staff(Score(tones: pair(E, E) + tones([E]), counts: true))),
            .look(text: "I el silenci d'un cop s'escriu amb aquest senyal.",
                  picture: .staff(Score(tones: [Tone(midi: E), .rest(), Tone(midi: E), .rest()], counts: true))),
            .rhythm(text: "Tot junt, i sense els punts.", tones: figuresBarreja, bpm: 63, rounds: 2,
                    keyboard: keyboard(Score(tones: figuresBarreja))),
        ]
    )

    // 22
    private static let compasA: [Tone] = tones([C, D, E, F]) + [long(G, 2), long(E, 2)] + tones([F, F, E, E]) + [long(D, 2), long(C, 2)]
    /// El ritme de `compasA`, tot amb el do: per escoltar el clic sense haver de llegir.
    /// Els dos primers compassos, tot amb el do: només el ritme, quatre negres i dues blanques.
    private static let compasRitme: [Tone] = compasA.prefix(6).map { Tone(midi: C, beats: $0.beats) }
    private static let compasB: [Tone] = [long(E, 2), long(G, 2)] + tones([F, E]) + [long(D, 2)] + tones([C, D, E, F]) + [long(E, 4)]

    static let compas = Lesson(
        id: "3-compas", number: 22,
        title: "El compàs",
        summary: "Les ratlles verticals i els dos quatres",
        minutes: 7,
        steps: [
            .look(text: "Les ratlles verticals parteixen la música en compassos. Al començament hi ha dos quatres: el de dalt diu que a cada compàs hi caben quatre cops, i el de baix, que cada cop és una negra.",
                  picture: .staff(Score(tones: Array(compasA.prefix(6)), bars: true, ends: false))),
            .look(text: "Per comptar, torna a començar a cada ratlla vertical: u, dos, tres, quatre. La ratlla doble del final vol dir que s'ha acabat.",
                  picture: .staff(Score(tones: compasA, bars: true))),
            .listen(text: "Segueix-la amb la vista mentre sona.", tones: compasA, bpm: 69,
                    keyboard: keyboard(Score(tones: compasA, bars: true)), pulse: true),
            read("Abans del pols, només les notes, sense pressa.", compasA, rounds: 1, bars: true),
            .rhythm(text: "Ara només el ritme, tot amb el do. No pensis en les notes: fes que cada do caigui just amb el pols. Les blanques duren dos cops.",
                    tones: compasRitme, bpm: 66, rounds: 1,
                    keyboard: keyboard(Score(tones: compasRitme, counts: true, bars: true, ends: false))),
            .rhythm(text: "El mateix ritme, ara amb les notes. Sota cada nota s'encén un punt a cada cop: canvia de nota quan s'encén el primer punt de la següent.",
                    tones: Array(compasA.prefix(6)), bpm: 66, rounds: 1,
                    keyboard: keyboard(Score(tones: Array(compasA.prefix(6)), counts: true, bars: true, ends: false))),
            .rhythm(text: "Ara sencera. Les blanques s'aguanten fins que s'han encès els dos punts.", tones: compasA, bpm: 66, rounds: 1,
                    keyboard: keyboard(Score(tones: compasA, counts: true, bars: true))),
            read("Aquesta no l'has sentida. Primer només les notes.", compasB, rounds: 1, bars: true),
            .rhythm(text: "Ara amb el pols.", tones: compasB, bpm: 66, rounds: 1,
                    keyboard: keyboard(Score(tones: compasB, counts: true, bars: true))),
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
                    keyboard: keyboard(Score(tones: novaA, counts: true, bars: true))),
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
        minutes: 8,
        steps: [
            .look(text: "La peça d'aquesta etapa no l'escoltaràs abans: la llegiràs. És el començament d'Au clair de la lune, una cançó francesa molt antiga.",
                  picture: .staff(Score(tones: llunaTota, bars: true))),
            read("Els dos primers compassos, només les notes.", llunaA, bars: true, ends: false),
            read("Els dos últims.", llunaB, bars: true),
            .rhythm(text: "Ara sencera, amb el pols.", tones: llunaTota, bpm: 66, rounds: 2,
                    keyboard: keyboard(Score(tones: llunaTota, counts: true, bars: true))),
            .listen(text: "Escolta-la. Ho has llegit bé?", tones: llunaTota, bpm: 84,
                    keyboard: keyboard(Score(tones: llunaTota, bars: true)), pulse: true),
            .rhythm(text: "On es torna a començar: el final i, tot seguit, el principi. Aguanta el do llarg els quatre cops.", tones: llunaB + llunaA, bpm: 66, rounds: 2,
                    keyboard: keyboard(Score(tones: llunaB + llunaA, counts: true, bars: true, ends: false))),
            .rhythm(text: "Per acabar, dues vegades seguides i una mica més de pressa. Els dos punts del final volen dir que es torna a començar.", tones: llunaTota + llunaTota, bpm: 76, rounds: 1,
                    keyboard: keyboard(Score(tones: llunaTota, bars: true, repeats: true))),
        ],
        isPiece: true
    )

    // MARK: Etapa 4 · La mà esquerra

    private static let lC = 48, lD = 50, lE = 52, lF = 53, lG = 55

    /// Els dits de la mà esquerra: el petit al do greu i el polze al sol, al revés que la dreta.
    private static let leftFingers: [Int: Int] = [lC: 5, lD: 4, lE: 3, lF: 2, lG: 1]
    private static let leftNames: [Int: String] = [lC: "do", lD: "re", lE: "mi", lF: "fa", lG: "sol"]
    private static let leftNamed = Keyboard(low: 48, high: 59, marked: [lC, lD, lE, lF, lG], names: leftNames, fingers: leftFingers)
    private static let leftPlain = Keyboard(low: 48, high: 59, marked: [lC, lD, lE, lF, lG], fingers: leftFingers)
    /// Les dues mans col·locades: la dreta sobre el do del mig i l'esquerra una octava més avall.
    private static let bothHands = Keyboard(
        low: 48, high: 67,
        marked: [lC, lD, lE, lF, lG, C, D, E, F, G],
        fingers: leftFingers.merging([C: 1, D: 2, E: 3, F: 4, G: 5]) { $1 }
    )

    private static func leftKeyboard(_ score: Score) -> Keyboard {
        var keyboard = score.names ? leftNamed : leftPlain
        keyboard.score = score
        return keyboard
    }

    private static func handsKeyboard(_ score: Score) -> Keyboard {
        var keyboard = bothHands
        keyboard.score = score
        return keyboard
    }

    /// La mateixa melodia, una octava més greu.
    private static func down(_ tones: [Tone]) -> [Tone] {
        tones.map { Tone(midi: $0.midi - 12, beats: $0.beats, rest: $0.rest) }
    }

    /// Notes amb el seu lloc exacte: a la mà esquerra importa quina octava, no només quina nota.
    private static func exactGoals(_ midis: [Int], keys: Bool = true) -> [Goal] {
        midis.map { Goal(accept: .exact($0), label: Music.name($0), key: keys ? $0 : nil) }
    }

    /// Tocar llegint, sense pols, amb la mà esquerra (clau de fa) o amb les dues (els dos pentagrames).
    private static func readHands(_ text: String, _ tones: [Tone], rounds: Int = 2, names: Bool = false,
                                  bars: Bool = false, both: Bool = false) -> Step {
        let score = Score(tones: tones, clef: true, names: names, bars: bars, bass: !both, grand: both)
        let keyboard = both ? handsKeyboard(score) : leftKeyboard(score)
        let goals = exactGoals(tones.map(\.midi), keys: names)
        return .play(text: text, goals: goals, rounds: rounds, keyboard: keyboard, distinct: false)
    }

    static let stage4 = Stage(
        id: 4,
        title: "La mà esquerra",
        summary: "Els mateixos dits al revés, la clau de fa i passar d'una mà a l'altra",
        lessons: [esquerra, esquerraDosSol, clauDeFa, esquerraLlargues, esquerraMelodia, canviarDeMa, duesClaus, odaDuesMans]
    )

    // 25
    static let esquerra = Lesson(
        id: "4-esquerra", number: 25,
        title: "La mà esquerra",
        summary: "Els mateixos dits, però al revés",
        minutes: 3,
        steps: [
            .look(text: "La mà esquerra té els mateixos dits numerats: el polze és l'1 i el petit el 5. Però sobre el teclat van al revés: el petit queda a l'esquerra i el polze a la dreta.",
                  picture: .symbol("hand.raised.fingers.spread.fill")),
            .look(text: "Posa el petit (dit 5) de la mà esquerra sobre el do anterior al do del mig. De l'un a l'altre hi ha vuit tecles blanques, comptant-hi tots dos: aquest camí fins a la nota del mateix nom es diu una octava. Després, un dit a cada tecla blanca. El polze (dit 1) queda sobre el sol.",
                  picture: .keyboard(leftNamed)),
            .listen(text: "Aquestes són les cinc notes de la mà esquerra. Són les mateixes que a la dreta, però més greus.",
                    tones: tones([lC, lD, lE, lF, lG]), bpm: 72, keyboard: leftNamed),
            .play("Sense moure la mà de lloc, toca amb el dit que et demano.",
                  [Goal(accept: .exact(lC), label: "dit 5", key: lC), Goal(accept: .exact(lE), label: "dit 3", key: lE), Goal(accept: .exact(lG), label: "dit 1", key: lG)],
                  rounds: 2, keyboard: Keyboard(low: 48, high: 59, fingers: leftFingers)),
            .play("Ara els dos que falten.",
                  [Goal(accept: .exact(lD), label: "dit 4", key: lD), Goal(accept: .exact(lF), label: "dit 2", key: lF)],
                  rounds: 2, keyboard: Keyboard(low: 48, high: 59, fingers: leftFingers)),
        ]
    )

    // 26
    static let esquerraDosSol = Lesson(
        id: "4-dosol", number: 26,
        title: "Do a sol amb l'esquerra",
        summary: "Pujar i baixar amb els dits 5, 4, 3, 2 i 1",
        minutes: 4,
        steps: [
            .look(text: "Amb la mà esquerra pugem igual que amb la dreta, però comptant els dits al revés: 5, 4, 3, 2, 1. Les notes són les mateixes, una octava més greu.",
                  picture: .keyboard(leftNamed)),
            .listen(text: "Do, re, mi, fa, sol.", tones: tones([lC, lD, lE, lF, lG]), bpm: 72, keyboard: leftNamed),
            .play("Puja de do a sol: dits 5, 4, 3, 2 i 1.", exactGoals([lC, lD, lE, lF, lG]), rounds: 2, keyboard: leftNamed),
            .play("Baixa de sol a do: dits 1, 2, 3, 4 i 5.", exactGoals([lG, lF, lE, lD, lC]), rounds: 2, keyboard: leftNamed),
            .listen(text: "Pujar i baixar d'una tirada.", tones: tones([lC, lD, lE, lF, lG, lF, lE, lD, lC]), bpm: 80, keyboard: leftNamed),
            .play("Puja i baixa sense aturar-te.", exactGoals([lC, lD, lE, lF, lG, lF, lE, lD, lC]), rounds: 2, keyboard: leftNamed),
        ]
    )

    // 27
    static let clauDeFa = Lesson(
        id: "4-clau-fa", number: 27,
        title: "La clau de fa",
        summary: "La clau de la mà esquerra",
        minutes: 4,
        steps: [
            .look(text: "La música de la mà esquerra s'escriu sovint amb una altra clau: la clau de fa. Els dos punts envolten la quarta ratlla, i aquesta és la ratlla del fa.",
                  picture: .staff(Score(tones: tones([lF]), names: true, bass: true))),
            .look(text: "Aquí les ratlles tenen uns altres noms que en clau de sol, però les notes pugen igual: com més amunt, més aguda. Aquestes són les cinc notes de la mà esquerra.",
                  picture: .staff(Score(tones: tones([lC, lD, lE, lF, lG]), names: true, bass: true))),
            .listen(text: "Mira-les mentre sonen.", tones: tones([lC, lD, lE, lF, lG]), bpm: 66,
                    keyboard: leftKeyboard(Score(tones: tones([lC, lD, lE, lF, lG]), names: true, bass: true))),
            readHands("Toca-les mirant la partitura. A sota hi ha el nom de cada una.", [lC, lD, lE, lF, lG].map { Tone(midi: $0) }, names: true),
            readHands("Ara sense els noms: del sol cap avall.", [lG, lF, lE, lD, lC].map { Tone(midi: $0) }),
            readHands("I desordenades. Mira on és cada nota.", [lE, lC, lD, lG, lF].map { Tone(midi: $0) }),
        ]
    )

    // 28
    private static let baseA: [Tone] = [long(lC, 4), long(lG, 4)]
    private static let baseBlanques: [Tone] = [long(lC, 2), long(lG, 2)]
    private static let baseB: [Tone] = [long(lC, 2), long(lG, 2), long(lC, 2), Tone(midi: lF), Tone(midi: lE)]

    static let esquerraLlargues = Lesson(
        id: "4-llargues", number: 28,
        title: "Notes llargues a l'esquerra",
        summary: "La mà esquerra fa de base",
        minutes: 5,
        steps: [
            .look(text: "Sovint la mà esquerra toca notes llargues, que fan de base mentre la dreta fa la melodia. S'aguanten la tecla i es compta fins que els punts de sota s'han encès tots.",
                  picture: .staff(Score(tones: baseA, counts: true, bass: true))),
            .listen(text: "Dues rodones: un do de quatre cops i un sol de quatre cops.", tones: baseA, bpm: 66,
                    keyboard: leftKeyboard(Score(tones: baseA, counts: true, bass: true)), pulse: true),
            .rhythm(text: "Toca el do i aguanta'l quatre cops. Després, el sol.", tones: baseA, bpm: 66, rounds: 2,
                    keyboard: leftKeyboard(Score(tones: baseA, counts: true, bass: true))),
            .listen(text: "Ara amb tres blanques i dues negres que baixen al final.", tones: baseB, bpm: 66,
                    keyboard: leftKeyboard(Score(tones: baseB, counts: true, bass: true)), pulse: true),
            .rhythm(text: "Primer, només un do i un sol de dos cops cadascun.", tones: baseBlanques, bpm: 66, rounds: 2,
                    keyboard: leftKeyboard(Score(tones: baseBlanques, counts: true, bass: true))),
            .rhythm(text: "Ara tot: do i sol, de dos cops cadascun; un altre do; i després fa i mi d'un cop.", tones: baseB, bpm: 66, rounds: 2,
                    keyboard: leftKeyboard(Score(tones: baseB, counts: true, bass: true))),
            .rhythm(text: "Ara sense els punts: només amb el que veus escrit.", tones: baseB, bpm: 66, rounds: 1,
                    keyboard: leftKeyboard(Score(tones: baseB, bass: true))),
        ]
    )

    // 29
    private static let odaLowA = down(odaA), odaLowB = down(odaB), odaLowD = down(odaD)

    static let esquerraMelodia = Lesson(
        id: "4-melodia", number: 29,
        title: "Una melodia amb l'esquerra",
        summary: "L'Oda a l'alegria, una octava més greu",
        minutes: 6,
        steps: [
            .look(text: "Ja coneixes l'Oda a l'alegria. Aquesta vegada la toques amb la mà esquerra, una octava més greu. Comença pel mi, amb el dit 3.",
                  picture: .staff(Score(tones: odaLowA, bass: true))),
            .listen(text: "Primer tros.", tones: odaLowA, bpm: 80, keyboard: leftKeyboard(Score(tones: odaLowA, bass: true))),
            readHands("Toca el primer tros.", odaLowA, rounds: 2),
            .look(text: "Al segon tros hi ha una nota amb un punt al costat. El punt allarga la nota la meitat: aquesta dura un cop i mig, i la de després, que porta una cua, només mig. Aquí només es toquen les notes, sense pols.",
                  picture: .staff(Score(tones: odaLowB, counts: true, bass: true))),
            .listen(text: "Segon tros. Comença en el do, amb el dit 5.", tones: odaLowB, bpm: 80, keyboard: leftKeyboard(Score(tones: odaLowB, bass: true))),
            readHands("Toca el segon tros.", odaLowB, rounds: 2),
            readHands("Els dos trossos seguits, sense pressa.", odaLowA + odaLowB, rounds: 1),
        ]
    )

    // 30
    private static let changeA: [Int] = [E, D, C, lG, lF, lE]
    private static let changeB: [Int] = [lE, lF, lG, C, D, E]
    private static let changeC: [Int] = [C, lC, D, lD, E, lE]

    static let canviarDeMa = Lesson(
        id: "4-canviar", number: 30,
        title: "Canviar de mà",
        summary: "Una nota amb la dreta, la següent amb l'esquerra",
        minutes: 6,
        steps: [
            .look(text: "Quan la música té dues claus, la dreta toca les notes del pentagrama de dalt (clau de sol) i l'esquerra les del de sota (clau de fa). Els dos pentagrames es llegeixen alhora.",
                  picture: .staff(Score(tones: tones(changeA), grand: true))),
            .look(text: "Posa les dues mans: la dreta amb el polze sobre el do del mig i l'esquerra amb el petit sobre el do que queda una octava més avall.",
                  picture: .keyboard(bothHands)),
            .listen(text: "Baixa de mi a mi: la dreta fa les tres primeres i l'esquerra continua.", tones: tones(changeA), bpm: 66,
                    keyboard: handsKeyboard(Score(tones: tones(changeA), grand: true))),
            readHands("Toca-les. Les tres primeres amb la dreta i les altres tres amb l'esquerra.", tones(changeA), rounds: 2, both: true),
            readHands("Ara a l'inrevés: primer l'esquerra, després la dreta.", tones(changeB), rounds: 2, both: true),
            readHands("Una nota a cada mà, alternant.", tones(changeC), rounds: 2, both: true),
        ]
    )

    // 31
    private static let claus1: [Int] = [lC, lE, lG, C, E, G]
    private static let claus2: [Int] = [G, E, C, lG, lE, lC]
    private static let claus3: [Int] = [E, lG, D, lF, C, lE]
    private static let claus4: [Int] = [C, E, G, E, lG, lE, lC, lE]

    static let duesClaus = Lesson(
        id: "4-claus", number: 31,
        title: "Llegir les dues claus",
        summary: "El pentagrama de dalt i el de sota",
        minutes: 6,
        steps: [
            .look(text: "Com més amunt s'escriu una nota, més aguda sona, passi o no d'un pentagrama a l'altre. Les notes del pentagrama de sota són més greus que les del de dalt.",
                  picture: .staff(Score(tones: tones(claus1), grand: true))),
            .look(text: "El do del mig és el pont entre les dues claus. S'escriu amb una ratlleta pròpia, just sota el pentagrama de dalt, i normalment el toca la dreta.",
                  picture: .staff(Score(tones: tones([lG, C]), names: true, grand: true))),
            readHands("Toca-les mirant on són escrites. A sota hi ha el nom.", tones(claus1), rounds: 2, names: true, both: true),
            readHands("Ara a l'inrevés, i sense els noms.", tones(claus2), rounds: 2, both: true),
            readHands("Barrejades: mira a quin pentagrama és cada nota.", tones(claus3), rounds: 2, both: true),
            readHands("Una de més llarga.", tones(claus4), rounds: 1, both: true),
        ]
    )

    // 32
    private static let odaMix: [Tone] = odaA + odaLowB + odaA + odaLowD

    static let odaDuesMans = Lesson(
        id: "4-oda", number: 32,
        title: "Oda a l'alegria, mà amb mà",
        summary: "Una frase amb cada mà",
        minutes: 8,
        steps: [
            .look(text: "L'Oda a l'alegria, un cop més. Ara passa d'una mà a l'altra: la dreta fa la primera frase i la tercera, i l'esquerra, la segona i la quarta, que acaba en el do. Mira on és escrita cada una.",
                  picture: .staff(Score(tones: odaMix, bars: true, grand: true))),
            .listen(text: "Escolta-la sencera.", tones: odaMix, bpm: 92,
                    keyboard: handsKeyboard(Score(tones: odaMix, bars: true, grand: true))),
            readHands("Primer tros: la dreta, a dalt.", odaA, rounds: 2, both: true),
            readHands("Segon tros: ara l'esquerra, a sota.", odaLowB, rounds: 2, both: true),
            readHands("El tercer tros és igual que el primer: torna-hi amb la dreta.", odaA, rounds: 1, both: true),
            readHands("El quart, amb l'esquerra. S'assembla al segon, però acaba en el do.", odaLowD, rounds: 2, both: true),
            readHands("Ara tota sencera, passant d'una mà a l'altra.", odaMix, rounds: 1, bars: true, both: true),
        ],
        isPiece: true
    )

    // MARK: Etapa 5 · Les dues mans

    static let stage5 = Stage(
        id: 5,
        title: "Les dues mans",
        summary: "Baix i melodia, mans juntes",
        lessons: [notaDeSota, canviarSota, mansAlhora, contrari, odaAcompanyada]
    )

    /// Una nota de l'esquerra que dura un compàs sencer i sona sola el primer cop; la dreta toca als cops 2, 3 i 4.
    private static func underneath(_ bass: Int, _ melody: [Int]) -> [Tone] {
        [Tone(midi: bass, beats: 1, hold: 4)] + tones(melody)
    }

    private static func handsRhythm(_ text: String, _ tones: [Tone], rounds: Int = 2, counts: Bool = true) -> Step {
        .rhythm(text: text, tones: tones, bpm: 60, rounds: rounds,
                keyboard: handsKeyboard(Score(tones: tones, counts: counts, bars: true, grand: true)))
    }

    // 33
    private static let sotaA = underneath(lC, [E, F, G])
    private static let sotaB = underneath(lG, [F, E, D])
    private static let sotaC = underneath(lC, [E, D, C])
    private static let sota = sotaA + sotaB + sotaC

    static let notaDeSota = Lesson(
        id: "5-sota", number: 33,
        title: "Una nota llarga a sota",
        summary: "L'esquerra aguanta, la dreta canta",
        minutes: 7,
        steps: [
            .look(text: "Fins ara, les mans tocaven per torns. Ara toquen juntes: l'esquerra fa una nota llarga i l'aguanta, i a sobre la dreta fa la melodia.",
                  picture: .staff(Score(tones: sotaA, bars: true, grand: true))),
            .look(text: "La nota de sota sona sola al primer cop. Mentre l'aguantes, la dreta toca als cops 2, 3 i 4. Per això a dalt, al primer cop, hi ha un silenci.",
                  picture: .staff(Score(tones: sotaA, counts: true, bars: true, grand: true))),
            .look(text: "Posa les dues mans: la dreta amb el polze sobre el do del mig i l'esquerra amb el petit sobre el do greu.",
                  picture: .keyboard(bothHands)),
            .listen(text: "Escolta: el do de sota i, mentre encara sona, mi, fa i sol a dalt.", tones: sotaA, bpm: 60,
                    keyboard: handsKeyboard(Score(tones: sotaA, counts: true, bars: true, grand: true)), pulse: true),
            handsRhythm("Toca el do amb el dit 5 de l'esquerra i no l'aixequis. Als cops 2, 3 i 4, la dreta: mi, fa i sol.", sotaA),
            .listen(text: "Ara la nota de sota és el sol, amb el polze de l'esquerra. A dalt, fa, mi i re.", tones: sotaB, bpm: 60,
                    keyboard: handsKeyboard(Score(tones: sotaB, counts: true, bars: true, grand: true)), pulse: true),
            handsRhythm("Toca el sol amb el polze de l'esquerra i aguanta'l. La dreta: fa, mi i re.", sotaB),
            .listen(text: "Tres compassos seguits. L'últim torna al do i la melodia baixa fins al do del mig.", tones: sota, bpm: 60,
                    keyboard: handsKeyboard(Score(tones: sota, counts: true, bars: true, grand: true)), pulse: true),
            handsRhythm("Toca els tres compassos. A cada un, primer la nota de sota i després les tres de dalt.", sota),
            handsRhythm("Ara sense els punts: només amb el que veus escrit.", sota, rounds: 1, counts: false),
        ]
    )

    // 34
    /// Una nota de l'esquerra de dos cops, sola al seu primer cop, i una nota de la dreta al segon.
    private static func half(_ bass: Int, _ melody: Int) -> [Tone] {
        [Tone(midi: bass, beats: 1, hold: 2), Tone(midi: melody)]
    }

    private static let canviA = half(lC, E) + half(lG, D)
    private static let canviB = half(lE, G) + half(lD, F)
    private static let canvi = canviA + canviB + sotaC

    static let canviarSota = Lesson(
        id: "5-canviar-sota", number: 34,
        title: "Canviar la nota de sota",
        summary: "L'esquerra canvia a mig compàs",
        minutes: 7,
        steps: [
            .look(text: "Ara la nota de sota dura dos cops en lloc de quatre: és una blanca. A cada compàs n'hi caben dues, i l'esquerra canvia de nota a mig compàs.",
                  picture: .staff(Score(tones: canviA, bars: true, grand: true))),
            .look(text: "L'esquerra toca als cops 1 i 3 i la dreta, als cops 2 i 4. Les mans es van alternant, però cada nota de sota s'aguanta mentre sona la de dalt.",
                  picture: .staff(Score(tones: canviA, counts: true, bars: true, grand: true))),
            .listen(text: "Escolta: do a sota i mi a dalt; després sol a sota i re a dalt.", tones: canviA, bpm: 60,
                    keyboard: handsKeyboard(Score(tones: canviA, counts: true, bars: true, grand: true)), pulse: true),
            handsRhythm("Toca el do amb el dit 5 i aguanta'l mentre la dreta fa el mi. Al cop 3, canvia al sol amb el polze, i la dreta fa el re.", canviA),
            .listen(text: "Ara l'esquerra fa mi i re, amb els dits 3 i 4. A dalt, sol i fa.", tones: canviB, bpm: 60,
                    keyboard: handsKeyboard(Score(tones: canviB, counts: true, bars: true, grand: true)), pulse: true),
            handsRhythm("Toca el mi de sota amb el dit 3 i, al cop 3, el re amb el dit 4. La dreta: sol i fa.", canviB),
            handsRhythm("Els dos compassos seguits. No aixequis la nota de sota fins que toqui la següent.", canviA + canviB),
            .listen(text: "Tot sencer. Acaba amb un compàs que ja coneixes: el do llarg a sota i mi, re i do a dalt.", tones: canvi, bpm: 60,
                    keyboard: handsKeyboard(Score(tones: canvi, counts: true, bars: true, grand: true)), pulse: true),
            handsRhythm("Toca els tres compassos. L'esquerra canvia quatre vegades i a l'últim compàs s'hi queda.", canvi),
            handsRhythm("Ara sense els punts: només amb el que veus escrit.", canvi, rounds: 1, counts: false),
        ]
    )

    // 35
    /// La mateixa nota amb les dues mans alhora: la dreta al seu lloc i l'esquerra una octava més avall.
    private static func both(_ midi: Int, _ beats: Double = 1) -> Tone {
        Tone(midi: midi, beats: beats, also: midi - 12)
    }

    private static let juntsDo = [both(C), both(C), both(C), both(C)]
    private static let juntsTres = [both(C), both(D), both(E, 2)]
    private static let juntsPuja = [both(C), both(D), both(E), both(F), both(G, 4)]
    private static let juntsTot = [both(C), both(D), both(E), both(F), both(G), both(F), both(E), both(D), both(C, 4)]

    static let mansAlhora = Lesson(
        id: "5-alhora", number: 35,
        title: "Les dues mans alhora",
        summary: "La mateixa nota, al mateix moment",
        minutes: 8,
        steps: [
            .look(text: "Fins ara les mans no començaven mai al mateix moment. Ara sí: les dues toquen la mateixa nota alhora, cada una a la seva altura. S'escriuen una sobre l'altra.",
                  picture: .staff(Score(tones: [both(C, 4)], names: true, bars: true, grand: true))),
            .look(text: "Les mans, com sempre: la dreta amb el polze sobre el do del mig i l'esquerra amb el petit sobre el do greu.",
                  picture: .keyboard(bothHands)),
            .listen(text: "Escolta quatre dos. A cada cop sonen el do greu i el do del mig junts, com una sola nota més plena.", tones: juntsDo, bpm: 60,
                    keyboard: handsKeyboard(Score(tones: juntsDo, counts: true, bars: true, grand: true)), pulse: true),
            handsRhythm("Toca el do amb les dues mans alhora: el polze de la dreta i el petit de l'esquerra. Quatre vegades, una a cada cop.", juntsDo),
            .look(text: "Quan les dues mans pugen juntes, els dits no són els mateixos. La dreta fa do, re i mi amb els dits 1, 2 i 3; l'esquerra, amb el 5, el 4 i el 3.",
                  picture: .keyboard(bothHands)),
            .listen(text: "Do, re i mi amb les dues mans. El mi dura dos cops.", tones: juntsTres, bpm: 60,
                    keyboard: handsKeyboard(Score(tones: juntsTres, counts: true, bars: true, grand: true)), pulse: true),
            handsRhythm("Toca do, re i mi amb les dues mans. Mira que els dos dits baixin al mateix moment.", juntsTres),
            .listen(text: "Ara les cinc notes pujant. El sol dura tot un compàs.", tones: juntsPuja, bpm: 60,
                    keyboard: handsKeyboard(Score(tones: juntsPuja, counts: true, bars: true, grand: true)), pulse: true),
            handsRhythm("Toca de do a sol amb les dues mans. A dalt de tot, aguanta el sol quatre cops.", juntsPuja),
            .listen(text: "Pujar i tornar a baixar: tres compassos seguits.", tones: juntsTot, bpm: 60,
                    keyboard: handsKeyboard(Score(tones: juntsTot, counts: true, bars: true, grand: true)), pulse: true),
            handsRhythm("Toca els tres compassos: puja fins al sol i torna al do, sempre amb les dues mans.", juntsTot),
            handsRhythm("Ara sense els punts: només amb el que veus escrit.", juntsTot, rounds: 1, counts: false),
        ]
    )

    // 36
    /// Una nota a cada mà, al mateix moment: la dreta a dalt i l'esquerra, a la seva altura.
    private static func mirror(_ right: Int, _ left: Int, _ beats: Double = 1) -> Tone {
        Tone(midi: right, beats: beats, also: left)
    }

    private static let polzes = [mirror(C, lG), mirror(C, lG), mirror(C, lG), mirror(C, lG)]
    private static let contrariTres = [mirror(C, lG), mirror(D, lF), mirror(E, lE, 2)]
    private static let contrariObre = [mirror(C, lG), mirror(D, lF), mirror(E, lE), mirror(F, lD), mirror(G, lC, 4)]
    private static let contrariTot = [mirror(C, lG), mirror(D, lF), mirror(E, lE), mirror(F, lD), mirror(G, lC),
                                      mirror(F, lD), mirror(E, lE), mirror(D, lF), mirror(C, lG, 4)]

    static let contrari = Lesson(
        id: "5-contrari", number: 36,
        title: "Moviment contrari",
        summary: "Una mà puja i l'altra baixa",
        minutes: 8,
        steps: [
            .look(text: "A la lliçó anterior les dues mans pujaven juntes. Ara cada una va cap al seu costat: la dreta puja i l'esquerra baixa. Se'n diu moviment contrari.",
                  picture: .staff(Score(tones: contrariTres, bars: true, grand: true))),
            .look(text: "El secret és als dits: les dues mans fan servir el mateix dit al mateix moment. Comencen els dos polzes, la dreta al do del mig i l'esquerra al sol.",
                  picture: .keyboard(bothHands)),
            .listen(text: "Escolta els dos polzes junts, quatre vegades: el do a dalt i el sol a sota.", tones: polzes, bpm: 60,
                    keyboard: handsKeyboard(Score(tones: polzes, counts: true, bars: true, grand: true)), pulse: true),
            handsRhythm("Toca el do i el sol alhora amb els dos polzes. Quatre vegades, una a cada cop.", polzes),
            .listen(text: "Ara dit 1, dit 2 i dit 3 a les dues mans. La dreta fa do, re i mi; l'esquerra, sol, fa i mi. Al final les dues arriben al mi.", tones: contrariTres, bpm: 60,
                    keyboard: handsKeyboard(Score(tones: contrariTres, counts: true, bars: true, grand: true)), pulse: true),
            handsRhythm("Toca les tres notes amb les dues mans. Mira que baixin els dos dits iguals: 1 i 1, 2 i 2, 3 i 3.", contrariTres),
            .listen(text: "Les cinc notes: les mans s'obren fins que la dreta arriba al sol i l'esquerra al do greu. L'última dura tot un compàs.", tones: contrariObre, bpm: 60,
                    keyboard: handsKeyboard(Score(tones: contrariObre, counts: true, bars: true, grand: true)), pulse: true),
            handsRhythm("Toca les cinc notes obrint les mans, fins al dit 5 de cada mà. Aguanta l'última quatre cops.", contrariObre),
            .listen(text: "Obrir i tornar a tancar: tres compassos que acaben als dos polzes, com han començat.", tones: contrariTot, bpm: 60,
                    keyboard: handsKeyboard(Score(tones: contrariTot, counts: true, bars: true, grand: true)), pulse: true),
            handsRhythm("Toca els tres compassos: les mans s'obren fins als dits 5 i tornen als polzes.", contrariTot),
            handsRhythm("Ara sense els punts: només amb el que veus escrit.", contrariTot, rounds: 1, counts: false),
        ]
    )

    // 37
    /// Un compàs de melodia amb una nota de sota que comença alhora amb la primera i s'aguanta tot el compàs.
    private static func withBass(_ bass: Int, _ bar: [Tone]) -> [Tone] {
        var tones = bar
        tones[0].also = bass
        tones[0].alsoHold = 4
        return tones
    }

    private static let odaBaix1 = withBass(lC, Array(odaA.prefix(4))) + withBass(lG, Array(odaA.suffix(4)))
    private static let odaBaix2 = withBass(lC, Array(odaB.prefix(4))) + withBass(lG, Array(odaB.suffix(3)))
    /// L'últim compàs canvia a mig camí: sol a sota mentre el re, i do per acabar.
    private static let odaBaix4: [Tone] = withBass(lC, Array(odaD.prefix(4))) + [
        Tone(midi: D, beats: 1.5, also: lG, alsoHold: 2), Tone(midi: C, beats: 0.5), Tone(midi: C, beats: 2, also: lC),
    ]
    private static let odaBaixos: [Tone] = [long(lC, 4), long(lG, 4)]
    private static let odaAcompanyadaTota = odaBaix1 + odaBaix2 + odaBaix1 + odaBaix4

    static let odaAcompanyada = Lesson(
        id: "5-oda", number: 37,
        title: "L'Oda amb acompanyament",
        summary: "La melodia a dalt, do i sol a sota",
        minutes: 10,
        steps: [
            .look(text: "La peça de l'etapa és una vella coneguda: l'Oda a l'alegria. La dreta fa la melodia de sempre i l'esquerra l'acompanya amb una nota llarga a cada compàs.",
                  picture: .staff(Score(tones: odaBaix1, bars: true, grand: true))),
            .look(text: "A sota només hi ha dues notes: el do greu, amb el dit 5, i el sol, amb el polze. Al primer cop de cada compàs les dues mans toquen alhora; després l'esquerra aguanta i la dreta continua.",
                  picture: .keyboard(bothHands)),
            .listen(text: "Primer, només l'acompanyament del primer tros: do i sol. Cada nota dura un compàs sencer.", tones: odaBaixos, bpm: 60,
                    keyboard: handsKeyboard(Score(tones: odaBaixos, counts: true, bars: true, grand: true)), pulse: true),
            handsRhythm("Toca només l'esquerra: do amb el dit 5 i sol amb el polze, i aguanta cada nota els quatre cops.", odaBaixos),
            .listen(text: "Ara el primer tros amb les dues mans: mi, mi, fa, sol a dalt sobre el do, i sol, fa, mi, re sobre el sol.", tones: odaBaix1, bpm: 60,
                    keyboard: handsKeyboard(Score(tones: odaBaix1, counts: true, bars: true, grand: true)), pulse: true),
            handsRhythm("Toca el primer tros. Les dues mans comencen juntes i l'esquerra no s'aixeca fins al compàs següent.", odaBaix1),
            .listen(text: "El segon tros: comença en el do, a dalt i a sota alhora, i acaba amb el re llarg sobre el sol.", tones: odaBaix2, bpm: 60,
                    keyboard: handsKeyboard(Score(tones: odaBaix2, counts: true, bars: true, grand: true)), pulse: true),
            handsRhythm("Toca el segon tros. Compte amb el mi amb punt: dura un cop i mig.", odaBaix2),
            .listen(text: "El final. A l'últim compàs l'esquerra canvia a mig camí: sol mentre sona el re, i do per acabar, amb les dues mans juntes.", tones: odaBaix4, bpm: 60,
                    keyboard: handsKeyboard(Score(tones: odaBaix4, counts: true, bars: true, grand: true)), pulse: true),
            handsRhythm("Toca el final. L'últim do, amb les dues mans alhora, aguanta'l dos cops.", odaBaix4),
            .listen(text: "Tota sencera: el primer tros, el segon, el primer un altre cop i el final.", tones: odaAcompanyadaTota, bpm: 60,
                    keyboard: handsKeyboard(Score(tones: odaAcompanyadaTota, counts: true, bars: true, grand: true)), pulse: true),
            handsRhythm("Toca-la sencera, amb les dues mans.", odaAcompanyadaTota, rounds: 1),
            handsRhythm("Ara sense els punts: només amb el que veus escrit.", odaAcompanyadaTota, rounds: 1, counts: false),
        ],
        isPiece: true
    )

    // MARK: Etapa 6 · Tres cops i tecles negres

    static let stage6 = Stage(
        id: 6,
        title: "Tres cops i tecles negres",
        summary: "El compàs de tres per quatre, sostinguts i bemolls",
        lessons: [tresPerQuatre, sostingut, bemoll, becaire]
    )

    /// Una partitura en tres per quatre.
    private static func waltz(_ tones: [Tone], counts: Bool = true, names: Bool = false) -> Score {
        Score(tones: tones, names: names, counts: counts, bars: true, meter: 3)
    }

    // 38
    private static let tresDos: [Tone] = tones([C, C, C, C, C, C])
    private static let tresExemple: [Tone] = tones([C, E, G]) + [long(C, 3)]
    private static let tresPunt: [Tone] = [long(C, 2), Tone(midi: E), long(G, 3)]
    private static let valsA: [Tone] = tones([C, D, E]) + [long(F, 2), Tone(midi: E)] + tones([D, E, D]) + [long(C, 3)]
    private static let valsB: [Tone] = tones([E, F, G]) + [long(G, 2), Tone(midi: F)] + tones([E, D, E]) + [long(C, 3)]
    private static let vals = valsA + valsB

    static let tresPerQuatre = Lesson(
        id: "6-tres", number: 38,
        title: "Comptar de tres en tres",
        summary: "El compàs de tres per quatre",
        minutes: 7,
        steps: [
            .look(text: "Fins ara, a cada compàs hi cabien quatre cops. N'hi ha que només en tenen tres: el número de dalt és un 3. Es compta u, dos, tres; u, dos, tres. És el compàs dels valsos.",
                  picture: .staff(waltz(tresExemple, counts: false))),
            .listen(text: "Escolta el pols de tres. El primer cop de cada compàs sona més fort: u, dos, tres.", tones: tresDos, bpm: 66,
                    keyboard: keyboard(waltz(tresDos)), pulse: true),
            .rhythm(text: "Toca el do a cada cop. Abans, l'app compta tres cops, no quatre.", tones: tresDos, bpm: 66, rounds: 2,
                    keyboard: keyboard(waltz(tresDos, names: true))),
            .look(text: "Una blanca amb un punt al costat dura tres cops: els dos de la blanca i un més pel punt. Omple tot un compàs de tres.",
                  picture: .staff(waltz(tresPunt))),
            .listen(text: "Do de dos cops i mi d'un; després el sol amb punt, que s'aguanta tot el compàs.", tones: tresPunt, bpm: 66,
                    keyboard: keyboard(waltz(tresPunt, names: true)), pulse: true),
            .rhythm(text: "Toca-ho. El sol amb punt no l'aixequis fins que s'hagin encès els tres punts.", tones: tresPunt, bpm: 66, rounds: 2,
                    keyboard: keyboard(waltz(tresPunt, names: true))),
            .listen(text: "Un vals petit. Escolta el primer tros: puja de do a fa i torna a baixar fins al do.", tones: valsA, bpm: 66,
                    keyboard: keyboard(waltz(valsA)), pulse: true),
            .rhythm(text: "Toca el primer tros. A cada compàs, el primer cop és el fort.", tones: valsA, bpm: 66, rounds: 2,
                    keyboard: keyboard(waltz(valsA))),
            .listen(text: "El vals sencer. El segon tros comença al mi i puja fins al sol.", tones: vals, bpm: 66,
                    keyboard: keyboard(waltz(vals)), pulse: true),
            .rhythm(text: "Toca el vals sencer.", tones: vals, bpm: 66, rounds: 1, keyboard: keyboard(waltz(vals))),
            .rhythm(text: "Ara sense els punts: només amb el que veus escrit.", tones: vals, bpm: 66, rounds: 1,
                    keyboard: keyboard(waltz(vals, counts: false))),
        ]
    )

    // 39–41: les tecles negres a la partitura
    private static let Fs = 66, Eb = 63
    private static let mib = Tone(midi: Eb, flat: true)
    private static func mib(_ beats: Double) -> Tone { Tone(midi: Eb, beats: beats, flat: true) }

    /// La mà de sempre, amb un dit que va a una tecla negra.
    /// `neighbour`: la blanca del costat de la negra (el fa del fa♯), amb el nom escrit encara que no es toqui.
    private static func blackKeys(_ score: Score?, marked: [Int], fingers: [Int: Int], neighbour: Int? = nil) -> Keyboard {
        var names: [Int: String] = [:]
        for key in marked + (neighbour.map { [$0] } ?? []) where !Music.isBlack(key) { names[key] = Music.name(key) }
        var keyboard = Keyboard(marked: marked, names: score == nil || score?.names == true ? names : [:], fingers: fingers)
        keyboard.score = score
        return keyboard
    }

    private static let sharpMarked = [C, D, E, Fs, G]
    private static let sharpFingers = [C: 1, D: 2, E: 3, Fs: 4, G: 5]
    private static func sharpKeys(_ score: Score? = nil) -> Keyboard { blackKeys(score, marked: sharpMarked, fingers: sharpFingers, neighbour: F) }

    private static let flatMarked = [C, D, Eb, F, G]
    private static let flatFingers = [C: 1, D: 2, Eb: 3, F: 4, G: 5]
    private static func flatKeys(_ score: Score? = nil) -> Keyboard { blackKeys(score, marked: flatMarked, fingers: flatFingers, neighbour: E) }

    private static let bothMarked = [C, D, Eb, E, F, Fs, G]
    private static let bothFingers = [C: 1, D: 2, Eb: 3, E: 3, F: 4, Fs: 4, G: 5]
    private static func bothKeys(_ score: Score? = nil) -> Keyboard { blackKeys(score, marked: bothMarked, fingers: bothFingers) }

    private static func bars(_ tones: [Tone], counts: Bool = true, names: Bool = false) -> Score {
        Score(tones: tones, names: names, counts: counts, bars: true)
    }

    // 39
    private static let faFaSost: [Tone] = [Tone(midi: F), Tone(midi: Fs), Tone(midi: F), Tone(midi: Fs)]
    private static let sostA: [Tone] = tones([D, E, Fs, G]) + tones([Fs, G, Fs, E])
    private static let sostB: [Tone] = tones([D, E, Fs, D]) + [long(G, 4)]
    private static let sost = sostA + sostB

    static let sostingut = Lesson(
        id: "6-sostingut", number: 39,
        title: "El sostingut",
        summary: "La tecla negra de la dreta",
        minutes: 7,
        steps: [
            .look(text: "Les tecles negres també són notes, i prenen el nom d'una blanca del costat. La negra que hi ha just a la dreta del fa és el fa sostingut. Un sostingut puja la nota fins a la tecla més propera de la dreta.",
                  picture: .keyboard(sharpKeys())),
            .look(text: "A la partitura, el fa sostingut va al mateix lloc que el fa, amb aquest signe al davant: ♯.",
                  picture: .staff(Score(tones: [long(F, 2), long(Fs, 2)], names: true, bars: true))),
            .listen(text: "Escolta fa i fa sostingut, dues vegades. Són tan a prop que gairebé es toquen.", tones: faFaSost, bpm: 66,
                    keyboard: sharpKeys(bars(faFaSost, names: true)), pulse: true),
            .play("Toca el fa sostingut amb el dit 4. El dit s'avança una mica i puja a la tecla negra.",
                  [Goal(accept: .named(6), label: "fa♯", key: Fs)], rounds: 3, keyboard: sharpKeys()),
            .listen(text: "Re, mi, fa sostingut i sol. Amb el sostingut, el sol sona com si arribessis a casa.", tones: Array(sostA.prefix(4)), bpm: 66,
                    keyboard: sharpKeys(bars(Array(sostA.prefix(4)), names: true)), pulse: true),
            .rhythm(text: "Toca re, mi, fa sostingut i sol: dits 2, 3, 4 i 5.", tones: Array(sostA.prefix(4)), bpm: 66, rounds: 2,
                    keyboard: sharpKeys(bars(Array(sostA.prefix(4)), names: true))),
            .look(text: "Un sostingut val per tot el compàs: si el fa torna a sortir abans de la ratlla, també és sostingut, encara que no porti el signe.",
                  picture: .staff(Score(tones: sostA, names: true, bars: true))),
            .rhythm(text: "Els dos primers compassos. Al segon hi ha dos fa, i tots dos són sostinguts.", tones: sostA, bpm: 66, rounds: 2,
                    keyboard: sharpKeys(bars(sostA))),
            .listen(text: "Tota la melodia: quatre compassos que acaben al sol.", tones: sost, bpm: 66,
                    keyboard: sharpKeys(bars(sost)), pulse: true),
            .rhythm(text: "Toca-la sencera. Compta quins fa són sostinguts: tots.", tones: sost, bpm: 66, rounds: 1, keyboard: sharpKeys(bars(sost))),
            .rhythm(text: "Ara sense els punts: només amb el que veus escrit.", tones: sost, bpm: 66, rounds: 1, keyboard: sharpKeys(bars(sost, counts: false))),
        ]
    )

    // 40
    private static let majorMenor: [Tone] = tones([C, D]) + [long(E, 2)] + tones([C, D]) + [mib(2)]
    private static let bemA: [Tone] = tones([C, D]) + [mib(2), Tone(midi: D), long(C, 3)]
    private static let bemB: [Tone] = tones([C, D]) + [mib, Tone(midi: F)] + [long(G, 2), mib(2)]
    private static let bemC: [Tone] = [Tone(midi: F), mib, Tone(midi: D), mib, long(C, 4)]
    private static let bem = bemB + bemC

    static let bemoll = Lesson(
        id: "6-bemoll", number: 40,
        title: "El bemoll",
        summary: "La tecla negra de l'esquerra",
        minutes: 7,
        steps: [
            .look(text: "El bemoll fa el contrari: baixa la nota fins a la tecla més propera de l'esquerra. La negra que hi ha just a l'esquerra del mi és el mi bemoll.",
                  picture: .keyboard(flatKeys())),
            .look(text: "S'escriu al lloc del mi, amb aquest signe al davant: ♭. És la mateixa tecla que el re sostingut: una tecla negra té dos noms, i la partitura tria el que li va millor.",
                  picture: .staff(Score(tones: [long(E, 2), mib(2)], names: true, bars: true))),
            .listen(text: "Escolta do, re, mi i després do, re, mi bemoll. Amb el bemoll, la mateixa melodia sona més trista.", tones: majorMenor, bpm: 66,
                    keyboard: flatKeys(bars(majorMenor, names: true)), pulse: true),
            .play("Toca el mi bemoll amb el dit 3. El dit s'avança i puja a la tecla negra.",
                  [Goal(accept: .named(3), label: "mi♭", key: Eb)], rounds: 3, keyboard: flatKeys()),
            .listen(text: "Do, re, mi bemoll llarg, i tornar a baixar fins al do.", tones: bemA, bpm: 66,
                    keyboard: flatKeys(bars(bemA, names: true)), pulse: true),
            .rhythm(text: "Toca-ho: dits 1, 2 i 3, i tornar. El do del final dura tres cops.", tones: bemA, bpm: 66, rounds: 2,
                    keyboard: flatKeys(bars(bemA, names: true))),
            .listen(text: "Una melodia trista, en dos trossos. El primer puja fins al sol.", tones: bemB, bpm: 66,
                    keyboard: flatKeys(bars(bemB)), pulse: true),
            .rhythm(text: "Toca el primer tros. Tots els mi són bemolls: al segon compàs el signe es torna a escriure.", tones: bemB, bpm: 66, rounds: 2,
                    keyboard: flatKeys(bars(bemB))),
            .listen(text: "Sencera: el segon tros baixa a poc a poc fins al do.", tones: bem, bpm: 66,
                    keyboard: flatKeys(bars(bem)), pulse: true),
            .rhythm(text: "Toca-la sencera.", tones: bem, bpm: 66, rounds: 1, keyboard: flatKeys(bars(bem))),
            .rhythm(text: "Ara sense els punts: només amb el que veus escrit.", tones: bem, bpm: 66, rounds: 1, keyboard: flatKeys(bars(bem, counts: false))),
        ]
    )

    // 41
    private static let becA: [Tone] = [Tone(midi: C), Tone(midi: D), mib, Tone(midi: E)] + [long(F, 2), long(E, 2)]
    private static let becB: [Tone] = tones([G, Fs, F, E]) + [long(D, 2), long(C, 2)]
    private static let bec = becA + becB

    static let becaire = Lesson(
        id: "6-becaire", number: 41,
        title: "El becaire",
        summary: "Tornar a la tecla blanca",
        minutes: 7,
        steps: [
            .look(text: "Un bemoll o un sostingut val fins a la ratlla de compàs. Si dins del mateix compàs la nota ha de tornar a ser blanca, porta aquest signe: el becaire, ♮.",
                  picture: .staff(Score(tones: Array(becA.prefix(4)), names: true, bars: true, ends: false))),
            .look(text: "Després de la ratlla de compàs, el bemoll ja no hi és: el mi del segon compàs és blanc, encara que no porti cap signe.",
                  picture: .staff(Score(tones: becA, names: true, bars: true))),
            .listen(text: "Escolta: do, re, mi bemoll, mi. Del bemoll al becaire, la tecla del costat.", tones: becA, bpm: 66,
                    keyboard: bothKeys(bars(becA, names: true)), pulse: true),
            .rhythm(text: "Toca-ho. El dit 3 va primer a la tecla negra i després a la blanca.", tones: becA, bpm: 66, rounds: 2,
                    keyboard: bothKeys(bars(becA, names: true))),
            .listen(text: "Ara amb el sostingut: sol, fa sostingut, fa i mi. El fa porta becaire perquè torna a ser blanc.", tones: becB, bpm: 66,
                    keyboard: bothKeys(bars(becB, names: true)), pulse: true),
            .rhythm(text: "Toca-ho. El dit 4 fa el fa sostingut i després el fa.", tones: becB, bpm: 66, rounds: 2,
                    keyboard: bothKeys(bars(becB, names: true))),
            .listen(text: "Tot seguit: puja amb el bemoll i baixa amb el sostingut.", tones: bec, bpm: 66,
                    keyboard: bothKeys(bars(bec)), pulse: true),
            .rhythm(text: "Toca els quatre compassos. Mira bé cada signe.", tones: bec, bpm: 66, rounds: 1, keyboard: bothKeys(bars(bec))),
            .rhythm(text: "Ara sense els punts: només amb el que veus escrit.", tones: bec, bpm: 66, rounds: 1, keyboard: bothKeys(bars(bec, counts: false))),
        ]
    )
}
