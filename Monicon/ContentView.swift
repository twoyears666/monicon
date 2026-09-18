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
                    Text(capture.isRunning ? "LIVE" : "IDLE").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                    Button { showSettings = true } label: { Image(systemName: "slider.horizontal.3") }
                        .buttonStyle(.bordered)
                }
                .padding()
                GeometryReader { proxy in
                    ZStack {
                        RoundedRectangle(cornerRadius: 18).fill(Color(red: 0.06, green: 0.07, blue: 0.09))
                        if let directImage = capture.directImage {
                            Image(decorative: directImage, scale: 1, orientation: .up)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                                .padding(10)
                        } else if capture.isRunning {
                            VideoPreview(session: capture.session)
                                .aspectRatio(16 / 9, contentMode: .fit)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                                .padding(10)
                        } else {
                            VStack(spacing: 12) {
                                Image(systemName: "rectangle.inset.filled.and.person.filled").font(.system(size: 42)).foregroundStyle(.secondary)
                                Text("Plug in your capture card").font(.title3.weight(.semibold))
                                Text("The full frame will fit inside this window — no cropping.").font(.subheadline).foregroundStyle(.secondary)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                HStack {
                    Text(capture.status).font(.footnote).foregroundStyle(.secondary)
                    Spacer()
                    Button(capture.isRunning ? "Stop" : "Start") { capture.isRunning ? capture.stop() : capture.start() }
                        .buttonStyle(.borderedProminent)
                }
                .padding()
            }
        }
        .sheet(isPresented: $showSettings) { SettingsView().environmentObject(capture) }
        .onAppear { capture.refreshDevices() }
    }
}

struct SettingsView: View {
    @EnvironmentObject private var capture: CaptureSessionManager
    var body: some View {
        NavigationStack {
            Form {
                Section("Capture") {
                    Picker("Resolution", selection: $capture.selectedResolution) { ForEach(capture.resolutions, id: \.self, content: Text.init) }
                    Picker("Frame rate", selection: $capture.selectedFrameRate) { ForEach(capture.frameRates, id: \.self, content: Text.init) }
                    Text("Changes apply the next time you start capture.").font(.caption).foregroundStyle(.secondary)
                }
                Section("Audio") { Label("Capture card audio only", systemImage: "speaker.wave.2.fill"); Text("iPad microphone is not connected.").font(.caption).foregroundStyle(.secondary) }
                Section("Video") { Label("Fit mode", systemImage: "rectangle.inset.filled"); Text("Aspect-fit preserves the entire input image and may show black bars.").font(.caption).foregroundStyle(.secondary) }
            }
            .navigationTitle("Settings")
        }
    }
}

struct VideoPreview: UIViewRepresentable {
    let session: AVCaptureSession
    func makeUIView(context: Context) -> PreviewView { let v = PreviewView(); v.videoPreviewLayer.session = session; return v }
    func updateUIView(_ uiView: PreviewView, context: Context) { uiView.videoPreviewLayer.session = session }
}

final class PreviewView: UIView {
    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
    var videoPreviewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
    override init(frame: CGRect) { super.init(frame: frame); videoPreviewLayer.videoGravity = .resizeAspect; backgroundColor = .black }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

