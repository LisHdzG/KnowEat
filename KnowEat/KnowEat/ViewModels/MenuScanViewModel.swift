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
    var errorTitle: String = "Error"
    var canRetry = false
    var showResults = false
    var showPermissionDeniedAlert = false

    private var lastImages: [UIImage] = []
    private var lastProfile: UserProfile?

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

    func handleScannedImages(_ images: [UIImage], profile: UserProfile) {
        lastImages = images
        lastProfile = profile
        isShowingScanner = false
        performAnalysis(images: images, profile: profile)
    }

    func retry() {
        guard let profile = lastProfile, !lastImages.isEmpty else { return }
        performAnalysis(images: lastImages, profile: profile)
    }

    func handleScanCancelled() {
        isShowingScanner = false
    }

    func dismissResults() {
        showResults = false
        scannedMenu = nil
        analyzedDishes = []
        lastImages = []
        lastProfile = nil
    }

    private func performAnalysis(images: [UIImage], profile: UserProfile) {
        isAnalyzing = true
        errorMessage = nil
        canRetry = false

        Task {
            do {
                let ocrText = try await OCRService.shared.extractText(from: images)
                let menu: ScannedMenu

                if FoundationModelAnalyzer.shared.isAvailable {
                    menu = try await FoundationModelAnalyzer.shared.analyze(
                        ocrText: ocrText,
                        userLanguage: profile.nativeLanguage
                    )
                } else {
                    menu = OfflineMenuAnalyzer.shared.analyze(
                        ocrText: ocrText,
                        userLanguage: profile.nativeLanguage
                    )
                }

                let analyzed = AllergenChecker.analyze(menu: menu, profile: profile)
                self.scannedMenu = menu
                self.analyzedDishes = analyzed
                self.isAnalyzing = false
                self.showResults = true
            } catch is FoundationModelError {
                if let ocrText = try? await OCRService.shared.extractText(from: images) {
                    let menu = OfflineMenuAnalyzer.shared.analyze(ocrText: ocrText, userLanguage: profile.nativeLanguage)
                    let analyzed = AllergenChecker.analyze(menu: menu, profile: profile)
                    self.scannedMenu = menu
                    self.analyzedDishes = analyzed
                    self.isAnalyzing = false
                    self.showResults = true
                } else {
                    self.isAnalyzing = false
                    self.errorTitle = "Analysis Error"
                    self.errorMessage = "Could not analyze the menu."
                    self.canRetry = true
                }
            } catch let ocrError as OCRError {
                self.isAnalyzing = false
                self.errorTitle = "Scan Error"
                self.errorMessage = ocrError.errorDescription
                self.canRetry = true
            } catch {
                self.isAnalyzing = false
                self.errorTitle = "Error"
                self.errorMessage = error.localizedDescription
                self.canRetry = true
            }
        }
    }
}
