import Foundation

@Observable
final class SettingsViewModel {
    let availableLanguages = ["English", "Español", "Italiano"]

    var selectedLanguage: String = "English"
    var showLanguagePicker = false

    func load(from profile: UserProfile) {
        selectedLanguage = profile.nativeLanguage
    }

    func appVersion() -> String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "KnowEat V\(version).\(build)"
    }
}
