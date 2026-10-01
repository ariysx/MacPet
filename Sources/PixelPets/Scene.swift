import Foundation

/// Something clickable in play mode, in grid pixels.
struct HitBox {
    enum Target: Equatable {
        case pet(UUID), egg(UUID), monster, loot(UUID)
    }

    var target: Target
    var minX: Float, minY: Float, maxX: Float, maxY: Float

    func contains(_ p: SIMD2<Float>, margin: Float = 0) -> Bool {
        p.x >= minX - margin && p.x <= maxX + margin && p.y >= minY - margin && p.y <= maxY + margin
    }
}

struct SceneFrame {
    var items: [SceneItem] = []
    /// Front to back, for hit testing.
    var hits: [HitBox] = []
}

/// Turns the World into the item list the shader draws, once per frame.
enum SceneBuilder {
    static func build(world: World, groundY: Float, time: Double, playMode: Bool,
                      atlas: SpriteAtlas, regions: PetSpriteRegions) -> SceneFrame {
        var entries: [(item: SceneItem, hit: HitBox?, priority: Int)] = []
        let clock = world.clock

        for grave in world.graves {
            var item = SceneItem()
            item.position = SIMD2(Float(grave.x), groundY)
            item.tile = atlas.tile(.grave)
            item.primary = PetPalette.rgba(0x9A9AA6)
            item.secondary = PetPalette.rgba(0x6E6E7A)
            entries.append((item, nil, 3))
        }

        for egg in world.eggs {
            var item = SceneItem()
            item.position = SIMD2(Float(egg.x), groundY)
            let wobbleSpeed = 0.3 + egg.progress * 2
            let wobbling = (time * wobbleSpeed).truncatingRemainder(dividingBy: 1) < 0.25
            item.tile = atlas.tile(.egg(egg.remaining < 60 ? 2 : wobbling ? 1 : 0))
            item.primary = PetPalette.rgba(0xF7EEDC)
            item.secondary = PetPalette.rgba(egg.genes.looks.primary)
            item.bars = SIMD4(Float(egg.progress), 0, 0, 0)
            item.flags = SceneItem.Flags.eggBar.rawValue
            if egg.mutated && Int(time * 2) % 2 == 0 {
                item.icon = Int32(atlas.tile(.icon(.sparkle)))
            }
            let hit = HitBox(target: .egg(egg.id), minX: Float(egg.x) - 5, minY: groundY,
                             maxX: Float(egg.x) + 5, maxY: groundY + 12)
            entries.append((item, hit, 3))
        }

        for loot in world.loot {
            var item = SceneItem()
            item.position = SIMD2(Float(loot.x), groundY)
            switch loot.kind {
            case .dailyChest:
                item.tile = atlas.tile(.chest)
                item.primary = PetPalette.rgba(0xA0673A)
                item.secondary = PetPalette.rgba(0xF7D358)
            case .bag:
                item.tile = atlas.tile(.bag)
                item.primary = PetPalette.rgba(0xC9A26B)
                item.secondary = PetPalette.rgba(0xE84A5F)
            }
            if (time + Double(loot.x)).truncatingRemainder(dividingBy: 3) < 1 {
                item.icon = Int32(atlas.tile(.icon(.sparkle)))
            }
            let hit = HitBox(target: .loot(loot.id), minX: Float(loot.x) - 6, minY: groundY,
                             maxX: Float(loot.x) + 6, maxY: groundY + 11)
            entries.append((item, hit, 2))
        }

        for pellet in world.pellets {
            var item = SceneItem()
            item.position = SIMD2(Float(pellet.x), groundY)
            item.tile = atlas.tile(.pellet)
            item.primary = PetPalette.rgba(0xC77B3A)
            item.secondary = PetPalette.rgba(0xF2C288)
            entries.append((item, nil, 1))
        }

        for pet in world.pets {
            let (petItem, weaponItem, hit) = petItems(pet, clock: clock, time: time, groundY: groundY,
                                                      playMode: playMode, atlas: atlas,
                                                      region: regions.region(for: pet.id))
            entries.append((petItem, hit, 4))
            if let weaponItem { entries.append((weaponItem, nil, 4)) }
        }

        if let m = world.monster {
            var item = SceneItem()
            let frame = Int(time * (m.kind == .bat ? 6 : 3)) % 2
            var y = groundY
            if m.kind == .bat { y += 5 + 10 * Float(0.5 + 0.5 * sin(m.age * 2)) }
            item.position = SIMD2(Float(m.x), y)
            switch m.kind {
            case .slime:
                item.tile = atlas.tile(.slime(frame))
                item.primary = PetPalette.rgba(0x6CCB5F)
                item.secondary = PetPalette.rgba(0xB8F0A8)
            case .bat:
                item.tile = atlas.tile(.bat(frame))
                item.primary = PetPalette.rgba(0x5A4A78)
                item.secondary = PetPalette.rgba(0xB08BD8)
            case .ogre:
                item.tile = atlas.tile(.ogre(frame))
                item.tileSpan = 2
                item.primary = PetPalette.rgba(0x8C9A5B)
                item.secondary = PetPalette.rgba(0xC9B28A)
            }
            var flags: SceneItem.Flags = []
            if m.facingLeft { flags.insert(.flipX) }
            if m.hurtFlash > 0 { flags.insert(.hurtFlash) }
            if m.phase == .attacking {
                flags.insert(.monsterBar)
                item.bars = SIMD4(Float(max(0, m.health / m.kind.maxHealth)), 0, 0, 0)
            }
            item.flags = flags.rawValue
            let height: Float = m.kind == .ogre ? 24 : 12
            let hit = HitBox(target: .monster, minX: Float(m.x - m.kind.halfWidth), minY: y,
                             maxX: Float(m.x + m.kind.halfWidth), maxY: y + height)
            entries.append((item, hit, 5))
        }

        if let puff = world.smoke {
            var item = SceneItem()
            item.position = SIMD2(Float(puff.x), groundY)
            item.tile = atlas.tile(.smoke(min(2, Int(puff.age / (SmokePuff.duration / 3)))))
            item.primary = PetPalette.rgba(0xE6E6E6)
            item.secondary = PetPalette.rgba(0xBDBDBD)
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
        let frame = Int(time * frameRate(anim)) % anim.frameCount

        var x = Float(pet.x)
        var y = groundY + Float(pet.height)
        if anim == .hop && frame == 0 { y += 3 }
        if pet.feeling == .scared && !pet.isAsleep { x += Int(time * 12) % 2 == 0 ? -1 : 1 }

        var item = SceneItem()
        item.position = SIMD2(x, y)
        item.tile = atlas.petTile(region: region, anim: anim, frame: frame, baby: baby)
        item.primary = PetPalette.rgba(pet.looks.primary)
        item.secondary = PetPalette.rgba(pet.looks.secondary)

        var flags: SceneItem.Flags = []
        if pet.facingLeft { flags.insert(.flipX) }
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
        if let weapon = pet.weapon, !pet.isAsleep {
            var w = SceneItem()
            let reach: Float = anim == .attack && frame == 0 ? 8 : 6
            w.position = SIMD2(x + (pet.facingLeft ? -reach : reach), y + (baby ? 1 : 3) - 0.01)
            w.tile = atlas.tile(.weapon(weapon))
            let colours = weaponColours(weapon)
            w.primary = PetPalette.rgba(colours.0)
            w.secondary = PetPalette.rgba(colours.1)
            w.flags = pet.facingLeft ? SceneItem.Flags.flipX.rawValue : 0
            weaponItem = w
        }

        let half: Float = baby ? 5 : 7
        let hit = HitBox(target: .pet(pet.id), minX: x - half, minY: y, maxX: x + half, maxY: y + (baby ? 10 : 13))
        return (item, weaponItem, hit)
    }

    static func animation(for pet: Pet, clock: Double) -> PetAnim {
        if pet.held { return .held }
        if pet.hurtFlash > 0 { return .hurt }
        if pet.isAsleep { return .sleep }
        if pet.isEating { return .eat }
        if pet.fight == .fighting && clock - pet.lastAttackAt < 0.4 { return .attack }
        if pet.feeling == .sick { return .sick }
        if pet.feeling == .excited { return .hop }
        if pet.isWalking { return .walk }
        return .idle
    }

    private static func frameRate(_ anim: PetAnim) -> Double {
        switch anim {
        case .idle: return 1.5
        case .walk, .eat: return 4
        case .hop: return 3
        case .sick: return 2
        case .attack: return 6
        default: return 1
        }
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

    private static func weaponColours(_ item: Item) -> (UInt32, UInt32) {
        switch item {
        case .stick, .slingshot: return (0x8A5A2B, 0x5E3B1A)
        case .woodenSword: return (0xC08A4E, 0x7A4E24)
        case .ironSword: return (0xDDE3EA, 0xF7D358)
        case .magicWand: return (0x9A5BC4, 0xF7D358)
        default: return (0xF4F1E8, 0xE84A5F)
        }
    }
}
