import SwiftUI
import UIKit

// MARK: - Colors
// All colors adapt to light / dark mode automatically.
// Dark mode is the canonical Samajh experience; light reads like warm paper.

extension Color {

    // MARK: Backgrounds

    /// True black in dark mode; warm parchment (#F7F3EC) in light.
    static let samajhBackground = Color(UIColor { t in
        t.userInterfaceStyle == .dark
            ? UIColor(red: 0.000, green: 0.000, blue: 0.000, alpha: 1) // #000000
            : UIColor(red: 0.969, green: 0.953, blue: 0.925, alpha: 1) // #F7F3EC
    })

    static let samajhBackgroundSecondary = Color(UIColor { t in
        t.userInterfaceStyle == .dark
            ? UIColor(red: 0.055, green: 0.055, blue: 0.067, alpha: 1) // #0E0E11
            : UIColor(red: 0.949, green: 0.933, blue: 0.906, alpha: 1) // #F2EEE7
    })

    static let samajhSurfaceElevated = Color(UIColor { t in
        t.userInterfaceStyle == .dark
            ? UIColor(red: 0.082, green: 0.082, blue: 0.094, alpha: 1) // #151518
            : UIColor(red: 0.929, green: 0.914, blue: 0.886, alpha: 1) // #EDEAD2
    })

    static let samajhSurfaceCard = Color(UIColor { t in
        t.userInterfaceStyle == .dark
            ? UIColor(red: 0.106, green: 0.106, blue: 0.125, alpha: 1) // #1B1B20
            : UIColor(red: 1.000, green: 1.000, blue: 1.000, alpha: 1) // #FFFFFF
    })

    // MARK: Accent gold — use sparingly

    /// Primary accent: #D6A05F dark / #B88952 light.
    static let samajhGold = Color(UIColor { t in
        t.userInterfaceStyle == .dark
            ? UIColor(red: 0.839, green: 0.627, blue: 0.373, alpha: 1) // #D6A05F
            : UIColor(red: 0.722, green: 0.537, blue: 0.322, alpha: 1) // #B88952
    })

    static let samajhGoldMuted = Color(UIColor { t in
        t.userInterfaceStyle == .dark
            ? UIColor(red: 0.722, green: 0.537, blue: 0.322, alpha: 1) // #B88952
            : UIColor(red: 0.627, green: 0.459, blue: 0.263, alpha: 1) // #A07543
    })

    static let samajhGoldPressed = Color(UIColor { t in
        t.userInterfaceStyle == .dark
            ? UIColor(red: 0.890, green: 0.694, blue: 0.427, alpha: 1) // #E3B16D
            : UIColor(red: 0.784, green: 0.600, blue: 0.376, alpha: 1) // #C89960
    })

    // MARK: Text

    static let samajhTextPrimary = Color(UIColor { t in
        t.userInterfaceStyle == .dark
            ? UIColor(red: 0.961, green: 0.949, blue: 0.922, alpha: 1) // #F5F2EB
            : UIColor(red: 0.169, green: 0.169, blue: 0.169, alpha: 1) // #2B2B2B
    })

    static let samajhTextSecondary = Color(UIColor { t in
        t.userInterfaceStyle == .dark
            ? UIColor(red: 0.722, green: 0.694, blue: 0.655, alpha: 1) // #B8B1A7
            : UIColor(red: 0.353, green: 0.341, blue: 0.322, alpha: 1) // #5A5752
    })

    /// #7E7A73 in both modes — sits mid-contrast on either background.
    static let samajhTextMuted = Color(red: 0.494, green: 0.478, blue: 0.451) // #7E7A73

    static let samajhTextDisabled = Color(UIColor { t in
        t.userInterfaceStyle == .dark
            ? UIColor(red: 0.353, green: 0.341, blue: 0.322, alpha: 1) // #5A5752
            : UIColor(red: 0.627, green: 0.612, blue: 0.596, alpha: 1) // #A09C98
    })

    /// Romanization text — slightly warmer than secondary.
    static let samajhTextRoman = Color(UIColor { t in
        t.userInterfaceStyle == .dark
            ? UIColor(red: 0.784, green: 0.757, blue: 0.718, alpha: 1) // #C8C1B7
            : UIColor(red: 0.420, green: 0.408, blue: 0.392, alpha: 1) // #6B6863
    })
}

