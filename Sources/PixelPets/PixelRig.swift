import Foundation

// A tiny procedural pixel-art renderer. A sprite is a list of shaded shapes ("parts") placed
// by a pose. Each pixel is lit from the top left and quantized into four tones per colour
// ramp, then outlined with the ramp's darkest tone on the silhouette and wherever a part in
// front overlaps a part behind it. The shader maps (ramp, tone) to a real colour, so the body
// and secondary ramps follow each pet's genes.

typealias V2 = SIMD2<Double>

/// Colour ramps. Body and secondary come from the item's colours; the rest are fixed.
enum Ramp: UInt8, CaseIterable {
    case body, secondary, gold, red, green, stone, white, dark, pink, purple, wood, blue
}

enum Tone: UInt8 {
    case light, base, shade, outline

    func darker(by n: Int) -> Tone {
        Tone(rawValue: UInt8(max(0, min(3, Int(rawValue) + n))))!
    }
}

/// Atlas values: 0 is transparent, otherwise 1 + ramp * 4 + tone.
enum Ink {
    static let clear: UInt8 = 0

    static func make(_ ramp: Ramp, _ tone: Tone) -> UInt8 {
        1 + ramp.rawValue * 4 + tone.rawValue
    }

    static func ramp(of ink: UInt8) -> Ramp? {
        ink == 0 ? nil : Ramp(rawValue: (ink - 1) / 4)
    }

    static func tone(of ink: UInt8) -> Tone {
        Tone(rawValue: (ink - 1) % 4) ?? .base
    }

    /// Characters used by hand-drawn stamps (eyes, mouths, icons).
    /// Lowercase is the base tone, uppercase the light tone; `o` is the dark outline.
    static func stamp(_ c: Character, bodyOutline: Bool = false) -> UInt8? {
        switch c {
        case ".": return nil
        case "o": return bodyOutline ? make(.body, .outline) : make(.dark, .outline)
        case "O": return make(.body, .outline)
        case "k": return make(.dark, .base)
        case "K": return make(.dark, .light)
        case "w": return make(.white, .base)
        case "W": return make(.white, .light)
        case "x": return make(.white, .shade)
        case "r": return make(.red, .base)
        case "R": return make(.red, .light)
        case "q": return make(.red, .shade)
        case "y": return make(.gold, .base)
        case "Y": return make(.gold, .light)
        case "u": return make(.gold, .shade)
        case "g": return make(.green, .base)
        case "G": return make(.green, .light)
        case "h": return make(.green, .shade)
        case "s": return make(.stone, .base)
        case "S": return make(.stone, .light)
        case "t": return make(.stone, .shade)
        case "p": return make(.pink, .base)
        case "P": return make(.pink, .light)
        case "b": return make(.blue, .base)
        case "B": return make(.blue, .light)
        case "n": return make(.blue, .shade)
        case "v": return make(.purple, .base)
        case "V": return make(.purple, .light)
        case "d": return make(.wood, .base)
        case "D": return make(.wood, .light)
        case "e": return make(.wood, .shade)
        case "1": return make(.body, .light)
        case "2": return make(.body, .base)
        case "3": return make(.body, .shade)
        case "4": return make(.secondary, .light)
        case "5": return make(.secondary, .base)
        case "6": return make(.secondary, .shade)
        default: return nil
        }
    }
}

// MARK: - Pixel grid

struct PixelSprite: Equatable {
    let width: Int
    let height: Int
    /// Row-major, row 0 at the top.
    var pixels: [UInt8]

    init(width: Int, height: Int) {
        self.width = width
        self.height = height
        pixels = Array(repeating: Ink.clear, count: width * height)
    }

    /// A hand-drawn stamp. See `Ink.stamp` for the characters.
    init(stamp rows: [String]) {
        let w = rows.map(\.count).max() ?? 0
        self.init(width: w, height: rows.count)
        for (y, line) in rows.enumerated() {
            for (x, c) in line.enumerated() { pixels[y * w + x] = Ink.stamp(c) ?? Ink.clear }
        }
    }

