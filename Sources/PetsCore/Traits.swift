import Foundation

enum Appetite: String, Codable, CaseIterable { case greedy, picky }
enum Affection: String, Codable, CaseIterable { case cuddly, aloof }
enum Vigor: String, Codable, CaseIterable { case energetic, lazy }
enum Courage: String, Codable, CaseIterable { case brave, timid }
enum Sociality: String, Codable, CaseIterable { case social, loner }

/// One trait from each pair, rolled at hatch. All numeric effects live here.
struct Traits: Codable, Equatable {
    var appetite: Appetite
    var affection: Affection
    var vigor: Vigor
    var courage: Courage
    var sociality: Sociality

    static func roll<R: RandomSource>(_ random: inout R) -> Traits {
        Traits(appetite: random.pick(Appetite.allCases),
               affection: random.pick(Affection.allCases),
               vigor: random.pick(Vigor.allCases),
               courage: random.pick(Courage.allCases),
               sociality: random.pick(Sociality.allCases))
    }

    var names: [String] {
        [appetite.rawValue, affection.rawValue, vigor.rawValue, courage.rawValue, sociality.rawValue]
            .map { $0.prefix(1).uppercased() + $0.dropFirst() }
    }

    // MARK: Greedy / Picky

    var hungerDecayMultiplier: Double { appetite == .greedy ? 1.3 : 1.0 }
    var pelletValue: Double { appetite == .picky ? 40 : 30 }

    // MARK: Cuddly / Aloof

    var pettingMultiplier: Double { affection == .cuddly ? 1.5 : 0.5 }
    var happinessDecayMultiplier: Double { affection == .cuddly ? 1.2 : 0.7 }

    // MARK: Energetic / Lazy

    var walkSpeedMultiplier: Double { vigor == .energetic ? 1.5 : 0.6 }
    var energyDecayMultiplier: Double { vigor == .energetic ? 1.4 : 0.7 }
    /// Seconds between hits in a fight.
    var attackInterval: Double { vigor == .energetic ? 1.15 : 1.5 }
    /// Energy below which the pet naps when nothing is happening.
    var calmNapThreshold: Double { vigor == .lazy ? 50 : 25 }

    // MARK: Brave / Timid

    /// Happiness change for every 10 s spent held.
    var heldHappinessPer10s: Double { courage == .brave ? 2 : -3 }

    // MARK: Social / Loner

    static let socialRange: Double = 60
    static let lonerRange: Double = 30
    static let socialAttackMultiplier: Double = 1.2
}

enum PetNames {
    static let syllables = ["mo", "po", "ki", "ri", "ta", "bu", "lu", "ne", "pi", "zo", "fa", "mi",
                            "ko", "su", "ba", "do", "ru", "yo", "chi", "pa", "ni", "wu", "te", "lo"]

    static func make<R: RandomSource>(_ random: inout R, avoiding taken: Set<String>) -> String {
        var name = ""
        for _ in 0..<64 {
            let raw = random.pick(syllables) + random.pick(syllables)
            name = raw.prefix(1).uppercased() + raw.dropFirst()
            if !taken.contains(name) { return name }
        }
        return name
    }
}
