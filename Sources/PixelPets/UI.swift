import Foundation

// The play-mode interface: a bag bar with drag and drop, chest reveals, pet cards, name tags,
// tooltips and toasts. It is drawn on the CPU into a half-resolution ink canvas that the shader
// lays over the scene, so it shares the sprites' palette and stays pixel-crisp.

// MARK: - Pixel font

enum PixelFont {
    static let height = 7
    static let advance = 6

    static func width(_ text: String) -> Int { max(0, text.count * advance - 1) }

    static func glyph(_ c: Character) -> [String]? {
        if c == " " { return nil }
        return glyphs[Character(c.uppercased())] ?? glyphs["?"]
    }

    private static let glyphs: [Character: [String]] = [
        "A": [".###.", "#...#", "#...#", "#####", "#...#", "#...#", "#...#"],
        "B": ["####.", "#...#", "#...#", "####.", "#...#", "#...#", "####."],
        "C": [".###.", "#...#", "#....", "#....", "#....", "#...#", ".###."],
        "D": ["####.", "#...#", "#...#", "#...#", "#...#", "#...#", "####."],
        "E": ["#####", "#....", "#....", "####.", "#....", "#....", "#####"],
        "F": ["#####", "#....", "#....", "####.", "#....", "#....", "#...."],
        "G": [".###.", "#...#", "#....", "#.###", "#...#", "#...#", ".###."],
        "H": ["#...#", "#...#", "#...#", "#####", "#...#", "#...#", "#...#"],
        "I": [".###.", "..#..", "..#..", "..#..", "..#..", "..#..", ".###."],
        "J": ["..###", "...#.", "...#.", "...#.", "#..#.", "#..#.", ".##.."],
        "K": ["#...#", "#..#.", "#.#..", "##...", "#.#..", "#..#.", "#...#"],
        "L": ["#....", "#....", "#....", "#....", "#....", "#....", "#####"],
        "M": ["#...#", "##.##", "#.#.#", "#.#.#", "#...#", "#...#", "#...#"],
        "N": ["#...#", "##..#", "#.#.#", "#..##", "#...#", "#...#", "#...#"],
        "O": [".###.", "#...#", "#...#", "#...#", "#...#", "#...#", ".###."],
        "P": ["####.", "#...#", "#...#", "####.", "#....", "#....", "#...."],
        "Q": [".###.", "#...#", "#...#", "#...#", "#.#.#", "#..#.", ".##.#"],
        "R": ["####.", "#...#", "#...#", "####.", "#.#..", "#..#.", "#...#"],
        "S": [".####", "#....", "#....", ".###.", "....#", "....#", "####."],
        "T": ["#####", "..#..", "..#..", "..#..", "..#..", "..#..", "..#.."],
        "U": ["#...#", "#...#", "#...#", "#...#", "#...#", "#...#", ".###."],
        "V": ["#...#", "#...#", "#...#", "#...#", "#...#", ".#.#.", "..#.."],
        "W": ["#...#", "#...#", "#...#", "#.#.#", "#.#.#", "#.#.#", ".#.#."],
        "X": ["#...#", "#...#", ".#.#.", "..#..", ".#.#.", "#...#", "#...#"],
        "Y": ["#...#", "#...#", ".#.#.", "..#..", "..#..", "..#..", "..#.."],
        "Z": ["#####", "....#", "...#.", "..#..", ".#...", "#....", "#####"],
        "0": [".###.", "#...#", "#..##", "#.#.#", "##..#", "#...#", ".###."],
        "1": ["..#..", ".##..", "..#..", "..#..", "..#..", "..#..", ".###."],
        "2": [".###.", "#...#", "....#", "...#.", "..#..", ".#...", "#####"],
        "3": ["####.", "....#", "....#", ".###.", "....#", "....#", "####."],
        "4": ["...#.", "..##.", ".#.#.", "#..#.", "#####", "...#.", "...#."],
        "5": ["#####", "#....", "####.", "....#", "....#", "#...#", ".###."],
        "6": ["..##.", ".#...", "#....", "####.", "#...#", "#...#", ".###."],
        "7": ["#####", "....#", "...#.", "..#..", ".#...", ".#...", ".#..."],
        "8": [".###.", "#...#", "#...#", ".###.", "#...#", "#...#", ".###."],
        "9": [".###.", "#...#", "#...#", ".####", "....#", "...#.", ".##.."],
        ".": [".....", ".....", ".....", ".....", ".....", ".##..", ".##.."],
        ",": [".....", ".....", ".....", ".....", ".##..", "..#..", ".#..."],
        "!": ["..#..", "..#..", "..#..", "..#..", "..#..", ".....", "..#.."],
        "?": [".###.", "#...#", "....#", "...#.", "..#..", ".....", "..#.."],
        ":": [".....", "..#..", "..#..", ".....", "..#..", "..#..", "....."],
        "+": [".....", "..#..", "..#..", "#####", "..#..", "..#..", "....."],
        "-": [".....", ".....", ".....", "#####", ".....", ".....", "....."],
        "/": ["....#", "...#.", "...#.", "..#..", ".#...", ".#...", "#...."],
        "%": ["##..#", "##.#.", "...#.", "..#..", ".#...", ".#.##", "#..##"],
        "'": ["..#..", "..#..", ".....", ".....", ".....", ".....", "....."],
        "(": ["...#.", "..#..", ".#...", ".#...", ".#...", "..#..", "...#."],
        ")": [".#...", "..#..", "...#.", "...#.", "...#.", "..#..", ".#..."],
        "<": ["...#.", "..#..", ".#...", "#....", ".#...", "..#..", "...#."],
        ">": [".#...", "..#..", "...#.", "....#", "...#.", "..#..", ".#..."],
        "*": [".....", "..#..", "#####", ".###.", ".#.#.", "#...#", "....."],
        "★": [".....", "..#..", "#####", ".###.", ".#.#.", "#...#", "....."],
        "x": [".....", ".....", "#...#", ".#.#.", "..#..", ".#.#.", "#...#"],
        "×": [".....", ".....", "#...#", ".#.#.", "..#..", ".#.#.", "#...#"],
    ]
}

