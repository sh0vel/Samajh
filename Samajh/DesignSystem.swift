import SwiftUI

// MARK: - Colors

extension Color {
    // Backgrounds
    static let samajhBackground         = Color(red: 0.000, green: 0.000, blue: 0.000) // #000000
    static let samajhBackgroundSecondary = Color(red: 0.055, green: 0.055, blue: 0.067) // #0E0E11
    static let samajhSurfaceElevated    = Color(red: 0.082, green: 0.082, blue: 0.094) // #151518
    static let samajhSurfaceCard        = Color(red: 0.106, green: 0.106, blue: 0.125) // #1B1B20

    // Accent gold — use sparingly
    static let samajhGold               = Color(red: 0.839, green: 0.627, blue: 0.373) // #D6A05F
    static let samajhGoldMuted          = Color(red: 0.722, green: 0.537, blue: 0.322) // #B88952
    static let samajhGoldPressed        = Color(red: 0.890, green: 0.694, blue: 0.427) // #E3B16D

    // Text
    static let samajhTextPrimary        = Color(red: 0.961, green: 0.949, blue: 0.922) // #F5F2EB
    static let samajhTextSecondary      = Color(red: 0.722, green: 0.694, blue: 0.655) // #B8B1A7
    static let samajhTextMuted          = Color(red: 0.494, green: 0.478, blue: 0.451) // #7E7A73
    static let samajhTextDisabled       = Color(red: 0.353, green: 0.341, blue: 0.322) // #5A5752
    static let samajhTextRoman          = Color(red: 0.784, green: 0.757, blue: 0.718) // #C8C1B7
}

// MARK: - Typography

enum SamajhFont {
    // Font names — files must be bundled in the Xcode project
    static let interRegular    = "Inter-Regular"
    static let interMedium     = "Inter-Medium"
    static let interSemiBold   = "Inter-SemiBold"
    static let interBold       = "Inter-Bold"

    // Cormorant Garamond — cinematic/literary moments only (onboarding, featured cards, empty states)
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
    // Song title
    static var songTitle: Font {
        .custom(SamajhFont.interBold, size: 32).weight(.bold)
    }

    // Artist name
    static var artistName: Font {
        .custom(SamajhFont.interMedium, size: 20)
    }

    // Original lyric (native script) — dominates visually
    static func nativeLyric(script: LyricScript) -> Font {
        switch script {
        case .devanagari: return .custom(SamajhFont.notoDevanagari, size: 36)
        case .nastaliq:   return .custom(SamajhFont.notoNastaliq, size: 36)
        case .bengali:    return .custom(SamajhFont.notoBengali, size: 36)
        case .latin:      return .custom(SamajhFont.interSemiBold, size: 36)
        }
    }

    // Romanization — supportive, not primary
    static var romanization: Font {
        .custom(SamajhFont.interRegular, size: 21)
    }

    // Translation layers
    static var wordByWord: Font {
        .custom(SamajhFont.interRegular, size: 16)
    }
    static var directTranslation: Font {
        .custom(SamajhFont.interRegular, size: 22)
    }
    static var naturalTranslation: Font {
        .custom(SamajhFont.interRegular, size: 24)
    }

    // Cormorant — cinematic/literary accent only
    static var cormorantDisplay: Font {
        .custom(SamajhFont.cormorantMedium, size: 48)
    }
    static var cormorantHeadline: Font {
        .custom(SamajhFont.cormorantSemiBold, size: 36)
    }
    static var cormorantQuote: Font {
        .custom(SamajhFont.cormorantItalic, size: 28)
    }
}

enum LyricScript {
    case devanagari
    case nastaliq
    case bengali
    case latin
}

// MARK: - Motion

enum SamajhMotion {
    static let standard  = Animation.easeInOut(duration: 0.28)
    static let slow      = Animation.easeInOut(duration: 0.35)
    static let fade      = Animation.easeOut(duration: 0.22)
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
        let fontNames = [
            SamajhFont.interRegular, SamajhFont.interMedium,
            SamajhFont.interSemiBold, SamajhFont.interBold,
            SamajhFont.cormorantRegular, SamajhFont.cormorantMedium,
            SamajhFont.cormorantSemiBold, SamajhFont.cormorantItalic,
            SamajhFont.notoDevanagari, SamajhFont.notoNastaliq,
            SamajhFont.notoBengali,
        ]
        for name in fontNames {
            guard
                let url = Bundle.main.url(forResource: name, withExtension: "ttf")
                       ?? Bundle.main.url(forResource: name, withExtension: "otf"),
                let data = try? Data(contentsOf: url) as CFData,
                let provider = CGDataProvider(data: data),
                let cgFont = CGFont(provider)
            else { continue }
            CTFontManagerRegisterGraphicsFont(cgFont, nil)
        }
    }
}
