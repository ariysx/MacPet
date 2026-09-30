import Foundation

enum ItemCategory: String, Codable, CaseIterable {
    case weapon, relic, potion

    var title: String {
        switch self {
        case .weapon: return "Weapons"
        case .relic: return "Relics"
        case .potion: return "Potions"
        }
    }
}

/// Weapons and relics are equipped by one pet at a time. Potions are used up.
enum Item: String, Codable, CaseIterable, RarityRanked {
    // Weapons
    case stick, woodenSword, slingshot, ironSword, magicWand, dragonFang
    // Relics
    case featherCharm, cozyScarf, snackPouch, moonPillow, guardianShell, heartLocket, luckyClover, phoenixFeather
    // Potions
    case snack, tonic, joyJuice, espresso, antidote, strengthPotion, couragePotion, hatchElixir, elixir, mutagen

    var category: ItemCategory {
        switch self {
        case .stick, .woodenSword, .slingshot, .ironSword, .magicWand, .dragonFang: return .weapon
        case .featherCharm, .cozyScarf, .snackPouch, .moonPillow, .guardianShell, .heartLocket,
             .luckyClover, .phoenixFeather: return .relic
        default: return .potion
        }
    }

    var rarity: Rarity {
        switch self {
        case .stick, .featherCharm, .cozyScarf, .snack, .tonic: return .common
        case .woodenSword, .slingshot, .snackPouch, .moonPillow, .joyJuice, .espresso, .antidote: return .uncommon
        case .ironSword, .guardianShell, .heartLocket, .strengthPotion, .couragePotion, .hatchElixir: return .rare
        case .magicWand, .luckyClover, .elixir: return .epic
        case .dragonFang, .phoenixFeather, .mutagen: return .legendary
        }
    }

    var title: String {
        switch self {
        case .stick: return "Stick"
        case .woodenSword: return "Wooden Sword"
        case .slingshot: return "Slingshot"
        case .ironSword: return "Iron Sword"
        case .magicWand: return "Magic Wand"
        case .dragonFang: return "Dragon Fang"
        case .featherCharm: return "Feather Charm"
        case .cozyScarf: return "Cozy Scarf"
        case .snackPouch: return "Snack Pouch"
        case .moonPillow: return "Moon Pillow"
        case .guardianShell: return "Guardian Shell"
        case .heartLocket: return "Heart Locket"
        case .luckyClover: return "Lucky Clover"
        case .phoenixFeather: return "Phoenix Feather"
        case .snack: return "Snack"
        case .tonic: return "Tonic"
        case .joyJuice: return "Joy Juice"
        case .espresso: return "Espresso"
        case .antidote: return "Antidote"
        case .strengthPotion: return "Strength Potion"
        case .couragePotion: return "Courage Potion"
        case .hatchElixir: return "Hatch Elixir"
        case .elixir: return "Elixir"
        case .mutagen: return "Mutagen"
        }
    }

    var blurb: String {
        switch self {
        case .stick: return "+1 attack"
        case .woodenSword: return "+2 attack"
        case .slingshot: return "+1.5 attack, hits 15% faster"
        case .ironSword: return "+3 attack"
        case .magicWand: return "+4 attack, hits 15% faster"
        case .dragonFang: return "+6 attack"
        case .featherCharm: return "walks 25% faster"
        case .cozyScarf: return "happiness fades 25% slower"
        case .snackPouch: return "hunger fades 25% slower"
        case .moonPillow: return "sleep restores 50% more energy"
        case .guardianShell: return "takes 40% less monster damage"
        case .heartLocket: return "heals twice as fast"
        case .luckyClover: return "better loot from fights it wins"
        case .phoenixFeather: return "once, comes back from death"
        case .snack: return "+40 hunger"
        case .tonic: return "+30 health"
        case .joyJuice: return "+40 happiness"
        case .espresso: return "+50 energy, wakes up"
        case .antidote: return "cures sickness"
        case .strengthPotion: return "1.5x attack for 10 min"
        case .couragePotion: return "acts Brave for 10 min"
        case .hatchElixir: return "hatches an egg now"
        case .elixir: return "all needs and health to full"
        case .mutagen: return "gives an egg a rare mutation"
        }
    }

    /// Potions that are used on an egg rather than a pet.
    var targetsEgg: Bool { self == .hatchElixir || self == .mutagen }

    // MARK: Weapon stats

    var attackBonus: Double {
        switch self {
        case .stick: return 1
        case .woodenSword: return 2
        case .slingshot: return 1.5
        case .ironSword: return 3
        case .magicWand: return 4
        case .dragonFang: return 6
        default: return 0
        }
    }

    var attackIntervalMultiplier: Double {
        self == .slingshot || self == .magicWand ? 0.85 : 1
    }
}

enum BuffKind: String, Codable, CaseIterable {
    case strength, courage
}

struct Buff: Codable, Equatable {
    var kind: BuffKind
    var remaining: Double
}

/// A loot bag dropped by a beaten monster, or the daily chest.
struct Loot: Codable, Identifiable, Equatable {
    enum Kind: String, Codable { case bag, dailyChest }

    var id: UUID
    var kind: Kind
    var x: Double
    var items: [Item]
    var age: Double = 0

    /// Loot bags collect themselves after this long, so nothing is lost outside play mode.
    static let bagAutoCollect: Double = 90
}