// MARK: - Canvas

struct UIRect {
    var x: Int, y: Int, w: Int, h: Int

    func contains(_ p: SIMD2<Int>) -> Bool { p.x >= x && p.y >= y && p.x < x + w && p.y < y + h }
}

/// A grid of ink values, row 0 at the top. 255 means "darken what is behind".
struct UICanvas {
    static let dim: UInt8 = 255
    let width: Int
    let height: Int
    private(set) var pixels: [UInt8]

    init(width: Int, height: Int) {
        self.width = max(1, width)
        self.height = max(1, height)
        pixels = Array(repeating: 0, count: self.width * self.height)
    }

    mutating func clear() {
        for i in pixels.indices { pixels[i] = 0 }
    }

    mutating func put(_ x: Int, _ y: Int, _ ink: UInt8) {
        guard x >= 0, y >= 0, x < width, y < height else { return }
        pixels[y * width + x] = ink
    }

    mutating func fill(_ r: UIRect, _ ink: UInt8) {
        // Clip to the canvas; a rect partly or wholly off-screen must not form a backwards range.
        let x0 = max(0, r.x), x1 = min(width, r.x + r.w)
        let y0 = max(0, r.y), y1 = min(height, r.y + r.h)
        guard x0 < x1, y0 < y1 else { return }
        for y in y0..<y1 {
            for x in x0..<x1 { pixels[y * width + x] = ink }
        }
    }

    /// A dark translucent panel with a crisp border and a lit top edge.
    mutating func panel(_ r: UIRect, border: Ramp = .dark) {
        guard r.w > 2, r.h > 2 else { return }
        fill(r, UICanvas.dim)
        let edge = Ink.make(border, border == .dark ? .outline : .base)
        for x in r.x..<(r.x + r.w) { put(x, r.y, edge); put(x, r.y + r.h - 1, edge) }
        for y in r.y..<(r.y + r.h) { put(r.x, y, edge); put(r.x + r.w - 1, y, edge) }
        let lit = Ink.make(border == .dark ? .stone : border, .light)
        for x in (r.x + 1)..<(r.x + r.w - 1) { put(x, r.y + 1, lit) }
    }

