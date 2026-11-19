import SwiftUI

/// Teclat dibuixat. Sense `onPress` només ensenya on és cada tecla; amb `onPress` es pot tocar.
struct KeyboardView: View {
    let keyboard: Keyboard
    /// Tecla que cal tocar ara.
    var target: Int?
    /// Tecla que sona a l'exemple.
    var sounding: Int?
    /// Si hi és, cada tecla respon al dit.
    var onPress: ((Int) -> Void)?
    /// Omple l'espai que li donen en lloc de mantenir la proporció d'un teclat.
    var fills = false
    /// Si les tecles queden massa estretes per tocar-les, ensenya una octava i deixa passar a les altres.
    var pages = false

    @State private var pageStart: Int?
    @State private var pressed: Set<Int> = []

    /// Per sota d'aquesta amplada una tecla no es pot tocar bé amb el dit.
    private let narrowest: CGFloat = 34
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

        return ZStack(alignment: .topLeading) {
            ForEach(Array(whites.enumerated()), id: \.element) { index, midi in
                touchable(whiteKey(midi, small: small), midi: midi)
                    .frame(width: whiteWidth, height: max(size.height, 0))
                    .offset(x: CGFloat(index) * whiteWidth)
            }
            ForEach(blacks, id: \.self) { midi in
                // Una negra queda a cavall entre la blanca d'abans i la de després.
                let leftWhites = whites.filter { $0 < midi }.count
                touchable(RoundedRectangle(cornerRadius: 4).fill(fill(midi) ?? Theme.ink), midi: midi)
                    .frame(width: blackWidth, height: max(size.height, 0) * 0.6)
                    .offset(x: CGFloat(leftWhites) * whiteWidth - blackWidth / 2)
            }
        }
        .frame(width: size.width, height: max(size.height, 0), alignment: .topLeading)
    }

    @ViewBuilder
    private func touchable<Key: View>(_ key: Key, midi: Int) -> some View {
        if onPress == nil {
            key
        } else {
            key
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { _ in
                            guard !pressed.contains(midi) else { return }
                            pressed.insert(midi)
                            onPress?(midi)
                        }
                        .onEnded { _ in pressed.remove(midi) }
                )
                .accessibilityElement()
                .accessibilityLabel(Music.name(midi))
                .accessibilityAddTraits(.isButton)
                .accessibilityIdentifier("tecla-\(midi)")
        }
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
        if pressed.contains(midi) || midi == sounding { return Theme.sage }
        if midi == target { return Theme.brass }
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
