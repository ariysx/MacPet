import Foundation

enum LifeStage: String, Codable {
    case baby, adult, elder

    static let adultAge: Double = 24 * 3600
    static let elderAge: Double = 14 * 24 * 3600

    static func of(age: Double) -> LifeStage {
        age < adultAge ? .baby : age < elderAge ? .adult : .elder
    }
}

enum DeathCause: String, Codable, CaseIterable {
    case starvation, heartbreak, sickness, monster, oldAge

    var title: String {
        switch self {
        case .starvation: return "starvation"
        case .heartbreak: return "heartbreak"
        case .sickness: return "sickness"
        case .monster: return "a monster"
        case .oldAge: return "old age"
        }
    }
}

enum FightRole: String, Codable {
    /// Not involved (or no monster).
    case none
    /// Brave: walking straight at the monster.
    case charging
    /// In range and hitting.
    case fighting
    /// Timid: running to the far edge.
    case fleeing
    /// Health below 25: out of this fight for good.
    case retreated
}

enum SleepKind: String, Codable {
    case awake
    /// Daytime nap, ends at full energy.
    case nap
    /// Night sleep, ends at 07:00.
    case night
}

/// Which way a pet faces. Pets only move left and right; front and back are for standing
/// still: looking at you, or looking off into the landscape.
enum PetFacing: String, Codable, CaseIterable {
    case side, front, back
}

enum CareReason: String, Codable {
    case starving, sick
}

struct Pet: Codable, Identifiable {
    static let maxNeed: Double = 100

    var id: UUID
    var name: String
    var traits: Traits
    var looks: Looks
    var generation = 1
    var parentName: String?
    var mutations: [String] = []

    /// Seconds of app running time since hatching.
    var age: Double = 0
    var hunger: Double = 70
    var happiness: Double = 80
    var energy: Double = 100
    var health: Double = 100
    var wins = 0
    var weapon: Item?
    var relic: Item?
    var buffs: [Buff] = []
    /// Time spent with hunger, happiness and energy all above 70. Lays an egg at 6 h.
    var contentTime: Double = 0

    /// Grid pixels from the left edge.
    var x: Double
    var facingLeft = false
    var facing: PetFacing = .side
    /// The facing it takes up when it stops walking, rolled with each new wander target.
    var idleFacing: PetFacing = .front
    var sleep: SleepKind = .awake
    var sickRemaining: Double = 0
    /// World clock times of overfed meals in the last 2 h.
    var overfeedTimes: [Double] = []
    var lastPettedAt: Double
    var pettingWindowStart: Double = 0
    var pettingInWindow: Double = 0
    var excitedRemaining: Double = 0
    var heldAccumulator: Double = 0
    var elderRollTimer: Double = 0
    var lastAlertAt: Double = -1_000_000

    // Movement
    var targetX: Double
    var wanderTimer: Double = 0
    var isWalking = false

    // Interaction and fights. Reset on load (see World.resetTransientState).
    var held = false
    /// Grid pixels above the ground line while held or falling.
    var height: Double = 0
    var foodTarget: UUID?
    var eatingRemaining: Double = 0
    var pendingMeal: Double = 0
    var fight: FightRole = .none
    var attackCooldown: Double = 0
    var landedHit = false
    var thrownBonus = false
    var hurtFlash: Double = 0
    var lastAttackAt: Double = -1_000_000
    var feeling: Feeling = .content

    init(id: UUID, name: String, genes: Genes, x: Double, clock: Double) {
        self.id = id
        self.name = name
        self.traits = genes.traits
        self.looks = genes.looks
        self.generation = genes.generation
        self.parentName = genes.parentName
        self.mutations = genes.mutations
        self.x = x
        self.targetX = x
        self.lastPettedAt = clock
    }

    var stage: LifeStage { LifeStage.of(age: age) }
    var isAsleep: Bool { sleep != .awake }
    var isFalling: Bool { !held && height > 0 }
    var isEating: Bool { eatingRemaining > 0 }

    func hasBuff(_ kind: BuffKind) -> Bool { buffs.contains { $0.kind == kind } }

    mutating func addBuff(_ kind: BuffKind, seconds: Double) {
        buffs.removeAll { $0.kind == kind }
        buffs.append(Buff(kind: kind, remaining: seconds))
    }

    /// Timid pets act Brave under a Courage Potion.
    var courage: Courage { hasBuff(.courage) ? .brave : traits.courage }

    /// Seconds between hits in a fight, after trait and weapon.
    var attackInterval: Double { traits.attackInterval * (weapon?.attackIntervalMultiplier ?? 1) }

    /// Grid pixels per second.
    var walkSpeed: Double {
        var speed = 10 * traits.walkSpeedMultiplier
        if relic == .featherCharm { speed *= 1.25 }
        if stage == .elder { speed *= 0.6 }
        if feeling == .sad { speed *= 0.7 }
        return speed
    }

    mutating func clampNeeds() {
        hunger = min(Self.maxNeed, max(0, hunger))
        happiness = min(Self.maxNeed, max(0, happiness))
        energy = min(Self.maxNeed, max(0, energy))
        health = min(Self.maxNeed, max(0, health))
    }

