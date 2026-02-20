//
//  GIFImageView.swift
//  KnowEat
//

import SwiftUI
import UIKit

struct GIFImageView: UIViewRepresentable {
    let name: String

    func makeUIView(context: Context) -> UIImageView {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.clipsToBounds = true
        imageView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        imageView.setContentCompressionResistancePriority(.defaultLow, for: .vertical)

        if let path = Bundle.main.path(forResource: name, ofType: "gif"),
           let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
           let source = CGImageSourceCreateWithData(data as CFData, nil) {
            var images: [UIImage] = []
            var duration: Double = 0

            let count = CGImageSourceGetCount(source)
            for i in 0..<count {
                if let cgImage = CGImageSourceCreateImageAtIndex(source, i, nil) {
                    images.append(UIImage(cgImage: cgImage))

                    if let properties = CGImageSourceCopyPropertiesAtIndex(source, i, nil) as? [String: Any],
                       let gifDict = properties[kCGImagePropertyGIFDictionary as String] as? [String: Any] {
                        let frameDuration = gifDict[kCGImagePropertyGIFUnclampedDelayTime as String] as? Double
                            ?? gifDict[kCGImagePropertyGIFDelayTime as String] as? Double
                            ?? 0.1
                        duration += frameDuration
                    }
                }
            }

            imageView.animationImages = images
            imageView.animationDuration = duration
            imageView.startAnimating()
        }

        return imageView
    }

    func updateUIView(_ uiView: UIImageView, context: Context) {}
}
