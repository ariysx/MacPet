import Foundation

/// Something clickable in play mode, in grid pixels.
struct HitBox {
    enum Target: Equatable {
        case pet(UUID), egg(UUID), monster, loot(UUID), pellet(UUID)
    }

    var target: Target
    var minX: Float, minY: Float, maxX: Float, maxY: Float

    func contains(_ p: SIMD2<Float>, margin: Float = 0) -> Bool {
        p.x >= minX - margin && p.x <= maxX + margin && p.y >= minY - margin && p.y <= maxY + margin
    }
}

/// A short-lived effect at a spot on the grid, such as a hit.
struct SceneEffect {
    var x: Float
    var y: Float
    var born: Double
    static let duration = 0.32
}

struct SceneFrame {
    var items: [SceneItem] = []
    /// Front to back, for hit testing.
    var hits: [HitBox] = []
}

/// Turns the World into the item list the shader draws, once per frame.
enum SceneBuilder {
    /// The screen grid is 960 wide; the simulation is 320 wide. Sprites are drawn at grid scale.
    static let gridWidth: Float = 960
    static let worldScale: Float = gridWidth / Float(World.width)

    static func gx(_ x: Double) -> Float { Float(x) * worldScale }

    static func build(world: World, groundY: Float, time: Double, playMode: Bool,
                      atlas: SpriteAtlas, regions: PetSpriteRegions, effects: [SceneEffect] = []) -> SceneFrame {
        var entries: [(item: SceneItem, hit: HitBox?, priority: Int)] = []
        for effect in effects {
            let age = time - effect.born
            guard age >= 0 && age < SceneEffect.duration else { continue }
            var item = SceneItem()
            item.position = SIMD2(effect.x, effect.y - 32)
            item.tile = atlas.tile(.impact(min(PropArt.impactFrames - 1, Int(age / SceneEffect.duration * Double(PropArt.impactFrames)))))
            entries.append((item, nil, 5))
        }
        let clock = world.clock

        for grave in world.graves {
            var item = SceneItem()
            item.position = SIMD2(gx(grave.x), groundY)
            item.tile = atlas.tile(.grave)
            entries.append((item, nil, 3))
        }

        for egg in world.eggs {
            var item = SceneItem()
            let x = gx(egg.x)
            item.position = SIMD2(x, groundY)
            let wobble = Int(time * (2 + egg.progress * 6)) % 4
            let still = (time * (0.3 + egg.progress)).truncatingRemainder(dividingBy: 1) > 0.35
            item.tile = atlas.tile(.egg(egg.remaining < 60 ? 4 + Int(time * 8) % 2 : still ? 0 : wobble))
            item.primary = PetPalette.rgba(0xF7EEDC)
            item.secondary = PetPalette.rgba(egg.genes.looks.primary)
            item.bars = SIMD4(Float(egg.progress), 0, 0, 0)
            item.flags = SceneItem.Flags.eggBar.rawValue
            item.barLift = 42
            item.shadow = 14
            if egg.mutated && Int(time * 2) % 2 == 0 {
                item.icon = Int32(atlas.tile(.icon(.sparkle)))
            }
            let hit = HitBox(target: .egg(egg.id), minX: x - 14, minY: groundY, maxX: x + 14, maxY: groundY + 38)
            entries.append((item, hit, 3))
        }

        for loot in world.loot {
            var item = SceneItem()
            let x = gx(loot.x)
            // New loot falls in from above and bounces, so it's clearly a delivery.
            var drop: Float = 0
            if loot.age < 1.1 {
                let t = Float(loot.age)
                drop = t < 0.6 ? 160 * (1 - t / 0.6) * (1 - t / 0.6) : 14 * abs(sin((t - 0.6) / 0.5 * .pi)) * (1.1 - t) / 0.5
            }
            item.position = SIMD2(x, groundY + drop)
            if loot.age < 2.5 && Int(time * 10) % 2 == 0 { item.icon = Int32(atlas.tile(.icon(.sparkle))) }
            switch loot.kind {
            case .dailyChest:
                item.tile = atlas.tile(.chest)
                item.primary = PetPalette.rgba(0xA0673A)
                item.secondary = PetPalette.rgba(0xF2C14E)
            case .bag:
                item.tile = atlas.tile(.bag)
                item.primary = PetPalette.rgba(0xE8D3A6)
                item.secondary = PetPalette.rgba(0xD9534F)
            }
            item.shadow = 18
            item.barLift = 36
            if (time + Double(loot.x)).truncatingRemainder(dividingBy: 3) < 1 {
                item.icon = Int32(atlas.tile(.icon(.sparkle)))
            }
            let hit = HitBox(target: .loot(loot.id), minX: x - 20, minY: groundY, maxX: x + 20, maxY: groundY + 34)
            entries.append((item, hit, 2))
        }

        for pellet in world.pellets {
            var item = SceneItem()
            let x = gx(pellet.x)
            // Food drops in from where it was placed, with a little bounce.
            let t = Float(pellet.age)
            let drop: Float = t < 0.3 ? 60 * (1 - t / 0.3) * (1 - t / 0.3) : t < 0.5 ? 6 * sin((t - 0.3) / 0.2 * .pi) : 0
            item.position = SIMD2(x, groundY + drop)
            item.tile = atlas.tile(.pellet)
            item.shadow = 6
            let hit = HitBox(target: .pellet(pellet.id), minX: x - 8, minY: groundY, maxX: x + 8, maxY: groundY + 16)
            entries.append((item, hit, 1))
        }

        for pet in world.pets {
            guard let region = regions.readyRegion(for: pet.id) else { continue }
            let (petItem, weaponItem, hit) = petItems(pet, clock: clock, time: time, groundY: groundY, playMode: playMode,
                                                      atlas: atlas, region: region)
            entries.append((petItem, hit, 4))
            if let weaponItem { entries.append((weaponItem, nil, 4)) }
        }

        if let m = world.monster {
            var item = SceneItem()
            let x = gx(m.x)
            // The attack animation plays right after each hit.
            let sinceHit = m.kind.hitInterval - m.hitCooldown
            let attacking = m.phase == .attacking && sinceHit >= 0 && sinceHit < Double(m.kind.attackFrames) / 10
            let frame = attacking ? min(m.kind.attackFrames - 1, Int(sinceHit * 10)) : Int(time * m.kind.moveFPS) % m.kind.moveFrames
            var y = groundY
            if m.kind.flies { y += 16 + 20 * Float(0.5 + 0.5 * sin(m.age * 2)) }
            item.position = SIMD2(x, y)
            item.tile = atlas.tile(.monster(m.kind, attack: attacking, frame))
            item.tileSpan = m.kind.isBig ? 2 : 1
            item.primary = PetPalette.rgba(m.kind.colours.0)
            item.secondary = PetPalette.rgba(m.kind.colours.1)
            var flags: SceneItem.Flags = []
            if m.facingLeft { flags.insert(.flipX) }
            if m.hurtFlash > 0 { flags.insert(.hurtFlash) }
            if m.phase == .attacking {
                flags.insert(.monsterBar)
                item.bars = SIMD4(Float(max(0, m.health / m.kind.maxHealth)), 0, 0, 0)
                item.barLift = m.kind.isBig ? 104 : m.kind.flies ? 52 : 44
            }
            item.flags = flags.rawValue
            item.shadow = m.kind.isBig ? 32 : 18
            let half = Float(m.kind.halfWidth) * worldScale
            let height: Float = m.kind.isBig ? 100 : 44
            let hit = HitBox(target: .monster, minX: x - half, minY: y, maxX: x + half, maxY: y + height)
            entries.append((item, hit, 5))
        }

        if let puff = world.smoke {
            var item = SceneItem()
            item.position = SIMD2(gx(puff.x), groundY)
            let frame = min(PropArt.smokeFrames - 1, Int(puff.age / SmokePuff.duration * Double(PropArt.smokeFrames)))
            item.tile = atlas.tile(.smoke(frame))
            entries.append((item, nil, 5))
        }

        // Keep the most important things if there are ever too many.
        if entries.count > SceneItem.maxCount {
            entries = Array(entries.enumerated()
                .sorted { $0.element.priority != $1.element.priority ? $0.element.priority > $1.element.priority : $0.offset < $1.offset }
                .prefix(SceneItem.maxCount)
                .map(\.element))
        }

        // Back to front: higher on screen first, so lower items draw in front.
        let ordered = entries.enumerated().sorted {
            let a = $0.element.item.position.y, b = $1.element.item.position.y
            return a != b ? a > b : $0.offset < $1.offset
        }.map(\.element)

        var frame = SceneFrame()
        frame.items = ordered.map(\.item)
        frame.hits = ordered.reversed().compactMap(\.hit)
        return frame
    }

