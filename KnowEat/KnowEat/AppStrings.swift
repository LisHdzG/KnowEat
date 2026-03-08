//
//  AppStrings.swift
//  KnowEat
//

import Foundation

struct AppStrings {
    let lang: String

    init(_ language: String = "English") {
        self.lang = language
    }

    private func t(_ en: String, _ es: String, _ it: String) -> String {
        switch lang {
        case "Español": return es
        case "Italiano": return it
        default: return en
        }
    }

    // MARK: - Common

    var save: String { t("Save", "Guardar", "Salva") }
    var cancel: String { t("Cancel", "Cancelar", "Annulla") }
    var close: String { t("Close", "Cerrar", "Chiudi") }
    var done: String { t("Done", "Listo", "Fatto") }
    var continueButton: String { t("Continue", "Continuar", "Continua") }
    var delete: String { t("Delete", "Eliminar", "Elimina") }

    // MARK: - Onboarding

    var welcomeTo: String { t("Welcome to", "Bienvenido a", "Benvenuto a") }
    var setupDescription: String { t(
        "Set up your dietary profile. You can always change it later in Settings.",
        "Configura tu perfil alimentario. Puedes cambiarlo después en Ajustes.",
        "Configura il tuo profilo alimentare. Puoi modificarlo nelle Impostazioni."
    ) }
    var primaryLanguage: String { t("Primary language", "Idioma principal", "Lingua principale") }
    var nativeLanguage: String { t("Native Language", "Idioma nativo", "Lingua madre") }
    var languagePickerHint: String { t(
        "Opens language picker to set your native language",
        "Abre el selector de idioma para configurar tu idioma nativo",
        "Apre il selettore lingua per impostare la tua lingua madre"
    ) }
    var continueHint: String { t(
        "Saves your dietary profile and starts using KnowEat",
        "Guarda tu perfil alimentario y comienza a usar KnowEat",
        "Salva il tuo profilo alimentare e inizia a usare KnowEat"
    ) }

    // MARK: - Dietary Categories

    var allergens: String { t("Allergens", "Alérgenos", "Allergeni") }
    var allergensDesc: String { t(
        "Most common food allergens.",
        "Alérgenos alimentarios más comunes.",
        "Allergeni alimentari più comuni."
    ) }
    var intolerances: String { t("Intolerances", "Intolerancias", "Intolleranze") }
    var intolerancesDesc: String { t(
        "Foods your body has trouble digesting.",
        "Alimentos que tu cuerpo tiene dificultad para digerir.",
        "Alimenti che il tuo corpo ha difficoltà a digerire."
    ) }
    var medicalConditions: String { t("Medical Conditions", "Condiciones médicas", "Condizioni mediche") }
    var conditionsDesc: String { t(
        "Conditions that affect your diet.",
        "Condiciones que afectan tu dieta.",
        "Condizioni che influenzano la tua dieta."
    ) }
    var diets: String { t("Diets", "Dietas", "Diete") }
    var dietsDesc: String { t(
        "Lifestyle or religious diets.",
        "Dietas de estilo de vida o religiosas.",
        "Diete di stile di vita o religiose."
    ) }
    var situations: String { t("Situations", "Situaciones", "Situazioni") }
    var situationsDesc: String { t(
        "Temporary situations.",
        "Situaciones temporales.",
        "Situazioni temporanee."
    ) }

    // MARK: - Home

