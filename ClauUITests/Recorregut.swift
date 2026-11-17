import XCTest

/// Recorre l'app al telèfon i en desa captures, per poder-la veure des del Mac.
/// Amb «-prova» l'app no engega el micròfon ni desa el progrés.
final class Recorregut: XCTestCase {
    private let app = XCUIApplication()

    override func setUp() {
        continueAfterFailure = true
        app.launchArguments = ["-prova"]
        app.launch()
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
        if !row.isHittable { app.swipeUp() }
        row.tap()
    }

    func testRecorregut() {
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
}