    private static func petItems(_ pet: Pet, clock: Double, time: Double, groundY: Float, playMode: Bool,
                                 atlas: SpriteAtlas, region: Int) -> (SceneItem, SceneItem?, HitBox) {
        let baby = pet.stage == .baby
        let anim = animation(for: pet, clock: clock)
        var frame: Int
        if let air = airFrame(pet) {
            frame = air
        } else if anim == .attack {
            frame = min(anim.frameCount - 1, Int((clock - pet.lastAttackAt) * anim.fps))
        } else {
            frame = Int(time * anim.fps) % anim.frameCount
        }

        var x = gx(pet.x)
        let y = groundY + Float(pet.height) * worldScale
        if pet.feeling == .scared && !pet.isAsleep { x += Int(time * 14) % 2 == 0 ? -2 : 2 }

        var item = SceneItem()
        item.position = SIMD2(x, y)
        item.tile = atlas.petTile(region: region, view: pet.facing, anim: anim, frame: frame, baby: baby)
        item.primary = PetPalette.rgba(pet.looks.primary)
        item.secondary = PetPalette.rgba(pet.looks.secondary)
        item.shadow = baby ? 12 : 18
        item.barLift = baby ? 42 : 58

        var flags: SceneItem.Flags = []
        if pet.facingLeft && pet.facing == .side { flags.insert(.flipX) }
        if pet.hurtFlash > 0 { flags.insert(.hurtFlash) }
        if pet.health < 25 { flags.insert(.blinkHealth) }
        item.flags = flags.rawValue

        if playMode || pet.health < 30 || pet.hunger < 30 || pet.happiness < 30 {
            item.bars = SIMD4(Float(pet.health / 100), Float(pet.hunger / 100), Float(pet.happiness / 100), 0)
        }
        if let icon = icon(for: pet, clock: clock) {
            item.icon = Int32(atlas.tile(.icon(icon)))
        }

        var weaponItem: SceneItem?
        if let weapon = pet.weapon, !pet.isAsleep, pet.facing != .back {
            var w = SceneItem()
            let forward: Float = pet.facing == .front ? 14 : (anim == .attack && frame >= 2 && frame <= 4 ? 22 : 16)
            let left = pet.facing == .side && pet.facingLeft
            w.position = SIMD2(x + (left ? -forward : forward), y + (baby ? 6 : 10) - 0.01)
            w.tile = atlas.tile(.weapon(weapon))
            w.flags = left ? SceneItem.Flags.flipX.rawValue : 0
            weaponItem = w
        }

        let half: Float = baby ? 14 : 20
        let hit = HitBox(target: .pet(pet.id), minX: x - half, minY: y, maxX: x + half, maxY: y + (baby ? 34 : 48))
        return (item, weaponItem, hit)
    }

