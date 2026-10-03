import SwiftUI

extension Color {
    init(hex: UInt, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }
}

enum Theme {

    static let canvas = Color(hex: 0x11121A)
    static let canvasSunken = Color(hex: 0x0c0d17)
    static let canvasDeep = Color(hex: 0x101220)
    static let canvasVoid = Color(hex: 0x050608)
    static let surface = Color(hex: 0x1D1F2B)
    static let surfaceTint = Color(hex: 0x29253E)

    static let neutral100 = Color(hex: 0xf3f5fe)
    static let neutral200 = Color(hex: 0xe4e7f5)
    static let neutral300 = Color(hex: 0xcfd3e5)
    static let neutral400 = Color(hex: 0xb2b6ca)
    static let neutral500 = Color(hex: 0x9397ab)
    static let neutral600 = Color(hex: 0x75798c)
    static let neutral700 = Color(hex: 0x595d6c)
    static let neutral800 = Color(hex: 0x3f424d)
    static let neutral900 = Color(hex: 0x292b31)

    fileprivate struct AccentPalette {
        let c100, c200, c300, c400, c500, c600, c700, c800, c900: UInt
    }

    private static let accentPalettes: [String: AccentPalette] = [
        "Pine Trail": AccentPalette(
            c100: 0xf5f4ff, c200: 0xe7e5fe, c300: 0xd2cefd, c400: 0xb5abfc,
            c500: 0x968ae0, c600: 0x796cbf, c700: 0x5d5294, c800: 0x423a6a, c900: 0x29253E
        ),
        "Sunrise": AccentPalette(
            c100: 0xfff6ed, c200: 0xffe6c9, c300: 0xffcf98, c400: 0xffab5e,
            c500: 0xe98a3a, c600: 0xbf6a27, c700: 0x94501e, c800: 0x6a3816, c900: 0x3e2410
        ),
        "Tidepool": AccentPalette(
            c100: 0xecfbff, c200: 0xc9f1fd, c300: 0x97e2f7, c400: 0x5cc9e6,
            c500: 0x3aa4c2, c600: 0x2a7f96, c700: 0x1f5f70, c800: 0x16414c, c900: 0x0f2a30
        ),
        "Nightwalk": AccentPalette(
            c100: 0xf1eefe, c200: 0xdcd4fc, c300: 0xb7a4f8, c400: 0x9270f0,
            c500: 0x714fd1, c600: 0x5539a8, c700: 0x40297f, c800: 0x2c1c58, c900: 0x1a1032
        ),
    ]

    private static var currentThemeName = "Pine Trail"

    private static var palette: AccentPalette {
        accentPalettes[currentThemeName] ?? accentPalettes["Pine Trail"]!
    }

    static func apply(themeName: String) {
        currentThemeName = themeName
    }

    static var accent100: Color { Color(hex: palette.c100) }
    static var accent200: Color { Color(hex: palette.c200) }
    static var accent300: Color { Color(hex: palette.c300) }
    static var accent400: Color { Color(hex: palette.c400) }
    static var accent500: Color { Color(hex: palette.c500) }
    static var accent600: Color { Color(hex: palette.c600) }
    static var accent700: Color { Color(hex: palette.c700) }
    static var accent800: Color { Color(hex: palette.c800) }
    static var accent900: Color { Color(hex: palette.c900) }
    static var accent: Color { accent400 }

    static let text = Color(hex: 0xe9e9ed)
    static let textMuted = neutral400
    static let textFaint = Color(hex: 0xA0A4B8)
    static let heading = text

    static let hairline = Color.white.opacity(0.09)
    static let divider = text.opacity(0.08)

    static var markGradient: LinearGradient {
        LinearGradient(
            colors: [accent900, Color(hex: 0x1a1826)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static let sectionGradient = LinearGradient(
        colors: [Color(hex: 0x262a60), Color(hex: 0x1b1d3a)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    static let sectionGlow = Color(hex: 0x4c5397)

    static let lockGround = canvasDeep

    static func display(_ size: CGFloat, _ weight: Font.Weight = .medium) -> Font {
        .custom(weight == .semibold || weight == .bold ? "Poppins-SemiBold" : "Poppins-Medium",
                size: size, relativeTo: size >= 28 ? .largeTitle : .title2)
    }

    static func body(_ size: CGFloat = 15, _ weight: Font.Weight = .regular) -> Font {
        let style: Font.TextStyle
        switch size {
        case ...12: style = .caption
        case ...14: style = .subheadline
        case ...16: style = .callout
        default: style = .body
        }
        let family = weight == .semibold || weight == .bold ? "Poppins-SemiBold" : "Poppins-Medium"
        return .custom(family, size: size, relativeTo: style)
    }

    static func mono(_ size: CGFloat, _ weight: Font.Weight = .semibold) -> Font {
        if size <= 14 {
            return .custom(weight == .medium ? "Poppins-Medium" : "Poppins-SemiBold",
                           size: max(11, size), relativeTo: .caption).monospacedDigit()
        }
        return .custom(weight == .medium ? "Poppins-Medium" : "Poppins-SemiBold",
                       size: size, relativeTo: size >= 26 ? .title : .body).monospacedDigit()
    }

    static let microLabel = Font.custom("Poppins-SemiBold", size: 11, relativeTo: .caption)
}