    subscript(x: Int, y: Int) -> UInt8 {
        get { x >= 0 && y >= 0 && x < width && y < height ? pixels[y * width + x] : Ink.clear }
        set { if x >= 0 && y >= 0 && x < width && y < height { pixels[y * width + x] = newValue } }
    }

    func mirrored() -> PixelSprite {
        var out = PixelSprite(width: width, height: height)
        for y in 0..<height { for x in 0..<width { out[width - 1 - x, y] = self[x, y] } }
        return out
    }

    func replacing(_ ink: UInt8, with other: UInt8) -> PixelSprite {
        var out = self
        for y in 0..<height { for x in 0..<width where out[x, y] == ink { out[x, y] = other } }
        return out
    }

    func upscaled(by k: Int) -> PixelSprite {
        var out = PixelSprite(width: width * k, height: height * k)
        for y in 0..<out.height { for x in 0..<out.width { out[x, y] = self[x / k, y / k] } }
        return out
    }

    /// Draws `other` with its top-left at (`x`, `y`), skipping transparent pixels.
    mutating func draw(_ other: PixelSprite, x: Int, y: Int) {
        for sy in 0..<other.height {
            for sx in 0..<other.width where other[sx, sy] != Ink.clear {
                self[x + sx, y + sy] = other[sx, sy]
            }
        }
    }
}

// MARK: - Shapes

enum Shape {
    case ellipse(c: V2, r: V2, angle: Double)
    /// A tapered capsule from `a` (radius `ra`) to `b` (radius `rb`).
    case capsule(a: V2, b: V2, ra: Double, rb: Double)
    case polygon([V2])
    case ring(c: V2, r: V2, width: Double)

    struct Hit {
        /// Surface normal: x right, y up, z toward the viewer.
        var normal: SIMD3<Double>
        /// Position inside the shape, roughly -1...1 on each axis.
        var local: V2
        /// Along a capsule from `a` (0) to `b` (1); bottom (0) to top (1) for other shapes.
        var along: Double
    }

    func hit(_ p: V2) -> Hit? {
        switch self {
        case let .ellipse(c, r, angle):
            let d = rotate(p - c, by: -angle)
            let q = V2(d.x / r.x, d.y / r.y)
            let len2 = q.x * q.x + q.y * q.y
            guard len2 <= 1 else { return nil }
            let n = rotate(q, by: angle)
            return Hit(normal: unit(n.x, n.y, (1 - len2).squareRoot() * 1.15), local: q, along: (q.y + 1) / 2)

        case let .capsule(a, b, ra, rb):
            let ab = b - a
            let len2 = dot2(ab, ab)
            let h = len2 > 0 ? max(0, min(1, dot2(p - a, ab) / len2)) : 0
            let r = ra + (rb - ra) * h
            let d = p - (a + ab * h)
            let dist = (d.x * d.x + d.y * d.y).squareRoot()
            guard dist <= r else { return nil }
            let k = r > 0 ? dist / r : 0
            let dir = dist > 0 ? d / dist : V2(0, 1)
            return Hit(normal: unit(dir.x * k, dir.y * k, (1 - k * k).squareRoot() * 1.15),
                       local: V2(k, h * 2 - 1), along: h)

        case let .polygon(points):
            guard Shape.contains(points, p) else { return nil }
            let xs = points.map(\.x), ys = points.map(\.y)
            let lo = V2(xs.min()!, ys.min()!), hi = V2(xs.max()!, ys.max()!)
            let size = V2(max(hi.x - lo.x, 0.001), max(hi.y - lo.y, 0.001))
            let q = (p - lo) / size * 2 - 1
            return Hit(normal: unit(q.x * 0.45, q.y * 0.45 + 0.15, 0.85), local: q, along: (q.y + 1) / 2)

        case let .ring(c, r, width):
            let d = p - c
            let q = V2(d.x / r.x, d.y / r.y)
            let l = (q.x * q.x + q.y * q.y).squareRoot()
            guard abs(l - 1) * min(r.x, r.y) <= width / 2 else { return nil }
            return Hit(normal: unit(q.x * 0.4, q.y * 0.4 + 0.3, 0.85), local: q, along: 0.5)
        }
    }