    /// Hop frames for flight: stretched rising, tucked falling, crouched on landing.
    static func airFrame(_ pet: Pet) -> Int? {
        if pet.held { return nil }
        if pet.isFalling { return pet.vy > 60 ? 1 : pet.vy < -60 ? 4 : 3 }
        if pet.landSquash > 0 { return 0 }
        return nil
    }

    static func animation(for pet: Pet, clock: Double) -> PetAnim {
        if pet.held { return .held }
        if airFrame(pet) != nil { return .hop }
        if pet.hurtFlash > 0 { return .hurt }
        if pet.isAsleep { return .sleep }
        if pet.isEating { return .eat }
        if pet.fight == .fighting && clock - pet.lastAttackAt < 0.5 { return .attack }
        if pet.feeling == .sick { return .sick }
        if pet.feeling == .excited { return .hop }
        if pet.isWalking { return .walk }
        return .idle
    }

    private static func icon(for pet: Pet, clock: Double) -> IconKind? {
        if clock - pet.lastPettedAt < 1.5 { return .heart }
        if pet.feeling == .content {
            // A small heart for 2 s every 30 s, staggered per pet.
            let phase = Double(pet.id.uuidString.unicodeScalars.reduce(0) { $0 + Int($1.value) } % 30)
            return (clock + phase).truncatingRemainder(dividingBy: 30) < 2 ? .heart : nil
        }
        return IconKind.for(pet.feeling)
    }
}
