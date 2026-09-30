import XCTest
@testable import PetsCore

final class FightTests: XCTestCase {
    func testDamageFormula() {
        var world = makeWorld()
        let id = addPet(&world)
        world.update(id) { $0.hunger = 50; $0.wins = 4 }
        var pet = world[pet: id]!
        XCTAssertEqual(Combat.attackDamage(for: pet, alliesInFight: 0), 4 + 2 + 2, accuracy: 1e-9)

        pet.wins = 40
        XCTAssertEqual(Combat.attackDamage(for: pet, alliesInFight: 0), 4 + 2 + 6, accuracy: 1e-9, "wins cap at +6")

        pet.wins = 0
        pet.age = hour
        XCTAssertEqual(Combat.attackDamage(for: pet, alliesInFight: 0), 3, accuracy: 1e-9, "babies deal half")

        pet.age = 2 * day
        pet.traits.sociality = .social
        XCTAssertEqual(Combat.attackDamage(for: pet, alliesInFight: 0), 6, accuracy: 1e-9)
        XCTAssertEqual(Combat.attackDamage(for: pet, alliesInFight: 1), 6 * 1.2, accuracy: 1e-9, "social bonus")
    }

    func testEnergeticHitsMoreOften() {
        XCTAssertEqual(Traits.plain.attackInterval, 1.15)
        var lazy = Traits.plain
        lazy.vigor = .lazy
        XCTAssertEqual(lazy.attackInterval, 1.5)
    }

    func testBraveChargesAndWins() {
        var world = makeWorld()
        let id = addPet(&world, x: 60)
        world.update(id) { $0.happiness = 50 }
        world.spawnMonster(kind: .slime, fromLeft: true)
        var seconds = 0.0
        while world.monster != nil && seconds < 120 {
            world.run(seconds: 0.1)
            seconds += 0.1
        }
        XCTAssertNil(world.monster)
        XCTAssertNotNil(world.smoke, "smoke puff appears on a win")
        let pet = world[pet: id]!
        XCTAssertEqual(pet.wins, 1)
        XCTAssertGreaterThan(pet.happiness, 70, "+25 for winning")
        XCTAssertEqual(pet.feeling, .excited)
        XCTAssertTrue(world.events.contains(.monsterDefeated(.slime)))
        XCTAssertEqual(pet.fight, .none)
    }

    func testTimidFleesToFarEdge() {
        var world = makeWorld()
        var timid = Traits.plain
        timid.courage = .timid
        let id = addPet(&world, traits: timid, x: 160)
        world.spawnMonster(kind: .slime, fromLeft: true)
        world.run(seconds: 2)
        XCTAssertEqual(world[pet: id]!.fight, .fleeing)
        XCTAssertEqual(world[pet: id]!.feeling, .scared)
        world.run(seconds: 20)
        XCTAssertEqual(world[pet: id]!.x, World.width - World.edgeMargin, accuracy: 0.5)
    }

    func testCorneredTimidFights() {
        var world = makeWorld()
        var timid = Traits.plain
        timid.courage = .timid
        let id = addPet(&world, traits: timid, x: World.width - World.edgeMargin)
        world.spawnMonster(kind: .slime, fromLeft: true)
        world.monster!.x = World.width - 40
        world.run(seconds: 1)
        XCTAssertEqual(world[pet: id]!.fight, .fighting)
    }

    func testRetreatsBelow25AndNeverRejoins() {
        var world = makeWorld()
        let id = addPet(&world, x: 20)
        world.spawnMonster(kind: .ogre, fromLeft: true)
        world.run(seconds: 5)
        XCTAssertEqual(world[pet: id]!.fight, .fighting)
        world.update(id) { $0.health = 20 }
        world.run(seconds: 0.2)
        XCTAssertEqual(world[pet: id]!.fight, .retreated)
        world.update(id) { $0.health = 90 }
        world.run(seconds: 2)
        XCTAssertEqual(world[pet: id]!.fight, .retreated)
    }

