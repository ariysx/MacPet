import XCTest
@testable import PetsCore

final class FeelingTests: XCTestCase {
    private func pet(_ change: (inout Pet) -> Void = { _ in }) -> Pet {
        var world = makeWorld()
        let id = addPet(&world)
        world.update(id) { $0.hunger = 80; $0.happiness = 80; $0.energy = 80 }
        var p = world[pet: id]!
        change(&p)
        return p
    }

    func testEachRow() {
        XCTAssertEqual(Feelings.resolve(pet { $0.held = true; $0.traits.courage = .timid }), .scared)
        XCTAssertEqual(Feelings.resolve(pet { $0.fight = .fleeing }), .scared)
        XCTAssertEqual(Feelings.resolve(pet { $0.sickRemaining = 10 }), .sick)
        XCTAssertEqual(Feelings.resolve(pet { $0.health = 29 }), .sick)
        XCTAssertEqual(Feelings.resolve(pet { $0.sleep = .nap }), .sleepy)
        XCTAssertEqual(Feelings.resolve(pet { $0.energy = 24 }), .sleepy)
        XCTAssertEqual(Feelings.resolve(pet { $0.hunger = 29 }), .hungry)
        XCTAssertEqual(Feelings.resolve(pet { $0.happiness = 29 }), .sad)
        XCTAssertEqual(Feelings.resolve(pet { $0.excitedRemaining = 5 }), .excited)
        XCTAssertEqual(Feelings.resolve(pet()), .content)
    }

    func testHigherPriorityWinsTies() {
        XCTAssertEqual(Feelings.resolve(pet { $0.held = true; $0.traits.courage = .timid; $0.health = 10 }), .scared)
        XCTAssertEqual(Feelings.resolve(pet { $0.health = 10; $0.sleep = .nap; $0.hunger = 0 }), .sick)
        XCTAssertEqual(Feelings.resolve(pet { $0.energy = 10; $0.hunger = 10; $0.happiness = 10 }), .sleepy)
        XCTAssertEqual(Feelings.resolve(pet { $0.hunger = 10; $0.happiness = 10 }), .hungry)
        XCTAssertEqual(Feelings.resolve(pet { $0.happiness = 10; $0.excitedRemaining = 5 }), .sad)
        XCTAssertEqual(Feelings.resolve(pet { $0.held = true }), .content, "held brave pets are not scared")
    }
}

final class GeneticsTests: XCTestCase {
    func testChildInheritsWithFewMutations() {
        var world = makeWorld()
        let id = addPet(&world, name: "Mopo")
        world.update(id) { $0.generation = 3; $0.looks.accessory = .horns; $0.looks.pattern = .spots }
        let parent = world[pet: id]!
        var random = SeededRandom(seed: 5)
        var sameAccessory = 0, sameTraits = 0
        for _ in 0..<1000 {
            let genes = Genetics.inherit(from: parent, generation: 4, &random)
            XCTAssertEqual(genes.parentName, "Mopo")
            XCTAssertEqual(genes.generation, 4)
            if genes.looks.accessory == .horns { sameAccessory += 1 }
            if genes.traits == parent.traits { sameTraits += 1 }
        }
        XCTAssertEqual(Double(sameAccessory) / 1000, 0.85, accuracy: 0.04)
        XCTAssertGreaterThan(sameTraits, 250, "most children keep most traits")
        XCTAssertLessThan(sameTraits, 800, "but mutations do happen")
    }

    func testMutationsAreListed() {
        var world = makeWorld()
        let id = addPet(&world)
        let parent = world[pet: id]!
        var random = SeededRandom(seed: 11)
        for _ in 0..<200 {
            let genes = Genetics.inherit(from: parent, generation: 2, &random)
            if genes.looks.accessory != parent.looks.accessory {
                XCTAssertTrue(genes.mutations.contains(Looks.words(genes.looks.accessory.rawValue))
                              || genes.looks.accessory == .none)
            }
            if genes.traits.courage != parent.traits.courage {
                XCTAssertTrue(genes.mutations.contains("Timid"))
            }
        }
    }

    func testHueShift() {
        let green = PetPalette.shiftHue(0xFF0000, degrees: 120)
        XCTAssertGreaterThan((green >> 8) & 0xFF, 200)
        XCTAssertLessThan((green >> 16) & 0xFF, 20)
        XCTAssertEqual(PetPalette.shiftHue(0x808080, degrees: 90), 0x808080, "grey has no hue")
    }

    func testHatchedPetGetsGenesAndUniqueName() {
        var world = makeWorld()
        addPet(&world, name: "Kiri")
        let genes = Genes(traits: .plain, looks: .plain, generation: 5, parentName: "Kiri", mutations: ["horns"])
        world.addEgg(at: 100, genes: genes)
        world.eggs[0].elapsed = world.eggs[0].duration
        world.tick(dt: 0.1)
        let child = world.pets.last!
        XCTAssertEqual(child.generation, 5)
        XCTAssertEqual(child.parentName, "Kiri")
        XCTAssertEqual(child.mutations, ["horns"])
        XCTAssertNotEqual(child.name, "Kiri")
        XCTAssertEqual(child.stage, .baby)
    }
}

