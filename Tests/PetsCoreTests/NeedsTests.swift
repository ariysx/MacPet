import XCTest
@testable import PetsCore

final class NeedsTests: XCTestCase {
    func testHungerDecaysAt8_5PerHour() {
        var world = makeWorld()
        let id = addPet(&world)
        world.advance(by: hour)
        XCTAssertEqual(world[pet: id]!.hunger, 100 - 8.5, accuracy: 0.01)
    }

    func testGreedyHungerDecays1_3xFaster() {
        var world = makeWorld()
        var traits = Traits.plain
        traits.appetite = .greedy
        let id = addPet(&world, traits: traits)
        world.advance(by: hour)
        XCTAssertEqual(world[pet: id]!.hunger, 100 - 8.5 * 1.3, accuracy: 0.01)
    }

    func testHappinessDecayByAffection() {
        var world = makeWorld()
        var cuddly = Traits.plain
        cuddly.affection = .cuddly
        let a = addPet(&world, traits: cuddly, x: 40)
        let b = addPet(&world, traits: .plain, x: 280) // aloof
        world.advance(by: hour)
        XCTAssertEqual(world[pet: a]!.happiness, 100 - 4 * 1.2, accuracy: 0.01)
        XCTAssertEqual(world[pet: b]!.happiness, 100 - 4 * 0.7, accuracy: 0.01)
    }

    func testHappinessDecaysTwiceAsFastAfterSixHoursWithoutPetting() {
        var world = makeWorld()
        var traits = Traits.plain
        traits.affection = .cuddly
        let id = addPet(&world, traits: traits)
        world.update(id) { $0.contentTime = -.infinity } // never lays, so it stays alone
        world.advance(by: 6 * hour)
        let before = world[pet: id]!.happiness
        XCTAssertEqual(before, 100 - 6 * 4 * 1.2, accuracy: 0.01)
        world.advance(by: hour)
        XCTAssertEqual(world[pet: id]!.happiness, before - 8 * 1.2, accuracy: 0.01)
    }

    func testEnergyDecayByVigor() {
        var world = makeWorld()
        var lazy = Traits.plain
        lazy.vigor = .lazy
        let a = addPet(&world, traits: .plain, x: 40) // energetic
        let b = addPet(&world, traits: lazy, x: 280)
        world.advance(by: hour)
        XCTAssertEqual(world[pet: a]!.energy, 100 - 6 * 1.4, accuracy: 0.01)
        XCTAssertEqual(world[pet: b]!.energy, 100 - 6 * 0.7, accuracy: 0.01)
    }

    func testNapBelow25RestoresEnergyAndWakesAtFull() {
        var world = makeWorld()
        let id = addPet(&world)
        world.update(id) { $0.energy = 20 }
        world.tick(dt: 1)
        XCTAssertEqual(world[pet: id]!.sleep, .nap)
        world.advance(by: hour)
        XCTAssertEqual(world[pet: id]!.energy, 40, accuracy: 0.1)
        world.advance(by: 3.5 * hour)
        XCTAssertEqual(world[pet: id]!.sleep, .awake)
    }

    func testLazyNapsBelow50WhenNothingIsHappening() {
        var world = makeWorld()
        var lazy = Traits.plain
        lazy.vigor = .lazy
        let a = addPet(&world, traits: lazy, x: 40)
        let b = addPet(&world, traits: .plain, x: 280)
        world.update(a) { $0.energy = 45 }
        world.update(b) { $0.energy = 45 }
        world.tick(dt: 1)
        XCTAssertEqual(world[pet: a]!.sleep, .nap)
        XCTAssertEqual(world[pet: b]!.sleep, .awake)
    }

    func testSleepsAtNightAndWakesAtSeven() {
        var clockHour = 23.5
        var world = makeWorld()
        world.localHour = { clockHour }
        let id = addPet(&world)
        world.tick(dt: 1)
        XCTAssertEqual(world[pet: id]!.sleep, .night)
        XCTAssertEqual(world[pet: id]!.feeling, .sleepy)
        world.advance(by: hour)
        XCTAssertEqual(world[pet: id]!.sleep, .night, "full energy does not end night sleep")
        clockHour = 7.01
        world.tick(dt: 1)
        XCTAssertEqual(world[pet: id]!.sleep, .awake)
    }

    func testPettingGivesSixScaledAndIsLimitedTo20PerMinute() {
        var world = makeWorld()
        var cuddly = Traits.plain
        cuddly.affection = .cuddly
        let id = addPet(&world, traits: cuddly)
        world.update(id) { $0.happiness = 10 }
        XCTAssertEqual(world.petPet(id: id), 9, accuracy: 0.001)
        XCTAssertEqual(world.petPet(id: id, times: 5), 11, accuracy: 0.001)
        XCTAssertEqual(world.petPet(id: id), 0)
        world.advance(by: 61)
        XCTAssertEqual(world.petPet(id: id), 9, accuracy: 0.001)
        XCTAssertEqual(world[pet: id]!.feeling, .excited)
    }

    func testHeldBraveGainsAndTimidLosesHappiness() {
        var world = makeWorld()
        var timid = Traits.plain
        timid.courage = .timid
        let brave = addPet(&world, x: 40)
        let scared = addPet(&world, traits: timid, x: 280)
        for id in [brave, scared] {
            world.update(id) { $0.happiness = 50 }
            world.pickUp(id: id)
        }
        world.advance(by: 10)
        XCTAssertEqual(world[pet: brave]!.happiness, 52, accuracy: 0.05)
        XCTAssertEqual(world[pet: scared]!.happiness, 47, accuracy: 0.05)
        XCTAssertEqual(world[pet: scared]!.feeling, .scared)
    }

    func testSocialGainsNearOthersAndLonerLoses() {
        var world = makeWorld()
        var social = Traits.plain
        social.sociality = .social
        let a = addPet(&world, traits: social, x: 100)
        let b = addPet(&world, traits: .plain, x: 120) // loner, 20 px away
        world.advance(by: hour)
        XCTAssertEqual(world[pet: a]!.happiness, 100 - 4 * 0.7 + 1, accuracy: 0.05)
        XCTAssertEqual(world[pet: b]!.happiness, 100 - 4 * 0.7 - 1, accuracy: 0.05)
    }

    func testOverfeedingThreeTimesMakesSick() {
        var world = makeWorld()
        var greedy = Traits.plain
        greedy.appetite = .greedy
        let id = addPet(&world, traits: greedy)
        for _ in 0..<3 {
            world.update(id) { $0.hunger = 95 }
            world.dropPellet(x: world[pet: id]!.x)
            world.advance(by: 5)
        }
        let pet = world[pet: id]!
        XCTAssertGreaterThan(pet.sickRemaining, 3500)
        XCTAssertEqual(pet.health, 90, accuracy: 0.5)
        XCTAssertEqual(pet.feeling, .sick)
    }

    func testPickyIgnoresFoodAbove50() {
        var world = makeWorld()
        let id = addPet(&world, x: 150)
        world.update(id) { $0.hunger = 60 }
        world.dropPellet(x: 170)
        world.advance(by: 5)
        XCTAssertEqual(world.pellets.count, 1)
        world.update(id) { $0.hunger = 45 }
        world.advance(by: 10)
        XCTAssertEqual(world.pellets.count, 0)
        XCTAssertGreaterThan(world[pet: id]!.hunger, 80, "picky pellets give +40")
    }
}
