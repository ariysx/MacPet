import Foundation

// Monsters, eggs, loot, weapons, smoke and icons, drawn with the same shaded-part renderer
// as the pets so everything on screen shares one style.

extension MonsterKind {
    /// Canvas size of one frame.
    var canvas: Int { isBig ? 128 : 64 }
    var moveFrames: Int {
        switch self {
        case .wolf, .ogre, .golem: return 8
        default: return 6
        }
    }
    var attackFrames: Int {
        switch self {
        case .wolf, .ogre, .golem: return 6
        default: return 4
        }
    }
    var moveFPS: Double {
        switch self {
        case .bat: return 12
        case .wolf: return 11
        case .ogre, .golem: return 6
        default: return 8
        }
    }
    /// Body and secondary colours.
    var colours: (UInt32, UInt32) {
        switch self {
        case .slime: return (0x5FC46E, 0xB8F0B0)
        case .shroomling: return (0xD9534F, 0xF2E3C6)
        case .bat: return (0x5A4A78, 0xC9A8E8)
        case .wolf: return (0x7A7F8F, 0xE6E4DE)
        case .wisp: return (0x3FB8E0, 0xB8F4FF)
        case .ogre: return (0x8C9A5B, 0xA0673A)
        case .golem: return (0x8A8798, 0x6FAE52)
        }
    }
}

/// Monsters, drawn with the same rigs, shading and faces as the pets.
enum MonsterArt {
    static func frame(_ kind: MonsterKind, attack: Bool, frame i: Int) -> PixelSprite {
        let n = Double(attack ? kind.attackFrames : kind.moveFrames)
        let t = Double(i) / n
        switch kind {
        case .slime: return slime(t, attack, i)
        case .shroomling: return shroomling(t, attack, i)
        case .bat: return bat(t, attack, i)
        case .wolf: return wolf(attack, i)
        case .wisp: return wisp(t, attack, i)
        case .ogre: return ogre(t, attack, i)
        case .golem: return golem(t, attack, i)
        }
    }

    private static func face(_ rows: [String], _ at: V2) -> Decal {
        Decal(sprite: PixelSprite(stamp: rows), at: at, upscale: false)
    }

    private static let angryEye = ["OO...", ".OOO.", "kWkk.", "kkkk.", ".kk.."]
    private static let angryEyeR = ["...OO", ".OOO.", ".kWkk", ".kkkk", "..kk."]

    // MARK: Slime

    private static func slime(_ t: Double, _ attack: Bool, _ i: Int) -> PixelSprite {
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
        let r = V2(10 / squash.squareRoot(), 7.5 * squash)
        let c = V2(15 + reach, 1 + r.y + lift)
        var parts = [Part(.ellipse(c: c, r: r, angle: -lean), .body, z: 0)]
        parts.append(Part(.ellipse(c: c + V2(1, -1.5), r: r * 0.62, angle: -lean), .secondary, z: 0.05, innerOutline: false))
        for (v, rr) in [(V2(-3, -2.5), 1.0), (V2(2.5, -4), 0.7), (V2(-1, -5), 0.6)] {
            parts.append(Part(.ellipse(c: c + v, r: V2(rr, rr), angle: 0), .white, z: 0.1, group: 2, innerOutline: false, fixedTone: .base))
        }
        parts.append(Part(.ellipse(c: c + V2(-4.5, r.y * 0.45), r: V2(2.6, 1.6), angle: 0.5), .white, z: 0.2, group: 3,
                          innerOutline: false, fixedTone: .light))
        parts.append(Part(.ellipse(c: c + V2(-1.8, r.y * 0.62), r: V2(0.8, 0.7), angle: 0), .white, z: 0.2, group: 3,
                          innerOutline: false, fixedTone: .light))
        let mad = attack && i >= 1
        let decals = [
            face(mad ? angryEye : [".kk.", "kWkk", "kkkk", ".kk."], c + V2(3.5, 1.2)),
            face(mad ? angryEyeR : [".kk.", "kWkk", "kkkk", ".kk."], c + V2(7.5, 1.4)),
            face(mad ? ["kkkkk", "kWkWk", ".kkk."] : ["k...k", ".kkk."], c + V2(5.5, -2)),
        ]
        return Rig.render(parts, decals: decals, size: 64, scale: 2)
    }

