//
//  DishLocationView.swift
//  KnowEat
//

import SwiftUI

struct DishLocationView: View {
    let dish: Dish
    let menu: ScannedMenu
    let strings: AppStrings

    @Environment(\.dismiss) private var dismiss
    @State private var scale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    private var menuImages: [UIImage] {
        ImageStorageService.shared.loadImages(forMenuId: menu.id)
    }

    private var matchedRegions: [TextRegion] {
        guard !dish.textRegionIndices.isEmpty else { return [] }
        return dish.textRegionIndices.compactMap { idx in
            idx < menu.textRegions.count ? menu.textRegions[idx] : nil
        }
    }

    private var targetImageIndex: Int {
        matchedRegions.first?.imageIndex ?? 0
    }

    var body: some View {
        NavigationStack {
            GeometryReader { geo in
                let images = menuImages
                if images.isEmpty {
                    noImagePlaceholder
                } else if targetImageIndex < images.count {
                    imageWithHighlight(image: images[targetImageIndex], size: geo.size)
                } else {
                    noImagePlaceholder
                }
            }
            .background(Color.black)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(dish.name)
                        .font(.interSemiBold(size: 14))
                        .foregroundStyle(.white)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 22))
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(.white.opacity(0.7))
                    }
                    .accessibilityLabel(strings.close)
                }
            }
            .toolbarBackground(.black, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }

    @ViewBuilder
    private func imageWithHighlight(image: UIImage, size: CGSize) -> some View {
        let imageSize = image.size
        let aspectRatio = imageSize.width / imageSize.height
        let fitWidth = size.width
        let fitHeight = fitWidth / aspectRatio

        let regionsForThisImage = matchedRegions.filter { $0.imageIndex == targetImageIndex }

        ZStack {
            ScrollView([.horizontal, .vertical], showsIndicators: false) {
                ZStack(alignment: .topLeading) {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: fitWidth * scale, height: fitHeight * scale)

                    ForEach(Array(regionsForThisImage.enumerated()), id: \.offset) { _, region in
                        let rect = convertBoundingBox(region, imageWidth: fitWidth * scale, imageHeight: fitHeight * scale)
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(Color.orange, lineWidth: 3)
                            .background(
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.orange.opacity(0.15))
                            )
                            .frame(width: rect.width + 8, height: rect.height + 6)
                            .offset(x: rect.minX - 4, y: rect.minY - 3)
                    }
                }
                .frame(width: fitWidth * scale, height: fitHeight * scale)
            }

            VStack {
                Spacer()
                HStack(spacing: 16) {
                    Button {
                        withAnimation { scale = max(1.0, scale - 0.5) }
                    } label: {
                        Image(systemName: "minus.magnifyingglass")
                            .font(.system(size: 20))
                            .foregroundStyle(.white)
                            .padding(10)
                            .background(.ultraThinMaterial, in: Circle())
                    }

                    Button {
                        withAnimation { scale = min(4.0, scale + 0.5) }
                    } label: {
                        Image(systemName: "plus.magnifyingglass")
                            .font(.system(size: 20))
                            .foregroundStyle(.white)
                            .padding(10)
                            .background(.ultraThinMaterial, in: Circle())
                    }

                    if scale != 1.0 {
                        Button {
                            withAnimation { scale = 1.0 }
                        } label: {
                            Image(systemName: "arrow.counterclockwise")
                                .font(.system(size: 20))
                                .foregroundStyle(.white)
                                .padding(10)
                                .background(.ultraThinMaterial, in: Circle())
                        }
                    }
                }
                .padding(.bottom, 24)
            }
        }
        .gesture(
            MagnificationGesture()
                .onChanged { value in
                    scale = min(4.0, max(1.0, value))
                }
        )
    }

    private func convertBoundingBox(_ region: TextRegion, imageWidth: CGFloat, imageHeight: CGFloat) -> CGRect {
        let x = region.x * imageWidth
        let y = (1.0 - region.y - region.height) * imageHeight
        let w = region.width * imageWidth
        let h = region.height * imageHeight
        return CGRect(x: x, y: y, width: w, height: h)
    }

    private var noImagePlaceholder: some View {
        VStack(spacing: 12) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text(strings.noPhotoAvailable)
                .font(.interRegular(size: 15))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
