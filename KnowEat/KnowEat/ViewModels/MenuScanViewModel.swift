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
                let menu = try await OpenAIService.shared.analyzeMenu(images: images, userLanguage: profile.nativeLanguage)
                let analyzed = AllergenChecker.analyze(menu: menu, profile: profile)

                await MainActor.run {
                    self.scannedMenu = menu
                    self.analyzedDishes = analyzed
                    self.isAnalyzing = false
                    self.showResults = true
                }
            } catch let openAIError as OpenAIError {
                await MainActor.run {
                    self.isAnalyzing = false
                    self.canRetry = openAIError.isRetryable
                    switch openAIError {
                    case .unreadableMenu:
                        self.errorTitle = "Unreadable Menu"
                        self.errorMessage = openAIError.errorDescription
                    case .timeout:
                        self.errorTitle = "Connection Timeout"
                        self.errorMessage = openAIError.errorDescription
                    default:
                        self.errorTitle = "Error"
                        self.errorMessage = openAIError.errorDescription
                    }
                }
            } catch {
                await MainActor.run {
                    self.isAnalyzing = false
                    self.errorTitle = "Error"
                    self.errorMessage = error.localizedDescription
                    self.canRetry = false
                }
            }
        }
    }
}
