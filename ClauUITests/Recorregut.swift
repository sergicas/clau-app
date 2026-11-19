import XCTest

/// Recorre l'app al telèfon i en desa captures, per poder-la veure des del Mac.
/// Amb «-prova» l'app no engega el micròfon ni desa el progrés.
final class Recorregut: XCTestCase {
    private let app = XCUIApplication()

    override func setUp() {
        continueAfterFailure = true
    }

    /// Obre l'app triant amb què es toca: "real" (un piano) o "screen" (la pantalla).
    private func launch(instrument: String) {
        app.launchArguments = ["-prova", "-instrument", instrument]
        app.launch()
    }

    private func press(_ midis: [Int]) {
        for midi in midis {
            let key = app.buttons["tecla-\(midi)"].firstMatch
            XCTAssertTrue(key.waitForExistence(timeout: 5), "No trobo la tecla \(midi)")
            key.tap()
        }
    }

    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func tap(_ label: String) {
        let button = app.buttons[label].firstMatch
        XCTAssertTrue(button.waitForExistence(timeout: 5), "No trobo el botó «\(label)»")
        button.tap()
    }

    private func open(lesson number: Int) {
        let row = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Lliçó \(number),")).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5), "No trobo la lliçó \(number)")
        // La llista és llarga: es busca cap avall i, si no hi és, cap amunt.
        for _ in 0..<6 where !row.isHittable { app.swipeUp(velocity: .slow) }
        for _ in 0..<12 where !row.isHittable { app.swipeDown(velocity: .slow) }
        row.tap()
    }

    func testAmbPiano() {
        launch(instrument: "real")
        capture("01-curs")
        app.swipeUp()
        capture("02-curs-avall")
        app.swipeDown()

        open(lesson: 1)
        capture("03-l1-mira-seure")
        tap("Continua"); capture("04-l1-mira-ma")
        tap("Continua"); capture("05-l1-mira-teclat")
        tap("Continua"); capture("06-l1-toca")
        tap("Continua sense comprovar"); capture("07-l1-final")
        tap("Torna al curs")

        open(lesson: 2)
        capture("08-l2-negres")
        tap("Continua"); capture("09-l2-toca-negres")
        tap("Tanca la lliçó")

        open(lesson: 4)
        capture("10-l4-tots-els-dos")
        tap("Tanca la lliçó")

        open(lesson: 5)
        tap("Continua"); capture("11-l5-dits")
        tap("Continua"); capture("12-l5-toca-dits")
        tap("Tanca la lliçó")

        open(lesson: 8)
        tap("Continua"); capture("13-l8-escolta")
        tap("Continua"); capture("14-l8-escolta-tros")
        tap("Ara jo"); capture("15-l8-toca-tros")
        tap("Tanca la lliçó")

        XCUIDevice.shared.orientation = .landscapeLeft
        open(lesson: 7)
        capture("16-l7-apaisat-mira")
        tap("Continua"); capture("17-l7-apaisat-escolta")
        tap("Ara jo"); capture("18-l7-apaisat-toca")
        XCUIDevice.shared.orientation = .portrait
    }

    func testAlaPantalla() {
        XCUIDevice.shared.orientation = .portrait
        launch(instrument: "screen")
        capture("p01-curs")

        open(lesson: 1)
        capture("p02-l1-mira")
        tap("Continua"); tap("Continua"); tap("Continua")
        capture("p03-l1-toca")
        press([64, 61, 67])
        XCTAssertTrue(app.staticTexts["Lliçó acabada."].waitForExistence(timeout: 6), "La lliçó 1 no s'ha acabat tocant tres tecles")
        capture("p04-l1-final")
        tap("Torna al curs")

        // Una nota equivocada no compta, i la bona sí.
        open(lesson: 6)
        tap("Continua"); tap("Ara jo")
        press([60, 65])
        capture("p05-l6-nota-equivocada")
        press([62, 64, 60, 62, 64, 60, 62, 64])
        XCTAssertTrue(app.buttons["Ara jo"].waitForExistence(timeout: 6), "Do, re, mi tres vegades no ha fet avançar el pas")
        capture("p06-l6-escolta")
        tap("Tanca la lliçó")

        // Teclat de tres octaves: en vertical s'ha de poder passar d'octava.
        open(lesson: 4)
        tap("Continua"); tap("Ara jo")
        capture("p07-l4-tres-dos")
        press([48])
        tap("Més agut"); press([60])
        tap("Més agut"); press([72])
        XCTAssertTrue(app.buttons["Continua"].waitForExistence(timeout: 6), "Tres dos diferents no han fet avançar el pas")
        capture("p08-l4-do-del-mig")
        tap("Tanca la lliçó")

        XCUIDevice.shared.orientation = .landscapeLeft
        open(lesson: 8)
        capture("p09-l8-apaisat-mira")
        tap("Continua"); tap("Continua"); tap("Ara jo")
        capture("p10-l8-apaisat-toca")
        press([64, 64, 65, 67])
        capture("p11-l8-apaisat-a-mig-tros")
        tap("Tanca la lliçó")
        open(lesson: 4)
        capture("p12-l4-apaisat-tres-octaves")
        XCUIDevice.shared.orientation = .portrait
    }

