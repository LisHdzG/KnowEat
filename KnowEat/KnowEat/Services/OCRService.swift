//
//  OCRService.swift
//  KnowEat
//
//  Created by Lisette HG on 20/02/26.
//

import Foundation
import UIKit
import Vision

enum OCRError: LocalizedError {
    case noTextFound
    case recognitionFailed(String)

    var errorDescription: String? {
        switch self {
        case .noTextFound:
            return "No text could be detected in the images. Please try with a clearer photo."
        case .recognitionFailed(let message):
            return "Text recognition failed: \(message)"
        }
    }
}

final class OCRService {
    static let shared = OCRService()

    struct OCRResult {
        let text: String
        let regions: [TextRegion]
    }

    func extractText(from images: [UIImage]) async throws -> String {
        let result = try await extractTextWithRegions(from: images)
        return result.text
    }

    func extractTextWithRegions(from images: [UIImage]) async throws -> OCRResult {
        var allText: [String] = []
        var allRegions: [TextRegion] = []

        for (index, image) in images.enumerated() {
            let result = try await recognizeTextWithRegions(in: image, imageIndex: index)
            if !result.text.isEmpty {
                allText.append(result.text)
            }
            allRegions.append(contentsOf: result.regions)
        }

        let combined = allText.joined(separator: "\n\n")
        guard !combined.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw OCRError.noTextFound
        }
        return OCRResult(text: combined, regions: allRegions)
    }

    private func recognizeTextWithRegions(in image: UIImage, imageIndex: Int) async throws -> OCRResult {
        guard let cgImage = image.cgImage else {
            throw OCRError.recognitionFailed("Could not process image.")
        }

        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error {
                    continuation.resume(throwing: OCRError.recognitionFailed(error.localizedDescription))
                    return
                }

                let observations = request.results as? [VNRecognizedTextObservation] ?? []
                var lines: [String] = []
                var regions: [TextRegion] = []

                for observation in observations {
                    guard let candidate = observation.topCandidates(1).first,
                          candidate.confidence > 0.3 else { continue }

                    lines.append(candidate.string)

                    let box = observation.boundingBox
                    regions.append(TextRegion(
                        text: candidate.string,
                        x: box.origin.x,
                        y: box.origin.y,
                        width: box.size.width,
                        height: box.size.height,
                        confidence: candidate.confidence,
                        imageIndex: imageIndex
                    ))
                }

                let text = lines.joined(separator: "\n")
                continuation.resume(returning: OCRResult(text: text, regions: regions))
            }

            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            request.automaticallyDetectsLanguage = true
            request.revision = VNRecognizeTextRequest.currentRevision

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: OCRError.recognitionFailed(error.localizedDescription))
            }
        }
    }
}
