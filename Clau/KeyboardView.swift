import SwiftUI
import UIKit
import os

/// Teclat dibuixat. Sense `onPress` només ensenya on és cada tecla; amb `onPress` es pot tocar.
struct KeyboardView: View {
    let keyboard: Keyboard
    /// Tecla que cal tocar ara.
    var target: Int?
    /// Tecla que sona a l'exemple.
    var sounding: Int?
    /// La tecla de l'altra mà, quan cal tocar-ne (o en sonen) dues alhora.
    var alsoTarget: Int?
    var alsoSounding: Int?
    /// Si hi és, cada tecla respon al dit. Rep la tecla i el moment exacte en què el dit l'ha tocada.
    var onPress: ((Int, TimeInterval) -> Void)?
    /// El dit ha deixat anar la tecla.
    var onRelease: ((Int) -> Void)?
    /// Omple l'espai que li donen en lloc de mantenir la proporció d'un teclat.
    var fills = false
    /// Si les tecles queden massa estretes per tocar-les, ensenya una octava i deixa passar a les altres.
    var pages = false

    @State private var pageStart: Int?
    @State private var pressed: Set<Int> = []

    /// Per sota d'aquesta amplada una tecla no es pot tocar bé amb el dit.
    private let narrowest: CGFloat = 30
    private let pagerHeight: CGFloat = 44

    private var allWhites: Int { (keyboard.low...keyboard.high).filter { !Music.isBlack($0) }.count }

    var body: some View {
        let content = GeometryReader { geometry in
            let paged = pages && geometry.size.width / CGFloat(max(allWhites, 1)) < narrowest
            let low = paged ? (pageStart ?? keyboard.low) : keyboard.low
            let high = paged ? min(low + 11, keyboard.high) : keyboard.high
            VStack(spacing: 6) {
                if paged { pager(low: low) }
                keys(low: low, high: high,
                     size: CGSize(width: geometry.size.width,
                                  height: geometry.size.height - (paged ? pagerHeight + 6 : 0)))
            }
        }
        if fills {
            content
        } else {
            content
                // Un teclat de moltes tecles es fa més alt en proporció, perquè no quedi una tira prima.
                .aspectRatio(CGFloat(allWhites) / (allWhites > 14 ? 5.6 : 3.4), contentMode: .fit)
                .frame(maxHeight: 190)
                .accessibilityElement()
                .accessibilityLabel(accessibilityText)
        }
    }

    // MARK: Tecles

    private func keys(low: Int, high: Int, size: CGSize) -> some View {
        let whites = (low...high).filter { !Music.isBlack($0) }
        let blacks = (low...high).filter(Music.isBlack)
        let whiteWidth = size.width / CGFloat(max(whites.count, 1))
        let blackWidth = whiteWidth * 0.62
        let small = whiteWidth < 30
        let letters = onPress != nil && KeyLetters.visible
            ? Dictionary(KeyLetters.map(whites: whites, blacks: blacks).map { ($1, $0.uppercased()) }, uniquingKeysWith: { a, _ in a })
            : [:]

        return ZStack(alignment: .topLeading) {
            ForEach(Array(whites.enumerated()), id: \.element) { index, midi in
                touchable(whiteKey(midi, small: small, letter: letters[midi]), midi: midi)
                    .frame(width: whiteWidth, height: max(size.height, 0))
                    .offset(x: CGFloat(index) * whiteWidth)
            }
            ForEach(blacks, id: \.self) { midi in
                // Una negra queda a cavall entre la blanca d'abans i la de després.
                let leftWhites = whites.filter { $0 < midi }.count
                touchable(blackKey(midi, letter: letters[midi]), midi: midi)
                    .frame(width: blackWidth, height: max(size.height, 0) * 0.6)
                    .offset(x: CGFloat(leftWhites) * whiteWidth - blackWidth / 2)
            }
        }
        .frame(width: size.width, height: max(size.height, 0), alignment: .topLeading)
        .overlay {
            if let onPress {
                // Tots els tocs passen per una sola superfície: cada dit que baixa compta una vegada,
                // encara que la pantalla es redibuixi mentre s'aguanta la tecla.
                KeyTouchSurface(whites: whites, blacks: blacks, onDown: onPress, onUp: { onRelease?($0) }, onHeld: { pressed = $0 })
                    .accessibilityHidden(true)
            }
        }
    }

    @ViewBuilder
    private func touchable<Key: View>(_ key: Key, midi: Int) -> some View {
        if onPress == nil {
            key
        } else {
            key
                .accessibilityElement()
                .accessibilityLabel(Music.name(midi))
                .accessibilityAddTraits(.isButton)
                .accessibilityIdentifier("tecla-\(midi)")
                .accessibilityAction { onPress?(midi, ProcessInfo.processInfo.systemUptime) }
        }
    }

