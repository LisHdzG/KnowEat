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
        NavigationStack {
            VStack(spacing: 0) {
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

                dishInfoPanel
            }
            .background(Color.black)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(dish.name)
                        .font(.interSemiBold(size: 14))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white.opacity(0.8))
                            .frame(width: 28, height: 28)
                            .background(.ultraThinMaterial, in: Circle())
                    }
                    .accessibilityLabel(strings.close)
                }
            }
            .toolbarBackground(.black, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }

    // MARK: - Dish Info Panel

    private var dishInfoPanel: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(accentColor)
                    .frame(width: 4, height: 18)

                Text(dish.name)
                    .font(.interSemiBold(size: 15))
                    .foregroundStyle(.white)
                    .lineLimit(1)
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
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemBackground).opacity(0.12))
    }

    // MARK: - Image

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
                .padding(.bottom, 12)
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
