import SwiftUI
import WebKit

struct RulesView: UIViewRepresentable {
    let htmlFileURL: String
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
        } else if let url = URL(string: htmlFileURL) {
            uiView.load(URLRequest(url: url))
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
    let htmlFileURL: String
    @Environment(\.dismiss) var dismiss
    @Environment(\.locale) private var locale

    @State private var localHtmlURL: URL?
    @State private var isLoadingUpdate = false
    @State private var updateMessage: String? = nil

    private var documentsDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    }
    
    private var localFileName: String {
        // Create a unique local filename from the URL
        return URL(string: htmlFileURL)?.lastPathComponent ?? "rules.html"
    }

    var body: some View {
        NavigationView {
            RulesView(htmlFileURL: htmlFileURL, localHtmlURL: $localHtmlURL)
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
        let fileURL = documentsDirectory.appendingPathComponent(localFileName)
        if FileManager.default.fileExists(atPath: fileURL.path) {
            localHtmlURL = fileURL
        } else {
            localHtmlURL = nil
        }
    }

    private func downloadAndSaveHtmlFile() async {
        isLoadingUpdate = true
        updateMessage = nil
        let remoteURLString = htmlFileURL
        let localFileURL = documentsDirectory.appendingPathComponent(localFileName)

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
            let (data, _) = try await URLSession.shared.data(from: url)
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
