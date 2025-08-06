import SwiftUI

struct HeaderButton: View {
    let imageName: String
    let action: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    private var iconTintColor: Color {
        colorScheme == .dark ? .white : .black
    }

    var body: some View {
        Button(action: action) {
            Image(systemName: imageName)
                .resizable()
                .scaledToFit()
                .frame(width: 24, height: 24)
                .padding(6)
                .foregroundColor(iconTintColor)
                .background(Color.gray.opacity(0.2))
                .cornerRadius(8)
                .fontWeight(.light)
        }
        .buttonStyle(PlainButtonStyle())
    }
}