    var recentMenus: String { t("Recent Menus", "Menús recientes", "Menu recenti") }
    var settings: String { t("Settings", "Ajustes", "Impostazioni") }
    var scanMenu: String { t("Scan Menu", "Escanear menú", "Scansiona menu") }
    var noMenusYet: String { t("No menus yet", "Sin menús aún", "Nessun menu") }
    var scanToGetStarted: String { t(
        "Scan a menu to get started",
        "Escanea un menú para comenzar",
        "Scansiona un menu per iniziare"
    ) }
    var today: String { t("Today", "Hoy", "Oggi") }
    var yesterday: String { t("Yesterday", "Ayer", "Ieri") }
    var dataLocalNote: String { t(
        "Everything is saved on your device. Uninstalling the app will remove your data.",
        "Todo se guarda en tu dispositivo. Si desinstalas la app, se borrarán tus datos.",
        "Tutto viene salvato sul tuo dispositivo. Disinstallando l'app, i dati verranno rimossi."
    ) }
    var dataPrivacyReminder: String { t(
        "Your data stays on your device. We don't share anything with third parties.",
        "Tus datos se quedan en tu teléfono. No compartimos nada con terceros.",
        "I tuoi dati restano sul tuo telefono. Non condividiamo nulla con terze parti."
    ) }
    var cameraAccessRequired: String { t(
        "Camera Access Required",
        "Acceso a cámara requerido",
        "Accesso fotocamera richiesto"
    ) }
    var cameraAccessMessage: String { t(
        "KnowEat needs camera access to scan menus. Please enable it in Settings.",
        "KnowEat necesita acceso a la cámara para escanear menús. Actívalo en Ajustes.",
        "KnowEat ha bisogno dell'accesso alla fotocamera per scansionare i menu. Abilitalo nelle Impostazioni."
    ) }
    var openSettings: String { t("Open Settings", "Abrir Ajustes", "Apri Impostazioni") }
    var renameMenu: String { t("Rename Menu", "Renombrar menú", "Rinomina menu") }
    var restaurantName: String { t("Restaurant name", "Nombre del restaurante", "Nome del ristorante") }
    var rename: String { t("Rename", "Renombrar", "Rinomina") }
    var retakePhoto: String { t("Retake Photo", "Tomar otra foto", "Scatta un'altra foto") }
    var searchMenus: String { t("Search menus...", "Buscar menús...", "Cerca menu...") }

    var setupProfileTitle: String { t(
        "Set up your dietary profile",
        "Configura tu perfil alimentario",
        "Configura il tuo profilo alimentare"
    ) }
    var setupProfileSubtitle: String { t(
        "Tell us about your allergies and dietary needs so we can personalize your experience.",
        "Cuéntanos sobre tus alergias y necesidades alimentarias para personalizar tu experiencia.",
        "Raccontaci le tue allergie e le tue esigenze alimentari per personalizzare la tua esperienza."
    ) }
    var setupProfileAction: String { t(
        "Set up now",
        "Configurar ahora",
        "Configura ora"
    ) }

    func dishesCount(_ count: Int) -> String {
        t("\(count) dishes", "\(count) platillos", "\(count) piatti")
    }

    // MARK: - Home Error Sheet

    var notAMenuTitle: String { t("Not a Menu", "No es un menú", "Non è un menu") }
    var analysisFailedTitle: String { t("Analysis Failed", "Análisis fallido", "Analisi fallita") }
    var noMenuTextFoundTitle: String { t("No Menu Text Found", "No se encontró texto", "Nessun testo trovato") }
    var couldntReadTextTitle: String { t("Couldn't Read Text", "No se pudo leer el texto", "Impossibile leggere il testo") }
    var somethingWentWrongTitle: String { t("Something Went Wrong", "Algo salió mal", "Qualcosa è andato storto") }
    var photographMenuTip: String { t(
        "Photograph a food menu with text",
        "Fotografía un menú de comida con texto",
        "Fotografa un menu con testo"
    ) }
    var goodLightingTip: String { t(
        "Use good lighting, avoid shadows",
        "Usa buena iluminación, evita sombras",
        "Usa una buona illuminazione, evita le ombre"
    ) }
    var keepFocusTip: String { t(
        "Keep text in focus and fully visible",
        "Mantén el texto enfocado y visible",
        "Mantieni il testo a fuoco e ben visibile"
    ) }

    // MARK: - Settings

