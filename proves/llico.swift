import Foundation
import QuartzCore

// Fa córrer una lliçó de debò (el mateix LessonRunner de l'app) al Mac, tocant les notes al seu moment.
// Serveix per veure què diu l'app quan es toca un ritme bé: proves/llico.sh <número de lliçó> [desplaçament] [manera]
// Manera: «bé» (per defecte: cada dit s'aixeca just abans del final de la nota), «solta» (les notes llargues
// es deixen anar al cap de mig cop) o «octava» (les notes de la mà esquerra, una octava més amunt).

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

/// Cap piano per cable: tot es toca a la pantalla.
final class MIDIInput: ObservableObject {
    @Published var connected = false
    var onNote: ((Int, TimeInterval) -> Void)?
    var onRelease: ((Int, TimeInterval) -> Void)?
    func start() {}
}

enum Way: String { case good = "bé", letGo = "solta", octave = "octava" }

@MainActor
func run(lessonNumber: Int, offset: Double, way: Way) async -> [String] {
    guard let lesson = Course.allLessons.first(where: { $0.number == lessonNumber }) else { return ["no hi ha la lliçó"] }
    let audio = AudioEngine()
    let runner = LessonRunner(lesson: lesson, instrument: .screen)
    runner.begin(audio: audio, midi: MIDIInput())
    var failed: [String] = []

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
            let lead = runner.meter
            while audio.clicks.count < lead { try? await Task.sleep(for: .milliseconds(5)) }
            let first = audio.clicks[lead - 1] + beat
            // Primer es fa la llista de quan s'enfonsa i quan s'aixeca cada tecla, i després es toca en ordre.
            var events: [(time: Double, midi: Int, down: Bool)] = []
            var at = first
            for tone in tones {
                if !tone.rest {
                    for (key, written) in [(tone.midi, tone.written)] + (tone.also.map { [($0, tone.alsoWritten)] } ?? []) {
                        let played = way == .octave && key < 60 ? key + 12 : key
                        let lift = way == .letGo && written >= 2 ? 0.5 : written - 0.15
                        events.append((at + offset, played, true))
                        events.append((at + offset + lift * beat, played, false))
                    }
                }
                at += tone.beats * beat
            }
            events.sort { $0.time < $1.time || ($0.time == $1.time && !$0.down) }
            for event in events {
                let wait = event.time - CACurrentMediaTime()
                if wait > 0 { try? await Task.sleep(for: .seconds(wait), tolerance: .zero) }
                if event.down { runner.keyPressed(event.midi, at: CACurrentMediaTime()) } else { runner.keyReleased(event.midi) }
            }
            // Fins que l'app digui com ha anat.
            while runner.rhythmPhase != .idle { try? await Task.sleep(for: .milliseconds(20)) }
            let marks = runner.marks.map { "\($0)".prefix(1) }.joined()
            print("     volta \(attempts): \(runner.mood == .wrong ? "MAL" : "bé ") [\(marks)] \(runner.message)")
            if runner.mood == .wrong { failed.append("pas \(index + 1): \(runner.message)"); break }
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
    return failed
}

@main
struct Main {
    static func main() async {
        let number = CommandLine.arguments.count > 1 ? Int(CommandLine.arguments[1]) ?? 21 : 21
        let offset = CommandLine.arguments.count > 2 ? Double(CommandLine.arguments[2]) ?? 0 : 0
        let way = CommandLine.arguments.count > 3 ? Way(rawValue: CommandLine.arguments[3]) ?? .good : .good
        print("Lliçó \(number), tocant \(offset == 0 ? "just al cop" : "\(offset) s desplaçat"), manera «\(way.rawValue)»")
        let failed = await run(lessonNumber: number, offset: offset, way: way)
        print(failed.isEmpty ? "Tot bé." : "Passos que no passen: \(failed.count).")
        exit(failed.isEmpty ? 0 : 1)
    }
}