    // MARK: Shroomling

    private static func shroomling(_ t: Double, _ attack: Bool, _ i: Int) -> PixelSprite {
        let s = sin(t * 2 * .pi)
        let bob = attack ? 0 : abs(s) * 1.2
        let bonk = attack ? [0.0, -0.25, 0.55, 0.3][i] : 0.05 * s
        let c = V2(16 + (attack ? [0, -1, 3, 1.5][i] : 0), 1 + 7 + bob)
        var parts: [Part] = []
        // Stubby legs
        for near in [true, false] {
            let foot = V2(c.x + (near ? 2.5 : -2.5) + (attack ? 0 : s * (near ? 1.8 : -1.8)), 2.2)
            parts.append(Part(.ellipse(c: foot, r: V2(2.4, 1.6), angle: 0), .secondary, z: near ? 1 : -1, group: near ? 3 : 4,
                              toneBias: near ? 0 : 1))
        }
        // Stem body with a face
        parts.append(Part(.ellipse(c: c, r: V2(5.5, 6), angle: 0), .secondary, z: 0, group: 0))
        parts.append(Part(.ellipse(c: c + V2(4.5, 0.5), r: V2(1.8, 1.4), angle: 0.4 + (attack ? 0.8 : 0)), .secondary,
                          z: 0.5, group: 5))
        // Cap, tipping forward to headbutt
        let capC = c + rotate(V2(0, 7), by: -bonk)
        parts.append(Part(.ellipse(c: capC, r: V2(11, 6.5), angle: -bonk), .body, z: 1, group: 1))
        parts.append(Part(.ellipse(c: capC + rotate(V2(0, -4.5), by: -bonk), r: V2(9.5, 2), angle: -bonk), .secondary,
                          z: 0.9, group: 1, toneBias: 1))
        for (v, r) in [(V2(-5, 2), 1.8), (V2(1, 4), 2.2), (V2(6, 1), 1.5), (V2(-1.5, 0), 1.1)] {
            parts.append(Part(.ellipse(c: capC + rotate(v, by: -bonk), r: V2(r, r * 0.85), angle: 0), .white, z: 1.1,
                              group: 6, innerOutline: false))
        }
        var decals = [
            face(attack && i >= 2 ? [".k.", "k.k"] : ["kk", "Wk", "kk"], c + V2(1, 0.5)),
            face(attack && i >= 2 ? [".k.", "k.k"] : ["kk", "Wk", "kk"], c + V2(4.5, 0.7)),
            face(attack ? ["kkk", "kpk"] : ["k.k", ".k."], c + V2(3, -2.5)),
        ]
        if attack && i >= 2 {
            for (k, v) in [V2(9, 13), V2(12, 10), V2(10, 16)].enumerated() {
                decals.append(Decal(sprite: PixelSprite(stamp: k == 1 ? ["g"] : ["G"]), at: c + v, upscale: true))
            }
        }
        return Rig.render(parts, decals: decals, size: 64, scale: 2)
    }

    // MARK: Bat

