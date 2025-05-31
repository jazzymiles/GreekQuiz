// RulesView.swift
import SwiftUI
import WebKit

struct RulesView: UIViewRepresentable {
    let htmlFileName: String
    @Environment(\.dismiss) var dismiss // NEW: Add environment dismiss

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        if let url = Bundle.main.url(forResource: htmlFileName, withExtension: "html") {
            let request = URLRequest(url: url)
            uiView.load(request)
        } else {
            print("Error: Could not find \(htmlFileName).html in bundle.")
        }
    }

    // NEW: Add a coordinator to handle button actions (optional, but good practice for UIViewRepresentable)
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject {
        var parent: RulesView

        init(_ parent: RulesView) {
            self.parent = parent
        }
    }
}

// NEW: Wrapper struct to add the dismiss button
struct RulesSheetView: View {
    let htmlFileName: String
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView { // Use NavigationView for the title and toolbar
            RulesView(htmlFileName: htmlFileName)
                .navigationTitle("Правила") // Set a title for the sheet
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Закрыть") {
                            dismiss() // Dismiss the sheet
                        }
                    }
                }
        }
    }
}
