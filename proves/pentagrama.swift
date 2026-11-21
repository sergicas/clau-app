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

/// Totes les partitures del curs, una imatge per lliçó a build/revisio/, amb l'amplada d'un iPhone dret.
@MainActor
func renderCourse() {
    let folder = URL(fileURLWithPath: "build/revisio")
    try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    for lesson in Course.allLessons {
        var items: [(String, Score)] = []
        for (index, step) in lesson.steps.enumerated() {
            let label: String
            var score: Score?
            switch step {
            case .look(let text, let picture):
                label = text
                if case .staff(let s) = picture { score = s }
                if case .keyboard(let k) = picture { score = k.score }
            case .listen(let text, _, _, let keyboard, _): label = text; score = keyboard.score
            case .play(let text, _, _, let keyboard, _): label = text; score = keyboard.score
            case .rhythm(let text, _, _, _, let keyboard): label = text; score = keyboard.score
            }
            if let score { items.append(("Pas \(index + 1). \(label)", score)) }
        }
        guard !items.isEmpty else { continue }
        let view = VStack(alignment: .leading, spacing: 10) {
            Text("Lliçó \(lesson.number): \(lesson.title)").font(.headline)
            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                Text(item.0).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                StaffView(score: item.1, spacing: item.1.grand ? 9 : 13)
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background(Theme.card, in: RoundedRectangle(cornerRadius: 16))
            }
        }
        .padding(16)
        .frame(width: 375)
        .background(Theme.paper)
        let renderer = ImageRenderer(content: view)
        renderer.scale = 2
        guard let image = renderer.nsImage, let tiff = image.tiffRepresentation,
              let png = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:]) else { continue }
        let name = String(format: "llico-%02d.png", lesson.number)
        try? png.write(to: folder.appendingPathComponent(name))
        print("build/revisio/" + name)
    }
}

@main struct Main {
    static func main() {
        MainActor.assumeIsolated {
            if CommandLine.arguments.contains("--curs") { renderCourse() } else { renderAll() }
        }
    }
}
