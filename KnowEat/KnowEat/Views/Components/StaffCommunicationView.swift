//
//  StaffCommunicationView.swift
//  KnowEat
//

import SwiftUI
import AVFoundation
import NaturalLanguage

struct StaffCommunicationView: View {
    let menu: ScannedMenu
    let profile: UserProfile
    let strings: AppStrings

    @State private var tts = TTSPlayer()

    private var menuLangCode: String {
        MenuLanguageDetector.detect(from: menu)
    }

    private var userLangCode: String {
        switch profile.nativeLanguage {
        case "Español": "es"
        case "Italiano": "it"
        default: "en"
        }
    }

    private var menuMessage: String {
        StaffMessageBuilder.build(profile: profile, langCode: menuLangCode)
    }

    private var userMessage: String {
        StaffMessageBuilder.build(profile: profile, langCode: userLangCode)
    }

    private var showTranslation: Bool {
        menuLangCode.prefix(2) != userLangCode.prefix(2)
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    instructionSection
                    menuLanguageCard

                    if showTranslation {
                        userLanguageSection
                    }
                }
                .padding(24)
            }
            .background(Color(.systemGroupedBackground))
            .navigationBarTitleDisplayMode(.inline)
        }
        .onDisappear { tts.stop() }
    }

    // MARK: - Sections

    private var instructionSection: some View {
        HStack(spacing: 8) {
            Image(systemName: "lightbulb.fill")
                .font(.system(size: 14))
                .foregroundStyle(Color("PrimaryOrange"))
                .symbolRenderingMode(.hierarchical)
            Text(strings.staffCardHint)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 20)
    }

    private var menuLanguageCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(StaffMessageBuilder.languageDisplayName(for: menuLangCode))
                    .font(.interMedium(size: 12))
                    .foregroundStyle(.white.opacity(0.7))
                Spacer()
                Button {
                    tts.toggle(text: menuMessage, langCode: menuLangCode)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: tts.isSpeaking ? "stop.fill" : "speaker.wave.2.fill")
                            .font(.system(size: 14))
                            .contentTransition(.symbolEffect(.replace))
                        Text(tts.isSpeaking ? strings.stopAudio : strings.playAudio)
                            .font(.interMedium(size: 13))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(.white.opacity(0.2), in: Capsule())
                }
                .accessibilityLabel(tts.isSpeaking ? strings.stopAudio : strings.playAudio)
                .accessibilityAddTraits(.startsMediaSession)
            }

            Text(menuMessage)
                .font(.interRegular(size: 16))
                .foregroundStyle(.white)
                .lineSpacing(5)
                .textSelection(.enabled)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color("PrimaryOrange").gradient)
        )
    }

    private var userLanguageSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(strings.yourLanguageLabel)
                .font(.interMedium(size: 12))
                .foregroundStyle(.tertiary)

            Text(userMessage)
                .font(.interRegular(size: 14))
                .foregroundStyle(.secondary)
                .lineSpacing(3)
                .textSelection(.enabled)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }

}

// MARK: - TTS Player

@Observable
final class TTSPlayer {
    var isSpeaking = false
    private let synthesizer = AVSpeechSynthesizer()
    private var delegate: TTSSynthDelegate?

    func toggle(text: String, langCode: String) {
        if isSpeaking { stop(); return }
        play(text: text, langCode: langCode)
    }

    func play(text: String, langCode: String) {
        stop()
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: Self.voiceLocale(for: langCode))
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.85
        utterance.pitchMultiplier = 1.0

