import SwiftUI

/// Teclat dibuixat. No es toca: ensenya on és cada tecla del piano de debò.
struct KeyboardView: View {
    let keyboard: Keyboard
    /// Tecla que cal tocar ara.
    var target: Int?
    /// Tecla que sona a l'exemple.
    var sounding: Int?

    private var whites: [Int] { (keyboard.low...keyboard.high).filter { !Music.isBlack($0) } }
    private var blacks: [Int] { (keyboard.low...keyboard.high).filter(Music.isBlack) }

    var body: some View {
        GeometryReader { geometry in
            let whiteWidth = geometry.size.width / CGFloat(max(whites.count, 1))
            let height = geometry.size.height
            let blackWidth = whiteWidth * 0.62
            let blackHeight = height * 0.6
            let small = whiteWidth < 30

            ZStack(alignment: .topLeading) {
                ForEach(Array(whites.enumerated()), id: \.element) { index, midi in
                    whiteKey(midi, small: small)
                        .frame(width: whiteWidth, height: height)
                        .offset(x: CGFloat(index) * whiteWidth)
                }
                ForEach(blacks, id: \.self) { midi in
                    // Una negra queda a cavall entre la blanca d'abans i la de després.
                    let leftWhites = whites.filter { $0 < midi }.count
                    RoundedRectangle(cornerRadius: 4)
                        .fill(fill(midi) ?? Theme.ink)
                        .frame(width: blackWidth, height: blackHeight)
                        .offset(x: CGFloat(leftWhites) * whiteWidth - blackWidth / 2)
                }
            }
        }
        // Un teclat de moltes tecles es fa més alt en proporció, perquè no quedi una tira prima.
        .aspectRatio(CGFloat(whites.count) / (whites.count > 14 ? 5.6 : 3.4), contentMode: .fit)
        .frame(maxHeight: 190)
        .accessibilityElement()
        .accessibilityLabel(accessibilityText)
    }

    private func whiteKey(_ midi: Int, small: Bool) -> some View {
        let colour = fill(midi)
        return ZStack(alignment: .bottom) {
            RoundedRectangle(cornerRadius: 5)
                .fill(colour ?? Theme.card)
            RoundedRectangle(cornerRadius: 5)
                .stroke(Theme.ink.opacity(0.45), lineWidth: 1)
            VStack(spacing: 3) {
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
        if midi == sounding { return Theme.sage }
        if midi == target { return Theme.brass }
        if keyboard.marked.contains(midi) { return Theme.brass.opacity(0.45) }
        return nil
    }

    private var accessibilityText: String {
        if let target { return "Teclat. Tecla marcada: \(Music.name(target))." }
        if !keyboard.marked.isEmpty {
            return "Teclat. Tecles marcades: " + keyboard.marked.map(Music.name).joined(separator: ", ") + "."
        }
        return "Teclat."
    }
}