    private func blackKey(_ midi: Int, letter: String?) -> some View {
        ZStack(alignment: .bottom) {
            RoundedRectangle(cornerRadius: 4).fill(fill(midi) ?? Theme.ink)
            VStack(spacing: 3) {
                if let letter {
                    Text(letter)
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(Theme.card.opacity(0.8))
                }
                // Quan un dit va a una tecla negra (el fa♯ amb el dit 4), el número també s'hi posa.
                if let finger = keyboard.fingers[midi] {
                    Text("\(finger)")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.ink)
                        .frame(width: 20, height: 20)
                        .background(Theme.card, in: Circle())
                }
            }
            .padding(.bottom, 5)
        }
    }

    private func whiteKey(_ midi: Int, small: Bool, letter: String? = nil) -> some View {
        let colour = fill(midi)
        return ZStack(alignment: .bottom) {
            RoundedRectangle(cornerRadius: 5)
                .fill(colour ?? Theme.card)
            RoundedRectangle(cornerRadius: 5)
                .stroke(Theme.ink.opacity(0.45), lineWidth: 1)
            VStack(spacing: 3) {
                if let letter {
                    Text(letter)
                        .font(.system(size: small ? 10 : 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(Theme.soft)
                }
                if let finger = keyboard.fingers[midi] {
                    Text("\(finger)")
                        .font(.system(size: small ? 11 : 15, weight: .bold, design: .rounded))
                        .foregroundStyle(colour == nil ? Theme.card : Theme.ink)
                        .frame(width: small ? 17 : 24, height: small ? 17 : 24)
                        .background(colour == nil ? Theme.ink.opacity(0.75) : Theme.card, in: Circle())
                }
                if let name = keyboard.names[midi] {
                    Text(name)
                        .font(.system(size: small ? 10 : 15, weight: .semibold, design: .serif))
                        .foregroundStyle(Theme.ink)
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                }
            }
            .padding(.bottom, 6)
        }
    }

    private func fill(_ midi: Int) -> Color? {
        if pressed.contains(midi) || midi == sounding || midi == alsoSounding { return Theme.sage }
        if midi == target || midi == alsoTarget { return Theme.brass }
        if keyboard.marked.contains(midi) { return Theme.brass.opacity(0.45) }
        return nil
    }

    // MARK: Passar d'octava

    private func pager(low: Int) -> some View {
        HStack {
            Button {
                pageStart = max(keyboard.low, low - 12)
            } label: {
                Label("Més greu", systemImage: "chevron.left")
            }
            .disabled(low <= keyboard.low)
            Spacer()
            Button {
                pageStart = min(low + 12, keyboard.high - 11)
            } label: {
                Label("Més agut", systemImage: "chevron.right").labelStyle(TrailingIcon())
            }
            .disabled(low + 12 > keyboard.high)
        }
        .font(.body.weight(.semibold))
        .tint(Theme.ink)
        .frame(height: pagerHeight)
        .padding(.horizontal, 6)
    }

    private var accessibilityText: String {
        if let target, let alsoTarget { return "Teclat. Tecles marcades: \(Music.name(alsoTarget)) greu i \(Music.name(target))." }
        if let target { return "Teclat. Tecla marcada: \(Music.name(target))." }
        if !keyboard.marked.isEmpty {
            return "Teclat. Tecles marcades: " + keyboard.marked.map(Music.name).joined(separator: ", ") + "."
        }
        return "Teclat."
    }
}

private struct TrailingIcon: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 6) {
            configuration.title
            configuration.icon
        }
    }
}

/// Quina tecla del piano toca cada lletra del teclat de l'ordinador, com en un piano de joguina:
/// la fila del mig (A S D F G H J K L Ñ) són les blanques i la de dalt (W E T Y U O P), les negres de entremig.
/// Si el teclat dibuixat comença més avall del do del mig, la fila de baix (Z X C V B N M) fa l'octava greu.
enum KeyLetters {
    private static let middle = ["a", "s", "d", "f", "g", "h", "j", "k", "l", "ñ"]
    private static let bottom = ["z", "x", "c", "v", "b", "n", "m"]
    /// La lletra de dalt que queda entre dues de la fila del mig, com la negra entre dues blanques.
    private static let above: [String: String] = ["a": "w", "s": "e", "f": "t", "g": "y", "h": "u", "k": "o", "l": "p"]

    static func map(whites: [Int], blacks: [Int]) -> [String: Int] {
        guard !whites.isEmpty else { return [:] }
        var start = 0
        var result: [String: Int] = [:]
        // Amb dues octaves o més, la fila del mig comença al do del mig i la de baix fa les de sota.
        if whites.count > middle.count, let central = whites.firstIndex(of: 60), central > 0 {
            start = central
            for (letter, midi) in zip(bottom, whites[max(0, central - bottom.count)..<central]) {
                result[letter] = midi
            }
        }
        for (offset, letter) in middle.enumerated() where start + offset < whites.count {
            let midi = whites[start + offset]
            result[letter] = midi
            if let upper = above[letter], blacks.contains(midi + 1) { result[upper] = midi + 1 }
        }
        return result
    }