        delegate = TTSSynthDelegate { [weak self] in
            Task { @MainActor in self?.isSpeaking = false }
        }
        synthesizer.delegate = delegate
        synthesizer.speak(utterance)
        isSpeaking = true
    }

    func stop() {
        if synthesizer.isSpeaking { synthesizer.stopSpeaking(at: .immediate) }
        isSpeaking = false
    }

    private static func voiceLocale(for langCode: String) -> String {
        let map: [String: String] = [
            "en": "en-US", "es": "es-ES", "it": "it-IT",
            "fr": "fr-FR", "de": "de-DE", "pt": "pt-PT",
            "ja": "ja-JP", "zh": "zh-CN", "ko": "ko-KR",
            "th": "th-TH", "tr": "tr-TR", "el": "el-GR",
            "ar": "ar-SA", "nl": "nl-NL", "ru": "ru-RU",
            "pl": "pl-PL", "sv": "sv-SE", "da": "da-DK",
            "nb": "nb-NO", "fi": "fi-FI", "cs": "cs-CZ",
            "hu": "hu-HU", "ro": "ro-RO", "hr": "hr-HR",
            "vi": "vi-VN", "id": "id-ID", "ms": "ms-MY",
            "hi": "hi-IN", "uk": "uk-UA", "he": "he-IL",
        ]
        return map[langCode] ?? langCode
    }
}

private final class TTSSynthDelegate: NSObject, AVSpeechSynthesizerDelegate {
    let onDone: @Sendable () -> Void
    init(onDone: @escaping @Sendable () -> Void) { self.onDone = onDone; super.init() }
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) { onDone() }
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) { onDone() }
}

// MARK: - Menu Language Detector

enum MenuLanguageDetector {
    static func detect(from menu: ScannedMenu) -> String {
        let text = menu.dishes.prefix(15).map(\.name).joined(separator: ". ")
        guard !text.isEmpty else { return "en" }
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(text)
        guard let lang = recognizer.dominantLanguage else { return "en" }
        let raw = lang.rawValue
        if raw.hasPrefix("zh") { return "zh" }
        return raw.components(separatedBy: "-").first ?? "en"
    }
}

// MARK: - Staff Message Builder

enum StaffMessageBuilder {

    static func build(profile: UserProfile, langCode: String) -> String {
        let t = template(for: langCode)
        var lines: [String] = []
        lines.append("\(t.greeting)\n\(t.intro)")

        var restrictions: [String] = []

        if !profile.allergenIds.isEmpty {
            let names = profile.allergenIds.map { allergenName($0, lang: langCode) }
            restrictions.append("\(t.allergicTo) \(names.joined(separator: ", ")).")
        }
        if !profile.intoleranceIds.isEmpty {
            let names = profile.intoleranceIds.map { allergenName($0, lang: langCode) }
            restrictions.append("\(t.intoleranceTo) \(names.joined(separator: ", ")).")
        }
        if !profile.conditionIds.isEmpty {
            let names = profile.conditionIds.map { allergenName($0, lang: langCode) }
            restrictions.append("\(t.conditionsText) \(names.joined(separator: ", ")).")
        }
        if !profile.dietIds.isEmpty {
            let names = profile.dietIds.map { allergenName($0, lang: langCode) }
            restrictions.append("\(t.dietText) \(names.joined(separator: ", ")).")
        }
        for sit in profile.situationIds {
            if sit == "pregnant" { restrictions.append(t.pregnant) }
            if sit == "breastfeeding" { restrictions.append(t.breastfeeding) }
        }

        if !restrictions.isEmpty {
            lines.append(restrictions.joined(separator: "\n"))
        }

        lines.append(t.question)
        return lines.joined(separator: "\n\n")
    }

    static func languageDisplayName(for code: String) -> String {
        let locale = Locale(identifier: code)
        return locale.localizedString(forLanguageCode: code)?.localizedCapitalized
            ?? code.uppercased()
    }

    // MARK: - Templates

    private struct MessageTemplate {
        let greeting: String
        let intro: String
        let allergicTo: String
        let intoleranceTo: String
        let conditionsText: String
        let dietText: String
        let pregnant: String
        let breastfeeding: String
        let question: String
    }

