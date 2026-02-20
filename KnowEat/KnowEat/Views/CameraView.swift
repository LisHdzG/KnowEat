//
//  CameraView.swift
//  KnowEat
//
//  Created by Lisette HG on 20/02/26.
//

import SwiftUI
import AVFoundation
import PhotosUI

struct CameraView: View {
    let onPhotosReady: ([UIImage]) -> Void
    let onCancelled: () -> Void

    @State private var capturedPhotos: [UIImage] = []
    @State private var showFlash = false
    @State private var isTorchOn = false
    @State private var galleryItems: [PhotosPickerItem] = []

    var body: some View {
        ZStack {
            CameraPreviewLayer()
                .ignoresSafeArea()

            if showFlash {
                Color.white
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            }

            viewfinderFrame

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
        .onChange(of: galleryItems) { _, items in
            Task {
                for item in items {
                    if let data = try? await item.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        withAnimation { capturedPhotos.append(image) }
                    }
                }
                galleryItems = []
            }
        }
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack {
            Button {
                CameraManager.shared.setTorch(false)
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

            Button {
                isTorchOn.toggle()
                CameraManager.shared.setTorch(isTorchOn)
            } label: {
                Image(systemName: isTorchOn ? "bolt.fill" : "bolt.slash.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(isTorchOn ? .yellow : .white)
                    .padding(12)
                    .background(.ultraThinMaterial, in: Circle())
            }
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

    // MARK: - Viewfinder

    private var viewfinderFrame: some View {
        GeometryReader { geo in
            let w = geo.size.width * 0.78
            let h = w * 1.25
            let x = (geo.size.width - w) / 2
            let y = (geo.size.height - h) / 2 - 40
            let len: CGFloat = 26
            let r: CGFloat = 12

            Path { p in
                p.move(to: CGPoint(x: x, y: y + len))
                p.addLine(to: CGPoint(x: x, y: y + r))
                p.addQuadCurve(to: CGPoint(x: x + r, y: y), control: CGPoint(x: x, y: y))
                p.addLine(to: CGPoint(x: x + len, y: y))

                p.move(to: CGPoint(x: x + w - len, y: y))
                p.addLine(to: CGPoint(x: x + w - r, y: y))
                p.addQuadCurve(to: CGPoint(x: x + w, y: y + r), control: CGPoint(x: x + w, y: y))
                p.addLine(to: CGPoint(x: x + w, y: y + len))

                p.move(to: CGPoint(x: x, y: y + h - len))
                p.addLine(to: CGPoint(x: x, y: y + h - r))
                p.addQuadCurve(to: CGPoint(x: x + r, y: y + h), control: CGPoint(x: x, y: y + h))
                p.addLine(to: CGPoint(x: x + len, y: y + h))

                p.move(to: CGPoint(x: x + w - len, y: y + h))
                p.addLine(to: CGPoint(x: x + w - r, y: y + h))
                p.addQuadCurve(to: CGPoint(x: x + w, y: y + h - r), control: CGPoint(x: x + w, y: y + h))
                p.addLine(to: CGPoint(x: x + w, y: y + h - len))
            }
            .stroke(.white.opacity(0.5), lineWidth: 2.5)
        }
        .allowsHitTesting(false)
    }

    // MARK: - Bottom Bar

    private var bottomBar: some View {
        HStack {
            PhotosPicker(selection: $galleryItems, matching: .images) {
                Image(systemName: "photo.on.rectangle.angled")
                    .font(.system(size: 20))
                    .foregroundStyle(.white)
                    .frame(width: 52, height: 52)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
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

            if capturedPhotos.isEmpty {
                Color.clear.frame(width: 52, height: 52)
            } else {
                Button {
                    CameraManager.shared.setTorch(false)
                    onPhotosReady(capturedPhotos)
                } label: {
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.system(size: 52))
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.white, Color("PrimaryOrange"))
                }
            }
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

    func setTorch(_ on: Bool) {
        guard let device = AVCaptureDevice.default(for: .video),
              device.hasTorch else { return }
        try? device.lockForConfiguration()
        device.torchMode = on ? .on : .off
        device.unlockForConfiguration()
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
