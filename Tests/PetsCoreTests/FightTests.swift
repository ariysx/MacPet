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
        for _ in 0..<20_000 { counts[MonsterKind.roll(&random), default: 0] += 1 }
        let total = MonsterKind.allCases.reduce(0) { $0 + $1.weight }
        for kind in MonsterKind.allCases {
            XCTAssertEqual(Double(counts[kind] ?? 0) / 20_000, kind.weight / total, accuracy: 0.02, "\(kind)")
        }
    }
}

final class PhysicsTests: XCTestCase {
    func testDroppedFromHeightFallsWithGravity() {
        var world = makeWorld()
        let id = addPet(&world)
        world.pickUp(id: id)
        world.drop(id: id, x: 150, height: 80)
        world.run(seconds: 0.2, step: 1.0 / 30)
        let h = world[pet: id]!.height
        XCTAssertLessThan(h, 80)
        XCTAssertGreaterThan(h, 60, "gravity accelerates, so it starts slow")
        world.run(seconds: 3, step: 1.0 / 30)
        XCTAssertEqual(world[pet: id]!.height, 0)
        XCTAssertFalse(world[pet: id]!.isFalling)
    }

    func testThrowCarriesSwingVelocityAndBounces() {
        var world = makeWorld()
        let id = addPet(&world, x: 100)
        world.pickUp(id: id)
        world.moveHeld(id: id, x: 100, height: 40)
        world.run(seconds: 0.5, step: 1.0 / 30)
        // Swing quickly to the right and up, then let go mid-swing.
        world.moveHeld(id: id, x: 160, height: 70)
        world.run(seconds: 2.0 / 30, step: 1.0 / 30)
        XCTAssertGreaterThan(world[pet: id]!.vx, 100)
        let releasedAt = world[pet: id]!.x
        world.throwHeld(id: id)
        var bounced = false
        var furthest = releasedAt
        var lastVy = world[pet: id]!.vy
        for _ in 0..<150 {
            world.tick(dt: 1.0 / 30)
            let vy = world[pet: id]!.vy
            if lastVy < 0 && vy > 0 { bounced = true }
            lastVy = vy
            furthest = max(furthest, world[pet: id]!.x)
        }
        let pet = world[pet: id]!
        XCTAssertTrue(bounced)
        XCTAssertGreaterThan(furthest, releasedAt + 80, "it kept flying after the swing")
        XCTAssertEqual(pet.height, 0)
        XCTAssertEqual(pet.vx, 0)
    }

    func testWallsBounceThrownPets() {
        var world = makeWorld()
        let id = addPet(&world)
        world.pickUp(id: id)
        world.drop(id: id, x: 300, height: 30, velocity: SIMD2(400, 50))
        var minVx = 0.0
        for _ in 0..<60 {
            world.tick(dt: 1.0 / 30)
            XCTAssertLessThanOrEqual(world[pet: id]!.x, World.width - World.edgeMargin)
            minVx = min(minVx, world[pet: id]!.vx)
        }
        XCTAssertLessThan(minVx, 0, "it rebounded off the right edge")
    }

    func testThrowingAPetAtTheMonsterJoinsTheFight() {
        var world = makeWorld()
        var timid = Traits.plain
        timid.courage = .timid
        let id = addPet(&world, traits: timid, x: 60)
        world.spawnMonster(kind: .ogre, fromLeft: false)
        world.monster!.x = 200
        world.monster!.hitCooldown = 100
        world.pickUp(id: id)
        world.drop(id: id, x: 120, height: 25, velocity: SIMD2(260, 40))
        world.run(seconds: 1, step: 1.0 / 30)
        XCTAssertEqual(world[pet: id]!.fight, .fighting)
    }

    func testHardLandingsPleaseBravePetsAndUpsetTimidOnes() {
        var world = makeWorld()
        var timid = Traits.plain
        timid.courage = .timid
        let brave = addPet(&world, x: 60)
        let scared = addPet(&world, traits: timid, x: 250)
        for id in [brave, scared] {
            world.update(id) { $0.happiness = 50 }
            world.pickUp(id: id)
            world.drop(id: id, x: id == brave ? 60 : 250, height: 120)
        }
        world.run(seconds: 0.8, step: 1.0 / 30)
        XCTAssertGreaterThan(world[pet: brave]!.happiness, 50)
        XCTAssertLessThan(world[pet: scared]!.happiness, 50)
    }
}

final class HitFeedbackTests: XCTestCase {
    func testBlowsAreRecordedAndKnockPetsBack() {
        var world = makeWorld()
        let id = addPet(&world, x: 20)
        world.spawnMonster(kind: .slime, fromLeft: true)
        world.monster!.x = 26
        world.monster!.hitCooldown = 0
        world.tick(dt: 1.0 / 30)
        XCTAssertTrue(world.hits.contains { !$0.onMonster })
        XCTAssertTrue(world[pet: id]!.isFalling, "knocked back into a hop")
        XCTAssertLessThan(world[pet: id]!.vx, 0, "away from the monster")
        world.hits.removeAll()
        world.playerHitMonster()
        XCTAssertEqual(world.hits.last?.damage, Combat.playerDamage)
        XCTAssertTrue(world.hits.last!.onMonster)
    }
}
