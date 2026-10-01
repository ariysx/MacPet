import Foundation

// Sprites are ASCII art, parsed into one r8Uint atlas that stores a palette index per pixel.
//   .  transparent     o  outline      b  body (primary)   s  secondary
//   e  eye             w  white        r  red              g  green
//   y  yellow          k  dark grey
// Pets are not stored as finished frames: each pet's frames are composed at hatch from its
// genes (body shape, pattern, eyes, accessory) and written into that pet's own atlas region.

enum Ink {
    static let clear: UInt8 = 0, outline: UInt8 = 1, body: UInt8 = 2, secondary: UInt8 = 3
    static let eye: UInt8 = 4, white: UInt8 = 5, red: UInt8 = 6, green: UInt8 = 7
    static let yellow: UInt8 = 8, grey: UInt8 = 9

    static func code(_ c: Character) -> UInt8 {
        switch c {
        case "o": return outline
        case "b": return body
        case "s": return secondary
        case "e": return eye
        case "w": return white
        case "r": return red
        case "g": return green
        case "y": return yellow
        case "k": return grey
        default: return clear
        }
    }
}

struct PixelSprite: Equatable {
    let width: Int
    let height: Int
    /// Row-major, row 0 at the top.
    var pixels: [UInt8]

    init(width: Int, height: Int) {
        self.width = width
        self.height = height
        pixels = Array(repeating: Ink.clear, count: width * height)
    }

    init(_ art: [String]) {
        let w = art.first?.count ?? 0
        for (row, line) in art.enumerated() where line.count != w {
            preconditionFailure("sprite row \(row) is \(line.count) wide, expected \(w): \(line)")
        }
        self.init(width: w, height: art.count)
        for (y, line) in art.enumerated() {
            for (x, c) in line.enumerated() { pixels[y * w + x] = Ink.code(c) }
        }
    }

    subscript(x: Int, y: Int) -> UInt8 {
        get { x >= 0 && y >= 0 && x < width && y < height ? pixels[y * width + x] : Ink.clear }
        set { if x >= 0 && y >= 0 && x < width && y < height { pixels[y * width + x] = newValue } }
    }

    func map(_ transform: (Int, Int, UInt8) -> UInt8) -> PixelSprite {
        var out = self
        for y in 0..<height { for x in 0..<width { out[x, y] = transform(x, y, self[x, y]) } }
        return out
    }

    func replacing(_ from: UInt8, with to: UInt8) -> PixelSprite {
        map { _, _, v in v == from ? to : v }
    }

    func shifted(dx: Int, dy: Int) -> PixelSprite {
        map { x, y, _ in self[x - dx, y - dy] }
    }

    /// Removes one row and pushes everything above it down by one: a 1 px bob.
    func squashed(removingRow row: Int) -> PixelSprite {
        map { x, y, _ in y > row ? self[x, y] : self[x, y - 1] }
    }

    /// Nearest-neighbour resize that keeps the first and last rows and columns.
    func scaled(width w: Int, height h: Int) -> PixelSprite {
        var out = PixelSprite(width: w, height: h)
        for y in 0..<h {
            for x in 0..<w {
                let sx = min(width - 1, Int((Double(x) + 0.5) * Double(width) / Double(w)))
                let sy = min(height - 1, Int((Double(y) + 0.5) * Double(height) / Double(h)))
                out[x, y] = self[sx, sy]
            }
        }
        return out
    }

    /// Draws `other` on top, at (`x`, `y`) = its top-left. Transparent pixels are skipped;
    /// with `underOnly`, it only fills pixels that are transparent here.
    mutating func draw(_ other: PixelSprite, x: Int, y: Int, underOnly: Bool = false) {
        for sy in 0..<other.height {
            for sx in 0..<other.width {
                let v = other[sx, sy]
                guard v != Ink.clear else { continue }
                if underOnly && self[x + sx, y + sy] != Ink.clear { continue }
                self[x + sx, y + sy] = v
            }
        }
    }

    var topRow: Int? {
        (0..<height).first { y in (0..<width).contains { self[$0, y] != Ink.clear } }
    }
}

// MARK: - Animations and icons

enum PetAnim: Int, CaseIterable {
    case idle, walk, sleep, eat, hop, sick, held, hurt, attack

    var frameCount: Int {
        switch self {
        case .sleep, .held, .hurt: return 1
        default: return 2
        }
    }

    /// Index of this animation's first frame in a pet's frame list.
    var offset: Int { PetAnim.allCases.prefix(while: { $0 != self }).reduce(0) { $0 + $1.frameCount } }

    static let totalFrames = PetAnim.allCases.reduce(0) { $0 + $1.frameCount }
}

enum IconKind: Int, CaseIterable {
    case heart, drumstick, cloud, zz, face, sparkle, exclamation

    static func `for`(_ feeling: Feeling) -> IconKind? {
        switch feeling {
        case .scared: return .exclamation
        case .sick: return .face
        case .sleepy: return .zz
        case .hungry: return .drumstick
        case .sad: return .cloud
        case .excited: return .sparkle
        case .content: return .heart
        }
    }
}

