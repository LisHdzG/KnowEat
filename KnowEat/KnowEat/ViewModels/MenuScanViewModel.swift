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

    private var strings: AppStrings {
        AppStrings(lastProfile?.nativeLanguage ?? "English")
    }

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
        isAnalyzing = true
        analysisProgress = 0.05
        analysisStage = strings.preparingImages
        isShowingScanner = false
        // Defer analysis to next run loop so the loader is visible immediately
        DispatchQueue.main.async { [weak self] in
            self?.performAnalysis(images: images, profile: profile)
        }
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
        analysisStage = strings.preparingImages

        Task {
            do {
                analysisProgress = 0.15
                analysisStage = strings.readingMenuText
                let ocrResult = try await OCRService.shared.extractTextWithRegions(from: images)

                analysisProgress = 0.25
                analysisStage = strings.validatingContent
                try MenuValidator.validate(ocrResult.text, regions: ocrResult.regions)

                analysisProgress = 0.40
                analysisStage = strings.analyzingDishes
                startProgressDrift(from: 0.40, to: 0.70, over: 15)

                var menu: ScannedMenu

                let nativeLang = profile.nativeLanguage
                let currentStrings = self.strings

                if FoundationModelAnalyzer.shared.isAvailable {
                    menu = try await FoundationModelAnalyzer.shared.analyze(
                        ocrText: ocrResult.text,
                        userLanguage: nativeLang,
                        onPhaseChange: { [weak self] phase in
                            guard let viewModel = self else { return }
                            Task { @MainActor in
                                switch phase {
                                case .extracting:
                                    break
                                case .translating(let current, let total):
                                    viewModel.stopProgressDrift()
                                    let base = 0.70
                                    let translationRange = 0.15
                                    viewModel.analysisProgress = base + translationRange * Double(current) / Double(total)
                                    viewModel.analysisStage = currentStrings.translatingDish(current, total)
                                }
                            }
                        }
                    )
                } else {
                    let offlineMenu = OfflineMenuAnalyzer.shared.analyze(
                        ocrText: ocrResult.text,
                        userLanguage: nativeLang
                    )
                    guard !offlineMenu.dishes.isEmpty else {
                        throw FoundationModelError.notAMenu
                    }
                    menu = offlineMenu
                }

                stopProgressDrift()

                let fileNames = ImageStorageService.shared.save(images: images, forMenuId: menu.id)
                menu.imageFileNames = fileNames
                menu.textRegions = ocrResult.regions
                menu.dishes = Self.matchDishesToRegions(dishes: menu.dishes, regions: ocrResult.regions)

                analysisProgress = 0.85
                analysisStage = strings.checkingAllergens
                let analyzed = AllergenChecker.analyze(menu: menu, profile: profile)

                analysisProgress = 1.0
                analysisStage = strings.doneStage
                try? await Task.sleep(for: .milliseconds(500))

                self.scannedMenu = menu
                self.analyzedDishes = analyzed
                self.isAnalyzing = false
                self.showResults = true
            } catch let validationError as MenuValidationError {
                stopProgressDrift()
                self.isAnalyzing = false
                self.errorTitle = self.strings.notAMenuTitle
                self.errorMessage = validationError.localizedDescription
                self.canRetry = true
            } catch FoundationModelError.notAMenu {
                stopProgressDrift()
                analysisProgress = 0.50
                analysisStage = self.strings.retryingBackup
                if let ocrResult = try? await OCRService.shared.extractTextWithRegions(from: images) {
                    var menu = OfflineMenuAnalyzer.shared.analyze(ocrText: ocrResult.text, userLanguage: "English")
                    if menu.dishes.isEmpty {
                        self.isAnalyzing = false
                        self.errorTitle = self.strings.notAMenuTitle
                        self.errorMessage = self.strings.notAMenuMessage
                        self.canRetry = true
                    } else {
                        let fileNames = ImageStorageService.shared.save(images: images, forMenuId: menu.id)
                        menu.imageFileNames = fileNames
                        menu.textRegions = ocrResult.regions
                        menu.dishes = Self.matchDishesToRegions(dishes: menu.dishes, regions: ocrResult.regions)

                        analysisProgress = 0.85
                        analysisStage = self.strings.checkingAllergens
                        let analyzed = AllergenChecker.analyze(menu: menu, profile: profile)
                        analysisProgress = 1.0
                        analysisStage = self.strings.doneStage
                        try? await Task.sleep(for: .milliseconds(500))
                        self.scannedMenu = menu
                        self.analyzedDishes = analyzed
                        self.isAnalyzing = false
                        self.showResults = true
                    }
                } else {
                    self.isAnalyzing = false
                    self.errorTitle = self.strings.notAMenuTitle
                    self.errorMessage = self.strings.notAMenuMessage
                    self.canRetry = true
                }
            } catch is FoundationModelError {
                stopProgressDrift()
                analysisProgress = 0.50
                analysisStage = self.strings.retryingBackup
                if let ocrResult = try? await OCRService.shared.extractTextWithRegions(from: images) {
                    var menu = OfflineMenuAnalyzer.shared.analyze(ocrText: ocrResult.text, userLanguage: "English")
                    if menu.dishes.isEmpty {
                        self.isAnalyzing = false
                        self.errorTitle = self.strings.analysisFailedTitle
                        self.errorMessage = self.strings.analysisFailedMessage
                        self.canRetry = true
                    } else {
                        let fileNames = ImageStorageService.shared.save(images: images, forMenuId: menu.id)
                        menu.imageFileNames = fileNames
                        menu.textRegions = ocrResult.regions
                        menu.dishes = Self.matchDishesToRegions(dishes: menu.dishes, regions: ocrResult.regions)

                        analysisProgress = 0.85
                        analysisStage = self.strings.checkingAllergens
                        let analyzed = AllergenChecker.analyze(menu: menu, profile: profile)
                        analysisProgress = 1.0
                        analysisStage = self.strings.doneStage
                        try? await Task.sleep(for: .milliseconds(500))
                        self.scannedMenu = menu
                        self.analyzedDishes = analyzed
                        self.isAnalyzing = false
                        self.showResults = true
                    }
                } else {
                    self.isAnalyzing = false
                    self.errorTitle = self.strings.analysisFailedTitle
                    self.errorMessage = self.strings.analysisFailedMessage
                    self.canRetry = true
                }
            } catch let ocrError as OCRError {
                stopProgressDrift()
                self.isAnalyzing = false
                switch ocrError {
                case .noTextFound:
                    self.errorTitle = self.strings.noMenuTextFoundTitle
                    self.errorMessage = self.strings.noTextMessage
                case .recognitionFailed:
                    self.errorTitle = self.strings.couldntReadTextTitle
                    self.errorMessage = self.strings.cantReadTextMessage
                }
                self.canRetry = true
            } catch {
                stopProgressDrift()
                self.isAnalyzing = false
                self.errorTitle = self.strings.somethingWentWrongTitle
                self.errorMessage = self.strings.unexpectedError
                self.canRetry = true
            }
        }
    }

    private static func matchDishesToRegions(dishes: [Dish], regions: [TextRegion]) -> [Dish] {
        dishes.map { dish in
            let normalize: (String) -> String = { s in
                s.lowercased()
                 .folding(options: .diacriticInsensitive, locale: nil)
                 .trimmingCharacters(in: .whitespacesAndNewlines)
            }
            let normalizedName = normalize(dish.name)
            let nameWords = normalizedName.split(separator: " ")
                .map(String.init)
                .filter { $0.count > 2 }

            var bestIdx: Int? = nil
            var bestScore: Int = 0

            for (idx, region) in regions.enumerated() {
                let normalizedRegion = normalize(region.text)
                if normalizedRegion.contains(normalizedName) {
                    bestIdx = idx
                    break
                }
                if !nameWords.isEmpty {
                    let hits = nameWords.filter { normalizedRegion.contains($0) }.count
                    let needed = nameWords.count <= 2 ? nameWords.count : (nameWords.count * 2 + 2) / 3
                    if hits >= needed && hits > bestScore {
                        bestScore = hits
                        bestIdx = idx
                    }
                }
            }

            let matchedIndices = bestIdx.map { [$0] } ?? []

            return Dish(
                name: dish.name,
                englishName: dish.englishName,
                translatedName: dish.translatedName,
                description: dish.description,
                price: dish.price,
                category: dish.category,
                ingredients: dish.ingredients,
                allergenIds: dish.allergenIds,
                inferredIngredients: dish.inferredIngredients,
                suggestedAllergenIds: dish.suggestedAllergenIds,
                textRegionIndices: matchedIndices
            )
        }
    }
}
