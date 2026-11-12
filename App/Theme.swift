import SwiftUI

// MARK: - Palette erase4me : encre, papier, filets fins, un seul accent (vermillon)

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  opacity: opacity)
    }
}

enum Palette {
    static let bg = Color(hex: 0x0E0E0F)
    static let surface = Color(hex: 0x151516)
    static let raise = Color(hex: 0x1C1C1E)
    static let line = Color(hex: 0xECE9E2, opacity: 0.11)
    static let line2 = Color(hex: 0xECE9E2, opacity: 0.24)
    static let text = Color(hex: 0xECE9E2)
    static let text2 = Color(hex: 0xBCB8AE)
    static let muted = Color(hex: 0x8B887F)
    static let paper = Color(hex: 0xECE9E2)
    static let ink = Color(hex: 0x121213)
    static let accent = Color(hex: 0xFF6A3D)
    static let ok = Color(hex: 0x8FBF9F)
    static let warn = Color(hex: 0xD9B45F)
    static let err = Color(hex: 0xE8695A)
}

enum Typo {
    /// Titres : serif éditorial du système (New York), comme les titres du site.
    static func title(_ size: CGFloat = 34) -> Font { .system(size: size, weight: .medium, design: .serif) }
    static func body(_ size: CGFloat = 16) -> Font { .system(size: size, weight: .regular, design: .default) }
    static func mono(_ size: CGFloat = 12) -> Font { .system(size: size, weight: .regular, design: .monospaced) }
}

// MARK: - Composants

struct Eyebrow: View {
    let text: String
    var body: some View {
        HStack(spacing: 10) {
            Rectangle().fill(Palette.accent).frame(width: 28, height: 1)
            Text(text.uppercased()).font(Typo.mono(11)).tracking(1.4).foregroundColor(Palette.muted)
        }
    }
}

struct Panel<Content: View>: View {
    let content: Content
    init(@ViewBuilder _ content: () -> Content) { self.content = content() }
    var body: some View {
        content
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Palette.surface)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Palette.line, lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct Chip: View {
    let text: String
    var color: Color = Palette.text2
    var body: some View {
        Text(text.uppercased())
            .font(Typo.mono(10)).tracking(0.8)
            .foregroundColor(color)
            .padding(.horizontal, 7).padding(.vertical, 3)
            .overlay(RoundedRectangle(cornerRadius: 3).stroke(color.opacity(0.5), lineWidth: 1))
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .semibold))
            .foregroundColor(Palette.ink)
            .padding(.vertical, 13).padding(.horizontal, 18)
            .frame(maxWidth: .infinity)
            .background(Palette.paper.opacity(configuration.isPressed ? 0.75 : 1))
            .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

struct GhostButtonStyle: ButtonStyle {
    var danger = false
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .medium))
            .foregroundColor(danger ? Palette.err : Palette.text)
            .padding(.vertical, 12).padding(.horizontal, 18)
            .frame(maxWidth: .infinity)
            .background(configuration.isPressed ? Palette.raise : Color.clear)
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(danger ? Palette.err.opacity(0.5) : Palette.line2, lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

struct FieldStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(Typo.body(17)).foregroundColor(Palette.text)
            .padding(.horizontal, 14).padding(.vertical, 12)
            .background(Palette.bg)
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Palette.line2, lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}
extension View { func fieldStyle() -> some View { modifier(FieldStyle()) } }

struct ScreenHeader: View {
    let eyebrow: String
    let title: String
    var subtitle: String? = nil
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Eyebrow(text: eyebrow)
            Text(title).font(Typo.title(34)).foregroundColor(Palette.text).fixedSize(horizontal: false, vertical: true)
            if let s = subtitle {
                Text(s).font(Typo.body(15)).foregroundColor(Palette.text2).fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

struct StatCell: View {
    let value: String
    let label: String
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(value).font(Typo.title(30)).foregroundColor(Palette.text).minimumScaleFactor(0.6).lineLimit(1)
            Text(label).font(Typo.body(12)).foregroundColor(Palette.muted).fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14).padding(.vertical, 16)
    }
}

struct Hairline: View {
    var body: some View { Rectangle().fill(Palette.line).frame(height: 1) }
}

struct InfoRow: View {
    let label: String
    let value: String
    var mono = false
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label.uppercased()).font(Typo.mono(10)).tracking(1).foregroundColor(Palette.muted)
            Text(value).font(mono ? Typo.mono(14) : Typo.body(15)).foregroundColor(Palette.text).fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Logo : feuille caviardée + sens interdit (même dessin que l'icône)

struct LogoMark: View {
    var size: CGFloat = 44
    var body: some View {
        let u = size / 100
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 22 * u).fill(Palette.bg)
            RoundedRectangle(cornerRadius: 3 * u).fill(Palette.paper)
                .frame(width: 59.8 * u, height: 73 * u).offset(x: 20 * u, y: 13.5 * u)
            Group {
                bar(u, x: 26.2, y: 21, w: 22, h: 1.6, grey: true)
                bar(u, x: 26.2, y: 26.2, w: 47.6, h: 1.2, grey: true)
                bar(u, x: 26.2, y: 38.3, w: 39, h: 4.5, grey: false)
                bar(u, x: 26.2, y: 45.5, w: 29.3, h: 4.5, grey: false)
                bar(u, x: 26.2, y: 52.7, w: 44.5, h: 4.5, grey: false)
            }
            Circle().strokeBorder(Palette.accent, lineWidth: 3 * u)
                .frame(width: 23.8 * u, height: 23.8 * u).offset(x: 53.3 * u, y: 60.6 * u)
            Capsule().fill(Palette.accent).frame(width: 3 * u, height: 22 * u)
                .rotationEffect(.degrees(-45)).offset(x: 63.8 * u, y: 61.6 * u)
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: 22 * u))
    }

    private func bar(_ u: CGFloat, x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat, grey: Bool) -> some View {
        RoundedRectangle(cornerRadius: 0.4 * u)
            .fill(grey ? Color(hex: 0xC9C5BA) : Palette.ink)
            .frame(width: w * u, height: h * u).offset(x: x * u, y: y * u)
    }
}

struct Wordmark: View {
    var size: CGFloat = 22
    var body: some View {
        (Text("erase").foregroundColor(Palette.text)
         + Text("4").foregroundColor(Palette.accent)
         + Text("me").foregroundColor(Palette.text))
            .font(.system(size: size, weight: .semibold, design: .serif))
    }
}