    private static func bat(_ t: Double, _ attack: Bool, _ i: Int) -> PixelSprite {
        let flap = attack ? [0.2, -0.8, 1.0, 0.0][i] : sin(t * 2 * .pi)
        let dive = attack ? [0.0, 2.0, -3.0, -1.0][i] : 0
        let c = V2(16 + (attack ? [0, -1, 4, 2][i] : 0), 15 + dive + flap * 1.2)
        var parts = [Part(.ellipse(c: c, r: V2(4.8, 4.6), angle: 0), .body, z: 0, group: 0, role: .torso)]
        parts.append(Part(.ellipse(c: c + V2(0.4, -1.6), r: V2(2.8, 2.2), angle: 0), .secondary, z: 0.1, group: 0))
        // Ears with pink insides
        for (near, pts) in [(false, [V2(-3.4, 2.8), V2(-1, 3.8), V2(-3.2, 8)]), (true, [V2(0.6, 3.8), V2(3.4, 2.8), V2(2.8, 8)])] {
            parts.append(Part(.polygon(pts.map { c + $0 }), .body, z: near ? 0.2 : -0.1, group: 1, toneBias: near ? 0 : 1))
            let inner = pts.map { c + pts[0] + ($0 - pts[0]) * 0.6 + V2(near ? -0.2 : 0.3, 0.6) }
            parts.append(Part(.polygon(inner), .pink, z: (near ? 0.2 : -0.1) + 0.01, group: 1, innerOutline: false))
        }
        // Feet
        for x in [-1.5, 1.5] {
            parts.append(Part(.capsule(a: c + V2(x, -4), b: c + V2(x * 1.2, -6), ra: 0.6, rb: 0.5), .dark, z: -0.2, group: 7))
        }
        // Wings with finger bones, far then near.
        for near in [false, true] {
            let side: Double = near ? 1 : -1
            let root = c + V2(side * 2.8, 1)
            let tipY = 7 * flap
            let pts = [root, root + V2(side * 6, 3.5 + tipY), root + V2(side * 12.5, 1.5 + tipY * 1.3),
                       root + V2(side * 10.5, -2 + tipY * 0.8), root + V2(side * 7.5, -0.8 + tipY * 0.6),
                       root + V2(side * 4.8, -3 + tipY * 0.4)]
            let z = near ? 0.5 : -0.5
            parts.append(Part(.polygon(pts), .body, z: z, group: near ? 2 : 3, toneBias: near ? 0 : 1))
            for k in [2, 3, 5] {
                parts.append(Part(.capsule(a: root, b: pts[k], ra: 0.45, rb: 0.3), .dark, z: z + 0.01, group: near ? 2 : 3,
                                  innerOutline: false))
            }
        }
        let decals = [
            face(attack ? ["RR.", ".RR"] : ["RR", "Rr"], c + V2(-1.5, 1)),
            face(attack ? [".RR", "RR."] : ["RR", "rR"], c + V2(2, 1)),
            face(attack ? ["kkkk", "WkkW", "W..W"] : ["W..W", "W..W"], c + V2(0.3, -1.6)),
        ]
        return Rig.render(parts, decals: decals, size: 64, scale: 2, furry: true)
    }

    // MARK: Wolf

    private static func wolf(_ attack: Bool, _ i: Int) -> PixelSprite {
        var pose = Pose.of(attack ? .attack : .walk, frame: i)
        pose.eyes = .open
        var spec = SpeciesRig.QuadSpec()
        spec.bodyR = V2(8.6, 5.2)
        spec.bodyX = 14
        spec.legLen = 5.2
        spec.legR = (1.7, 1.3)
        spec.legX = (5.2, -5.5)
        spec.headR = 4.4
        spec.headOffset = V2(8.6, 4.6)
        spec.bellyR = V2(4.5, 2)
        let q = SpeciesRig.quadruped(spec, pose)
        var b = q.built
        // Long snout, tall ears, a ruff, and a bushy tail.
        b.parts.append(Part(SpeciesRig.headPolygon(b, [V2(0.3, 0.3), V2(1.85, -0.25), V2(1.75, -0.65), V2(0.3, -0.8)]), .body,
                            z: 1.1, group: 1, patterned: true))
        b.parts.append(Part(SpeciesRig.headPolygon(b, [V2(0.3, -0.4), V2(1.6, -0.6), V2(0.4, -0.95)]), .secondary, z: 1.15, group: 1))
        for (pts, z, bias) in [([V2(-0.85, 0.5), V2(-0.2, 0.85), V2(-0.75, 1.8)], 0.9, 1),
                               ([V2(-0.1, 0.8), V2(0.55, 0.55), V2(0.25, 1.75)], 1.2, 0)] {
            b.parts.append(Part(SpeciesRig.headPolygon(b, pts), .body, z: z, group: 6, toneBias: bias))
        }
        let neck = q.bodyC + rotate(V2(q.bodyR.x * 0.55, q.bodyR.y * 0.3), by: q.angle)
        b.parts.append(Part(.polygon([neck + V2(-3, 4), neck + V2(1, 6), neck + V2(4, 2), neck + V2(3, -3), neck + V2(-2, -2)]),
                            .secondary, z: 0.6, group: 8))
        var a = 2.9 + pose.tail * 0.2
        var p = q.bodyC + rotate(V2(-q.bodyR.x * 0.9, q.bodyR.y * 0.25), by: q.angle)
        for k in 0..<3 {
            let next = p + rotate(V2(3.2, 0), by: a)
            b.parts.append(Part(.ellipse(c: (p + next) / 2, r: V2(2.6, [1.8, 2.3, 1.9][k]), angle: a), k == 2 ? .secondary : .body,
                                z: -1, group: 5))
            p = next
            a -= 0.3
        }
        let eye = b.onHead(V2(0.35, 0.2))
        let decals = [face(["OOO..", ".OOOO", "..kWk", "..kkk"], eye),
                      face(attack && i >= 2 && i <= 4 ? ["kkkkk", "kWkWk", "kk.kk"] : ["k.k.k", ".kkk."], b.onHead(V2(1.5, -0.75)))]
        return Rig.render(b.parts, decals: decals, size: 64, scale: 2, furry: true)
    }

