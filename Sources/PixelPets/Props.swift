import Foundation

// Monsters, eggs, loot, weapons, smoke and icons, drawn with the same shaded-part renderer
// as the pets so everything on screen shares one style.

extension MonsterKind {
    /// Canvas size of one frame.
    var canvas: Int { self == .ogre ? 128 : 64 }
    var moveFrames: Int { self == .ogre ? 8 : 6 }
    var attackFrames: Int { self == .ogre ? 6 : 4 }
    var moveFPS: Double { self == .bat ? 12 : self == .ogre ? 7 : 8 }
}

enum MonsterArt {
    static func frame(_ kind: MonsterKind, attack: Bool, frame i: Int) -> PixelSprite {
        let n = Double(attack ? kind.attackFrames : kind.moveFrames)
        let t = Double(i) / n
        switch kind {
        case .slime: return slime(t: t, attack: attack, i: i)
        case .bat: return bat(t: t, attack: attack, i: i)
        case .ogre: return ogre(t: t, attack: attack, i: i)
        }
    }

    private static func slime(t: Double, attack: Bool, i: Int) -> PixelSprite {
        let s = sin(t * 2 * .pi)
        var squash = 1 + 0.16 * s
        var lift = max(0, -s) * 3
        var lean = 0.0, reach = 0.0
        if attack {
            let k = [0.0, 0.6, 1.0, 0.4][i]
            squash = 1 - 0.15 * k
            lift = 0
            lean = 0.25 * k
            reach = 5 * k
        }
        let r = V2(9 / squash.squareRoot(), 7 * squash)
        let c = V2(15 + reach, 1 + r.y + lift)
        var parts = [Part(.ellipse(c: c, r: r, angle: -lean), .body, z: 0)]
        parts.append(Part(.ellipse(c: c + V2(-3.5, r.y * 0.45), r: V2(2.4, 1.6), angle: 0.5), .white, z: 0.1,
                          innerOutline: false, fixedTone: .light))
        parts.append(Part(.ellipse(c: c + V2(1, -r.y * 0.55), r: V2(6, 2), angle: 0), .secondary, z: 0.05, innerOutline: false))
        let eye = attack && i >= 1 ? ["kkk", ".kk"] : ["Wk", "kk"]
        let decals = [
            Decal(sprite: PixelSprite(stamp: eye), at: c + V2(3.5, 1)),
            Decal(sprite: PixelSprite(stamp: eye), at: c + V2(7, 1.2)),
            Decal(sprite: PixelSprite(stamp: attack && i >= 1 ? ["kkkk", "kWWk", ".kk."] : ["k..k", ".kk."]), at: c + V2(5.5, -2)),
        ]
        return Rig.render(parts, decals: decals, size: 64, scale: 2)
    }

    private static func bat(t: Double, attack: Bool, i: Int) -> PixelSprite {
        let flap = attack ? [0.2, -0.8, 1.0, 0.0][i] : sin(t * 2 * .pi)
        let dive = attack ? [0.0, 2.0, -3.0, -1.0][i] : 0
        let c = V2(16 + (attack ? [0, -1, 4, 2][i] : 0), 15 + dive + flap * 1.2)
        var parts = [Part(.ellipse(c: c, r: V2(4.6, 4.2), angle: 0), .body, z: 0, group: 0)]
        parts.append(Part(.ellipse(c: c + V2(0.5, -1.5), r: V2(2.6, 2), angle: 0), .secondary, z: 0.1, group: 0))
        // Ears
        parts.append(Part(.polygon([c + V2(-3, 2.5), c + V2(-1, 3.5), c + V2(-2.8, 7)]), .body, z: -0.1, group: 1, toneBias: 1))
        parts.append(Part(.polygon([c + V2(0.5, 3.5), c + V2(3, 2.5), c + V2(2.5, 7)]), .body, z: 0.2, group: 1))
        // Wings, far then near.
        for near in [false, true] {
            let side: Double = near ? 1 : -1
            let root = c + V2(side * 2.5, 1)
            let tipY = 7 * flap
            let pts = [root, root + V2(side * 6, 3 + tipY), root + V2(side * 12, 1 + tipY * 1.3),
                       root + V2(side * 10, -2 + tipY * 0.8), root + V2(side * 7, -1 + tipY * 0.6),
                       root + V2(side * 4.5, -3 + tipY * 0.4)]
            parts.append(Part(.polygon(pts), .body, z: near ? 0.5 : -0.5, group: near ? 2 : 3, toneBias: near ? 0 : 1))
        }
        let decals = [
            Decal(sprite: PixelSprite(stamp: ["R", "r"]), at: c + V2(-1.2, 1)),
            Decal(sprite: PixelSprite(stamp: ["R", "r"]), at: c + V2(1.8, 1)),
            Decal(sprite: PixelSprite(stamp: attack ? ["w.w", "w.w"] : ["w.w"]), at: c + V2(0.3, -1.8)),
        ]
        return Rig.render(parts, decals: decals, size: 64, scale: 2)
    }

