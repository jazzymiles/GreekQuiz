//
//  FeedbackText.swift
//  GreekQuiz
//
//  Created by miles on 05/08/2025.
//


import SwiftUI

struct FeedbackText: View {
    let key: LocalizedStringKey
    let word: String
    let isVisible: Bool

    @Environment(\.colorScheme) private var colorScheme
    private var textColor: Color { colorScheme == .dark ? .white : .black }

    var body: some View {
        (isVisible ? (Text(key) + Text(" \(word)")) : Text(" "))
            .foregroundColor(isVisible ? textColor : .clear)
            .padding(.vertical, 5).padding(.horizontal)
            .frame(maxWidth: .infinity, alignment: .center)
            .frame(height: 15)
            .font(.system(size: 24))
    }
}
