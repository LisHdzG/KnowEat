//
//  MenuCell.swift
//  KnowEat
//
//  Created by Lisette HG on 20/02/26.
//

import SwiftUI

struct MenuCell: View {
    let menu: ScannedMenu

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd MMM yyyy, hh:mm a"
        return formatter.string(from: menu.scannedAt)
    }

    var body: some View {
        HStack(spacing: 14) {
            RoundedRectangle(cornerRadius: 14)
                .fill(Color("PrimaryOrange").opacity(0.08))
                .frame(width: 64, height: 64)
                .overlay {
                    Image(systemName: "menucard.fill")
                        .font(.system(size: 26))
                        .foregroundStyle(Color("PrimaryOrange").opacity(0.5))
                }

            VStack(alignment: .leading, spacing: 4) {
                Text(menu.restaurant)
                    .font(.interSemiBold(size: 16))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Text(formattedDate)
                    .font(.interRegular(size: 12))
                    .foregroundStyle(.secondary)

                HStack(spacing: 4) {
                    Image(systemName: "fork.knife")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)

                    Text("\(menu.dishes.count) dishes")
                        .font(.interRegular(size: 12))
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color("PrimaryOrange"))
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.06), radius: 10, y: 3)
        )
    }
}
