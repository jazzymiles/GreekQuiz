import SwiftUI

struct NavButton: View {
    let systemName: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.largeTitle).foregroundColor(.blue)
                //.background(Color.white.opacity(0.1)).cornerRadius(8)
        }
    }
}
