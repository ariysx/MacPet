import Foundation

enum BodyShape: String, Codable, CaseIterable { case blob, bird, cat }
enum Pattern: String, Codable, CaseIterable { case plain, spots, stripes, patch }
enum Accessory: String, Codable, CaseIterable { case none, horns, antenna, crest, leaf, bow }
enum EyeStyle: String, Codable, CaseIterable { case dot, wide, sleepy }

/// Everything about how a pet looks. Sprites are composed from this at hatch.
struct Looks: Codable, Equatable {
    var shape: BodyShape
    var primary: UInt32
    var secondary: UInt32
    var pattern: Pattern
    var accessory: Accessory
    var eyes: EyeStyle
    /// Rare gold mutation.
    var shiny = false

    var summary: String {
        var parts = [shape.rawValue.capitalized]
        if pattern != .plain { parts.append(pattern.rawValue) }
        if accessory != .none { parts.append(accessory.rawValue) }
        if eyes != .dot { parts.append("\(eyes.rawValue) eyes") }
        if shiny { parts.append("shiny") }
        return parts.joined(separator: ", ")
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

/// Hand-picked colour pairs that stay readable on the green landscape.
enum PetPalette {
    static let pairs: [(primary: UInt32, secondary: UInt32)] = [
        (0xF2A65A, 0xFCE3B0), // orange / cream
        (0x7FB7E8, 0xE8F4FF), // sky / ice
        (0xE88BB0, 0xFFE0EC), // pink / blush
        (0xA98BE0, 0xF0E6FF), // lilac / mist
        (0xF5D547, 0xE8904A), // lemon / tangerine
        (0x5E7CE2, 0xF5D547), // blue / lemon
        (0xD9534F, 0xFFD6CC), // red / peach
        (0xF4F1E8, 0xE88BB0), // white / pink
        (0x8A6A52, 0xE8D2B0), // brown / sand
        (0x4DC3C3, 0xFFF1C1), // teal / butter
        (0x6B6B7B, 0xF2A65A), // grey / orange
        (0xFFB3C7, 0x7FB7E8), // candy / sky
    ]
    static let shiny: (primary: UInt32, secondary: UInt32) = (0xFFC933, 0xFFF6C8)

    static func rgba(_ hex: UInt32) -> SIMD4<Float> {
        SIMD4(Float((hex >> 16) & 0xFF) / 255, Float((hex >> 8) & 0xFF) / 255, Float(hex & 0xFF) / 255, 1)
    }

    /// Rotates the hue by `degrees`, keeping saturation and value inside a readable band.
    static func shiftHue(_ hex: UInt32, degrees: Double) -> UInt32 {
        let r = Double((hex >> 16) & 0xFF) / 255, g = Double((hex >> 8) & 0xFF) / 255, b = Double(hex & 0xFF) / 255
        let maxC = max(r, g, b), minC = min(r, g, b), delta = maxC - minC
        var h = 0.0
        if delta > 0 {
            if maxC == r { h = 60 * ((g - b) / delta).truncatingRemainder(dividingBy: 6) }
            else if maxC == g { h = 60 * ((b - r) / delta + 2) }
            else { h = 60 * ((r - g) / delta + 4) }
        }
        let s = maxC == 0 ? 0 : delta / maxC
        let v = min(0.98, max(0.4, maxC))
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

enum Genetics {
    /// Chance per gene of mutating when an egg is laid.
    static let shapeMutation = 0.08
    static let colourJump = 0.10
    static let patternMutation = 0.15
    static let accessoryMutation = 0.15
    static let eyeMutation = 0.10
    static let traitMutation = 0.20
    static let shinyMutation = 0.02
    static let shinyInheritance = 0.25

    /// A brand-new pet with no parent: first egg, graveyard eggs, and the "never empty" egg.
    static func random<R: RandomSource>(_ random: inout R) -> Genes {
        let pair = random.pick(PetPalette.pairs)
        let looks = Looks(shape: random.pick(BodyShape.allCases),
                          primary: pair.primary,
                          secondary: pair.secondary,
                          pattern: random.chance(0.4) ? .plain : random.pick(Pattern.allCases),
                          accessory: random.chance(0.4) ? .none : random.pick(Accessory.allCases),
                          eyes: random.pick(EyeStyle.allCases),
                          shiny: random.chance(shinyMutation))
        return Genes(traits: .roll(&random), looks: looks, generation: 1, parentName: nil, mutations: [])
    }

    /// The genome of an egg laid by `parent`: a copy with a few mutations.
    static func inherit<R: RandomSource>(from parent: Pet, generation: Int, _ random: inout R) -> Genes {
        var looks = parent.looks
        var traits = parent.traits
        var mutations: [String] = []

        if random.chance(shapeMutation) {
            let others = BodyShape.allCases.filter { $0 != looks.shape }
            looks.shape = random.pick(others)
            mutations.append(looks.shape.rawValue)
        }
        if random.chance(colourJump) {
            let pair = random.pick(PetPalette.pairs)
            looks.primary = pair.primary
            looks.secondary = pair.secondary
            mutations.append("new colours")
        } else {
            // Small drift every generation, so lines of descent slowly change colour.
            let drift = random.double(in: -18...18)
            looks.primary = PetPalette.shiftHue(looks.primary, degrees: drift)
            looks.secondary = PetPalette.shiftHue(looks.secondary, degrees: drift * 0.5)
        }
        if random.chance(patternMutation) {
            looks.pattern = random.pick(Pattern.allCases.filter { $0 != looks.pattern })
            mutations.append(looks.pattern.rawValue)
        }
        if random.chance(accessoryMutation) {
            looks.accessory = random.pick(Accessory.allCases.filter { $0 != looks.accessory })
            mutations.append(looks.accessory == .none ? "lost \(parent.looks.accessory.rawValue)" : looks.accessory.rawValue)
        }
        if random.chance(eyeMutation) {
            looks.eyes = random.pick(EyeStyle.allCases.filter { $0 != looks.eyes })
            mutations.append("\(looks.eyes.rawValue) eyes")
        }
        let wasShiny = looks.shiny
        looks.shiny = wasShiny ? random.chance(shinyInheritance) : random.chance(shinyMutation)
        if looks.shiny && !wasShiny { mutations.append("shiny") }

        let fresh = Traits.roll(&random)
        if random.chance(traitMutation) { traits.appetite = fresh.appetite }
        if random.chance(traitMutation) { traits.affection = fresh.affection }
        if random.chance(traitMutation) { traits.vigor = fresh.vigor }
        if random.chance(traitMutation) { traits.courage = fresh.courage }
        if random.chance(traitMutation) { traits.sociality = fresh.sociality }
        let changed = zip(parent.traits.names, traits.names).filter { $0 != $1 }.map(\.1)
        mutations += changed

        return Genes(traits: traits, looks: looks, generation: generation, parentName: parent.name, mutations: mutations)
    }
}