    private static func ogre(t: Double, attack: Bool, i: Int) -> PixelSprite {
        let s = sin(t * 2 * .pi)
        let stride = attack ? 0 : s
        let bob = attack ? 0 : (1 - abs(s)) * 1.2
        // Club angle: resting on the shoulder, raised, then smashed down.
        let swing: Double = attack ? [1.2, 2.2, 2.6, 0.4, -0.6, 0.4][i] : 1.0 + 0.1 * s
        let lean: Double = attack ? [0, -0.08, -0.12, 0.12, 0.18, 0.05][i] : 0.03
        let ground = 1.0
        let hipY = ground + 15 + bob
        let body = V2(30, hipY + 9)
        var parts: [Part] = []
        // Legs
        for near in [true, false] {
            let hip = V2(body.x + (near ? 3 : -3), hipY)
            let foot = V2(hip.x + stride * (near ? 4 : -4), ground + 2.5)
            let knee = (hip + foot) / 2 + V2(1.5, 0)
            let z = near ? 1.0 : -1.0
            parts.append(Part(.capsule(a: hip, b: knee, ra: 4, rb: 3.4), .body, z: z, group: near ? 3 : 4, toneBias: near ? 0 : 1))
            parts.append(Part(.capsule(a: knee, b: foot, ra: 3.4, rb: 3), .body, z: z, group: near ? 3 : 4, toneBias: near ? 0 : 1))
            parts.append(Part(.ellipse(c: foot + V2(2, 0), r: V2(4.5, 2.5), angle: 0), .body, z: z + 0.01,
                              group: near ? 3 : 4, toneBias: near ? 0 : 1))
        }
        // Body, belly and loincloth
        parts.append(Part(.ellipse(c: body, r: V2(11, 11), angle: lean), .body, z: 0, group: 0))
        parts.append(Part(.ellipse(c: body + V2(2, -2), r: V2(7, 7), angle: 0), .body, z: 0.05, group: 0, fixedTone: .light))
        parts.append(Part(.polygon([body + V2(-10, -5), body + V2(10, -5), body + V2(8, -12), body + V2(1, -10),
                                    body + V2(-8, -12)]), .secondary, z: 0.5, group: 5))
        parts.append(Part(.polygon([body + V2(-10.5, -4), body + V2(10.5, -4), body + V2(10.5, -6), body + V2(-10.5, -6)]),
                          .wood, z: 0.6, group: 5))
        // Head with tusks
        let head = body + rotate(V2(4, 13), by: lean) + V2(attack ? lean * 10 : 0, 0)
        parts.append(Part(.ellipse(c: head, r: V2(7.5, 7), angle: 0), .body, z: 1, group: 1))
        parts.append(Part(.ellipse(c: head + V2(4, -2), r: V2(4, 3.2), angle: 0), .body, z: 1.1, group: 1, fixedTone: .base))
        parts.append(Part(.polygon([head + V2(3, -4), head + V2(5, -4), head + V2(3.5, 0)]), .white, z: 1.2, group: 6))
        parts.append(Part(.polygon([head + V2(6, -4), head + V2(8, -4), head + V2(7.5, -0.5)]), .white, z: 1.2, group: 7))
        // Far arm, near arm with the club.
        let shoulderFar = body + rotate(V2(-7, 6), by: lean)
        parts.append(Part(.capsule(a: shoulderFar, b: shoulderFar + V2(-3 - stride * 2, -10), ra: 3.2, rb: 3),
                          .body, z: -0.5, group: 8, toneBias: 1))
        let shoulder = body + rotate(V2(7, 6), by: lean)
        let hand = shoulder + rotate(V2(0, -10), by: swing * 0.9)
        parts.append(Part(.capsule(a: shoulder, b: hand, ra: 3.4, rb: 3), .body, z: 2, group: 9))
        let clubEnd = hand + rotate(V2(0, 15), by: swing)
        parts.append(Part(.capsule(a: hand, b: clubEnd, ra: 1.6, rb: 3.6), .wood, z: swing > 1.5 ? -0.8 : 2.1, group: 10))
        let decals = [
            Decal(sprite: PixelSprite(stamp: ["oo..", "Wkk.", "kkk."]), at: head + V2(1, 2)),
            Decal(sprite: PixelSprite(stamp: ["oo", "kk"]), at: head + V2(6, 2.2)),
            Decal(sprite: PixelSprite(stamp: ["kkkk"]), at: head + V2(5, -3.5)),
        ]
        return Rig.render(parts, decals: decals, size: 128, scale: 2)
    }
}

