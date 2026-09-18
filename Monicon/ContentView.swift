import SwiftUI
import AVFoundation

struct ContentView: View {
    @EnvironmentObject private var capture: CaptureSessionManager
    @State private var showSettings = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 0) {
                HStack {
                    Label("MONICON", systemImage: "gamecontroller.fill")
                        .font(.headline.weight(.bold))
                    Spacer()
                    Circle().fill(capture.isRunning ? .green : .gray).frame(width: 8, height: 8)
                    Text(capture.isRunning ? "LIVE" : "IDLE")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Button { showSettings = true } label: {
                        Image(systemName: "slider.horizontal.3")
                    }
                    .buttonStyle(.bordered)
                }
                .padding()

                GeometryReader { _ in
                    ZStack {
                        RoundedRectangle(cornerRadius: 18)
                            .fill(Color(red: 0.06, green: 0.07, blue: 0.09))

                        if let directImage = capture.directImage {
                            DirectImagePreview(image: directImage, mode: capture.displayMode)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                                .padding(10)
                        } else if capture.isRunning {
                            VideoPreview(session: capture.session, mode: capture.displayMode)
                                .aspectRatio(16 / 9, contentMode: .fit)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                                .padding(10)
                        } else {
                            VStack(spacing: 12) {
                                Image(systemName: "rectangle.inset.filled.and.person.filled")
                                    .font(.system(size: 42))
                                    .foregroundStyle(.secondary)
                                Text("Plug in your capture card")
                                    .font(.title3.weight(.semibold))
                                Text("原始比例默认保留完整画面，也可以切换拉伸或填充。")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                            .padding()
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }

                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(capture.status)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        if !capture.lastAction.isEmpty {
                            Text(capture.lastAction)
                                .font(.caption)
                                .foregroundStyle(capture.isRecording ? .red : .secondary)
                        }
                    }
                    Spacer()
                    CaptureActionButton(isRecording: capture.isRecording,
                                        onSingleTap: { capture.takeScreenshot() },
                                        onDoubleTap: { capture.toggleRecording() })
                        .frame(width: 58, height: 44)
                    Button(capture.isRunning ? "Stop" : "Start") {
                        capture.isRunning ? capture.stop() : capture.start()
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
            }
        }
        .sheet(isPresented: $showSettings) { SettingsView().environmentObject(capture) }
        .onAppear { capture.refreshDevices() }
    }
}

struct DirectImagePreview: View {
    let image: CGImage
    let mode: VideoDisplayMode

    var body: some View {
        let source = Image(decorative: image, scale: 1, orientation: .up)
            .resizable()
        Group {
            switch mode {
            case .fit:
                source.aspectRatio(contentMode: .fit)
            case .stretch:
                source
            case .fill:
                source.aspectRatio(contentMode: .fill).clipped()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct CaptureActionButton: View {
    let isRecording: Bool
    let onSingleTap: () -> Void
    let onDoubleTap: () -> Void
    @State private var pendingSingleTap: DispatchWorkItem?

    var body: some View {
        Image(systemName: isRecording ? "stop.circle.fill" : "record.circle")
            .font(.system(size: 28))
            .foregroundStyle(isRecording ? .red : .white)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
            .contentShape(Rectangle())
            .onTapGesture(count: 2) {
                pendingSingleTap?.cancel()
                onDoubleTap()
            }
            .onTapGesture(count: 1) {
                let work = DispatchWorkItem { onSingleTap() }
                pendingSingleTap = work
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.28, execute: work)
            }
            .accessibilityLabel(isRecording ? "结束录制" : "截图或录制")
            .accessibilityHint("短按截图，双击开始或结束录制")
    }
}

struct SettingsView: View {
    @EnvironmentObject private var capture: CaptureSessionManager

    var body: some View {
        NavigationStack {
            Form {
                Section("Capture") {
                    Picker("Resolution", selection: $capture.selectedResolution) {
                        ForEach(capture.resolutions, id: \.self, content: Text.init)
                    }
                    Picker("Frame rate", selection: $capture.selectedFrameRate) {
                        ForEach(capture.frameRates, id: \.self, content: Text.init)
                    }
                    Text("Changes apply the next time you start capture.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Section("Audio") {
                    Toggle(isOn: Binding(
                        get: { capture.audioEnabled },
                        set: { capture.setAudioEnabled($0) }
                    )) {
                        Label("采集卡音频", systemImage: "speaker.wave.2.fill")
                    }
                    Text("关闭后不会播放采集卡声音，也不会切换到 iPad 麦克风。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Section("Video") {
                    Picker("显示方式", selection: $capture.displayMode) {
                        ForEach(VideoDisplayMode.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    Text("原始比例为默认模式：完整显示画面；填充模式可能裁掉边缘；拉伸模式会改变比例。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Settings")
        }
    }
}

struct VideoPreview: UIViewRepresentable {
    let session: AVCaptureSession
    let mode: VideoDisplayMode

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.videoPreviewLayer.session = session
        view.set(mode: mode)
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {
        uiView.videoPreviewLayer.session = session
        uiView.set(mode: mode)
    }
}

final class PreviewView: UIView {
    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
    var videoPreviewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }

    override init(frame: CGRect) {
        super.init(frame: frame)
        videoPreviewLayer.videoGravity = .resizeAspect
        backgroundColor = .black
    }

    func set(mode: VideoDisplayMode) {
        switch mode {
        case .fit: videoPreviewLayer.videoGravity = .resizeAspect
        case .stretch: videoPreviewLayer.videoGravity = .resize
        case .fill: videoPreviewLayer.videoGravity = .resizeAspectFill
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}
