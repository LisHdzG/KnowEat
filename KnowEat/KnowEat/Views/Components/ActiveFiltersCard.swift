//
//  ActiveFiltersCard.swift
//  KnowEat
//
//  Created by Lisette HG on 20/02/26.
//

import SwiftUI

struct ActiveFiltersCard: View {
    let groups: [DietaryFilterGroup]
    var showChevron: Bool = false
    var onTap: (() -> Void)? = nil

    private var allChips: [(item: Allergen, color: Color)] {
        groups.flatMap { group in
            group.items.map { (item: $0, color: chipColor(for: group.id)) }
        }
    }

    var body: some View {
        Button {
            onTap?()
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "heart.text.clipboard.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(allChips.isEmpty ? Color("SecondaryGray").opacity(0.4) : Color("PrimaryOrange"))

                    Text("Dietary Profile")
                        .font(.interMedium(size: 14))
                        .foregroundStyle(.primary)

                    Spacer()

                    if showChevron {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Color(.tertiaryLabel))
                    }
                }

                if allChips.isEmpty {
                    Text("No dietary restrictions configured")
                        .font(.interRegular(size: 13))
                        .foregroundStyle(.secondary)
                } else {
                    FlowLayout(spacing: 6) {
                        ForEach(allChips, id: \.item.id) { chip in
                            Text(chip.item.name)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(chip.color)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(
                                    Capsule()
                                        .fill(chip.color.opacity(0.12))
                                )
                        }
                    }
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.06), radius: 10, y: 3)
            )
        }
        .buttonStyle(.plain)
        .disabled(onTap == nil)
    }

    private func chipColor(for groupId: String) -> Color {
        switch groupId {
        case "allergens": Color("PrimaryOrange")
        case "intolerances": .purple
        case "conditions": .red
        case "diets": .green
        case "situations": .blue
        default: Color("PrimaryOrange")
        }
    }
}

// MARK: - Flow Layout

struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        arrange(proposal: proposal, subviews: subviews).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: proposal, subviews: subviews)
        for (index, subview) in subviews.enumerated() {
            subview.place(
                at: CGPoint(x: bounds.minX + result.positions[index].x,
                             y: bounds.minY + result.positions[index].y),
                anchor: .topLeading,
                proposal: .unspecified
            )
        }
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (positions: [CGPoint], size: CGSize) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var maxX: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
            maxX = max(maxX, x - spacing)
        }

        return (positions, CGSize(width: maxX, height: y + rowHeight))
    }
}
