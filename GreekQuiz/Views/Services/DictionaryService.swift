import Foundation
import SwiftUI

@MainActor
class DictionaryService: ObservableObject {
    @Published var allDictionaries: [DictionaryInfo] = []
    @Published var allWords: [Word] = []
    @Published var activeWords: [Word] = []
    @Published var selectedDictionaries: Set<String> = []
    
    @Published var ruleInfos: [RuleInfo] = []
    
    @Published var isDownloading: Bool = false
    @Published var downloadProgressValue: Double = 0.0
    @Published var downloadStatusText: String = ""
    @Published var currentDictionaryName: String = ""
    @Published var downloadCounterText: String = ""
    @Published var statusMessage: String = ""

    private var downloadedDictionariesDirectory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("DownloadedDictionaries")
    }
    
    init() {
        if let savedSelection = UserDefaults.standard.stringArray(forKey: "selectedDictionaries") {
            self.selectedDictionaries = Set(savedSelection)
        }
        loadDictionariesMetadata()
    }

    func loadDictionariesMetadata() {
        guard let metadataData = UserDefaults.standard.data(forKey: "downloadedDictionaryMetadata"),
              let decodedMetadata = try? JSONDecoder().decode([DictionaryInfo].self, from: metadataData) else {
            return
        }
        self.allDictionaries = decodedMetadata
        
        if let rulesData = UserDefaults.standard.data(forKey: "ruleInfos"),
           let decodedRules = try? JSONDecoder().decode([RuleInfo].self, from: rulesData) {
            self.ruleInfos = decodedRules
        }
        
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
            let localFileName = dictInfo.file
            let filePath = downloadedDictionariesDirectory.appendingPathComponent(localFileName)
            
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

            if selectedDictionaries.contains(dictInfo.file) {
                tempActiveWords.append(contentsOf: decodedWords)
            }
        }
        
        self.allWords = tempAllWords
        self.activeWords = tempActiveWords.shuffled()
        
        UserDefaults.standard.set(Array(self.selectedDictionaries), forKey: "selectedDictionaries")
    }

    func downloadAndSaveDictionaries(source: DictionarySource, customURL: String, interfaceLanguage: String) async {
        isDownloading = true
        statusMessage = ""
        downloadProgressValue = 0.0
        currentDictionaryName = ""
        downloadCounterText = ""
        downloadStatusText = NSLocalizedString("clearing_old_dictionaries", comment: "")
        
        await clearDownloadedDictionaries()

        let urlString: String
        if source == .standard {
            urlString = "https://redinger.cc/greekquiz/settings.txt"
        } else {
            guard !customURL.isEmpty else {
                statusMessage = NSLocalizedString("error_incorrect_download_url", comment: "")
                isDownloading = false
                return
            }
            urlString = customURL
        }

        guard let url = URL(string: urlString) else {
            statusMessage = NSLocalizedString("error_invalid_dictionaries_list_url", comment: "")
            isDownloading = false
            return
        }

        do {
            downloadStatusText = NSLocalizedString("downloading_dictionaries_list", comment: "")
            let (data, _) = try await URLSession.shared.data(from: url)
            
            // ✨ ИЗМЕНЕНИЕ: Добавлена детальная обработка ошибок парсинга
            let appSettings: AppSettings
            do {
                appSettings = try JSONDecoder().decode(AppSettings.self, from: data)
            } catch {
                // Если парсинг не удался, выводим подробную информацию
                print("--- ОШИБКА ПАРСИНГА JSON ---")
                print("Ошибка: \(error)")
                if let jsonString = String(data: data, encoding: .utf8) {
                    print("Полученные данные:\n\(jsonString)")
                } else {
                    print("Не удалось преобразовать полученные данные в строку.")
                }
                print("--------------------------")
                // Выбрасываем ошибку дальше, чтобы ее поймал внешний catch
                throw error
            }

            let remoteDictsInfo = appSettings.dictionaries
            self.ruleInfos = appSettings.settings.rules
            
            let encodedRules = try JSONEncoder().encode(self.ruleInfos)
            UserDefaults.standard.set(encodedRules, forKey: "ruleInfos")
            
            try FileManager.default.createDirectory(at: downloadedDictionariesDirectory, withIntermediateDirectories: true)
            
            var downloadedMetadata: [DictionaryInfo] = []
            let total = remoteDictsInfo.count
            downloadStatusText = NSLocalizedString("download_status_text", comment: "")
            
            for (index, var dictInfo) in remoteDictsInfo.enumerated() {
                let current = index + 1
                downloadCounterText = "\(current)/\(total)"
                currentDictionaryName = dictInfo.localizedName(for: interfaceLanguage)
                
                let dictURLString = dictInfo.filePath.contains("dropbox.com") && !dictInfo.filePath.hasSuffix("raw=1") ? "\(dictInfo.filePath)&raw=1" : dictInfo.filePath
                guard let dictURL = URL(string: dictURLString) else { continue }
                
                let (dictData, _) = try await URLSession.shared.data(from: dictURL)
                let localFileName = dictInfo.file
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
            statusMessage = "Ошибка: " + error.localizedDescription
        }
        
        isDownloading = false
    }

    private func clearDownloadedDictionaries() async {
        try? FileManager.default.removeItem(at: downloadedDictionariesDirectory)
        UserDefaults.standard.removeObject(forKey: "downloadedDictionaryMetadata")
        UserDefaults.standard.removeObject(forKey: "selectedDictionaries")
        UserDefaults.standard.removeObject(forKey: "ruleInfos")
        self.allDictionaries = []
        self.selectedDictionaries = []
        self.allWords = []
        self.activeWords = []
        self.ruleInfos = []
    }
}
