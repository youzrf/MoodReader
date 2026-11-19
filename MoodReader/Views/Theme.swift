import SwiftUI
import UIKit

// MARK: - Palette

enum Palette {
    static let paper = Color(hex: 0xF7F1E5)
    static let paperDeep = Color(hex: 0xEFE5D3)
    static let card = Color(hex: 0xFBF7EF)
    static let ink = Color(hex: 0x2B2722)
    static let inkSoft = Color(hex: 0x756B5D)
    static let inkFaint = Color(hex: 0xA79C8B)
    static let accent = Color(hex: 0xB85C3E)
    static let accentSoft = Color(hex: 0xE9C6B6)
    static let sage = Color(hex: 0x70806A)
    static let gold = Color(hex: 0xD3A24A)
    static let line = Color(hex: 0xDED2BE)
    static let highlight = Color(hex: 0xF1D9A7)
}

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        let r = Double((hex >> 16) & 0xFF) / 255
        let g = Double((hex >> 8) & 0xFF) / 255
        let b = Double(hex & 0xFF) / 255
        self.init(.sRGB, red: r, green: g, blue: b, opacity: opacity)
    }
}

extension UIColor {
    convenience init(hex: UInt32, alpha: CGFloat = 1) {
        let r = CGFloat((hex >> 16) & 0xFF) / 255
        let g = CGFloat((hex >> 8) & 0xFF) / 255
        let b = CGFloat(hex & 0xFF) / 255
        self.init(red: r, green: g, blue: b, alpha: alpha)
    }
}

// MARK: - Type

enum AppFont {
    static func serif(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .custom("Songti SC", size: size).weight(weight)
    }

    static func rounded(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }
}

extension UIFont {
    static func readerFont(size: CGFloat) -> UIFont {
        if let font = UIFont(name: "SongtiSC-Regular", size: size) {
            return font
        }
        let base = UIFont.systemFont(ofSize: size)
        if let descriptor = base.fontDescriptor.withDesign(.serif) {
            return UIFont(descriptor: descriptor, size: size)
        }
        return base
    }
}

// MARK: - Background

struct PaperBackground: View {
    var body: some View {
        ZStack {
            Palette.paper
            RadialGradient(
                colors: [Color.white.opacity(0.65), Color.clear],
                center: .topLeading,
                startRadius: 10,
                endRadius: 460
            )
            RadialGradient(
                colors: [Palette.gold.opacity(0.10), Color.clear],
                center: .bottomTrailing,
                startRadius: 20,
                endRadius: 380
            )
            Circle()
                .fill(Palette.sage.opacity(0.06))
                .frame(width: 320, height: 320)
                .blur(radius: 70)
                .offset(x: -150, y: 280)
        }
        .ignoresSafeArea()
    }
}

// MARK: - Small components

struct CapsuleTag: View {
    let text: String
    var tint: Color = Palette.accent
    var filled: Bool = false

    var body: some View {
        Text(text)
            .font(AppFont.rounded(11, weight: .medium))
            .foregroundStyle(filled ? Color.white : tint)
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(filled ? tint : tint.opacity(0.10))
            )
            .overlay(
                Capsule()
                    .stroke(tint.opacity(filled ? 0 : 0.22), lineWidth: 0.7)
            )
    }
}

struct SoftDivider: View {
    var body: some View {
        Rectangle()
            .fill(Palette.line.opacity(0.6))
            .frame(height: 0.7)
    }
}

struct PressableButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .opacity(configuration.isPressed ? 0.82 : 1)
            .animation(.spring(response: 0.28, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

struct ToastView: View {
    let text: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 13, weight: .semibold))
            Text(text)
                .font(AppFont.rounded(13, weight: .medium))
        }
        .foregroundStyle(Color.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            Capsule().fill(Palette.ink.opacity(0.88))
        )
        .shadow(color: Color.black.opacity(0.15), radius: 12, y: 6)
    }
}

struct ToastModifier: ViewModifier {
    @Binding var message: String?

    func body(content: Content) -> some View {
        content.overlay(alignment: .bottom) {
            if let message {
                ToastView(text: message)
                    .padding(.bottom, 170)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .task(id: message) {
                        try? await Task.sleep(nanoseconds: 1_600_000_000)
                        guard !Task.isCancelled else { return }
                        withAnimation(.easeOut(duration: 0.2)) {
                            self.message = nil
                        }
                    }
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: message)
    }
}

extension View {
    func toast(_ message: Binding<String?>) -> some View {
        modifier(ToastModifier(message: message))
    }
}
