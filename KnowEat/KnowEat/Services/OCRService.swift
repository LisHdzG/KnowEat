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

    func extractText(from images: [UIImage]) async throws -> String {
        var allText: [String] = []

        for image in images {
            let text = try await recognizeText(in: image)
            if !text.isEmpty {
                allText.append(text)
            }
        }

        let combined = allText.joined(separator: "\n\n")
        guard !combined.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw OCRError.noTextFound
        }
        return combined
    }

    private func recognizeText(in image: UIImage) async throws -> String {
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
                let lines = observations.compactMap { $0.topCandidates(1).first?.string }
                continuation.resume(returning: lines.joined(separator: "\n"))
            }

            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            request.recognitionLanguages = ["en", "es", "it", "fr", "de", "pt"]

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: OCRError.recognitionFailed(error.localizedDescription))
            }
        }
    }
}
