//
//  AllergenChipView.swift
//  KnowEat
//
//  Created by Lisette HG on 20/02/26.
//

import SwiftUI

struct AllergenChipView: View {
    let allergen: Allergen
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: allergen.icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(isSelected ? .white : Color("PrimaryOrange"))
                    .frame(width: 34, height: 34)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(isSelected ? Color.white.opacity(0.25) : Color("PrimaryOrange").opacity(0.12))
                    )

                Text(allergen.name)
                    .font(.interMedium(size: 13))
                    .foregroundStyle(isSelected ? .white : .primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                Spacer(minLength: 0)
            }
            .padding(8)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(isSelected ? Color("PrimaryOrange") : Color(.systemBackground))
                    .shadow(color: .black.opacity(isSelected ? 0.08 : 0.05), radius: isSelected ? 4 : 6, y: isSelected ? 1 : 2)
            )
        }
        .buttonStyle(.plain)
    }
}