    // MARK: Wisp

    private static func wisp(_ t: Double, _ attack: Bool, _ i: Int) -> PixelSprite {
        let f = sin(t * 2 * .pi)
        let flare = attack ? [0.0, 0.6, 1.2, 0.5][i] : 0
        let c = V2(16 + (attack ? [0, -1, 4, 2][i] : 0), 11 + f * 1.2)
        func flame(_ scale: Double, _ ramp: Ramp, _ z: Double, _ group: Int, tone: Tone? = nil) -> Part {
            let h = (15 + flare * 5) * scale
            let w = 9.5 * scale
            let pts = [c + V2(-w, 0), c + V2(-w * 0.9, -w * 0.7), c + V2(0, -w), c + V2(w * 0.9, -w * 0.7), c + V2(w, 0),
                       c + V2(w * 0.6, h * 0.45), c + V2(w * 0.2 + f * 1.2, h * 0.3), c + V2(-w * 0.1 + f * 1.5, h),
                       c + V2(-w * 0.4, h * 0.4), c + V2(-w * 0.75 - f, h * 0.55)]
            return Part(.polygon(pts), ramp, z: z, group: group, fixedTone: tone)
        }
        var parts = [flame(1, .body, 0, 0), flame(0.68, .secondary, 0.1, 1), flame(0.38, .white, 0.2, 2, tone: .light)]
        for k in 0..<3 {
            let e = c + V2(Double(k - 1) * 5 + f * 2, 12 + Double(k) * 3 + (t * 8).truncatingRemainder(dividingBy: 6))
            parts.append(Part(.ellipse(c: e, r: V2(0.9, 0.9), angle: 0), .secondary, z: 0.3, group: 3 + k, innerOutline: false,
                              fixedTone: .light))
        }
        let decals = [face(attack ? ["kk..", ".kkk", ".kkk"] : [".kk", "kWk", "kkk"], c + V2(-3, -1.5)),
                      face(attack ? ["..kk", "kkk.", "kkk."] : ["kk.", "kWk", "kkk"], c + V2(3, -1.5)),
                      face(attack ? ["kkkk", "k..k"] : ["k..k", ".kk."], c + V2(0, -5.5))]
        return Rig.render(parts, decals: decals, size: 64, scale: 2)
    }

    // MARK: Ogre

