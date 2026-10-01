import Foundation

enum MonsterKind: String, Codable, CaseIterable {
    case slime, shroomling, bat, wolf, wisp, ogre, golem

    var maxHealth: Double {
        switch self {
        case .slime: return 30
        case .shroomling: return 35
        case .bat: return 25
        case .wolf: return 50
        case .wisp: return 30
        case .ogre: return 120
        case .golem: return 160
        }
    }
    var damage: Double {
        switch self {
        case .slime: return 4
        case .shroomling: return 5
        case .bat: return 6
        case .wolf: return 8
        case .wisp: return 7
        case .ogre: return 12
        case .golem: return 14
        }
    }
    var hitInterval: Double {
        switch self {
        case .slime: return 2.0
        case .shroomling: return 2.2
        case .bat: return 1.5
        case .wolf: return 1.6
        case .wisp: return 1.8
        case .ogre: return 2.5
        case .golem: return 3.0
        }
    }
    /// Units per second.
    var speed: Double {
        switch self {
        case .slime: return 6
        case .shroomling: return 7
        case .bat: return 22
        case .wolf: return 18
        case .wisp: return 12
        case .ogre: return 5
        case .golem: return 4
        }
    }
    /// Spawn chance out of 100.
    var weight: Double {
        switch self {
        case .slime: return 30
        case .shroomling: return 18
        case .bat: return 18
        case .wolf: return 14
        case .wisp: return 10
        case .ogre: return 6
        case .golem: return 4
        }
    }
    var isBig: Bool { self == .ogre || self == .golem }
    /// Chance a win drops a Mystery Egg, and a Shiny Egg.
    var eggChance: Double {
        switch self {
        case .slime, .shroomling: return 0.06
        case .bat, .wolf: return 0.12
        case .wisp: return 0.18
        case .ogre: return 0.4
        case .golem: return 0.5
        }
    }
    var shinyEggChance: Double { self == .golem ? 0.25 : self == .ogre ? 0.1 : self == .wisp ? 0.03 : 0 }
    /// Experience for each pet that landed a hit.
    var xp: Double { maxHealth / 2 }
    var flies: Bool { self == .bat || self == .wisp }
    /// How close it has to be to hit a pet.
    var reach: Double { isBig ? 14 : 10 }
    /// Half the sprite's visible width, for hit testing and throwing pets in.
    var halfWidth: Double { isBig ? 12 : 7 }

    static func roll<R: RandomSource>(_ random: inout R) -> MonsterKind {
        var r = random.nextDouble() * allCases.reduce(0) { $0 + $1.weight }
        for kind in allCases {
            r -= kind.weight
            if r < 0 { return kind }
        }
        return .slime
    }
}

enum MonsterPhase {
    case attacking
    case leaving
}

struct Monster {
    var kind: MonsterKind
    var x: Double
    var health: Double
    var fromLeft: Bool
    var phase: MonsterPhase = .attacking
    var age: Double = 0
    var sinceLastHit: Double = 0
    var hitCooldown: Double
    var hurtFlash: Double = 0
    var facingLeft: Bool

    init(kind: MonsterKind, fromLeft: Bool, worldWidth: Double) {
        self.kind = kind
        self.fromLeft = fromLeft
        x = fromLeft ? -kind.halfWidth : worldWidth + kind.halfWidth
        health = kind.maxHealth
        hitCooldown = kind.hitInterval
        facingLeft = !fromLeft
    }

    var exitX: Double { fromLeft ? -kind.halfWidth - 4 : World.width + kind.halfWidth + 4 }
}

/// One blow landing, for hit effects and damage numbers. Not saved.
struct CombatHit: Equatable {
    var x: Double
    var height: Double
    var damage: Double
    /// True when the monster was hit; false when a pet was.
    var onMonster: Bool
    /// A critical hit, a heavy blow from a big monster, or the blow that finished the fight.
    var crit = false
    var heavy = false
    var finishing = false
}

enum Combat {
    static let joinDistance: Double = 40
    static let retreatHealth: Double = 25
    static let lossTimeout: Double = 90
    static let leaveTimeout: Double = 300
    static let playerDamage: Double = 5
    static let playerCooldown: Double = 0.4
    static let critChance: Double = 0.12
    static let critMultiplier: Double = 1.8