    var languageSection: String { t("Language", "Idioma", "Lingua") }
    var languageChangeNote: String { t(
        "Changing your native language will change the entire app language.",
        "Cambiar tu idioma nativo cambiará el idioma de toda la aplicación.",
        "Cambiare la lingua madre cambierà la lingua dell'intera app."
    ) }
    var dietaryProfile: String { t("Dietary Profile", "Perfil alimentario", "Profilo alimentare") }
    var myAllergens: String { t("My Allergens", "Mis alérgenos", "I miei allergeni") }
    var selectAllergensDesc: String { t(
        "Select the allergens you want KnowEat to watch for when scanning menus.",
        "Selecciona los alérgenos que quieres que KnowEat detecte al escanear menús.",
        "Seleziona gli allergeni che vuoi che KnowEat rilevi durante la scansione dei menu."
    ) }
    var selectIntolerancesDesc: String { t(
        "Select food intolerances so KnowEat can flag problematic ingredients.",
        "Selecciona intolerancias alimentarias para que KnowEat señale ingredientes problemáticos.",
        "Seleziona le intolleranze alimentari in modo che KnowEat segnali ingredienti problematici."
    ) }
    var selectConditionsDesc: String { t(
        "Select medical conditions that affect your diet so KnowEat can give better recommendations.",
        "Selecciona condiciones médicas que afecten tu dieta para mejores recomendaciones.",
        "Seleziona condizioni mediche che influenzano la tua dieta per raccomandazioni migliori."
    ) }
    var selectDietsDesc: String { t(
        "Select lifestyle or religious diets you follow.",
        "Selecciona dietas de estilo de vida o religiosas que sigues.",
        "Seleziona le diete di stile di vita o religiose che segui."
    ) }
    var selectSituationsDesc: String { t(
        "Select temporary situations that may affect what you should eat.",
        "Selecciona situaciones temporales que puedan afectar lo que debes comer.",
        "Seleziona situazioni temporanee che possono influenzare ciò che dovresti mangiare."
    ) }

    func activeCount(_ count: Int) -> String {
        t("\(count) active", "\(count) activos", "\(count) attivi")
    }

    var history: String { t("History", "Historial", "Cronologia") }
    var saveHistory: String { t("Save history", "Guardar historial", "Salva cronologia") }
    var deleteAllMenus: String { t("Delete all menus", "Eliminar todos los menús", "Elimina tutti i menu") }
    var deleteAllMenusConfirm: String { t(
        "Delete All Menus?",
        "¿Eliminar todos los menús?",
        "Eliminare tutti i menu?"
    ) }
    func deleteAllMessage(_ count: Int) -> String {
        t(
            "This will permanently delete all \(count) saved menus.",
            "Esto eliminará permanentemente los \(count) menús guardados.",
            "Questo eliminerà permanentemente tutti i \(count) menu salvati."
        )
    }
    var deleteAllButton: String { t("Delete All", "Eliminar todo", "Elimina tutto") }
    var areYouSure: String { t("Are you sure?", "¿Estás seguro?", "Sei sicuro?") }
    var cannotBeUndone: String { t(
        "This action cannot be undone.",
        "Esta acción no se puede deshacer.",
        "Questa azione non può essere annullata."
    ) }
    var yesDeleteAll: String { t(
        "Yes, delete everything",
        "Sí, eliminar todo",
        "Sì, elimina tutto"
    ) }

    var about: String { t("About", "Acerca de", "Informazioni") }
    var privacyPolicy: String { t("Privacy Policy", "Política de privacidad", "Informativa sulla privacy") }
    var rateKnowEat: String { t("Rate KnowEat", "Califica KnowEat", "Valuta KnowEat") }

    // MARK: - Menu Result

    func dishesFound(_ count: Int) -> String {
        t("\(count) dishes found", "\(count) platillos encontrados", "\(count) piatti trovati")
    }
    var analyzedOnDevice: String { t(
        "Analyzed on your device",
        "Analizado en tu dispositivo",
        "Analizzato sul tuo dispositivo"
    ) }
    var confirmWithStaff: String { t(
        "Always confirm with staff for severe allergies.",
        "Siempre confirma con el personal para alergias graves.",
        "Conferma sempre con il personale per allergie gravi."
    ) }
    var searchDishes: String { t("Search dishes...", "Buscar platillos...", "Cerca piatti...") }
    var noPhotoAvailable: String { t("No photo available", "Foto no disponible", "Foto non disponibile") }
    var viewOnMenu: String { t("View on menu", "Ver en el menú", "Vedi nel menu") }
    var restaurantNameTitle: String { t("Restaurant Name", "Nombre del restaurante", "Nome del ristorante") }
    var enterRestaurantName: String { t(
        "Enter restaurant name",
        "Ingresa el nombre",
        "Inserisci il nome"
    ) }
    var couldntDetectName: String { t(
        "We couldn't detect the restaurant name. Please enter it to save this menu.",
        "No pudimos detectar el nombre del restaurante. Ingresa un nombre para guardar este menú.",
        "Non siamo riusciti a rilevare il nome del ristorante. Inserisci un nome per salvare questo menu."
    ) }

