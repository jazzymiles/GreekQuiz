import SwiftUI
import WebKit

struct RulesView: UIViewRepresentable {
    let htmlFileName: String
    @Binding var localHtmlURL: URL?
    @Environment(\.dismiss) var dismiss

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.navigationDelegate = context.coordinator
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        if let localURL = localHtmlURL {
            uiView.loadFileURL(localURL, allowingReadAccessTo: localURL.deletingLastPathComponent())
            print("Загрузка HTML из локального URL: \(localURL.lastPathComponent)")
        } else {
   
            let languageCode = context.environment.locale.identifier
            
               if let url = Bundle.main.url(forResource: htmlFileName, withExtension: "html", subdirectory: nil, localization: languageCode) {
                let request = URLRequest(url: url)
                uiView.load(request)
                print("Загрузка HTML из бандла для языка '\(languageCode)': \(htmlFileName).html")
            } else {

                if let url = Bundle.main.url(forResource: htmlFileName, withExtension: "html") {
                    let request = URLRequest(url: url)
                    uiView.load(request)
                    print("Загрузка HTML из бандла (запасной вариант): \(htmlFileName).html")
                } else {
                    print("Error: Could not find \(htmlFileName).html in bundle or local URL is nil.")
                }
            }
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

        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            if navigationAction.navigationType == .linkActivated {
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

struct RulesSheetView: View {
    let htmlFileName: String
    @Environment(\.dismiss) var dismiss
    @Environment(\.locale) private var locale
    
    @State private var localHtmlURL: URL?
    @State private var isLoadingUpdate = false
    @State private var updateMessage: String? = nil
    
    private var documentsDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    }
    
    var body: some View {
        NavigationView {
            RulesView(htmlFileName: htmlFileName, localHtmlURL: $localHtmlURL)
                .navigationTitle("rules_view_title")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("button_refresh") {
                            Task {
                                await downloadAndSaveHtmlFile()
                            }
                        }
                        .disabled(isLoadingUpdate)
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("button_close") {
                            dismiss()
                        }
                    }
                }
                .overlay(
                    Group {
                        if isLoadingUpdate {
                            ProgressView("download_status_1")
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
                                .transition(.opacity)
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
                .onAppear(perform: loadLocalHtmlFile)
        }
    }
    
    private func loadLocalHtmlFile() {
        let fileNameWithoutExtension = (htmlFileName as NSString).deletingPathExtension
        let fileURL = documentsDirectory.appendingPathComponent("\(fileNameWithoutExtension).html")
        if FileManager.default.fileExists(atPath: fileURL.path) {
            localHtmlURL = fileURL
            print("Локальный файл правил найден: \(fileURL.lastPathComponent)")
        } else {
            localHtmlURL = nil
            print("Локальный файл правил не найден. Будет использоваться файл из бандла.")
        }
    }
    
    private func downloadAndSaveHtmlFile() async {
            isLoadingUpdate = true
            updateMessage = nil
            let remoteURLString = "https://redinger.cc/greekquiz/\(htmlFileName).html"
            let localFileURL = documentsDirectory.appendingPathComponent("\(htmlFileName).html")

            func localizedString(forKey key: String, default value: String) -> String {
                guard let path = Bundle.main.path(forResource: locale.identifier, ofType: "lproj"),
                      let bundle = Bundle(path: path) else {
                    return value
                }
                return NSLocalizedString(key, bundle: bundle, comment: "")
            }

            guard let url = URL(string: remoteURLString) else {
                await MainActor.run {
                    self.isLoadingUpdate = false
                    self.updateMessage = localizedString(forKey: "error_incorrect_download_url", default: "Invalid URL")
                }
                return
            }

            do {
                let (data, response) = try await URLSession.shared.data(from: url)
                guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                    let errorText = "Download error: HTTP \(String(describing: (response as? HTTPURLResponse)?.statusCode))."
                    await MainActor.run {
                        self.isLoadingUpdate = false
                        self.updateMessage = String(format: localizedString(forKey: "update_error_message", default: "Update error: %@."), errorText)
                    }
                    return
                }

                try data.write(to: localFileURL, options: .atomicWrite)

                await MainActor.run {
                    self.localHtmlURL = localFileURL
                    self.isLoadingUpdate = false
                    self.updateMessage = localizedString(forKey: "rules_updated_message", default: "Rules updated!")
                }
            } catch {
                await MainActor.run {
                    self.isLoadingUpdate = false
                    self.updateMessage = String(format: localizedString(forKey: "update_error_message", default: "Update error: %@."), error.localizedDescription)
                }
            }
        }
    }
