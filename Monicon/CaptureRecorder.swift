import AVFoundation
import Photos
import UIKit

final class CaptureRecorder {
    private var writer: AVAssetWriter?
    private var input: AVAssetWriterInput?
    private var adaptor: AVAssetWriterInputPixelBufferAdaptor?
    private var outputURL: URL?
    private var frameNumber: Int64 = 0
    private var frameRate: Int32 = 60

    var isRecording: Bool { writer != nil }

    func start(width: Int, height: Int, fps: Int32 = 60) throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("Monicon-(Int(Date().timeIntervalSince1970)).mp4")
        try? FileManager.default.removeItem(at: url)

        let writer = try AVAssetWriter(outputURL: url, fileType: .mp4)
        let settings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: width,
            AVVideoHeightKey: height,
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: max(width * height * 4, 8_000_000),
                AVVideoExpectedSourceFrameRateKey: fps
            ]
        ]
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: settings)
        input.expectsMediaDataInRealTime = true
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: input,
            sourcePixelBufferAttributes: [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
                kCVPixelBufferWidthKey as String: width,
                kCVPixelBufferHeightKey as String: height
            ])

        guard writer.canAdd(input) else {
            throw NSError(domain: "MoniconRecorder", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "Cannot add video writer input"])
        }
        writer.add(input)
        guard writer.startWriting() else {
            throw writer.error ?? NSError(domain: "MoniconRecorder", code: 2,
                                          userInfo: [NSLocalizedDescriptionKey: "Cannot start video writer"])
        }
        writer.startSession(atSourceTime: .zero)
        self.writer = writer
        self.input = input
        self.adaptor = adaptor
        self.outputURL = url
        self.frameNumber = 0
        self.frameRate = fps
    }

    func append(rgb: Data, width: Int, height: Int) {
        guard let input, let adaptor, input.isReadyForMoreMediaData else { return }
        var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(kCFAllocatorDefault, width, height,
                                         kCVPixelFormatType_32BGRA, nil, &pixelBuffer)
        guard status == kCVReturnSuccess, let pixelBuffer else { return }

        CVPixelBufferLockBaseAddress(pixelBuffer, [])
        if let destination = CVPixelBufferGetBaseAddress(pixelBuffer) {
            let dst = destination.assumingMemoryBound(to: UInt8.self)
            rgb.withUnsafeBytes { sourceRaw in
                guard let source = sourceRaw.baseAddress?.assumingMemoryBound(to: UInt8.self) else { return }
                let srcStride = width * 3
                let dstStride = CVPixelBufferGetBytesPerRow(pixelBuffer)
                for y in 0..<height {
                    for x in 0..<width {
                        let sourceIndex = y * srcStride + x * 3
                        let destinationIndex = y * dstStride + x * 4
                        dst[destinationIndex] = source[sourceIndex + 2]
                        dst[destinationIndex + 1] = source[sourceIndex + 1]
                        dst[destinationIndex + 2] = source[sourceIndex]
                        dst[destinationIndex + 3] = 255
                    }
                }
            }
        }
        CVPixelBufferUnlockBaseAddress(pixelBuffer, [])

        let time = CMTime(value: frameNumber, timescale: frameRate)
        if adaptor.append(pixelBuffer, withPresentationTime: time) {
            frameNumber += 1
        }
    }

    func finish(completion: @escaping (URL?) -> Void) {
        guard let writer, let url = outputURL else {
            completion(nil)
            return
        }
        input?.markAsFinished()
        self.writer = nil
        self.input = nil
        self.adaptor = nil
        self.outputURL = nil
        writer.finishWriting {
            DispatchQueue.main.async {
                if writer.status == .completed {
                    self.saveToPhotos(url: url)
                    completion(url)
                } else {
                    completion(nil)
                }
            }
        }
    }

    private func saveToPhotos(url: URL) {
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            guard status == .authorized || status == .limited else { return }
            PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: url)
            }
        }
    }
}