    private static func template(for langCode: String) -> MessageTemplate {
        switch langCode {
        case "es":
            return MessageTemplate(
                greeting: "Hola, buenas.",
                intro: "Soy una persona con alergias alimentarias y restricciones dietéticas muy importantes para mi salud.",
                allergicTo: "Soy una persona alérgica a:",
                intoleranceTo: "Soy una persona con intolerancia a:",
                conditionsText: "Soy una persona con las siguientes condiciones médicas:",
                dietText: "Soy una persona que sigue una dieta:",
                pregnant: "Soy una persona gestante.",
                breastfeeding: "Soy una persona en período de lactancia.",
                question: "¿Podría indicarme qué platos del menú son seguros para mí? Muchas gracias."
            )
        case "it":
            return MessageTemplate(
                greeting: "Buongiorno.",
                intro: "Sono una persona con allergie alimentari e restrizioni dietetiche molto importanti per la mia salute.",
                allergicTo: "Sono una persona allergica a:",
                intoleranceTo: "Sono una persona con intolleranza a:",
                conditionsText: "Sono una persona con le seguenti condizioni mediche:",
                dietText: "Sono una persona che segue una dieta:",
                pregnant: "Sono una persona in stato di gravidanza.",
                breastfeeding: "Sono una persona in periodo di allattamento.",
                question: "Potrebbe indicarmi quali piatti del menu sono sicuri per me? Grazie mille."
            )
        case "fr":
            return MessageTemplate(
                greeting: "Bonjour.",
                intro: "Je suis une personne avec des allergies alimentaires et des restrictions diététiques très importantes pour ma santé.",
                allergicTo: "Je suis une personne allergique à :",
                intoleranceTo: "Je suis une personne avec une intolérance à :",
                conditionsText: "Je suis une personne avec les conditions médicales suivantes :",
                dietText: "Je suis une personne qui suit un régime :",
                pregnant: "Je suis une personne enceinte.",
                breastfeeding: "Je suis une personne qui allaite.",
                question: "Pourriez-vous m'indiquer quels plats du menu sont sans danger pour moi ? Merci beaucoup."
            )
        case "de":
            return MessageTemplate(
                greeting: "Guten Tag.",
                intro: "Ich bin eine Person mit Nahrungsmittelallergien und Ernährungseinschränkungen, die für meine Gesundheit sehr wichtig sind.",
                allergicTo: "Ich bin eine Person mit Allergien gegen:",
                intoleranceTo: "Ich bin eine Person mit Unverträglichkeit gegen:",
                conditionsText: "Ich bin eine Person mit folgenden Erkrankungen:",
                dietText: "Ich bin eine Person, die eine Diät befolgt:",
                pregnant: "Ich bin eine schwangere Person.",
                breastfeeding: "Ich bin eine Person, die stillt.",
                question: "Könnten Sie mir bitte sagen, welche Gerichte auf der Speisekarte für mich sicher sind? Vielen Dank."
            )
        case "pt":
            return MessageTemplate(
                greeting: "Olá, bom dia.",
                intro: "Sou uma pessoa com alergias alimentares e restrições dietéticas muito importantes para a minha saúde.",
                allergicTo: "Sou uma pessoa alérgica a:",
                intoleranceTo: "Sou uma pessoa com intolerância a:",
                conditionsText: "Sou uma pessoa com as seguintes condições médicas:",
                dietText: "Sou uma pessoa que segue uma dieta:",
                pregnant: "Sou uma pessoa gestante.",
                breastfeeding: "Sou uma pessoa em período de amamentação.",
                question: "Poderia me indicar quais pratos do cardápio são seguros para mim? Muito obrigado/a."
            )
        case "ja":
            return MessageTemplate(
                greeting: "こんにちは。",
                intro: "私は食物アレルギーと食事制限がある人です。健康上とても重要です。",
                allergicTo: "アレルギーがある人です：",
                intoleranceTo: "不耐症がある人です：",
                conditionsText: "以下の疾患がある人です：",
                dietText: "食事制限をしている人です：",
                pregnant: "妊娠中の人です。",
                breastfeeding: "授乳中の人です。",
                question: "メニューの中で私が安全に食べられる料理を教えていただけますか？よろしくお願いいたします。"
            )
        case "zh":
            return MessageTemplate(
                greeting: "你好。",
                intro: "我是一个有食物过敏和饮食限制的人，这对我的健康非常重要。",
                allergicTo: "我是一个对以下食物过敏的人：",
                intoleranceTo: "我是一个对以下食物不耐受的人：",
                conditionsText: "我是一个有以下健康状况的人：",
                dietText: "我是一个遵循以下饮食的人：",
                pregnant: "我是一个怀孕的人。",
                breastfeeding: "我是一个在哺乳期的人。",
                question: "请问菜单上哪些菜品对我来说是安全的？非常感谢。"
            )
        case "ko":
            return MessageTemplate(
                greeting: "안녕하세요.",
                intro: "저는 식품 알레르기와 식이 제한이 있는 사람이며, 이는 제 건강에 매우 중요합니다.",
                allergicTo: "알레르기가 있는 사람입니다:",
                intoleranceTo: "불내증이 있는 사람입니다:",
                conditionsText: "다음과 같은 건강 상태가 있는 사람입니다:",
                dietText: "식이요법을 따르는 사람입니다:",
                pregnant: "임신 중인 사람입니다.",
                breastfeeding: "수유 중인 사람입니다.",
                question: "메뉴에서 제가 안전하게 먹을 수 있는 요리를 알려주시겠어요? 감사합니다."
            )
        case "th":
            return MessageTemplate(
                greeting: "สวัสดีครับ/ค่ะ",
                intro: "ผม/ดิฉันเป็นบุคคลที่มีอาการแพ้อาหารและข้อจำกัดด้านอาหารที่สำคัญมากต่อสุขภาพ",
                allergicTo: "เป็นบุคคลที่แพ้:",
                intoleranceTo: "เป็นบุคคลที่แพ้ (ไม่ทนต่อ):",
                conditionsText: "เป็นบุคคลที่มีโรคประจำตัว:",
                dietText: "เป็นบุคคลที่ทานอาหาร:",
                pregnant: "เป็นบุคคลที่กำลังตั้งครรภ์",
                breastfeeding: "เป็นบุคคลที่กำลังให้นมบุตร",
                question: "ช่วยแนะนำเมนูที่ปลอดภัยสำหรับผม/ดิฉันได้ไหมครับ/คะ? ขอบคุณมากครับ/ค่ะ"
            )
        case "tr":
            return MessageTemplate(
                greeting: "Merhaba.",
                intro: "Gıda alerjileri ve sağlığım için çok önemli diyet kısıtlamaları olan bir kişiyim.",
                allergicTo: "Alerjisi olan bir kişiyim:",
                intoleranceTo: "İntoleransı olan bir kişiyim:",
                conditionsText: "Şu sağlık durumları olan bir kişiyim:",
                dietText: "Şu diyeti uygulayan bir kişiyim:",
                pregnant: "Hamile bir kişiyim.",
                breastfeeding: "Emziren bir kişiyim.",
                question: "Menüde benim için güvenli olan yemekleri söyleyebilir misiniz? Çok teşekkürler."
            )
        case "el":
            return MessageTemplate(
                greeting: "Γεια σας.",
                intro: "Είμαι άτομο με τροφικές αλλεργίες και διατροφικούς περιορισμούς πολύ σημαντικούς για την υγεία μου.",
                allergicTo: "Είμαι άτομο με αλλεργία σε:",
                intoleranceTo: "Είμαι άτομο με δυσανεξία σε:",
                conditionsText: "Είμαι άτομο με τις ακόλουθες ιατρικές καταστάσεις:",
                dietText: "Είμαι άτομο που ακολουθεί δίαιτα:",
                pregnant: "Είμαι άτομο σε κατάσταση εγκυμοσύνης.",
                breastfeeding: "Είμαι άτομο που θηλάζει.",
                question: "Μπορείτε να μου πείτε ποια πιάτα του μενού είναι ασφαλή για μένα; Ευχαριστώ πολύ."
            )
        case "ar":
            return MessageTemplate(
                greeting: "مرحباً.",
                intro: "أنا شخص لديه حساسيات غذائية وقيود غذائية مهمة جداً لصحتي.",
                allergicTo: "أنا شخص لديه حساسية من:",
                intoleranceTo: "أنا شخص لديه عدم تحمل لـ:",
                conditionsText: "أنا شخص لديه الحالات الصحية التالية:",
                dietText: "أنا شخص يتبع نظاماً غذائياً:",
                pregnant: "أنا شخص في فترة الحمل.",
                breastfeeding: "أنا شخص يرضع.",
                question: "هل يمكنكم إخباري بالأطباق الآمنة لي في القائمة؟ شكراً جزيلاً."
            )
        case "nl":
            return MessageTemplate(
                greeting: "Goedendag.",
                intro: "Ik ben een persoon met voedselallergieën en dieetbeperkingen die erg belangrijk zijn voor mijn gezondheid.",
                allergicTo: "Ik ben een persoon met allergie voor:",
                intoleranceTo: "Ik ben een persoon met intolerantie voor:",
                conditionsText: "Ik ben een persoon met de volgende medische aandoeningen:",
                dietText: "Ik ben een persoon die een dieet volgt:",
                pregnant: "Ik ben een zwangere persoon.",
                breastfeeding: "Ik ben een persoon die borstvoeding geeft.",
                question: "Kunt u mij vertellen welke gerechten op het menu veilig voor mij zijn? Hartelijk dank."
            )
        case "ru":
            return MessageTemplate(
                greeting: "Здравствуйте.",
                intro: "Я человек с пищевой аллергией и диетическими ограничениями, очень важными для моего здоровья.",
                allergicTo: "Я человек с аллергией на:",
                intoleranceTo: "Я человек с непереносимостью:",
                conditionsText: "Я человек со следующими заболеваниями:",
                dietText: "Я человек, соблюдающий диету:",
                pregnant: "Я человек в положении.",
                breastfeeding: "Я человек, кормящий грудью.",
                question: "Не могли бы вы подсказать, какие блюда в меню безопасны для меня? Большое спасибо."
            )
        default:
            return MessageTemplate(
                greeting: "Hello.",
                intro: "I am a person with food allergies and dietary restrictions that are very important for my health.",
                allergicTo: "I am a person allergic to:",
                intoleranceTo: "I am a person with intolerance to:",
                conditionsText: "I am a person with the following medical conditions:",
                dietText: "I am a person who follows a diet:",
                pregnant: "I am a person who is pregnant.",
                breastfeeding: "I am a person who is breastfeeding.",
                question: "Could you please tell me which dishes on the menu are safe for me to eat? Thank you very much."
            )
        }
    }