    /// Etapa 2: captures de les pantalles del pols. Els tocs d'una prova no són prou puntuals per jutjar-hi el ritme.
    func testElPols() {
        XCUIDevice.shared.orientation = .portrait
        launch(instrument: "screen")
        app.swipeUp()
        capture("r01-curs-etapa2")

        open(lesson: 9)
        capture("r02-l9-mira")
        tap("Continua"); capture("r03-l9-escolta-pols")
        tap("Continua"); tap("Continua")
        capture("r04-l9-ritme-a-punt")
        tap("Comença")
        capture("r05-l9-comptant")
        XCTAssertTrue(app.buttons["Torna-hi"].waitForExistence(timeout: 15), "Sense tocar res, el ritme hauria d'acabar demanant de tornar-hi")
        capture("r06-l9-no-ha-sortit")
        XCUIDevice.shared.orientation = .landscapeLeft
        capture("r06b-l9-apaisat-no-ha-sortit")
        XCUIDevice.shared.orientation = .portrait
        tap("Tanca la lliçó")

        open(lesson: 13)
        tap("Continua"); tap("Ara jo")
        capture("r07-l13-mig-cop")
        tap("Tanca la lliçó")

        XCUIDevice.shared.orientation = .landscapeLeft
        open(lesson: 15)
        tap("Continua"); tap("Continua"); tap("Ara jo")
        capture("r08-l15-apaisat-ritme")
        XCUIDevice.shared.orientation = .portrait
    }

    /// Etapa 3: captures de les partitures.
    func testLlegir() {
        XCUIDevice.shared.orientation = .portrait
        launch(instrument: "screen")

        open(lesson: 16)
        capture("g01-l16-cinc-ratlles")
        tap("Continua"); capture("g02-l16-ratlla-i-espai")
        tap("Continua"); tap("Continua"); capture("g03-l16-escolta")
        tap("Ara jo"); capture("g04-l16-toca-llegint")
        press([60, 62])
        capture("g05-l16-a-mig-llegir")
        tap("Tanca la lliçó")

        open(lesson: 17)
        capture("g06-l17-clau-de-sol")
        tap("Continua"); capture("g07-l17-el-sol")
        tap("Tanca la lliçó")

        open(lesson: 18)
        tap("Continua"); tap("Ara jo")
        press([60, 62, 64, 60, 62, 64])
        XCTAssertTrue(app.staticTexts["Ara sense els noms. Mira on és cada nota."].waitForExistence(timeout: 6), "Llegir do, re, mi dues vegades no ha fet avançar el pas")
        capture("g08-l18-sense-noms")
        tap("Tanca la lliçó")

        open(lesson: 21)
        capture("g09-l21-figures")
        tap("Continua"); tap("Ara jo"); capture("g10-l21-ritme-llegit")
        tap("Tanca la lliçó")

        open(lesson: 22)
        tap("Continua"); capture("g11-l22-compassos")
        tap("Tanca la lliçó")

        XCUIDevice.shared.orientation = .landscapeLeft
        open(lesson: 24)
        capture("g12-l24-apaisat-mira")
        tap("Continua"); capture("g13-l24-apaisat-llegeix")
        XCUIDevice.shared.orientation = .portrait
    }

    /// Una tecla aguantada molta estona, mentre la pantalla es va redibuixant amb el pols, ha de comptar una sola vegada.
    func testNotaLlarga() {
        XCUIDevice.shared.orientation = .portrait
        launch(instrument: "screen")
        open(lesson: 21)
        tap("Continua"); tap("Ara jo")
        tap("Comença")
        let key = app.buttons["tecla-64"].firstMatch
        XCTAssertTrue(key.waitForExistence(timeout: 5))
        key.press(forDuration: 5)
        capture("n01-l21-nota-aguantada")
        XCTAssertTrue(app.staticTexts["premudes 1"].waitForExistence(timeout: 3), "Un sol dit aguantat ha comptat més d'una vegada, o cap")
        key.tap(); key.tap()
        XCTAssertTrue(app.staticTexts["premudes 3"].waitForExistence(timeout: 3), "Dos tocs més haurien de fer tres premudes")
        XCTAssertTrue(app.buttons["Torna-hi"].waitForExistence(timeout: 20))
        capture("n02-l21-resultat")
    }

    /// Etapa 4: captures de la clau de fa i de les dues mans.
    func testEsquerra() {
        XCUIDevice.shared.orientation = .portrait
        launch(instrument: "screen")

        open(lesson: 25)
        tap("Continua"); capture("e01-l25-mans")
        tap("Continua"); tap("Ara jo"); capture("e02-l25-toca-dits")
        tap("Tanca la lliçó")

        open(lesson: 27)
        capture("e03-l27-clau-de-fa")
        tap("Continua"); capture("e04-l27-cinc-notes")
        tap("Tanca la lliçó")

        open(lesson: 28)
        tap("Continua"); tap("Ara jo"); capture("e05-l28-notes-llargues")
        tap("Tanca la lliçó")

        open(lesson: 30)
        capture("e06-l30-dues-mans")
        tap("Continua"); tap("Continua"); tap("Ara jo")
        capture("e07-l30-toca-dues-mans")
        press([64, 62, 60, 55, 53, 52])
        XCTAssertTrue(app.staticTexts["Molt bé."].waitForExistence(timeout: 3) || app.staticTexts["Bé. Una vegada més."].waitForExistence(timeout: 3), "Tocar mi, re, do, sol, fa, mi no ha comptat a la lliçó 30")
        tap("Tanca la lliçó")

        open(lesson: 32)
        capture("e08-l32-peca")
        tap("Continua"); tap("Ara jo")
        capture("e09-l32-primer-tros")
        tap("Tanca la lliçó")
    }
}
