import Foundation

enum ItemCategory: String, Codable, CaseIterable {
    case weapon, relic, potion, special

    var title: String {
        switch self {
        case .weapon: return "Weapons"
        case .relic: return "Relics"
        case .potion: return "Potions"
        case .special: return "Specials"
        }
    }
}

/// Weapons and relics are equipped by one pet at a time. Potions are used up. Specials are
/// dropped anywhere on the ground: eggs are placed there, a horn calls a monster.
enum Item: String, Codable, CaseIterable, RarityRanked {
    // Weapons
    case stick, woodenSword, slingshot, ironSword, magicWand, dragonFang
    // Relics
    case featherCharm, cozyScarf, snackPouch, moonPillow, guardianShell, heartLocket, luckyClover, phoenixFeather, timelessAmber
    // Potions
    case snack, tonic, joyJuice, espresso, antidote, strengthPotion, couragePotion, hatchElixir, elixir, mutagen
    // Specials
    case mysteryEgg, shinyEgg, warHorn

    var category: ItemCategory {
        switch self {
        case .stick, .woodenSword, .slingshot, .ironSword, .magicWand, .dragonFang: return .weapon
        case .featherCharm, .cozyScarf, .snackPouch, .moonPillow, .guardianShell, .heartLocket,
             .luckyClover, .phoenixFeather, .timelessAmber: return .relic
        case .mysteryEgg, .shinyEgg, .warHorn: return .special
        default: return .potion
        }
    }

    var rarity: Rarity {
        switch self {
        case .stick, .featherCharm, .cozyScarf, .snack, .tonic: return .common
        case .woodenSword, .slingshot, .snackPouch, .moonPillow, .joyJuice, .espresso, .antidote, .mysteryEgg: return .uncommon
        case .ironSword, .guardianShell, .heartLocket, .strengthPotion, .couragePotion, .hatchElixir, .warHorn: return .rare
        case .magicWand, .luckyClover, .elixir, .shinyEgg: return .epic
        case .dragonFang, .phoenixFeather, .mutagen, .timelessAmber: return .legendary
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
        case .timelessAmber: return "Timeless Amber"
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
        case .mysteryEgg: return "Mystery Egg"
        case .shinyEgg: return "Shiny Egg"
        case .warHorn: return "War Horn"
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
        case .timelessAmber: return "age frozen: never grows old"
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
        case .mysteryEgg: return "a new egg; who knows what hatches"
        case .shinyEgg: return "an egg with a rare mutation inside"
        case .warHorn: return "calls a monster to fight now"
        }
    }

    /// Potions that are used on an egg rather than a pet.
    var targetsEgg: Bool { self == .hatchElixir || self == .mutagen }

    /// Items that turn up in ordinary loot rolls. Specials and Timeless Amber only come from
    /// their own, much rarer drops.
    static let lootable = allCases.filter { $0.category != .special && $0 != .timelessAmber }

    // MARK: Durability