    mutating func text(_ s: String, _ x: Int, _ y: Int, _ ink: UInt8, shadow: Bool = true) {
        var cx = x
        for c in s {
            if let rows = PixelFont.glyph(c) {
                for (gy, row) in rows.enumerated() {
                    for (gx, ch) in row.enumerated() where ch == "#" {
                        if shadow { put(cx + gx + 1, y + gy + 1, Ink.make(.dark, .outline)) }
                        put(cx + gx, y + gy, ink)
                    }
                }
            }
            cx += PixelFont.advance
        }
    }

    mutating func sprite(_ s: PixelSprite, _ x: Int, _ y: Int) {
        for sy in 0..<s.height {
            for sx in 0..<s.width where s[sx, sy] != Ink.clear { put(x + sx, y + sy, s[sx, sy]) }
        }
    }
}

// MARK: - Play UI

final class PlayUI {
    struct Toast {
        var text: String
        var ink: UInt8
        var x: Int
        var y: Int
        var born: Double
    }

    struct Reveal {
        var title: String
        var items: [Item]
        var born: Double
        var x: Int
    }

    /// Grid pixels per UI pixel.
    static let scale: Float = 1.5
    private(set) var canvas = UICanvas(width: 640, height: 400)
    /// Pointer in canvas coordinates, and the same point on the scene grid.
    var pointer: SIMD2<Int>?
    var gridPointer: SIMD2<Float>?
    var pinnedPet: UUID?
    private(set) var dragging: Item?
    private var pressed: (item: Item, at: SIMD2<Int>)?
    private var page = 0
    private var reveal: Reveal?
    private var toasts: [Toast] = []
    private var slots: [(item: Item, rect: UIRect)] = []
    private var bar = UIRect(x: 0, y: 0, w: 0, h: 0)
    private var prevPage: UIRect?
    private var nextPage: UIRect?
    private var card: UIRect?
    private var cardClose: UIRect?
    private var cardSlots: [(category: ItemCategory, rect: UIRect)] = []
    private var revealRect: UIRect?
    private var now = 0.0
    private let icons: [Item: PixelSprite] = Dictionary(uniqueKeysWithValues: Item.allCases.map { ($0, ItemArt.icon($0)) })

    static let white = Ink.make(.white, .light)
    static let grey = Ink.make(.stone, .light)
    static func ink(_ rarity: Rarity) -> UInt8 { Ink.make(ItemArt.ramp(for: rarity), .light) }

    /// Canvas size for a scene grid, `scale` grid pixels per UI pixel.
    func resize(gridWidth: Int, gridHeight: Int) {
        let w = Int(Float(gridWidth) / PlayUI.scale), h = Int(Float(gridHeight) / PlayUI.scale)
        if canvas.width != w || canvas.height != h { canvas = UICanvas(width: w, height: h) }
    }

    func toCanvas(_ grid: SIMD2<Float>) -> SIMD2<Int> {
        // Clamp first: converting a huge or non-finite Float to Int traps.
        let x = grid.x.isFinite ? min(max(grid.x / PlayUI.scale, -10_000), 10_000) : 0
        let y = grid.y.isFinite ? min(max(grid.y / PlayUI.scale, -10_000), 10_000) : 0
        return SIMD2(Int(x), canvas.height - 1 - Int(y))
    }

    // MARK: Events

    func toast(_ text: String, ink: UInt8 = PlayUI.white, atGrid p: SIMD2<Float>? = nil) {
        let at = p.map(toCanvas) ?? SIMD2(canvas.width / 2, canvas.height - 50)
        toasts.append(Toast(text: text.uppercased(), ink: ink, x: at.x, y: at.y, born: now))
        if toasts.count > 6 { toasts.removeFirst() }
    }

