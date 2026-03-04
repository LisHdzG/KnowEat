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

    @State private var currentZoom: CGFloat = 1.0
    @State private var lastZoomValue: CGFloat = 1.0
    @State private var showZoomLabel = false

    @State private var showCrop = false
    @State private var isCapturing = false

    var body: some View {
        ZStack {
            cameraMode

            if showPreview && !capturedPhotos.isEmpty {
                previewMode
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .statusBarHidden()
        .onAppear {
            loadRecentPhotos()
            currentZoom = 1.0
            lastZoomValue = 1.0
            CameraManager.shared.setZoom(1.0)
        }
        .onChange(of: galleryItems) { _, items in
            loadFromPicker(items)
        }
    }

    // MARK: - Camera Mode

    private var cameraMode: some View {
        ZStack {
            CameraPreviewLayer()
                .ignoresSafeArea()
                .gesture(
                    MagnificationGesture()
                        .onChanged { value in
                            let newZoom = lastZoomValue * value
                            currentZoom = max(1.0, min(newZoom, CameraManager.shared.maxZoomFactor))
                            CameraManager.shared.setZoom(currentZoom)
                            withAnimation { showZoomLabel = true }
                        }
                        .onEnded { _ in
                            lastZoomValue = currentZoom
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                                withAnimation { showZoomLabel = false }
                            }
                        }
                )

            if showFlash {
                Color.white
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            }

            viewfinderFrame

            if showZoomLabel {
                zoomIndicator
            }

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

    private var zoomIndicator: some View {
        Text(String(format: "%.1fx", currentZoom))
            .font(.system(size: 14, weight: .semibold, design: .rounded))
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(.ultraThinMaterial, in: Capsule())
            .transition(.opacity)
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
            .disabled(isCapturing)
            .opacity(isCapturing ? 0.6 : 1)
            .animation(.easeInOut(duration: 0.2), value: isCapturing)
            .accessibilityLabel("Take photo")
            .accessibilityHint(isCapturing ? "Capturing…" : "Captures a photo of the menu")

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
        .fullScreenCover(isPresented: $showCrop) {
            if previewIndex < capturedPhotos.count {
                PhotoCropView(image: capturedPhotos[previewIndex]) { cropped in
                    capturedPhotos[previewIndex] = cropped
                    showCrop = false
                } onCancel: {
                    showCrop = false
                }
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

            HStack(spacing: 12) {
                Button {
                    showCrop = true
                } label: {
                    Image(systemName: "crop")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.white)
                        .padding(12)
                        .background(.ultraThinMaterial, in: Circle())
                }
                .accessibilityLabel("Crop photo")
                .accessibilityHint("Opens the crop editor for the current photo")

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
        guard !isCapturing else { return }
        isCapturing = true

        CameraManager.shared.capturePhoto { image in
            DispatchQueue.main.async {
                isCapturing = false
            }
            guard let image else { return }
            DispatchQueue.main.async {
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
    private(set) var captureDevice: AVCaptureDevice?

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

        captureDevice = device

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
        guard let device = captureDevice, device.hasTorch else { return }
        try? device.lockForConfiguration()
        device.torchMode = on ? .on : .off
        device.unlockForConfiguration()
    }

    func setZoom(_ factor: CGFloat) {
        guard let device = captureDevice else { return }
        let maxZoom = min(device.activeFormat.videoMaxZoomFactor, 10.0)
        let clamped = max(1.0, min(factor, maxZoom))
        try? device.lockForConfiguration()
        device.videoZoomFactor = clamped
        device.unlockForConfiguration()
    }

    var maxZoomFactor: CGFloat {
        guard let device = captureDevice else { return 5.0 }
        return min(device.activeFormat.videoMaxZoomFactor, 10.0)
    }

    static func cropToPreviewAspect(_ image: UIImage) -> UIImage {
        let screenSize = UIScreen.main.bounds.size
        let targetRatio = screenSize.height / screenSize.width
        let imageRatio = image.size.height / image.size.width

        guard abs(imageRatio - targetRatio) > 0.01 else { return image }

        var cropSize: CGSize
        if imageRatio > targetRatio {
            cropSize = CGSize(width: image.size.width, height: image.size.width * targetRatio)
        } else {
            cropSize = CGSize(width: image.size.height / targetRatio, height: image.size.height)
        }

        let origin = CGPoint(
            x: (image.size.width - cropSize.width) / 2,
            y: (image.size.height - cropSize.height) / 2
        )

        let format = UIGraphicsImageRendererFormat()
        format.scale = image.scale
        let renderer = UIGraphicsImageRenderer(size: cropSize, format: format)
        return renderer.image { _ in
            image.draw(at: CGPoint(x: -origin.x, y: -origin.y))
        }
    }
}

extension CameraManager: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard let data = photo.fileDataRepresentation(),
              let image = UIImage(data: data) else {
            completion?(nil)
            return
        }
        let cropped = Self.cropToPreviewAspect(image)
        DispatchQueue.main.async { [weak self] in
            self?.completion?(cropped)
        }
    }
}

// MARK: - Photo Crop View

struct PhotoCropView: View {
    let image: UIImage
    let onCropped: (UIImage) -> Void
    let onCancel: () -> Void

    @State private var cropRect: CGRect = .zero
    @State private var imageRect: CGRect = .zero
    @State private var activeDrag: DragType? = nil
    @State private var dragStartRect: CGRect = .zero
    @State private var viewSize: CGSize = .zero

    private let minCrop: CGFloat = 60
    private let hitRadius: CGFloat = 32

    enum DragType {
        case topLeft, topRight, bottomLeft, bottomRight
        case top, bottom, left, right
        case move
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            GeometryReader { geo in
                let size = geo.size

                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: size.width, height: size.height)

                dimOverlay(size: size)
                cropBorder
                if activeDrag != nil { gridOverlay }
                cropDecorations

                Color.clear
                    .contentShape(Rectangle())
                    .gesture(cropDragGesture)
                    .onAppear {
                        viewSize = size
                        let r = imageFitRect(in: size)
                        imageRect = r
                        cropRect = r
                    }
            }

            VStack {
                cropTopBar
                Spacer()
                cropBottomBar
            }
        }
        .statusBarHidden()
    }

    // MARK: - Image Geometry

    private func imageFitRect(in size: CGSize) -> CGRect {
        let imgAspect = image.size.width / image.size.height
        let viewAspect = size.width / size.height
        var fitSize: CGSize
        if imgAspect > viewAspect {
            fitSize = CGSize(width: size.width, height: size.width / imgAspect)
        } else {
            fitSize = CGSize(width: size.height * imgAspect, height: size.height)
        }
        return CGRect(
            x: (size.width - fitSize.width) / 2,
            y: (size.height - fitSize.height) / 2,
            width: fitSize.width,
            height: fitSize.height
        )
    }

    // MARK: - Dim Overlay

    private func dimOverlay(size: CGSize) -> some View {
        Path { path in
            path.addRect(CGRect(origin: .zero, size: size))
            path.addRect(cropRect)
        }
        .fill(style: FillStyle(eoFill: true))
        .foregroundStyle(.black.opacity(0.55))
        .allowsHitTesting(false)
    }

    // MARK: - Crop Border

    private var cropBorder: some View {
        Rectangle()
            .strokeBorder(.white.opacity(0.8), lineWidth: 1)
            .frame(width: max(0, cropRect.width), height: max(0, cropRect.height))
            .position(x: cropRect.midX, y: cropRect.midY)
            .allowsHitTesting(false)
    }

    // MARK: - Grid (Rule of Thirds)

    private var gridOverlay: some View {
        let r = cropRect
        return Path { p in
            let thirdW = r.width / 3
            let thirdH = r.height / 3
            for i in 1...2 {
                let x = r.minX + thirdW * CGFloat(i)
                p.move(to: CGPoint(x: x, y: r.minY))
                p.addLine(to: CGPoint(x: x, y: r.maxY))
                let y = r.minY + thirdH * CGFloat(i)
                p.move(to: CGPoint(x: r.minX, y: y))
                p.addLine(to: CGPoint(x: r.maxX, y: y))
            }
        }
        .stroke(.white.opacity(0.35), lineWidth: 0.5)
        .allowsHitTesting(false)
    }

    // MARK: - Corner & Edge Decorations

    private var cropDecorations: some View {
        let r = cropRect
        let cLen: CGFloat = 20
        let eLen: CGFloat = 16
        let w: CGFloat = 3.0

        return Path { p in
            // Top-left
            p.move(to: CGPoint(x: r.minX - 1, y: r.minY + cLen))
            p.addLine(to: CGPoint(x: r.minX - 1, y: r.minY - 1))
            p.addLine(to: CGPoint(x: r.minX + cLen, y: r.minY - 1))
            // Top-right
            p.move(to: CGPoint(x: r.maxX - cLen, y: r.minY - 1))
            p.addLine(to: CGPoint(x: r.maxX + 1, y: r.minY - 1))
            p.addLine(to: CGPoint(x: r.maxX + 1, y: r.minY + cLen))
            // Bottom-left
            p.move(to: CGPoint(x: r.minX - 1, y: r.maxY - cLen))
            p.addLine(to: CGPoint(x: r.minX - 1, y: r.maxY + 1))
            p.addLine(to: CGPoint(x: r.minX + cLen, y: r.maxY + 1))
            // Bottom-right
            p.move(to: CGPoint(x: r.maxX - cLen, y: r.maxY + 1))
            p.addLine(to: CGPoint(x: r.maxX + 1, y: r.maxY + 1))
            p.addLine(to: CGPoint(x: r.maxX + 1, y: r.maxY - cLen))

            // Edge midpoints
            let midX = r.midX, midY = r.midY
            p.move(to: CGPoint(x: midX - eLen, y: r.minY - 1))
            p.addLine(to: CGPoint(x: midX + eLen, y: r.minY - 1))
            p.move(to: CGPoint(x: midX - eLen, y: r.maxY + 1))
            p.addLine(to: CGPoint(x: midX + eLen, y: r.maxY + 1))
            p.move(to: CGPoint(x: r.minX - 1, y: midY - eLen))
            p.addLine(to: CGPoint(x: r.minX - 1, y: midY + eLen))
            p.move(to: CGPoint(x: r.maxX + 1, y: midY - eLen))
            p.addLine(to: CGPoint(x: r.maxX + 1, y: midY + eLen))
        }
        .stroke(.white, lineWidth: w)
        .allowsHitTesting(false)
    }

    // MARK: - Gesture

    private var cropDragGesture: some Gesture {
        DragGesture(minimumDistance: 1)
            .onChanged { value in
                if activeDrag == nil {
                    activeDrag = determineDragType(at: value.startLocation)
                    dragStartRect = cropRect
                }
                guard let drag = activeDrag else { return }
                applyDrag(drag, translation: value.translation)
            }
            .onEnded { _ in
                withAnimation(.easeOut(duration: 0.15)) { activeDrag = nil }
            }
    }

    private func determineDragType(at point: CGPoint) -> DragType? {
        let r = cropRect
        func dist(_ a: CGPoint, _ b: CGPoint) -> CGFloat { hypot(a.x - b.x, a.y - b.y) }

        if dist(point, CGPoint(x: r.minX, y: r.minY)) < hitRadius { return .topLeft }
        if dist(point, CGPoint(x: r.maxX, y: r.minY)) < hitRadius { return .topRight }
        if dist(point, CGPoint(x: r.minX, y: r.maxY)) < hitRadius { return .bottomLeft }
        if dist(point, CGPoint(x: r.maxX, y: r.maxY)) < hitRadius { return .bottomRight }

        if abs(point.y - r.minY) < hitRadius && point.x > r.minX && point.x < r.maxX { return .top }
        if abs(point.y - r.maxY) < hitRadius && point.x > r.minX && point.x < r.maxX { return .bottom }
        if abs(point.x - r.minX) < hitRadius && point.y > r.minY && point.y < r.maxY { return .left }
        if abs(point.x - r.maxX) < hitRadius && point.y > r.minY && point.y < r.maxY { return .right }

        if r.contains(point) { return .move }
        return nil
    }

    private func applyDrag(_ drag: DragType, translation: CGSize) {
        let dx = translation.width, dy = translation.height
        let s = dragStartRect, img = imageRect

        switch drag {
        case .topLeft:
            let x = clamp(s.minX + dx, lo: img.minX, hi: s.maxX - minCrop)
            let y = clamp(s.minY + dy, lo: img.minY, hi: s.maxY - minCrop)
            cropRect = CGRect(x: x, y: y, width: s.maxX - x, height: s.maxY - y)
        case .topRight:
            let mx = clamp(s.maxX + dx, lo: s.minX + minCrop, hi: img.maxX)
            let y = clamp(s.minY + dy, lo: img.minY, hi: s.maxY - minCrop)
            cropRect = CGRect(x: s.minX, y: y, width: mx - s.minX, height: s.maxY - y)
        case .bottomLeft:
            let x = clamp(s.minX + dx, lo: img.minX, hi: s.maxX - minCrop)
            let my = clamp(s.maxY + dy, lo: s.minY + minCrop, hi: img.maxY)
            cropRect = CGRect(x: x, y: s.minY, width: s.maxX - x, height: my - s.minY)
        case .bottomRight:
            let mx = clamp(s.maxX + dx, lo: s.minX + minCrop, hi: img.maxX)
            let my = clamp(s.maxY + dy, lo: s.minY + minCrop, hi: img.maxY)
            cropRect = CGRect(x: s.minX, y: s.minY, width: mx - s.minX, height: my - s.minY)
        case .top:
            let y = clamp(s.minY + dy, lo: img.minY, hi: s.maxY - minCrop)
            cropRect = CGRect(x: s.minX, y: y, width: s.width, height: s.maxY - y)
        case .bottom:
            let my = clamp(s.maxY + dy, lo: s.minY + minCrop, hi: img.maxY)
            cropRect = CGRect(x: s.minX, y: s.minY, width: s.width, height: my - s.minY)
        case .left:
            let x = clamp(s.minX + dx, lo: img.minX, hi: s.maxX - minCrop)
            cropRect = CGRect(x: x, y: s.minY, width: s.maxX - x, height: s.height)
        case .right:
            let mx = clamp(s.maxX + dx, lo: s.minX + minCrop, hi: img.maxX)
            cropRect = CGRect(x: s.minX, y: s.minY, width: mx - s.minX, height: s.height)
        case .move:
            let cdx = clamp(dx, lo: img.minX - s.minX, hi: img.maxX - s.maxX)
            let cdy = clamp(dy, lo: img.minY - s.minY, hi: img.maxY - s.maxY)
            cropRect = s.offsetBy(dx: cdx, dy: cdy)
        }
    }

    private func clamp(_ v: CGFloat, lo: CGFloat, hi: CGFloat) -> CGFloat {
        Swift.max(lo, Swift.min(hi, v))
    }

    // MARK: - Perform Crop

    private func performCrop() -> UIImage {
        guard imageRect.width > 0, imageRect.height > 0 else { return image }

        let nX = (cropRect.minX - imageRect.minX) / imageRect.width
        let nY = (cropRect.minY - imageRect.minY) / imageRect.height
        let nW = cropRect.width / imageRect.width
        let nH = cropRect.height / imageRect.height

        let pixRect = CGRect(
            x: nX * image.size.width,
            y: nY * image.size.height,
            width: nW * image.size.width,
            height: nH * image.size.height
        )

        guard pixRect.width > 0, pixRect.height > 0 else { return image }

        let format = UIGraphicsImageRendererFormat()
        format.scale = image.scale
        let renderer = UIGraphicsImageRenderer(size: pixRect.size, format: format)
        return renderer.image { _ in
            image.draw(at: CGPoint(x: -pixRect.origin.x, y: -pixRect.origin.y))
        }
    }

    // MARK: - Bars

    private var cropTopBar: some View {
        HStack {
            Button { onCancel() } label: {
                Text("Cancel")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(.ultraThinMaterial, in: Capsule())
            }

            Spacer()

            Button {
                withAnimation(.easeOut(duration: 0.25)) {
                    cropRect = imageRect
                }
            } label: {
                Image(systemName: "arrow.counterclockwise")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(12)
                    .background(.ultraThinMaterial, in: Circle())
            }
            .accessibilityLabel("Reset crop")
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
    }

    private var cropBottomBar: some View {
        Button {
            let cropped = performCrop()
            onCropped(cropped)
        } label: {
            Text("Done")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(Color("PrimaryOrange"), in: RoundedRectangle(cornerRadius: 14))
        }
        .padding(.horizontal, 28)
        .padding(.bottom, 32)
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