    /// Hits a weapon lands before it breaks. Relics never wear out; potions are used up.
    var maxDurability: Int {
        switch self {
        case .stick: return 40
        case .woodenSword: return 80
        case .slingshot: return 100
        case .ironSword: return 160
        case .magicWand: return 220
        case .dragonFang: return 400
        default: return 0
        }
    }

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
    /// `reward` is the chest a Petdex milestone drops.
    enum Kind: String, Codable { case bag, dailyChest, reward }

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
        let potions = Item.allCases.filter { $0.category == .potion }
        let gear = Item.allCases.filter { $0.category == .weapon || $0.category == .relic }
        switch kind {
        case .slime, .shroomling:
            items.append(.roll(&random, from: potions))
            if random.chance(0.25) { items.append(.roll(&random, from: Item.lootable)) }
        case .bat, .wolf:
            items.append(.roll(&random, from: Item.lootable))
            items.append(.roll(&random, from: potions))
        case .wisp:
            items.append(.roll(&random, from: Item.lootable, atLeast: .uncommon))
            items.append(.roll(&random, from: potions))
        case .ogre:
            items.append(.roll(&random, from: gear, atLeast: .rare))
            items.append(.roll(&random, from: Item.lootable))
            items.append(.roll(&random, from: Item.lootable))
        case .golem:
            items.append(.roll(&random, from: gear, atLeast: .epic))
            items.append(.roll(&random, from: Item.lootable, atLeast: .uncommon))
            items.append(.roll(&random, from: Item.lootable))
            items.append(.roll(&random, from: Item.lootable))
        }
        if lucky {
            items.append(.roll(&random, from: Item.lootable, atLeast: .uncommon))
        }
        // The big prizes: eggs, and a horn to start the next fight.
        if random.chance(kind.eggChance) { items.append(.mysteryEgg) }
        if random.chance(kind.shinyEggChance) { items.append(.shinyEgg) }
        if random.chance(kind.isBig ? 0.3 : 0.08) { items.append(.warHorn) }
        if random.chance(kind == .golem ? 0.03 : kind == .ogre ? 0.01 : 0) { items.append(.timelessAmber) }
        return items
    }

    /// The daily chest grows with the streak of days in a row: three rolls on day 1, up to six
    /// from day 4, an egg some days, and a Shiny Egg every 7th day.
    static func dailyChest<R: RandomSource>(streak: Int = 1, _ random: inout R) -> [Item] {
        var items: [Item] = [.roll(&random, from: Item.lootable, atLeast: .uncommon)]
        for _ in 0..<(2 + min(3, max(0, streak - 1))) { items.append(.roll(&random, from: Item.lootable)) }
        if streak >= 3 { items.append(.roll(&random, from: Item.lootable, atLeast: .rare)) }
        if streak > 0 && streak % 7 == 0 {
            items.append(.shinyEgg)
        } else if random.chance(0.35) {
            items.append(.mysteryEgg)
        }
        if random.chance(0.25) { items.append(.warHorn) }
        if random.chance(streak >= 7 ? 0.02 : 0.004) { items.append(.timelessAmber) }
        return items
    }

    /// A Petdex milestone: a Mystery Egg, a rare-or-better roll and a bonus roll.
    static func dexReward<R: RandomSource>(_ random: inout R) -> [Item] {
        var items: [Item] = [.mysteryEgg, .roll(&random, from: Item.lootable, atLeast: .rare), .roll(&random, from: Item.lootable)]
        if random.chance(0.03) { items.append(.timelessAmber) }
        return items
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
            if let old = pets[i].weapon { stowWorn(old, durability: pets[i].weaponDurability) }
            pets[i].weapon = item
            pets[i].weaponDurability = takeWorn(item) ?? item.maxDurability
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
            if let old = pets[i].weapon { stowWorn(old, durability: pets[i].weaponDurability) }
            pets[i].weapon = nil
            pets[i].weaponDurability = 0
        case .relic:
            if let old = pets[i].relic { addToInventory([old]) }
            pets[i].relic = nil
        case .potion, .special:
            break
        }
    }

    /// Puts a weapon back in the bag, remembering its wear. A fresh one is just counted.
    mutating func stowWorn(_ item: Item, durability: Int) {
        addToInventory([item])
        if durability > 0 && durability < item.maxDurability { wornWeapons[item, default: []].append(durability) }
    }

    /// Takes the most worn copy's durability, if a worn copy is in the bag. Used up first.
    private mutating func takeWorn(_ item: Item) -> Int? {
        guard var list = wornWeapons[item], !list.isEmpty, let k = list.indices.min(by: { list[$0] < list[$1] }) else { return nil }
        let d = list.remove(at: k)
        wornWeapons[item] = list.isEmpty ? nil : list
        return d
    }

    /// Durability of each copy in the bag, most worn first; fresh ones are full.
    func bagDurabilities(_ item: Item) -> [Int] {
        let worn = (wornWeapons[item] ?? []).sorted()
        return worn + Array(repeating: item.maxDurability, count: max(0, count(of: item) - worn.count))
    }

    /// One hit's wear on a pet's weapon. A weapon at 0 breaks and is gone.
    mutating func wearWeapon(petIndex i: Int) {
        guard let weapon = pets[i].weapon else { return }
        if pets[i].weaponDurability <= 0 { pets[i].weaponDurability = weapon.maxDurability } // from an old save
        pets[i].weaponDurability -= 1
        if pets[i].weaponDurability <= 0 {
            pets[i].weapon = nil
            pets[i].weaponDurability = 0
            events.append(.weaponBroke(name: pets[i].name, item: weapon))
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

        // One daily chest per calendar day the app runs. Days in a row build a streak.
        let today = World.dayKey(now())
        if today != lastDailyChestDay && !loot.contains(where: { $0.kind == .dailyChest }) {
            let yesterday = World.dayKey(now().addingTimeInterval(-86400))
            dailyStreak = lastDailyChestDay == yesterday ? dailyStreak + 1 : 1
            lastDailyChestDay = today
            let x = random.double(in: 40...(World.width - 40))
            loot.append(Loot(id: UUID(), kind: .dailyChest, x: x, items: LootTable.dailyChest(streak: dailyStreak, &random)))
            events.append(.dailyChestArrived)
        }
    }

    mutating func dropMonsterLoot(_ kind: MonsterKind, at x: Double, winners: [Int]) {
        let lucky = winners.contains { pets[$0].relic == .luckyClover }
        let items = LootTable.monsterLoot(kind, lucky: lucky, &random)
        loot.append(Loot(id: UUID(), kind: .bag, x: clampX(x), items: items))
    }

    /// Drops a special anywhere: an egg is placed at `x`, a horn calls a monster.
    /// Returns false (and keeps the item) when there is no room or a fight is already on.
    @discardableResult
    mutating func useSpecial(_ item: Item, at x: Double) -> Bool {
        guard item.category == .special, count(of: item) > 0 else { return false }
        switch item {
        case .mysteryEgg, .shinyEgg:
            guard freeSlots > 0 else { return false }
            var genes = Genetics.random(&random)
            if item == .shinyEgg { genes = Genetics.mutagen(genes, &random) }
            addEgg(at: x, genes: genes)
            if item == .shinyEgg { eggs[eggs.count - 1].mutated = true }
        case .warHorn:
            guard monster == nil, !pets.isEmpty else { return false }
            spawnMonster(kind: .roll(&random), fromLeft: x > World.width / 2)
        default:
            return false
        }
        _ = takeFromInventory(item)
        return true
    }

    static func dayKey(_ date: Date) -> String {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }
}
