import XCTest
@testable import PetsCore

final class HealthTests: XCTestCase {
    func testDrainsPerBadCondition() {
        var world = makeWorld()
        let starving = addPet(&world, x: 40)
        let both = addPet(&world, x: 280)
        world.update(starving) { $0.hunger = 0; $0.happiness = 80 }
        world.update(both) { $0.hunger = 0; $0.happiness = 5 }
        world.advance(by: hour)
        XCTAssertEqual(world[pet: starving]!.health, 100 - 1.4, accuracy: 0.01)
        XCTAssertEqual(world[pet: both]!.health, 100 - 2.8, accuracy: 0.01)
    }

    func testHealsWhenWellFedAndHappy() {
        var world = makeWorld()
        let id = addPet(&world)
        world.update(id) { $0.health = 50; $0.hunger = 80; $0.happiness = 80 }
        world.advance(by: hour)
        XCTAssertEqual(world[pet: id]!.health, 53, accuracy: 0.01)
    }

    func testFullNeglectKillsInTwoToThreeDays() {
        let combos: [Traits] = [
            Traits(appetite: .greedy, affection: .cuddly, vigor: .energetic, courage: .brave, sociality: .loner),
            Traits(appetite: .picky, affection: .aloof, vigor: .lazy, courage: .timid, sociality: .social),
        ]
        for traits in combos {
            var world = makeWorld()
            addPet(&world, traits: traits, name: "Neglected")
            var hours = 0.0
            while world.graveyard.isEmpty && hours < 100 {
                world.advance(by: hour)
                hours += 1
            }
            XCTAssertEqual(world.graveyard.first?.name, "Neglected")
            // Greedy + Cuddly is the fastest decline, just under 2 days.
            XCTAssertTrue((44...72).contains(hours), "\(traits) died after \(hours) h")
        }
    }

    func testCausesOfDeathAreRecorded() {
        func dieOnce(_ setup: (inout Pet) -> Void) -> DeathCause? {
            var world = makeWorld()
            let id = addPet(&world)
            world.update(id) { $0.health = 0.0001; setup(&$0) }
            world.tick(dt: 1)
            return world.graveyard.first?.cause
        }
        XCTAssertEqual(dieOnce { $0.hunger = 0 }, .starvation)
        XCTAssertEqual(dieOnce { $0.happiness = 0 }, .heartbreak)
        XCTAssertEqual(dieOnce { $0.sickRemaining = 100 }, .sickness)
    }

    func testDiesOfOldAge() {
        var world = makeWorld()
        addPet(&world, age: 14 * day + 1, name: "Elder")
        var hours = 0
        while !world.graveyard.contains(where: { $0.name == "Elder" }) && hours < 3000 {
            for i in world.pets.indices {
                world.pets[i].hunger = 100
                world.pets[i].happiness = 100
            }
            world.advance(by: hour)
            hours += 1
        }
        XCTAssertEqual(world.graveyard.first { $0.name == "Elder" }?.cause, .oldAge)
    }

    func testLifeStages() {
        XCTAssertEqual(LifeStage.of(age: 23 * hour), .baby)
        XCTAssertEqual(LifeStage.of(age: 25 * hour), .adult)
        XCTAssertEqual(LifeStage.of(age: 14 * day + 1), .elder)
    }
}

final class PopulationTests: XCTestCase {
    func testFirstLaunchHasOneEgg() {
        let world = World.newWorld(seed: 1)
        XCTAssertEqual(world.eggs.count, 1)
        XCTAssertTrue(world.pets.isEmpty)
        XCTAssertEqual(world.eggs[0].x, World.width / 2)
    }

    func testEggHatchesAfter20MinutesAndPettingSpeedsItUp() {
        var world = World.newWorld(seed: 1)
        world.localHour = { 12 }
        world.monsterSpawnChance = 0
        XCTAssertEqual(world.eggs[0].duration, 20 * 60)
        for _ in 0..<7 { world.petEgg(id: world.eggs[0].id) }
        XCTAssertEqual(world.eggs[0].pettingBonus, 300, "at most 5 min off")
        world.advance(by: 15 * 60 - 2)
        XCTAssertEqual(world.eggs.count, 1)
        world.advance(by: 3)
        XCTAssertEqual(world.pets.count, 1)
        XCTAssertEqual(world.hatchedCount, 1)
        XCTAssertEqual(world.nextHatchDuration, 19 * 60)
        guard case .hatched = world.events.last else { return XCTFail("no hatch event") }
    }

    func testDeathLeavesGraveThatBecomesEgg() {
        var world = makeWorld()
        let id = addPet(&world, x: 90)
        world.update(id) { $0.health = 0.0001; $0.hunger = 0 }
        world.tick(dt: 1)
        XCTAssertEqual(world.graves.count, 1)
        XCTAssertTrue(world.eggs.isEmpty, "the grave stays for 60 s")
        world.advance(by: 60)
        XCTAssertTrue(world.graves.isEmpty)
        XCTAssertEqual(world.eggs.count, 1)
        XCTAssertEqual(world.eggs[0].x, 90)
    }

    func testNeverEmpty() {
        var world = makeWorld()
        world.tick(dt: 1)
        XCTAssertEqual(world.eggs.count, 1)
    }

    func testLayingNeedsSixHoursContentAndAFreeSlot() {
        var world = makeWorld()
        let id = addPet(&world)
        world.update(id) { $0.contentTime = 6 * hour - 5 }
        world.advance(by: 3)
        XCTAssertTrue(world.eggs.isEmpty)
        // Fill the other three slots.
        for x in [40.0, 80, 240] { world.addEgg(at: x, genes: nil) }
        world.advance(by: 5)
        XCTAssertEqual(world.eggs.count, 3)
        XCTAssertEqual(world[pet: id]!.contentTime, 6 * hour, "capped while waiting for a slot")
        world.eggs.removeLast()
        world.tick(dt: 1)
        XCTAssertEqual(world.eggs.count, 3)
        XCTAssertEqual(world[pet: id]!.contentTime, 0)
        XCTAssertEqual(world.eggs.last?.genes.parentName, world[pet: id]!.name)
        XCTAssertEqual(world.eggs.last?.genes.generation, 2)
    }

    func testBabiesDoNotLay() {
        var world = makeWorld()
        let id = addPet(&world, age: hour)
        world.advance(by: 7 * hour)
        XCTAssertEqual(world[pet: id]!.contentTime, 0)
        XCTAssertTrue(world.eggs.isEmpty)
    }

    func testNeverMoreThanFourSlots() {
        var world = makeWorld()
        addPet(&world)
        for _ in 0..<(40 * 24) {
            for i in world.pets.indices {
                world.pets[i].hunger = 100
                world.pets[i].happiness = 100
            }
            world.advance(by: hour)
            XCTAssertLessThanOrEqual(world.usedSlots, World.maxSlots)
        }
        XCTAssertGreaterThan(world.hatchedCount, 1, "the family grew")
    }
}