    // MARK: - Allergen Names

    private static func allergenName(_ id: String, lang: String) -> String {
        allergenNames[lang]?[id]
            ?? allergenNames["en"]?[id]
            ?? id.replacingOccurrences(of: "_", with: " ").capitalized
    }

    private static let allergenNames: [String: [String: String]] = [
        "en": [
            "gluten": "gluten", "dairy": "dairy", "eggs": "eggs", "fish": "fish",
            "crustaceans": "crustaceans", "peanuts": "peanuts", "soy": "soy",
            "tree_nuts": "tree nuts", "celery": "celery", "mustard": "mustard",
            "sesame": "sesame", "sulfites": "sulfites", "lupins": "lupins",
            "mollusks": "mollusks", "lactose": "lactose", "fructose": "fructose",
            "histamine": "histamine", "fodmap": "FODMAP",
            "celiac": "celiac disease", "diabetes": "diabetes",
            "hypertension": "hypertension", "kidney_disease": "kidney disease",
            "gout": "gout", "favism": "favism (G6PD)",
            "vegetarian": "vegetarian", "vegan": "vegan",
            "pescatarian": "pescatarian", "halal": "halal", "kosher": "kosher",
            "meat": "meat", "poultry": "poultry", "pork": "pork", "alcohol": "alcohol",
        ],
        "es": [
            "gluten": "gluten", "dairy": "lácteos", "eggs": "huevos", "fish": "pescado",
            "crustaceans": "crustáceos", "peanuts": "cacahuetes", "soy": "soja",
            "tree_nuts": "frutos secos", "celery": "apio", "mustard": "mostaza",
            "sesame": "sésamo", "sulfites": "sulfitos", "lupins": "altramuces",
            "mollusks": "moluscos", "lactose": "lactosa", "fructose": "fructosa",
            "histamine": "histamina", "fodmap": "FODMAP",
            "celiac": "enfermedad celíaca", "diabetes": "diabetes",
            "hypertension": "hipertensión", "kidney_disease": "enfermedad renal",
            "gout": "gota", "favism": "favismo (G6PD)",
            "vegetarian": "vegetariana", "vegan": "vegana",
            "pescatarian": "pescetariana", "halal": "halal", "kosher": "kosher",
            "meat": "carne", "poultry": "aves", "pork": "cerdo", "alcohol": "alcohol",
        ],
        "it": [
            "gluten": "glutine", "dairy": "latticini", "eggs": "uova", "fish": "pesce",
            "crustaceans": "crostacei", "peanuts": "arachidi", "soy": "soia",
            "tree_nuts": "frutta a guscio", "celery": "sedano", "mustard": "senape",
            "sesame": "sesamo", "sulfites": "solfiti", "lupins": "lupini",
            "mollusks": "molluschi", "lactose": "lattosio", "fructose": "fruttosio",
            "histamine": "istamina", "fodmap": "FODMAP",
            "celiac": "celiachia", "diabetes": "diabete",
            "hypertension": "ipertensione", "kidney_disease": "malattia renale",
            "gout": "gotta", "favism": "favismo (G6PD)",
            "vegetarian": "vegetariana", "vegan": "vegana",
            "pescatarian": "pescetariana", "halal": "halal", "kosher": "kosher",
            "meat": "carne", "poultry": "pollame", "pork": "maiale", "alcohol": "alcol",
        ],
        "fr": [
            "gluten": "gluten", "dairy": "produits laitiers", "eggs": "œufs", "fish": "poisson",
            "crustaceans": "crustacés", "peanuts": "arachides", "soy": "soja",
            "tree_nuts": "fruits à coque", "celery": "céleri", "mustard": "moutarde",
            "sesame": "sésame", "sulfites": "sulfites", "lupins": "lupins",
            "mollusks": "mollusques", "lactose": "lactose", "fructose": "fructose",
            "histamine": "histamine", "fodmap": "FODMAP",
            "celiac": "maladie cœliaque", "diabetes": "diabète",
            "hypertension": "hypertension", "kidney_disease": "maladie rénale",
            "gout": "goutte", "favism": "favisme (G6PD)",
            "vegetarian": "végétarien", "vegan": "végétalien",
            "pescatarian": "pescatarien", "halal": "halal", "kosher": "casher",
            "meat": "viande", "poultry": "volaille", "pork": "porc", "alcohol": "alcool",
        ],
        "de": [
            "gluten": "Gluten", "dairy": "Milchprodukte", "eggs": "Eier", "fish": "Fisch",
            "crustaceans": "Krebstiere", "peanuts": "Erdnüsse", "soy": "Soja",
            "tree_nuts": "Schalenfrüchte", "celery": "Sellerie", "mustard": "Senf",
            "sesame": "Sesam", "sulfites": "Sulfite", "lupins": "Lupinen",
            "mollusks": "Weichtiere", "lactose": "Laktose", "fructose": "Fruktose",
            "histamine": "Histamin", "fodmap": "FODMAP",
            "celiac": "Zöliakie", "diabetes": "Diabetes",
            "hypertension": "Bluthochdruck", "kidney_disease": "Nierenerkrankung",
            "gout": "Gicht", "favism": "Favismus (G6PD)",
            "vegetarian": "vegetarisch", "vegan": "vegan",
            "pescatarian": "pescetarisch", "halal": "halal", "kosher": "koscher",
            "meat": "Fleisch", "poultry": "Geflügel", "pork": "Schweinefleisch", "alcohol": "Alkohol",
        ],
        "pt": [
            "gluten": "glúten", "dairy": "laticínios", "eggs": "ovos", "fish": "peixe",
            "crustaceans": "crustáceos", "peanuts": "amendoins", "soy": "soja",
            "tree_nuts": "frutos de casca rija", "celery": "aipo", "mustard": "mostarda",
            "sesame": "sésamo", "sulfites": "sulfitos", "lupins": "tremoços",
            "mollusks": "moluscos", "lactose": "lactose", "fructose": "frutose",
            "histamine": "histamina", "fodmap": "FODMAP",
            "celiac": "doença celíaca", "diabetes": "diabetes",
            "hypertension": "hipertensão", "kidney_disease": "doença renal",
            "gout": "gota", "favism": "favismo (G6PD)",
            "vegetarian": "vegetariana", "vegan": "vegana",
            "pescatarian": "pescetariana", "halal": "halal", "kosher": "kosher",
            "meat": "carne", "poultry": "aves", "pork": "porco", "alcohol": "álcool",
        ],
        "ja": [
            "gluten": "グルテン", "dairy": "乳製品", "eggs": "卵", "fish": "魚",
            "crustaceans": "甲殻類", "peanuts": "ピーナッツ", "soy": "大豆",
            "tree_nuts": "ナッツ類", "celery": "セロリ", "mustard": "マスタード",
            "sesame": "ごま", "sulfites": "亜硫酸塩", "lupins": "ルピン",
            "mollusks": "軟体動物", "lactose": "乳糖", "fructose": "果糖",
            "histamine": "ヒスタミン", "fodmap": "FODMAP",
            "celiac": "セリアック病", "diabetes": "糖尿病",
            "hypertension": "高血圧", "kidney_disease": "腎臓病",
            "gout": "痛風", "favism": "ファビズム",
            "vegetarian": "ベジタリアン", "vegan": "ビーガン",
            "pescatarian": "ペスカタリアン", "halal": "ハラール", "kosher": "コーシャ",
            "meat": "肉", "poultry": "鶏肉", "pork": "豚肉", "alcohol": "アルコール",
        ],
        "zh": [
            "gluten": "麸质", "dairy": "乳制品", "eggs": "鸡蛋", "fish": "鱼",
            "crustaceans": "甲壳类", "peanuts": "花生", "soy": "大豆",
            "tree_nuts": "坚果", "celery": "芹菜", "mustard": "芥末",
            "sesame": "芝麻", "sulfites": "亚硫酸盐", "lupins": "羽扇豆",
            "mollusks": "软体动物", "lactose": "乳糖", "fructose": "果糖",
            "histamine": "组胺", "fodmap": "FODMAP",
            "celiac": "乳糜泻", "diabetes": "糖尿病",
            "hypertension": "高血压", "kidney_disease": "肾病",
            "gout": "痛风", "favism": "蚕豆病",
            "vegetarian": "素食", "vegan": "纯素食",
            "pescatarian": "鱼素", "halal": "清真", "kosher": "犹太洁食",
            "meat": "肉类", "poultry": "禽肉", "pork": "猪肉", "alcohol": "酒精",
        ],
        "ko": [
            "gluten": "글루텐", "dairy": "유제품", "eggs": "달걀", "fish": "생선",
            "crustaceans": "갑각류", "peanuts": "땅콩", "soy": "대두",
            "tree_nuts": "견과류", "celery": "셀러리", "mustard": "겨자",
            "sesame": "참깨", "sulfites": "아황산염", "lupins": "루핀",
            "mollusks": "연체동물", "lactose": "유당", "fructose": "과당",
            "histamine": "히스타민", "fodmap": "FODMAP",
            "celiac": "셀리악병", "diabetes": "당뇨병",
            "hypertension": "고혈압", "kidney_disease": "신장병",
            "gout": "통풍", "favism": "잠두중독",
            "vegetarian": "채식", "vegan": "비건",
            "pescatarian": "페스코", "halal": "할랄", "kosher": "코셔",
            "meat": "육류", "poultry": "가금류", "pork": "돼지고기", "alcohol": "알코올",
        ],
    ]
}