enum StaticSprite: Hashable {
    case egg(Int)       // 0, 1 wobble; 2 cracked
    case grave
    case pellet
    case slime(Int)
    case bat(Int)
    case ogre(Int)      // 2x2 tiles
    case smoke(Int)
    case icon(IconKind)
    case weapon(Item)
    case chest
    case bag
}

// MARK: - Art

enum SpriteArt {
    struct Poses {
        var stand, step, sleep, eat, held: PixelSprite
    }

    static func poses(for shape: BodyShape) -> Poses {
        switch shape {
        case .blob: return blob
        case .bird: return bird
        case .cat: return cat
        case .bunny: return bunny
        case .frog: return frog
        case .bear: return bear
        case .ghost: return ghost
        case .fox: return fox
        case .dragon: return dragon
        }
    }

    private static func pose(_ base: [String], rows: [Int: String] = [:]) -> PixelSprite {
        var art = base
        for (i, row) in rows { art[i] = row }
        return PixelSprite(art)
    }

    private static let empty = "................"

    // Blob: a round jelly. Faces right.
    private static let blobStand = [
        empty, empty, empty, empty, empty,
        ".....oooooo.....",
        "....obbbbbbo....",
        "...obwbbbbbbo...",
        "...obwbbbebeo...",
        "..obbbbbbbbbbo..",
        "..obbbbbbbrbbo..",
        "..obssbbbbbbbo..",
        "..obsssbbbbbbo..",
        "...obssbbbbbo...",
        "....oooooooo....",
        "....oo....oo....",
    ]
    static let blob = Poses(
        stand: pose(blobStand),
        step: pose(blobStand, rows: [15: ".....oo..oo....."]),
        sleep: PixelSprite([
            empty, empty, empty, empty, empty, empty, empty, empty, empty,
            ".....oooooo.....",
            "...oobbbbbboo...",
            "..obwbbbbbbbbo..",
            "..obbbbbkkbkko..",
            "..obssbbbbbbbo..",
            "...obsssbbbbo...",
            "....oooooooo....",
        ]),
        eat: pose(blobStand, rows: [8: "...obwbbbkbko...",
                                     10: "..obbbbbbbokko..",
                                     11: "..obssbbbbbbro.."]),
        held: pose(blobStand, rows: [15: ".....o....o....."]))

    // Bird: a round chick with a beak.
    private static let birdStand = [
        empty, empty, empty,
        "......oooo......",
        ".....obbbbo.....",
        "....obbbbbbo....",
        "....obwbbebo....",
        "....obbbbbbooo..",
        "...obbbbbbbbyyo.",
        "..obsssbbbbboo..",
        "..obssssbbbbo...",
        "..obsssbbbbbo...",
        "...obbbbbbbo....",
        "....ooooooo.....",
        "......y..y......",
        ".....yy.yy......",
    ]
    static let bird = Poses(
        stand: pose(birdStand),
        step: pose(birdStand, rows: [14: ".....y...y......", 15: "....yy..yy......"]),
        sleep: PixelSprite([
            empty, empty, empty, empty, empty, empty, empty, empty, empty,
            ".....oooo.......",
            "....obbbbooo....",
            "...obbkbbbyyo...",
            "..obssssbbbbo...",
            "..obsssssbbbo...",
            "...obbbbbbbo....",
            "....ooooooo.....",
        ]),
        eat: pose(birdStand, rows: [6: "....obwbbkbo....",
                                     8: "...obbbbbbbbyo..",
                                     9: "..obsssbbbbbyo.."]),
        held: pose(birdStand, rows: [14: "......y..y......", 15: "......y..y......"]))

    // Cat: pointy ears, tail on the left.
    private static let catStand = [
        empty, empty, empty,
        "....o....o......",
        "...obo..obo.....",
        "...obbooobbo....",
        "...obbbbbbbbo...",
        "...obwbbebbeo...",
        "...obbbbbrkrbo..",
        ".o.obbbbbbbbbo..",
        "oboobssbbbbbbo..",
        "obbobsssbbbbbo..",
        ".oobssssbbbbbo..",
        "...obsssbbbbbo..",
        "...oooooooooo...",
        "...oo.oo..oo.oo.",
    ]
    static let cat = Poses(
        stand: pose(catStand),
        step: pose(catStand, rows: [15: "....oo..oo.oo..."]),
        sleep: PixelSprite([
            empty, empty, empty, empty, empty, empty, empty, empty, empty,
            "....o....o......",
            "...obo..obo.....",
            "..obbooobbbo....",
            "..obbbkkbkkbo...",
            ".oobbssssbbbo...",
            "osbbsssssbbbo...",
            ".ooooooooooo....",
        ]),
        eat: pose(catStand, rows: [7: "...obwbbkbbko...", 8: "...obbbbbbkkbo.."]),
        held: pose(catStand, rows: [15: "....o..o..o..o.."]))

