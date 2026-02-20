//
//  CameraView.swift
//  KnowEat
//
//  Created by Lisette HG on 20/02/26.
//

import SwiftUI
import AVFoundation

struct CameraView: View {
    let onPhotosReady: ([UIImage]) -> Void
    let onCancelled: () -> Void

    @State private var capturedPhotos: [UIImage] = []
    @State private var showFlash = false

    var body: some View {
        ZStack {
            CameraPreviewLayer()
                .ignoresSafeArea()

            if showFlash {
                Color.white
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            }

            VStack {
                topBar
                Spacer()
                if !capturedPhotos.isEmpty {
                    photoStrip
                }
                bottomBar
            }
        }
        .statusBarHidden()
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack {
            Button {
                onCancelled()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(12)
                    .background(.ultraThinMaterial, in: Circle())
            }

            Spacer()

            if !capturedPhotos.isEmpty {
                Text("\(capturedPhotos.count) photo\(capturedPhotos.count == 1 ? "" : "s")")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(.ultraThinMaterial, in: Capsule())
            }

            Spacer()

            Color.clear
                .frame(width: 40, height: 40)
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }

    // MARK: - Photo Strip

    private var photoStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(capturedPhotos.indices, id: \.self) { index in
                    ZStack(alignment: .topTrailing) {
                        Image(uiImage: capturedPhotos[index])
                            .resizable()
                            .scaledToFill()
                            .frame(width: 56, height: 56)
                            .clipShape(RoundedRectangle(cornerRadius: 8))

                        Button {
                            let i = index
                            withAnimation { _ = capturedPhotos.remove(at: i) }
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 18))
                                .foregroundStyle(.white, .black.opacity(0.5))
                        }
                        .offset(x: 6, y: -6)
                    }
                }
            }
            .padding(.horizontal, 24)
        }
        .padding(.bottom, 8)
    }

    // MARK: - Bottom Bar

    private var bottomBar: some View {
        HStack {
            if capturedPhotos.isEmpty {
                Color.clear.frame(width: 60, height: 60)
            } else {
                Button {
                    onPhotosReady(capturedPhotos)
                } label: {
                    Text("Analyze")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(Color("PrimaryOrange"), in: Capsule())
                }
            }

            Spacer()

            Button {
                takePhoto()
            } label: {
                ZStack {
                    Circle()
                        .strokeBorder(.white, lineWidth: 4)
                        .frame(width: 72, height: 72)

                    Circle()
                        .fill(.white)
                        .frame(width: 60, height: 60)
                }
            }

            Spacer()

            Text("Scan all\npages")
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.6))
                .multilineTextAlignment(.center)
                .frame(width: 60)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 20)
    }

    // MARK: - Take Photo

    private func takePhoto() {
        CameraManager.shared.capturePhoto { image in
            if let image {
                withAnimation {
                    showFlash = true
                    capturedPhotos.append(image)
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    withAnimation { showFlash = false }
                }
            }
        }
    }
}

// MARK: - Camera Manager

final class CameraManager: NSObject {
    static let shared = CameraManager()

    let session = AVCaptureSession()
    private let output = AVCapturePhotoOutput()
    private var completion: ((UIImage?) -> Void)?

    override init() {
        super.init()
        configureCaptureSession()
    }

    private func configureCaptureSession() {
        session.beginConfiguration()
        session.sessionPreset = .photo

        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: device) else {
            session.commitConfiguration()
            return
        }

        if session.canAddInput(input) { session.addInput(input) }
        if session.canAddOutput(output) { session.addOutput(output) }

        session.commitConfiguration()
    }

    func start() {
        guard !session.isRunning else { return }
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.session.startRunning()
        }
    }

    func stop() {
        guard session.isRunning else { return }
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.session.stopRunning()
        }
    }

    func capturePhoto(completion: @escaping (UIImage?) -> Void) {
        self.completion = completion
        let settings = AVCapturePhotoSettings()
        output.capturePhoto(with: settings, delegate: self)
    }
}

extension CameraManager: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard let data = photo.fileDataRepresentation(),
              let image = UIImage(data: data) else {
            completion?(nil)
            return
        }
        DispatchQueue.main.async { [weak self] in
            self?.completion?(image)
        }
    }
}

// MARK: - Camera Preview Layer

struct CameraPreviewLayer: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        let previewLayer = AVCaptureVideoPreviewLayer(session: CameraManager.shared.session)
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)
        context.coordinator.previewLayer = previewLayer

        CameraManager.shared.start()

        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        DispatchQueue.main.async {
            context.coordinator.previewLayer?.frame = uiView.bounds
        }
    }

    static func dismantleUIView(_ uiView: UIView, coordinator: Coordinator) {
        CameraManager.shared.stop()
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator {
        var previewLayer: AVCaptureVideoPreviewLayer?
    }
}
