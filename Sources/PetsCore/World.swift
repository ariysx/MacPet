import Foundation

enum WorldEvent: Equatable {
    case hatched(name: String, mutations: [String])
    case laidEgg(parent: String)
    case died(name: String, cause: DeathCause)
    case monsterArrived(MonsterKind)
    case monsterDefeated(MonsterKind)
    case monsterAte(MonsterKind)
    case needsCare(name: String, reason: CareReason)
}

/// All pet state and rules. No AppKit or Metal. Positions are in grid pixels; only x
/// matters on the ground, and `height` is how far above the ground line a pet is.
struct World: Codable {
    static let width: Double = 320
    static let maxSlots = 4
    static let edgeMargin: Double = 8
    static let minSpacing: Double = 6
    static let maxPellets = 6
    static let pelletLifetime: Double = 600
    static let graveDuration: Double = 60
    static let mealDuration: Double = 2
    static let pickyRange: Double = 120

    // MARK: Saved

    var clock: Double = 0
    var pets: [Pet] = []
    var eggs: [Egg] = []
    var graves: [Grave] = []
    /// Newest first.
    var graveyard: [GraveyardEntry] = []
    var hatchedCount = 0
    var random: SeededRandom
    var monsterSpawnTimer: Double = 0
    var rainTimer: Double = 0

    // MARK: Not saved

    var monster: Monster?
    var pellets: [Pellet] = []
    var smoke: SmokePuff?
    /// 0...1, eases toward 1 while it rains.
    var rain: Double = 0
    var rainRemaining: Double = 0
    var playerHitCooldown: Double = 0
    /// Things the app may want to notify about. The app drains this.
    var events: [WorldEvent] = []
    var monsterSpawnChance = 0.12
    /// Local hour of day, 0..<24. Injected so tests can pick day or night.
    var localHour: () -> Double = World.systemLocalHour
    var now: () -> Date = { Date() }

    enum CodingKeys: String, CodingKey {
        case clock, pets, eggs, graves, graveyard, hatchedCount, random, monsterSpawnTimer, rainTimer
    }

    init(seed: UInt64) {
        random = SeededRandom(seed: seed)
    }

    /// First launch: one egg in the middle of the ground.
    static func newWorld(seed: UInt64) -> World {
        var world = World(seed: seed)
        world.addEgg(at: width / 2, genes: nil)
        return world
    }

    static func systemLocalHour() -> Double {
        let parts = Calendar.current.dateComponents([.hour, .minute, .second], from: Date())
        return Double(parts.hour ?? 12) + Double(parts.minute ?? 0) / 60 + Double(parts.second ?? 0) / 3600
    }

    static func isNight(hour: Double) -> Bool { hour >= 23 || hour < 7 }

    var usedSlots: Int { pets.count + eggs.count + graves.count }
    var freeSlots: Int { max(0, World.maxSlots - usedSlots) }

    // MARK: Ticking

    /// Advances by any amount of time in steps of at most 1 s.
    mutating func advance(by seconds: Double) {
        var left = seconds
        while left > 0 {
            let step = min(1, left)
            tick(dt: step)
            left -= step
        }
    }

    mutating func tick(dt rawDt: Double) {
        let dt = min(max(rawDt, 0), 1)
        guard dt > 0 else { return }
        clock += dt
        let night = World.isNight(hour: localHour())

        updateEggs(dt: dt)
        updateGraves(dt: dt)
        updatePets(dt: dt, night: night)
        updatePellets(dt: dt)
        updateMonster(dt: dt, night: night)
        updateSmoke(dt: dt)
        updateRain(dt: dt)
        separatePets()
        ensureNotEmpty()
        for i in pets.indices { pets[i].feeling = Feelings.resolve(pets[i]) }
    }

    // MARK: Eggs, graves, population

    /// Hatch time: 20 min minus 1 min per pet hatched so far, at least 5 min.
    var nextHatchDuration: Double { Double(max(5, 20 - hatchedCount)) * 60 }

    @discardableResult
    mutating func addEgg(at x: Double, genes: Genes?) -> Bool {
        guard freeSlots > 0 else { return false }
        let genes = genes ?? Genetics.random(&random)
        eggs.append(Egg(id: UUID(), x: clampX(x), genes: genes, duration: nextHatchDuration))
        return true
    }

    private mutating func updateEggs(dt: Double) {
        var i = 0
        while i < eggs.count {
            eggs[i].elapsed += dt
            if eggs[i].progress >= 1 {
                let egg = eggs.remove(at: i)
                hatch(egg)
            } else {
                i += 1
            }
        }
    }