enum LootTable {
    /// Items from beating a monster. A Lucky Clover on a winner adds a roll and raises the floor.
    static func monsterLoot<R: RandomSource>(_ kind: MonsterKind, lucky: Bool, _ random: inout R) -> [Item] {
        var items: [Item] = []
        switch kind {
        case .slime:
            items.append(.roll(&random, from: Item.allCases.filter { $0.category == .potion }))
            if random.chance(0.25) { items.append(.roll(&random)) }
        case .bat:
            items.append(.roll(&random))
            items.append(.roll(&random, from: Item.allCases.filter { $0.category == .potion }))
        case .ogre:
            items.append(.roll(&random, from: Item.allCases.filter { $0.category != .potion }, atLeast: .rare))
            items.append(.roll(&random))
            items.append(.roll(&random))
        }
        if lucky {
            items.append(.roll(&random, atLeast: .uncommon))
        }
        return items
    }

    /// The daily chest: three rolls, at least one uncommon or better.
    static func dailyChest<R: RandomSource>(_ random: inout R) -> [Item] {
        [.roll(&random, atLeast: .uncommon), .roll(&random), .roll(&random)]
    }
}

// MARK: - World: bag, equipment, potions, loot

extension World {
    static let buffDuration: Double = 600

    func count(of item: Item) -> Int { inventory[item] ?? 0 }

    mutating func addToInventory(_ items: [Item]) {
        for item in items { inventory[item, default: 0] += 1 }
    }

    private mutating func takeFromInventory(_ item: Item) -> Bool {
        guard let n = inventory[item], n > 0 else { return false }
        inventory[item] = n > 1 ? n - 1 : nil
        return true
    }

    /// Equips a weapon or relic from the bag. Whatever was in that slot goes back to the bag.
    @discardableResult
    mutating func equip(_ item: Item, onPet id: UUID) -> Bool {
        guard item.category != .potion, let i = petIndex(id), takeFromInventory(item) else { return false }
        if item.category == .weapon {
            if let old = pets[i].weapon { addToInventory([old]) }
            pets[i].weapon = item
        } else {
            if let old = pets[i].relic { addToInventory([old]) }
            pets[i].relic = item
        }
        return true
    }

    mutating func unequip(_ category: ItemCategory, fromPet id: UUID) {
        guard let i = petIndex(id) else { return }
        switch category {
        case .weapon:
            if let old = pets[i].weapon { addToInventory([old]) }
            pets[i].weapon = nil
        case .relic:
            if let old = pets[i].relic { addToInventory([old]) }
            pets[i].relic = nil
        case .potion:
            break
        }
    }

    /// Drinks a potion. Returns false if the potion is missing or does nothing for a pet.
    @discardableResult
    mutating func use(_ item: Item, onPet id: UUID) -> Bool {
        guard item.category == .potion, !item.targetsEgg, let i = petIndex(id), count(of: item) > 0 else { return false }
        _ = takeFromInventory(item)
        switch item {
        case .snack: pets[i].hunger += 40
        case .tonic: pets[i].health += 30
        case .joyJuice: pets[i].happiness += 40
        case .espresso:
            pets[i].energy += 50
            pets[i].sleep = .awake
        case .antidote:
            pets[i].sickRemaining = 0
            pets[i].overfeedTimes = []
        case .strengthPotion: pets[i].addBuff(.strength, seconds: World.buffDuration)
        case .couragePotion: pets[i].addBuff(.courage, seconds: World.buffDuration)
        case .elixir:
            pets[i].hunger = 100
            pets[i].happiness = 100
            pets[i].energy = 100
            pets[i].health = 100
            pets[i].sickRemaining = 0
        default: break
        }
        pets[i].excitedRemaining = 20
        pets[i].clampNeeds()
        pets[i].feeling = Feelings.resolve(pets[i])
        return true
    }

    @discardableResult
    mutating func use(_ item: Item, onEgg id: UUID) -> Bool {
        guard item.targetsEgg, let e = eggs.firstIndex(where: { $0.id == id }), count(of: item) > 0 else { return false }
        _ = takeFromInventory(item)
        switch item {
        case .hatchElixir:
            eggs[e].elapsed = eggs[e].duration
        case .mutagen:
            eggs[e].genes = Genetics.mutagen(eggs[e].genes, &random)
            eggs[e].mutated = true
        default: break
        }
        return true
    }

    /// Picks up a loot bag or opens the daily chest.
    @discardableResult
    mutating func collectLoot(id: UUID) -> [Item] {
        guard let l = loot.firstIndex(where: { $0.id == id }) else { return [] }
        let found = loot.remove(at: l)
        addToInventory(found.items)
        events.append(.lootCollected(found.items, fromChest: found.kind == .dailyChest))
        return found.items
    }

    mutating func updateLoot(dt: Double) {
        for l in loot.indices { loot[l].age += dt }
        for bag in loot where bag.kind == .bag && bag.age >= Loot.bagAutoCollect {
            collectLoot(id: bag.id)
        }

        // One daily chest per calendar day the app runs.
        let today = World.dayKey(now())
        if today != lastDailyChestDay && !loot.contains(where: { $0.kind == .dailyChest }) {
            lastDailyChestDay = today
            let x = random.double(in: 40...(World.width - 40))
            loot.append(Loot(id: UUID(), kind: .dailyChest, x: x, items: LootTable.dailyChest(&random)))
            events.append(.dailyChestArrived)
        }
    }

    mutating func dropMonsterLoot(_ kind: MonsterKind, at x: Double, winners: [Int]) {
        let lucky = winners.contains { pets[$0].relic == .luckyClover }
        let items = LootTable.monsterLoot(kind, lucky: lucky, &random)
        loot.append(Loot(id: UUID(), kind: .bag, x: clampX(x), items: items))
    }

    static func dayKey(_ date: Date) -> String {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }
}
