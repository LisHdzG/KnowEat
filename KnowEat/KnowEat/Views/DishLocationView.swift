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
    @State private var scale: CGFloat = 1.35
    @State private var lastScale: CGFloat = 1.35
    @State private var didAppear = false

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
        VStack(spacing: 0) {
            // Card arriba con datos y botón cerrar dentro
            dishInfoPanel

            // Foto debajo (con zoom)
            GeometryReader { geo in
                let images = menuImages
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
                .background(Color(.systemBackground))
            }
        }
        .background(Color(.systemBackground))
        .onAppear {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.78)) {
                didAppear = true
            }
        }
    }

    // MARK: - Dish Info Card (arriba, sin X)

    private var dishInfoPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(accentColor)
                    .frame(width: 3, height: 20)

                VStack(alignment: .leading, spacing: 2) {
                    Text(dish.name)
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundStyle(.primary)

                    if let translated = dish.translatedName, !translated.isEmpty {
                        Text(translated)
                            .font(.system(size: 13, weight: .regular))
                            .foregroundStyle(Color("PrimaryOrange"))
                            .lineLimit(1)
                    }
                }
            }

                if let description = dish.description, !description.isEmpty {
                    Text(description)
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                if hasExplicitIngredients {
                    HStack(alignment: .top, spacing: 5) {
                        Image(systemName: "list.bullet")
                            .font(.system(size: 10))
                            .foregroundStyle(.tertiary)
                            .padding(.top, 2)
                        Text(dish.ingredients.joined(separator: ", "))
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                } else if isUnrecognizedDish {
                    Label {
                        Text(strings.unknownDishWarning)
                            .font(.system(size: 12))
                    } icon: {
                        Image(systemName: "questionmark.circle")
                            .font(.system(size: 11))
                    }
                    .foregroundStyle(.orange)
                } else {
                    Label {
                        Text(strings.noIngredientsDetected)
                            .font(.system(size: 12))
                    } icon: {
                        Image(systemName: "info.circle")
                            .font(.system(size: 11))
                    }
                    .foregroundStyle(.tertiary)
                }

                if !item.isSafe {
                    HStack(spacing: 10) {
                        if item.isDanger {
                            Label {
                                Text(item.matchedAllergenIds.map { nameFor($0) }.joined(separator: ", "))
                            } icon: {
                                Image(systemName: "exclamationmark.triangle.fill")
                            }
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.red)
                        }
                        if item.isAdvisory {
                            let ids = item.matchedIntoleranceIds + item.matchedDietIds + item.matchedSituationIds
                            Label {
                                Text(ids.map { nameFor($0) }.joined(separator: ", "))
                            } icon: {
                                Image(systemName: "info.circle.fill")
                            }
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.orange)
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color(.secondarySystemGroupedBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .strokeBorder(Color(.separator).opacity(0.5), lineWidth: 0.5)
                    )
                    .shadow(color: .black.opacity(0.08), radius: 12, y: 4)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 8)
        .scaleEffect(didAppear ? 1 : 0.98)
        .opacity(didAppear ? 1 : 0)
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
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .strokeBorder(Color("PrimaryOrange").opacity(0.9), lineWidth: 2)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(Color("PrimaryOrange").opacity(0.08))
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
                .font(.system(size: 44, weight: .light))
                .foregroundStyle(.tertiary)
            Text(strings.noPhotoAvailable)
                .font(.system(size: 15, weight: .regular))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