enum PropArt {
    /// Egg frames: 0-3 wobble, 4-5 cracked and shaking. `b` is the shell, `s` the spots.
    static let eggFrames = 6

    static func egg(_ i: Int) -> PixelSprite {
        let tilt: Double = [0, 0.12, 0, -0.12, 0.08, -0.08][i]
        let c = V2(16, 10.5)
        let pivot = V2(16, 1)
        func at(_ v: V2) -> V2 { pivot + rotate(c + v - pivot, by: tilt) }
        var parts = [Part(.ellipse(c: at(.zero), r: V2(7, 9.2), angle: tilt), .body, z: 0, patterned: true, role: .torso)]
        for (v, r) in [(V2(-3, 3), 1.6), (V2(2.5, -1), 2), (V2(-2, -5), 1.4), (V2(3.5, 5), 1.2), (V2(-4.5, -1), 1)] {
            parts.append(Part(.ellipse(c: at(v), r: V2(r, r * 0.9), angle: 0), .secondary, z: 0.1, innerOutline: false))
        }
        var decals: [Decal] = []
        if i >= 4 {
            decals.append(Decal(sprite: PixelSprite(stamp: ["k......", ".k..k.k", "..kk.k.", "......."]), at: at(V2(0, 2))))
        }
        return Rig.render(parts, decals: decals, size: 64, scale: 2)
    }

    static func grave() -> PixelSprite {
        let parts = [
            Part(.ellipse(c: V2(16, 15), r: V2(6.5, 6), angle: 0), .stone, z: 0),
            Part(.polygon([V2(9.5, 15), V2(22.5, 15), V2(22.5, 3), V2(9.5, 3)]), .stone, z: 0),
            Part(.ellipse(c: V2(16, 2.5), r: V2(10, 2.2), angle: 0), .green, z: 1, group: 2),
        ]
        let decals = [Decal(sprite: PixelSprite(stamp: [".t.", "ttt", ".t.", ".t."]), at: V2(16, 13)),
                      Decal(sprite: PixelSprite(stamp: ["g.G..g.G", "gGg.gGgg"]), at: V2(16, 4))]
        return Rig.render(parts, decals: decals, size: 64, scale: 2)
    }

    static func pellet() -> PixelSprite {
        Rig.render([Part(.ellipse(c: V2(16, 3.2), r: V2(3.2, 2.4), angle: 0), .body, z: 0),
                    Part(.ellipse(c: V2(15.2, 4), r: V2(1, 0.7), angle: 0), .secondary, z: 0.1, innerOutline: false)],
                   size: 64, scale: 2)
    }

    static func chest() -> PixelSprite {
        let parts = [
            Part(.polygon([V2(6, 2), V2(26, 2), V2(26, 11), V2(6, 11)]), .body, z: 0, group: 0),
            Part(.ellipse(c: V2(16, 11.5), r: V2(10.2, 5), angle: 0), .body, z: 0.5, group: 1),
            Part(.polygon([V2(6, 10.5), V2(26, 10.5), V2(26, 12), V2(6, 12)]), .secondary, z: 1, group: 2),
            Part(.polygon([V2(9, 2), V2(11, 2), V2(11, 16.3), V2(9, 16.3)]), .secondary, z: 1, group: 3),
            Part(.polygon([V2(21, 2), V2(23, 2), V2(23, 16.3), V2(21, 16.3)]), .secondary, z: 1, group: 4),
            Part(.polygon([V2(14.5, 8.5), V2(17.5, 8.5), V2(17.5, 12.5), V2(14.5, 12.5)]), .gold, z: 2, group: 5),
        ]
        return Rig.render(parts, decals: [Decal(sprite: PixelSprite(stamp: ["k"]), at: V2(16, 10))], size: 64, scale: 2)
    }