    private static func ogre(_ t: Double, _ attack: Bool, _ i: Int) -> PixelSprite {
        let s = sin(t * 2 * .pi)
        let stride = attack ? 0 : s
        let bob = attack ? 0 : (1 - abs(s)) * 1.2
        let swing: Double = attack ? [1.2, 2.2, 2.6, 0.4, -0.6, 0.4][i] : 1.0 + 0.1 * s
        let lean: Double = attack ? [0, -0.08, -0.12, 0.12, 0.18, 0.05][i] : 0.03
        let hipY = 16 + bob
        let body = V2(30, hipY + 9)
        var parts: [Part] = []
        for near in [true, false] {
            let hip = V2(body.x + (near ? 3.5 : -3.5), hipY)
            let foot = V2(hip.x + stride * (near ? 4 : -4), 3.5)
            let knee = (hip + foot) / 2 + V2(1.5, 0)
            let z = near ? 1.0 : -1.0, g = near ? 3 : 4, bias = near ? 0 : 1
            parts.append(Part(.capsule(a: hip, b: knee, ra: 4.2, rb: 3.4), .body, z: z, group: g, toneBias: bias))
            parts.append(Part(.capsule(a: knee, b: foot, ra: 3.4, rb: 3), .body, z: z + 0.01, group: g + 10, toneBias: bias))
            parts.append(Part(.ellipse(c: foot + V2(2.2, -1), r: V2(5, 2.6), angle: 0), .body, z: z + 0.02, group: g + 20,
                              toneBias: bias))
            for k in 0..<3 {
                parts.append(Part(.ellipse(c: foot + V2(4.5 + Double(k) * 1.4, -2.2), r: V2(0.7, 0.6), angle: 0), .white,
                                  z: z + 0.03, group: g + 20, innerOutline: false))
            }
        }
        parts.append(Part(.ellipse(c: body, r: V2(11.5, 11), angle: lean), .body, z: 0, group: 0))
        parts.append(Part(.ellipse(c: body + V2(2.5, -1.5), r: V2(7.5, 7.5), angle: 0), .body, z: 0.05, group: 0, innerOutline: false,
                          fixedTone: .light))
        parts.append(Part(.polygon([body + V2(-10.5, -5), body + V2(10.5, -5), body + V2(8, -13), body + V2(1, -10.5),
                                    body + V2(-8, -13)]), .secondary, z: 0.5, group: 5))
        parts.append(Part(.polygon([body + V2(-11, -3.6), body + V2(11, -3.6), body + V2(11, -6.2), body + V2(-11, -6.2)]),
                          .wood, z: 0.6, group: 6))
        parts.append(Part(.polygon([body + V2(1.5, -3.2), body + V2(5, -3.2), body + V2(5, -6.6), body + V2(1.5, -6.6)]),
                          .gold, z: 0.7, group: 7))
        let head = body + rotate(V2(4, 13.5), by: lean) + V2(attack ? lean * 10 : 0, 0)
        parts.append(Part(.ellipse(c: head + V2(-6.5, 0.5), r: V2(2, 2.6), angle: 0), .body, z: 0.9, group: 8, toneBias: 1))
        parts.append(Part(.ellipse(c: head, r: V2(7.5, 7.2), angle: 0), .body, z: 1, group: 1))
        parts.append(Part(.ellipse(c: head + V2(1.5, 3), r: V2(6.5, 1.8), angle: -0.1), .body, z: 1.05, group: 1, toneBias: 1))
        parts.append(Part(.ellipse(c: head + V2(5.5, 0), r: V2(2.4, 2), angle: 0), .body, z: 1.15, group: 9))
        parts.append(Part(.polygon([head + V2(-3, 6.5), head + V2(-1, 9.5), head + V2(1, 6.8), head + V2(2.5, 9), head + V2(3, 6.5)]),
                          .dark, z: 1.2, group: 10))
        parts.append(Part(.polygon([head + V2(2.5, -4), head + V2(4.5, -4), head + V2(3, 0)]), .white, z: 1.2, group: 11))
        parts.append(Part(.polygon([head + V2(6, -4), head + V2(8, -4), head + V2(7.2, -0.5)]), .white, z: 1.2, group: 12))
        let shoulderFar = body + rotate(V2(-7.5, 6), by: lean)
        let elbowFar = shoulderFar + V2(-2.5 - stride, -6)
        parts.append(Part(.capsule(a: shoulderFar, b: elbowFar, ra: 3.4, rb: 3), .body, z: -0.5, group: 13, toneBias: 1))
        parts.append(Part(.capsule(a: elbowFar, b: elbowFar + V2(0.5, -5), ra: 3, rb: 2.8), .body, z: -0.5, group: 13, toneBias: 1))
        let shoulder = body + rotate(V2(7.5, 6), by: lean)
        let elbow = shoulder + rotate(V2(0, -6), by: swing * 0.6)
        let hand = elbow + rotate(V2(0, -5), by: swing * 0.9)
        parts.append(Part(.capsule(a: shoulder, b: elbow, ra: 3.6, rb: 3.1), .body, z: 2, group: 14))
        parts.append(Part(.capsule(a: elbow, b: hand, ra: 3.1, rb: 2.8), .body, z: 2.01, group: 15))
        parts.append(Part(.ellipse(c: hand, r: V2(3, 3), angle: 0), .body, z: 2.02, group: 16))
        let clubEnd = hand + rotate(V2(0, 16), by: swing)
        let clubZ = swing > 1.5 ? -0.8 : 2.1
        parts.append(Part(.capsule(a: hand, b: clubEnd, ra: 1.6, rb: 3.8), .wood, z: clubZ, group: 17))
        for k in 0..<3 {
            let at = hand + rotate(V2(Double(k % 2 == 0 ? 3.2 : -3.2), 9 + Double(k) * 3), by: swing)
            parts.append(Part(.polygon([at, at + rotate(V2(k % 2 == 0 ? 2 : -2, 0.8), by: swing), at + rotate(V2(0, 1.6), by: swing)]),
                              .stone, z: clubZ + 0.01, group: 17))
        }
        let decals = [face(angryEye, head + V2(1, 1.6)), face(angryEyeR, head + V2(6, 1.8)),
                      face(attack && i >= 2 ? ["kkkkk", "k...k"] : ["kkkk"], head + V2(4.5, -3))]
        return Rig.render(parts, decals: decals, size: 128, scale: 2)
    }

