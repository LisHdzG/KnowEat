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

    var analysisProgress: Double = 0
    var analysisStage: String = ""

    private var lastImages: [UIImage] = []
    private var lastProfile: UserProfile?
    private var driftTask: Task<Void, Never>?

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

    func retakePhoto() {
        errorMessage = nil
        lastImages = []
        openScanner()
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

    private func startProgressDrift(from start: Double, to end: Double, over seconds: Double) {
        driftTask?.cancel()
        driftTask = Task { @MainActor in
            let steps = 30
            let stepDelay = seconds / Double(steps)
            let increment = (end - start) / Double(steps)

            for i in 1...steps {
                try? await Task.sleep(for: .milliseconds(Int(stepDelay * 1000)))
                if Task.isCancelled { return }
                analysisProgress = start + increment * Double(i)
            }
        }
    }

    private func stopProgressDrift() {
        driftTask?.cancel()
        driftTask = nil
    }

    private func performAnalysis(images: [UIImage], profile: UserProfile) {
        isAnalyzing = true
        errorMessage = nil
        canRetry = false
        analysisProgress = 0.05
        analysisStage = "Preparing images…"

        Task {
            do {
                analysisProgress = 0.15
                analysisStage = "Reading menu text…"
                let ocrText = try await OCRService.shared.extractText(from: images)

                analysisProgress = 0.40
                analysisStage = "Analyzing dishes…"
                startProgressDrift(from: 0.40, to: 0.78, over: 18)

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

                stopProgressDrift()
                analysisProgress = 0.82
                analysisStage = "Checking your allergens…"
                let analyzed = AllergenChecker.analyze(menu: menu, profile: profile)

                analysisProgress = 1.0
                analysisStage = "Done!"
                try? await Task.sleep(for: .milliseconds(500))

                self.scannedMenu = menu
                self.analyzedDishes = analyzed
                self.isAnalyzing = false
                self.showResults = true
            } catch is FoundationModelError {
                analysisProgress = 0.50
                analysisStage = "Retrying with backup…"
                if let ocrText = try? await OCRService.shared.extractText(from: images) {
                    let menu = OfflineMenuAnalyzer.shared.analyze(ocrText: ocrText, userLanguage: profile.nativeLanguage)
                    analysisProgress = 0.85
                    analysisStage = "Checking your allergens…"
                    let analyzed = AllergenChecker.analyze(menu: menu, profile: profile)
                    analysisProgress = 1.0
                    analysisStage = "Done!"
                    try? await Task.sleep(for: .milliseconds(500))
                    self.scannedMenu = menu
                    self.analyzedDishes = analyzed
                    self.isAnalyzing = false
                    self.showResults = true
                } else {
                    self.isAnalyzing = false
                    self.errorTitle = "Analysis Failed"
                    self.errorMessage = "We couldn't identify any dishes in this image. Make sure you're photographing a food menu with dish names and descriptions."
                    self.canRetry = true
                }
            } catch let ocrError as OCRError {
                self.isAnalyzing = false
                switch ocrError {
                case .noTextFound:
                    self.errorTitle = "No Menu Text Found"
                    self.errorMessage = "We couldn't detect any readable text in your photo. Please make sure you're photographing a restaurant menu."
                case .recognitionFailed:
                    self.errorTitle = "Couldn't Read Text"
                    self.errorMessage = "The text in the image couldn't be processed. Try taking a clearer, well-lit photo with the menu fully visible."
                }
                self.canRetry = true
            } catch {
                self.isAnalyzing = false
                self.errorTitle = "Something Went Wrong"
                self.errorMessage = "An unexpected error occurred. Please try again with a new photo."
                self.canRetry = true
            }
        }
    }
}
