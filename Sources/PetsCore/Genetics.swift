import Foundation

enum Rarity: Int, Codable, CaseIterable, Comparable {
    case common, uncommon, rare, epic, legendary

    static func < (a: Rarity, b: Rarity) -> Bool { a.rawValue < b.rawValue }

    /// Relative chance of a roll landing on this tier.
    var weight: Double {
        switch self {
        case .common: return 100
        case .uncommon: return 35
        case .rare: return 12
        case .epic: return 4
        case .legendary: return 1
        }
    }

    var title: String { String(describing: self).capitalized }
    var stars: String { String(repeating: "★", count: rawValue + 1) }
}

/// Anything with a rarity that can be rolled by weight.
protocol RarityRanked: CaseIterable, Equatable {
    var rarity: Rarity { get }
}

extension RarityRanked {
    /// A weighted roll over `options`, each weighted by its tier.
    static func roll<R: RandomSource>(_ random: inout R, from options: [Self] = Array(allCases),
                                      atLeast minimum: Rarity = .common) -> Self {
        var pool = options.filter { $0.rarity >= minimum }
        if pool.isEmpty { pool = options }
        let total = pool.reduce(0) { $0 + $1.rarity.weight }
        var r = random.nextDouble() * total
        for option in pool {
            r -= option.rarity.weight
            if r < 0 { return option }
        }
        return pool[pool.count - 1]
    }

    /// A weighted roll that never returns `current`.
    static func mutate<R: RandomSource>(_ random: inout R, from current: Self, atLeast minimum: Rarity = .common) -> Self {
        roll(&random, from: Array(allCases).filter { $0 != current }, atLeast: minimum)
    }
}

enum BodyShape: String, Codable, CaseIterable, RarityRanked {
    // The rarer the tier, the more mythical the animal.
    case blob, bird, cat, mouse, pig, duck
    case hamster, puppy, chick, sheep, snail
    case bunny, frog, bear, deer, hedgehog, penguin, turtle
    case koala, panda, squirrel, otter, goat, seal
    case ghost, fox, owl, raccoon, axolotl
    case redPanda, lion, chameleon, pangolin, fruitBat, peacock
    case dragon
    case kitsune, griffin, pegasus, jackalope, qilin, mothkin, wyvern
    case unicorn
    case phoenix, spiritStag, skyWhale, thunderbird, sphinx, cerberus

    var rarity: Rarity {
        switch self {
        case .blob, .bird, .cat, .mouse, .pig, .duck,
             .hamster, .puppy, .chick, .sheep, .snail: return .common
        case .bunny, .frog, .bear, .deer, .hedgehog, .penguin, .turtle,
             .koala, .panda, .squirrel, .otter, .goat, .seal: return .uncommon
        case .ghost, .fox, .owl, .raccoon, .axolotl,
             .redPanda, .lion, .chameleon, .pangolin, .fruitBat, .peacock: return .rare
        case .dragon, .kitsune, .griffin, .pegasus, .jackalope, .qilin, .mothkin, .wyvern: return .epic
        case .unicorn, .phoenix, .spiritStag, .skyWhale, .thunderbird, .sphinx, .cerberus: return .legendary
        }
    }

    /// Display name: "red panda" rather than "redPanda".
    var title: String {
        rawValue.reduce(into: "") { out, c in
            if c.isUppercase { out += " " + c.lowercased() } else { out.append(c) }
        }
    }
}

enum Pattern: String, Codable, CaseIterable, RarityRanked {
    case plain, spots, stripes, patch, socks, tips, twoTone, checker, speckle, heart, stars, rainbow

    var rarity: Rarity {
        switch self {
        case .plain, .spots, .stripes, .patch: return .common
        case .socks, .tips, .twoTone: return .uncommon
        case .checker, .speckle: return .rare
        case .heart, .stars: return .epic
        case .rainbow: return .legendary
        }
    }
}

enum Accessory: String, Codable, CaseIterable, RarityRanked {
    case none, leaf, bow, antenna, horns, crest, flower, sprout, tophat, cap, mushroom, unihorn, crown, halo, flame

    var rarity: Rarity {
        switch self {
        case .none, .leaf, .bow: return .common
        case .antenna, .horns, .crest, .flower, .sprout: return .uncommon
        case .tophat, .cap, .mushroom: return .rare
        case .unihorn, .crown: return .epic
        case .halo, .flame: return .legendary
        }
    }
}

