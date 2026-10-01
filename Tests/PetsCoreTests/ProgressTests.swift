import XCTest
@testable import PetsCore

final class ProgressTests: XCTestCase {
    func testLevelsFromXP() {
        var world = makeWorld()
        let id = addPet(&world)
        XCTAssertEqual(world[pet: id]!.level, 1)
        world.gainXP(petIndex: 0, 19)
        XCTAssertEqual(world[pet: id]!.level, 1)
        XCTAssertTrue(world.events.isEmpty)
        world.gainXP(petIndex: 0, 1)
        XCTAssertEqual(world[pet: id]!.level, 2)
        XCTAssertTrue(world.events.contains(.levelUp(name: world[pet: id]!.name, level: 2)))
        world.gainXP(petIndex: 0, 1_000_000)
        XCTAssertEqual(world[pet: id]!.level, Pet.maxLevel)
        XCTAssertEqual(world[pet: id]!.levelProgress, 1)
    }

    func testLevelsAddDamage() {
        var world = makeWorld()
        let id = addPet(&world)
        let base = Combat.attackDamage(for: world[pet: id]!, alliesInFight: 0)
        world.update(id) { $0.xp = Pet.xpNeeded(forLevel: 6) }
        XCTAssertEqual(Combat.attackDamage(for: world[pet: id]!, alliesInFight: 0), base + 5 * 0.4, accuracy: 1e-9)
    }

    func testWinningGivesXP() {
        var world = makeWorld()
        let id = addPet(&world)
        world.spawnMonster(kind: .slime, fromLeft: true)
        world.monster!.health = 1
        world.monster!.x = world[pet: id]!.x - 5
        world.monster!.hitCooldown = 100
        world.advance(by: 3)
        XCTAssertNil(world.monster)
        XCTAssertEqual(world[pet: id]!.xp, MonsterKind.slime.xp)
        XCTAssertTrue(world.hits.contains { $0.finishing })
    }

    func testHatchFillsDexAndMilestonesDropChests() {
        var world = makeWorld()
        world.addEgg(at: 100, genes: nil)
        world.eggs[0].duration = 1
        world.advance(by: 2)
        XCTAssertEqual(world.dex.count, 5)
        XCTAssertTrue(world.events.contains { if case .discovered = $0 { return true } else { return false } })
        XCTAssertTrue(world.loot.allSatisfy { $0.kind != .reward })

        // Keep hatching different looks until a milestone is passed.
        var random = SeededRandom(seed: 3)
        while world.dex.count < World.dexMilestone {
            world.discover(Genetics.random(&random).looks, name: "X")
        }
        XCTAssertEqual(world.loot.filter { $0.kind == .reward }.count, 1)
        XCTAssertEqual(world.dexRewards, 1)
        XCTAssertTrue(world.loot.first { $0.kind == .reward }!.items.contains(.mysteryEgg))
    }

    func testQuietSyncGivesNoRetroactiveChests() {
        var world = makeWorld()
        var random = SeededRandom(seed: 5)
        for _ in 0..<6 { addPet(&world); world.pets[world.pets.count - 1].looks = Genetics.random(&random).looks }
        world.syncDex()
        XCTAssertGreaterThanOrEqual(world.dex.count, World.dexMilestone)
        XCTAssertTrue(world.loot.isEmpty)
        XCTAssertTrue(world.events.isEmpty)
        XCTAssertEqual(DexEntry.total, BodyShape.allCases.count + PetPalette.colourways.count + 12 + 15 + 9)
    }

    func testMysteryAndShinyEggsArePlaced() {
        var world = makeWorld()
        world.addToInventory([.mysteryEgg, .shinyEgg])
        XCTAssertTrue(world.useSpecial(.mysteryEgg, at: 50))
        XCTAssertTrue(world.useSpecial(.shinyEgg, at: 200))
        XCTAssertEqual(world.eggs.count, 2)
        XCTAssertGreaterThanOrEqual(world.eggs[1].genes.looks.rarity, .rare)
        XCTAssertTrue(world.eggs[1].mutated)
        XCTAssertTrue(world.inventory.isEmpty)
        XCTAssertFalse(world.useSpecial(.mysteryEgg, at: 50), "none left")
    }

    func testEggsNeedRoom() {
        var world = makeWorld()
        for k in 0..<World.maxSlots { world.addEgg(at: Double(20 + k * 25), genes: nil) }
        world.addToInventory([.mysteryEgg])
        XCTAssertFalse(world.useSpecial(.mysteryEgg, at: 50))
        XCTAssertEqual(world.count(of: .mysteryEgg), 1, "kept")
    }

    func testWarHornCallsAMonster() {
        var world = makeWorld()
        world.addToInventory([.warHorn, .warHorn])
        XCTAssertFalse(world.useSpecial(.warHorn, at: 50), "no pets to fight")
        addPet(&world)
        XCTAssertTrue(world.useSpecial(.warHorn, at: 50))
        XCTAssertNotNil(world.monster)
        XCTAssertFalse(world.useSpecial(.warHorn, at: 50), "one fight at a time")
        XCTAssertEqual(world.count(of: .warHorn), 1)
    }

