import Foundation

// Long-term goals: pet levels from fights, and the Petdex of every look found.

extension Pet {
    static let maxLevel = 20

    /// Experience needed to reach `level` from level 1: 20, 60, 120, 200, ...
    static func xpNeeded(forLevel level: Int) -> Double {
        let n = Double(max(1, level) - 1)
        return 10 * n * (n + 1)
    }

    var level: Int {
        var l = 1
        while l < Pet.maxLevel && xp >= Pet.xpNeeded(forLevel: l + 1) { l += 1 }
        return l
    }

    /// 0...1 through the current level.
    var levelProgress: Double {
        let l = level
        guard l < Pet.maxLevel else { return 1 }
        let lo = Pet.xpNeeded(forLevel: l), hi = Pet.xpNeeded(forLevel: l + 1)
        return min(1, max(0, (xp - lo) / (hi - lo)))
    }
}

/// One thing the Petdex can record.
enum DexEntry: Hashable {
    case shape(BodyShape), pattern(Pattern), accessory(Accessory), eyes(EyeStyle), colour(String)

    var key: String {
        switch self {
        case .shape(let s): return "shape." + s.rawValue
        case .pattern(let p): return "pattern." + p.rawValue
        case .accessory(let a): return "accessory." + a.rawValue
        case .eyes(let e): return "eyes." + e.rawValue
        case .colour(let c): return "colour." + c
        }
    }

    var title: String {
        switch self {
        case .shape(let s): return s.title
        case .pattern(let p): return p.rawValue + " pattern"
        case .accessory(let a): return a == .none ? "no hat" : a.rawValue
        case .eyes(let e): return e.rawValue + " eyes"
        case .colour(let c): return c
        }
    }

    var rarity: Rarity {
        switch self {
        case .shape(let s): return s.rarity
        case .pattern(let p): return p.rarity
        case .accessory(let a): return a.rarity
        case .eyes(let e): return e.rarity
        case .colour(let c): return PetPalette.colourways.first { $0.name == c }?.rarity ?? .common
        }
    }

    static func entries(for looks: Looks) -> [DexEntry] {
        [.shape(looks.shape), .colour(looks.colourName), .pattern(looks.pattern), .accessory(looks.accessory), .eyes(looks.eyes)]
    }

    /// The Petdex's sections, in display order.
    static let sections: [(title: String, entries: [DexEntry])] = [
        ("ANIMALS", BodyShape.allCases.map { .shape($0) }),
        ("COLOURS", PetPalette.colourways.map { .colour($0.name) }),
        ("PATTERNS", Pattern.allCases.map { .pattern($0) }),
        ("HATS", Accessory.allCases.map { .accessory($0) }),
        ("EYES", EyeStyle.allCases.map { .eyes($0) }),
    ]

    static let total = sections.reduce(0) { $0 + $1.entries.count }
}

extension World {
    /// Every this many Petdex entries drops a reward chest.
    static let dexMilestone = 8

    mutating func gainXP(petIndex i: Int, _ amount: Double) {
        let before = pets[i].level
        pets[i].xp += amount
        let after = pets[i].level
        if after > before {
            pets[i].health = min(Pet.maxNeed, pets[i].health + 20)
            pets[i].excitedRemaining = 20
            events.append(.levelUp(name: pets[i].name, level: after))
        }
    }

    func knows(_ entry: DexEntry) -> Bool { dex.contains(entry.key) }

    /// Records a pet's looks. New finds are announced; every `dexMilestone` finds drops a chest.
    /// `quiet` records without events or rewards, for saves made before the Petdex existed.
    mutating func discover(_ looks: Looks, name: String, quiet: Bool = false) {
        let new = DexEntry.entries(for: looks).filter { !knows($0) }
        guard !new.isEmpty else { return }
        dex.append(contentsOf: new.map(\.key))
        if quiet {
            dexRewards = max(dexRewards, dex.count / World.dexMilestone)
            return
        }
        events.append(.discovered(name: name, entries: new.map(\.title)))
        while dexRewards < dex.count / World.dexMilestone {
            dexRewards += 1
            let x = random.double(in: 40...(World.width - 40))
            loot.append(Loot(id: UUID(), kind: .reward, x: x, items: LootTable.dexReward(&random)))
            events.append(.dexReward(found: dex.count))
        }
    }

    /// Fills the Petdex from the pets alive and remembered, quietly.
    mutating func syncDex() {
        for pet in pets { discover(pet.looks, name: pet.name, quiet: true) }
        for entry in graveyard { discover(entry.looks, name: entry.name, quiet: true) }
    }
}