    func showReveal(title: String, items: [Item], atGridX x: Float) {
        reveal = Reveal(title: title, items: items, born: now, x: Int(x / PlayUI.scale))
    }

    // MARK: Drawing

    /// Redraws the canvas. Returns the colours a pinned pet's portrait needs, if one is shown.
    func render(world: World, hits: [HitBox], atlas: SpriteAtlas, regions: PetSpriteRegions, time: Double,
                groundY: Float) -> (primary: UInt32, secondary: UInt32)? {
        now = time
        canvas.clear()
        let w = canvas.width, h = canvas.height

        // Controls hint.
        let hint = dragging == nil ? "DRAG ITEMS ONTO PETS   F+CLICK: FEED   RIGHT-CLICK: PET INFO   ESC: EXIT"
                                   : "DROP ON A PET" + (dragging!.targetsEgg ? " EGG" : "")
        let hw = PixelFont.width(hint) + 10
        canvas.panel(UIRect(x: (w - hw) / 2, y: 4, w: hw, h: 13))
        canvas.text(hint, (w - hw) / 2 + 5, 7, PlayUI.grey)

        // Name tag over the pet under the pointer, or a drop highlight while dragging.
        if let gp = gridPointer, let hit = hits.first(where: { $0.contains(gp) }) {
            let top = toCanvas(SIMD2(hit.minX, hit.maxY))
            let right = toCanvas(SIMD2(hit.maxX, hit.minY))
            if dragging != nil {
                let r = UIRect(x: top.x - 2, y: top.y - 2, w: max(1, right.x - top.x + 4), h: max(1, right.y - top.y + 4))
                for x in r.x..<(r.x + r.w) where x % 2 == 0 { canvas.put(x, r.y, PlayUI.white); canvas.put(x, r.y + r.h - 1, PlayUI.white) }
                for y in r.y..<(r.y + r.h) where y % 2 == 0 { canvas.put(r.x, y, PlayUI.white); canvas.put(r.x + r.w - 1, y, PlayUI.white) }
            } else if case .pet(let id) = hit.target, let pet = world.pets.first(where: { $0.id == id }), pinnedPet != id {
                let label = "\(pet.name)  " + String(repeating: "★", count: pet.looks.rarity.rawValue + 1)
                let lw = PixelFont.width(label) + 8
                let left = min(max(2, (top.x + right.x) / 2 - lw / 2), canvas.width - lw - 2)
                let tagY = min(max(20, top.y - 26), canvas.height - 50)
                canvas.panel(UIRect(x: left, y: tagY, w: lw, h: 13))
                canvas.text(pet.name.uppercased(), left + 4, tagY + 3, PlayUI.white)
                let starX = left + 4 + PixelFont.width(pet.name + "  ") + 1
                canvas.text(String(repeating: "★", count: pet.looks.rarity.rawValue + 1), starX, tagY + 3,
                            PlayUI.ink(pet.looks.rarity))
            }
        }

        drawBag(world: world)
        let colours = drawCard(world: world, atlas: atlas, regions: regions)
        drawReveal()
        drawToasts()

        // The item being dragged follows the pointer.
        if let item = dragging, let p = pointer, let icon = icons[item] {
            canvas.sprite(icon, p.x - 8, p.y - 8)
        }
        _ = h
        return colours
    }