enum EyeStyle: String, Codable, CaseIterable, RarityRanked {
    case dot, wide, sleepy, happy, sparkly, angry, cyclops, hearts, starry

    var rarity: Rarity {
        switch self {
        case .dot, .wide, .sleepy: return .common
        case .happy, .sparkly, .angry: return .uncommon
        case .cyclops: return .rare
        case .hearts: return .epic
        case .starry: return .legendary
        }
    }
}

/// A named colour pair. Pairs are grouped by rarity.
struct Colourway: Equatable {
    var name: String
    var primary: UInt32
    var secondary: UInt32
    var rarity: Rarity
}

enum PetPalette {
    /// Hand-picked pairs that stay readable on the green landscape.
    static let colourways: [Colourway] = [
        Colourway(name: "orange", primary: 0xF2A65A, secondary: 0xFCE3B0, rarity: .common),
        Colourway(name: "sky", primary: 0x7FB7E8, secondary: 0xE8F4FF, rarity: .common),
        Colourway(name: "pink", primary: 0xE88BB0, secondary: 0xFFE0EC, rarity: .common),
        Colourway(name: "lilac", primary: 0xA98BE0, secondary: 0xF0E6FF, rarity: .common),
        Colourway(name: "lemon", primary: 0xF5D547, secondary: 0xE8904A, rarity: .common),
        Colourway(name: "blue", primary: 0x5E7CE2, secondary: 0xF5D547, rarity: .common),
        Colourway(name: "red", primary: 0xD9534F, secondary: 0xFFD6CC, rarity: .common),
        Colourway(name: "snow", primary: 0xF4F1E8, secondary: 0xE88BB0, rarity: .common),
        Colourway(name: "cocoa", primary: 0x8A6A52, secondary: 0xE8D2B0, rarity: .common),
        Colourway(name: "teal", primary: 0x4DC3C3, secondary: 0xFFF1C1, rarity: .common),
        Colourway(name: "slate", primary: 0x6B6B7B, secondary: 0xF2A65A, rarity: .common),
        Colourway(name: "candy", primary: 0xFFB3C7, secondary: 0x7FB7E8, rarity: .common),
        Colourway(name: "coral", primary: 0xFF7F6E, secondary: 0xFFE3B3, rarity: .uncommon),
        Colourway(name: "mint", primary: 0x7FE0B5, secondary: 0xF5FFF9, rarity: .uncommon),
        Colourway(name: "peach", primary: 0xFFC2A1, secondary: 0x9A5BC4, rarity: .uncommon),
        Colourway(name: "midnight", primary: 0x34407A, secondary: 0x9FB4FF, rarity: .rare),
        Colourway(name: "plum", primary: 0x7D3C6E, secondary: 0xF2A6D8, rarity: .rare),
        Colourway(name: "sunset", primary: 0xFF9E5E, secondary: 0xB65FCF, rarity: .rare),
        Colourway(name: "obsidian", primary: 0x2F2A3A, secondary: 0xE84A5F, rarity: .epic),
        Colourway(name: "frost", primary: 0xD8F3FF, secondary: 0x6FA8DC, rarity: .epic),
        Colourway(name: "gold", primary: 0xFFC933, secondary: 0xFFF6C8, rarity: .legendary),
        Colourway(name: "prism", primary: 0xE0B0FF, secondary: 0x9FFFE0, rarity: .legendary),
    ]

    static func roll<R: RandomSource>(_ random: inout R, atLeast minimum: Rarity = .common,
                                      excluding current: String? = nil) -> Colourway {
        var pool = colourways.filter { $0.rarity >= minimum && $0.name != current }
        if pool.isEmpty { pool = colourways }
        let total = pool.reduce(0) { $0 + $1.rarity.weight }
        var r = random.nextDouble() * total
        for c in pool {
            r -= c.rarity.weight
            if r < 0 { return c }
        }
        return pool[pool.count - 1]
    }

    static func rgba(_ hex: UInt32) -> SIMD4<Float> {
        SIMD4(Float((hex >> 16) & 0xFF) / 255, Float((hex >> 8) & 0xFF) / 255, Float(hex & 0xFF) / 255, 1)
    }

