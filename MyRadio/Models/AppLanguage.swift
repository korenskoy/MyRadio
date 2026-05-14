//
//  AppLanguage.swift
//  MyRadio
//
//  App-language preference. `nativeName` is what we show in the picker —
//  each language is rendered in its own script/translation, matching the
//  design in docs/design/myradio/project/preferences.jsx.
//

import Foundation

enum AppLanguage: String, CaseIterable, Identifiable, Codable {
    case system
    case en, ru, de, fr, es, az, ja, zh

    var id: String { rawValue }

    /// Label rendered in the picker, written in the language itself.
    /// System falls through to the OS preferred language so the user sees
    /// what "System" actually maps to right now.
    var nativeName: String {
        switch self {
        case .system:
            let osLocale = Locale(identifier: Locale.preferredLanguages.first ?? "en")
            let lang = AppLanguage(rawValue: osLocale.language.languageCode?.identifier ?? "en") ?? .en
            return "System (\(lang.nativeName))"
        case .en: return "English"
        case .ru: return "Русский"
        case .de: return "Deutsch"
        case .fr: return "Français"
        case .es: return "Español"
        case .az: return "Azərbaycan"
        case .ja: return "日本語"
        case .zh: return "中文"
        }
    }

    /// BCP-47 codes written into `AppleLanguages` so macOS picks up the override
    /// on next launch. `system` clears the override.
    var appleLanguagesCodes: [String]? {
        switch self {
        case .system: return nil
        case .en: return ["en"]
        case .ru: return ["ru"]
        case .de: return ["de"]
        case .fr: return ["fr"]
        case .es: return ["es"]
        case .az: return ["az"]
        case .ja: return ["ja"]
        case .zh: return ["zh-Hans"]
        }
    }
}