    private func drawBag(world: World) {
        let w = canvas.width, h = canvas.height
        let items = world.inventory.keys.sorted { $0.rarity != $1.rarity ? $0.rarity > $1.rarity : $0.title < $1.title }
        let perPage = max(1, (w - 70) / 22)
        let pages = max(1, (items.count + perPage - 1) / perPage)
        page = min(page, pages - 1)
        let shown = Array(items.dropFirst(page * perPage).prefix(perPage))
        let barW = max(150, shown.count * 22 + 50)
        bar = UIRect(x: (w - barW) / 2, y: h - 31, w: barW, h: 28)
        canvas.panel(bar)
        canvas.text("BAG", bar.x + 6, bar.y + 4, PlayUI.grey)
        canvas.text("\(world.inventory.values.reduce(0, +))", bar.x + 6, bar.y + 15, PlayUI.white)
        slots = []
        if shown.isEmpty {
            canvas.text("EMPTY: WIN FIGHTS, OPEN CHESTS", bar.x + 30, bar.y + 10, PlayUI.grey)
        }
        for (i, item) in shown.enumerated() {
            let r = UIRect(x: bar.x + 30 + i * 22, y: bar.y + 3, w: 21, h: 21)
            slots.append((item, r))
            let hover = pointer.map(r.contains) ?? false
            canvas.fill(r, hover ? Ink.make(.stone, .shade) : Ink.make(.dark, .base))
            let edge = Ink.make(ItemArt.ramp(for: item.rarity), hover ? .light : .base)
            for x in r.x..<(r.x + r.w) { canvas.put(x, r.y, edge); canvas.put(x, r.y + r.h - 1, edge) }
            for y in r.y..<(r.y + r.h) { canvas.put(r.x, y, edge); canvas.put(r.x + r.w - 1, y, edge) }
            if let icon = icons[item] { canvas.sprite(icon, r.x + 2, r.y + 2) }
            let n = world.count(of: item) - (dragging == item ? 1 : 0)
            if n > 1 { canvas.text("\(n)", r.x + r.w - PixelFont.width("\(n)") - 1, r.y + r.h - 8, PlayUI.white) }
        }
        prevPage = nil
        nextPage = nil
        if pages > 1 {
            let prev = UIRect(x: bar.x + bar.w - 18, y: bar.y + 3, w: 8, h: 10)
            let next = UIRect(x: bar.x + bar.w - 18, y: bar.y + 14, w: 8, h: 10)
            canvas.text("<", prev.x + 1, prev.y + 1, page > 0 ? PlayUI.white : PlayUI.grey)
            canvas.text(">", next.x + 1, next.y + 1, page < pages - 1 ? PlayUI.white : PlayUI.grey)
            prevPage = prev
            nextPage = next
        }

        // Tooltip for the hovered slot.
        if dragging == nil, let p = pointer, let slot = slots.first(where: { $0.rect.contains(p) }) {
            let item = slot.item
            let lines: [(String, UInt8)] = [
                (item.title.uppercased(), PlayUI.ink(item.rarity)),
                (String(repeating: "★", count: item.rarity.rawValue + 1) + " " + item.rarity.title.uppercased(), PlayUI.ink(item.rarity)),
                (item.blurb.uppercased(), PlayUI.white),
                (item.targetsEgg ? "DRAG ONTO AN EGG" : item.category == .potion ? "DRAG ONTO A PET TO USE" : "DRAG ONTO A PET TO EQUIP",
                 PlayUI.grey),
            ]
            let tw = (lines.map { PixelFont.width($0.0) }.max() ?? 0) + 12
            let th = lines.count * 10 + 6
            let tx = min(max(2, slot.rect.x + 10 - tw / 2), w - tw - 2)
            let ty = bar.y - th - 3
            canvas.panel(UIRect(x: tx, y: ty, w: tw, h: th), border: ItemArt.ramp(for: item.rarity))
            for (i, line) in lines.enumerated() { canvas.text(line.0, tx + 6, ty + 5 + i * 10, line.1) }
        }
    }

