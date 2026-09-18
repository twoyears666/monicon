import AVFoundation
import Combine
import CoreMedia
import CoreGraphics

final class CaptureSessionManager: NSObject, ObservableObject {
    @Published var isRunning = false
    @Published var status = "Connect a UVC capture card"
    @Published var selectedResolution = "Auto"
    @Published var selectedFrameRate = "Auto"
    @Published var devices: [AVCaptureDevice] = []
    @Published var directImage: CGImage?
    @Published var usesDirectUVC = true

    private let directBackend = MNDirectUVCBackend()
    private let captureCardAudio = CaptureCardAudioRouter()

    let session = AVCaptureSession()
    private let videoOutput = AVCaptureVideoDataOutput()
    private let audioOutput = AVCaptureAudioDataOutput()
    private let audioEngine = AVAudioEngine()
    private let audioPlayer = AVAudioPlayerNode()
    private let queue = DispatchQueue(label: "monicon.capture", qos: .userInteractive)
    private var currentVideoInput: AVCaptureDeviceInput?
    private var currentAudioInput: AVCaptureDeviceInput?

    let resolutions = ["Auto", "1920 × 1080", "1280 × 720", "720 × 480"]
    let frameRates = ["Auto", "60 fps", "30 fps", "24 fps"]

    override init() {
        super.init()
        directBackend.delegate = self
        refreshDevices()
        session.sessionPreset = .high
        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.setSampleBufferDelegate(self, queue: queue)
        audioOutput.setSampleBufferDelegate(self, queue: queue)
        audioEngine.attach(audioPlayer)
        audioEngine.connect(audioPlayer, to: audioEngine.mainMixerNode, format: nil)
        audioEngine.prepare()
    }

    func refreshDevices() {
        devices = AVCaptureDevice.devices(for: .video)
        status = devices.isEmpty ? "Connect a UVC capture card" : "Ready: \(devices.count) capture card(s)"
    }

    func start(device: AVCaptureDevice? = nil) {
        if usesDirectUVC {
            directBackend.start(withWidth: 1280, height: 720, fps: 60)
            do { try captureCardAudio.start() } catch { DispatchQueue.main.async { self.status = "USB video opened; capture-card audio unavailable" } }
            DispatchQueue.main.async { self.isRunning = true; if self.status == "Connect a UVC capture card" { self.status = "Opening direct UVC…" } }
            return
        }
        queue.async {
            self.session.beginConfiguration()
            defer { self.session.commitConfiguration() }
            self.session.inputs.forEach { self.session.removeInput($0) }
            self.session.outputs.forEach { self.session.removeOutput($0) }
            let videoDevice = device ?? self.devices.first
            guard let videoDevice,
                  let videoInput = try? AVCaptureDeviceInput(device: videoDevice),
                  self.session.canAddInput(videoInput) else {
                DispatchQueue.main.async { self.status = "No compatible UVC video input" }
                return
            }
            self.session.addInput(videoInput)
            self.currentVideoInput = videoInput

            if let audioDevice = AVCaptureDevice.devices(for: .audio).first,
               let audioInput = try? AVCaptureDeviceInput(device: audioDevice),
               self.session.canAddInput(audioInput) {
                self.session.addInput(audioInput)
                self.currentAudioInput = audioInput
            }
            if self.session.canAddOutput(self.videoOutput) { self.session.addOutput(self.videoOutput) }
            if self.session.canAddOutput(self.audioOutput) { self.session.addOutput(self.audioOutput) }
            self.applyFormat(to: videoDevice)
            self.session.startRunning()
            try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .gameChat, options: [.allowBluetooth, .defaultToSpeaker])
            try? AVAudioSession.sharedInstance().setActive(true)
            try? self.audioEngine.start()
            self.audioPlayer.play()
            DispatchQueue.main.async {
                self.isRunning = true
                self.status = "Live • capture-card audio only"
            }
        }
    }

    func stop() {
        if usesDirectUVC {
            directBackend.stop()
            captureCardAudio.stop()
            DispatchQueue.main.async { self.isRunning = false; self.directImage = nil; self.status = "Stopped" }
            return
        }
        queue.async {
            self.session.stopRunning()
            self.audioPlayer.stop()
            self.audioEngine.stop()
            DispatchQueue.main.async {
                self.isRunning = false
                self.status = "Stopped"
            }
        }
    }

    func applyFormat(to device: AVCaptureDevice) {
        guard selectedResolution != "Auto" || selectedFrameRate != "Auto" else { return }
        let width = selectedResolution == "1920 × 1080" ? 1920 : selectedResolution == "1280 × 720" ? 1280 : 720
        let height = selectedResolution == "1920 × 1080" ? 1080 : selectedResolution == "1280 × 720" ? 720 : 480
        let fps = selectedFrameRate == "60 fps" ? 60.0 : selectedFrameRate == "30 fps" ? 30.0 : 24.0
        guard let format = device.formats.first(where: { f in
            let d = CMVideoFormatDescriptionGetDimensions(f.formatDescription)
            return d.width == width && d.height == height && f.videoSupportedFrameRateRanges.contains { $0.maxFrameRate >= fps }
        }) else { return }
        try? device.lockForConfiguration()
        device.activeFormat = format
        device.activeVideoMinFrameDuration = CMTime(value: 1, timescale: CMTimeScale(fps))
        device.activeVideoMaxFrameDuration = CMTime(value: 1, timescale: CMTimeScale(fps))
        device.unlockForConfiguration()
    }
}