    // MARK: - Dish Card

    var unknownDishWarning: String { t(
        "Unknown dish — please ask staff about ingredients",
        "Platillo desconocido — pregunta al personal sobre los ingredientes",
        "Piatto sconosciuto — chiedi al personale riguardo gli ingredienti"
    ) }
    var ingredientsNotListed: String { t(
        "Ingredients not listed on menu — confirm with staff",
        "Ingredientes no listados en el menú — confirma con el personal",
        "Ingredienti non elencati nel menu — conferma con il personale"
    ) }
    var noIngredientsAvailable: String { t(
        "No ingredients available — please ask staff",
        "Sin ingredientes disponibles — pregunta al personal",
        "Nessun ingrediente disponibile — chiedi al personale"
    ) }
    var noIngredientsDetected: String { t(
        "No ingredients detected — ask staff about this dish",
        "No se detectaron ingredientes — pregunta al personal sobre este platillo",
        "Ingredienti non rilevati — chiedi al personale riguardo questo piatto"
    ) }

    func aiSuggestsMayContain(_ names: String) -> String { t(
        "AI suggests may contain: \(names)",
        "IA sugiere que podría contener: \(names)",
        "IA suggerisce che potrebbe contenere: \(names)"
    ) }

    var translatingDescriptions: String { t(
        "Translating descriptions…",
        "Traduciendo descripciones…",
        "Traduzione delle descrizioni…"
    ) }

    var ingredientsLabel: String { t("Ingredients", "Ingredientes", "Ingredienti") }
    var inferredByAI: String { t("AI inferred", "Inferido por IA", "Dedotto dall'IA") }

    func localizedAllergenName(_ id: String) -> String {
        switch id {
        // Allergens
        case "gluten": return t("Gluten", "Gluten", "Glutine")
        case "dairy": return t("Dairy", "Lácteos", "Latticini")
        case "eggs": return t("Eggs", "Huevos", "Uova")
        case "fish": return t("Fish", "Pescado", "Pesce")
        case "crustaceans": return t("Crustaceans", "Crustáceos", "Crostacei")
        case "peanuts": return t("Peanuts", "Cacahuetes", "Arachidi")
        case "soy": return t("Soy", "Soja", "Soia")
        case "tree_nuts": return t("Tree Nuts", "Frutos secos", "Frutta a guscio")
        case "celery": return t("Celery", "Apio", "Sedano")
        case "mustard": return t("Mustard", "Mostaza", "Senape")
        case "sesame": return t("Sesame", "Sésamo", "Sesamo")
        case "sulfites": return t("Sulfites", "Sulfitos", "Solfiti")
        case "lupins": return t("Lupins", "Altramuces", "Lupini")
        case "mollusks": return t("Mollusks", "Moluscos", "Molluschi")
        // Intolerances
        case "lactose": return t("Lactose", "Lactosa", "Lattosio")
        case "fructose": return t("Fructose", "Fructosa", "Fruttosio")
        case "histamine": return t("Histamine", "Histamina", "Istamina")
        case "fodmap": return t("FODMAP (digestive sensitivity)", "FODMAP (sensibilidad digestiva)", "FODMAP (sensibilità digestiva)")
        // Content types
        case "meat": return t("Meat", "Carne", "Carne")
        case "poultry": return t("Poultry", "Aves", "Pollame")
        case "pork": return t("Pork", "Cerdo", "Maiale")
        case "alcohol": return t("Alcohol", "Alcohol", "Alcol")
        // Conditions
        case "celiac": return t("Celiac Disease", "Enfermedad celíaca", "Celiachia")
        case "diabetes": return t("Diabetes", "Diabetes", "Diabete")
        case "hypertension": return t("Hypertension", "Hipertensión", "Ipertensione")
        case "kidney_disease": return t("Kidney Disease", "Enfermedad renal", "Malattia renale")
        case "gout": return t("Gout", "Gota", "Gotta")
        case "favism": return t("Favism (G6PD)", "Favismo (G6PD)", "Favismo (G6PD)")
        // Diets
        case "vegetarian": return t("Vegetarian", "Vegetariano", "Vegetariano")
        case "vegan": return t("Vegan", "Vegano", "Vegano")
        case "pescatarian": return t("Pescatarian", "Pescetariano", "Pescetariano")
        case "halal": return "Halal"
        case "kosher": return "Kosher"
        // Situations
        case "pregnant": return t("Pregnancy", "Embarazo", "Gravidanza")
        case "breastfeeding": return t("Breastfeeding", "Lactancia", "Allattamento")
        default: return id.replacingOccurrences(of: "_", with: " ").capitalized
        }
    }

