//
//  ActiveFiltersCard.swift
//  KnowEat
//
//  Created by Lisette HG on 20/02/26.
//

import SwiftUI

struct ActiveFiltersCard: View {
    let filters: [Allergen]
    var showChevron: Bool = true
    var onTap: (() -> Void)? = nil

    var body: some View {
        Button {
            onTap?()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "exclamationmark.shield.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(filters.isEmpty ? Color("SecondaryGray").opacity(0.4) : Color("PrimaryOrange"))

                VStack(alignment: .leading, spacing: 5) {
                    Text("My Allergens")
                        .font(.interMedium(size: 14))
                        .foregroundStyle(.primary)

                    if filters.isEmpty {
                        Text("None selected")
                            .font(.interRegular(size: 12))
                            .foregroundStyle(.secondary)
                    } else {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 6) {
                                ForEach(filters) { allergen in
                                    Text(allergen.name)
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundStyle(Color("PrimaryOrange"))
                                        .fixedSize()
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 5)
                                        .background(
                                            Capsule()
                                                .fill(Color("PrimaryOrange").opacity(0.12))
                                        )
                                }
                            }
                        }
                    }
                }

                Spacer()

                if showChevron {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }
}
