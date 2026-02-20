//
//  MenuScanViewModel.swift
//  KnowEat
//
//  Created by Lisette HG on 20/02/26.
//

import SwiftUI
import AVFoundation

@Observable
final class MenuScanViewModel {
    var isShowingScanner = false
    var isAnalyzing = false
    var scannedMenu: ScannedMenu?
    var analyzedDishes: [AnalyzedDish] = []
    var errorMessage: String?
    var showResults = false
    var showPermissionDeniedAlert = false

    func openScanner() {
        errorMessage = nil

        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            isShowingScanner = true

        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                Task { @MainActor in
                    if granted {
                        self.isShowingScanner = true
                    } else {
                        self.showPermissionDeniedAlert = true
                    }
                }
            }

        case .denied, .restricted:
            showPermissionDeniedAlert = true

        @unknown default:
            showPermissionDeniedAlert = true
        }
    }

    func openAppSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    func handleScannedImages(_ images: [UIImage], userAllergenIds: [String], userLanguage: String) {
        isShowingScanner = false
        isAnalyzing = true
        errorMessage = nil

        Task {
            do {
                let menu = try await OpenAIService.shared.analyzeMenu(images: images, userLanguage: userLanguage)
                let analyzed = AllergenChecker.analyze(menu: menu, userAllergenIds: userAllergenIds)

                await MainActor.run {
                    self.scannedMenu = menu
                    self.analyzedDishes = analyzed
                    self.isAnalyzing = false
                    self.showResults = true
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isAnalyzing = false
                }
            }
        }
    }

    func handleScanCancelled() {
        isShowingScanner = false
    }

    func dismissResults() {
        showResults = false
        scannedMenu = nil
        analyzedDishes = []
    }
}