    private func drawCard(world: World, atlas: SpriteAtlas, regions: PetSpriteRegions) -> (UInt32, UInt32)? {
        card = nil
        cardClose = nil
        cardSlots = []
        guard let id = pinnedPet, let pet = world.pets.first(where: { $0.id == id }) else {
            pinnedPet = nil
            return nil
        }
        let r = UIRect(x: 6, y: 22, w: 178, h: 142)
        card = r
        canvas.panel(r, border: ItemArt.ramp(for: pet.looks.rarity))
        // Portrait: the front idle frame at half size.
        let tile = atlas.petTile(region: regions.region(for: pet.id), view: .front, anim: .idle,
                                 frame: Int(now * 3) % 4, baby: pet.stage == .baby)
        canvas.fill(UIRect(x: r.x + 5, y: r.y + 6, w: 36, h: 36), Ink.make(.dark, .base))
        canvas.sprite(atlas.tileSprite(tile).halved(), r.x + 7, r.y + 8)
        let tx = r.x + 46
        canvas.text(pet.name.uppercased(), tx, r.y + 6, PlayUI.white)
        canvas.text(String(repeating: "★", count: pet.looks.rarity.rawValue + 1) + " " + pet.looks.rarity.title.uppercased(),
                    tx, r.y + 16, PlayUI.ink(pet.looks.rarity))
        canvas.text("GEN \(pet.generation)  \(pet.stage.rawValue.uppercased())", tx, r.y + 26, PlayUI.grey)
        canvas.text(pet.looks.shape.rawValue.uppercased() + " " + pet.feeling.title.uppercased(), tx, r.y + 36, PlayUI.grey)
        let close = UIRect(x: r.x + r.w - 11, y: r.y + 4, w: 8, h: 9)
        canvas.text("×", close.x + 1, close.y + 1, PlayUI.white)
        cardClose = close

        // Traits
        let t = pet.traits.names.map { $0.uppercased() }
        canvas.text(t[0] + " " + t[1] + " " + t[2], r.x + 6, r.y + 48, PlayUI.white)
        canvas.text(t[3] + " " + t[4], r.x + 6, r.y + 58, PlayUI.white)

        // Needs
        let needs: [(String, Double, Ramp)] = [("HEALTH", pet.health, .red), ("FOOD", pet.hunger, .gold),
                                               ("JOY", pet.happiness, .pink), ("ENERGY", pet.energy, .blue)]
        for (i, need) in needs.enumerated() {
            let y = r.y + 70 + i * 10
            canvas.text(need.0, r.x + 6, y, PlayUI.grey)
            let bx = r.x + 52, bw = 80
            canvas.fill(UIRect(x: bx, y: y + 1, w: bw + 2, h: 6), Ink.make(.dark, .outline))
            canvas.fill(UIRect(x: bx + 1, y: y + 2, w: Int(Double(bw) * need.1 / 100), h: 4), Ink.make(need.2, .base))
            canvas.fill(UIRect(x: bx + 1, y: y + 2, w: Int(Double(bw) * need.1 / 100), h: 1), Ink.make(need.2, .light))
            canvas.text("\(Int(need.1.rounded()))", bx + bw + 6, y, PlayUI.white)
        }

        // Equipment: click a slot to put the item back in the bag.
        for (i, (category, equipped)) in [(ItemCategory.weapon, pet.weapon), (.relic, pet.relic)].enumerated() {
            let sr = UIRect(x: r.x + 6 + i * 86, y: r.y + 112, w: 21, h: 21)
            cardSlots.append((category, sr))
            canvas.fill(sr, Ink.make(.dark, .base))
            let edge = Ink.make(equipped.map { ItemArt.ramp(for: $0.rarity) } ?? .stone, .base)
            for x in sr.x..<(sr.x + sr.w) { canvas.put(x, sr.y, edge); canvas.put(x, sr.y + sr.h - 1, edge) }
            for y in sr.y..<(sr.y + sr.h) { canvas.put(sr.x, y, edge); canvas.put(sr.x + sr.w - 1, y, edge) }
            if let equipped, let icon = icons[equipped] { canvas.sprite(icon, sr.x + 2, sr.y + 2) }
            canvas.text(category == .weapon ? "WEAPON" : "RELIC", sr.x + 25, sr.y + 2, PlayUI.grey)
            canvas.text(equipped == nil ? "EMPTY" : "CLICK: OFF", sr.x + 25, sr.y + 12, equipped == nil ? Ink.make(.stone, .base) : PlayUI.white)
        }
        if let buff = pet.buffs.first {
            canvas.text("\(buff.kind.rawValue.uppercased()) \(Int(ceil(buff.remaining / 60)))M", r.x + 110, r.y + 6 + 30, PlayUI.ink(.rare))
        }
        return (pet.looks.primary, pet.looks.secondary)
    }

