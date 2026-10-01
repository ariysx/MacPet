import Foundation

enum IconKind: Int, CaseIterable {
    case heart, drumstick, cloud, zz, face, sparkle, exclamation

    static func `for`(_ feeling: Feeling) -> IconKind? {
        switch feeling {
        case .scared: return .exclamation
        case .sick: return .face
        case .sleepy: return .zz
        case .hungry: return .drumstick
        case .sad: return .cloud
        case .excited: return .sparkle
        case .content: return .heart
        }
    }
}

enum StaticSprite: Hashable {
    case monster(MonsterKind, attack: Bool, Int)
    case egg(Int)
    case grave
    case pellet
    case chest
    case bag
    case weapon(Item)
    case smoke(Int)
    case icon(IconKind)
}

/// One r8Uint atlas of 32 x 32 tiles, 16 across. Fixed sprites (monsters, props, icons) are
/// rendered once at launch; the rest is one region per pet slot, filled when a pet hatches.
struct SpriteAtlas {
    static let columns = 16
    static let tileSize = 64
    static let regionCount = World.maxSlots
    static let tilesPerRegion = PetComposer.framesPerSet * 2

    let width = columns * tileSize
    let height: Int
    private(set) var pixels: [UInt8]
    private(set) var tiles: [StaticSprite: UInt32] = [:]
    /// Tile indices of each pet region, in `PetComposer.frames` order.
    private(set) var regionTiles: [[UInt32]] = []

    static func build() -> SpriteAtlas {
        var big: [(StaticSprite, PixelSprite)] = []
        var small: [(StaticSprite, PixelSprite)] = []
        for kind in MonsterKind.allCases {
            for attack in [false, true] {
                for i in 0..<(attack ? kind.attackFrames : kind.moveFrames) {
                    let entry = (StaticSprite.monster(kind, attack: attack, i), MonsterArt.frame(kind, attack: attack, frame: i))
                    if kind.canvas > tileSize { big.append(entry) } else { small.append(entry) }
                }
            }
        }
        for i in 0..<PropArt.eggFrames { small.append((.egg(i), PropArt.egg(i))) }
        small.append((.grave, PropArt.grave()))
        small.append((.pellet, PropArt.pellet()))
        small.append((.chest, PropArt.chest()))
        small.append((.bag, PropArt.bag()))
        for item in Item.allCases where item.category == .weapon { small.append((.weapon(item), PropArt.weapon(item))) }
        for i in 0..<PropArt.smokeFrames { small.append((.smoke(i), PropArt.smoke(i))) }
        for kind in IconKind.allCases { small.append((.icon(kind), shadowed(PropArt.icon(kind)))) }

        // 2x2 blocks first, packed along pairs of rows; then single tiles in the gaps.
        var occupied = Set<Int>()
        var bigTiles: [Int] = []
        var row = 0, col = 0
        for _ in big {
            if col + 2 > columns { col = 0; row += 2 }
            let t = row * columns + col
            bigTiles.append(t)
            occupied.formUnion([t, t + 1, t + columns, t + columns + 1])
            col += 2
        }
        var singles: [Int] = []
        var next = 0
        while singles.count < small.count + regionCount * tilesPerRegion {
            if !occupied.contains(next) { singles.append(next) }
            next += 1
        }
        let used = max(next, (occupied.max() ?? 0) + 1)
        let rows = (used + columns - 1) / columns

        var atlas = SpriteAtlas(height: rows * tileSize, pixels: Array(repeating: 0, count: columns * tileSize * rows * tileSize))
        for (i, (key, sprite)) in big.enumerated() {
            atlas.blit(sprite, tile: UInt32(bigTiles[i]))
            atlas.tiles[key] = UInt32(bigTiles[i])
        }
        var cursor = 0
        for (key, sprite) in small {
            atlas.blit(sprite, tile: UInt32(singles[cursor]))
            atlas.tiles[key] = UInt32(singles[cursor])
            cursor += 1
        }
        for _ in 0..<regionCount {
            atlas.regionTiles.append(singles[cursor..<(cursor + tilesPerRegion)].map(UInt32.init))
            cursor += tilesPerRegion
        }
        return atlas
    }