    static func bag() -> PixelSprite {
        let parts = [
            Part(.ellipse(c: V2(16, 7), r: V2(7, 6), angle: 0), .body, z: 0, group: 0),
            Part(.polygon([V2(13.5, 11), V2(18.5, 11), V2(20, 16), V2(12, 16)]), .body, z: -0.1, group: 1),
            Part(.capsule(a: V2(13, 12.5), b: V2(19, 12.5), ra: 1, rb: 1), .secondary, z: 1, group: 2),
        ]
        return Rig.render(parts, decals: [Decal(sprite: PixelSprite(stamp: ["yY", "uy"]), at: V2(17, 6))], size: 64, scale: 2)
    }

    /// Weapons are drawn with their grip at the centre of the canvas, pointing up and forward.
    static func weapon(_ item: Item) -> PixelSprite {
        Rig.render(weaponParts(item), size: 64, scale: 2)
    }

    /// `thick` widens blades and handles, for small icons.
    static func weaponParts(_ item: Item, thick: Double = 1) -> [Part] {
        let grip = V2(16, 6)
        let dir = rotate(V2(0, 1), by: -0.55)
        func along(_ d: Double, _ side: Double = 0) -> V2 { grip + dir * d + V2(dir.y, -dir.x) * side * thick }
        var parts: [Part] = []
        func blade(_ length: Double, width: Double, ramp: Ramp) {
            parts.append(Part(.polygon([along(3, -width), along(length - 2, -width), along(length, 0), along(length - 2, width),
                                        along(3, width)]), ramp, z: 0, group: 0))
        }
        func guardBar(_ ramp: Ramp) {
            parts.append(Part(.capsule(a: along(2.5, -3), b: along(2.5, 3), ra: 0.9 * thick, rb: 0.9 * thick), ramp, z: 1, group: 1))
        }
        func handle(_ ramp: Ramp, _ length: Double = 3) {
            parts.append(Part(.capsule(a: along(-length), b: along(2), ra: 0.9 * thick, rb: 0.9 * thick), ramp, z: 0.5, group: 2))
        }
        switch item {
        case .stick:
            parts.append(Part(.capsule(a: along(-3), b: along(13), ra: 1.1 * thick, rb: 0.8 * thick), .wood, z: 0))
            parts.append(Part(.capsule(a: along(7), b: along(9, 2.5), ra: 0.6 * thick, rb: 0.5 * thick), .wood, z: 0.1, group: 1))
        case .woodenSword:
            blade(15, width: 1.6, ramp: .wood); guardBar(.wood); handle(.wood)
        case .ironSword:
            blade(17, width: 1.6, ramp: .white); guardBar(.gold); handle(.wood)
        case .slingshot:
            parts.append(Part(.capsule(a: along(-3), b: along(5), ra: 1 * thick, rb: 1 * thick), .wood, z: 0, group: 0))
            parts.append(Part(.capsule(a: along(5), b: along(11, -3), ra: 1 * thick, rb: 0.8 * thick), .wood, z: 0, group: 1))
            parts.append(Part(.capsule(a: along(5), b: along(11, 3), ra: 1 * thick, rb: 0.8 * thick), .wood, z: 0, group: 2))
            parts.append(Part(.capsule(a: along(10.5, -3), b: along(10.5, 3), ra: 0.45 * thick, rb: 0.45 * thick), .red, z: 0.5, group: 3,
                              innerOutline: false))
        case .magicWand:
            parts.append(Part(.capsule(a: along(-3), b: along(11), ra: 0.9 * thick, rb: 0.8 * thick), .purple, z: 0))
            let tip = along(13)
            let star = (0..<10).map { k -> V2 in
                let a = Double(k) / 10 * 2 * .pi + 0.3
                return tip + V2(cos(a), sin(a)) * (k % 2 == 0 ? 3.6 : 1.6)
            }
            parts.append(Part(.polygon(star), .gold, z: 1, group: 1))
        default: // Dragon Fang
            parts.append(Part(.polygon([along(2, -2), along(9, -1.8), along(15, 1.5), along(9, 1.5), along(2, 1.8)]),
                              .white, z: 0))
            parts.append(Part(.capsule(a: along(-3), b: along(2), ra: 1.1 * thick, rb: 1.1 * thick), .red, z: 0.5, group: 2))
        }
        return parts
    }

