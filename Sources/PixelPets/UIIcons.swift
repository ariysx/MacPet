import Foundation

/// Small pictograms for the play-mode UI: what a click or drag does, shown instead of words.
/// Stamps use the letters in `Ink.stamp`.
enum UIIcon: CaseIterable {
    case mouseLeft, mouseRight, openHand, grabHand, pointHand, sword, chest, hourglass, apple, dropDown, egg, book, flame

    var sprite: PixelSprite { UIIcon.cache[self]! }

    private static let cache: [UIIcon: PixelSprite] = Dictionary(uniqueKeysWithValues: allCases.map { ($0, PixelSprite(stamp: $0.rows)) })

    private var rows: [String] {
        switch self {
        case .mouseLeft: return [
            "..ooooo..",
            ".oYYoSSo.",
            "oYYYoSSSo",
            "oYYYoSSSo",
            "ooooooooo",
            "oSSSSSSSo",
            "oSSSSSSto",
            "oSSSSSSto",
            ".oSSSSto.",
            "..ooooo..",
        ]
        case .mouseRight: return [
            "..ooooo..",
            ".oSSoYYo.",
            "oSSSoYYYo",
            "oSSSoYYYo",
            "ooooooooo",
            "oSSSSSSSo",
            "oSSSSSSto",
            "oSSSSSSto",
            ".oSSSSto.",
            "..ooooo..",
        ]
        case .openHand: return [
            "...o.o.o...",
            "..oWoWoWo..",
            "..oWoWoWoo.",
            "o.oWoWoWoWo",
            "oWoWWWWWoWo",
            "oWWWWWWWWWo",
            ".oWWWWWWWxo",
            ".oWWWWWWWo.",
            "..oWWWWWxo.",
            "...oWWWxo..",
            "....oooo...",
        ]
        case .grabHand: return [
            "...........",
            "...o.o.o...",
            "..oWoWoWoo.",
            ".ooWoWoWoWo",
            "oWoWWWWWWWo",
            "oWWWWWWWWWo",
            ".oWWWWWWWxo",
            "..oWWWWWWo.",
            "...oWWWxo..",
            "....oooo...",
        ]
        case .pointHand: return [
            "...oo......",
            "..oWWo.....",
            "..oWWo.....",
            "..oWWoooo..",
            "..oWWoWoWoo",
            "ooWWWWWWWWo",
            "oWoWWWWWWWo",
            "oWWWWWWWWWo",
            ".oWWWWWWWxo",
            "..oWWWWWWo.",
            "...oWWWWxo.",
            "...oooooo..",
        ]
        case .sword: return [
            "........ooo",
            ".......oWWo",
            "......oWWxo",
            ".....oWWxo.",
            ".o..oWWxo..",
            "oyo.oWxo...",
            ".oyoWxo....",
            "..oyoo.....",
            ".odoyyo....",
            "odo..oyo...",
            "oo....o....",
        ]
        case .chest: return [
            ".ooooooooo.",
            "oDDDDDDDDDo",
            "odddddddddo",
            "ooooYYYoooo",
            "oddddYddddo",
            "oddddddddeo",
            "oeeeeeeeeeo",
            ".ooooooooo.",
        ]
        case .hourglass: return [
            "ooooooo",
            ".oWWWo.",
            ".oYYYo.",
            "..oYo..",
            "..oWo..",
            ".oWyWo.",
            ".oyyyo.",
            "ooooooo",
        ]
        case .apple: return [
            "....o.oo",
            "...oeoGg",
            ".oooeoo.",
            "oRRrrrqo",
            "oRrrrrqo",
            "orrrrrqo",
            "orrrrqqo",
            ".oqqqqo.",
            "..oooo..",
        ]
        case .dropDown: return [
            "..ooo..",
            "..oWo..",
            "..oWo..",
            "ooOWOoo",
            "oWWWWWo",
            ".oWWWo.",
            "..oWo..",
            "...o...",
        ]
        case .egg: return [
            "..ooo..",
            ".oWWWo.",
            "oWWwWWo",
            "oWwWWxo",
            "oWWWwxo",
            "oWWWxxo",
            ".oxxxo.",
            "..ooo..",
        ]
        case .book: return [
            "ooooooooo",
            "oVVVVVVVo",
            "oVVYYYVvo",
            "oVVVVVVvo",
            "oVVVVVVvo",
            "oVVVVVVvo",
            "ovvvvvvvo",
            "oWWWWWWWo",
            "ooooooooo",
        ]
        case .flame: return [
            "...o...",
            "..oRo..",
            ".oRRo..",
            ".oRYRo.",
            "oRYYRo.",
            "oRYWYRo",
            "oRYWYRo",
            ".oRRRo.",
            "..ooo..",
        ]
        }
    }

    /// A key cap with a label, such as F or ESC.
    static func key(_ label: String) -> PixelSprite {
        let w = PixelFont.width(label) + 6
        var s = PixelSprite(width: w, height: 11)
        let outline = Ink.make(.dark, .outline)
        for y in 0..<11 {
            for x in 0..<w {
                let edge = x == 0 || y == 0 || x == w - 1 || y == 10
                let corner = (x == 0 || x == w - 1) && (y == 0 || y == 10)
                if corner { continue }
                s[x, y] = edge ? outline : y >= 8 ? Ink.make(.stone, .shade) : Ink.make(.stone, .light)
            }
        }
        var cx = 3
        for c in label {
            if let rows = PixelFont.glyph(c) {
                for (gy, row) in rows.enumerated() { for (gx, ch) in row.enumerated() where ch == "#" { s[cx + gx, 1 + gy] = Ink.make(.dark, .base) } }
            }
            cx += PixelFont.advance
        }
        return s
    }
}
