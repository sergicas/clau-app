import SwiftUI
import AppKit

// Dibuixa uns quants pentagrames en un PNG, per mirar-los al Mac sense telèfon: proves/pentagrama.sh

@MainActor
func renderAll() {
    let C = 60, D = 62, E = 64, F = 65, G = 67
    func t(_ midis: [Int]) -> [Tone] { midis.map { Tone(midi: $0) } }
    let lluna: [Tone] = t([C, C, C, D]) + [Tone(midi: E, beats: 2), Tone(midi: D, beats: 2)] + t([C, E, D, D]) + [Tone(midi: C, beats: 4)]
    let barreja: [Tone] = t([C, C]) + [Tone(midi: D, beats: 0.5), Tone(midi: D, beats: 0.5)] + t([E]) + [Tone(midi: E), .rest(), Tone(midi: C, beats: 2)]

    let view = VStack(alignment: .leading, spacing: 14) {
        StaffView(score: Score(clef: false, numbered: true))
        StaffView(score: Score(tones: t([C, D, E, F, G]), names: true), current: 2, done: 2)
        StaffView(score: Score(tones: [Tone(midi: E), Tone(midi: E), Tone(midi: E, beats: 2), Tone(midi: E, beats: 4)], counts: true), current: 3, marks: [.hit, .hit, .hit, .pending], beat: 3, spacing: 13)
        StaffView(score: Score(tones: barreja), marks: [.hit, .hit, .wrong, .missed, .pending, .pending, .pending, .pending])
        StaffView(score: Score(tones: lluna, bars: true), current: 5)
        StaffView(score: Score(tones: t([G]), names: true), spacing: 8)
        StaffView(score: Score(tones: t([48, 50, 52, 53, 55]), names: true, bass: true), current: 3, done: 3, spacing: 13)
        StaffView(score: Score(tones: t([E, D, C, 55, 53, 52]), grand: true), current: 4, done: 4, spacing: 9)
    }
    .padding(16)
    .frame(width: 370)
    .background(Theme.card)

    let renderer = ImageRenderer(content: view)
    renderer.scale = 2
    guard let image = renderer.nsImage, let tiff = image.tiffRepresentation,
          let png = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:]) else {
        print("No s'ha pogut dibuixar")
        exit(1)
    }
    try? png.write(to: URL(fileURLWithPath: "build/pentagrama.png"))
    print("build/pentagrama.png")
}

@main struct Main { static func main() { MainActor.assumeIsolated { renderAll() } } }
