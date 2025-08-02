import Foundation
import SwiftUI

@MainActor
class DictionaryService: ObservableObject {
    @Published var allDictionaries: [DictionaryInfo] = []
    @Published var allWords: [Word] = []
    @Published var activeWords: [Word] = []
    @Published var selectedDictionaries: Set<String> = []
    
    // ✨ ИЗМЕНЕНИЕ: Старые и новые свойства для отслеживания статуса
    @Published var isDownloading: Bool = false
    @Published var statusMessage: String = "" // Для общих сообщений (успех, ошибка)

    // ✨ НОВЫЕ СВОЙСТВА для детального прогресса скачивания
    @Published var downloadProgressValue: Double = 0.0
    @Published var downloadStatusText: String = ""
    @Published var currentDictionaryName: String = ""
    @Published var downloadCounterText: String = ""
    

    private var downloadedDictionariesDirectory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("DownloadedDictionaries")
    }
    
    init() {
        if let savedSelection = UserDefaults.standard.stringArray(forKey: "selectedDictionaries") {
            self.selectedDictionaries = Set(savedSelection)
            print("Загружен сохраненный выбор: \(savedSelection.count) словарей.")
        }
        loadDictionariesMetadata()
    }

    func loadDictionariesMetadata() {
        guard let metadataData = UserDefaults.standard.data(forKey: "downloadedDictionaryMetadata"),
              let decodedMetadata = try? JSONDecoder().decode([DictionaryInfo].self, from: metadataData) else {
            print("Нет сохраненных метаданных для словарей.")
            return
        }
        self.allDictionaries = decodedMetadata
        print("Загружены метаданные сохраненных словарей.")
        
        let initialLanguage = UserDefaults.standard.string(forKey: "interfaceLanguage") ?? "en"
        self.loadSelectedWords(interfaceLanguage: initialLanguage)
    }

    func loadSelectedWords(interfaceLanguage: String) {
        guard FileManager.default.fileExists(atPath: downloadedDictionariesDirectory.path) else {
            self.allWords = []
            self.activeWords = []
            return
        }

        var tempAllWords: [Word] = []
        var tempActiveWords: [Word] = []

        for dictInfo in allDictionaries {
            let filePath = downloadedDictionariesDirectory.appendingPathComponent(dictInfo.filePath)
            guard FileManager.default.fileExists(atPath: filePath.path),
                  let data = try? Data(contentsOf: filePath),
                  var decodedWords = try? JSONDecoder().decode([Word].self, from: data) else {
                continue
            }
            
            let localizedDictName = dictInfo.localizedName(for: interfaceLanguage)
            for i in 0..<decodedWords.count {
                decodedWords[i].dictionaryName = localizedDictName
            }

            tempAllWords.append(contentsOf: decodedWords)

            if self.selectedDictionaries.contains(dictInfo.filePath) {
                tempActiveWords.append(contentsOf: decodedWords)
            }
        }
        
        self.allWords = tempAllWords
        self.activeWords = tempActiveWords.shuffled()
        
        UserDefaults.standard.set(Array(self.selectedDictionaries), forKey: "selectedDictionaries")
        
        print("Актуализированы слова. Активных слов: \(self.activeWords.count). Выбор сохранен.")
    }

    func downloadAndSaveDictionaries(source: DictionarySource, customURL: String, interfaceLanguage: String) async {
        // ✨ ИЗМЕНЕНИЕ: Подготовка к скачиванию
        isDownloading = true
        statusMessage = "" // Очищаем старые сообщения
        downloadProgressValue = 0.0
        currentDictionaryName = ""
        downloadStatusText = NSLocalizedString("clearing_old_dictionaries", comment: "")
        downloadCounterText = ""
        
        await clearDownloadedDictionaries()

        let urlString: String
        if source == .standard {
            urlString = "https://www.dropbox.com/scl/fi/z9avztiil4v150g0h58i8/dictionaries.txt?rlkey=k5mrqfwgdgwz2wt8q1wu3ernj&st=peuf016l&raw=1"
        } else {
            guard !customURL.isEmpty else {
                statusMessage = NSLocalizedString("error_incorrect_download_url", comment: "")
                isDownloading = false
                return
            }
            urlString = customURL.hasSuffix("raw=1") ? customURL : "\(customURL)&raw=1"
        }

        guard let url = URL(string: urlString) else {
            statusMessage = NSLocalizedString("error_invalid_dictionaries_list_url", comment: "")
            isDownloading = false
            return
        }

        do {
            downloadStatusText = NSLocalizedString("downloading_dictionaries_list", comment: "")
            let (data, _) = try await URLSession.shared.data(from: url)
            let remoteDictsInfo = try JSONDecoder().decode([DictionaryInfo].self, from: data)
            
            try FileManager.default.createDirectory(at: downloadedDictionariesDirectory, withIntermediateDirectories: true)
            
            var downloadedMetadata: [DictionaryInfo] = []
            
            // ✨ ИЗМЕНЕНИЕ: Обновляем статус в цикле скачивания
            let total = remoteDictsInfo.count
            downloadStatusText = NSLocalizedString("download_status_text", comment: "") // "Скачивается словарь:"
            
            for (index, var dictInfo) in remoteDictsInfo.enumerated() {
                let current = index + 1
                downloadCounterText = "\(current)/\(total)"
                currentDictionaryName = dictInfo.localizedName(for: interfaceLanguage)
                
                let dictURLString = dictInfo.filePath.contains("dropbox.com") && !dictInfo.filePath.hasSuffix("raw=1") ? "\(dictInfo.filePath)&raw=1" : dictInfo.filePath
                guard let dictURL = URL(string: dictURLString) else { continue }
                
                let (dictData, _) = try await URLSession.shared.data(from: dictURL)
                let localFileName = UUID().uuidString + ".txt"
                let localFileURL = downloadedDictionariesDirectory.appendingPathComponent(localFileName)
                try dictData.write(to: localFileURL)
                
                dictInfo.filePath = localFileName
                downloadedMetadata.append(dictInfo)
                
                downloadProgressValue = Double(current) / Double(total)
            }
            
            let encodedMetadata = try JSONEncoder().encode(downloadedMetadata)
            UserDefaults.standard.set(encodedMetadata, forKey: "downloadedDictionaryMetadata")
            
            self.allDictionaries = downloadedMetadata
            self.selectedDictionaries = []
            loadSelectedWords(interfaceLanguage: interfaceLanguage)
            
            statusMessage = NSLocalizedString("all_dictionaries_updated", comment: "")
            
        } catch {
            statusMessage = String(format: NSLocalizedString("error_downloading_dictionaries", comment: ""), error.localizedDescription)
        }
        
        isDownloading = false
    }

    private func clearDownloadedDictionaries() async {
        try? FileManager.default.removeItem(at: downloadedDictionariesDirectory)
        UserDefaults.standard.removeObject(forKey: "downloadedDictionaryMetadata")
        UserDefaults.standard.removeObject(forKey: "selectedDictionaries")
        self.allDictionaries = []
        self.selectedDictionaries = []
        self.allWords = []
        self.activeWords = []
    }
}