    // Bunny: long ears, fluffy tail.
    private static let bunnyStand = [
        empty,
        ".....o...o......",
        "....obo.obo.....",
        "....oso.oso.....",
        "....oso.oso.....",
        "....obooobo.....",
        "...obbbbbbbo....",
        "..obwbbbbebo....",
        "..obbbbbbbrko...",
        "..obbbbbbbbo....",
        ".obsssbbbbbbo...",
        "owbsssbbbbbbo...",
        "owwsssbbbbbbo...",
        ".oobbbbbbbbo....",
        "...oooooooooo...",
        "...ooo....ooo...",
    ]
    static let bunny = Poses(
        stand: pose(bunnyStand),
        step: pose(bunnyStand, rows: [15: "....ooo..ooo...."]),
        sleep: PixelSprite([
            empty, empty, empty, empty, empty, empty, empty, empty, empty,
            "......oooooo....",
            ".....osssssbo...",
            "...oobbbbbbbbo..",
            "..obbbbbkkbbbo..",
            ".owbssbbbbbbbo..",
            ".owbsssbbbbbo...",
            "..oooooooooo....",
        ]),
        eat: pose(bunnyStand, rows: [7: "..obwbbbbkbo....", 8: "..obbbbbbbrkko.."]),
        held: pose(bunnyStand, rows: [15: "....o..o..o..o.."]))

    // Frog: wide, bulging eyes, big mouth.
    private static let frogStand = [
        empty, empty, empty, empty, empty,
        "...ooo....ooo...",
        "..owebo..owebo..",
        "..obbboooobbbo..",
        ".obbbbbbbbbbbbo.",
        ".obbbbbbbbbbbbo.",
        ".obbbbbbbkkkbbo.",
        ".obssssssssssbo.",
        ".obssssssssssbo.",
        "..obbssssssbbo..",
        ".oobbooooooobboo",
        "obbbo......obbbo",
    ]
    static let frog = Poses(
        stand: pose(frogStand),
        step: pose(frogStand, rows: [15: ".obbbo....obbbo."]),
        sleep: pose(frogStand, rows: [6: "..okkbo..okkbo..", 10: ".obbbbbbbbbbbbo."]),
        eat: pose(frogStand, rows: [10: ".obbbbbbbkkkrrr."]),
        held: pose(frogStand, rows: [15: "..obo......obo.."]))

    // Bear: round ears and a snout.
    private static let bearStand = [
        empty, empty, empty,
        "...oo....oo.....",
        "..obso..obso....",
        "..obboooobbo....",
        "..obbbbbbbbbo...",
        "..obwbbbebbbo...",
        "..obbbbbbssko...",
        "..obbbbbbbsso...",
        ".oobbbbbbbbbo...",
        "obbbbssssbbbbo..",
        "obbbssssssbbbo..",
        ".obbssssssbbo...",
        "..oooooooooo....",
        "..obbo...obbo...",
    ]
    static let bear = Poses(
        stand: pose(bearStand),
        step: pose(bearStand, rows: [15: "...obbo.obbo...."]),
        sleep: PixelSprite([
            empty, empty, empty, empty, empty, empty, empty, empty, empty,
            "....oo....oo....",
            "...obso..obso...",
            "..obbbooooobbo..",
            ".obbbbkkbkkbbbo.",
            ".obbbbbbbbsskbo.",
            "obbssssssssbbbbo",
            ".oooooooooooooo.",
        ]),
        eat: pose(bearStand, rows: [7: "..obwbbbkbbbo...", 9: "..obbbbbbbkro..."]),
        held: pose(bearStand, rows: [15: "...o..o..o..o..."]))

    // Ghost: floats, wavy hem, no legs.
    private static let ghostStand = [
        empty, empty, empty,
        ".....oooooo.....",
        "....obbbbbbo....",
        "...obwbbbbbbo...",
        "...obwbbebbeo...",
        "...obbbbbbbbo...",
        "...obbbbbkkbo...",
        "...obbbbbbbbo...",
        "..obbbbbbbbbbo..",
        "..obsbbbbbbbbo..",
        "..obbbbbbbbbbo..",
        "..obbbbbbbbbbo..",
        "..obbobbobbobo..",
        "..oo.oo.oo.oo...",
    ]
    static let ghost = Poses(
        stand: pose(ghostStand),
        step: pose(ghostStand, rows: [14: "..obobbobbobbo..", 15: "...oo.oo.oo.oo.."]),
        sleep: pose(ghostStand, rows: [6: "...obwbbkbbko...", 8: "...obbbbbbbbo..."]),
        eat: pose(ghostStand, rows: [8: "...obbbbbkkko..."]),
        held: pose(ghostStand, rows: [14: "..obobbobbobbo..", 15: "...oo.oo.oo.oo.."]))