    /// Damage of one pet hit, before the thrown-in double.
    static func attackDamage(for pet: Pet, alliesInFight: Int) -> Double {
        var damage = 4 + 4 * (pet.hunger / 100) + min(Double(pet.wins) * 0.5, 6) + (pet.weapon?.attackBonus ?? 0)
            + Double(pet.level - 1) * 0.4
        if pet.stage == .baby { damage *= 0.5 }
        if pet.hasBuff(.strength) { damage *= 1.5 }
        if pet.traits.sociality == .social && alliesInFight > 0 { damage *= Traits.socialAttackMultiplier }
        return damage
    }
}

extension World {
    /// Brings a monster in from a screen edge.
    mutating func spawnMonster(kind: MonsterKind, fromLeft: Bool) {
        monster = Monster(kind: kind, fromLeft: fromLeft, worldWidth: World.width)
        for i in pets.indices {
            pets[i].sleep = .awake
            pets[i].fight = pets[i].health < Combat.retreatHealth ? .retreated : .none
            pets[i].landedHit = false
            pets[i].attackCooldown = 0.5
            releaseFood(petIndex: i)
        }
        events.append(.monsterArrived(kind))
    }

    mutating func updateMonster(dt: Double, night: Bool) {
        playerHitCooldown = max(0, playerHitCooldown - dt)

        guard var m = monster else {
            monsterSpawnTimer += dt
            if monsterSpawnTimer >= World.monsterCheckInterval {
                monsterSpawnTimer -= World.monsterCheckInterval
                if !night && !pets.isEmpty && random.chance(monsterSpawnChance) {
                    let kind = MonsterKind.roll(&random)
                    spawnMonster(kind: kind, fromLeft: random.coin())
                }
            }
            return
        }

        m.age += dt
        m.sinceLastHit += dt
        m.hurtFlash = max(0, m.hurtFlash - dt)
        m.hitCooldown -= dt

        if m.phase == .leaving {
            m.facingLeft = m.exitX < m.x
            m.x += (m.exitX < m.x ? -1 : 1) * min(abs(m.exitX - m.x), m.kind.speed * 1.5 * dt)
            if abs(m.exitX - m.x) < 0.5 {
                monster = nil
                endFight()
            } else {
                monster = m
            }
            return
        }

        if m.age >= Combat.leaveTimeout {
            m.phase = .leaving
            monster = m
            endFight()
            return
        }
        if m.sinceLastHit >= Combat.lossTimeout {
            for i in pets.indices { pets[i].hunger = max(0, pets[i].hunger - 25) }
            events.append(.monsterAte(m.kind))
            m.phase = .leaving
            monster = m
            endFight()
            return
        }

        // Pets pick their roles and hit.
        for i in pets.indices {
            updateFightRole(petIndex: i, monster: m, dt: dt)
        }
        let fighters = pets.indices.filter { pets[$0].fight == .fighting && !pets[$0].held && !pets[$0].isFalling }
        for i in fighters where abs(pets[i].x - m.x) <= m.kind.reach + 2 {
            pets[i].attackCooldown -= dt
            guard pets[i].attackCooldown <= 0 else { continue }
            let allies = fighters.filter { $0 != i && abs(pets[$0].x - m.x) <= m.kind.reach + 2 }.count
            var damage = Combat.attackDamage(for: pets[i], alliesInFight: allies)
            if pets[i].thrownBonus {
                damage *= 2
                pets[i].thrownBonus = false
            }
            let crit = critChance > 0 && random.chance(critChance + (pets[i].relic == .luckyClover ? 0.08 : 0))
            if crit { damage *= Combat.critMultiplier }
            m.health -= damage
            hits.append(CombatHit(x: (m.x + pets[i].x) / 2, height: 8, damage: damage, onMonster: true, crit: crit))
            m.x += (m.x > pets[i].x ? 1 : -1) * 1.5 // a little knockback
            m.hurtFlash = 0.2
            m.sinceLastHit = 0
            pets[i].landedHit = true
            wearWeapon(petIndex: i)
            pets[i].lastAttackAt = clock
            pets[i].attackCooldown = pets[i].attackInterval
        }

        if m.health <= 0 {
            smoke = SmokePuff(x: m.x, y: 0)
            if let last = hits.indices.last, hits[last].onMonster { hits[last].finishing = true }
            let winners = pets.indices.filter { pets[$0].landedHit }
            if !winners.isEmpty { dropMonsterLoot(m.kind, at: m.x, winners: winners) }
            for i in winners {
                pets[i].happiness = min(100, pets[i].happiness + 25)
                pets[i].excitedRemaining = 20
                pets[i].wins += 1
                gainXP(petIndex: i, m.kind.xp)
            }
            events.append(.monsterDefeated(m.kind))
            monster = nil
            endFight()
            return
        }

        // The monster walks to the nearest pet on the ground and hits it.
        let targets = pets.indices.filter { !pets[$0].held && !pets[$0].isFalling }
        if let target = targets.min(by: { abs(pets[$0].x - m.x) < abs(pets[$1].x - m.x) }) {
            let dx = pets[target].x - m.x
            m.facingLeft = dx < 0
            if abs(dx) > m.kind.reach {
                m.x += (dx < 0 ? -1 : 1) * min(abs(dx) - m.kind.reach + 0.5, m.kind.speed * dt)
            } else if m.hitCooldown <= 0 {
                m.hitCooldown = m.kind.hitInterval
                let damage = m.kind.damage * (pets[target].relic == .guardianShell ? 0.6 : 1)
                pets[target].health -= damage
                pets[target].hurtFlash = 0.3
                hits.append(CombatHit(x: pets[target].x, height: 10, damage: damage, onMonster: false, heavy: m.kind.isBig))
                // Knocked back: a hop away from the monster, then it comes back in.
                pets[target].vx = (pets[target].x < m.x ? -1 : 1) * 70
                pets[target].vy = 110
                if pets[target].health <= 0 {
                    pets[target].health = 0
                    monster = m
                    if kill(petIndex: target, cause: .monster) { return }
                }
            }
        } else {
            let middle = World.width / 2
            m.x += (middle < m.x ? -1 : 1) * min(abs(middle - m.x), m.kind.speed * dt)
        }
        monster = m
    }