    // MARK: Golem

    private static func golem(_ t: Double, _ attack: Bool, _ i: Int) -> PixelSprite {
        let s = sin(t * 2 * .pi)
        let stride = attack ? 0 : s
        let bob = attack ? 0 : (1 - abs(s)) * 1.5
        let raise: Double = attack ? [0.3, 1.0, 1.3, -0.2, -0.6, 0][i] : 0
        let c = V2(31, 24 + bob)
        var parts: [Part] = []
        func rock(_ center: V2, _ r: Double, _ seed: Int, z: Double, group: Int, bias: Int = 0, moss: Bool = false) {
            let pts = (0..<7).map { k -> V2 in
                let a = Double(k) / 7 * 2 * .pi + Double(seed)
                let rr = r * (0.82 + 0.3 * hash01(seed, k, 9))
                return center + V2(cos(a) * rr, sin(a) * rr * 0.9)
            }
            parts.append(Part(.polygon(pts), .body, z: z, group: group, toneBias: bias))
            if moss {
                parts.append(Part(.polygon([pts[1], pts[2], pts[3], center + V2(0, r * 0.35)]), .secondary, z: z + 0.01,
                                  group: group, innerOutline: false))
            }
        }
        for near in [true, false] {
            let x = c.x + (near ? 5 : -5) + stride * (near ? 3 : -3)
            rock(V2(x, 6), 5.5, near ? 3 : 4, z: near ? 1 : -1, group: near ? 3 : 4, bias: near ? 0 : 1)
            rock(V2(x - 0.5, 13), 5, near ? 5 : 6, z: near ? 0.9 : -1.1, group: near ? 13 : 14, bias: near ? 0 : 1)
        }
        rock(c + V2(0, 6), 13, 1, z: 0, group: 0, moss: true)
        rock(c + V2(1, -3), 9, 2, z: 0.05, group: 20)
        let head = c + V2(3, 19)
        rock(head, 6.5, 7, z: 1, group: 1, moss: true)
        for near in [false, true] {
            let shoulder = c + V2(near ? 11 : -11, 11)
            let hand = shoulder + V2(near ? 3 : -3, -12 + raise * 14)
            rock(shoulder, 6, near ? 8 : 9, z: near ? 2 : -0.5, group: near ? 15 : 16, bias: near ? 0 : 1, moss: near)
            rock((shoulder + hand) / 2, 5, near ? 10 : 11, z: near ? 2.1 : -0.6, group: near ? 17 : 18, bias: near ? 0 : 1)
            rock(hand, 6.5, near ? 12 : 13, z: near ? 2.2 : -0.7, group: near ? 19 : 21, bias: near ? 0 : 1)
        }
        let glow = attack && i >= 1 && i <= 3
        let decals = [face(glow ? ["YYY", "YWY", "YYY"] : ["yYy", "YWY"], head + V2(0, 1)),
                      face(glow ? ["YYY", "YWY", "YYY"] : ["yYy", "YWY"], head + V2(4, 1.2)),
                      face(["k.k.k", ".k.k."], c + V2(-3, 9)),
                      face(["k..", ".k.", ".kk"], c + V2(5, 2))]
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

    /// Food: a little red apple with a leaf, so it reads as food at a glance.
    static func pellet() -> PixelSprite {
        Rig.render([Part(.ellipse(c: V2(16, 4.6), r: V2(4.2, 3.8), angle: 0), .red, z: 0, group: 0),
                    Part(.ellipse(c: V2(14.6, 5.8), r: V2(1, 1.2), angle: 0.3), .white, z: 0.1, group: 0, innerOutline: false,
                         fixedTone: .light),
                    Part(.capsule(a: V2(16, 8), b: V2(16.6, 10.2), ra: 0.45, rb: 0.4), .wood, z: 0.2, group: 1),
                    Part(.ellipse(c: V2(18, 9.6), r: V2(1.7, 0.8), angle: 0.4), .green, z: 0.3, group: 2)],
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

    /// A treasure sack: tied neck, gold coins spilling out, and a coin on the ground.
    static func bag() -> PixelSprite {
        let parts = [
            Part(.ellipse(c: V2(16, 7.5), r: V2(7.5, 6.5), angle: 0), .body, z: 0, group: 0),
            Part(.polygon([V2(13, 12), V2(19, 12), V2(21.5, 16.5), V2(10.5, 16.5)]), .body, z: -0.1, group: 1),
            Part(.capsule(a: V2(12.5, 12.8), b: V2(19.5, 12.8), ra: 1.1, rb: 1.1), .secondary, z: 1, group: 2),
            Part(.ellipse(c: V2(14, 17), r: V2(2.2, 1.4), angle: 0.2), .gold, z: 0.5, group: 3),
            Part(.ellipse(c: V2(17.5, 17.6), r: V2(2.2, 1.4), angle: -0.3), .gold, z: 0.6, group: 4),
            Part(.ellipse(c: V2(25, 1.6), r: V2(2.2, 1.2), angle: 0), .gold, z: 0.6, group: 5),
        ]
        let decals = [Decal(sprite: PixelSprite(stamp: ["dD", "Dd"]), at: V2(13.5, 7.5)),
                      Decal(sprite: PixelSprite(stamp: ["Y"]), at: V2(13.5, 17.2)), Decal(sprite: PixelSprite(stamp: ["Y"]), at: V2(17, 17.8))]
        return Rig.render(parts, decals: decals, size: 64, scale: 2)
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

    static let impactFrames = 4

    /// A hit: a white-hot star that bursts and breaks up.
    static func impact(_ i: Int) -> PixelSprite {
        let t = Double(i) / Double(impactFrames - 1)
        let c = V2(16, 16)
        let outer = 5 + t * 8, inner = 1.5 + t * 2.5
        let star = (0..<12).map { k -> V2 in
            let a = Double(k) / 12 * 2 * .pi + t * 0.4
            return c + V2(cos(a), sin(a)) * (k % 2 == 0 ? outer : inner)
        }
        var parts = [Part(.polygon(star), .gold, z: 0, group: 0, fixedTone: i == 0 ? .light : .base)]
        if i < 2 { parts.append(Part(.ellipse(c: c, r: V2(inner, inner) * 1.1, angle: 0), .white, z: 1, group: 1, fixedTone: .light)) }
        var sprite = Rig.render(parts, size: 64, scale: 2)
        if t > 0.5 {
            for y in 0..<64 { for x in 0..<64 where hash01(x / 2, y / 2, i + 40) < (t - 0.4) * 1.1 { sprite[x, y] = Ink.clear } }
        }
        return sprite
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
        case .mysteryEgg:
            return [Part(.ellipse(c: V2(16, 15), r: V2(9.5, 12), angle: 0), .white, z: 0, group: 0),
                    Part(.ellipse(c: V2(12, 18), r: V2(2.4, 2), angle: 0.3), .green, z: 0.1, group: 0, innerOutline: false),
                    Part(.ellipse(c: V2(20, 12), r: V2(2, 1.7), angle: 0), .green, z: 0.1, group: 0, innerOutline: false),
                    Part(.ellipse(c: V2(17, 22), r: V2(1.6, 1.4), angle: 0), .green, z: 0.1, group: 0, innerOutline: false)]
        case .shinyEgg:
            return [Part(.ellipse(c: V2(16, 15), r: V2(9.5, 12), angle: 0), .gold, z: 0, group: 0),
                    Part(.ellipse(c: V2(12, 17), r: V2(2.4, 2), angle: 0.3), .purple, z: 0.1, group: 0, innerOutline: false),
                    Part(.ellipse(c: V2(20, 11), r: V2(2, 1.7), angle: 0), .purple, z: 0.1, group: 0, innerOutline: false),
                    Part(.ellipse(c: V2(12, 21), r: V2(1.5, 2.6), angle: 0.4), .white, z: 0.2, group: 0, innerOutline: false, fixedTone: .light)]
        case .warHorn:
            return [Part(.capsule(a: V2(7, 21), b: V2(15, 14), ra: 6, rb: 4), .white, z: 0, group: 0),
                    Part(.capsule(a: V2(15, 14), b: V2(21, 8), ra: 4, rb: 2.6), .white, z: 0.1, group: 1, toneBias: 1),
                    Part(.capsule(a: V2(21, 8), b: V2(26, 6), ra: 2.6, rb: 1.2), .white, z: 0.2, group: 2, toneBias: 1),
                    Part(.ellipse(c: V2(6, 22), r: V2(4.2, 4.2), angle: 0), .dark, z: 0.3, group: 3),
                    Part(.capsule(a: V2(13, 11), b: V2(17, 17), ra: 1.1, rb: 1.1), .gold, z: 0.4, group: 4, innerOutline: false),
                    Part(.capsule(a: V2(19, 6), b: V2(22, 10), ra: 0.9, rb: 0.9), .gold, z: 0.4, group: 5, innerOutline: false)]
        case .timelessAmber:
            return [Part(.polygon([V2(16, 3), V2(26, 9), V2(26, 21), V2(16, 28), V2(6, 21), V2(6, 9)]), .gold, z: 0, group: 0),
                    Part(.ellipse(c: V2(16, 15), r: V2(3, 4.5), angle: 0.5), .wood, z: 0.1, group: 1, fixedTone: .shade),
                    Part(.capsule(a: V2(10, 20), b: V2(12, 10), ra: 1.1, rb: 0.8), .white, z: 0.2, group: 2, innerOutline: false, fixedTone: .light)]
        default:
            return []
        }
    }

    private static func decals(_ item: Item) -> [Decal] {
        switch item {
        case .snack: return [Decal(sprite: PixelSprite(stamp: ["e.e", "...", ".e."]), at: V2(16, 15), upscale: false)]
        case .luckyClover: return [Decal(sprite: PixelSprite(stamp: ["Y"]), at: V2(16, 18), upscale: false)]
        case .shinyEgg: return [Decal(sprite: PixelSprite(stamp: [".W.", "WWW", ".W."]), at: V2(24, 24), upscale: false)]
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
