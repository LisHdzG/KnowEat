//
//  Font+App.swift
//  KnowEat
//
//  Created by Lisette HG on 20/02/26.
//

import SwiftUI
import UIKit

extension Font {
    // MARK: - Fixed size (legacy)

    static func italianno(size: CGFloat) -> Font {
        .custom("Italianno-Regular", size: size)
    }

    static func interRegular(size: CGFloat) -> Font {
        .custom("Inter-Regular", size: size)
    }

    static func interMedium(size: CGFloat) -> Font {
        .custom("Inter-Medium", size: size)
    }

    static func interSemiBold(size: CGFloat) -> Font {
        .custom("Inter-SemiBold", size: size)
    }

    // MARK: - Dynamic Type (scales with user's text size preference)

    static func italianno(_ textStyle: UIFont.TextStyle = .body) -> Font {
        let size = UIFont.preferredFont(forTextStyle: textStyle).pointSize
        return .custom("Italianno-Regular", size: size)
    }

    static func interRegular(_ textStyle: UIFont.TextStyle = .body) -> Font {
        let size = UIFont.preferredFont(forTextStyle: textStyle).pointSize
        return .custom("Inter-Regular", size: size)
    }

    static func interMedium(_ textStyle: UIFont.TextStyle = .body) -> Font {
        let size = UIFont.preferredFont(forTextStyle: textStyle).pointSize
        return .custom("Inter-Medium", size: size)
    }

    static func interSemiBold(_ textStyle: UIFont.TextStyle = .body) -> Font {
        let size = UIFont.preferredFont(forTextStyle: textStyle).pointSize
        return .custom("Inter-SemiBold", size: size)
    }
}