    /// Rotates the hue by `degrees`, keeping saturation and value inside a readable band.
    static func shiftHue(_ hex: UInt32, degrees: Double) -> UInt32 {
        let r = Double((hex >> 16) & 0xFF) / 255, g = Double((hex >> 8) & 0xFF) / 255, b = Double(hex & 0xFF) / 255
        let maxC = max(r, g, b), minC = min(r, g, b), delta = maxC - minC
        guard delta > 0 else { return hex }
        var h: Double
        if maxC == r { h = 60 * ((g - b) / delta).truncatingRemainder(dividingBy: 6) }
        else if maxC == g { h = 60 * ((b - r) / delta + 2) }
        else { h = 60 * ((r - g) / delta + 4) }
        let s = delta / maxC
        let v = min(0.98, max(0.25, maxC))
        h = (h + degrees).truncatingRemainder(dividingBy: 360)
        if h < 0 { h += 360 }
        let c = v * s, x = c * (1 - abs((h / 60).truncatingRemainder(dividingBy: 2) - 1)), m = v - c
        let (r1, g1, b1): (Double, Double, Double)
        switch h {
        case ..<60: (r1, g1, b1) = (c, x, 0)
        case ..<120: (r1, g1, b1) = (x, c, 0)
        case ..<180: (r1, g1, b1) = (0, c, x)
        case ..<240: (r1, g1, b1) = (0, x, c)
        case ..<300: (r1, g1, b1) = (x, 0, c)
        default: (r1, g1, b1) = (c, 0, x)
        }
        func byte(_ v: Double) -> UInt32 { UInt32(max(0, min(255, ((v + m) * 255).rounded()))) }
        return byte(r1) << 16 | byte(g1) << 8 | byte(b1)
    }
}

/// Everything about how a pet looks. Sprites are composed from this at hatch.
struct Looks: Codable, Equatable {
    var shape: BodyShape
    var colourName: String
    var colourRarity: Rarity
    var primary: UInt32
    var secondary: UInt32
    var pattern: Pattern
    var accessory: Accessory
    var eyes: EyeStyle

    init(shape: BodyShape, colourway: Colourway, pattern: Pattern, accessory: Accessory, eyes: EyeStyle) {
        self.shape = shape
        colourName = colourway.name
        colourRarity = colourway.rarity
        primary = colourway.primary
        secondary = colourway.secondary
        self.pattern = pattern
        self.accessory = accessory
        self.eyes = eyes
    }

    /// The rarest thing about this pet.
    var rarity: Rarity {
        [shape.rarity, colourRarity, pattern.rarity, accessory.rarity, eyes.rarity].max()!
    }

    var summary: String {
        var parts = ["\(colourName.capitalized) \(shape.title)"]
        if pattern != .plain { parts.append(Self.words(pattern.rawValue)) }
        if accessory != .none { parts.append(Self.words(accessory.rawValue)) }
        if eyes != .dot { parts.append("\(Self.words(eyes.rawValue)) eyes") }
        return parts.joined(separator: ", ")
    }

    /// "twoTone" -> "two tone"
    static func words(_ camel: String) -> String {
        camel.reduce(into: "") { out, c in
            if c.isUppercase { out += " " + c.lowercased() } else { out.append(c) }
        }
    }
}

/// What an egg carries: a full genome, plus where it came from.
struct Genes: Codable, Equatable {
    var traits: Traits
    var looks: Looks
    var generation: Int
    var parentName: String?
    /// Human-readable list of what changed from the parent, e.g. ["horns", "Timid"].
    var mutations: [String]
}

enum Genetics {
    /// Chance per gene of mutating when an egg is laid.
    static let shapeMutation = 0.08
    static let colourJump = 0.10
    static let patternMutation = 0.15
    static let accessoryMutation = 0.15
    static let eyeMutation = 0.10
    static let traitMutation = 0.20

    /// A brand-new pet with no parent: first egg, graveyard eggs, and the "never empty" egg.
    static func random<R: RandomSource>(_ random: inout R) -> Genes {
        let looks = Looks(shape: .roll(&random),
                          colourway: PetPalette.roll(&random),
                          pattern: random.chance(0.35) ? .plain : .roll(&random),
                          accessory: random.chance(0.35) ? .none : .roll(&random),
                          eyes: .roll(&random))
        return Genes(traits: .roll(&random), looks: looks, generation: 1, parentName: nil, mutations: [])
    }