    private mutating func hatch(_ egg: Egg) {
        let name = PetNames.make(&random, avoiding: Set(pets.map(\.name)))
        var pet = Pet(id: UUID(), name: name, genes: egg.genes, x: egg.x, clock: clock)
        pet.wanderTimer = random.double(in: 2...6)
        pets.append(pet)
        hatchedCount += 1
        events.append(.hatched(name: name, mutations: egg.genes.mutations))
    }

    private mutating func updateGraves(dt: Double) {
        var i = 0
        while i < graves.count {
            graves[i].remaining -= dt
            if graves[i].remaining <= 0 {
                let grave = graves.remove(at: i)
                addEgg(at: grave.x, genes: nil)
            } else {
                i += 1
            }
        }
    }

    private mutating func ensureNotEmpty() {
        if pets.isEmpty && eggs.isEmpty && graves.isEmpty {
            addEgg(at: World.width / 2, genes: nil)
        }
    }

    mutating func kill(petIndex i: Int, cause: DeathCause) {
        let pet = pets.remove(at: i)
        for p in pellets.indices where pellets[p].claimedBy == pet.id { pellets[p].claimedBy = nil }
        graves.append(Grave(id: UUID(), x: pet.x, name: pet.name, remaining: World.graveDuration))
        graveyard.insert(GraveyardEntry(name: pet.name, generation: pet.generation, traits: pet.traits,
                                        looks: pet.looks, age: pet.age, cause: cause, date: now()),
                         at: 0)
        events.append(.died(name: pet.name, cause: cause))
    }

    // MARK: Pets

    private mutating func updatePets(dt: Double, night: Bool) {
        let calm = monster == nil

        var i = 0
        while i < pets.count {
            let x = pets[i].x
            let others = pets.indices.filter { $0 != i }.map { abs(pets[$0].x - x) }
            let near60 = others.filter { $0 <= Traits.socialRange }.count
            let near30 = others.filter { $0 <= Traits.lonerRange }.count
            let calmForPet = calm && pets[i].foodTarget == nil
            if let cause = pets[i].updateNeeds(dt: dt, clock: clock, night: night, calm: calmForPet,
                                               petsWithin60: near60, petsWithin30: near30) {
                kill(petIndex: i, cause: cause)
                continue
            }

            // Old age: each hour as an elder, a 2% chance of dying peacefully.
            if pets[i].stage == .elder {
                pets[i].elderRollTimer += dt
                if pets[i].elderRollTimer >= 3600 {
                    pets[i].elderRollTimer -= 3600
                    if random.chance(0.02) {
                        kill(petIndex: i, cause: .oldAge)
                        continue
                    }
                }
            }

            // Laying
            if pets[i].contentTime >= 6 * 3600 && freeSlots > 0 {
                let genes = Genetics.inherit(from: pets[i], generation: pets[i].generation + 1, &random)
                let side: Double = random.coin() ? 12 : -12
                if addEgg(at: pets[i].x + side, genes: genes) {
                    pets[i].contentTime = 0
                    events.append(.laidEgg(parent: pets[i].name))
                }
            }

            // Care alerts, at most one per pet every 2 h.
            let reason: CareReason? = pets[i].hunger <= 0 ? .starving : pets[i].sickRemaining > 0 ? .sick : nil
            if let reason, clock - pets[i].lastAlertAt >= 2 * 3600 {
                pets[i].lastAlertAt = clock
                events.append(.needsCare(name: pets[i].name, reason: reason))
            }

            updateBehaviour(petIndex: i, dt: dt)
            i += 1
        }
    }