    // Fox: pointy ears, white-tipped tail, dark socks.
    private static let foxStand = [
        empty, empty,
        "...o....o.......",
        "..obo..obo......",
        "..obbooobbo.....",
        "..obbbbbbbbo....",
        "..obwbbbebbooo..",
        "..obbbbbbbwwwko.",
        "..obbbbbbwwoo...",
        "oo.obbbbbbbo....",
        "obooobwwbbbbo...",
        "obbobwwwbbbbo...",
        "owbbbwwbbbbbo...",
        ".owobbbbbbbbo...",
        "...oooooooooo...",
        "...ok.ok..ok.ok.",
    ]
    static let fox = Poses(
        stand: pose(foxStand),
        step: pose(foxStand, rows: [15: "....ok.ok.ok.ok."]),
        sleep: PixelSprite([
            empty, empty, empty, empty, empty, empty, empty, empty, empty,
            "....o...o.......",
            "...obo.obo......",
            "..obbbobbbooo...",
            ".obbkkbkkbwwko..",
            "owbbbbbbbbboo...",
            "owwbbbbbbbbbo...",
            ".oooooooooooo...",
        ]),
        eat: pose(foxStand, rows: [6: "..obwbbbkbbooo..", 8: "..obbbbbbwkro..."]),
        held: pose(foxStand, rows: [15: "...o..o...o..o.."]))

    // Dragon: horns, wings, claws. Breathes a little fire when it eats.
    private static let dragonStand = [
        empty,
        ".......y.y......",
        "......oyoyo.....",
        ".....obbbbbo....",
        "....obwbbebbo...",
        "....obbbbbbbooo.",
        ".s..obbbbbbbbbko",
        "sso.obbbbbboooo.",
        "ssso.obbbbbo....",
        ".sssobbbbbbbo...",
        "..ssobssssbbbo..",
        "...oobssssbbbbo.",
        "....obssssbbbbo.",
        "....obbbbbbbbo..",
        ".....oooooooo...",
        ".....oy.oy.oy...",
    ]
    static let dragon = Poses(
        stand: pose(dragonStand),
        step: pose(dragonStand, rows: [15: "......oy.oy.oy.."]),
        sleep: PixelSprite([
            empty, empty, empty, empty, empty, empty, empty, empty, empty,
            "........y.y.....",
            ".......oyoyo....",
            ".ss..oobbbbbo...",
            "sssoobbbbkkbbko.",
            ".ssobssssbbbbbo.",
            "..obbssssbbbbbo.",
            "...oooooooooooo.",
        ]),
        eat: pose(dragonStand, rows: [5: "....obbbbbbbooyr", 6: ".s..obbbbbbbbbkr"]),
        held: pose(dragonStand, rows: [15: ".....o..o..o...."]))

    // Accessories sit on top of the head. Drawn with fixed inks so they read on any body.
    static func accessory(_ kind: Accessory) -> PixelSprite? {
        switch kind {
        case .none: return nil
        case .horns: return PixelSprite(["o.....o", "wo...ow", "ow...wo"])
        case .antenna: return PixelSprite(["oyo", ".o.", ".o."])
        case .crest: return PixelSprite(["..r..", ".rr.r", "rrrr."])
        case .leaf: return PixelSprite([".gg", "ggo", "..o"])
        case .bow: return PixelSprite(["rr.rr", "rrorr", "r...r"])
        case .flower: return PixelSprite([".r.", "ryr", ".g."])
        case .sprout: return PixelSprite(["g.g", ".g.", ".g."])
        case .tophat: return PixelSprite([".ooo.", ".oko.", ".oro.", "ooooo"])
        case .cap: return PixelSprite([".ooo..", "orrro.", "orrrrr"])
        case .mushroom: return PixelSprite([".ooo.", "orwro", "ooooo"])
        case .unihorn: return PixelSprite(["..y", ".wy", ".yw"])
        case .crown: return PixelSprite(["y.y.y", "yyyyy", "yryry"])
        case .halo: return PixelSprite([".yyy.", "y...y", ".yyy.", "....."])
        case .flame: return PixelSprite(["..r..", ".ryr.", "ryyyr"])
        }
    }

    // Egg: `b` is the shell, `s` the spots (tinted with the chick's colour).
    static let egg = PixelSprite([
        empty, empty, empty, empty,
        "......oooo......",
        ".....obbbbo.....",
        "....obwbbsbo....",
        "....owbbbbbo....",
        "...obbbsbbbbo...",
        "...obsbbbbsbo...",
        "...obbbbbbbbo...",
        "...obbsbbbsbo...",
        "...obbbbbbbbo...",
        "....obbsbbbo....",
        ".....obbbbo.....",
        "......oooo......",
    ])

    static let grave = PixelSprite([
        empty, empty, empty,
        "......oooo......",
        ".....obbbbo.....",
        "....obbkbbbo....",
        "....obkkkbbo....",
        "....obbkbbbo....",
        "....obbkbbbo....",
        "....obbbbbbo....",
        "....obbbbbso....",
        "....obbbbbbo....",
        "....obsbbbbo....",
        "....obbbbsbo....",
        "..ggoooooooogg..",
        ".gggggggggggggg.",
    ])

    static let pellet = PixelSprite([
        empty, empty, empty, empty, empty, empty, empty, empty, empty, empty, empty,
        "......oooo......",
        ".....osbbbo.....",
        ".....obbbbo.....",
        ".....obbbso.....",
        "......oooo......",
    ])