    // MARK: - Analysis Disclaimer

    var howKnowEatWorks: String { t(
        "How KnowEat works",
        "Cómo funciona KnowEat",
        "Come funziona KnowEat"
    ) }
    var privacyPolicyUpdated: String { t(
        "Privacy Policy Updated",
        "Política de privacidad actualizada",
        "Informativa sulla privacy aggiornata"
    ) }
    var alwaysDoubleCheck: String { t("Always double-check", "Siempre verifica", "Verifica sempre") }
    var doubleCheckDesc: String { t(
        "We suggest — you decide. Please confirm with restaurant staff before ordering.",
        "Nosotros sugerimos — tú decides. Confirma con el personal del restaurante antes de ordenar.",
        "Noi suggeriamo — tu decidi. Conferma con il personale del ristorante prima di ordinare."
    ) }
    var suggestsYouDecide: String { t(
        "KnowEat suggests, you decide. Always confirm with staff for severe allergies.",
        "KnowEat sugiere, tú decides. Siempre confirma con el personal para alergias graves.",
        "KnowEat suggerisce, tu decidi. Conferma sempre con il personale per allergie gravi."
    ) }
    var noDataSent: String { t(
        "No data sent to third parties",
        "Sin envío de datos a terceros",
        "Nessun dato inviato a terzi"
    ) }
    var noDataSentDesc: String { t(
        "Menu photos and preferences stay on your device. No third-party AI receives your data.",
        "Las fotos y preferencias permanecen en tu dispositivo. Ninguna IA de terceros recibe tus datos.",
        "Le foto e le preferenze restano sul tuo dispositivo. Nessuna IA di terze parti riceve i tuoi dati."
    ) }
    var personalizedForYou: String { t(
        "Personalized for you",
        "Personalizado para ti",
        "Personalizzato per te"
    ) }
    var personalizedDesc: String { t(
        "Results match your dietary profile.",
        "Los resultados coinciden con tu perfil alimentario.",
        "I risultati corrispondono al tuo profilo alimentare."
    ) }
    var understandNotMedical: String { t(
        "I understand this is not medical advice",
        "Entiendo que esto no es consejo médico",
        "Capisco che questo non è un consiglio medico"
    ) }
    var acceptContinue: String { t("Accept & Continue", "Aceptar y continuar", "Accetta e continua") }
    var readPrivacyPolicy: String { t(
        "Read our Privacy Policy",
        "Leer nuestra Política de Privacidad",
        "Leggi la nostra Informativa sulla Privacy"
    ) }
    var acceptUpdatedPrivacyNotice: String { t(
        "Accept updated privacy notice",
        "Aceptar aviso de privacidad actualizado",
        "Accetta avviso privacy aggiornato"
    ) }
    var continuesToApp: String { t(
        "Continues to the app",
        "Continúa a la app",
        "Continua all'app"
    ) }
    var mustAcceptFirst: String { t(
        "You must accept the notice first",
        "Debes aceptar el aviso primero",
        "Devi accettare l'avviso prima"
    ) }
    var opensPrivacyInSafari: String { t(
        "Opens the privacy policy in Safari",
        "Abre la política de privacidad en Safari",
        "Apre l'informativa sulla privacy in Safari"
    ) }
    var acceptedTapToUncheck: String { t(
        "Accepted. Tap to uncheck",
        "Aceptado. Toca para desmarcar",
        "Accettato. Tocca per deselezionare"
    ) }
    var tapToAccept: String { t(
        "Tap to accept",
        "Toca para aceptar",
        "Tocca per accettare"
    ) }

