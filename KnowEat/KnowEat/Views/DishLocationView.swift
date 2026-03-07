//
//  DishLocationView.swift
//  KnowEat
//

import SwiftUI

struct DishLocationView: View {
    let item: AnalyzedDish
    let allergens: [Allergen]
    let menu: ScannedMenu
    let strings: AppStrings

    @Environment(\.dismiss) private var dismiss
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0

    private var dish: Dish { item.dish }

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

    private var accentColor: Color {
        if item.isSafe { return .green }
        if item.isDanger { return .red }
        return .orange
    }

    private var hasExplicitIngredients: Bool {
        !dish.ingredients.isEmpty
    }

    private var isUnrecognizedDish: Bool {
        dish.inferredIngredients.contains { $0.lowercased().contains("unrecognized") }
    }

    private func nameFor(_ id: String) -> String {
        strings.localizedAllergenName(id)
    }

    var body: some View {
        GeometryReader { geo in
            let images = menuImages
            ZStack(alignment: .topTrailing) {
                ZStack(alignment: .bottom) {
                    Group {
                        if images.isEmpty {
                            noImagePlaceholder
                        } else if targetImageIndex < images.count {
                            imageWithHighlight(image: images[targetImageIndex], size: geo.size)
                        } else {
                            noImagePlaceholder
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black)
                    .ignoresSafeArea()

                    LinearGradient(
                        stops: [
                            .init(color: .clear, location: 0),
                            .init(color: .black.opacity(0.4), location: 0.4),
                            .init(color: .black.opacity(0.9), location: 1)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 260)
                    .allowsHitTesting(false)

                    dishInfoPanel
                }

                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .medium))
                        .frame(width: 36, height: 36)
                        .contentShape(Circle())
                }
                .buttonStyle(.glass)
                .buttonBorderShape(.circle)
                .padding(.top, 12)
                .padding(.trailing, 16)
                .accessibilityLabel(strings.close)
            }
        }
        .background(Color.black)
        .ignoresSafeArea()
    }

    // MARK: - Dish Info Panel

    private var dishInfoPanel: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(accentColor)
                    .frame(width: 4, height: 18)

                VStack(alignment: .leading, spacing: 2) {
                    Text(dish.name)
                        .font(.interSemiBold(size: 15))
                        .foregroundStyle(.white)
                        .lineLimit(1)

                    if let translated = dish.translatedName, !translated.isEmpty {
                        Text(translated)
                            .font(.interRegular(size: 12))
                            .foregroundStyle(Color("PrimaryOrange").opacity(0.8))
                            .lineLimit(1)
                    }
                }
            }

            if let description = dish.description, !description.isEmpty {
                Text(description)
                    .font(.interRegular(size: 12))
                    .foregroundStyle(.white.opacity(0.7))
                    .lineLimit(2)
            }

            if hasExplicitIngredients {
                HStack(alignment: .top, spacing: 4) {
                    Image(systemName: "list.bullet")
                        .font(.system(size: 9))
                        .foregroundStyle(.white.opacity(0.4))
                        .padding(.top, 2)
                    Text(dish.ingredients.joined(separator: ", "))
                        .font(.interRegular(size: 11))
                        .foregroundStyle(.white.opacity(0.6))
                        .lineLimit(2)
                }
            } else if isUnrecognizedDish {
                Label {
                    Text(strings.unknownDishWarning)
                        .font(.interRegular(size: 11))
                } icon: {
                    Image(systemName: "questionmark.circle")
                        .font(.system(size: 9))
                }
                .foregroundStyle(.orange.opacity(0.8))
            } else {
                Label {
                    Text(strings.noIngredientsDetected)
                        .font(.interRegular(size: 11))
                } icon: {
                    Image(systemName: "info.circle")
                        .font(.system(size: 9))
                }
                .foregroundStyle(.white.opacity(0.4))
            }

            if !item.isSafe {
                HStack(spacing: 8) {
                    if item.isDanger {
                        Label {
                            Text(item.matchedAllergenIds.map { nameFor($0) }.joined(separator: ", "))
                        } icon: {
                            Image(systemName: "exclamationmark.triangle.fill")
                        }
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.red)
                    }
                    if item.isAdvisory {
                        let ids = item.matchedIntoleranceIds + item.matchedDietIds + item.matchedSituationIds
                        Label {
                            Text(ids.map { nameFor($0) }.joined(separator: ", "))
                        } icon: {
                            Image(systemName: "info.circle.fill")
                        }
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.orange)
                    }
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 20)
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Image

    @ViewBuilder
    private func imageWithHighlight(image: UIImage, size: CGSize) -> some View {
        let imageSize = image.size
        let aspectRatio = imageSize.width / imageSize.height
        let fitWidth = size.width
        let fitHeight = fitWidth / aspectRatio

        let regionsForThisImage = matchedRegions.filter { $0.imageIndex == targetImageIndex }

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
        .contentShape(Rectangle())
        .simultaneousGesture(
            MagnificationGesture()
                .onChanged { value in
                    scale = min(4.0, max(1.0, lastScale * value))
                }
                .onEnded { _ in
                    lastScale = scale
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