    private init(height: Int, pixels: [UInt8]) {
        self.height = height
        self.pixels = pixels
    }

    func tile(_ key: StaticSprite) -> UInt32 { tiles[key] ?? 0 }

    func petTile(region: Int, view: PetView, anim: PetAnim, frame: Int, baby: Bool) -> UInt32 {
        regionTiles[region % regionTiles.count][PetComposer.frameIndex(view: view, anim: anim, frame: frame, baby: baby)]
    }

    /// Composes a pet's frames and writes them into `region`.
    mutating func writePet(region: Int, looks: Looks) {
        write(PetComposer.frames(for: looks), region: region)
    }

    mutating func write(_ frames: [PixelSprite], region: Int) {
        for (i, sprite) in frames.enumerated() where i < regionTiles[region].count {
            blit(sprite, tile: regionTiles[region][i])
        }
    }

    private mutating func blit(_ sprite: PixelSprite, tile: UInt32) {
        let ox = Int(tile) % Self.columns * Self.tileSize
        let oy = Int(tile) / Self.columns * Self.tileSize
        for y in 0..<sprite.height {
            for x in 0..<sprite.width {
                pixels[(oy + y) * width + ox + x] = sprite[x, y]
            }
        }
    }

    /// Icons get a one-pixel drop shadow so they read on any background.
    private static func shadowed(_ s: PixelSprite) -> PixelSprite {
        var out = PixelSprite(width: tileSize, height: tileSize)
        let shadow = Ink.make(.dark, .outline)
        for y in 0..<s.height {
            for x in 0..<s.width where s[x, y] != Ink.clear && s[x + 1, y + 1] == Ink.clear {
                out[x + 1, y + 1] = shadow
            }
        }
        out.draw(s, x: 0, y: 0)
        return out
    }
}

/// Which atlas region each living pet's frames live in.
struct PetSpriteRegions {
    private(set) var assigned: [UUID: Int] = [:]
    /// Regions handed out whose frames are still being composed.
    private var pending: Set<UUID> = []

    func isAssigned(_ id: UUID) -> Bool { assigned[id] != nil }
    func isReserved(_ id: UUID, region: Int) -> Bool { assigned[id] == region }

    /// Frees the regions of pets that are gone.
    mutating func releaseGone(_ pets: [Pet]) {
        let living = Set(pets.map(\.id))
        assigned = assigned.filter { living.contains($0.key) }
        pending = pending.filter { living.contains($0) }
    }

    /// Hands a free region to a pet whose frames are about to be composed.
    mutating func reserve(_ id: UUID) -> Int? {
        let used = Set(assigned.values)
        guard let region = (0..<SpriteAtlas.regionCount).first(where: { !used.contains($0) }) else { return nil }
        assigned[id] = region
        pending.insert(id)
        return region
    }

    mutating func markReady(_ id: UUID) { pending.remove(id) }

    /// The pet's region once its frames are in the atlas.
    func readyRegion(for id: UUID) -> Int? {
        pending.contains(id) ? nil : assigned[id]
    }

    /// Gives new pets a region (composing their sprites) and frees the regions of pets that
    /// are gone. Returns true when the atlas pixels changed.
    mutating func sync(pets: [Pet], atlas: inout SpriteAtlas) -> Bool {
        let living = Set(pets.map(\.id))
        assigned = assigned.filter { living.contains($0.key) }
        var changed = false
        for pet in pets where assigned[pet.id] == nil {
            let used = Set(assigned.values)
            let region = (0..<SpriteAtlas.regionCount).first { !used.contains($0) } ?? 0
            atlas.writePet(region: region, looks: pet.looks)
            assigned[pet.id] = region
            changed = true
        }
        return changed
    }

    func region(for id: UUID) -> Int { assigned[id] ?? 0 }
}