extension CaptureSessionManager: AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureAudioDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard output === audioOutput,
              let description = CMSampleBufferGetFormatDescription(sampleBuffer) else { return }
        let format = AVAudioFormat(cmAudioFormatDescription: description)
        guard let pcm = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(sampleBuffer.numSamples)) else { return }
        pcm.frameLength = AVAudioFrameCount(sampleBuffer.numSamples)
        var size = 0
        CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer(sampleBuffer, bufferListSizeNeededOut: &size, bufferListOut: nil, bufferListSize: 0, blockBufferAllocator: nil, blockBufferMemoryAllocator: nil, flags: 0, blockBufferOut: nil)
        let raw = UnsafeMutableRawPointer.allocate(byteCount: size, alignment: MemoryLayout<AudioBufferList>.alignment)
        defer { raw.deallocate() }
        let list = raw.assumingMemoryBound(to: AudioBufferList.self)
        guard CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer(sampleBuffer, bufferListSizeNeededOut: &size, bufferListOut: list, bufferListSize: size, blockBufferAllocator: nil, blockBufferMemoryAllocator: nil, flags: 0, blockBufferOut: nil) == noErr else { return }
        let source = UnsafeMutableAudioBufferListPointer(list)
        let destination = UnsafeMutableAudioBufferListPointer(pcm.mutableAudioBufferList)
        for index in 0..<min(source.count, destination.count) {
            guard let sourceData = source[index].mData, let destinationData = destination[index].mData else { continue }
            memcpy(destinationData, sourceData, min(Int(source[index].mDataByteSize), Int(destination[index].mDataByteSize)))
        }
        audioPlayer.scheduleBuffer(pcm)
    }
}


extension CaptureSessionManager: MNDirectUVCBackendDelegate {
    func uvcBackendDidStart(withWidth width: UInt, height: UInt, fps: UInt) {
        status = "Direct UVC live • \(width)×\(height) @ \(fps) fps"
        isRunning = true
    }

    func uvcBackendDidReceiveRGB(_ rgb: Data, width: UInt, height: UInt) {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let provider = CGDataProvider(data: rgb as CFData)
        directImage = CGImage(width: Int(width), height: Int(height), bitsPerComponent: 8,
                              bitsPerPixel: 24, bytesPerRow: Int(width) * 3,
                              space: colorSpace,
                              bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue),
                              provider: provider!, decode: nil, shouldInterpolate: false,
                              intent: .defaultIntent)
    }

    func uvcBackendDidFail(_ message: String) {
        isRunning = false
        status = "Direct UVC failed: \(message)"
    }
}