    static let slime = [
        PixelSprite([
            empty, empty, empty, empty, empty, empty, empty, empty, empty,
            "......oooo......",
            "....oobbbboo....",
            "...obwbbbbbbo...",
            "..obwbbebbebbo..",
            "..obbbbbbbbbbo..",
            "..osbbbbbbbbso..",
            "...oooooooooo...",
        ]),
        PixelSprite([
            empty, empty, empty, empty, empty, empty, empty, empty, empty, empty,
            ".....oooooo.....",
            "...oobwbbbbboo..",
            "..obwbbebbebbbo.",
            ".obbbbbbbbbbbbo.",
            ".osbbbbbbbbbbso.",
            "..oooooooooooo..",
        ]),
    ]

    static let bat = [
        PixelSprite([
            empty, empty, empty, empty,
            "o..............o",
            "oo............oo",
            "obo....oo....obo",
            "obbo..obbo..obbo",
            "obbbooobbooobbbo",
            ".obbbbbbbbbbbbo.",
            "..obbbrbbrbbbo..",
            "...oobbwwbboo...",
            ".....obbbbo.....",
            "......oooo......",
            empty, empty,
        ]),
        PixelSprite([
            empty, empty, empty, empty, empty, empty,
            ".......oo.......",
            "......obbo......",
            "....ooobbooo....",
            "..oobbbbbbbboo..",
            ".obbbbrbbrbbbbo.",
            "obbbobbwwbbobbbo",
            "obbo..obbo..obbo",
            "oo....oooo....oo",
            "o..............o",
            empty,
        ]),
    ]

    private static let e24 = "........................"
    private static let ogreTop = [
        e24, e24, e24,
        "........oooooooo........",
        ".......obbbbbbbbo.......",
        "......obbbbbbbbbbo......",
        "......obbkkbbbkkbo......",
        "......obbebbbbbebo......",
        "......obbbbbbbbbbo......",
        "......obwbkkkkbwbo......",
        ".......obbbbbbbbo.......",
        ".....oooobbbbbboooo.....",
        "....obbbbbbbbbbbbbbo....",
        "...obbbobbbbbbbbobbbo...",
        "...obbbobbbbbbbbobbbo...",
        "...obbbobbbbbbbbobbbo...",
        "...obboossssssssoobbo...",
        "........osssssssso......",
        "........obbbbbbbbo......",
        "........obbboobbbo......",
    ]
    static let ogre = [
        PixelSprite(ogreTop + [
            "........obbbo.obbbo.....",
            ".......obbbbo.obbbbo....",
            ".......obbbbo.obbbbo....",
            ".......oooooo.oooooo....",
        ]),
        PixelSprite(ogreTop + [
            ".......obbbo..obbbo.....",
            "......obbbo....obbbo....",
            "......obbbo....obbbbo...",
            "......ooooo....oooooo...",
        ]),
    ]

    static let smoke = [
        PixelSprite([
            empty, empty, empty, empty, empty, empty, empty, empty, empty, empty,
            "......ww........",
            ".....wbbw.......",
            "....wbbbbw..ww..",
            "....wbbsbw.wbbw.",
            ".....wbbw..wbbw.",
            "......ww....ww..",
        ]),
        PixelSprite([
            empty, empty, empty, empty, empty, empty,
            ".....www........",
            "...wwbbbww..ww..",
            "..wbbbbbbbwwbbw.",
            "..wbbsbbbbbbbbw.",
            ".wbbbbbssbbbbw..",
            ".wbbsbbbbbbbw...",
            "..wbbbbbbbbw....",
            "...wwbbbbww.....",
            ".....wwww.......",
            empty,
        ]),
        PixelSprite([
            empty, empty, empty, empty,
            "..w.......w.....",
            empty,
            "....ww....w..w..",
            ".w..............",
            "......w.....w...",
            "..s.........s...",
            "........w.......",
            "...w..........w.",
            empty,
            ".....s...w......",
            empty, empty,
        ]),
    ]

    /// Held weapons: `b` and `s` are tinted per weapon by the scene.
    static func weapon(_ item: Item) -> PixelSprite {
        switch item {
        case .stick: return PixelSprite([
            "......o.",
            ".....obo",
            "....obo.",
            "...obo..",
            "..obo...",
            ".obo....",
            "obo.....",
            "oo......"])
        case .slingshot: return PixelSprite([
            "o...o",
            "brrrb",
            "ob.bo",
            ".obo.",
            "..b..",
            ".obo.",
            ".obo.",
            "..o.."])
        case .magicWand: return PixelSprite([
            ".....y.",
            "....yyy",
            ".....y.",
            "....ob.",
            "...ob..",
            "..ob...",
            ".ob....",
            "oo....."])
        case .dragonFang: return PixelSprite([
            ".....oo",
            "....oww",
            "...owwo",
            "..owwo.",
            ".owwo..",
            "orro...",
            "oro....",
            "oo....."])
        default: return PixelSprite([ // swords
            "......oo",
            ".....obo",
            "....obo.",
            "...obo..",
            "o.obo...",
            "osso....",
            ".oko....",
            "oko.....",
            "oo......"])
        }
    }

