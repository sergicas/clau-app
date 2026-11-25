import CoreMIDI
import Foundation

// Un piano de mentida connectat «per cable»: crea una font MIDI virtual al Mac i hi toca les notes que se li diuen.
// Serveix per provar, amb Clau oberta al Mac, que l'app rep les tecles d'un piano digital sense tenir-ne cap.
// Ús: piano-virtual <segons d'espera> <nota[+nota]...> [cada <segons>]
//   piano-virtual 3 60 60 60            tres dos, un per segon, al cap de 3 segons
//   piano-virtual 3 60+48 62+50 64+52   les dues mans alhora
var client = MIDIClientRef()
var source = MIDIEndpointRef()
MIDIClientCreateWithBlock("Piano de prova" as CFString, &client) { _ in }
MIDISourceCreateWithProtocol(client, "Piano de prova" as CFString, ._1_0, &source)

var arguments = Array(CommandLine.arguments.dropFirst())
let wait = Double(arguments.isEmpty ? "3" : arguments.removeFirst()) ?? 3
var every = 1.0
if let index = arguments.firstIndex(of: "cada"), index + 1 < arguments.count {
    every = Double(arguments[index + 1]) ?? 1
    arguments.removeSubrange(index...)
}

func send(_ status: UInt32, _ note: UInt32) {
    var list = MIDIEventList()
    let packet = MIDIEventListInit(&list, ._1_0)
    let word: UInt32 = 0x2 << 28 | status << 16 | note << 8 | (status == 0x90 ? 90 : 0)
    _ = MIDIEventListAdd(&list, MemoryLayout<MIDIEventList>.size, packet, 0, 1, [word])
    MIDIReceivedEventList(source, &list)
}

print("Piano de prova connectat. Espero \(wait) s.")
Thread.sleep(forTimeInterval: wait)
for chord in arguments {
    let notes = chord.split(separator: "+").compactMap { UInt32($0) }
    for note in notes { send(0x90, note) }
    print("toco \(chord)")
    Thread.sleep(forTimeInterval: every * 0.6)
    for note in notes { send(0x80, note) }
    Thread.sleep(forTimeInterval: every * 0.4)
}
Thread.sleep(forTimeInterval: 1)