final class SaveTests: XCTestCase {
    private var directory: URL!

    override func setUp() {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: directory)
    }

    func testRoundTripKeepsEverything() throws {
        var world = makeWorld()
        let id = addPet(&world, name: "Tabu")
        world.update(id) { $0.hunger = 42; $0.wins = 3; $0.contentTime = 99; $0.looks.accessory = .leaf }
        world.addEgg(at: 50, genes: nil)
        world.advance(by: 90)
        let other = addPet(&world, x: 250, name: "Gone")
        world.update(other) { $0.health = 0.0001; $0.hunger = 0 }
        world.tick(dt: 1)

        let url = directory.appendingPathComponent("world.json")
        try SaveStore.save(world, to: url)
        let (loaded, outcome) = SaveStore.load(from: url, newSeed: 1)

        XCTAssertEqual(outcome, .loaded)
        XCTAssertEqual(loaded.clock, world.clock)
        XCTAssertEqual(loaded.random, world.random)
        XCTAssertEqual(loaded.hatchedCount, world.hatchedCount)
        let a = world[pet: id]!, b = loaded[pet: id]!
        XCTAssertEqual(b.name, a.name)
        XCTAssertEqual(b.hunger, a.hunger)
        XCTAssertEqual(b.health, a.health)
        XCTAssertEqual(b.age, a.age)
        XCTAssertEqual(b.wins, 3)
        XCTAssertEqual(b.contentTime, a.contentTime)
        XCTAssertEqual(b.traits, a.traits)
        XCTAssertEqual(b.looks, a.looks)
        XCTAssertEqual(b.x, a.x)
        XCTAssertEqual(loaded.eggs.map(\.progress), world.eggs.map(\.progress))
        XCTAssertEqual(loaded.eggs.map(\.genes), world.eggs.map(\.genes))
        XCTAssertEqual(loaded.graves.map(\.name), ["Gone"])
        XCTAssertEqual(loaded.graveyard, world.graveyard)
    }

    func testMonstersAndHeldStateAreNotSaved() throws {
        var world = makeWorld()
        let id = addPet(&world)
        world.spawnMonster(kind: .bat, fromLeft: true)
        world.pickUp(id: id)
        world.dropPellet(x: 10)
        let url = directory.appendingPathComponent("world.json")
        try SaveStore.save(world, to: url)
        let (loaded, _) = SaveStore.load(from: url, newSeed: 1)
        XCTAssertNil(loaded.monster)
        XCTAssertTrue(loaded.pellets.isEmpty)
        XCTAssertFalse(loaded[pet: id]!.held)
    }

    func testTimeDoesNotPassWhileClosed() throws {
        var world = makeWorld()
        let id = addPet(&world)
        world.advance(by: 3 * hour)
        let url = directory.appendingPathComponent("world.json")
        try SaveStore.save(world, to: url)
        // "Closed" for a while: nothing ticks, and loading must not catch up.
        let (loaded, _) = SaveStore.load(from: url, newSeed: 1, date: Date().addingTimeInterval(5 * day))
        XCTAssertEqual(loaded.clock, world.clock)
        XCTAssertEqual(loaded[pet: id]!.hunger, world[pet: id]!.hunger)
        XCTAssertEqual(loaded[pet: id]!.age, world[pet: id]!.age)
    }

    func testMissingFileStartsNewWorld() {
        let (world, outcome) = SaveStore.load(from: directory.appendingPathComponent("none.json"), newSeed: 3)
        XCTAssertEqual(outcome, .created)
        XCTAssertEqual(world.eggs.count, 1)
    }

    func testCorruptFileIsRenamedAndNewWorldStarts() throws {
        let url = directory.appendingPathComponent("world.json")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Data("{ not json".utf8).write(to: url)
        let date = Date(timeIntervalSince1970: 1_790_000_000)
        let (world, outcome) = SaveStore.load(from: url, newSeed: 3, date: date)
        guard case .recovered(let moved) = outcome else { return XCTFail("expected recovery, got \(outcome)") }
        XCTAssertTrue(moved.lastPathComponent.hasPrefix("world.corrupt-"))
        XCTAssertTrue(FileManager.default.fileExists(atPath: moved.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
        XCTAssertEqual(world.eggs.count, 1)
        XCTAssertTrue(world.pets.isEmpty)
    }
}

final class LayoutTests: XCTestCase {
    func testStridesMatchMetal() {
        XCTAssertEqual(MemoryLayout<SceneUniforms>.stride, 64)
        XCTAssertEqual(MemoryLayout<SceneItem>.stride, 80)
        XCTAssertEqual(MemoryLayout<SceneItem>.offset(of: \.primary), 16)
        XCTAssertEqual(MemoryLayout<SceneItem>.offset(of: \.icon), 64)
        XCTAssertEqual(MemoryLayout<SceneUniforms>.offset(of: \.itemCount), 32)
        XCTAssertEqual(MemoryLayout<SceneUniforms>.offset(of: \.pad), 48)
    }
}