    /// Advances needs, sleep, health and timers. Returns the cause if health ran out.
    /// `calm` is true when nothing is going on (no monster, no food to fetch).
    mutating func updateNeeds(dt: Double, clock: Double, night: Bool, calm: Bool,
                              petsWithin60: Int, petsWithin30: Int) -> DeathCause? {
        let hours = dt / 3600
        age += dt
        for b in buffs.indices { buffs[b].remaining -= dt }
        buffs.removeAll { $0.remaining <= 0 }
        let sleepGain = 20 * hours * (relic == .moonPillow ? 1.5 : 1)

        // Sleep and energy
        if held || fight != .none { sleep = .awake }
        switch sleep {
        case .night:
            energy += sleepGain
            if !night { sleep = .awake }
        case .nap:
            energy += sleepGain
            if energy >= Self.maxNeed { sleep = .awake }
        case .awake:
            energy -= 6 * hours * traits.energyDecayMultiplier
            if !held && fight == .none && !isEating && !isFalling {
                if night {
                    sleep = .night
                } else if energy < 25 || (energy < traits.calmNapThreshold && calm) {
                    sleep = .nap
                }
            }
        }

        // Hunger
        hunger -= 8.5 * hours * traits.hungerDecayMultiplier * (relic == .snackPouch ? 0.75 : 1)

        // Happiness
        let lonely = clock - lastPettedAt >= 6 * 3600
        happiness -= (lonely ? 8 : 4) * hours * traits.happinessDecayMultiplier * (relic == .cozyScarf ? 0.75 : 1)
        switch traits.sociality {
        case .social: happiness += Double(petsWithin60) * hours
        case .loner: happiness -= Double(petsWithin30) * hours
        }
        if held {
            heldAccumulator += dt
            while heldAccumulator >= 10 {
                heldAccumulator -= 10
                happiness += courage == .brave ? 2 : -3
            }
        } else {
            heldAccumulator = 0
        }

        // Timers
        sickRemaining = max(0, sickRemaining - dt)
        excitedRemaining = max(0, excitedRemaining - dt)
        hurtFlash = max(0, hurtFlash - dt)
        clampNeeds()

        // Egg laying builds up while everything is above 70.
        if stage != .baby && hunger > 70 && happiness > 70 && energy > 70 {
            contentTime = min(6 * 3600, contentTime + dt)
        }

        // Health
        let starving = hunger <= 0
        let heartbroken = happiness < 10
        let sick = sickRemaining > 0
        let drains = (starving ? 1 : 0) + (heartbroken ? 1 : 0) + (sick ? 1 : 0)
        if drains > 0 {
            health -= 1.4 * Double(drains) * hours
        } else if hunger > 40 && happiness > 40 {
            health += 3 * hours * (relic == .heartLocket ? 2 : 1)
        }
        clampNeeds()

        guard health <= 0 else { return nil }
        if starving { return .starvation }
        if heartbroken { return .heartbreak }
        return .sickness
    }

    /// Adds happiness from petting, limited to +20 a minute. Returns the amount gained.
    @discardableResult
    mutating func receivePetting(clock: Double) -> Double {
        if clock - pettingWindowStart >= 60 {
            pettingWindowStart = clock
            pettingInWindow = 0
        }
        let gain = min(6 * traits.pettingMultiplier, max(0, 20 - pettingInWindow))
        pettingInWindow += gain
        happiness = min(Self.maxNeed, happiness + gain)
        lastPettedAt = clock
        excitedRemaining = 20
        return gain
    }

    /// Finishes a meal. Three overfed meals within 2 h make the pet sick.
    mutating func finishMeal(clock: Double) {
        if hunger > 90 {
            overfeedTimes.append(clock)
        }
        overfeedTimes.removeAll { clock - $0 > 2 * 3600 }
        if overfeedTimes.count >= 3 {
            overfeedTimes.removeAll()
            sickRemaining = 3600
            health -= 10
        }
        hunger += pendingMeal
        pendingMeal = 0
        excitedRemaining = 20
        clampNeeds()
    }
}

struct Egg: Codable, Identifiable {
    var id: UUID
    var x: Double
    var genes: Genes
    /// Seconds to hatch.
    var duration: Double
    var elapsed: Double = 0
    /// Seconds taken off by petting, at most 5 min.
    var pettingBonus: Double = 0
    /// Touched by a Mutagen: drawn with a shimmer.
    var mutated = false

    var progress: Double { min(1, (elapsed + pettingBonus) / duration) }
    var remaining: Double { max(0, duration - elapsed - pettingBonus) }
}

struct Grave: Codable, Identifiable {
    var id: UUID
    var x: Double
    var name: String
    var remaining: Double = 60
}

struct GraveyardEntry: Codable, Equatable {
    var name: String
    var generation: Int
    var traits: Traits
    var looks: Looks
    var age: Double
    var cause: DeathCause
    var date: Date
}

struct Pellet: Identifiable {
    var id: UUID
    var x: Double
    var age: Double = 0
    var claimedBy: UUID?
}

struct SmokePuff {
    var x: Double
    var y: Double
    var age: Double = 0
    static let duration: Double = 0.9
}
