import CoreMIDI
import QuartzCore

/// Un piano digital connectat amb un cable. Diu exactament quines tecles es toquen, encara que en comencin dues alhora,
/// que és el que el micròfon no pot sentir. Només s'escolta: Clau no envia res al piano.
final class MIDIInput: ObservableObject {
    /// Hi ha algun piano connectat ara mateix.
    @Published private(set) var connected = false

    /// S'avisa al fil principal cada vegada que es prem una tecla: quina i en quin moment (el rellotge de `CACurrentMediaTime`).
    var onNote: ((Int, TimeInterval) -> Void)?
    /// Una tecla que s'ha deixat anar, amb el seu instant: per saber si s'ha aguantat una nota llarga.
    var onRelease: ((Int, TimeInterval) -> Void)?

    private var client = MIDIClientRef()
    private var port = MIDIPortRef()
    private var sources: Set<MIDIEndpointRef> = []
    private static let secondsPerTick: Double = {
        var info = mach_timebase_info_data_t()
        mach_timebase_info(&info)
        return Double(info.numer) / Double(info.denom) / 1_000_000_000
    }()

    func start() {
        guard client == 0 else { return }
        MIDIClientCreateWithBlock("Clau" as CFString, &client) { [weak self] _ in
            // Algú ha endollat o desendollat un aparell.
            DispatchQueue.main.async { self?.refresh() }
        }
        MIDIInputPortCreateWithProtocol(client, "Entrada" as CFString, ._1_0, &port) { [weak self] list, _ in
            self?.receive(list)
        }
        refresh()
    }

    /// Connecta els pianos que hi hagi i recorda si n'hi ha cap.
    private func refresh() {
        var found: Set<MIDIEndpointRef> = []
        for index in 0..<MIDIGetNumberOfSources() {
            let source = MIDIGetSource(index)
            guard source != 0, MIDIInput.isInstrument(source) else { continue }
            found.insert(source)
            if !sources.contains(source) { MIDIPortConnectSource(port, source, nil) }
        }
        for gone in sources.subtracting(found) { MIDIPortDisconnectSource(port, gone) }
        sources = found
        if connected != !found.isEmpty { connected = !found.isEmpty }
    }

    /// Un aparell de debò i endollat: ni la sessió de xarxa ni els busos interns del sistema, que hi són encara que no hi hagi cap piano.
    private static func isInstrument(_ source: MIDIEndpointRef) -> Bool {
        var offline: Int32 = 0
        if MIDIObjectGetIntegerProperty(source, kMIDIPropertyOffline, &offline) == noErr, offline != 0 { return false }
        var entity = MIDIEntityRef()
        var device = MIDIDeviceRef()
        guard MIDIEndpointGetEntity(source, &entity) == noErr, MIDIEntityGetDevice(entity, &device) == noErr else { return true }
        var owner: Unmanaged<CFString>?
        guard MIDIObjectGetStringProperty(device, kMIDIPropertyDriverOwner, &owner) == noErr, let name = owner?.takeRetainedValue() as String? else { return true }
        return !name.contains("RTP") && !name.contains("IAC")
    }

    private func receive(_ list: UnsafePointer<MIDIEventList>) {
        var notes: [(Int, TimeInterval)] = []
        var releases: [(Int, TimeInterval)] = []
        for packet in list.unsafeSequence() {
            let stamp = packet.pointee.timeStamp
            let time = stamp == 0 ? CACurrentMediaTime() : Double(stamp) * MIDIInput.secondsPerTick
            for word in packet.words() {
                // Missatge MIDI 1.0 de canal (tipus 2): estat, nota i força.
                guard word >> 28 == 0x2 else { continue }
                let status = (word >> 16) & 0xF0
                let note = Int((word >> 8) & 0x7F)
                let velocity = word & 0x7F
                if status == 0x90, velocity > 0 { notes.append((note, time)) }
                // Deixar anar: «nota apagada», o «nota encesa» amb força zero, com fan molts pianos.
                if status == 0x80 || (status == 0x90 && velocity == 0) { releases.append((note, time)) }
            }
        }
        guard !notes.isEmpty || !releases.isEmpty else { return }
        DispatchQueue.main.async { [weak self] in
            for (note, time) in notes { self?.onNote?(note, time) }
            for (note, time) in releases { self?.onRelease?(note, time) }
        }
    }
}