    static let smokeFrames = 6

    static func smoke(_ i: Int) -> PixelSprite {
        let t = Double(i) / Double(smokeFrames - 1)
        var parts: [Part] = []
        let puffs: [(V2, Double)] = [(V2(16, 8), 6), (V2(10, 6), 4), (V2(22, 6), 4.2), (V2(13, 13), 4), (V2(20, 12), 3.6)]
        for (k, (c, r)) in puffs.enumerated() {
            let grow = 0.5 + t * 0.9
            let rise = t * 6
            parts.append(Part(.ellipse(c: c + (c - V2(16, 8)) * t * 0.6 + V2(0, rise), r: V2(r, r) * grow, angle: 0),
                              k % 2 == 0 ? .white : .stone, z: Double(k), group: k))
        }
        var sprite = Rig.render(parts, size: 64, scale: 2)
        // Dissolve as it fades.
        if t > 0.4 {
            for y in 0..<64 { for x in 0..<64 where hash01(x / 2, y / 2, i) < (t - 0.4) * 1.3 { sprite[x, y] = Ink.clear } }
        }
        return sprite
    }

    /// 10 x 10 icons drawn in the top-left of a tile. A dark drop shadow is added by the atlas.
    static func icon(_ kind: IconKind) -> PixelSprite {
        switch kind {
        case .heart: return PixelSprite(stamp: [
            ".rr..rr..",
            "rRRrrrrr.",
            "rRrrrrrq.",
            "rrrrrrrq.",
            ".rrrrrq..",
            "..rrrq...",
            "...rq....",
            "....q...."])
        case .drumstick: return PixelSprite(stamp: [
            "..ddd....",
            ".dDDdd...",
            "dDdddde..",
            "ddddddde.",
            ".dddddee.",
            "..ddeeWw.",
            "......ww.",
            ".....Wwx.",
            "......x.."])
        case .cloud: return PixelSprite(stamp: [
            "...sss...",
            ".sSSssss.",
            "sSsssssst",
            "ssssssstt",
            ".ttttttt.",
            "..b..b...",
            ".b..b..b.",
            "...b..b.."])
        case .zz: return PixelSprite(stamp: [
            "WWWW.....",
            "..W......",
            ".W.......",
            "WWWW.....",
            ".....WWW.",
            "......W..",
            ".....WWW."])
        case .face: return PixelSprite(stamp: [
            "..gggg...",
            ".gGGggg..",
            "gGkggkgh.",
            "gggggggh.",
            "ggkkkkgh.",
            "gkgggkgh.",
            ".ghhhhh..",
            "..hhhh..."])
        case .sparkle: return PixelSprite(stamp: [
            "...y.....",
            "...Y.....",
            ".yYWYy...",
            "...Y...y.",
            "...y..yWy",
            ".......y.",
            "..y......",
            ".yWy....."])
        case .exclamation: return PixelSprite(stamp: [
            "..rR.",
            "..rR.",
            "..rr.",
            "..rr.",
            "..qr.",
            ".....",
            "..rR.",
            "..qq."])
        }
    }
}

// MARK: - Item icons for the bag

enum ItemArt {
    /// A 16 x 16 icon, designed on the same 32-unit canvas and rendered at half scale.
    static func icon(_ item: Item) -> PixelSprite {
        Rig.render(parts(item), decals: decals(item), size: 16, scale: 0.5)
    }