    func testDailyStreak() {
        var date = Date(timeIntervalSince1970: 1_790_000_000)
        var world = makeWorld()
        world.now = { date }
        addPet(&world)
        for day in 1...7 {
            world.tick(dt: 1)
            XCTAssertEqual(world.dailyStreak, day)
            let chest = world.loot.first { $0.kind == .dailyChest }!
            if day == 7 { XCTAssertTrue(chest.items.contains(.shinyEgg)) }
            XCTAssertGreaterThanOrEqual(chest.items.filter { $0.category != .special }.count, 3 + min(3, day - 1))
            world.collectLoot(id: chest.id)
            date += 86400
        }
        date += 86400 // a day missed
        world.tick(dt: 1)
        XCTAssertEqual(world.dailyStreak, 1)
    }

    func testBigMonstersOftenDropEggs() {
        var random = SeededRandom(seed: 11)
        var eggs = 0
        for _ in 0..<200 where LootTable.monsterLoot(.golem, lucky: false, &random).contains(where: { $0 == .mysteryEgg || $0 == .shinyEgg }) {
            eggs += 1
        }
        XCTAssertGreaterThan(eggs, 100)
    }

    func testCritsHitHarder() {
        var world = makeWorld()
        world.critChance = 1
        let id = addPet(&world)
        world.spawnMonster(kind: .golem, fromLeft: true)
        world.monster!.x = world[pet: id]!.x - 5
        world.monster!.hitCooldown = 100
        world.advance(by: 2)
        let hit = world.hits.first { $0.onMonster }!
        XCTAssertTrue(hit.crit)
        XCTAssertEqual(hit.damage, Combat.attackDamage(for: world[pet: id]!, alliesInFight: 0) * Combat.critMultiplier, accuracy: 0.01)
    }
}

final class DurabilityAndAmberTests: XCTestCase {
    func testWeaponsWearOutAndBreak() {
        var world = makeWorld()
        let id = addPet(&world)
        world.addToInventory([.stick])
        XCTAssertTrue(world.equip(.stick, onPet: id))
        XCTAssertEqual(world[pet: id]!.weaponDurability, Item.stick.maxDurability)
        for _ in 0..<(Item.stick.maxDurability - 1) { world.wearWeapon(petIndex: 0) }
        XCTAssertEqual(world[pet: id]!.weapon, .stick)
        world.wearWeapon(petIndex: 0)
        XCTAssertNil(world[pet: id]!.weapon)
        XCTAssertTrue(world.events.contains(.weaponBroke(name: world[pet: id]!.name, item: .stick)))
        XCTAssertEqual(world.count(of: .stick), 0, "a broken weapon is gone")
    }

    func testWearIsKeptThroughTheBag() {
        var world = makeWorld()
        let a = addPet(&world, x: 60)
        let b = addPet(&world, x: 200)
        world.addToInventory([.ironSword, .ironSword])
        world.equip(.ironSword, onPet: a)
        for _ in 0..<10 { world.wearWeapon(petIndex: 0) }
        world.unequip(.weapon, fromPet: a)
        XCTAssertEqual(world.bagDurabilities(.ironSword), [150, 160])
        world.equip(.ironSword, onPet: b)
        XCTAssertEqual(world[pet: b]!.weaponDurability, 150, "the worn copy is used first")
        XCTAssertTrue(world.wornWeapons.isEmpty)
    }

    func testFightsWearWeapons() {
        var world = makeWorld()
        let id = addPet(&world)
        world.addToInventory([.woodenSword])
        world.equip(.woodenSword, onPet: id)
        world.spawnMonster(kind: .golem, fromLeft: true)
        world.monster!.x = world[pet: id]!.x - 5
        world.monster!.hitCooldown = 100
        world.advance(by: 5)
        XCTAssertLessThan(world[pet: id]!.weaponDurability, Item.woodenSword.maxDurability)
    }

    func testRelicsNeverWear() {
        XCTAssertTrue(Item.allCases.filter { $0.category == .relic }.allSatisfy { $0.maxDurability == 0 })
    }

    func testTimelessAmberFreezesAge() {
        var world = makeWorld()
        let id = addPet(&world, age: 20 * day)
        world.addToInventory([.timelessAmber])
        world.equip(.timelessAmber, onPet: id)
        let age = world[pet: id]!.age
        world.advance(by: 30 * hour)
        XCTAssertEqual(world[pet: id]!.age, age)
        XCTAssertFalse(world.graveyard.contains { $0.cause == .oldAge })
        XCTAssertFalse(Item.lootable.contains(.timelessAmber), "only from its own rare drops")
    }
}

final class WeatherTests: XCTestCase {
    func testWeatherIntensityAndStormLightning() {
        var world = makeWorld()
        world.weatherOverride = .drizzle
        world.advance(by: 200)
        XCTAssertEqual(world.rain, Weather.drizzle.intensity, accuracy: 0.01)
        XCTAssertTrue(world.lightning.isEmpty, "no lightning in a drizzle")
        world.weatherOverride = .storm
        world.advance(by: 200)
        XCTAssertEqual(world.rain, 1, accuracy: 0.01)
        XCTAssertFalse(world.lightning.isEmpty)
        XCTAssertTrue(world.lightning.allSatisfy { $0 > 0 && $0 < World.width })
        world.weatherOverride = .clear
        world.advance(by: 200)
        XCTAssertEqual(world.rain, 0, accuracy: 0.01)
    }

    func testRainComesInThreeKinds() {
        var world = makeWorld()
        var seen = Set<Weather>()
        for _ in 0..<400 {
            world.advance(by: 3600)
            seen.insert(world.weather)
        }
        XCTAssertTrue(seen.isSuperset(of: [.drizzle, .rain, .storm]))
    }
}