    func transformed(_ f: (V2) -> V2, scale: Double) -> Shape {
        switch self {
        case let .ellipse(c, r, angle): return .ellipse(c: f(c), r: r * scale, angle: angle)
        case let .capsule(a, b, ra, rb): return .capsule(a: f(a), b: f(b), ra: ra * scale, rb: rb * scale)
        case let .polygon(points): return .polygon(points.map(f))
        case let .ring(c, r, width): return .ring(c: f(c), r: r * scale, width: width * scale)
        }
    }

    private static func contains(_ poly: [V2], _ p: V2) -> Bool {
        var inside = false
        var j = poly.count - 1
        for i in 0..<poly.count {
            let a = poly[i], b = poly[j]
            if (a.y > p.y) != (b.y > p.y) && p.x < (b.x - a.x) * (p.y - a.y) / (b.y - a.y) + a.x {
                inside.toggle()
            }
            j = i
        }
        return inside
    }
}

func rotate(_ v: V2, by angle: Double) -> V2 {
    let c = cos(angle), s = sin(angle)
    return V2(v.x * c - v.y * s, v.x * s + v.y * c)
}

func dot2(_ a: V2, _ b: V2) -> Double { a.x * b.x + a.y * b.y }

private func unit(_ x: Double, _ y: Double, _ z: Double) -> SIMD3<Double> {
    let l = (x * x + y * y + z * z).squareRoot()
    return l > 0 ? SIMD3(x / l, y / l, z / l) : SIMD3(0, 0, 1)
}

/// A stable hash in 0..<1.
func hash01(_ x: Int, _ y: Int, _ seed: Int = 0) -> Double {
    var h = UInt64(bitPattern: Int64(x &* 374_761_393 &+ y &* 668_265_263 &+ seed &* 2_147_483_647))
    h = (h ^ (h >> 13)) &* 1_274_126_177
    h ^= h >> 16
    return Double(h & 0xFFFF) / 65_536
}

// MARK: - Parts

struct Part {
    enum Role { case plain, torso, head, limb, extremity }

    var shape: Shape
    var ramp: Ramp
    var z: Double = 0
    /// Parts in the same group are not outlined against each other.
    var group = 0
    /// Body patterns (spots, stripes...) paint over this part.
    var patterned = false
    /// +1 darkens a part on the far side.
    var toneBias = 0
    var role: Role = .plain
    /// Draws a line where this part overlaps a part behind it.
    var innerOutline = true
    /// Ignore lighting and use this tone.
    var fixedTone: Tone?

    init(_ shape: Shape, _ ramp: Ramp, z: Double = 0, group: Int = 0, patterned: Bool = false,
         toneBias: Int = 0, role: Role = .plain, innerOutline: Bool = true, fixedTone: Tone? = nil) {
        self.shape = shape
        self.ramp = ramp
        self.z = z
        self.group = group
        self.patterned = patterned
        self.toneBias = toneBias
        self.role = role
        self.innerOutline = innerOutline
        self.fixedTone = fixedTone
    }
}

/// A small drawing placed after shading: eyes, mouths, blush, cracks.
struct Decal {
    var sprite: PixelSprite
    /// Centre of the decal, in canvas coordinates (y up).
    var at: V2
    /// Drawn at the render scale (chunky), or 1:1 for stamps already drawn at full resolution.
    var upscale = true
}

enum Rig {
    static let light = SIMD3<Double>(-0.5, 0.72, 0.55) / (0.25 + 0.5184 + 0.3025).squareRoot()

