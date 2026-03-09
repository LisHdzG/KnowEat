//
//  KnowEatApp.swift
//  KnowEat
//
//  Created by Lisette HG on 19/02/26.
//

import SwiftUI
import CoreText
import FirebaseCore
import UserNotifications

extension Notification.Name {
    /// Posted when user taps the "menu ready" local notification. userInfo[NotificationPayload.menuIdKey] = menuId as String (UUID string).
    static let knowEatOpenMenuFromNotification = Notification.Name("KnowEatOpenMenuFromNotification")
}

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        FirebaseApp.configure()
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        if let menuIdString = userInfo[NotificationPayload.menuIdKey] as? String,
           UUID(uuidString: menuIdString) != nil {
            DispatchQueue.main.async {
                NotificationCenter.default.post(
                    name: .knowEatOpenMenuFromNotification,
                    object: nil,
                    userInfo: [NotificationPayload.menuIdKey: menuIdString]
                )
            }
        }
        completionHandler()
    }
}

@main
struct KnowEatApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate

    @State private var profileStore = UserProfileStore()
    @State private var menuStore = MenuStore()

    init() {
        registerCustomFonts()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(profileStore)
                .environment(menuStore)
        }
    }

    private func registerCustomFonts() {
        let fonts = ["Italianno-Regular", "Inter-Regular", "Inter-Medium", "Inter-SemiBold"]
        for font in fonts {
            guard let url = Bundle.main.url(forResource: font, withExtension: "ttf") else { continue }
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }
}