    // MARK: - Language Picker

    var selectLanguage: String { t("Select Language", "Seleccionar idioma", "Seleziona lingua") }
    var choosePreferredLanguage: String { t(
        "Choose your preferred language",
        "Elige tu idioma preferido",
        "Scegli la tua lingua preferita"
    ) }

    // MARK: - Active Filters Card

    var noDietaryRestrictions: String { t(
        "No dietary restrictions configured",
        "Sin restricciones alimentarias configuradas",
        "Nessuna restrizione alimentare configurata"
    ) }

    // MARK: - Scan Tutorial

    var scanTutorialTitle: String { t(
        "How to scan a menu",
        "Cómo escanear un menú",
        "Come scansionare un menu"
    ) }
    var scanTutorialTip1: String { t(
        "Capture the full menu so we can read every dish",
        "Captura todo el menú para que podamos leer cada platillo",
        "Cattura l'intero menu così possiamo leggere ogni piatto"
    ) }
    var scanTutorialTip2: String { t(
        "Center the text and hold your phone vertically",
        "Centra el texto y sostén el teléfono verticalmente",
        "Centra il testo e tieni il telefono in verticale"
    ) }
    var scanTutorialTip3: String { t(
        "Works best with menus that list ingredients",
        "Funciona mejor con menús que listen ingredientes",
        "Funziona meglio con menu che elencano gli ingredienti"
    ) }
    var scanTutorialTip4: String { t(
        "Use good lighting and avoid shadows or glare",
        "Usa buena iluminación y evita sombras o reflejos",
        "Usa una buona illuminazione ed evita ombre o riflessi"
    ) }
    var scanTutorialNote: String { t(
        "These are suggestions — scan any menu and we'll do our best!",
        "Son sugerencias — escanea cualquier menú y haremos nuestro mejor esfuerzo!",
        "Sono suggerimenti — scansiona qualsiasi menu e faremo del nostro meglio!"
    ) }
    var scanTutorialAction: String { t(
        "Let's scan!",
        "¡Vamos a escanear!",
        "Iniziamo a scansionare!"
    ) }

    // MARK: - Camera

    var closeCamera: String { t("Close camera", "Cerrar cámara", "Chiudi fotocamera") }
    var flashOn: String { t("Flash on", "Flash encendido", "Flash acceso") }
    var flashOff: String { t("Flash off", "Flash apagado", "Flash spento") }
    func photoCount(_ count: Int) -> String {
        if count == 1 { return t("1 photo", "1 foto", "1 foto") }
        return t("\(count) photos", "\(count) fotos", "\(count) foto")
    }
    var addMore: String { t("Add more", "Agregar más", "Aggiungi") }
    var analyze: String { t("Analyze", "Analizar", "Analizza") }
    var backToCamera: String { t("Back to camera", "Volver a cámara", "Torna alla fotocamera") }
    var cropPhoto: String { t("Crop photo", "Recortar foto", "Ritaglia foto") }
    var deletePhoto: String { t("Delete photo", "Eliminar foto", "Elimina foto") }
    var takePhoto: String { t("Take photo", "Tomar foto", "Scatta foto") }
    var photoLibrary: String { t("Photo library", "Biblioteca de fotos", "Libreria foto") }
    var resetCrop: String { t("Reset crop", "Restablecer recorte", "Ripristina ritaglio") }
    var discardCrop: String { t("Discard", "Descartar", "Annulla") }
    var applyCrop: String { t("Apply", "Aplicar", "Applica") }

    // MARK: - Loader / Analysis Stages

    var preparingImages: String { t("Preparing images…", "Preparando imágenes…", "Preparazione immagini…") }
    var readingMenuText: String { t("Reading menu text…", "Leyendo texto del menú…", "Lettura testo del menu…") }
    var validatingContent: String { t("Validating content…", "Validando contenido…", "Validazione contenuto…") }
    var analyzingDishes: String { t("Analyzing dishes…", "Analizando platillos…", "Analisi piatti…") }
    func translatingDish(_ current: Int, _ total: Int) -> String {
        t("Translating \(current)/\(total)…", "Traduciendo \(current)/\(total)…", "Traduzione \(current)/\(total)…")
    }
    var checkingAllergens: String { t("Checking your allergens…", "Verificando tus alérgenos…", "Controllo dei tuoi allergeni…") }
    var doneStage: String { t("Done!", "¡Listo!", "Fatto!") }
    var retryingBackup: String { t("Retrying with backup…", "Reintentando…", "Nuovo tentativo…") }
    var analyzingMenu: String { t("Analyzing menu", "Analizando menú", "Analisi menu") }