    func testAlreadyWeakPetNeverJoinsButCanStillDie() {
        var world = makeWorld()
        let id = addPet(&world, x: 20)
        world.update(id) { $0.health = 3 }
        world.spawnMonster(kind: .slime, fromLeft: true)
        XCTAssertEqual(world[pet: id]!.fight, .retreated)
        world.monster!.x = 25
        world.monster!.hitCooldown = 0
        world.tick(dt: 0.05)
        XCTAssertNil(world[pet: id])
        XCTAssertEqual(world.graveyard.first?.cause, .monster)
    }

    func testLossAfter90sWithoutHitsMonsterEats() {
        var world = makeWorld()
        let id = addPet(&world, x: 160)
        world.pickUp(id: id) // held pets are out of reach
        world.spawnMonster(kind: .slime, fromLeft: true)
        world.run(seconds: 89)
        XCTAssertEqual(world.monster?.phase, .attacking)
        let hunger = world[pet: id]!.hunger
        world.run(seconds: 2)
        XCTAssertEqual(world.monster?.phase, .leaving)
        XCTAssertEqual(world[pet: id]!.hunger, hunger - 25, accuracy: 0.1)
        XCTAssertTrue(world.events.contains(.monsterAte(.slime)))
    }

    func testLeavesAfterFiveMinutesRegardless() {
        var world = makeWorld()
        let id = addPet(&world, x: 160)
        world.pickUp(id: id)
        world.spawnMonster(kind: .ogre, fromLeft: false)
        for _ in 0..<5 {
            XCTAssertTrue(world.playerHitMonster())
            world.run(seconds: 60)
        }
        world.run(seconds: 1)
        XCTAssertEqual(world.monster?.phase, .leaving)
        XCTAssertFalse(world.events.contains(.monsterAte(.ogre)))
    }

    func testPlayerHitCooldown() {
        var world = makeWorld()
        addPet(&world)
        world.spawnMonster(kind: .ogre, fromLeft: true)
        XCTAssertTrue(world.playerHitMonster())
        XCTAssertFalse(world.playerHitMonster())
        world.run(seconds: 0.5)
        XCTAssertTrue(world.playerHitMonster())
        XCTAssertEqual(world.monster!.health, 110, accuracy: 1e-9)
    }

    func testThrownPetHitsDoubleFirst() {
        var world = makeWorld()
        var timid = Traits.plain
        timid.courage = .timid
        let id = addPet(&world, traits: timid, x: 160)
        world.update(id) { $0.hunger = 100 }
        world.spawnMonster(kind: .ogre, fromLeft: true)
        world.monster!.x = 100
        world.monster!.hitCooldown = 100
        world.pickUp(id: id)
        world.drop(id: id, x: 100, height: 0)
        world.tick(dt: 0.01)
        let hunger = world[pet: id]!.hunger
        XCTAssertEqual(world.monster!.health, 120 - 2 * (4 + 4 * hunger / 100), accuracy: 0.01)
    }

    func testNoSpawnsAtNightOrWithoutPets() {
        var world = makeWorld(hour: 2)
        world.monsterSpawnChance = 1
        addPet(&world)
        world.advance(by: 2 * hour)
        XCTAssertNil(world.monster)

        var eggsOnly = makeWorld()
        eggsOnly.monsterSpawnChance = 1
        eggsOnly.addEgg(at: 100, genes: nil)
        eggsOnly.eggs[0].duration = 10 * hour
        eggsOnly.advance(by: 1.1 * hour)
        XCTAssertNil(eggsOnly.monster)

        var day = makeWorld()
        day.monsterSpawnChance = 1
        addPet(&day)
        day.advance(by: 1.01 * hour)
        XCTAssertTrue(day.events.contains { if case .monsterArrived = $0 { return true } else { return false } })
    }

    func testSpawnWeights() {
        var random = SeededRandom(seed: 99)
        var counts: [MonsterKind: Int] = [:]
        for _ in 0..<10_000 { counts[MonsterKind.roll(&random), default: 0] += 1 }
        XCTAssertEqual(Double(counts[.slime]!) / 10_000, 0.6, accuracy: 0.03)
        XCTAssertEqual(Double(counts[.bat]!) / 10_000, 0.3, accuracy: 0.03)
        XCTAssertEqual(Double(counts[.ogre]!) / 10_000, 0.1, accuracy: 0.03)
    }
}