    private mutating func updateFightRole(petIndex i: Int, monster m: Monster, dt: Double) {
        // Retreating doesn't wait for a knocked-back pet to land.
        if pets[i].health < Combat.retreatHealth && (pets[i].fight == .fighting || pets[i].fight == .charging) {
            pets[i].fight = .retreated
        }
        guard !pets[i].held, !pets[i].isFalling else { return }
        let distance = abs(pets[i].x - m.x)

        switch pets[i].fight {
        case .retreated:
            break
        case .fighting:
            if pets[i].health < Combat.retreatHealth { pets[i].fight = .retreated }
        case .none, .charging, .fleeing:
            if pets[i].health < Combat.retreatHealth {
                pets[i].fight = .retreated
            } else if pets[i].courage == .brave {
                pets[i].fight = distance <= m.kind.reach ? .fighting : .charging
            } else {
                let cornered = abs(pets[i].x - fleeEdge(from: m.x, petX: pets[i].x)) < 10
                pets[i].fight = cornered && distance < Combat.joinDistance ? .fighting : .fleeing
            }
        }

        // Movement for this tick.
        let speed = pets[i].walkSpeed
        switch pets[i].fight {
        case .charging, .fighting:
            if distance > m.kind.reach {
                let goal = m.x + (pets[i].x < m.x ? -m.kind.reach + 2 : m.kind.reach - 2)
                moveToward(petIndex: i, x: goal, speed: speed * 1.3, dt: dt)
            } else {
                pets[i].isWalking = false
                pets[i].facingLeft = m.x < pets[i].x
            }
        case .fleeing, .retreated:
            moveToward(petIndex: i, x: fleeEdge(from: m.x, petX: pets[i].x), speed: speed * 1.4, dt: dt)
        case .none:
            break
        }
    }

    /// The screen edge on the far side of the pet from the monster.
    func fleeEdge(from monsterX: Double, petX: Double) -> Double {
        petX >= monsterX ? World.width - World.edgeMargin : World.edgeMargin
    }

    mutating func endFight() {
        for i in pets.indices {
            pets[i].fight = .none
            pets[i].landedHit = false
            pets[i].thrownBonus = false
            pets[i].wanderTimer = 0
        }
    }

    /// A click on the monster in play mode.
    @discardableResult
    mutating func playerHitMonster() -> Bool {
        guard var m = monster, m.phase == .attacking, playerHitCooldown <= 0 else { return false }
        playerHitCooldown = Combat.playerCooldown
        m.health -= Combat.playerDamage
        hits.append(CombatHit(x: m.x, height: 10, damage: Combat.playerDamage, onMonster: true))
        m.hurtFlash = 0.2
        m.sinceLastHit = 0
        monster = m
        return true
    }
}