    static let chest = PixelSprite([
        empty, empty, empty, empty, empty,
        "...oooooooooo...",
        "..obbbbbbbbbbo..",
        "..osbbbbbbbbso..",
        "..oooooyyooooo..",
        "..obbbbyybbbbo..",
        "..osbbbbbbbbso..",
        "..obbbbbbbbbbo..",
        "..osbbbbbbbbso..",
        "..obbbbbbbbbbo..",
        "..osbbbbbbbbso..",
        "..oooooooooooo..",
    ])

    static let bag = PixelSprite([
        empty, empty, empty, empty, empty, empty, empty,
        "......o.o.......",
        ".......o........",
        "......oso.......",
        ".....obbbo......",
        "....obbbbbo.....",
        "...obbwbbbbo....",
        "...obbbbbbbo....",
        "...obbbbbbbo....",
        "....ooooooo.....",
    ])

    /// 8 x 8, drawn in the top-left of a tile. A dark drop shadow is added when the atlas is built.
    static func icon(_ kind: IconKind) -> PixelSprite {
        switch kind {
        case .heart: return PixelSprite([
            ".rr.rr..",
            "rwrrrrr.",
            "rrrrrrr.",
            "rrrrrrr.",
            ".rrrrr..",
            "..rrr...",
            "...r....",
            "........"])
        case .drumstick: return PixelSprite([
            "..yyy...",
            ".yyyyy..",
            "yyyyyyy.",
            "yyyyyyy.",
            ".yyyyy..",
            "..yyww..",
            "....www.",
            ".....w..",
            ])
        case .cloud: return PixelSprite([
            "..kkk...",
            ".kkkkkk.",
            "kkkkkkkk",
            ".kkkkkk.",
            "........",
            ".w..w...",
            "..w..w..",
            "........"])
        case .zz: return PixelSprite([
            "wwww....",
            "..w.....",
            ".w......",
            "wwww....",
            "....www.",
            ".....w..",
            "....www.",
            "........"])
        case .face: return PixelSprite([
            ".gggggg.",
            "gggggggg",
            "gkggggkg",
            "gggggggg",
            "ggkkkkgg",
            "gkggggkg",
            "gggggggg",
            ".gggggg."])
        case .sparkle: return PixelSprite([
            "...y....",
            "...y....",
            ".yywyy..",
            "...y....",
            "...y..y.",
            ".....yyy",
            "......y.",
            "........"])
        case .exclamation: return PixelSprite([
            "..rr....",
            "..rr....",
            "..rr....",
            "..rr....",
            "..rr....",
            "........",
            "..rr....",
            "..rr...."])
        }
    }
}

// MARK: - Procedural pets

enum PetComposer {
    /// All frames of one pet, in `PetAnim` order: the adult set, then the baby set.
    static func frames(for looks: Looks) -> (adult: [PixelSprite], baby: [PixelSprite]) {
        let poses = SpriteArt.poses(for: looks.shape)
        let decorate = { (s: PixelSprite) in applyEyes(applyPattern(s, looks.pattern), looks.eyes) }
        let stand = decorate(poses.stand), step = decorate(poses.step)
        let sick = { (s: PixelSprite) in
            s.replacing(Ink.white, with: Ink.green).replacing(Ink.red, with: Ink.green).replacing(Ink.eye, with: Ink.grey)
        }

        var bare: [PixelSprite] = []
        for anim in PetAnim.allCases {
            switch anim {
            case .idle: bare += [stand, stand.squashed(removingRow: 10)]
            case .walk: bare += [stand, step]
            case .sleep: bare += [decorate(poses.sleep)]
            case .eat: bare += [decorate(poses.eat), stand]
            case .hop: bare += [step, stand]
            case .sick: bare += [sick(stand), sick(step)]
            case .held: bare += [decorate(poses.held)]
            case .hurt: bare += [stand.replacing(Ink.eye, with: Ink.grey)]
            case .attack: bare += [stand.shifted(dx: 2, dy: 0), step]
            }
        }
        precondition(bare.count == PetAnim.totalFrames)

        let accessory = SpriteArt.accessory(looks.accessory)
        let adult = bare.map { addAccessory(accessory, to: $0) }
        let baby = bare.map { frame -> PixelSprite in
            var tile = PixelSprite(width: 16, height: 16)
            tile.draw(frame.scaled(width: 12, height: 12), x: 2, y: 4)
            return addAccessory(accessory, to: tile)
        }
        return (adult, baby)
    }