    /// Rasterizes parts into a `size` x `size` sprite. Canvas coordinates have y up, origin
    /// at the bottom left; the result has row 0 at the top.
    /// `furry` adds short strokes of the neighbouring tone, like brushed fur.
    /// Parts and decals are laid out in canvas units; `scale` renders them that many times
    /// larger, so a 32-unit design fills a 64-pixel sprite with 1-pixel outlines.
    static func render(_ designParts: [Part], decals designDecals: [Decal] = [], size: Int, scale: Double = 1,
                       pattern: Pattern = .plain, furry: Bool = false) -> PixelSprite {
        let parts = scale == 1 ? designParts : designParts.map { part -> Part in
            var p = part
            p.shape = part.shape.transformed({ $0 * scale }, scale: scale)
            return p
        }
        let decals = designDecals.map { d -> Decal in
            var out = d
            out.at = d.at * scale
            if d.upscale && scale >= 2 { out.sprite = d.sprite.upscaled(by: Int(scale)) }
            return out
        }
        let order = parts.indices.sorted { parts[$0].z != parts[$1].z ? parts[$0].z < parts[$1].z : $0 < $1 }
        var owner = Array(repeating: -1, count: size * size)
        var ink = Array(repeating: Ink.clear, count: size * size)

        for y in 0..<size {
            for x in 0..<size {
                let p = V2(Double(x) + 0.5, Double(y) + 0.5)
                var found: (Int, Shape.Hit)?
                for i in order {
                    if let hit = parts[i].shape.hit(p) { found = (i, hit) }
                }
                guard let (i, hit) = found else { continue }
                let part = parts[i]
                var tone: Tone
                if let fixed = part.fixedTone {
                    tone = fixed
                } else {
                    let l = hit.normal.x * light.x + hit.normal.y * light.y + hit.normal.z * light.z
                    tone = l > 0.83 ? .light : l > 0.4 ? .base : .shade
                }
                if furry && (part.ramp == .body || part.ramp == .secondary) && part.fixedTone == nil {
                    // Two-pixel vertical strokes, offset per column.
                    let h = hash01(x, (y + x % 3) / 3, 5)
                    if tone == .base && h < 0.13 { tone = .shade }
                    else if tone == .light && h < 0.22 { tone = .base }
                    else if tone == .shade && h > 0.9 { tone = .base }
                }
                tone = tone.darker(by: part.toneBias)
                if tone == .outline { tone = .shade }
                var ramp = part.ramp
                if part.patterned, let painted = paint(pattern, part: part, hit: hit,
                                                       x: Int(Double(x) / scale), y: Int(Double(y) / scale)) {
                    ramp = painted
                }
                owner[y * size + x] = i
                ink[y * size + x] = Ink.make(ramp, tone)
            }
        }

        // Cast shadow: a part just up-left of a part behind it shades that part's edge.
        var shaded = ink
        for y in 0..<size {
            for x in 0..<size {
                let i = owner[y * size + x]
                guard i >= 0, let ramp = Ink.ramp(of: ink[y * size + x]) else { continue }
                for (dx, dy) in [(-1, 1), (0, 1), (-1, 0)] {
                    let nx = x + dx, ny = y + dy
                    guard nx >= 0, ny >= 0, nx < size, ny < size else { continue }
                    let j = owner[ny * size + nx]
                    if j >= 0 && parts[j].group != parts[i].group && parts[j].z > parts[i].z {
                        let tone = Ink.tone(of: ink[y * size + x])
                        shaded[y * size + x] = Ink.make(ramp, tone == .light ? .base : .shade)
                        break
                    }
                }
            }
        }
        ink = shaded

        // Outlines: the silhouette, and front parts where they overlap parts behind.
        var outlined = ink
        for y in 0..<size {
            for x in 0..<size {
                let i = owner[y * size + x]
                guard i >= 0, let ramp = Ink.ramp(of: ink[y * size + x]) else { continue }
                var edge = false
                for (dx, dy) in [(1, 0), (-1, 0), (0, 1), (0, -1)] {
                    let nx = x + dx, ny = y + dy
                    guard nx >= 0, ny >= 0, nx < size, ny < size else { edge = true; break }
                    let j = owner[ny * size + nx]
                    if j < 0 { edge = true; break }
                    if parts[i].innerOutline && parts[j].group != parts[i].group && parts[j].z < parts[i].z {
                        edge = true
                        break
                    }
                }
                if edge { outlined[y * size + x] = Ink.make(ramp, .outline) }
            }
        }

        var sprite = PixelSprite(width: size, height: size)
        for y in 0..<size {
            for x in 0..<size { sprite[x, size - 1 - y] = outlined[y * size + x] }
        }
        // Decals respect depth: they only paint the part under their centre (usually the head),
        // so anything in front of that part, like an ear or a paw, hides them.
        func ownerGroup(_ x: Int, _ yUp: Int) -> Int? {
            guard x >= 0, yUp >= 0, x < size, yUp < size else { return nil }
            let i = owner[yUp * size + x]
            return i >= 0 ? parts[i].group : nil
        }
        for decal in decals {
            let left = Int((decal.at.x - Double(decal.sprite.width) / 2).rounded())
            let top = size - Int((decal.at.y + Double(decal.sprite.height) / 2).rounded())
            let anchor = ownerGroup(Int(decal.at.x), Int(decal.at.y))
            for sy in 0..<decal.sprite.height {
                for sx in 0..<decal.sprite.width where decal.sprite[sx, sy] != Ink.clear {
                    let x = left + sx, yUp = size - 1 - (top + sy)
                    guard let group = ownerGroup(x, yUp) else { continue }
                    if let anchor, group != anchor { continue }
                    sprite[x, top + sy] = decal.sprite[sx, sy]
                }
            }
        }
        return sprite
    }

