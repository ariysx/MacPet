import XCTest
@testable import PetsCore

final class RarityTests: XCTestCase {
    func testEveryTierExistsForEachGene() {
        XCTAssertEqual(Set(BodyShape.allCases.map(\.rarity)), Set(Rarity.allCases))
        XCTAssertEqual(BodyShape.allCases.count, 20)
        XCTAssertEqual(Set(Pattern.allCases.map(\.rarity)), Set(Rarity.allCases))
        XCTAssertEqual(Set(Accessory.allCases.map(\.rarity)), Set(Rarity.allCases))
        XCTAssertEqual(Set(EyeStyle.allCases.map(\.rarity)), Set(Rarity.allCases))
        XCTAssertEqual(Set(PetPalette.colourways.map(\.rarity)), Set(Rarity.allCases))
        XCTAssertEqual(Set(Item.allCases.map(\.rarity)), Set(Rarity.allCases))
        XCTAssertEqual(Set(PetPalette.colourways.map(\.name)).count, PetPalette.colourways.count)
    }

    func testRollsFollowWeights() {
        var random = SeededRandom(seed: 3)
        var counts: [Rarity: Int] = [:]
        for _ in 0..<20_000 { counts[Accessory.roll(&random).rarity, default: 0] += 1 }
        // Commons are far more likely than legendaries, and legendaries do happen.
        XCTAssertGreaterThan(counts[.common]!, counts[.uncommon]!)
        XCTAssertGreaterThan(counts[.rare]!, counts[.epic]!)
        XCTAssertGreaterThan(counts[.epic]!, counts[.legendary]!)
        XCTAssertGreaterThan(counts[.legendary]!, 0)
    }

    func testMinimumRarityIsRespected() {
        var random = SeededRandom(seed: 4)
        for _ in 0..<500 {
            XCTAssertGreaterThanOrEqual(EyeStyle.roll(&random, atLeast: .rare).rarity, .rare)
            XCTAssertGreaterThanOrEqual(PetPalette.roll(&random, atLeast: .epic).rarity, .epic)
            XCTAssertNotEqual(Pattern.mutate(&random, from: .spots), .spots)
        }
    }

    func testPetRarityIsItsRarestPart() {
        var looks = Looks.plain
        XCTAssertEqual(looks.rarity, .common)
        looks.accessory = .crown
        XCTAssertEqual(looks.rarity, .epic)
        looks.eyes = .starry
        XCTAssertEqual(looks.rarity, .legendary)
        XCTAssertEqual(Looks.words("twoTone"), "two tone")
    }

    func testMutagenGivesARareMutation() {
        var random = SeededRandom(seed: 8)
        let base = Genes(traits: .plain, looks: .plain, generation: 1, parentName: nil, mutations: [])
        for _ in 0..<200 {
            let genes = Genetics.mutagen(base, &random)
            XCTAssertGreaterThanOrEqual(genes.looks.rarity, .rare)
            XCTAssertFalse(genes.mutations.isEmpty)
        }
    }
}

final class ItemTests: XCTestCase {
    func testCategories() {
        XCTAssertEqual(Item.allCases.filter { $0.category == .weapon }.count, 6)
        XCTAssertEqual(Item.allCases.filter { $0.category == .relic }.count, 8)
        XCTAssertEqual(Item.allCases.filter { $0.category == .potion }.count, 10)
        XCTAssertTrue(Item.allCases.filter { $0.category == .weapon }.allSatisfy { $0.attackBonus > 0 })
    }

    func testWeaponAddsDamageAndStrengthMultiplies() {
        var world = makeWorld()
        let id = addPet(&world)
        world.update(id) { $0.hunger = 50 }
        world.addToInventory([.ironSword, .strengthPotion])
        XCTAssertTrue(world.equip(.ironSword, onPet: id))
        XCTAssertEqual(world.count(of: .ironSword), 0)
        XCTAssertEqual(Combat.attackDamage(for: world[pet: id]!, alliesInFight: 0), 6 + 3, accuracy: 1e-9)
        XCTAssertTrue(world.use(.strengthPotion, onPet: id))
        XCTAssertEqual(Combat.attackDamage(for: world[pet: id]!, alliesInFight: 0), 9 * 1.5, accuracy: 1e-9)
        world.advance(by: World.buffDuration + 1)
        XCTAssertFalse(world[pet: id]!.hasBuff(.strength), "buffs wear off")
    }