    private func drawReveal() {
        revealRect = nil
        guard let rv = reveal else { return }
        let age = now - rv.born
        let perItem = 0.35
        let total = Double(rv.items.count) * perItem + 2.5
        if age > total {
            reveal = nil
            toast("+\(rv.items.count) ITEMS TO BAG", ink: PlayUI.ink(.uncommon))
            return
        }
        let shown = min(rv.items.count, Int(age / perItem) + 1)
        let longest = rv.items.map { PixelFont.width($0.title.uppercased() + " (" + $0.rarity.title.uppercased() + ")") }.max() ?? 0
        let rw = max(PixelFont.width(rv.title) + 20, rv.items.count * 26 + 16, longest + 16)
        let r = UIRect(x: min(max(2, rv.x - rw / 2), canvas.width - rw - 2), y: canvas.height / 2 - 70, w: rw, h: 62)
        revealRect = r
        canvas.panel(r, border: .gold)
        canvas.text(rv.title, r.x + (rw - PixelFont.width(rv.title)) / 2, r.y + 6, Ink.make(.gold, .light))
        for i in 0..<shown {
            let item = rv.items[i]
            let pop = min(1, (age - Double(i) * perItem) / 0.15)
            let sx = r.x + 8 + i * 26 + (rw - 16 - rv.items.count * 26) / 2
            let sy = r.y + 18 + Int((1 - pop) * 6)
            let sr = UIRect(x: sx, y: sy, w: 22, h: 22)
            canvas.fill(sr, Ink.make(.dark, .base))
            let edge = Ink.make(ItemArt.ramp(for: item.rarity), .light)
            for x in sr.x..<(sr.x + sr.w) { canvas.put(x, sr.y, edge); canvas.put(x, sr.y + sr.h - 1, edge) }
            for y in sr.y..<(sr.y + sr.h) { canvas.put(sr.x, y, edge); canvas.put(sr.x + sr.w - 1, y, edge) }
            if item.rarity >= .rare && Int(now * 6) % 2 == 0 {
                canvas.put(sr.x - 1, sr.y - 1, Ink.make(.gold, .light))
                canvas.put(sr.x + sr.w, sr.y + sr.h, Ink.make(.gold, .light))
            }
            if let icon = icons[item] { canvas.sprite(icon, sx + 3, sy + 3) }
        }
        // The newest item's name.
        let newest = rv.items[shown - 1]
        let name = newest.title.uppercased() + " (" + newest.rarity.title.uppercased() + ")"
        canvas.text(name, r.x + (rw - PixelFont.width(name)) / 2, r.y + 47, PlayUI.ink(newest.rarity))
    }

    private func drawToasts() {
        toasts.removeAll { now - $0.born > 2.4 }
        for t in toasts {
            let rise = Int((now - t.born) * 10)
            let tw = PixelFont.width(t.text)
            let x = min(max(2, t.x - tw / 2), canvas.width - tw - 2)
            canvas.text(t.text, x, t.y - 30 - rise, t.ink)
        }
    }

    // MARK: Input

    /// Returns true when the UI used the click.
    func mouseDown(at p: SIMD2<Int>, world: inout World) -> Bool {
        pointer = p
        if let close = cardClose, close.contains(p) {
            pinnedPet = nil
            return true
        }
        if let id = pinnedPet, let slot = cardSlots.first(where: { $0.rect.contains(p) }) {
            if let i = world.pets.firstIndex(where: { $0.id == id }) {
                let item = slot.category == .weapon ? world.pets[i].weapon : world.pets[i].relic
                if let item {
                    world.unequip(slot.category, fromPet: id)
                    toast("\(item.title) back in bag", ink: PlayUI.grey, atGrid: nil)
                }
            }
            return true
        }
        if let card, card.contains(p) { return true }
        if let r = revealRect, r.contains(p) {
            reveal?.born -= 100 // skip to the end
            return true
        }
        if let prev = prevPage, prev.contains(p) { page = max(0, page - 1); return true }
        if let next = nextPage, next.contains(p) { page += 1; return true }
        if let slot = slots.first(where: { $0.rect.contains(p) }) {
            pressed = (slot.item, p)
            return true
        }
        return bar.contains(p)
    }

