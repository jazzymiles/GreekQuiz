//
//  HelpView.swift
//  GreekQuiz
//
//  Created by miles on 05/08/2025.
//


import SwiftUI
import WebKit


struct HelpView: UIViewRepresentable {
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
        } else if let url = Bundle.main.url(forResource: htmlFileName, withExtension: "html") {
            uiView.load(URLRequest(url: url))
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, WKNavigationDelegate {
        var parent: HelpView

        init(_ parent: HelpView) {
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


struct HelpSheetView: View {
    let htmlFileName: String
    @Environment(\.dismiss) var dismiss

    @State private var localHtmlURL: URL?
    @State private var isLoadingUpdate = false
    @State private var updateMessage: String? = nil

    private var documentsDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    }

    var body: some View {
        NavigationView {
            HelpView(htmlFileName: htmlFileName, localHtmlURL: $localHtmlURL)
                .navigationTitle("help_view_title")
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
        let fileURL = documentsDirectory.appendingPathComponent("\(htmlFileName).html")
        if FileManager.default.fileExists(atPath: fileURL.path) {
            localHtmlURL = fileURL
        } else {
            localHtmlURL = nil
        }
    }

    private func downloadAndSaveHtmlFile() async {
        isLoadingUpdate = true
        updateMessage = nil
        let remoteURLString = "https://redinger.cc/greekquiz/\(htmlFileName).html"
        let localFileURL = documentsDirectory.appendingPathComponent("\(htmlFileName).html")

        guard let url = URL(string: remoteURLString) else {
            //
            return
        }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            try data.write(to: localFileURL, options: .atomicWrite)
            
            await MainActor.run {
                self.localHtmlURL = localFileURL
                self.isLoadingUpdate = false
                self.updateMessage = "Помощь обновлена!"
            }

        } catch {
            //
        }
    }
}