    var loaderPhrases: [String] { [
        t("Reading every dish on the menu…", "Leyendo cada platillo del menú…", "Lettura di ogni piatto del menu…"),
        t("Checking ingredients carefully…", "Revisando ingredientes cuidadosamente…", "Controllo attento degli ingredienti…"),
        t("Matching with your allergen profile…", "Comparando con tu perfil de alérgenos…", "Confronto con il tuo profilo allergeni…"),
        t("Almost there, analyzing details…", "Casi listo, analizando detalles…", "Quasi pronto, analisi dei dettagli…"),
        t("Making sure everything is safe for you…", "Asegurándome que todo sea seguro para ti…", "Mi assicuro che tutto sia sicuro per te…"),
    ] }

    // MARK: - Error Messages

    var notAMenuMessage: String { t(
        "We couldn't identify any dishes in this image. Make sure you're photographing a restaurant food menu.",
        "No pudimos identificar platillos en esta imagen. Asegúrate de fotografiar un menú de restaurante.",
        "Non siamo riusciti a identificare piatti in questa immagine. Assicurati di fotografare un menu di un ristorante."
    ) }
    var analysisFailedMessage: String { t(
        "We couldn't identify any dishes in this image. Make sure you're photographing a food menu with dish names and descriptions.",
        "No pudimos identificar platillos en esta imagen. Asegúrate de fotografiar un menú con nombres y descripciones.",
        "Non siamo riusciti a identificare piatti in questa immagine. Assicurati di fotografare un menu con nomi e descrizioni dei piatti."
    ) }
    var noTextMessage: String { t(
        "We couldn't detect any readable text in your photo. Please make sure you're photographing a restaurant menu.",
        "No pudimos detectar texto legible en tu foto. Asegúrate de fotografiar un menú de restaurante.",
        "Non siamo riusciti a rilevare testo leggibile nella foto. Assicurati di fotografare un menu di un ristorante."
    ) }
    var cantReadTextMessage: String { t(
        "The text in the image couldn't be processed. Try taking a clearer, well-lit photo with the menu fully visible.",
        "No se pudo procesar el texto de la imagen. Intenta tomar una foto más clara y bien iluminada.",
        "Il testo nell'immagine non può essere elaborato. Prova a scattare una foto più chiara e ben illuminata."
    ) }
    var unexpectedError: String { t(
        "An unexpected error occurred. Please try again with a new photo.",
        "Ocurrió un error inesperado. Intenta de nuevo con una nueva foto.",
        "Si è verificato un errore imprevisto. Riprova con una nuova foto."
    ) }

    // MARK: - Dietary Editor (from DietaryProfileEditorView)

    var foodAllergensDesc: String { t(
        "Food allergens that can cause reactions.",
        "Alérgenos alimentarios que pueden causar reacciones.",
        "Allergeni alimentari che possono causare reazioni."
    ) }

    // MARK: - Accessibility (contextual)

    var analysisNoticeA11y: String { t(
        "Analysis notice. Menu was analyzed on your device. Always confirm with staff for severe allergies.",
        "Aviso de análisis. El menú fue analizado en tu dispositivo. Siempre confirma con el personal para alergias graves.",
        "Avviso di analisi. Il menu è stato analizzato sul tuo dispositivo. Conferma sempre con il personale per allergie gravi."
    ) }
    var dismissDisclaimer: String { t(
        "Dismiss disclaimer",
        "Descartar aviso",
        "Chiudi avviso"
    ) }
    var saveMenu: String { t("Save menu", "Guardar menú", "Salva menu") }
    var saveMenuHint: String { t(
        "Saves this menu to your recent menus list",
        "Guarda este menú en tu lista de menús recientes",
        "Salva questo menu nella lista dei menu recenti"
    ) }
}
