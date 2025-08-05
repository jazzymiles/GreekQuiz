import Foundation
import SwiftUI

// Модель для одного слова
struct Word: Codable, Equatable, Identifiable {
    let id = UUID()
    let ru: String
    let el: String
    let en: String?
    let transcription: String
    
    // Опциональные поля, которые не вызовут сбоя при отсутствии
    let el_transcription_en: String?
    let category: String?
    let gender: String?
    
    // Новые опциональные поля для примеров
    let ru_example: String?
    let en_example: String?
    let el_example: String?
    
    var dictionaryName: String?
}

// Режимы квиза
enum QuizMode: String, CaseIterable, Identifiable {
    case keyboard
    case quiz
    case cards
    case talkShow

    var id: String { self.rawValue }

    var displayName: LocalizedStringKey {
        switch self {
        case .keyboard: return "mode_keyboard_display_name"
        case .quiz: return "mode_quiz_display_name"
        case .cards: return "mode_cards_display_name"
        case .talkShow: return "mode_talkshow_display_name"
        }
    }
}

// Модель для информации о словаре
struct DictionaryInfo: Codable, Identifiable, Hashable {
    let id = UUID()
    let name_ru: String
    let name_en: String
    let name_el: String
    var filePath: String

    func localizedName(for language: String) -> String {
        switch language {
        case "ru":
            return name_ru
        case "el":
            return name_el
        default:
            return name_en
        }
    }
}

// Источники для загрузки словарей
enum DictionarySource: String, CaseIterable, Identifiable, Codable {
    case standard
    case customURL

    var id: String { self.rawValue }

    var displayName: LocalizedStringKey {
        switch self {
        case .standard: return "dictionary_download_option_1"
        case .customURL: return "dictionary_download_option_2"
        }
    }
}