    private static func bottle(_ liquid: Ramp, shape: Int) -> [Part] {
        switch shape {
        case 0: // round flask
            return [Part(.ellipse(c: V2(16, 11), r: V2(9, 9), angle: 0), .white, z: 0, group: 0),
                    Part(.ellipse(c: V2(16, 9.5), r: V2(7.6, 6.5), angle: 0), liquid, z: 0.1, group: 0),
                    Part(.capsule(a: V2(16, 18), b: V2(16, 25), ra: 3, rb: 3), .white, z: -0.1, group: 1),
                    Part(.ellipse(c: V2(16, 26.5), r: V2(3.6, 2.2), angle: 0), .wood, z: 0.2, group: 2),
                    Part(.ellipse(c: V2(12, 14), r: V2(1.6, 2.4), angle: 0.4), .white, z: 0.3, group: 0, innerOutline: false, fixedTone: .light)]
        case 1: // tall vial
            return [Part(.capsule(a: V2(16, 5), b: V2(16, 22), ra: 5.5, rb: 5.5), .white, z: 0, group: 0),
                    Part(.capsule(a: V2(16, 5), b: V2(16, 15), ra: 4.4, rb: 4.4), liquid, z: 0.1, group: 0),
                    Part(.polygon([V2(10, 23), V2(22, 23), V2(22, 28), V2(10, 28)]), .wood, z: 0.2, group: 2),
                    Part(.capsule(a: V2(13, 9), b: V2(13, 18), ra: 1, rb: 1), .white, z: 0.3, group: 0, innerOutline: false, fixedTone: .light)]
        default: // wide jar
            return [Part(.polygon([V2(7, 3), V2(25, 3), V2(26, 19), V2(6, 19)]), .white, z: 0, group: 0),
                    Part(.polygon([V2(8, 4), V2(24, 4), V2(24.5, 14), V2(7.5, 14)]), liquid, z: 0.1, group: 0),
                    Part(.polygon([V2(8, 19), V2(24, 19), V2(24, 25), V2(8, 25)]), .gold, z: 0.2, group: 2),
                    Part(.capsule(a: V2(10, 7), b: V2(10, 16), ra: 1, rb: 1), .white, z: 0.3, group: 0, innerOutline: false, fixedTone: .light)]
        }
    }

    private static func feather(_ ramp: Ramp, tip: Ramp) -> [Part] {
        [Part(.polygon([V2(8, 6), V2(12, 9), V2(22, 26), V2(19, 27), V2(11, 18)]), ramp, z: 0, group: 0),
         Part(.polygon([V2(12, 9), V2(17, 10), V2(24, 22), V2(22, 26)]), ramp, z: 0.1, group: 1, toneBias: 1),
         Part(.polygon([V2(18, 21), V2(24, 22), V2(22, 26), V2(19, 27)]), tip, z: 0.2, group: 2),
         Part(.capsule(a: V2(5, 3), b: V2(21, 26), ra: 0.7, rb: 0.5), .wood, z: 0.3, group: 3, innerOutline: false)]
    }

