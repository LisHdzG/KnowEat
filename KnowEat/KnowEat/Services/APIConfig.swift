//
//  APIConfig.swift
//  KnowEat
//
//  Created by Lisette HG on 20/02/26.
//

import Foundation

enum APIConfig {
    static let openAIKey: String = {
        guard let url = Bundle.main.url(forResource: "Secrets", withExtension: "plist"),
              let data = try? Data(contentsOf: url),
              let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
              let key = plist["OPENAI_API_KEY"] as? String,
              key != "YOUR_API_KEY_HERE" else {
            return ""
        }
        return key
    }()

    static let openAIBaseURL = "https://api.openai.com/v1/chat/completions"
    static let model = "gpt-4o"
}
