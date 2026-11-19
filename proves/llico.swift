import Foundation
import QuartzCore

// Fa córrer una lliçó de debò (el mateix LessonRunner de l'app) al Mac, tocant les notes al seu moment.
// Serveix per veure què diu l'app quan es toca un ritme bé: proves/llico.sh <número de lliçó>

enum ClauApp { static let isTest = false }

/// Un motor de so de mentida: no sona, només deixa passar les crides.
final class AudioEngine {
    var onNote: ((Int) -> Void)?
    var clicks: [Double] = []
    func start(microphone: Bool) {}
    func setListening(_ on: Bool) {}
    func stopPlaying() {}
    func play(midi: Int, seconds: Double, gain: Float = 0.32) {}
    func click(accent: Bool) { clicks.append(CACurrentMediaTime()) }
    func noteOn(midi: Int, gain: Float = 0.32) -> Int { 1 }
    func noteOff(_ id: Int) {}
    var outputDelay: Double { 0 }
}

@MainActor
func run(lessonNumber: Int, offset: Double) async -> Bool {
    guard let lesson = Course.allLessons.first(where: { $0.number == lessonNumber }) else { return false }
    let audio = AudioEngine()
    let runner = LessonRunner(lesson: lesson, instrument: .screen)
    runner.begin(audio: audio)
    var allGood = true

    while !runner.finished {
        guard case .rhythm(let text, let tones, let bpm, let rounds, _) = runner.step else {
            runner.advance()
            continue
        }
        let beat = 60 / bpm
        print("  pas \(runner.stepIndex + 1): «\(text)» a \(Int(bpm)), \(rounds) vegades")
        let index = runner.stepIndex
        var attempts = 0
        while runner.stepIndex == index, !runner.finished, attempts < rounds {
            attempts += 1
            audio.clicks = []
            if runner.rhythmPhase == .idle { runner.startRhythm() }
            // Espera els quatre cops d'entrada i toca cada nota quan toca, seguint els cops que sonen.
            while audio.clicks.count < 4 { try? await Task.sleep(for: .milliseconds(5)) }
            let first = audio.clicks[3] + beat
            var at = first
            for tone in tones {
                if !tone.rest {
                    let wait = at + offset - CACurrentMediaTime()
                    if wait > 0 { try? await Task.sleep(for: .seconds(wait), tolerance: .zero) }
                    runner.keyPressed(tone.midi, at: CACurrentMediaTime())
                }
                at += tone.beats * beat
            }
            // Fins que l'app digui com ha anat.
            while runner.rhythmPhase != .idle { try? await Task.sleep(for: .milliseconds(20)) }
            let marks = runner.marks.map { "\($0)".prefix(1) }.joined()
            print("     volta \(attempts): \(runner.mood == .wrong ? "MAL" : "bé ") [\(marks)] \(runner.message)")
            if runner.mood == .wrong { allGood = false; break }
            try? await Task.sleep(for: .seconds(0.3))
            // L'app torna a començar sola després d'una volta bona.
            while runner.stepIndex == index, !runner.finished, runner.rhythmPhase == .idle, !runner.stepComplete, attempts < rounds {
                try? await Task.sleep(for: .milliseconds(20))
            }
        }
        while runner.stepIndex == index, !runner.finished {
            if runner.mood == .wrong { runner.advance() } else { try? await Task.sleep(for: .milliseconds(50)) }
        }
    }
    return allGood
}

@main
struct Main {
    static func main() async {
        let number = CommandLine.arguments.count > 1 ? Int(CommandLine.arguments[1]) ?? 21 : 21
        let offset = CommandLine.arguments.count > 2 ? Double(CommandLine.arguments[2]) ?? 0 : 0
        print("Lliçó \(number), tocant \(offset == 0 ? "just al cop" : "\(offset) s desplaçat")")
        let good = await run(lessonNumber: number, offset: offset)
        print(good ? "Tot bé." : "Hi ha ritmes que surten malament tocant-los bé.")
        exit(good ? 0 : 1)
    }
}