    /// Si val la pena ensenyar les lletres: al Mac, o amb un teclat connectat.
    static var visible: Bool {
        ProcessInfo.processInfo.isiOSAppOnMac || ProcessInfo.processInfo.isMacCatalystApp
    }
}

/// Rep els dits directament de UIKit: sap quan baixa cada un, amb el seu instant, i quan s'aixeca.
private struct KeyTouchSurface: UIViewRepresentable {
    let whites: [Int]
    let blacks: [Int]
    let onDown: (Int, TimeInterval) -> Void
    let onUp: (Int) -> Void
    let onHeld: (Set<Int>) -> Void

    func makeUIView(context: Context) -> KeyTouchView {
        let view = KeyTouchView()
        view.isMultipleTouchEnabled = true
        view.backgroundColor = .clear
        return view
    }

    func updateUIView(_ view: KeyTouchView, context: Context) {
        view.whites = whites
        view.blacks = blacks
        view.onDown = onDown
        view.onUp = onUp
        view.onHeld = onHeld
    }
}

final class KeyTouchView: UIView {
    var whites: [Int] = []
    var blacks: [Int] = []
    var onDown: ((Int, TimeInterval) -> Void)?
    var onUp: ((Int) -> Void)?
    var onHeld: ((Set<Int>) -> Void)?

    private static let diary = Logger(subsystem: "cat.sergicastillo.clau", category: "tecles")

    /// Quina tecla aguanta cada dit.
    private var held: [ObjectIdentifier: Int] = [:]
    /// Quina tecla del piano aguanta cada lletra del teclat de l'ordinador.
    private var heldLetters: [String: Int] = [:]

    override var canBecomeFirstResponder: Bool { true }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        // Així les lletres del teclat de l'ordinador arriben aquí sense haver de clicar enlloc.
        if window != nil { DispatchQueue.main.async { [weak self] in self?.becomeFirstResponder() } }
    }

    private func letter(of press: UIPress) -> String? {
        guard let key = press.key, key.modifierFlags.intersection([.command, .control, .alternate]).isEmpty else { return nil }
        return key.charactersIgnoringModifiers.lowercased()
    }

    override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        let letters = KeyLetters.map(whites: whites, blacks: blacks)
        var handled = false
        for press in presses {
            guard let letter = letter(of: press), let midi = letters[letter] else { continue }
            handled = true
            // Una lletra aguantada no torna a sonar.
            guard heldLetters[letter] == nil else { continue }
            heldLetters[letter] = midi
            onDown?(midi, press.timestamp)
        }
        if handled { onHeld?(Set(held.values).union(heldLetters.values)) } else { super.pressesBegan(presses, with: event) }
    }

    override func pressesEnded(_ presses: Set<UIPress>, with event: UIPressesEvent?) { release(presses, with: event) }
    override func pressesCancelled(_ presses: Set<UIPress>, with event: UIPressesEvent?) { release(presses, with: event) }

    private func release(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        var handled = false
        for press in presses {
            guard let letter = letter(of: press), let midi = heldLetters.removeValue(forKey: letter) else { continue }
            handled = true
            if !held.values.contains(midi), !heldLetters.values.contains(midi) { onUp?(midi) }
        }
        if handled { onHeld?(Set(held.values).union(heldLetters.values)) } else { super.pressesEnded(presses, with: event) }
    }

    /// La mateixa geometria amb què es dibuixen les tecles.
    private func key(at point: CGPoint) -> Int? {
        guard !whites.isEmpty, bounds.width > 0 else { return nil }
        let whiteWidth = bounds.width / CGFloat(whites.count)
        let blackWidth = whiteWidth * 0.62
        if point.y <= bounds.height * 0.6 {
            for black in blacks {
                let left = CGFloat(whites.filter { $0 < black }.count) * whiteWidth - blackWidth / 2
                if point.x >= left, point.x < left + blackWidth { return black }
            }
        }
        let index = Int(point.x / whiteWidth)
        return whites.indices.contains(index) ? whites[index] : nil
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        if !isFirstResponder { becomeFirstResponder() }
        for touch in touches {
            let point = touch.location(in: self)
            let found = key(at: point)
            // Per poder mirar, quan una tecla no respon, on ha caigut el dit i què s'hi ha entès.
            KeyTouchView.diary.notice("toc x=\(Int(point.x)) y=\(Int(point.y)) de \(Int(self.bounds.width))x\(Int(self.bounds.height)), \(self.whites.count) blanques des de \(self.whites.first ?? 0): \(found.map(Music.name) ?? "cap tecla", privacy: .public)")
            guard let midi = found else { continue }
            held[ObjectIdentifier(touch)] = midi
            onDown?(midi, touch.timestamp)
        }
        onHeld?(Set(held.values).union(heldLetters.values))
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) { lift(touches) }
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) { lift(touches) }

    private func lift(_ touches: Set<UITouch>) {
        for touch in touches {
            guard let midi = held.removeValue(forKey: ObjectIdentifier(touch)) else { continue }
            if !held.values.contains(midi) { onUp?(midi) }
        }
        onHeld?(Set(held.values).union(heldLetters.values))
    }
}