    /// Returns true while the UI owns the drag.
    func mouseDragged(at p: SIMD2<Int>) -> Bool {
        pointer = p
        guard let press = pressed else { return dragging != nil }
        if dragging == nil, abs(p.x - press.at.x) + abs(p.y - press.at.y) > 2 { dragging = press.item }
        return true
    }

    /// Finishes a drag: drops the item on whatever pet or egg is under the pointer.
    func mouseUp(at p: SIMD2<Int>, grid: SIMD2<Float>, hits: [HitBox], world: inout World) -> Bool {
        pointer = p
        defer { pressed = nil; dragging = nil }
        guard let item = dragging else {
            if let press = pressed {
                toast(press.item.targetsEgg ? "drag it onto an egg" : "drag it onto a pet", ink: PlayUI.grey, atGrid: nil)
                return true
            }
            return false
        }
        guard let hit = hits.first(where: { $0.contains(grid) }) else { return true }
        let at = SIMD2(grid.x, hit.maxY)
        switch hit.target {
        case .pet(let id):
            let name = world.pets.first { $0.id == id }?.name ?? ""
            if item.targetsEgg {
                toast("only for eggs", ink: PlayUI.grey, atGrid: at)
            } else if item.category == .potion {
                if world.use(item, onPet: id) { toast("\(name): \(item.blurb)", ink: PlayUI.ink(.uncommon), atGrid: at) }
            } else if world.equip(item, onPet: id) {
                toast("\(name) equipped \(item.title)", ink: PlayUI.ink(item.rarity), atGrid: at)
            }
        case .egg(let id):
            if item.targetsEgg, world.use(item, onEgg: id) {
                toast(item == .mutagen ? "the egg shimmers!" : "it's hatching!", ink: PlayUI.ink(.epic), atGrid: at)
            } else {
                toast("eggs only take egg potions", ink: PlayUI.grey, atGrid: at)
            }
        default:
            break
        }
        return true
    }

    /// Right-click: pin the card of the pet under the pointer, or close it.
    func rightClick(grid: SIMD2<Float>, hits: [HitBox]) {
        if let hit = hits.first(where: { $0.contains(grid) }), case .pet(let id) = hit.target {
            pinnedPet = pinnedPet == id ? nil : id
        } else {
            pinnedPet = nil
        }
    }

    var isBusy: Bool { pressed != nil || dragging != nil }
}

extension SpriteAtlas {
    /// A copy of one tile's pixels.
    func tileSprite(_ tile: UInt32) -> PixelSprite {
        var s = PixelSprite(width: Self.tileSize, height: Self.tileSize)
        let ox = Int(tile) % Self.columns * Self.tileSize, oy = Int(tile) / Self.columns * Self.tileSize
        for y in 0..<Self.tileSize { for x in 0..<Self.tileSize { s[x, y] = pixels[(oy + y) * width + ox + x] } }
        return s
    }
}

extension PixelSprite {
    /// Half size, keeping outlines: each 2x2 block takes its darkest-toned pixel.
    func halved() -> PixelSprite {
        var out = PixelSprite(width: width / 2, height: height / 2)
        for y in 0..<out.height {
            for x in 0..<out.width {
                let block = [self[2 * x, 2 * y], self[2 * x + 1, 2 * y], self[2 * x, 2 * y + 1], self[2 * x + 1, 2 * y + 1]]
                let filled = block.filter { $0 != Ink.clear }
                guard filled.count >= 2 else { continue }
                out[x, y] = filled.contains { Ink.tone(of: $0) == .outline } ? filled.first { Ink.tone(of: $0) == .outline }! : filled[0]
            }
        }
        return out
    }
}