    func testSwappingEquipmentReturnsOldToBag() {
        var world = makeWorld()
        let id = addPet(&world)
        world.addToInventory([.stick, .dragonFang, .cozyScarf])
        world.equip(.stick, onPet: id)
        world.equip(.dragonFang, onPet: id)
        world.equip(.cozyScarf, onPet: id)
        XCTAssertEqual(world[pet: id]!.weapon, .dragonFang)
        XCTAssertEqual(world[pet: id]!.relic, .cozyScarf)
        XCTAssertEqual(world.count(of: .stick), 1)
        world.unequip(.relic, fromPet: id)
        XCTAssertNil(world[pet: id]!.relic)
        XCTAssertEqual(world.count(of: .cozyScarf), 1)
        XCTAssertFalse(world.equip(.cozyScarf, onPet: UUID()))
    }

    func testPotions() {
        var world = makeWorld()
        let id = addPet(&world)
        world.update(id) { $0.hunger = 10; $0.health = 20; $0.happiness = 10; $0.energy = 10; $0.sickRemaining = 500; $0.sleep = .nap }
        world.addToInventory([.snack, .tonic, .joyJuice, .espresso, .antidote])
        for potion in [Item.snack, .tonic, .joyJuice, .espresso, .antidote] {
            XCTAssertTrue(world.use(potion, onPet: id), "\(potion)")
        }
        let pet = world[pet: id]!
        XCTAssertEqual(pet.hunger, 50)
        XCTAssertEqual(pet.health, 50)
        XCTAssertEqual(pet.happiness, 50)
        XCTAssertEqual(pet.energy, 60)
        XCTAssertEqual(pet.sickRemaining, 0)
        XCTAssertEqual(pet.sleep, .awake)
        XCTAssertFalse(world.use(.snack, onPet: id), "used up")
    }

    func testCouragePotionMakesTimidFight() {
        var world = makeWorld()
        var timid = Traits.plain
        timid.courage = .timid
        let id = addPet(&world, traits: timid, x: 60)
        world.addToInventory([.couragePotion])
        world.use(.couragePotion, onPet: id)
        world.spawnMonster(kind: .slime, fromLeft: true)
        world.run(seconds: 1)
        XCTAssertEqual(world[pet: id]!.fight, .charging)
    }

    func testEggPotions() {
        var world = makeWorld()
        world.addEgg(at: 100, genes: nil)
        world.addEgg(at: 200, genes: nil)
        world.addToInventory([.mutagen, .hatchElixir])
        let mutated = world.eggs[1].id
        XCTAssertFalse(world.use(.mutagen, onPet: mutated))
        XCTAssertTrue(world.use(.mutagen, onEgg: mutated))
        XCTAssertTrue(world.eggs[1].mutated)
        XCTAssertGreaterThanOrEqual(world.eggs[1].genes.looks.rarity, .rare)
        XCTAssertTrue(world.use(.hatchElixir, onEgg: world.eggs[0].id))
        world.tick(dt: 0.1)
        XCTAssertEqual(world.pets.count, 1)
    }

    func testPhoenixFeatherRevivesOnce() {
        var world = makeWorld()
        let id = addPet(&world)
        world.addToInventory([.phoenixFeather])
        world.equip(.phoenixFeather, onPet: id)
        world.update(id) { $0.health = 0.0001; $0.hunger = 0 }
        world.tick(dt: 1)
        XCTAssertEqual(world[pet: id]?.health ?? 0, 50, accuracy: 0.1)
        XCTAssertNil(world[pet: id]!.relic)
        XCTAssertTrue(world.events.contains(.revived(name: world[pet: id]!.name)))
        world.update(id) { $0.health = 0.0001; $0.hunger = 0 }
        world.tick(dt: 1)
        XCTAssertNil(world[pet: id])
    }

    func testEquipmentReturnsToBagOnDeath() {
        var world = makeWorld()
        let id = addPet(&world)
        world.addToInventory([.magicWand, .heartLocket])
        world.equip(.magicWand, onPet: id)
        world.equip(.heartLocket, onPet: id)
        world.update(id) { $0.health = 0.0001; $0.hunger = 0 }
        world.tick(dt: 1)
        XCTAssertNil(world[pet: id])
        XCTAssertEqual(world.count(of: .magicWand), 1)
        XCTAssertEqual(world.count(of: .heartLocket), 1)
    }

