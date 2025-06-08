import SwiftUI
import WebKit

struct RulesView: UIViewRepresentable {
    let htmlFileName: String
    @Binding var localHtmlURL: URL? // NEW: Привязка для URL локального файла
    @Environment(\.dismiss) var dismiss

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        // NEW: Добавляем координатор для обработки навигации (если нужно, например, для открытия внешних ссылок)
        webView.navigationDelegate = context.coordinator
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        if let localURL = localHtmlURL {
            uiView.loadFileURL(localURL, allowingReadAccessTo: localURL.deletingLastPathComponent())
            print("Загрузка HTML из локального URL: \(localURL.lastPathComponent)")
        } else if let url = Bundle.main.url(forResource: htmlFileName, withExtension: "html") {
            let request = URLRequest(url: url)
            uiView.load(request)
            print("Загрузка HTML из бандла: \(htmlFileName).html")
        } else {
            print("Error: Could not find \(htmlFileName).html in bundle or local URL is nil.")
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, WKNavigationDelegate {
        var parent: RulesView

        init(_ parent: RulesView) {
            self.parent = parent
        }

        // Пример, если нужно обрабатывать переходы по ссылкам
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            if navigationAction.navigationType == .linkActivated {
                // Если это внешняя ссылка, открыть в Safari
                if let url = navigationAction.request.url, url.host != nil && url.host != webView.url?.host {
                    UIApplication.shared.open(url)
                    decisionHandler(.cancel)
                    return
                }
            }
            decisionHandler(.allow)
        }
    }
}

// NEW: Wrapper struct to add the dismiss and update buttons
struct RulesSheetView: View {
    let htmlFileName: String
    @Environment(\.dismiss) var dismiss

    @State private var localHtmlURL: URL? // Состояние для хранения URL локального HTML-файла
    @State private var isLoadingUpdate = false
    @State private var updateMessage: String? = nil

    private var documentsDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    }

    var body: some View {
        NavigationView {
            RulesView(htmlFileName: htmlFileName, localHtmlURL: $localHtmlURL) // Передаем localHtmlURL в RulesView
                .navigationTitle("Правила")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Обновить") {
                            Task {
                                await downloadAndSaveHtmlFile()
                            }
                        }
                        .disabled(isLoadingUpdate) // Отключаем кнопку во время загрузки
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Закрыть") {
                            dismiss()
                        }
                    }
                }
                .overlay(
                    Group {
                        if isLoadingUpdate {
                            ProgressView("Загрузка...")
                                .padding()
                                .background(Color.black.opacity(0.7))
                                .cornerRadius(10)
                                .foregroundColor(.white)
                        } else if let message = updateMessage {
                            Text(message)
                                .padding()
                                .background(Color.black.opacity(0.7))
                                .cornerRadius(10)
                                .foregroundColor(.white)
                                .transition(.opacity) // Плавное появление/исчезновение
                                .onAppear {
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                        withAnimation {
                                            updateMessage = nil
                                        }
                                    }
                                }
                        }
                    }
                )
                .onAppear(perform: loadLocalHtmlFile) // Загружаем локальный файл при появлении
        }
    }

    // Загрузка локального HTML-файла при старте
    private func loadLocalHtmlFile() {
        let fileNameWithoutExtension = (htmlFileName as NSString).deletingPathExtension
        let fileURL = documentsDirectory.appendingPathComponent("\(fileNameWithoutExtension).html")
        if FileManager.default.fileExists(atPath: fileURL.path) {
            localHtmlURL = fileURL
            print("Локальный файл правил найден: \(fileURL.lastPathComponent)")
        } else {
            localHtmlURL = nil // Если локального файла нет, используем бандл
            print("Локальный файл правил не найден. Будет использоваться файл из бандла.")
        }
    }

    // Функция для скачивания и сохранения HTML-файла
    private func downloadAndSaveHtmlFile() async {
        isLoadingUpdate = true
        updateMessage = nil
        let remoteURLString = "https://redinger.cc/greekquiz/\(htmlFileName).html" // URL для скачивания
        let fileNameWithoutExtension = (htmlFileName as NSString).deletingPathExtension
        let localFileName = "\(fileNameWithoutExtension).html"
        let localFileURL = documentsDirectory.appendingPathComponent(localFileName)

        guard let url = URL(string: remoteURLString) else {
            print("Некорректный URL: \(remoteURLString)")
            await MainActor.run {
                self.isLoadingUpdate = false
                self.updateMessage = "Ошибка: Некорректный URL."
            }
            return
        }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)

            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                print("Ошибка HTTP при загрузке: Статус \(String(describing: (response as? HTTPURLResponse)?.statusCode))")
                await MainActor.run {
                    self.isLoadingUpdate = false
                    self.updateMessage = "Ошибка загрузки: \(String(describing: (response as? HTTPURLResponse)?.statusCode))."
                }
                return
            }

            try data.write(to: localFileURL, options: .atomicWrite)
            print("Файл успешно скачан и сохранен: \(localFileURL.lastPathComponent)")

            await MainActor.run {
                self.localHtmlURL = localFileURL // Обновляем URL для WKWebView
                self.isLoadingUpdate = false
                self.updateMessage = "Правила обновлены!"
            }

        } catch {
            print("Ошибка при скачивании или сохранении файла: \(error.localizedDescription)")
            await MainActor.run {
                self.isLoadingUpdate = false
                self.updateMessage = "Ошибка обновления: \(error.localizedDescription)."
            }
        }
    }
}