// MARK: - Typography

enum SamajhFont {
    static let interRegular    = "Inter_18pt-Regular"
    static let interMedium     = "Inter_18pt-Medium"
    static let interSemiBold   = "Inter_18pt-SemiBold"
    static let interBold       = "Inter_18pt-Bold"

    // Cormorant Garamond — cinematic/literary moments only
    static let cormorantRegular  = "CormorantGaramond-Regular"
    static let cormorantMedium   = "CormorantGaramond-Medium"
    static let cormorantSemiBold = "CormorantGaramond-SemiBold"
    static let cormorantItalic   = "CormorantGaramond-Italic"

    // Native script fonts
    static let notoDevanagari = "NotoSerifDevanagari-Regular"
    static let notoNastaliq   = "NotoNastaliqUrdu-Regular"
    static let notoBengali    = "NotoSerifBengali-Regular"
}

extension Font {
    static var songTitle: Font {
        .custom(SamajhFont.interBold, size: 32).weight(.bold)
    }

    static var artistName: Font {
        .custom(SamajhFont.interMedium, size: 20)
    }

    static func nativeLyric(script: LyricScript) -> Font {
        switch script {
        case .devanagari: return .custom(SamajhFont.notoDevanagari, size: 36)
        case .nastaliq:   return .custom(SamajhFont.notoNastaliq,   size: 36)
        case .bengali:    return .custom(SamajhFont.notoBengali,     size: 36)
        case .latin:      return .custom(SamajhFont.interSemiBold,   size: 36)
        }
    }

    static var romanization: Font   { .custom(SamajhFont.interRegular,  size: 21) }
    static var wordByWord: Font     { .custom(SamajhFont.interRegular,  size: 16) }
    static var directTranslation: Font { .custom(SamajhFont.interRegular, size: 22) }
    static var naturalTranslation: Font { .custom(SamajhFont.interRegular, size: 24) }

    // Cormorant — onboarding, empty states, editorial moments only
    static var cormorantDisplay: Font  { .custom(SamajhFont.cormorantMedium,   size: 48) }
    static var cormorantHeadline: Font { .custom(SamajhFont.cormorantSemiBold, size: 36) }
    static var cormorantQuote: Font    { .custom(SamajhFont.cormorantItalic,   size: 28) }
}

enum LyricScript {
    case devanagari
    case nastaliq
    case bengali
    case latin
}

// MARK: - Motion
// Durations stay in the 220ms–350ms range. No bounces or exaggerated springs.

enum SamajhMotion {
    static let standard = Animation.easeInOut(duration: 0.28)
    static let slow     = Animation.easeInOut(duration: 0.35)
    static let fade     = Animation.easeOut(duration: 0.22)
}

// MARK: - Shape

enum SamajhRadius {
    static let card: CGFloat   = 24
    static let button: CGFloat = 14
    static let small: CGFloat  = 10
}

// MARK: - Font registration

enum SamajhFonts {
    static func register() {
        let fontNames: [(name: String, ext: String)] = [
            (SamajhFont.interRegular,    "ttf"),
            (SamajhFont.interMedium,     "ttf"),
            (SamajhFont.interSemiBold,   "ttf"),
            (SamajhFont.interBold,       "ttf"),
            (SamajhFont.cormorantRegular,  "ttf"),
            (SamajhFont.cormorantMedium,   "ttf"),
            (SamajhFont.cormorantSemiBold, "ttf"),
            (SamajhFont.cormorantItalic,   "ttf"),
            (SamajhFont.notoDevanagari, "ttf"),
            (SamajhFont.notoNastaliq,   "ttf"),
            (SamajhFont.notoBengali,    "ttf"),
        ]
        for font in fontNames {
            guard
                let url      = Bundle.main.url(forResource: font.name, withExtension: font.ext),
                let data     = try? Data(contentsOf: url) as CFData,
                let provider = CGDataProvider(data: data),
                let cgFont   = CGFont(provider)
            else { continue }
            CTFontManagerRegisterGraphicsFont(cgFont, nil)
        }
    }
}
