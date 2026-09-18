import AVFoundation

final class CaptureCardAudioRouter {
    private let engine = AVAudioEngine()
    private var isRunning = false

    func start() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .gameChat, options: [.defaultToSpeaker, .allowBluetooth])
        try session.setActive(true)

        guard let usbInput = session.availableInputs?.first(where: { $0.portType == .usbAudio }) else {
            throw NSError(domain: "MoniconAudio", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "No USB capture-card audio input"])
        }
        try session.setPreferredInput(usbInput)

        let input = engine.inputNode
        let format = input.inputFormat(forBus: 0)
        engine.connect(input, to: engine.mainMixerNode, format: format)
        engine.prepare()
        try engine.start()
        isRunning = true
    }

    func stop() {
        guard isRunning else { return }
        engine.stop()
        engine.disconnectNodeInput(engine.mainMixerNode)
        try? AVAudioSession.sharedInstance().setActive(false)
        isRunning = false
    }
}