    /// Pet AI, in order: held, falling, eating, fighting or fleeing, food, sleep, wander.
    private mutating func updateBehaviour(petIndex i: Int, dt: Double) {
        if pets[i].held {
            pets[i].isWalking = false
            return
        }
        if pets[i].height > 0 {
            pets[i].height = max(0, pets[i].height - 160 * dt)
            pets[i].isWalking = false
            return
        }
        if pets[i].eatingRemaining > 0 {
            pets[i].eatingRemaining -= dt
            pets[i].isWalking = false
            if pets[i].eatingRemaining <= 0 {
                pets[i].eatingRemaining = 0
                pets[i].finishMeal(clock: clock)
            }
            return
        }
        if monster != nil && pets[i].fight != .none {
            return // movement handled by the fight
        }
        if let target = pets[i].foodTarget {
            guard let p = pellets.firstIndex(where: { $0.id == target }) else {
                pets[i].foodTarget = nil
                return
            }
            if abs(pellets[p].x - pets[i].x) < 2 {
                pets[i].pendingMeal = pets[i].traits.pelletValue
                pets[i].eatingRemaining = World.mealDuration
                pets[i].foodTarget = nil
                pets[i].isWalking = false
                pellets.remove(at: p)
            } else {
                moveToward(petIndex: i, x: pellets[p].x, speed: pets[i].walkSpeed * 1.3, dt: dt)
            }
            return
        }
        if pets[i].isAsleep {
            pets[i].isWalking = false
            return
        }
        pets[i].wanderTimer -= dt
        if pets[i].wanderTimer <= 0 {
            pets[i].wanderTimer = random.double(in: 5...20)
            pets[i].targetX = wanderTarget(for: i)
        }
        moveToward(petIndex: i, x: pets[i].targetX, speed: pets[i].walkSpeed, dt: dt)
    }

    private mutating func wanderTarget(for i: Int) -> Double {
        let pet = pets[i]
        if pet.traits.vigor == .lazy && random.chance(0.4) { return pet.x }
        let others = pets.indices.filter { $0 != i }.map { pets[$0].x }
        if pet.traits.sociality == .social, !others.isEmpty, random.chance(0.6) {
            return clampX(random.pick(others) + random.double(in: -20...20))
        }
        if pet.traits.sociality == .loner, !others.isEmpty {
            // Of three candidate spots, pick the one furthest from anyone.
            var best = pet.x, bestGap = -1.0
            for _ in 0..<3 {
                let candidate = random.double(in: World.edgeMargin...(World.width - World.edgeMargin))
                let gap = others.map { abs($0 - candidate) }.min() ?? 0
                if gap > bestGap { best = candidate; bestGap = gap }
            }
            return best
        }
        return random.double(in: World.edgeMargin...(World.width - World.edgeMargin))
    }

    mutating func moveToward(petIndex i: Int, x target: Double, speed: Double, dt: Double) {
        let dx = clampX(target) - pets[i].x
        if abs(dx) < 0.5 {
            pets[i].isWalking = false
            return
        }
        pets[i].x += (dx < 0 ? -1 : 1) * min(abs(dx), speed * dt)
        pets[i].facingLeft = dx < 0
        pets[i].isWalking = true
    }

    /// Keeps pets at least 6 px apart, except while fighting, held or falling.
    private mutating func separatePets() {
        let order = pets.indices
            .filter { !pets[$0].held && !pets[$0].isFalling && pets[$0].fight != .fighting }
            .sorted { pets[$0].x < pets[$1].x }
        guard order.count > 1 else { return }
        for k in 1..<order.count {
            let a = order[k - 1], b = order[k]
            let gap = pets[b].x - pets[a].x
            if gap < World.minSpacing {
                let push = (World.minSpacing - gap) / 2
                pets[a].x = clampX(pets[a].x - push)
                pets[b].x = clampX(pets[b].x + push)
            }
        }
    }

    func clampX(_ x: Double) -> Double {
        min(World.width - World.edgeMargin, max(World.edgeMargin, x))
    }

    // MARK: Food

    private mutating func updatePellets(dt: Double) {
        for p in pellets.indices { pellets[p].age += dt }
        let expired = Set(pellets.filter { $0.age >= World.pelletLifetime }.map(\.id))
        if !expired.isEmpty {
            pellets.removeAll { expired.contains($0.id) }
            for i in pets.indices where pets[i].foodTarget.map(expired.contains) == true {
                pets[i].foodTarget = nil
            }
        }
        assignFood()
    }

    /// Would this pet walk over to eat a pellet at `x`?
    func wantsFood(_ pet: Pet, at x: Double) -> Bool {
        guard !pet.held, !pet.isAsleep, !pet.isEating, !pet.isFalling, pet.foodTarget == nil else { return false }
        if monster != nil && pet.fight != .none { return false }
        switch pet.traits.appetite {
        case .greedy:
            return true
        case .picky:
            return pet.hunger <= 50 && (pet.hunger < 30 || abs(pet.x - x) <= World.pickyRange)
        }
    }