    static func applyPattern(_ s: PixelSprite, _ pattern: Pattern) -> PixelSprite {
        let body = (0..<s.height).flatMap { y in (0..<s.width).map { (x: $0, y: y) } }.filter { s[$0.x, $0.y] == Ink.body }
        guard let minX = body.map(\.x).min(), let maxX = body.map(\.x).max(),
              let minY = body.map(\.y).min(), let maxY = body.map(\.y).max() else { return s }
        let midX = (minX + maxX) / 2, midY = (minY + maxY) / 2
        let heart = PixelSprite([".r.r.", "rrrrr", ".rrr.", "..r.."])
        let rainbow = [Ink.red, Ink.yellow, Ink.green, Ink.secondary, Ink.body]
        return s.map { x, y, v in
            if pattern == .heart, v == Ink.body || v == Ink.secondary {
                let hx = x - (midX - 3), hy = y - (midY - 1)
                if heart[hx, hy] != Ink.clear { return Ink.red }
            }
            guard v == Ink.body else { return v }
            switch pattern {
            case .plain, .heart: return v
            case .spots: return (x % 4 == 1 && y % 4 == 2) || (x % 4 == 3 && y % 4 == 0) ? Ink.secondary : v
            case .stripes: return x % 3 == 0 ? Ink.secondary : v
            case .patch: return x <= minX + 3 && y <= minY + 3 ? Ink.secondary : v
            case .socks: return y >= maxY - 1 ? Ink.secondary : v
            case .tips: return y <= minY + 1 ? Ink.secondary : v
            case .twoTone: return x < midX ? Ink.secondary : v
            case .checker: return (x / 2 + y / 2) % 2 == 0 ? Ink.secondary : v
            case .speckle: return (x * 7 + y * 13) % 9 == 0 ? Ink.secondary : v
            case .stars:
                if (x * 7 + y * 13) % 9 == 0 { return Ink.white }
                return (x * 5 + y * 3) % 13 == 0 ? Ink.yellow : v
            case .rainbow: return rainbow[y % rainbow.count]
            }
        }
    }

    static func applyEyes(_ s: PixelSprite, _ eyes: EyeStyle) -> PixelSprite {
        var out = s
        let eyePixels = (0..<s.height).flatMap { y in (0..<s.width).map { (x: $0, y: y) } }.filter { s[$0.x, $0.y] == Ink.eye }
        func paint(_ x: Int, _ y: Int, _ ink: UInt8) {
            if s[x, y] == Ink.body || s[x, y] == Ink.secondary { out[x, y] = ink }
        }
        if eyes == .cyclops, !eyePixels.isEmpty {
            let cx = eyePixels.map(\.x).reduce(0, +) / eyePixels.count
            let cy = eyePixels.map(\.y).reduce(0, +) / eyePixels.count
            for p in eyePixels { out[p.x, p.y] = Ink.body }
            out[cx, cy] = Ink.white
            out[cx + 1, cy] = Ink.eye
            out[cx, cy + 1] = Ink.eye
            out[cx + 1, cy + 1] = Ink.eye
            return out
        }
        for (x, y) in eyePixels {
            switch eyes {
            case .dot, .cyclops: break
            case .wide: paint(x, y + 1, Ink.eye)
            case .sleepy: paint(x, y - 1, Ink.outline)
            case .happy:
                out[x, y] = Ink.body
                paint(x - 1, y, Ink.outline)
                paint(x + 1, y, Ink.outline)
                paint(x, y - 1, Ink.outline)
            case .sparkly:
                out[x, y] = Ink.white
                paint(x, y + 1, Ink.eye)
            case .angry:
                paint(x - 1, y - 1, Ink.outline)
                paint(x, y - 1, Ink.outline)
            case .hearts:
                out[x, y] = Ink.red
                paint(x, y + 1, Ink.red)
            case .starry:
                out[x, y] = Ink.yellow
                for (dx, dy) in [(0, -1), (0, 1), (-1, 0), (1, 0)] { paint(x + dx, y + dy, Ink.yellow) }
            }
        }
        return out
    }

    static func addAccessory(_ accessory: PixelSprite?, to s: PixelSprite) -> PixelSprite {
        guard let accessory, let top = s.topRow else { return s }
        let columns = (0..<s.width).filter { s[$0, top] != Ink.clear }
        let centre = (columns.first! + columns.last! + 1) / 2
        var out = s
        out.draw(accessory, x: centre - accessory.width / 2, y: top - accessory.height, underOnly: true)
        return out
    }
}

// MARK: - Atlas

/// A 16-tile-wide atlas. Fixed sprites are packed first; the rest is one region per pet slot.
struct SpriteAtlas {
    static let columns = 16
    static let tileSize = 16
    static let regionCount = World.maxSlots
    static let tilesPerRegion = PetAnim.totalFrames * 2

    let width = columns * tileSize
    let height: Int
    private(set) var pixels: [UInt8]
    private(set) var tiles: [StaticSprite: UInt32] = [:]
    /// Tile indices of each pet region: adult frames, then baby frames.
    private(set) var regionTiles: [[UInt32]] = []