    private static func parts(_ item: Item) -> [Part] {
        if item.category == .weapon {
            return PropArt.weaponParts(item, thick: 1.9).map { part in
                var p = part
                p.shape = part.shape.transformed({ $0 + V2(-4, 3) }, scale: 1)
                return p
            }
        }
        switch item {
        case .snack:
            return [Part(.ellipse(c: V2(16, 15), r: V2(11, 10), angle: 0), .wood, z: 0)]
        case .tonic: return bottle(.red, shape: 0)
        case .joyJuice: return bottle(.pink, shape: 0)
        case .antidote: return bottle(.green, shape: 0)
        case .elixir: return bottle(.purple, shape: 0)
        case .strengthPotion: return bottle(.red, shape: 1)
        case .couragePotion: return bottle(.blue, shape: 1)
        case .hatchElixir: return bottle(.gold, shape: 2)
        case .mutagen: return bottle(.green, shape: 2) + [
            Part(.ellipse(c: V2(13, 10), r: V2(2, 2), angle: 0), .purple, z: 0.3, group: 4, innerOutline: false),
            Part(.ellipse(c: V2(19, 8), r: V2(1.5, 1.5), angle: 0), .purple, z: 0.3, group: 4, innerOutline: false)]
        case .espresso:
            return [Part(.polygon([V2(7, 4), V2(22, 4), V2(23, 20), V2(6, 20)]), .white, z: 0, group: 0),
                    Part(.ring(c: V2(24, 12), r: V2(4, 4.5), width: 2.2), .white, z: -0.1, group: 1),
                    Part(.ellipse(c: V2(14.5, 19.5), r: V2(7.5, 1.8), angle: 0), .wood, z: 0.1, group: 0, fixedTone: .shade),
                    Part(.capsule(a: V2(11, 23), b: V2(13, 29), ra: 0.8, rb: 0.6), .white, z: 0.2, group: 2, innerOutline: false, fixedTone: .light),
                    Part(.capsule(a: V2(17, 23), b: V2(16, 28), ra: 0.8, rb: 0.6), .white, z: 0.2, group: 3, innerOutline: false, fixedTone: .light)]
        case .featherCharm: return feather(.white, tip: .blue)
        case .phoenixFeather: return feather(.red, tip: .gold)
        case .cozyScarf:
            return [Part(.ring(c: V2(16, 19), r: V2(9, 6), width: 5), .red, z: 0, group: 0),
                    Part(.capsule(a: V2(19, 15), b: V2(21, 3), ra: 2.6, rb: 2.4), .red, z: 0.5, group: 1),
                    Part(.capsule(a: V2(22, 15), b: V2(26, 5), ra: 2.4, rb: 2.2), .red, z: 0.4, group: 2, toneBias: 1),
                    Part(.capsule(a: V2(18.5, 7), b: V2(23.5, 7.5), ra: 0.8, rb: 0.8), .white, z: 0.6, group: 1, innerOutline: false)]
        case .snackPouch:
            return [Part(.ellipse(c: V2(16, 11), r: V2(10, 8.5), angle: 0), .wood, z: 0, group: 0),
                    Part(.polygon([V2(12, 17), V2(20, 17), V2(23, 25), V2(9, 25)]), .wood, z: -0.1, group: 1),
                    Part(.capsule(a: V2(11, 18.5), b: V2(21, 18.5), ra: 1.4, rb: 1.4), .red, z: 0.2, group: 2)]
        case .moonPillow:
            return [Part(.ellipse(c: V2(16, 14), r: V2(13, 8), angle: 0), .blue, z: 0, group: 0),
                    Part(.ellipse(c: V2(16, 15), r: V2(5, 5), angle: 0), .gold, z: 0.1, group: 1),
                    Part(.ellipse(c: V2(18.5, 16.5), r: V2(4.2, 4.2), angle: 0), .blue, z: 0.2, group: 0)]
        case .guardianShell:
            return [Part(.ellipse(c: V2(16, 13), r: V2(12, 10), angle: 0), .green, z: 0, group: 0),
                    Part(.polygon([V2(12, 9), V2(20, 9), V2(22, 15), V2(16, 20), V2(10, 15)]), .green, z: 0.1, group: 1, toneBias: -1),
                    Part(.ellipse(c: V2(16, 4.5), r: V2(12, 2.5), angle: 0), .gold, z: -0.1, group: 2)]
        case .heartLocket:
            return [Part(.ring(c: V2(16, 20), r: V2(8, 8), width: 1.2), .gold, z: -0.1, group: 0),
                    Part(.polygon([V2(16, 3), V2(26, 13), V2(24, 17), V2(20, 18), V2(16, 15), V2(12, 18), V2(8, 17), V2(6, 13)]),
                         .red, z: 0.1, group: 1)]
        case .luckyClover:
            return [Part(.capsule(a: V2(16, 15), b: V2(20, 3), ra: 1, rb: 0.8), .green, z: -0.1, group: 0, toneBias: 1),
                    Part(.ellipse(c: V2(11, 18), r: V2(5, 5), angle: 0), .green, z: 0, group: 1),
                    Part(.ellipse(c: V2(21, 18), r: V2(5, 5), angle: 0), .green, z: 0, group: 2),
                    Part(.ellipse(c: V2(16, 23), r: V2(5, 5), angle: 0), .green, z: 0.1, group: 3),
                    Part(.ellipse(c: V2(16, 13), r: V2(5, 5), angle: 0), .green, z: 0.2, group: 4)]
        default:
            return []
        }
    }

    private static func decals(_ item: Item) -> [Decal] {
        switch item {
        case .snack: return [Decal(sprite: PixelSprite(stamp: ["e.e", "...", ".e."]), at: V2(16, 15), upscale: false)]
        case .luckyClover: return [Decal(sprite: PixelSprite(stamp: ["Y"]), at: V2(16, 18), upscale: false)]
        default: return []
        }
    }

    /// Rarity tint for frames and names.
    static func ramp(for rarity: Rarity) -> Ramp {
        switch rarity {
        case .common: return .stone
        case .uncommon: return .green
        case .rare: return .blue
        case .epic: return .purple
        case .legendary: return .gold
        }
    }
}