    func testRelics() {
        var world = makeWorld()
        let plain = addPet(&world, x: 40)
        let pouch = addPet(&world, x: 280)
        world.addToInventory([.snackPouch])
        world.equip(.snackPouch, onPet: pouch)
        world.advance(by: hour)
        XCTAssertEqual(world[pet: plain]!.hunger, 100 - 8.5, accuracy: 0.01)
        XCTAssertEqual(world[pet: pouch]!.hunger, 100 - 8.5 * 0.75, accuracy: 0.01)

        var shell = makeWorld()
        let a = addPet(&shell, x: 20)
        shell.addToInventory([.guardianShell])
        shell.equip(.guardianShell, onPet: a)
        shell.pickUp(id: a)
        shell.drop(id: a, x: 20, height: 0)
        shell.spawnMonster(kind: .ogre, fromLeft: true)
        shell.monster!.x = 25
        shell.monster!.hitCooldown = 0
        shell.tick(dt: 0.05)
        XCTAssertEqual(shell[pet: a]!.health, 100 - 12 * 0.6, accuracy: 0.01)
    }

    func testWinningDropsLootBagThatAutoCollects() {
        var world = makeWorld()
        let id = addPet(&world, x: 60)
        world.tick(dt: 0.1) // lets the daily chest arrive first
        world.loot.removeAll()
        world.spawnMonster(kind: .ogre, fromLeft: true)
        world.update(id) { $0.wins = 12; $0.hunger = 100 }
        world.addToInventory([.dragonFang, .strengthPotion])
        world.equip(.dragonFang, onPet: id)
        world.use(.strengthPotion, onPet: id)
        var seconds = 0.0
        while world.monster?.phase == .attacking && seconds < 200 {
            world.update(id) { $0.health = 100 }
            world.run(seconds: 0.5)
            seconds += 0.5
        }
        XCTAssertEqual(world.loot.count, 1)
        let bag = world.loot[0]
        XCTAssertEqual(bag.kind, .bag)
        XCTAssertGreaterThanOrEqual(bag.items.count, 3, "ogres drop three items")
        XCTAssertTrue(bag.items.contains { $0.category != .potion && $0.rarity >= .rare })
        world.advance(by: Loot.bagAutoCollect + 1)
        XCTAssertTrue(world.loot.isEmpty)
        XCTAssertEqual(world.inventory.values.reduce(0, +), bag.items.count)
    }

    func testLuckyCloverAddsARoll() {
        var random = SeededRandom(seed: 1)
        XCTAssertEqual(LootTable.monsterLoot(.bat, lucky: false, &random).count, 2)
        XCTAssertEqual(LootTable.monsterLoot(.bat, lucky: true, &random).count, 3)
    }

    func testOneDailyChestPerDay() {
        var date = Date(timeIntervalSince1970: 1_790_000_000)
        var world = makeWorld()
        world.now = { date }
        addPet(&world)
        world.tick(dt: 1)
        XCTAssertEqual(world.loot.filter { $0.kind == .dailyChest }.count, 1)
        XCTAssertTrue(world.events.contains(.dailyChestArrived))
        let chest = world.loot[0]
        XCTAssertEqual(chest.items.count, 3)
        XCTAssertTrue(chest.items.contains { $0.rarity >= .uncommon })
        world.collectLoot(id: chest.id)
        world.advance(by: 2 * hour)
        XCTAssertTrue(world.loot.isEmpty, "only one per day")
        XCTAssertEqual(world.inventory.values.reduce(0, +), 3)
        date = date.addingTimeInterval(day)
        world.tick(dt: 1)
        XCTAssertEqual(world.loot.count, 1, "a new day brings a new chest")
    }

    func testInventoryAndLootAreSaved() throws {
        var world = makeWorld()
        let id = addPet(&world)
        world.tick(dt: 1)
        world.addToInventory([.elixir, .elixir, .slingshot, .moonPillow])
        world.equip(.moonPillow, onPet: id)
        world.use(.couragePotion, onPet: id)
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: dir) }
        let url = dir.appendingPathComponent("world.json")
        try SaveStore.save(world, to: url)
        let (loaded, _) = SaveStore.load(from: url, newSeed: 1)
        XCTAssertEqual(loaded.inventory, world.inventory)
        XCTAssertEqual(loaded.loot, world.loot)
        XCTAssertEqual(loaded.lastDailyChestDay, world.lastDailyChestDay)
        XCTAssertEqual(loaded[pet: id]!.relic, .moonPillow)
    }
}