    static func build() -> SpriteAtlas {
        var layout: [(StaticSprite, PixelSprite)] = []
        for (i, s) in SpriteArt.ogre.enumerated() { layout.append((.ogre(i), s)) }
        for i in 0..<2 { layout.append((.egg(i), i == 0 ? SpriteArt.egg : wobble(SpriteArt.egg))) }
        layout.append((.egg(2), cracked(SpriteArt.egg)))
        layout.append((.grave, SpriteArt.grave))
        layout.append((.pellet, SpriteArt.pellet))
        for (i, s) in SpriteArt.slime.enumerated() { layout.append((.slime(i), s)) }
        for (i, s) in SpriteArt.bat.enumerated() { layout.append((.bat(i), s)) }
        for (i, s) in SpriteArt.smoke.enumerated() { layout.append((.smoke(i), s)) }
        for kind in IconKind.allCases { layout.append((.icon(kind), shadowed(SpriteArt.icon(kind)))) }
        for item in Item.allCases where item.category == .weapon {
            var tile = PixelSprite(width: 16, height: 16)
            let art = SpriteArt.weapon(item)
            tile.draw(art, x: 8 - art.width / 2, y: 16 - art.height)
            layout.append((.weapon(item), tile))
        }
        layout.append((.chest, SpriteArt.chest))
        layout.append((.bag, SpriteArt.bag))

        // Ogre frames take 2x2 tiles at the start of the first two rows.
        let bigTiles = SpriteArt.ogre.count
        var occupied = Set<Int>()
        for i in 0..<bigTiles {
            let t = i * 2
            occupied.formUnion([t, t + 1, t + columns, t + columns + 1])
        }
        let singles = layout.count - bigTiles + regionCount * tilesPerRegion
        var next = 0
        var singleTiles: [Int] = []
        while singleTiles.count < singles {
            if !occupied.contains(next) { singleTiles.append(next) }
            next += 1
        }
        let rows = (max(next, bigTiles * 2 + columns + 1) + columns - 1) / columns

        var atlas = SpriteAtlas(height: rows * tileSize,
                                pixels: Array(repeating: 0, count: columns * tileSize * rows * tileSize))
        var cursor = 0
        for (key, sprite) in layout {
            let tile: Int
            if case .ogre(let i) = key {
                tile = i * 2
                // 24x24 art, bottom-centred in a 32x32 block.
                var block = PixelSprite(width: 32, height: 32)
                block.draw(sprite, x: 4, y: 8)
                atlas.blit(block, tile: UInt32(tile))
            } else {
                tile = singleTiles[cursor]
                cursor += 1
                atlas.blit(sprite, tile: UInt32(tile))
            }
            atlas.tiles[key] = UInt32(tile)
        }
        for _ in 0..<regionCount {
            atlas.regionTiles.append(singleTiles[cursor..<(cursor + tilesPerRegion)].map(UInt32.init))
            cursor += tilesPerRegion
        }
        return atlas
    }

    private init(height: Int, pixels: [UInt8]) {
        self.height = height
        self.pixels = pixels
    }

    func tile(_ key: StaticSprite) -> UInt32 { tiles[key] ?? 0 }

    func petTile(region: Int, anim: PetAnim, frame: Int, baby: Bool) -> UInt32 {
        let index = (baby ? PetAnim.totalFrames : 0) + anim.offset + frame % anim.frameCount
        return regionTiles[region % regionTiles.count][index]
    }

    /// Composes a pet's frames and writes them into `region`.
    mutating func writePet(region: Int, looks: Looks) {
        let (adult, baby) = PetComposer.frames(for: looks)
        for (i, sprite) in (adult + baby).enumerated() {
            blit(sprite, tile: regionTiles[region][i])
        }
    }

    private mutating func blit(_ sprite: PixelSprite, tile: UInt32) {
        let ox = Int(tile) % Self.columns * Self.tileSize
        let oy = Int(tile) / Self.columns * Self.tileSize
        let size = sprite.width > Self.tileSize ? 2 * Self.tileSize : Self.tileSize
        for y in 0..<size {
            for x in 0..<size {
                pixels[(oy + y) * width + ox + x] = sprite[x, y]
            }
        }
    }

    private static func wobble(_ s: PixelSprite) -> PixelSprite {
        // Lean the top half one pixel to the right.
        s.map { x, y, v in y < 10 ? s[x - 1, y] : v }
    }

    private static func cracked(_ s: PixelSprite) -> PixelSprite {
        var out = s
        for (x, y) in [(4, 8), (5, 9), (6, 8), (7, 9), (8, 8), (9, 9), (10, 8), (11, 9)] where out[x, y] != Ink.outline {
            out[x, y] = Ink.grey
        }
        return out
    }

    private static func shadowed(_ s: PixelSprite) -> PixelSprite {
        var out = PixelSprite(width: 16, height: 16)
        for y in 0..<s.height {
            for x in 0..<s.width where s[x, y] != Ink.clear && s[x + 1, y + 1] == Ink.clear {
                out[x + 1, y + 1] = Ink.outline
            }
        }
        out.draw(s, x: 0, y: 0)
        return out
    }
}

/// Which atlas region each living pet's frames live in.
struct PetSpriteRegions {
    private(set) var assigned: [UUID: Int] = [:]

    /// Gives new pets a region (composing their sprites) and frees the regions of pets that
    /// are gone. Returns true when the atlas pixels changed.
    mutating func sync(pets: [Pet], atlas: inout SpriteAtlas) -> Bool {
        let living = Set(pets.map(\.id))
        assigned = assigned.filter { living.contains($0.key) }
        var changed = false
        for pet in pets where assigned[pet.id] == nil {
            let used = Set(assigned.values)
            let region = (0..<SpriteAtlas.regionCount).first { !used.contains($0) } ?? 0
            atlas.writePet(region: region, looks: pet.looks)
            assigned[pet.id] = region
            changed = true
        }
        return changed
    }

    func region(for id: UUID) -> Int { assigned[id] ?? 0 }
}
