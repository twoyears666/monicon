import AVFoundation

final class CaptureCardAudioRouter {
    private let engine = AVAudioEngine()
    private var isRunning = false

    func start() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .default,
                                options: [.defaultToSpeaker, .allowBluetooth, .mixWithOthers])
        try session.setActive(true, options: [])
        try? session.overrideOutputAudioPort(.speaker)

        guard let inputs = session.availableInputs,
              let usbInput = inputs.first(where: { $0.portType == .usbAudio }) else {
            let ports = session.availableInputs?.map { "\($0.portType.rawValue):\($0.portName)" }.joined(separator: ", ") ?? "none"
            throw NSError(domain: "MoniconAudio", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "No USB capture-card audio input. Available: \(ports)"])
        }
        try session.setPreferredInput(usbInput)

        let input = engine.inputNode
        if engine.isRunning { engine.stop() }
        engine.disconnectNodeOutput(input)
        engine.disconnectNodeInput(engine.mainMixerNode)
        engine.disconnectNodeOutput(engine.mainMixerNode)
        let format = input.inputFormat(forBus: 0)
        guard format.sampleRate > 0 && format.channelCount > 0 else {
            throw NSError(domain: "MoniconAudio", code: 2,
                          userInfo: [NSLocalizedDescriptionKey: "USB audio format is unavailable"])
        }
        engine.connect(input, to: engine.mainMixerNode, format: format)
        engine.connect(engine.mainMixerNode, to: engine.outputNode, format: nil)
        engine.mainMixerNode.outputVolume = 1.0
        engine.prepare()
        try engine.start()
        isRunning = true
    }

    func stop() {
        guard isRunning else { return }
        engine.stop()
        engine.disconnectNodeInput(engine.mainMixerNode)
        try? AVAudioSession.sharedInstance().overrideOutputAudioPort(.none)
        try? AVAudioSession.sharedInstance().setActive(false)
        isRunning = false
    }
}