    /// The ramp a body pattern paints at this pixel, if any.
    static func paint(_ pattern: Pattern, part: Part, hit: Shape.Hit, x: Int, y: Int) -> Ramp? {
        let q = hit.local
        switch pattern {
        case .plain:
            return nil
        case .spots:
            let g = q * 2.3 + V2(5, 5)
            let cell = V2(g.x.rounded(.down), g.y.rounded(.down))
            let f = g - cell - V2(0.5, 0.5)
            let lucky = hash01(Int(cell.x), Int(cell.y), part.role == .head ? 7 : 3) > 0.35
            return lucky && (f.x * f.x + f.y * f.y) < 0.09 ? .secondary : nil
        case .stripes:
            return sin((Double(x) + Double(y) * 0.35) * 1.25) > 0.5 ? .secondary : nil
        case .patch:
            guard part.role == .torso || part.role == .head else { return nil }
            let d = q - V2(-0.3, 0.35)
            return d.x * d.x + d.y * d.y < 0.3 ? .secondary : nil
        case .socks:
            if part.role == .limb { return hit.along > 0.55 ? .secondary : nil }
            return part.role == .torso && q.y < -0.62 ? .secondary : nil
        case .tips:
            if part.role == .extremity { return hit.along > 0.55 ? .secondary : nil }
            return part.role == .head && q.y > 0.5 ? .secondary : nil
        case .twoTone:
            return q.x < -0.05 ? .secondary : nil
        case .checker:
            return (x / 3 + y / 3) % 2 == 0 ? .secondary : nil
        case .speckle:
            return hash01(x, y, 11) < 0.14 ? .secondary : nil
        case .heart:
            guard part.role == .torso else { return nil }
            let hx = (q.x + 0.05) * 1.9, hy = q.y * 1.9 + 0.35
            let a = hx * hx + hy * hy - 1
            return a * a * a - hx * hx * hy * hy * hy < 0 ? .red : nil
        case .stars:
            let h = hash01(x, y, 23)
            return h < 0.05 ? .white : h < 0.09 ? .gold : nil
        case .rainbow:
            let bands: [Ramp] = [.red, .gold, .green, .blue, .purple]
            return bands[((y / 3) % bands.count + bands.count) % bands.count]
        }
    }
}