    private mutating func assignFood() {
        for p in pellets.indices where pellets[p].claimedBy == nil {
            let x = pellets[p].x
            let candidates = pets.indices.filter { wantsFood(pets[$0], at: x) }
            guard let best = candidates.min(by: { abs(pets[$0].x - x) < abs(pets[$1].x - x) }) else { continue }
            pellets[p].claimedBy = pets[best].id
            pets[best].foodTarget = pellets[p].id
        }
    }

    mutating func releaseFood(petIndex i: Int) {
        if let target = pets[i].foodTarget, let p = pellets.firstIndex(where: { $0.id == target }) {
            pellets[p].claimedBy = nil
        }
        pets[i].foodTarget = nil
    }

    // MARK: Weather and effects

    private mutating func updateSmoke(dt: Double) {
        guard var puff = smoke else { return }
        puff.age += dt
        smoke = puff.age >= SmokePuff.duration ? nil : puff
    }

    /// About once a day, 20 to 40 minutes of rain. Purely for looks.
    private mutating func updateRain(dt: Double) {
        rainTimer += dt
        if rainTimer >= 3600 {
            rainTimer -= 3600
            if rainRemaining <= 0 && random.chance(1.0 / 24) {
                rainRemaining = random.double(in: 1200...2400)
            }
        }
        rainRemaining = max(0, rainRemaining - dt)
        let target: Double = rainRemaining > 0 ? 1 : 0
        rain += (target - rain) * min(1, dt / 20)
    }

    // MARK: Player actions (play mode)

    func petIndex(_ id: UUID) -> Int? { pets.firstIndex { $0.id == id } }

    /// A click on a pet. Returns the happiness gained.
    @discardableResult
    mutating func petPet(id: UUID, times: Int = 1) -> Double {
        guard let i = petIndex(id) else { return 0 }
        var total = 0.0
        for _ in 0..<times { total += pets[i].receivePetting(clock: clock) }
        pets[i].feeling = Feelings.resolve(pets[i])
        return total
    }

    /// A click on an egg: 1 min off, at most 5 min in total.
    mutating func petEgg(id: UUID) {
        guard let e = eggs.firstIndex(where: { $0.id == id }) else { return }
        eggs[e].pettingBonus = min(300, eggs[e].pettingBonus + 60)
    }

    /// Hold F and click: drops a pellet on the ground under `x`.
    @discardableResult
    mutating func dropPellet(x: Double) -> Bool {
        guard pellets.count < World.maxPellets else { return false }
        pellets.append(Pellet(id: UUID(), x: clampX(x)))
        assignFood()
        return true
    }

    mutating func pickUp(id: UUID) {
        guard let i = petIndex(id) else { return }
        releaseFood(petIndex: i)
        pets[i].held = true
        pets[i].sleep = .awake
        pets[i].eatingRemaining = 0
        pets[i].pendingMeal = 0
        pets[i].isWalking = false
        if pets[i].fight == .fighting || pets[i].fight == .charging { pets[i].fight = .retreated }
        pets[i].feeling = Feelings.resolve(pets[i])
    }

    mutating func moveHeld(id: UUID, x: Double, height: Double) {
        guard let i = petIndex(id), pets[i].held else { return }
        pets[i].x = min(World.width, max(0, x))
        pets[i].height = max(0, height)
    }

    /// Lets go. Dropped on the monster, the pet joins the fight and its first hit does double damage.
    mutating func drop(id: UUID, x: Double, height: Double) {
        guard let i = petIndex(id) else { return }
        pets[i].held = false
        pets[i].x = clampX(x)
        pets[i].height = max(0, height)
        pets[i].wanderTimer = random.double(in: 3...8)
        pets[i].targetX = pets[i].x
        if let m = monster, m.phase == .attacking, abs(x - m.x) <= m.kind.halfWidth + 4 {
            pets[i].fight = .fighting
            pets[i].thrownBonus = true
            pets[i].attackCooldown = 0
        }
        pets[i].feeling = Feelings.resolve(pets[i])
    }

    // MARK: Loading

    /// Clears everything that only makes sense while the app is running.
    mutating func resetTransientState() {
        monster = nil
        pellets = []
        smoke = nil
        events = []
        for i in pets.indices {
            pets[i].held = false
            pets[i].height = 0
            pets[i].foodTarget = nil
            pets[i].eatingRemaining = 0
            pets[i].pendingMeal = 0
            pets[i].fight = .none
            pets[i].landedHit = false
            pets[i].thrownBonus = false
            pets[i].hurtFlash = 0
            pets[i].isWalking = false
        }
    }
}
