//
//  CameraView.swift
//  KnowEat
//
//  Created by Lisette HG on 20/02/26.
//

import SwiftUI
import AVFoundation
import PhotosUI
import Photos

private struct GalleryThumbnail: Identifiable {
    let id: String
    let thumbnail: UIImage
}

struct CameraView: View {
    let onPhotosReady: ([UIImage]) -> Void
    let onCancelled: () -> Void

    @State private var capturedPhotos: [UIImage] = []
    @State private var showFlash = false
    @State private var isTorchOn = false
    @State private var showPreview = false
    @State private var previewIndex = 0
    @State private var recentThumbnails: [GalleryThumbnail] = []
    @State private var galleryItems: [PhotosPickerItem] = []

    var body: some View {
        ZStack {
            cameraMode

            if showPreview && !capturedPhotos.isEmpty {
                previewMode
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .statusBarHidden()
        .onAppear { loadRecentPhotos() }
        .onChange(of: galleryItems) { _, items in
            loadFromPicker(items)
        }
    }

    // MARK: - Camera Mode

    private var cameraMode: some View {
        ZStack {
            CameraPreviewLayer()
                .ignoresSafeArea()

            if showFlash {
                Color.white
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            }

            viewfinderFrame

            VStack(spacing: 0) {
                cameraTopBar
                Spacer()

                if !recentThumbnails.isEmpty {
                    galleryStrip
                }

                shutterBar
            }
        }
    }

    // MARK: - Camera Top Bar

    private var cameraTopBar: some View {
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
            .accessibilityLabel("Close camera")
            .accessibilityHint("Dismisses the camera and returns without analyzing")

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
            .accessibilityLabel(isTorchOn ? "Flash on" : "Flash off")
            .accessibilityHint("Toggles the camera flash or torch")
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }

    // MARK: - Gallery Strip

    private var galleryStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 3) {
                ForEach(Array(recentThumbnails.enumerated()), id: \.element.id) { index, item in
                    Button {
                        loadFullImage(identifier: item.id)
                    } label: {
                        Image(uiImage: item.thumbnail)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 64, height: 64)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .accessibilityLabel("Recent photo \(index + 1) of \(recentThumbnails.count)")
                    .accessibilityHint("Adds this photo from your gallery to the selection")
                }
            }
            .padding(.horizontal, 16)
        }
        .frame(height: 68)
        .padding(.bottom, 12)
    }

    // MARK: - Shutter Bar

    private var shutterBar: some View {
        HStack {
            PhotosPicker(selection: $galleryItems, matching: .images) {
                Image(systemName: "photo.on.rectangle")
                    .font(.system(size: 22))
                    .foregroundStyle(.white)
                    .frame(width: 48, height: 48)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
            }
            .accessibilityLabel("Photo library")
            .accessibilityHint("Opens your photo library to select menu images")

            Spacer()

            Button { takePhoto() } label: {
                ZStack {
                    Circle()
                        .strokeBorder(.white, lineWidth: 4)
                        .frame(width: 72, height: 72)

                    Circle()
                        .fill(.white)
                        .frame(width: 60, height: 60)
                }
            }
            .accessibilityLabel("Take photo")
            .accessibilityHint("Captures a photo of the menu")

            Spacer()

            if capturedPhotos.isEmpty {
                Color.clear.frame(width: 48, height: 48)
            } else {
                Button {
                    previewIndex = capturedPhotos.count - 1
                    withAnimation(.easeInOut(duration: 0.25)) { showPreview = true }
                } label: {
                    ZStack(alignment: .topTrailing) {
                        Image(uiImage: capturedPhotos[capturedPhotos.count - 1])
                            .resizable()
                            .scaledToFill()
                            .frame(width: 48, height: 48)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(.white, lineWidth: 2)
                            )

                        Text("\(capturedPhotos.count)")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Color("PrimaryOrange"), in: Capsule())
                            .offset(x: 6, y: -6)
                    }
                }
                .accessibilityLabel("\(capturedPhotos.count) photo\(capturedPhotos.count == 1 ? "" : "s") selected")
                .accessibilityHint("Opens preview to review photos or send for analysis")
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 28)
    }

    // MARK: - Viewfinder Frame

    private var viewfinderFrame: some View {
        GeometryReader { geo in
            let w = geo.size.width * 0.78
            let h = w * 1.25
            let x = (geo.size.width - w) / 2
            let y = (geo.size.height - h) / 2 - 60
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

    // MARK: - Preview Mode

    private var previewMode: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                previewTopBar

                TabView(selection: $previewIndex) {
                    ForEach(capturedPhotos.indices, id: \.self) { index in
                        Image(uiImage: capturedPhotos[index])
                            .resizable()
                            .scaledToFit()
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .padding(.horizontal, 8)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: capturedPhotos.count > 1 ? .automatic : .never))

                if capturedPhotos.count > 1 {
                    previewThumbnailStrip
                }

                previewActionBar
            }
        }
    }

    // MARK: - Preview Top Bar

    private var previewTopBar: some View {
        HStack {
            Button {
                withAnimation(.easeInOut(duration: 0.25)) { showPreview = false }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(12)
                    .background(.ultraThinMaterial, in: Circle())
            }
            .accessibilityLabel("Back to camera")
            .accessibilityHint("Returns to camera to add more photos")

            Spacer()

            Text("\(capturedPhotos.count) photo\(capturedPhotos.count == 1 ? "" : "s")")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.white.opacity(0.8))

            Spacer()

            Button {
                withAnimation {
                    capturedPhotos.remove(at: previewIndex)
                    if capturedPhotos.isEmpty {
                        showPreview = false
                    } else if previewIndex >= capturedPhotos.count {
                        previewIndex = capturedPhotos.count - 1
                    }
                }
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.white)
                    .padding(12)
                    .background(.ultraThinMaterial, in: Circle())
            }
            .accessibilityLabel("Delete photo")
            .accessibilityHint("Removes the current photo from the selection")
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }

    // MARK: - Preview Thumbnails

    private var previewThumbnailStrip: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(capturedPhotos.indices, id: \.self) { index in
                        Image(uiImage: capturedPhotos[index])
                            .resizable()
                            .scaledToFill()
                            .frame(width: 52, height: 52)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(previewIndex == index ? .white : .clear, lineWidth: 2)
                            )
                            .scaleEffect(previewIndex == index ? 1.08 : 1.0)
                            .animation(.easeOut(duration: 0.2), value: previewIndex)
                            .onTapGesture {
                                withAnimation { previewIndex = index }
                            }
                            .id(index)
                            .accessibilityLabel("Photo \(index + 1) of \(capturedPhotos.count)")
                            .accessibilityHint(previewIndex == index ? "Currently selected" : "Selects this photo")
                            .accessibilityAddTraits(previewIndex == index ? [.isButton, .isSelected] : .isButton)
                    }
                }
                .padding(.horizontal, 24)
            }
            .onChange(of: previewIndex) { _, newIndex in
                withAnimation { proxy.scrollTo(newIndex, anchor: .center) }
            }
        }
        .padding(.vertical, 12)
    }

    // MARK: - Preview Actions

    private var previewActionBar: some View {
        HStack(spacing: 16) {
            Button {
                withAnimation(.easeInOut(duration: 0.25)) { showPreview = false }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .bold))
                    Text("Add more")
                        .font(.system(size: 15, weight: .semibold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
                .background(.ultraThinMaterial, in: Capsule())
            }
            .accessibilityLabel("Add more photos")
            .accessibilityHint("Returns to camera to capture or select more menu photos")

            Spacer()

            Button {
                CameraManager.shared.setTorch(false)
                onPhotosReady(capturedPhotos)
            } label: {
                HStack(spacing: 6) {
                    Text("Analyze")
                        .font(.system(size: 15, weight: .semibold))
                    Image(systemName: "arrow.right")
                        .font(.system(size: 14, weight: .bold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 14)
                .background(Color("PrimaryOrange"), in: Capsule())
            }
            .accessibilityLabel("Analyze menu")
            .accessibilityHint("Sends the selected photos for allergen and menu analysis")
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 28)
    }

    // MARK: - Actions

    private func takePhoto() {
        CameraManager.shared.capturePhoto { image in
            if let image {
                withAnimation {
                    showFlash = true
                    capturedPhotos.append(image)
                    previewIndex = capturedPhotos.count - 1
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                    withAnimation { showFlash = false }
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    withAnimation(.easeInOut(duration: 0.25)) { showPreview = true }
                }
            }
        }
    }

    private func loadFromPicker(_ items: [PhotosPickerItem]) {
        Task {
            for item in items {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    capturedPhotos.append(image)
                }
            }
            galleryItems = []
            if !capturedPhotos.isEmpty {
                previewIndex = capturedPhotos.count - 1
                withAnimation(.easeInOut(duration: 0.25)) { showPreview = true }
            }
        }
    }

    private func loadRecentPhotos() {
        let currentStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)

        switch currentStatus {
        case .authorized, .limited:
            fetchThumbnails()
        case .notDetermined:
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
                if status == .authorized || status == .limited {
                    DispatchQueue.main.async { fetchThumbnails() }
                }
            }
        default:
            break
        }
    }

    private func fetchThumbnails() {
        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        fetchOptions.fetchLimit = 30

        let results = PHAsset.fetchAssets(with: .image, options: fetchOptions)
        let manager = PHImageManager.default()
        let targetSize = CGSize(width: 200, height: 200)
        let imageOptions = PHImageRequestOptions()
        imageOptions.deliveryMode = .fastFormat
        imageOptions.resizeMode = .fast
        imageOptions.isNetworkAccessAllowed = false

        results.enumerateObjects { asset, _, _ in
            let identifier = asset.localIdentifier
            manager.requestImage(for: asset, targetSize: targetSize, contentMode: .aspectFill, options: imageOptions) { image, _ in
                guard let image else { return }
                DispatchQueue.main.async {
                    if !recentThumbnails.contains(where: { $0.id == identifier }) {
                        recentThumbnails.append(GalleryThumbnail(id: identifier, thumbnail: image))
                    }
                }
            }
        }
    }

    private func loadFullImage(identifier: String) {
        let results = PHAsset.fetchAssets(withLocalIdentifiers: [identifier], options: nil)
        guard let asset = results.firstObject else { return }

        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.isNetworkAccessAllowed = true

        PHImageManager.default().requestImage(
            for: asset,
            targetSize: CGSize(width: 2048, height: 2048),
            contentMode: .aspectFit,
            options: options
        ) { image, info in
            guard let image else { return }
            let isDegraded = (info?[PHImageResultIsDegradedKey] as? Bool) ?? false
            if isDegraded { return }

            DispatchQueue.main.async {
                capturedPhotos.append(image)
                previewIndex = capturedPhotos.count - 1
                withAnimation(.easeInOut(duration: 0.25)) { showPreview = true }
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
