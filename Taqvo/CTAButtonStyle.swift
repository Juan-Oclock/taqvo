import SwiftUI

struct TaqvoCTAButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(.taqvoTextLight) // #111111
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.taqvoCTA.opacity(configuration.isPressed ? 0.85 : 1.0)) // #A8FF60
            .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}