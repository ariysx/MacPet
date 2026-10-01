import Foundation
@testable import PetsCore

let hour: Double = 3600
let day: Double = 24 * hour

extension Traits {
    /// Greedy is the only appetite that changes hunger decay, so "plain" tests use Picky.
    static let plain = Traits(appetite: .picky, affection: .aloof, vigor: .energetic, courage: .brave, sociality: .loner)
}

extension Looks {
    static let plain = Looks(shape: .blob, colourway: PetPalette.colourways[0],
                             pattern: .plain, accessory: .none, eyes: .dot)
}

/// A daytime world with no monsters and a fixed date.
func makeWorld(hour localHour: Double = 12, seed: UInt64 = 7) -> World {
    var world = World(seed: seed)
    world.localHour = { localHour }
    world.monsterSpawnChance = 0
    world.critChance = 0
    world.now = { Date(timeIntervalSince1970: 1_790_000_000) }
    return world
}

/// Adds an adult pet with full needs and returns its id.
@discardableResult
func addPet(_ world: inout World, traits: Traits = .plain, x: Double = 160, age: Double = 2 * day,
            name: String? = nil) -> UUID {
    let genes = Genes(traits: traits, looks: .plain, generation: 1, parentName: nil, mutations: [])
    var pet = Pet(id: UUID(), name: name ?? "Pet\(world.pets.count)", genes: genes, x: x, clock: world.clock)
    pet.age = age
    pet.hunger = 100
    pet.happiness = 100
    pet.energy = 100
    pet.health = 100
    pet.wanderTimer = 1_000_000 // stand still unless a test wants movement
    world.pets.append(pet)
    return pet.id
}

extension World {
    subscript(pet id: UUID) -> Pet? { pets.first { $0.id == id } }

    mutating func update(_ id: UUID, _ change: (inout Pet) -> Void) {
        guard let i = pets.firstIndex(where: { $0.id == id }) else { return }
        change(&pets[i])
    }

    /// Advances in small steps, for fights.
    mutating func run(seconds: Double, step: Double = 0.1) {
        var left = seconds
        while left > 1e-9 {
            tick(dt: min(step, left))
            left -= step
        }
    }
}