    /// The genome of an egg laid by `parent`: a copy with a few mutations.
    static func inherit<R: RandomSource>(from parent: Pet, generation: Int, _ random: inout R) -> Genes {
        var genes = Genes(traits: parent.traits, looks: parent.looks, generation: generation,
                          parentName: parent.name, mutations: [])
        mutateLooks(&genes, random: &random, chances: 1)

        // Small colour drift every generation, so lines of descent slowly change.
        if genes.looks.colourName == parent.looks.colourName {
            let drift = random.double(in: -18...18)
            genes.looks.primary = PetPalette.shiftHue(genes.looks.primary, degrees: drift)
            genes.looks.secondary = PetPalette.shiftHue(genes.looks.secondary, degrees: drift * 0.5)
        }

        let fresh = Traits.roll(&random)
        var traits = parent.traits
        if random.chance(traitMutation) { traits.appetite = fresh.appetite }
        if random.chance(traitMutation) { traits.affection = fresh.affection }
        if random.chance(traitMutation) { traits.vigor = fresh.vigor }
        if random.chance(traitMutation) { traits.courage = fresh.courage }
        if random.chance(traitMutation) { traits.sociality = fresh.sociality }
        genes.traits = traits
        genes.mutations += zip(parent.traits.names, traits.names).filter { $0 != $1 }.map(\.1)
        return genes
    }

    /// Mutagen potion: at least one guaranteed mutation, rare or better.
    static func mutagen<R: RandomSource>(_ genes: Genes, _ random: inout R) -> Genes {
        var out = genes
        out.mutations = []
        mutateLooks(&out, random: &random, chances: 1.5)
        // The guaranteed one goes last so nothing overwrites it.
        switch random.int(below: 5) {
        case 0:
            out.looks.shape = .mutate(&random, from: out.looks.shape, atLeast: .rare)
            out.mutations.append(out.looks.shape.rawValue)
        case 1:
            let c = PetPalette.roll(&random, atLeast: .rare, excluding: out.looks.colourName)
            out.looks.primary = c.primary
            out.looks.secondary = c.secondary
            out.looks.colourName = c.name
            out.looks.colourRarity = c.rarity
            out.mutations.append("\(c.name) colours")
        case 2:
            out.looks.pattern = .mutate(&random, from: out.looks.pattern, atLeast: .rare)
            out.mutations.append(Looks.words(out.looks.pattern.rawValue))
        case 3:
            out.looks.accessory = .mutate(&random, from: out.looks.accessory, atLeast: .rare)
            out.mutations.append(Looks.words(out.looks.accessory.rawValue))
        default:
            out.looks.eyes = .mutate(&random, from: out.looks.eyes, atLeast: .rare)
            out.mutations.append("\(Looks.words(out.looks.eyes.rawValue)) eyes")
        }
        return out
    }

    private static func mutateLooks<R: RandomSource>(_ genes: inout Genes, random: inout R, chances k: Double) {
        if random.chance(shapeMutation * k) {
            genes.looks.shape = .mutate(&random, from: genes.looks.shape)
            genes.mutations.append(genes.looks.shape.rawValue)
        }
        if random.chance(colourJump * k) {
            let c = PetPalette.roll(&random, excluding: genes.looks.colourName)
            genes.looks.primary = c.primary
            genes.looks.secondary = c.secondary
            genes.looks.colourName = c.name
            genes.looks.colourRarity = c.rarity
            genes.mutations.append("\(c.name) colours")
        }
        if random.chance(patternMutation * k) {
            genes.looks.pattern = .mutate(&random, from: genes.looks.pattern)
            genes.mutations.append(Looks.words(genes.looks.pattern.rawValue))
        }
        if random.chance(accessoryMutation * k) {
            let old = genes.looks.accessory
            genes.looks.accessory = .mutate(&random, from: old)
            genes.mutations.append(genes.looks.accessory == .none ? "lost \(Looks.words(old.rawValue))"
                                                                  : Looks.words(genes.looks.accessory.rawValue))
        }
        if random.chance(eyeMutation * k) {
            genes.looks.eyes = .mutate(&random, from: genes.looks.eyes)
            genes.mutations.append("\(Looks.words(genes.looks.eyes.rawValue)) eyes")
        }
    }
}
