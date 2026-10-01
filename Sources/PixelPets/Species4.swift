import Foundation

// Wave 4 species: seal, redPanda, lion, chameleon, pangolin, fruitBat, peacock, kitsune, griffin, pegasus.
// The side rigs reuse the four-legged frame in Species.swift. The front and back views are custom (built on
// `w4Front`), because manes, fans, wings and a fistful of tails are beyond the shared profile.

extension SpeciesRig {
    /// Side rigs for this wave. Returns nil for any other shape.
    static func buildWave4(_ shape: BodyShape, pose: Pose) -> Built? {
        switch shape {
        case .seal: return w4Seal(pose)
        case .redPanda: return w4RedPanda(pose)
        case .lion: return w4Lion(pose)
        case .chameleon: return w4Chameleon(pose)
        case .pangolin: return w4Pangolin(pose)
        case .fruitBat: return w4FruitBat(pose)
        case .peacock: return w4Peacock(pose)
        case .kitsune: return w4Kitsune(pose)
        case .griffin: return w4Griffin(pose)
        case .pegasus: return w4Pegasus(pose)
        default: return nil
        }
    }

    /// Fully custom front or back views, for animals the shared FrontProfile can't express.
    /// Returns nil to use the profile from `FrontProfile.wave4`.
    static func frontalWave4(_ shape: BodyShape, pose: Pose, back: Bool) -> Built? {
        switch shape {
        case .seal: return w4SealFront(pose, back: back)
        case .redPanda: return w4RedPandaFront(pose, back: back)
        case .lion: return w4LionFront(pose, back: back)
        case .chameleon: return w4ChameleonFront(pose, back: back)
        case .pangolin: return w4PangolinFront(pose, back: back)
        case .fruitBat: return w4FruitBatFront(pose, back: back)
        case .peacock: return w4PeacockFront(pose, back: back)
        case .kitsune: return w4KitsuneFront(pose, back: back)
        case .griffin: return w4GriffinFront(pose, back: back)
        case .pegasus: return w4PegasusFront(pose, back: back)
        default: return nil
        }
    }
}

extension FrontProfile {
    /// Front and back profiles for this wave. Every wave-4 animal has a custom front in `frontalWave4`.
    static func wave4(_ shape: BodyShape) -> FrontProfile? {
        nil
    }
}

// MARK: - Shared helpers

/// A head-on four-legged body: what the front and back views of this wave start from.
private struct W4FrontSpec {
    var bodyR = V2(6, 5.2)
    var headR = 5.0
    var headY = 6.0
    var legLen = 4.5
    var legR = (1.7, 1.4)
    var legGap = 2.8
    var legRamp = Ramp.body
    var chest: Ramp? = .secondary
}

private struct W4Front {
    var built = Built()
    var c = V2.zero
    var r = V2.zero
    var faceZ = 1.0
    var back = false
}

private func w4Clamp(_ x: Double) -> Double { max(0, min(1, x)) }

private func w4Mix(_ a: Double, _ b: Double, _ t: Double) -> Double { a + (b - a) * t }

extension SpeciesRig {
    /// Torso, chest, legs and head seen from the front (or the back, with the face hidden behind the body).
    fileprivate static func w4Front(_ s: W4FrontSpec, _ pose: Pose, back: Bool) -> W4Front {
        var f = W4Front()
        f.back = back
        f.faceZ = back ? -0.5 : 1
        let angle = pose.sway
        let legLen = s.legLen * (1 + 0.2 * pose.dangle) * (1 - 0.7 * pose.lying)
        let r = V2(s.bodyR.x / pose.squash.squareRoot(), s.bodyR.y * pose.squash)
        let c = V2(16, ground + legLen + r.y * 0.72 + pose.bob + pose.lift)
        f.c = c
        f.r = r
        var b = Built()
        b.parts.append(Part(.ellipse(c: c, r: r, angle: angle), .body, z: 0, group: 0, patterned: true, role: .torso))
        if !back, let chest = s.chest {
            b.parts.append(Part(.ellipse(c: c + V2(0, -r.y * 0.3), r: V2(r.x * 0.5, r.y * 0.55), angle: angle), chest, z: 0.1, group: 0))
        }
        for side in [-1.0, 1.0] {
            let hip = c + rotate(V2(side * s.legGap, -r.y * 0.5), by: angle)
            var foot = V2(hip.x + side * 0.3, ground + s.legR.1 + pose.lift + max(0, pose.stride * side) * 1.2)
            if pose.dangle > 0 { foot = hip + V2(side * 0.5 + sin(pose.sway * 3) * 0.6, -legLen * 1.1) }
            if pose.paw > 0 && side > 0 { foot = hip + V2(2, -legLen * 0.2 + pose.paw * 2.5) }
            if pose.lying > 0 { foot = V2(hip.x + side * 0.6, ground + s.legR.1) }
            b.parts.append(Part(.capsule(a: hip, b: foot, ra: s.legR.0, rb: s.legR.1), s.legRamp, z: back ? -0.1 : 2,
                                group: side < 0 ? 3 : 4, patterned: s.legRamp == .body, role: .limb))
            let hind = c + rotate(V2(side * (s.legGap + 2), -r.y * 0.4), by: angle)
            b.parts.append(Part(.capsule(a: hind, b: V2(hind.x + side * 0.8, ground + s.legR.1 + pose.lift), ra: s.legR.0, rb: s.legR.1),
                                s.legRamp, z: back ? 2 : -1, group: side < 0 ? 5 : 8, patterned: s.legRamp == .body,
                                toneBias: back ? 0 : 1, role: .limb))
        }
        b.headC = c + rotate(V2(0, s.headY), by: angle) + V2(0, -pose.headDip - pose.lying * 2)
        b.headR = s.headR
        b.headAngle = angle * 0.6 + pose.headTilt
        b.headZ = f.faceZ
        b.parts.append(Part(.ellipse(c: b.headC, r: V2(s.headR * 1.06, s.headR), angle: b.headAngle), .body, z: f.faceZ, group: 1,
                            patterned: true, role: .head))
        b.eyeX = (0.42, 0)
        b.eyeY = 0.12
        f.built = b
        return f
    }

    /// A feathered wing from `root`: an arm along `angle` with long primaries at the wrist and shorter feathers
    /// towards the shoulder, all turned away from the arm by up to `fan` (`turn` picks the side). Folded, the
    /// feathers lie along the arm; spread, they fan out behind it. Uses groups `group - count + 1 ... group + 1`.
    fileprivate static func w4Wing(root: V2, angle: Double, fan: Double, turn: Double = 1, length: Double, count: Int = 6,
                                   ramp: Ramp = .white, covert: Ramp = .white, z: Double, group: Int, bias: Int) -> [Part] {
        var parts: [Part] = []
        let arm = V2(cos(angle), sin(angle)) * length * 0.45
        let wrist = root + arm
        for i in 0..<count {
            let f = Double(i) / Double(count - 1)
            let origin = wrist - arm * (f * 0.8)
            let a = angle + turn * (0.12 + fan * f)
            let tip = origin + V2(cos(a), sin(a)) * (length * (0.62 - 0.27 * f))
            parts.append(Part(.capsule(a: origin, b: tip, ra: 1.0, rb: 1.4), ramp, z: z + Double(i) * 0.01, group: group - i,
                              toneBias: bias, role: .extremity))
        }
        // Coverts along the arm.
        parts.append(Part(.capsule(a: root, b: wrist, ra: 2.3, rb: 1.5), covert, z: z + 0.1, group: group + 1, toneBias: bias))
        return parts
    }

    /// A small floating flame with a pale core that flickers with `flicker` (-1...1).
    fileprivate static func w4Wisp(_ at: V2, size: Double, flicker: Double, ramp: Ramp, z: Double, group: Int) -> [Part] {
        [Part(.polygon([at + V2(-size, 0.2), at + V2(size, 0.2), at + V2(flicker * size * 0.8, size * 2.8)]), ramp, z: z, group: group,
              fixedTone: .base),
         Part(.ellipse(c: at, r: V2(size, size), angle: 0), ramp, z: z, group: group, fixedTone: .base),
         Part(.ellipse(c: at + V2(0, 0.2), r: V2(size * 0.5, size * 0.6), angle: 0), .white, z: z + 0.01, group: group,
              innerOutline: false, fixedTone: .light)]
    }

    /// A peacock's eye-spot: gold ring, blue iris and a dark pupil.
    fileprivate static func w4EyeSpot(_ at: V2, size: Double, angle: Double, z: Double, group: Int) -> [Part] {
        [Part(.ellipse(c: at, r: V2(size, size * 0.85), angle: angle), .gold, z: z, group: group, innerOutline: false),
         Part(.ellipse(c: at, r: V2(size * 0.62, size * 0.55), angle: angle), .blue, z: z + 0.001, group: group, innerOutline: false),
         Part(.ellipse(c: at, r: V2(size * 0.3, size * 0.28), angle: angle), .dark, z: z + 0.002, group: group, innerOutline: false)]
    }

    /// A tufted cat tail: a thin chain ending in a ball of `tuft`.
    fileprivate static func w4TuftTail(from base: V2, angle: Double, curl: Double, tuft: Ramp, z: Double) -> [Part] {
        var parts = tail(from: base, angle: angle, curl: curl, segments: 4, length: 2.6, radius: (0.95, 0.7), ramp: .body, z: z)
        if case let .capsule(_, tip, _, _) = parts.last!.shape {
            parts.append(Part(.ellipse(c: tip, r: V2(1.7, 1.7), angle: 0), tuft, z: z + 0.01, group: 5, role: .extremity))
        }
        return parts
    }

    /// Gold hooves over the ends of the legs.
    fileprivate static func w4Hooves(_ parts: [Part]) -> [Part] {
        parts.compactMap { part -> Part? in
            guard part.role == .limb, case let .capsule(_, f, _, rb) = part.shape else { return nil }
            return Part(.ellipse(c: f, r: V2(rb * 1.25, rb * 1.05), angle: 0), .gold, z: part.z + 0.01, group: part.group,
                        toneBias: part.toneBias)
        }
    }
}

// MARK: - Seal

extension SpeciesRig {
    fileprivate static func w4Seal(_ pose: Pose) -> Built {
        var b = Built()
        let squash = pose.squash * (1 - 0.08 * pose.lying)
        let r = V2(9.2 / squash.squareRoot(), 5.2 * squash)
        // No legs: the whole body rocks as the flippers shuffle it along.
        let angle = 0.1 + pose.lean + pose.sway + pose.stride * 0.07 - pose.lying * 0.1 + pose.dangle * 0.45
        let c = V2(13.5 + pose.lunge * 0.6, ground + r.y + 0.6 + pose.bob * 0.6 + pose.lift + pose.dangle * 2)
        func at(_ v: V2) -> V2 { c + rotate(v, by: angle) }
        b.parts.append(Part(.ellipse(c: c, r: r, angle: angle), .body, z: 0, group: 0, patterned: true, role: .torso))
        b.parts.append(Part(.ellipse(c: at(V2(1.5, -r.y * 0.5)), r: V2(r.x * 0.62, r.y * 0.42), angle: angle), .secondary,
                            z: 0.1, group: 0))
        // Tapering hind end with two tail flippers.
        let hip = at(V2(-r.x * 0.55, -0.4))
        let end = at(V2(-r.x - 2.2, -1.6)) + V2(0, pose.tail * 0.4)
        b.parts.append(Part(.capsule(a: hip, b: end, ra: r.y * 0.8, rb: 1.3), .body, z: -0.1, group: 0, patterned: true, role: .torso))
        for near in [false, true] {
            let up = near ? -0.6 : 0.8
            b.parts.append(Part(.polygon([end + V2(0.8, 0.3), end + V2(-3.2, 1.6 + up), end + V2(-3.4, -0.9 + up)]), .body,
                                z: near ? 0.2 : -0.3, group: near ? 7 : 8, patterned: true, toneBias: near ? 0 : 1, role: .extremity))
        }
        // Front flippers paddle with the stride.
        for near in [true, false] {
            let shoulder = at(V2(3.4 - (near ? 0 : 1.4), -r.y * 0.4))
            var a = -1.15 + pose.stride * (near ? 0.5 : -0.5)
            if pose.paw > 0 && near { a = -1.15 + pose.paw * 1.9 }
            if pose.dangle > 0 { a = -1.7 + pose.sway * 2 }
            if pose.lying > 0 { a = -0.25 }
            let dir = V2(cos(a), sin(a))
            b.parts.append(Part(.ellipse(c: shoulder + dir * 2, r: V2(3, 1.3), angle: a), .body, z: near ? 1.5 : -1,
                                group: near ? 3 : 4, patterned: true, toneBias: near ? 0 : 1, role: .limb))
        }
        // Round head with a whiskered muzzle.
        b.headC = at(V2(r.x * 0.74, r.y * 0.85)) + V2(pose.headDip * 0.5 + pose.lying * 0.8, -pose.headDip - pose.lying * 1.8)
        b.headR = 5
        b.headAngle = angle * 0.4 + pose.headTilt - pose.lying * 0.1
        b.parts.append(Part(.ellipse(c: b.headC, r: V2(5.2, 5), angle: b.headAngle), .body, z: 1, group: 1, patterned: true,
                            role: .head))
        b.parts.append(Part(.ellipse(c: b.onHead(V2(0.8, -0.42)), r: V2(2.2, 1.8), angle: b.headAngle), .secondary, z: 1.1, group: 1))
        b.parts.append(Part(.ellipse(c: b.onHead(V2(1.22, -0.12)), r: V2(0.75, 0.6), angle: 0), .dark, z: 1.2, group: 1))
        for dy in [0.7, 0.0, -0.7] {
            let root = b.onHead(V2(1.05, -0.48))
            b.parts.append(Part(.capsule(a: root, b: root + V2(2, dy), ra: 0.3, rb: 0.25), .white, z: 1.25, group: 22,
                                innerOutline: false))
        }
        b.eyeX = (0.3, 0.72)
        b.eyeY = 0.22
        b.mouth = V2(0.95, -0.75)
        b.cheek = V2(0.3, -0.3)
        return b
    }

    fileprivate static func w4SealFront(_ pose: Pose, back: Bool) -> Built {
        var b = Built()
        let faceZ: Double = back ? -0.5 : 1
        let r = V2(6.6 / pose.squash.squareRoot(), 5.6 * pose.squash)
        let angle = pose.sway
        let c = V2(16, ground + r.y + 1 + pose.bob * 0.6 + pose.lift + pose.dangle * 2 - pose.lying * 0.8)
        b.parts.append(Part(.ellipse(c: c, r: r, angle: angle), .body, z: 0, group: 0, patterned: true, role: .torso))
        if !back {
            b.parts.append(Part(.ellipse(c: c + V2(0, -r.y * 0.3), r: V2(r.x * 0.55, r.y * 0.55), angle: angle), .secondary,
                                z: 0.1, group: 0))
        }
        let flap = max(0, pose.wing) * 0.6 + pose.paw + pose.dangle * 0.7
        for s in [-1.0, 1.0] {
            // Tail flippers splay out at the bottom.
            let feetY = pose.dangle > 0 ? c.y - r.y - 0.4 : ground + 1 + pose.lift
            b.parts.append(Part(.ellipse(c: V2(16 + s * 3.6, feetY), r: V2(3, 1.2), angle: s * -0.2), .body, z: back ? 0.3 : -0.3,
                                group: s < 0 ? 3 : 4, patterned: true, toneBias: back ? 0 : 1, role: .limb))
            b.parts.append(Part(.ellipse(c: c + V2(s * (r.x - 0.3), -1 + flap * 1.5), r: V2(1.5, 3.6), angle: s * (0.45 + flap * 0.6)),
                                .body, z: 0.5, group: s < 0 ? 9 : 10, patterned: true, role: .limb))
        }
        b.headC = c + rotate(V2(0, r.y * 0.95), by: angle) + V2(0, -pose.headDip - pose.lying * 1.5)
        b.headR = 4.8
        b.headAngle = angle * 0.6 + pose.headTilt
        b.headZ = faceZ
        b.parts.append(Part(.ellipse(c: b.headC, r: V2(5.1, 4.8), angle: b.headAngle), .body, z: faceZ, group: 1, patterned: true,
                            role: .head))
        if !back {
            b.parts.append(Part(.ellipse(c: b.onHead(V2(0, -0.45)), r: V2(2.6, 1.7), angle: b.headAngle), .secondary, z: faceZ + 0.1,
                                group: 1))
            b.parts.append(Part(.ellipse(c: b.onHead(V2(0, -0.2)), r: V2(0.9, 0.6), angle: 0), .dark, z: faceZ + 0.2, group: 1))
            for s in [-1.0, 1.0] {
                for dy in [0.6, -0.4] {
                    let root = b.onHead(V2(s * 0.45, -0.5))
                    b.parts.append(Part(.capsule(a: root, b: root + V2(s * 3, dy), ra: 0.3, rb: 0.25), .white, z: faceZ + 0.25,
                                        group: 22, innerOutline: false))
                }
            }
        }
        b.eyeX = (0.42, 0)
        b.eyeY = 0.15
        return b
    }
}

// MARK: - Red panda

extension SpeciesRig {
    fileprivate static func w4RedPanda(_ pose: Pose) -> Built {
        var spec = QuadSpec()
        spec.bodyR = V2(7.4, 5.2)
        spec.bodyX = 15.5
        spec.legLen = 3.6
        spec.legR = (1.6, 1.35)
        spec.headR = 4.9
        spec.headOffset = V2(7.2, 4.8)
        spec.bellyR = V2(3.4, 1.6)
        let q = quadruped(spec, pose)
        var b = q.built
        // Dark legs and belly.
        b.parts[1].ramp = .dark
        b.parts = b.parts.map { part in
            var p = part
            if p.role == .limb { p.ramp = .dark; p.patterned = false }
            return p
        }
        // White-rimmed ears.
        for (pts, z, bias) in [([V2(-0.8, 0.5), V2(-0.1, 0.85), V2(-0.62, 1.5)], 0.9, 1),
                               ([V2(-0.05, 0.85), V2(0.62, 0.55), V2(0.36, 1.45)], 1.2, 0)] {
            b.parts.append(Part(headPolygon(b, pts), .white, z: z, group: 6, toneBias: bias, role: .extremity))
            let mid = (pts[0] + pts[1] + pts[2]) / 3
            b.parts.append(Part(headPolygon(b, pts.map { mid + ($0 - mid) * 0.55 + V2(0, -0.05) }), .body, z: z + 0.01, group: 6,
                                toneBias: bias + 1, innerOutline: false))
        }
        // The white face: muzzle, cheeks and eyebrows, split by a rusty tear stripe.
        b.parts.append(Part(headPolygon(b, [V2(0.3, 0.05), V2(1.55, -0.3), V2(1.45, -0.62), V2(0.3, -0.8)]), .white, z: 1.1, group: 1))
        b.parts.append(Part(.ellipse(c: b.onHead(V2(0.15, -0.45)), r: V2(2.1, 1.6), angle: 0), .white, z: 1.08, group: 1))
        b.parts.append(Part(.ellipse(c: b.onHead(V2(0.55, 0.62)), r: V2(1.2, 0.75), angle: 0.2), .white, z: 1.08, group: 1))
        b.parts.append(Part(.capsule(a: b.onHead(V2(0.62, -0.05)), b: b.onHead(V2(0.55, -0.7)), ra: 0.55, rb: 0.45), .body,
                            z: 1.12, group: 1))
        b.parts.append(Part(.ellipse(c: b.onHead(V2(1.5, -0.38)), r: V2(0.75, 0.65), angle: 0), .dark, z: 1.2, group: 1))
        // Big ringed bushy tail.
        let base = q.bodyC + rotate(V2(-q.bodyR.x * 0.85, q.bodyR.y * 0.15), by: q.angle)
        var a = 2.8 + pose.tail * 0.25 - pose.dangle * 1.1 - pose.lying * 0.9
        var p = base
        for k in 0..<5 {
            let next = p + rotate(V2(2.1, 0), by: a)
            let r = [2.2, 2.5, 2.5, 2.3, 1.9][k]
            b.parts.append(Part(.ellipse(c: (p + next) / 2, r: V2(1.8, r), angle: a), k % 2 == 0 ? .body : .secondary,
                                z: -1 - Double(k) * 0.01, group: -10 - k, patterned: k % 2 == 0, role: .extremity))
            p = next
            a -= 0.22
        }
        b.eyeX = (0.4, 0.8)
        b.eyeY = 0.18
        b.mouth = V2(1.15, -0.72)
        b.cheek = V2(0.15, -0.45)
        return b
    }

    fileprivate static func w4RedPandaFront(_ pose: Pose, back: Bool) -> Built {
        var s = W4FrontSpec()
        s.bodyR = V2(6, 5.2)
        s.headR = 5
        s.legLen = 3.6
        s.legR = (1.6, 1.35)
        s.legRamp = .dark
        s.chest = nil
        let f = w4Front(s, pose, back: back)
        var b = f.built
        let earZ = back ? 0.5 : f.faceZ - 0.1
        for side in [-1.0, 1.0] {
            let pts = [V2(side * 0.25, 0.85), V2(side * 0.9, 0.45), V2(side * 0.75, 1.5)]
            b.parts.append(Part(headPolygon(b, pts), .white, z: earZ, group: 6, role: .extremity))
            if !back {
                let mid = (pts[0] + pts[1] + pts[2]) / 3
                b.parts.append(Part(headPolygon(b, pts.map { mid + ($0 - mid) * 0.55 }), .body, z: earZ + 0.01, group: 6, toneBias: 1,
                                    innerOutline: false))
                // Eyebrow spots and white cheeks either side of the rusty tear stripes.
                b.parts.append(Part(.ellipse(c: b.onHead(V2(side * 0.42, 0.62)), r: V2(1.1, 0.7), angle: 0), .white, z: f.faceZ + 0.05,
                                    group: 1))
                b.parts.append(Part(.ellipse(c: b.onHead(V2(side * 0.68, -0.42)), r: V2(1.6, 1.4), angle: 0), .white, z: f.faceZ + 0.05,
                                    group: 1))
            }
        }
        if !back {
            b.parts.append(Part(.ellipse(c: b.onHead(V2(0, -0.48)), r: V2(2.2, 1.6), angle: b.headAngle), .white, z: f.faceZ + 0.1, group: 1))
            b.parts.append(Part(.ellipse(c: b.onHead(V2(0, -0.28)), r: V2(0.85, 0.6), angle: 0), .dark, z: f.faceZ + 0.2, group: 1))
        }
        // Ringed tail: peeking out from the front, curling up in full from the back.
        var tp = f.c + V2(back ? 0 : 3, f.r.y * 0.1)
        var a = (back ? 1.7 : 0.9) + pose.tail * 0.3
        for k in 0..<5 {
            let next = tp + rotate(V2(2.1, 0), by: a)
            b.parts.append(Part(.ellipse(c: (tp + next) / 2, r: V2(1.8, 2.4), angle: a), k % 2 == 0 ? .body : .secondary,
                                z: (back ? 1.5 : -1) + Double(k) * 0.01, group: -10 - k, patterned: k % 2 == 0))
            tp = next
            a += back ? 0.25 : 0.3
        }
        return b
    }
}

// MARK: - Lion

extension SpeciesRig {
    /// A spiky ring of mane around `c`.
    fileprivate static func w4Mane(_ c: V2, radius: Double, spikes: Int, wobble: Double, z: Double) -> Part {
        let pts = (0..<(spikes * 2)).map { k -> V2 in
            let a = Double(k) / Double(spikes * 2) * 2 * .pi + wobble
            let r = k % 2 == 0 ? radius : radius * 0.78
            return c + V2(cos(a), sin(a)) * r
        }
        return Part(.polygon(pts), .wood, z: z, group: 6, role: .extremity)
    }

    fileprivate static func w4Lion(_ pose: Pose) -> Built {
        var spec = QuadSpec()
        spec.bodyR = V2(8, 5.5)
        spec.bodyX = 13.8
        spec.legLen = 4.2
        spec.legR = (2, 1.7)
        spec.legX = (5, -5)
        spec.headR = 4.8
        spec.headOffset = V2(7.8, 5.6)
        spec.bellyR = V2(4.5, 2.2)
        let q = quadruped(spec, pose)
        var b = q.built
        // The mane frames the head and spills over the shoulders.
        let wobble = sin(pose.t * 2 * .pi) * 0.05
        b.parts.append(w4Mane(b.onHead(V2(-0.45, 0.05)), radius: 8.4, spikes: 10, wobble: wobble, z: 0.8))
        b.parts.append(Part(.polygon([b.onHead(V2(-0.6, 0.6)), b.onHead(V2(-1.5, -0.3)), q.bodyC + rotate(V2(3, 1), by: q.angle),
                                      q.bodyC + rotate(V2(5.5, -2.5), by: q.angle), b.onHead(V2(0.2, -1.2))]), .wood, z: 0.85, group: 6))
        // Round ears peeking over the mane.
        for (c, z, bias) in [(V2(-0.55, 0.85), 0.9, 1), (V2(0.1, 0.95), 1.05, 0)] {
            b.parts.append(Part(.ellipse(c: b.onHead(c), r: V2(1.5, 1.5), angle: 0), .body, z: z, group: 20, toneBias: bias,
                                role: .extremity))
        }
        b.parts.append(Part(.ellipse(c: b.onHead(V2(0.78, -0.4)), r: V2(2.5, 1.9), angle: b.headAngle), .secondary, z: 1.1, group: 1))
        b.parts.append(Part(headPolygon(b, [V2(1.05, -0.05), V2(1.45, -0.1), V2(1.3, -0.4)]), .dark, z: 1.2, group: 1))
        // Tufted tail.
        let base = q.bodyC + rotate(V2(-q.bodyR.x * 0.88, q.bodyR.y * 0.2), by: q.angle)
        b.parts += w4TuftTail(from: base, angle: 3.5 + pose.tail * 0.3 - pose.dangle * 1.2 - pose.lying * 0.3,
                              curl: -0.5 + pose.tail * 0.1 + pose.lying * 0.3, tuft: .wood, z: -1)
        b.eyeX = (0.28, 0.72)
        b.eyeY = 0.2
        b.mouth = V2(1.0, -0.62)
        b.topOverride = b.onHead(V2(-0.12, 1.25))
        return b
    }

    fileprivate static func w4LionFront(_ pose: Pose, back: Bool) -> Built {
        var s = W4FrontSpec()
        s.bodyR = V2(6.6, 5.6)
        s.headR = 4.8
        s.headY = 6.4
        s.legLen = 4.2
        s.legR = (2, 1.7)
        s.legGap = 3
        let f = w4Front(s, pose, back: back)
        var b = f.built
        let wobble = sin(pose.t * 2 * .pi) * 0.05
        // From the front the mane rings the face; from the back it covers the head.
        b.parts.append(w4Mane(b.headC + V2(0, -0.3), radius: 8.2, spikes: 11, wobble: wobble, z: back ? 1.2 : f.faceZ - 0.2))
        for side in [-1.0, 1.0] {
            b.parts.append(Part(.ellipse(c: b.onHead(V2(side * 0.78, 0.85)), r: V2(1.6, 1.6), angle: 0), .body,
                                z: back ? 1.25 : f.faceZ - 0.1, group: 20, role: .extremity))
        }
        if !back {
            b.parts.append(Part(.ellipse(c: b.onHead(V2(0, -0.45)), r: V2(2.8, 2.0), angle: b.headAngle), .secondary, z: f.faceZ + 0.1,
                                group: 1))
            b.parts.append(Part(headPolygon(b, [V2(-0.3, -0.12), V2(0.3, -0.12), V2(0, -0.42)]), .dark, z: f.faceZ + 0.2, group: 1))
        }
        let base = f.c + V2(back ? 0 : 3, -f.r.y * 0.1)
        b.parts += w4TuftTail(from: base, angle: back ? -1.2 + pose.tail * 0.3 : 0.9 + pose.tail * 0.3,
                              curl: back ? 0.5 : 0.35, tuft: .wood, z: back ? 1.5 : -1)
        b.topOverride = b.onHead(V2(0, 1.3))
        return b
    }
}

// MARK: - Chameleon

extension SpeciesRig {
    /// A tail that coils into a spiral, tighter towards the tip.
    fileprivate static func w4Spiral(from base: V2, angle start: Double, curl: Double, z: Double) -> [Part] {
        var parts: [Part] = []
        var p = base
        var a = start
        var len = 2.5
        let n = 9
        for i in 0..<n {
            let next = p + V2(cos(a), sin(a)) * len
            let r0 = 1.5 - Double(i) * 0.11, r1 = 1.5 - Double(i + 1) * 0.11
            parts.append(Part(.capsule(a: p, b: next, ra: r0, rb: r1), .body, z: z + Double(i) * 0.001, group: 5, patterned: true,
                              role: .extremity))
            p = next
            a += curl * (1 + Double(i) * 0.12)
            len *= 0.88
        }
        return parts
    }

    fileprivate static func w4Chameleon(_ pose: Pose) -> Built {
        var b = Built()
        let r = V2(6.8 / pose.squash.squareRoot(), 4.3 * pose.squash)
        let legLen = 3.4 * (1 - 0.75 * pose.lying) * (1 + 0.2 * pose.dangle)
        let angle = pose.lean + pose.sway
        let c = V2(13 + pose.lunge, ground + legLen + r.y * 0.85 + pose.bob * 0.6 + pose.lift)
        func at(_ v: V2) -> V2 { c + rotate(v, by: angle) }
        b.parts.append(Part(.ellipse(c: c, r: r, angle: angle), .body, z: 0, group: 0, patterned: true, role: .torso))
        // A zigzag crest along the spine, tucked behind the body so only the teeth show.
        var crest: [V2] = []
        for k in 0...12 {
            let a = 0.35 + Double(k) / 12 * 2.4
            let out = k % 2 == 0 ? 1.18 : 0.98
            crest.append(at(V2(cos(a) * r.x * out, sin(a) * r.y * out)))
        }
        crest.append(at(V2(-r.x * 0.5, 0)))
        crest.append(at(V2(r.x * 0.5, 0)))
        b.parts.append(Part(.polygon(crest), .body, z: -0.1, group: 0, toneBias: 1))
        // A pale stripe down the flank.
        b.parts.append(Part(.ellipse(c: at(V2(0.3, -0.8)), r: V2(r.x * 0.75, 1.0), angle: angle - 0.05), .secondary, z: 0.1, group: 0,
                            innerOutline: false))
        // Thin legs ending in pincer feet.
        for (x, front) in [(3.6, true), (-3.8, false)] {
            for near in [true, false] {
                let hip = at(V2(x - (near ? 0 : 1), -r.y * 0.4))
                let swing = pose.stride * (front ? 1 : -1) * (near ? 1 : -1)
                var foot = V2(hip.x + 0.8 + swing * 1.6, ground + 0.8 + pose.lift)
                if pose.dangle > 0 { foot = hip + V2(0.6, -legLen * 1.1) }
                if pose.lying > 0 { foot = V2(hip.x + 1.5, ground + 0.8) }
                let knee = (hip + foot) / 2 + V2(front ? -1 : 1, 0.3)
                let z = near ? 2.0 : -2.0
                let group = near ? 3 : 4
                b.parts.append(Part(.capsule(a: hip, b: knee, ra: 1.0, rb: 0.85), .body, z: z, group: group, patterned: true,
                                    toneBias: near ? 0 : 1, role: .limb))
                b.parts.append(Part(.capsule(a: knee, b: foot, ra: 0.85, rb: 0.75), .body, z: z, group: group, patterned: true,
                                    toneBias: near ? 0 : 1, role: .limb))
                for dx in [-0.75, 0.75] {
                    b.parts.append(Part(.ellipse(c: foot + V2(dx, -0.1), r: V2(0.9, 0.6), angle: dx * 0.5), .body, z: z + 0.01,
                                        group: group, toneBias: near ? 0 : 1))
                }
            }
        }
        // Spiral tail.
        let base = at(V2(-r.x * 0.9, 0.2))
        b.parts += w4Spiral(from: base, angle: 3.0 - pose.dangle * 0.8, curl: 0.5 + pose.tail * 0.08 - pose.dangle * 0.3, z: -1)
        // Head: pointed snout, a tall casque and a big turret eye.
        b.headC = at(V2(r.x * 0.95, 1.6)) + V2(pose.headDip * 0.5, -pose.headDip - pose.lying)
        b.headR = 4
        b.headAngle = angle * 0.5 + pose.headTilt - 0.05
        b.parts.append(Part(.ellipse(c: b.headC, r: V2(4.2, 3.7), angle: b.headAngle), .body, z: 1, group: 1, patterned: true, role: .head))
        b.parts.append(Part(headPolygon(b, [V2(0.2, 0.55), V2(1.5, -0.1), V2(1.35, -0.55), V2(0.2, -0.85)]), .body, z: 1.02, group: 1,
                            patterned: true))
        b.parts.append(Part(headPolygon(b, [V2(0.2, 0.75), V2(-0.4, 1.95), V2(-1.4, 0.9), V2(-0.9, 0.2)]), .body, z: 0.95, group: 6,
                            patterned: true, role: .extremity))
        b.parts.append(Part(.ellipse(c: b.onHead(V2(0.45, 0.15)), r: V2(2, 2), angle: 0), .body, z: 1.05, group: 26))
        b.parts.append(Part(.ring(c: b.onHead(V2(0.45, 0.15)), r: V2(1.55, 1.55), width: 0.55), .secondary, z: 1.06, group: 26,
                            innerOutline: false))
        // A long sticky tongue when it strikes.
        if pose.paw > 0.5 {
            let root = b.onHead(V2(1.3, -0.45))
            let tip = V2(min(root.x + 5 * pose.paw, 31), root.y - 0.6)
            b.parts.append(Part(.capsule(a: root, b: tip, ra: 0.4, rb: 0.4), .pink, z: 1.3, group: 22))
            b.parts.append(Part(.ellipse(c: tip, r: V2(1.1, 1.1), angle: 0), .pink, z: 1.31, group: 22))
        }
        b.eyeX = (0.3, 0.6)
        b.eyeY = 0.15
        b.mouth = V2(1.0, -0.5)
        b.cheek = V2(0.6, -0.5)
        b.topOverride = b.onHead(V2(-0.3, 1.6))
        return b
    }

    fileprivate static func w4ChameleonFront(_ pose: Pose, back: Bool) -> Built {
        var s = W4FrontSpec()
        s.bodyR = V2(4.6, 4.6)
        s.headR = 4.2
        s.headY = 4.6
        s.legLen = 3.4
        s.legR = (0.9, 0.8)
        s.legGap = 3.6
        let f = w4Front(s, pose, back: back)
        var b = f.built
        // Splay the legs outwards like a lizard's.
        b.parts = b.parts.map { part in
            var p = part
            if p.role == .limb, case let .capsule(a, foot, ra, rb) = p.shape {
                let side: Double = foot.x < 16 ? -1 : 1
                p.shape = .capsule(a: a, b: foot + V2(side * 1.6, 0), ra: ra, rb: rb)
            }
            return p
        }
        // Casque and the two turret eyes on the sides of the head.
        b.parts.append(Part(headPolygon(b, [V2(-0.55, 0.6), V2(0.55, 0.6), V2(0, 1.75)]), .body, z: back ? f.faceZ + 0.05 : f.faceZ - 0.1,
                            group: 6, patterned: true, role: .extremity))
        if !back {
            for side in [-1.0, 1.0] {
                b.parts.append(Part(.ellipse(c: b.onHead(V2(side * 0.62, 0.12)), r: V2(1.9, 1.9), angle: 0), .body, z: f.faceZ + 0.05,
                                    group: 26))
                b.parts.append(Part(.ring(c: b.onHead(V2(side * 0.62, 0.12)), r: V2(1.45, 1.45), width: 0.5), .secondary,
                                    z: f.faceZ + 0.06, group: 26, innerOutline: false))
            }
            b.parts.append(Part(.ellipse(c: b.onHead(V2(0, -0.4)), r: V2(2.4, 1.2), angle: 0), .secondary, z: f.faceZ + 0.04, group: 1))
        }
        // The tail coils up behind.
        b.parts += w4Spiral(from: f.c + V2(back ? 0 : 2, -f.r.y * 0.4), angle: back ? -0.2 : 0.2, curl: 0.55, z: back ? 1.5 : -1)
        b.eyeX = (0.62, 0)
        b.eyeY = 0.12
        return b
    }
}

// MARK: - Pangolin

extension SpeciesRig {
    /// One overlapping scale plate: a rounded shield pointing along `dir`.
    fileprivate static func w4Scale(_ at: V2, size: Double, dir: Double, z: Double, group: Int, shade: Int) -> Part {
        let pts = [V2(-0.9, 0.9), V2(0.35, 1.0), V2(1.2, 0.35), V2(1.35, -0.3), V2(0.6, -1.0), V2(-0.9, -0.9)].map {
            at + rotate($0 * size, by: dir)
        }
        return Part(.polygon(pts), .body, z: z, group: group, patterned: true, toneBias: shade)
    }

    fileprivate static func w4Pangolin(_ pose: Pose) -> Built {
        if pose.lying > 0.5 { return w4PangolinBall(pose) }
        var spec = QuadSpec()
        spec.bodyR = V2(7.6, 4.9)
        spec.bodyX = 16.5
        spec.legLen = 2.4
        spec.legR = (1.3, 1.1)
        spec.legX = (4.5, -4.5)
        spec.headR = 3.3
        spec.headOffset = V2(7.4, 0.6)
        spec.bellyR = V2(5, 1.8)
        let q = quadruped(spec, pose)
        var b = q.built
        // Skin of the face, belly and legs is pale; the plates carry the colour.
        b.parts = b.parts.map { part in
            var p = part
            if p.role == .limb || p.role == .head { p.ramp = .secondary; p.patterned = false }
            return p
        }
        b.parts.append(Part(.capsule(a: b.onHead(V2(0.3, -0.05)), b: b.onHead(V2(1.9, -0.55)), ra: 2.3, rb: 0.8), .secondary,
                            z: 1.05, group: 1))
        b.parts.append(Part(.ellipse(c: b.onHead(V2(2.05, -0.55)), r: V2(0.7, 0.6), angle: 0), .dark, z: 1.2, group: 1))
        // Rows of plates over the back, front ones over the ones behind, upper rows over lower.
        var g = -20
        for (row, (f, n)) in [(0.95, 7), (0.66, 6), (0.36, 4)].enumerated() {
            for k in 0..<n {
                let a = 0.2 + (Double(k) + (row == 1 ? 0.5 : 0)) / Double(n) * 2.7
                let pos = q.bodyC + rotate(V2(cos(a) * q.bodyR.x * f, sin(a) * q.bodyR.y * f + 0.4), by: q.angle)
                let dir = a + .pi / 2 + q.angle + 0.5
                b.parts.append(w4Scale(pos, size: 1.75, dir: dir, z: 0.3 - Double(row) * 0.01 + Double(n - k) * 0.001 - 0.0001,
                                       group: g, shade: (k + row) % 2))
                g -= 1
            }
        }
        // Long armoured tail sweeping down to the ground.
        let base = q.bodyC + rotate(V2(-q.bodyR.x * 0.8, 0.3), by: q.angle)
        var a = 3.4 + pose.tail * 0.08 - pose.dangle * 1.0
        var p = base
        for k in 0..<4 {
            let next = p + rotate(V2(2.4, 0), by: a)
            let rr = 3.1 - Double(k) * 0.6
            b.parts.append(Part(.capsule(a: p, b: next, ra: rr, rb: rr - 0.6), .body, z: -1, group: 5, patterned: true, role: .extremity))
            b.parts.append(w4Scale((p + next) / 2 + rotate(V2(0, rr * 0.45), by: a), size: rr * 0.62, dir: a, z: -0.9 + Double(k) * -0.001,
                                   group: g, shade: k % 2))
            g -= 1
            p = next
            a -= 0.12
        }
        b.eyeX = (0.15, 0.55)
        b.eyeY = 0.3
        b.mouth = V2(1.7, -0.85)
        b.cheek = V2(0.3, -0.35)
        return b
    }

    /// Asleep, the pangolin rolls into an armoured ball with its tail wrapped over its face.
    fileprivate static func w4PangolinBall(_ pose: Pose) -> Built {
        var b = Built()
        let r = 6.8 * pose.squash
        let c = V2(16, ground + r)
        b.parts.append(Part(.ellipse(c: c, r: V2(r * 1.05, r), angle: 0), .body, z: 0, group: 0, patterned: true, role: .torso))
        var g = -20
        for (row, (f, n)) in [(0.8, 10), (0.45, 6)].enumerated() {
            for k in 0..<n {
                let a = Double(k) / Double(n) * 2 * .pi + Double(row) * 0.3 + 1.6
                let pos = c + V2(cos(a), sin(a)) * r * f
                b.parts.append(w4Scale(pos, size: 1.9 - Double(row) * 0.3, dir: a + .pi / 2, z: 0.3 + Double(row) * 0.1 + Double(k) * 0.001,
                                       group: g, shade: (k + row) % 2))
                g -= 1
            }
        }
        // The face peeks out low at the front, under the tail.
        b.headC = c + V2(3.2, -3.6)
        b.headR = 2.6
        b.parts.append(Part(.ellipse(c: b.headC, r: V2(2.8, 2.5), angle: 0), .secondary, z: 1, group: 1, role: .head))
        for k in 0..<4 {
            let a = 1.3 - Double(k) * 0.42
            let pos = c + V2(cos(a), sin(a)) * r * 0.98
            b.parts.append(w4Scale(pos, size: 2.3 - Double(k) * 0.2, dir: a - .pi / 2, z: 1.5 + Double(k) * 0.01, group: g, shade: k % 2))
            g -= 1
        }
        b.eyeX = (-0.1, 0.4)
        b.eyeY = 0.1
        b.mouth = V2(3, 3)
        b.topOverride = c + V2(0, r)
        return b
    }

    fileprivate static func w4PangolinFront(_ pose: Pose, back: Bool) -> Built {
        if pose.lying > 0.5 { return w4PangolinBall(pose) }
        var s = W4FrontSpec()
        s.bodyR = V2(6.2, 5.2)
        s.headR = 3.6
        s.headY = 3.6
        s.legLen = 2.4
        s.legR = (1.3, 1.1)
        s.legGap = 2.8
        s.legRamp = .secondary
        let f = w4Front(s, pose, back: back)
        var b = f.built
        b.parts = b.parts.map { part in
            var p = part
            if p.role == .head { p.ramp = .secondary; p.patterned = false }
            return p
        }
        // Plates over the shoulders and back: in rows above the head from the front, all over from the back.
        var g = -20
        let rows: [(Double, Int)] = back ? [(0.95, 7), (0.6, 5), (0.25, 3)] : [(0.95, 7)]
        for (row, (rf, n)) in rows.enumerated() {
            for k in 0..<n {
                let a = 0.1 + (Double(k) + (row % 2 == 1 ? 0.5 : 0)) / Double(n - 1) * (.pi - 0.2)
                let pos = f.c + V2(cos(a) * f.r.x * rf, sin(a) * f.r.y * rf * (back ? 1 : 0.9) + (back ? -0.6 : 0.3))
                b.parts.append(w4Scale(pos, size: 1.8, dir: -.pi / 2 + (a - .pi / 2) * 0.5,
                                       z: (back ? 0.5 : -0.2) + Double(row) * 0.01 - Double(abs(k - n / 2)) * 0.001,
                                       group: g, shade: (k + row) % 2))
                g -= 1
            }
        }
        if !back {
            b.parts.append(Part(.ellipse(c: b.onHead(V2(0, -0.45)), r: V2(1.8, 1.5), angle: 0), .secondary, z: f.faceZ + 0.1, group: 1))
            b.parts.append(Part(.ellipse(c: b.onHead(V2(0, -0.4)), r: V2(0.8, 0.6), angle: 0), .dark, z: f.faceZ + 0.2, group: 1))
        } else {
            // The armoured tail runs down the middle.
            var tp = f.c + V2(0, -1)
            for k in 0..<3 {
                let next = tp + V2(pose.tail * 0.4, -2.2)
                b.parts.append(w4Scale(tp, size: 2.2 - Double(k) * 0.3, dir: -.pi / 2, z: 1 + Double(k) * 0.01, group: g, shade: k % 2))
                g -= 1
                tp = next
            }
        }
        return b
    }
}

// MARK: - Fruit bat

extension SpeciesRig {
    /// An open bat wing from `shoulder`: three finger bones with scalloped membrane between them.
    /// `s` is 1 for a wing reaching right, -1 for left.
    fileprivate static func w4BatWing(_ shoulder: V2, s: Double, flap: Double, size: Double, z: Double, group: Int, bias: Int,
                                      body: V2) -> [Part] {
        let wrist = shoulder + V2(s * 2.8, 4.6 + flap * 1.2) * size
        let tips = [wrist + V2(s * 6.5, 2.5 + flap) * size, wrist + V2(s * 7.5, -2.2 + flap * 0.5) * size, wrist + V2(s * 4.5, -6.5) * size]
        var membrane = [shoulder, wrist, tips[0]]
        // Scallops between finger tips, then back to the body.
        membrane.append((tips[0] + tips[1]) / 2 + V2(-s * 1.6, -0.3) * size)
        membrane.append(tips[1])
        membrane.append((tips[1] + tips[2]) / 2 + V2(-s * 1.6, 0.3) * size)
        membrane.append(tips[2])
        membrane.append(body)
        var parts = [Part(.polygon(membrane), .dark, z: z, group: group, toneBias: bias)]
        parts.append(Part(.capsule(a: shoulder, b: wrist, ra: 0.55, rb: 0.45), .body, z: z + 0.01, group: group, toneBias: bias,
                          innerOutline: false))
        for tip in tips {
            parts.append(Part(.capsule(a: wrist, b: tip, ra: 0.4, rb: 0.25), .body, z: z + 0.01, group: group, toneBias: bias,
                              innerOutline: false))
        }
        parts.append(Part(.ellipse(c: wrist + V2(s * 0.2, 0.6), r: V2(0.6, 0.6), angle: 0), .white, z: z + 0.02, group: group,
                          toneBias: bias, innerOutline: false))
        return parts
    }

    /// The fox face shared by the side and hanging poses.
    fileprivate static func w4BatHead(_ b: inout Built, z: Double, side: Bool) {
        if side {
            b.parts.append(Part(headPolygon(b, [V2(0.3, 0.3), V2(1.6, -0.3), V2(1.5, -0.55), V2(0.3, -0.75)]), .body, z: z + 0.1,
                                group: 1, patterned: true))
            b.parts.append(Part(.ellipse(c: b.onHead(V2(1.55, -0.38)), r: V2(0.7, 0.6), angle: 0), .dark, z: z + 0.2, group: 1))
            for (pts, dz, bias) in [([V2(-0.85, 0.4), V2(-0.25, 0.8), V2(-0.7, 1.75)], -0.1, 1),
                                    ([V2(-0.2, 0.8), V2(0.45, 0.6), V2(0.15, 1.7)], 0.2, 0)] {
                b.parts.append(Part(headPolygon(b, pts), .body, z: z + dz, group: 6, patterned: true, toneBias: bias, role: .extremity))
            }
        } else {
            b.parts.append(Part(headPolygon(b, [V2(-0.5, -0.05), V2(0.5, -0.05), V2(0, -1.0)]), .body, z: z + 0.1, group: 1,
                                patterned: true))
            b.parts.append(Part(.ellipse(c: b.onHead(V2(0, -0.78)), r: V2(0.75, 0.55), angle: b.headAngle), .dark, z: z + 0.2, group: 1))
            for sx in [-1.0, 1.0] {
                b.parts.append(Part(headPolygon(b, [V2(sx * 0.25, 0.8), V2(sx * 0.85, 0.45), V2(sx * 0.75, 1.75)]), .body,
                                    z: z - 0.1, group: 6, patterned: true, role: .extremity))
            }
        }
    }

    fileprivate static func w4FruitBat(_ pose: Pose) -> Built {
        if pose.lying > 0.5 { return w4BatHanging(pose, front: false) }
        var b = Built()
        let r = V2(4.6 / pose.squash.squareRoot(), 5.4 * pose.squash)
        let open = pose.wing > 0.5 || pose.dangle > 0
        let angle = -0.3 + pose.lean + pose.sway
        let c = V2(14 + pose.lunge, ground + 2.4 + r.y + pose.bob + pose.lift + pose.dangle)
        func at(_ v: V2) -> V2 { c + rotate(v, by: angle) }
        b.parts.append(Part(.ellipse(c: c, r: r, angle: angle), .body, z: 0, group: 0, patterned: true, role: .torso))
        // Golden mantle round the shoulders.
        b.parts.append(Part(.ellipse(c: at(V2(0.8, 2.6)), r: V2(3.8, 2.8), angle: angle), .secondary, z: 0.1, group: 0))
        // Little hind legs.
        for near in [true, false] {
            let hip = at(V2(-1.5 - (near ? 0 : 0.8), -r.y * 0.7))
            var foot = V2(hip.x - 0.6 - pose.stride * (near ? 1 : -1), ground + 0.7 + pose.lift)
            if pose.dangle > 0 { foot = hip + V2(-0.5, -2.5) }
            b.parts.append(Part(.capsule(a: hip, b: foot, ra: 0.9, rb: 0.7), .dark, z: near ? 1.6 : -1.6, group: near ? 3 : 4,
                                toneBias: near ? 0 : 1, role: .limb))
        }
        let shoulder = at(V2(0.8, 2.4))
        if open {
            let flap = pose.dangle > 0 ? pose.sway * 4 : (pose.paw > 0 ? 0.5 : 1)
            b.parts += w4BatWing(shoulder + V2(0.6, 0.6), s: -1, flap: flap + 0.5, size: 1.05, z: -1.5, group: 11, bias: 1,
                                 body: at(V2(-1, -3)))
            b.parts += w4BatWing(shoulder + V2(-0.4, 0), s: -1, flap: flap, size: 1.15, z: 0.5, group: 12, bias: 0, body: at(V2(-2.5, -3)))
        } else {
            // Folded wings: slim dark blades from shoulder to wrist; it walks on its wrists.
            for near in [false, true] {
                let sh = shoulder + V2(near ? 0 : -0.8, near ? 0 : 0.4)
                let swing = pose.stride * (near ? 1 : -1)
                let wrist = V2(sh.x + 2.6 + swing * 1.6, ground + 1 + pose.lift)
                let pts = [sh + V2(-1.2, 1.2), sh + V2(0.9, 0.6), wrist + V2(0.7, 0.3), wrist + V2(-0.5, -0.1), sh + V2(-2.2, -3.5)]
                b.parts.append(Part(.polygon(pts), .dark, z: near ? 0.5 : -1.5, group: near ? 12 : 11, toneBias: near ? 0 : 1))
                b.parts.append(Part(.ellipse(c: wrist + V2(0.6, 0.4), r: V2(0.6, 0.6), angle: 0), .white, z: near ? 0.51 : -1.49,
                                    group: near ? 12 : 11, toneBias: near ? 0 : 1, innerOutline: false))
            }
        }
        b.headC = at(V2(2, r.y + 2.6)) + V2(pose.headDip * 0.6, -pose.headDip)
        b.headR = 4.2
        b.headAngle = pose.headTilt + angle * 0.3 + 0.1
        b.parts.append(Part(.ellipse(c: b.headC, r: V2(4.3, 4.1), angle: b.headAngle), .body, z: 1, group: 1, patterned: true,
                            role: .head))
        w4BatHead(&b, z: 1, side: true)
        b.eyeX = (0.3, 0.75)
        b.eyeY = 0.2
        b.mouth = V2(1.2, -0.62)
        return b
    }

    /// Asleep, the bat hangs upside down from a branch, wrapped in its wings.
    fileprivate static func w4BatHanging(_ pose: Pose, front: Bool) -> Built {
        var b = Built()
        let swing = sin(pose.t * 2 * .pi) * 0.04
        let top = V2(16, 28.5)
        b.parts.append(Part(.capsule(a: V2(4, 29.6), b: V2(28, 29.2), ra: 1.0, rb: 0.9), .wood, z: 3, group: 9))
        for dx in [-1.0, 1.0] {
            b.parts.append(Part(.capsule(a: top + V2(dx, -2.5), b: top + V2(dx * 0.8, 0.6), ra: 0.7, rb: 0.6), .dark, z: 2, group: 3))
        }
        let c = top + rotate(V2(0, -8), by: swing)
        let r = V2(4.6, 5.8 * pose.squash)
        b.parts.append(Part(.ellipse(c: c, r: r, angle: swing), .body, z: 0, group: 0, patterned: true, role: .torso))
        // Wings wrapped round like a cloak, open a crack at the front.
        let cloakR = V2(5.4, 6.4 * pose.squash)
        for s in [-1.0, 1.0] {
            let shift = front ? s * 1.6 : s * 0.6 - 0.8
            b.parts.append(Part(.ellipse(c: c + V2(shift, 0.2), r: V2(cloakR.x * 0.75, cloakR.y), angle: swing - s * 0.08), .dark,
                                z: s < 0 ? 0.5 : 0.6, group: s < 0 ? 11 : 12))
        }
        b.headC = c + rotate(V2(0, -r.y - 2.4), by: swing)
        b.headR = 4
        b.headAngle = .pi + swing
        b.headZ = 1
        b.parts.append(Part(.ellipse(c: b.headC, r: V2(4.2, 4), angle: b.headAngle), .body, z: 1, group: 1, patterned: true, role: .head))
        if front {
            w4BatHead(&b, z: 1, side: false)
            b.eyeX = (0.42, 0)
            b.eyeY = 0.12
        } else {
            // Upside down and facing right, so the snout is mirrored onto the other side of the head.
            b.headAngle = swing
            b.parts.removeLast()
            b.parts.append(Part(.ellipse(c: b.headC, r: V2(4.2, 4), angle: b.headAngle), .body, z: 1, group: 1, patterned: true,
                                role: .head))
            b.parts.append(Part(headPolygon(b, [V2(0.3, -0.3), V2(1.6, 0.3), V2(1.5, 0.55), V2(0.3, 0.75)]), .body, z: 1.1, group: 1,
                                patterned: true))
            b.parts.append(Part(.ellipse(c: b.onHead(V2(1.55, 0.38)), r: V2(0.7, 0.6), angle: 0), .dark, z: 1.2, group: 1))
            for (pts, dz, bias) in [([V2(-0.85, -0.4), V2(-0.25, -0.8), V2(-0.7, -1.75)], -0.1, 1),
                                    ([V2(-0.2, -0.8), V2(0.45, -0.6), V2(0.15, -1.7)], 0.2, 0)] {
                b.parts.append(Part(headPolygon(b, pts), .body, z: 1 + dz, group: 6, patterned: true, toneBias: bias, role: .extremity))
            }
            b.eyeX = (0.3, 0.75)
            b.eyeY = -0.2
            b.mouth = V2(2, 2)
            b.cheek = V2(0.3, 0.3)
        }
        b.topOverride = b.headC + V2(0, -4)
        return b
    }

    fileprivate static func w4FruitBatFront(_ pose: Pose, back: Bool) -> Built {
        if pose.lying > 0.5 { return w4BatHanging(pose, front: !back) }
        var b = Built()
        let faceZ: Double = back ? -0.5 : 1
        let r = V2(4.6 / pose.squash.squareRoot(), 5.2 * pose.squash)
        let c = V2(16, ground + 2.4 + r.y + pose.bob + pose.lift + pose.dangle)
        b.parts.append(Part(.ellipse(c: c, r: r, angle: pose.sway), .body, z: 0, group: 0, patterned: true, role: .torso))
        b.parts.append(Part(.ellipse(c: c + V2(0, 2.4), r: V2(4.2, 2.8), angle: 0), .secondary, z: 0.1, group: 0))
        let open = pose.wing > 0.5 || pose.dangle > 0
        for s in [-1.0, 1.0] {
            let hip = c + V2(s * 1.8, -r.y * 0.7)
            let foot = pose.dangle > 0 ? hip + V2(s * 0.4, -2.4) : V2(hip.x + s * 0.4, ground + 0.7 + pose.lift)
            b.parts.append(Part(.capsule(a: hip, b: foot, ra: 0.9, rb: 0.7), .dark, z: back ? -0.1 : 1.6, group: s < 0 ? 3 : 4, role: .limb))
            let shoulder = c + V2(s * 2.6, 2.4)
            if open {
                let flap = pose.dangle > 0 ? pose.sway * 4 : 1
                b.parts += w4BatWing(shoulder, s: s, flap: flap, size: 0.95, z: back ? 0.5 : -1, group: s < 0 ? 11 : 12, bias: back ? 0 : 1,
                                     body: c + V2(s * 1.5, -3.5))
            } else {
                let wrist = V2(c.x + s * (r.x + 1.6), ground + 1 + pose.lift)
                b.parts.append(Part(.polygon([shoulder + V2(-s * 0.6, 1.4), shoulder + V2(s * 1.8, 0.6), wrist + V2(s * 0.6, 0),
                                              wrist + V2(-s * 1.0, 0), c + V2(s * 2, -r.y * 0.6)]), .dark, z: 0.5, group: s < 0 ? 11 : 12))
                b.parts.append(Part(.ellipse(c: wrist + V2(0, 0.6), r: V2(0.6, 0.6), angle: 0), .white, z: 0.51, group: s < 0 ? 11 : 12,
                                    innerOutline: false))
            }
        }
        b.headC = c + V2(0, r.y + 2.4 - pose.headDip)
        b.headR = 4.2
        b.headAngle = pose.sway * 0.6 + pose.headTilt
        b.headZ = faceZ
        b.parts.append(Part(.ellipse(c: b.headC, r: V2(4.4, 4.2), angle: b.headAngle), .body, z: faceZ, group: 1, patterned: true,
                            role: .head))
        if back {
            for sx in [-1.0, 1.0] {
                b.parts.append(Part(headPolygon(b, [V2(sx * 0.25, 0.8), V2(sx * 0.85, 0.45), V2(sx * 0.75, 1.75)]), .body,
                                    z: 0.5, group: 6, patterned: true, role: .extremity))
            }
        } else {
            w4BatHead(&b, z: faceZ, side: false)
        }
        b.eyeX = (0.42, 0)
        b.eyeY = 0.15
        return b
    }
}

// MARK: - Peacock

extension SpeciesRig {
    /// The peacock's train spread into a fan of eye-spot feathers around `c`, from `a0` to `a1`.
    fileprivate static func w4Fan(_ c: V2, radius: Double, from a0: Double, to a1: Double, count: Int, shimmer: Double, z: Double,
                                  spots: Bool) -> [Part] {
        var parts: [Part] = []
        // A solid backing so the fan reads as one shape.
        var backing = [c]
        for k in 0...16 {
            let a = a0 + (a1 - a0) * Double(k) / 16
            backing.append(c + V2(cos(a), sin(a)) * radius * 0.9)
        }
        parts.append(Part(.polygon(backing), .green, z: z - 0.05, group: -40, toneBias: 1))
        for i in 0..<count {
            let f = Double(i) / Double(count - 1)
            let a = a0 + (a1 - a0) * f + sin(shimmer + f * 6) * 0.03
            let dir = V2(cos(a), sin(a))
            let len = radius * (0.94 + 0.06 * sin(f * 9 + shimmer))
            let g = -41 - i
            let fz = z + Double(i % 2) * 0.01 + Double(i) * 0.0001
            parts.append(Part(.capsule(a: c + dir * 2, b: c + dir * len, ra: 0.6, rb: 2.0), .green, z: fz, group: g, role: .extremity))
            if spots {
                parts += w4EyeSpot(c + dir * (len - 1.2), size: 1.65, angle: a, z: fz + 0.001, group: g)
            }
        }
        // An inner row of shorter feathers.
        if spots {
            for i in 0..<(count - 1) {
                let f = (Double(i) + 0.5) / Double(count - 1)
                let a = a0 + (a1 - a0) * f
                let dir = V2(cos(a), sin(a))
                let g = -60 - i
                parts.append(Part(.capsule(a: c + dir * 1.5, b: c + dir * radius * 0.58, ra: 0.5, rb: 1.6), .green, z: z + 0.02, group: g))
                parts += w4EyeSpot(c + dir * (radius * 0.58 - 0.8), size: 1.25, angle: a, z: z + 0.021, group: g)
            }
        }
        return parts
    }

    fileprivate static func w4Peacock(_ pose: Pose) -> Built {
        var b = Built()
        let r = V2(5.4 / pose.squash.squareRoot(), 4.6 * pose.squash)
        let legLen = 3.8 * (1 - pose.lying) * (1 + 0.3 * pose.dangle)
        let angle = pose.lean + pose.sway - 0.2
        let c = V2(17 + pose.lunge, ground + legLen + r.y * 0.85 + pose.bob + pose.lift)
        func at(_ v: V2) -> V2 { c + rotate(v, by: angle) }
        b.parts.append(Part(.ellipse(c: c, r: r, angle: angle), .body, z: 0, group: 0, patterned: true, role: .torso))
        // The train: fanned for display when standing or showing off, folded and trailing when on the move.
        let fanned = pose.lying == 0 && pose.dangle == 0 && pose.headDip < 0.5 && (pose.lift > 0 || abs(pose.stride) < 0.01)
        if fanned {
            b.parts += w4Fan(at(V2(-2.5, 1.5)), radius: 12.5 + pose.tail * 0.3, from: 0.3, to: 3.0, count: 11,
                             shimmer: pose.t * 2 * .pi, z: -2, spots: true)
        } else {
            let root = at(V2(-3.5, 0.8))
            let end = V2(max(1.5, root.x - 13), ground + 1.2 + pose.lying * 0.5) + V2(0, pose.dangle > 0 ? -2 : pose.tail * 0.3)
            let tip = pose.dangle > 0 ? root + V2(-3, -9) : end
            b.parts.append(Part(.polygon([root + V2(0.5, 2.2), tip + V2(-0.5, 1.3), tip + V2(0, -0.8), at(V2(-3, -2.6))]), .green,
                                z: -1, group: 5, role: .extremity))
            for k in 1...3 {
                let f = Double(k) / 3.5
                let pos = root + (tip - root) * f + V2(0, 0.6 - f * 0.6)
                b.parts += w4EyeSpot(pos, size: 1.0 + f * 0.3, angle: 0, z: -0.99 + Double(k) * 0.001, group: 5)
            }
        }
        // Folded wing.
        b.parts.append(Part(.ellipse(c: at(V2(-1.2, 0.3 + pose.wing * 0.6)), r: V2(3.4, 2.2), angle: angle - 0.25 + pose.wing * 0.6),
                            .secondary, z: 0.5, group: 7, role: .extremity))
        // Long legs.
        for near in [true, false] {
            let hip = at(V2(near ? 1 : -0.6, -r.y * 0.75))
            var foot = V2(hip.x + pose.stride * (near ? 1.8 : -1.8), ground + 0.6 + pose.lift)
            if pose.dangle > 0 { foot = hip + V2(0.3, -legLen * 1.2 - 1) }
            if pose.lying > 0 { foot = hip + V2(1, -0.6) }
            let z = near ? 2.0 : -2.0
            if legLen > 0.5 {
                b.parts.append(Part(.capsule(a: hip, b: foot, ra: 0.6, rb: 0.5), .stone, z: z, group: near ? 3 : 4, toneBias: near ? 0 : 1,
                                    innerOutline: false))
            }
            b.parts.append(Part(.ellipse(c: foot + V2(1, 0), r: V2(1.6, 0.7), angle: 0), .stone, z: z, group: near ? 3 : 4,
                                toneBias: near ? 0 : 1))
        }
        // Slender neck, small head, beak and a crest of feather fans.
        b.headC = at(V2(3.6, 7.6)) + V2(pose.headDip * 0.7 + pose.lying * 0.5, -pose.headDip * 1.4 - pose.lying * 2.5)
        b.headR = 3.3
        b.headAngle = angle * 0.4 + pose.headTilt
        b.parts.append(Part(.capsule(a: at(V2(2.6, 2)), b: b.headC + V2(-0.6, -1.2), ra: 2.4, rb: 1.7), .body, z: 0.6, group: 1,
                            patterned: true))
        b.parts.append(Part(.ellipse(c: b.headC, r: V2(3.5, 3.3), angle: b.headAngle), .body, z: 1, group: 1, patterned: true, role: .head))
        b.parts.append(Part(.capsule(a: b.onHead(V2(0.3, -0.15)), b: b.onHead(V2(0.9, -0.5)), ra: 0.45, rb: 0.35), .white, z: 1.05,
                            group: 1, innerOutline: false))
        let open = pose.mouth == .open ? 0.25 : 0
        b.parts.append(Part(headPolygon(b, [V2(0.8, 0.15), V2(1.75, -0.2 + open * 0.3), V2(0.85, -0.45)]), .stone, z: 1.3, group: 21))
        for k in 0..<4 {
            let base = b.onHead(V2(-0.15 + Double(k) * 0.12, 0.85))
            let top = base + rotate(V2(0, 3.2), by: 0.55 - Double(k) * 0.28 + sin(pose.t * 2 * .pi + Double(k)) * 0.05)
            b.parts.append(Part(.capsule(a: base, b: top, ra: 0.25, rb: 0.25), .body, z: 0.95 + Double(k) * 0.01, group: 20,
                                innerOutline: false))
            b.parts.append(Part(.ellipse(c: top, r: V2(0.75, 0.75), angle: 0), .blue, z: 0.96 + Double(k) * 0.01, group: 20 + k))
        }
        b.eyeX = (0.25, 0.65)
        b.eyeY = 0.18
        b.mouth = V2(3, 3)
        b.topOverride = b.onHead(V2(0, 1.0))
        return b
    }

    fileprivate static func w4PeacockFront(_ pose: Pose, back: Bool) -> Built {
        var b = Built()
        let faceZ: Double = back ? -0.5 : 1
        let r = V2(5.2 / pose.squash.squareRoot(), 5.0 * pose.squash)
        let legLen = 3.8 * (1 - 0.8 * pose.lying) * (1 + 0.3 * pose.dangle)
        let c = V2(16, ground + legLen + r.y * 0.85 + pose.bob + pose.lift)
        b.parts.append(Part(.ellipse(c: c, r: r, angle: pose.sway), .body, z: 0, group: 0, patterned: true, role: .torso))
        let fanned = pose.lying == 0 && pose.dangle == 0 && pose.headDip < 0.5
        if fanned {
            // Seen from behind the fan shows its plain, pale underside.
            b.parts += w4Fan(c + V2(0, 1), radius: 14, from: 0.12, to: .pi - 0.12, count: 13, shimmer: pose.t * 2 * .pi,
                             z: back ? 0.5 : -2, spots: !back)
            if back {
                b.parts = b.parts.map { part in
                    var p = part
                    if p.ramp == .green { p.ramp = .wood }
                    return p
                }
            }
        } else {
            b.parts.append(Part(.polygon([c + V2(-3, 1), c + V2(3, 1), c + V2(2, -r.y - 2), c + V2(-2, -r.y - 2)]), .green,
                                z: back ? 0.5 : -1, group: 5))
        }
        for s in [-1.0, 1.0] {
            let hip = c + V2(s * 1.8, -r.y * 0.75)
            let foot = pose.dangle > 0 ? hip + V2(s * 0.3, -legLen * 1.2) : V2(hip.x + s * 0.3, ground + 0.6 + pose.lift)
            if legLen > 0.5 {
                b.parts.append(Part(.capsule(a: hip, b: foot, ra: 0.6, rb: 0.5), .stone, z: back ? 0.4 : 2, group: s < 0 ? 3 : 4,
                                    innerOutline: false))
            }
            b.parts.append(Part(.ellipse(c: foot + V2(0, -0.1), r: V2(1.2, 0.7), angle: 0), .stone, z: back ? 0.4 : 2, group: s < 0 ? 3 : 4))
            let flap = max(0, pose.wing) * 0.5 + pose.dangle * 0.5
            b.parts.append(Part(.ellipse(c: c + V2(s * (r.x - 0.6), 0.3 + flap), r: V2(1.8, 3.4), angle: s * (-0.25 - flap * 0.6)),
                                .secondary, z: back ? 0.6 : 0.4, group: s < 0 ? 9 : 10, role: .extremity))
        }
        b.headC = c + V2(0, r.y + 4.4 - pose.headDip * 1.2 - pose.lying * 2)
        b.headR = 3.4
        b.headAngle = pose.sway * 0.6 + pose.headTilt
        b.headZ = faceZ
        b.parts.append(Part(.capsule(a: c + V2(0, r.y * 0.4), b: b.headC + V2(0, -1.5), ra: 2.4, rb: 1.8), .body, z: back ? 0.55 : 0.6,
                            group: 1, patterned: true))
        b.parts.append(Part(.ellipse(c: b.headC, r: V2(3.6, 3.4), angle: b.headAngle), .body, z: faceZ, group: 1, patterned: true,
                            role: .head))
        if !back {
            let open = pose.mouth == .open ? 0.2 : 0
            b.parts.append(Part(headPolygon(b, [V2(-0.3, -0.25), V2(0.3, -0.25), V2(0, -0.8 - open)]), .stone, z: faceZ + 0.2, group: 21))
        }
        for k in 0..<5 {
            let lean = (Double(k) - 2) * 0.28
            let base = b.onHead(V2(0, 0.85))
            let top = base + rotate(V2(0, 3.2), by: -lean)
            b.parts.append(Part(.capsule(a: base, b: top, ra: 0.25, rb: 0.25), .body, z: faceZ - 0.05, group: 20, innerOutline: false))
            b.parts.append(Part(.ellipse(c: top, r: V2(0.75, 0.75), angle: 0), .blue, z: faceZ - 0.04, group: 20 + k))
        }
        b.eyeX = (0.45, 0)
        b.eyeY = 0.12
        b.topOverride = b.onHead(V2(0, 1.0))
        return b
    }
}

// MARK: - Kitsune

extension SpeciesRig {
    /// One bushy tail of the kitsune: three puffs ending in a white tip.
    fileprivate static func w4FoxTail(from base: V2, angle start: Double, curl: Double, z: Double, group: Int, bias: Int) -> (parts: [Part], tip: V2) {
        var parts: [Part] = []
        var p = base
        var a = start
        for i in 0..<3 {
            let next = p + rotate(V2(2.9, 0), by: a)
            let r = [1.6, 2.1, 1.9][i]
            parts.append(Part(.ellipse(c: (p + next) / 2, r: V2(2.2, r), angle: a), i == 2 ? .white : .body, z: z, group: group,
                              patterned: i < 2, toneBias: bias, role: .extremity))
            p = next
            a += curl
        }
        return (parts, p)
    }

    fileprivate static func w4Kitsune(_ pose: Pose) -> Built {
        var spec = QuadSpec()
        spec.bodyX = 15
        spec.legLen = 4.8
        spec.legR = (1.5, 1.2)
        spec.headR = 4.8
        spec.headOffset = V2(7.2, 5.6)
        spec.bellyR = V2(3.5, 2)
        let q = quadruped(spec, pose)
        var b = q.built
        // Tall ears with pink insides.
        for (pts, z, bias) in [([V2(-0.8, 0.5), V2(-0.1, 0.9), V2(-0.75, 1.95)], 0.9, 1),
                               ([V2(-0.05, 0.85), V2(0.65, 0.55), V2(0.35, 1.9)], 1.2, 0)] {
            b.parts.append(Part(headPolygon(b, pts), .body, z: z, group: 6, patterned: true, toneBias: bias, role: .extremity))
            if bias == 0 {
                b.parts.append(Part(headPolygon(b, [V2(0.08, 0.9), V2(0.5, 0.68), V2(0.33, 1.55)]), .pink, z: z + 0.01, group: 6,
                                    innerOutline: false))
            }
        }
        // Slim snout, white chin and chest.
        b.parts.append(Part(headPolygon(b, [V2(0.35, 0.15), V2(1.55, -0.35), V2(1.45, -0.6), V2(0.35, -0.75)]), .body, z: 1.1, group: 1,
                            patterned: true))
        b.parts.append(Part(headPolygon(b, [V2(0.2, -0.35), V2(1.35, -0.55), V2(0.3, -0.95)]), .white, z: 1.15, group: 1))
        b.parts.append(Part(.ellipse(c: b.onHead(V2(1.5, -0.42)), r: V2(0.6, 0.55), angle: 0), .dark, z: 1.2, group: 1))
        b.parts.append(Part(.ellipse(c: q.bodyC + rotate(V2(q.bodyR.x * 0.55, 0), by: q.angle), r: V2(3, 3.6), angle: q.angle), .white,
                            z: 0.2, group: 0))
        // Red markings under the eye and a flame mark on the brow.
        b.parts.append(Part(.capsule(a: b.onHead(V2(0.35, -0.15)), b: b.onHead(V2(-0.25, -0.05)), ra: 0.4, rb: 0.25), .red, z: 1.16,
                            group: 1, innerOutline: false))
        b.parts.append(Part(headPolygon(b, [V2(0.25, 0.62), V2(0.6, 0.58), V2(0.35, 0.98)]), .purple, z: 1.16, group: 1,
                            innerOutline: false, fixedTone: .light))
        // Seven tails fanned behind, with spirit flames at alternate tips.
        let flick = sin(pose.t * 4 * .pi)
        for i in 0..<7 {
            let f = Double(i) / 6
            let base = q.bodyC + rotate(V2(-q.bodyR.x * 0.8, q.bodyR.y * 0.15), by: q.angle)
            let wag = pose.tail * 0.15 * (i % 2 == 0 ? 1 : -1)
            let start = 1.3 + f * 2.0 + wag - pose.dangle * 1.0 - pose.lying * (0.6 + f * 0.6)
            let tail = w4FoxTail(from: base, angle: start, curl: -0.15 + pose.lying * 0.05, z: -1 - Double(i % 2) * 0.1 - f * 0.01,
                                 group: -30 - i, bias: i % 2)
            b.parts += tail.parts
            if i % 2 == 0 && pose.lying == 0 {
                b.parts += w4Wisp(tail.tip + V2(0, 1.2), size: 1.1, flicker: flick * (i % 4 == 0 ? 1 : -1), ramp: .blue, z: 2.5,
                                  group: -50 - i)
            }
        }
        b.mouth = V2(1.15, -0.55)
        b.eyeX = (0.3, 0.75)
        b.topOverride = b.onHead(V2(-0.1, 1.1))
        return b
    }

    fileprivate static func w4KitsuneFront(_ pose: Pose, back: Bool) -> Built {
        var s = W4FrontSpec()
        s.bodyR = V2(5.4, 5)
        s.headR = 4.8
        s.legLen = 4.8
        s.legR = (1.5, 1.2)
        s.chest = .white
        let f = w4Front(s, pose, back: back)
        var b = f.built
        let earZ = back ? 0.5 : f.faceZ - 0.1
        for side in [-1.0, 1.0] {
            let pts = [V2(side * 0.25, 0.85), V2(side * 0.88, 0.45), V2(side * 0.78, 1.85)]
            b.parts.append(Part(headPolygon(b, pts), .body, z: earZ, group: 6, patterned: true, role: .extremity))
            if !back {
                b.parts.append(Part(headPolygon(b, [V2(side * 0.38, 0.85), V2(side * 0.76, 0.6), V2(side * 0.7, 1.45)]), .pink,
                                    z: earZ + 0.01, group: 6, innerOutline: false))
                b.parts.append(Part(.capsule(a: b.onHead(V2(side * 0.58, -0.15)), b: b.onHead(V2(side * 0.95, 0.05)), ra: 0.4, rb: 0.25),
                                    .red, z: f.faceZ + 0.05, group: 1, innerOutline: false))
            }
        }
        if !back {
            b.parts.append(Part(headPolygon(b, [V2(-0.55, -0.15), V2(0.55, -0.15), V2(0, -0.95)]), .white, z: f.faceZ + 0.1, group: 1))
            b.parts.append(Part(.ellipse(c: b.onHead(V2(0, -0.78)), r: V2(0.6, 0.45), angle: 0), .dark, z: f.faceZ + 0.2, group: 1))
            b.parts.append(Part(headPolygon(b, [V2(-0.2, 0.55), V2(0.2, 0.55), V2(0, 0.95)]), .purple, z: f.faceZ + 0.1, group: 1,
                                innerOutline: false, fixedTone: .light))
        }
        // The tails fan out like a peacock's train behind the body, or in front of it from the back.
        let flick = sin(pose.t * 4 * .pi)
        let base = f.c + V2(0, -f.r.y * 0.1)
        for i in 0..<7 {
            let fr = Double(i) / 6
            let wag = pose.tail * 0.12 * (i % 2 == 0 ? 1 : -1)
            let start = 0.2 + fr * (.pi - 0.4) + wag - pose.dangle * 0.3 - pose.lying * (fr - 0.5) * 0.6
            let curl = (fr - 0.5) * 0.25
            let mid = abs(fr - 0.5)
            let tail = w4FoxTail(from: base, angle: start, curl: curl, z: (back ? 1.5 : -1.5) - mid + Double(i) * 0.001,
                                 group: -30 - i, bias: back ? 0 : i % 2)
            b.parts += tail.parts
            if i % 2 == 0 && pose.lying == 0 {
                b.parts += w4Wisp(tail.tip + V2(0, 1.2), size: 1.1, flicker: flick * (i % 4 == 0 ? 1 : -1), ramp: .blue, z: 2.5,
                                  group: -50 - i)
            }
        }
        b.topOverride = b.onHead(V2(0, 1.1))
        return b
    }
}

// MARK: - Griffin

extension SpeciesRig {
    fileprivate static func w4Griffin(_ pose: Pose) -> Built {
        var spec = QuadSpec()
        spec.bodyR = V2(7.8, 5.3)
        spec.bodyX = 14
        spec.legLen = 4.2
        spec.legR = (1.9, 1.5)
        spec.legX = (4.8, -5)
        spec.headR = 4.4
        spec.headOffset = V2(7.8, 6.6)
        spec.bellyR = V2(4.5, 2.2)
        let q = quadruped(spec, pose)
        var b = q.built
        // Eagle in front: white feathered head and neck, golden scaly forelegs with talons.
        var front = 0
        b.parts = b.parts.map { part in
            var p = part
            if p.role == .head { p.ramp = .white; p.patterned = false }
            return p
        }
        for part in b.parts where part.role == .limb {
            front += 1
            guard front <= 2, case let .capsule(a, foot, _, rb) = part.shape else { continue }
            let knee = a + (foot - a) * 0.45
            b.parts.append(Part(.capsule(a: knee, b: foot, ra: rb * 0.85, rb: rb * 0.75), .gold, z: part.z + 0.01, group: part.group,
                                toneBias: part.toneBias))
            for dx in [0.6, 1.6] {
                b.parts.append(Part(.polygon([foot + V2(dx - 0.6, 0.2), foot + V2(dx + 0.6, -0.1), foot + V2(dx + 0.3, -1.3)]), .white,
                                    z: part.z + 0.02, group: part.group, toneBias: part.toneBias + 1))
            }
        }
        let neckBase = q.bodyC + rotate(V2(q.bodyR.x * 0.55, q.bodyR.y * 0.35), by: q.angle)
        b.parts.append(Part(.capsule(a: neckBase, b: b.headC + V2(-1, -1.5), ra: 3, rb: 2.4), .white, z: 0.6, group: 1))
        // A ragged ruff where feathers meet fur.
        var ruff: [V2] = [b.headC + V2(-3.5, 0)]
        for k in 0...6 {
            let f = Double(k) / 6
            let p = b.headC + V2(-3.6, -1) + (q.bodyC + rotate(V2(q.bodyR.x * 0.75, -q.bodyR.y * 0.55), by: q.angle) - b.headC
                                              - V2(-3.6, -1)) * f
            ruff.append(p + rotate(V2(k % 2 == 0 ? -1.4 : 0, 0), by: -0.6))
        }
        ruff.append(q.bodyC + rotate(V2(q.bodyR.x, -q.bodyR.y * 0.2), by: q.angle))
        ruff.append(b.headC + V2(1, -2))
        b.parts.append(Part(.polygon(ruff), .white, z: 0.55, group: 1))
        // Feather tufts behind the head and a hooked golden beak.
        for (base, z, bias) in [(V2(-0.8, 0.45), 0.9, 1), (V2(-0.75, 0.15), 1.05, 0)] {
            b.parts.append(Part(headPolygon(b, [base + V2(0.3, 0.35), base + V2(-0.85, 0.85), base + V2(0.1, -0.25)]), .white, z: z,
                                group: 6, toneBias: bias, role: .extremity))
        }
        let open = pose.mouth == .open ? 0.3 : 0
        b.parts.append(Part(headPolygon(b, [V2(0.55, 0.35), V2(1.3, 0.25), V2(1.75, -0.2), V2(1.6, -0.75), V2(1.35, -0.3),
                                            V2(0.6, -0.3)]), .gold, z: 1.3, group: 21))
        b.parts.append(Part(headPolygon(b, [V2(0.65, -0.3), V2(1.3, -0.4 - open), V2(0.7, -0.62 - open * 0.5)]), .gold, z: 1.29,
                            group: 21, toneBias: 1))
        // Lion tail with a tuft.
        let base = q.bodyC + rotate(V2(-q.bodyR.x * 0.88, q.bodyR.y * 0.2), by: q.angle)
        b.parts += w4TuftTail(from: base, angle: 3.6 + pose.tail * 0.3 - pose.dangle * 1.2 - pose.lying * 0.3,
                              curl: -0.35 + pose.tail * 0.1, tuft: .white, z: -1.2)
        // Great wings: folded along the back, swept up when it leaps or strikes.
        let open2 = w4Clamp(pose.wing * 1.2 + pose.dangle * 0.5)
        let wingAngle = w4Mix(.pi - 0.25, 1.65, open2), fan = w4Mix(0.35, 1.2, open2)
        for near in [false, true] {
            let root = q.bodyC + rotate(V2(near ? 1.5 : 0.3, q.bodyR.y * 0.6 + (near ? 0 : 0.6)), by: q.angle)
            b.parts += w4Wing(root: root, angle: wingAngle + (near ? 0 : -0.15), fan: fan, length: 11.5, ramp: .white,
                              covert: .body, z: near ? 0.7 : -1.5, group: near ? -60 : -70, bias: near ? 0 : 1)
        }
        b.eyeX = (0.2, 0.55)
        b.eyeY = 0.25
        b.mouth = V2(3, 3)
        b.cheek = V2(0.25, -0.3)
        return b
    }

    /// Two wings spread up and out either side of `c`, for the front and back views.
    fileprivate static func w4FrontWings(_ c: V2, r: V2, pose: Pose, back: Bool, length: Double, ramp: Ramp, covert: Ramp) -> [Part] {
        var parts: [Part] = []
        let open = w4Clamp(0.45 + pose.wing * 0.6 + pose.dangle * 0.3)
        let lead = w4Mix(1.3, 0.7, open), fan = w4Mix(0.7, 1.3, open)
        for s in [-1.0, 1.0] {
            let root = c + V2(s * 2.4, r.y * 0.45)
            let angle = s > 0 ? lead : .pi - lead
            parts += w4Wing(root: root, angle: angle, fan: fan, turn: -s, length: length, ramp: ramp, covert: covert,
                            z: back ? 0.6 : -1.5, group: s < 0 ? -60 : -70, bias: 0)
        }
        return parts
    }

    fileprivate static func w4GriffinFront(_ pose: Pose, back: Bool) -> Built {
        var s = W4FrontSpec()
        s.bodyR = V2(6.2, 5.4)
        s.headR = 4.4
        s.headY = 6.6
        s.legLen = 4.2
        s.legR = (1.9, 1.5)
        s.legGap = 2.8
        s.chest = .white
        let f = w4Front(s, pose, back: back)
        var b = f.built
        b.parts = b.parts.map { part in
            var p = part
            if p.role == .head { p.ramp = .white; p.patterned = false }
            // The front pair are eagle legs.
            if !back, p.role == .limb, p.group == 3 || p.group == 4, case let .capsule(a, foot, ra, rb) = p.shape {
                p.shape = .capsule(a: a + (foot - a) * 0.3, b: foot, ra: ra * 0.85, rb: rb * 0.85)
                p.ramp = .gold
                p.patterned = false
            }
            return p
        }
        if !back {
            for side in [-1.0, 1.0] {
                b.parts.append(Part(.ellipse(c: f.c + V2(side * s.legGap, -f.r.y * 0.3), r: V2(2.2, 2.4), angle: 0), .white, z: 2.1,
                                    group: side < 0 ? 3 : 4))
            }
            // White ruff over the chest.
            var ruff: [V2] = []
            for k in 0...10 {
                let a = .pi + Double(k) / 10 * .pi
                ruff.append(f.c + V2(0, 1.5) + V2(cos(a) * 4.4, sin(a) * (k % 2 == 0 ? 5 : 3.8)))
            }
            ruff.append(f.c + V2(3.5, 4))
            ruff.append(f.c + V2(-3.5, 4))
            b.parts.append(Part(.polygon(ruff), .white, z: 0.2, group: 0))
        }
        b.parts += w4FrontWings(f.c, r: f.r, pose: pose, back: back, length: 11, ramp: .white, covert: .body)
        let earZ = back ? 0.5 : f.faceZ - 0.1
        for side in [-1.0, 1.0] {
            b.parts.append(Part(headPolygon(b, [V2(side * 0.4, 0.75), V2(side * 0.95, 0.35), V2(side * 1.2, 1.2)]), .white, z: earZ,
                                group: 6, role: .extremity))
        }
        if !back {
            let open = pose.mouth == .open ? 0.25 : 0
            b.parts.append(Part(headPolygon(b, [V2(-0.4, -0.05), V2(0.4, -0.05), V2(0.25, -0.75 - open), V2(0, -1.0 - open),
                                                V2(-0.25, -0.75 - open)]), .gold, z: f.faceZ + 0.2, group: 21))
        }
        let base = f.c + V2(back ? 0 : 3, -f.r.y * 0.1)
        b.parts += w4TuftTail(from: base, angle: back ? -1.2 + pose.tail * 0.3 : 0.9 + pose.tail * 0.3, curl: back ? 0.5 : 0.35,
                              tuft: .white, z: back ? 1.5 : -1)
        b.eyeX = (0.4, 0)
        b.eyeY = 0.2
        return b
    }
}

// MARK: - Pegasus

extension SpeciesRig {
    fileprivate static func w4Pegasus(_ pose: Pose) -> Built {
        var spec = QuadSpec()
        spec.bodyR = V2(8.6, 5.6)
        spec.bodyX = 14
        spec.legLen = 6.6
        spec.legR = (1.7, 1.25)
        spec.legX = (5.5, -5.5)
        spec.headR = 4.2
        spec.headOffset = V2(8.4, 8.6)
        spec.bellyR = V2(4.8, 2.2)
        let q = quadruped(spec, pose)
        var b = q.built
        b.parts += w4Hooves(b.parts)
        // Strong neck and a long muzzle.
        let neckBase = q.bodyC + rotate(V2(q.bodyR.x * 0.6, q.bodyR.y * 0.3), by: q.angle)
        b.parts.append(Part(.capsule(a: neckBase, b: b.headC + V2(-1.5, -1.5), ra: 3, rb: 2.2), .body, z: 0.5, group: 1, patterned: true))
        b.parts.append(Part(.ellipse(c: b.onHead(V2(1.0, -0.5)), r: V2(2.8, 1.9), angle: b.headAngle - 0.35), .body, z: 1.1, group: 1,
                            patterned: true))
        b.parts.append(Part(.ellipse(c: b.onHead(V2(1.6, -0.62)), r: V2(0.6, 0.5), angle: 0), .dark, z: 1.2, group: 1))
        // Upright horse ears.
        for (base, z, bias) in [(V2(-0.6, 0.7), 0.9, 1), (V2(-0.2, 0.8), 1.2, 0)] {
            b.parts.append(Part(headPolygon(b, [base, base + V2(0.45, 0.05), base + V2(0.05, 0.85)]), .body, z: z, group: 6,
                                patterned: true, toneBias: bias, role: .extremity))
        }
        // Flowing mane in locks down the neck, and a long tail.
        let flow = sin(pose.t * 2 * .pi) * 0.6
        for k in 0..<3 {
            let f = Double(k) / 3
            let top = b.onHead(V2(-0.4, 0.95)) + (neckBase + V2(-1.5, 2.5) - b.onHead(V2(-0.4, 0.95))) * f
            b.parts.append(Part(.polygon([top + V2(1, 0.3), top + V2(-1.5, 0.8), top + V2(-4 + flow, -2.5 - f), top + V2(0.5, -3)]),
                                .secondary, z: 1.3 + Double(k) * 0.01, group: 7))
        }
        b.parts.append(Part(headPolygon(b, [V2(-0.2, 0.95), V2(0.6, 0.75), V2(0.15, 0.45)]), .secondary, z: 1.35, group: 22))
        let tailBase = q.bodyC + rotate(V2(-q.bodyR.x * 0.9, q.bodyR.y * 0.4), by: q.angle)
        let sway = pose.tail * 1.5
        b.parts.append(Part(.polygon([tailBase + V2(0.5, 1.2), tailBase + V2(-3.5, 1.5 + sway * 0.5), tailBase + V2(-6 + sway, -3),
                                      tailBase + V2(-5 + sway, -8.5), tailBase + V2(-2.5, -5), tailBase + V2(0.5, -1.2)]), .secondary,
                            z: -1, group: 5))
        // Big white wings that beat on the jump.
        let open = w4Clamp(0.35 + pose.wing * 0.8 + pose.dangle * 0.3 - pose.lying * 0.6)
        let wingAngle = w4Mix(.pi - 0.25, 1.6, open), fan = w4Mix(0.35, 1.2, open)
        for near in [false, true] {
            let root = q.bodyC + rotate(V2(near ? 2 : 0.8, q.bodyR.y * 0.65 + (near ? 0 : 0.6)), by: q.angle)
            b.parts += w4Wing(root: root, angle: wingAngle + (near ? 0 : -0.15), fan: fan, length: 12,
                              z: near ? 0.7 : -1.5, group: near ? -60 : -70, bias: near ? 0 : 1)
        }
        b.eyeX = (0.2, 0.6)
        b.eyeY = 0.2
        b.mouth = V2(1.4, -0.85)
        b.topOverride = b.onHead(V2(-0.3, 1.0))
        return b
    }

    fileprivate static func w4PegasusFront(_ pose: Pose, back: Bool) -> Built {
        var s = W4FrontSpec()
        s.bodyR = V2(5.6, 5)
        s.headR = 4.2
        s.headY = 8.6
        s.legLen = 6.6
        s.legR = (1.6, 1.25)
        s.legGap = 2.4
        let f = w4Front(s, pose, back: back)
        var b = f.built
        b.parts += w4Hooves(b.parts)
        b.parts.append(Part(.capsule(a: f.c + V2(0, f.r.y * 0.4), b: b.headC + V2(0, -2), ra: 2.6, rb: 2.2), .body,
                            z: back ? -0.6 : 0.6, group: 1, patterned: true))
        b.parts += w4FrontWings(f.c, r: f.r, pose: pose, back: back, length: 11.5, ramp: .white, covert: .white)
        let earZ = back ? 0.5 : f.faceZ - 0.1
        for side in [-1.0, 1.0] {
            b.parts.append(Part(headPolygon(b, [V2(side * 0.3, 0.75), V2(side * 0.75, 0.55), V2(side * 0.7, 1.45)]), .body, z: earZ,
                                group: 6, patterned: true, role: .extremity))
        }
        // Forelock and mane.
        let top = b.onHead(V2(0, 0.95))
        b.parts.append(Part(.polygon([top + V2(-2, -0.2), top + V2(2, -0.2), top + V2(1, -2.4), top + V2(-0.6, -1.8)]), .secondary,
                            z: back ? 0.55 : f.faceZ + 0.3, group: 22))
        if back {
            b.parts.append(Part(.polygon([top + V2(-2, 0), top + V2(2, 0), f.c + V2(1.8, f.r.y * 0.6), f.c + V2(-1.8, f.r.y * 0.6)]),
                                .secondary, z: 0.56, group: 22))
        } else {
            b.parts.append(Part(.ellipse(c: b.onHead(V2(0, -0.48)), r: V2(2.4, 1.8), angle: 0), .body, z: f.faceZ + 0.1, group: 1,
                                patterned: true))
            for side in [-1.0, 1.0] {
                b.parts.append(Part(.ellipse(c: b.onHead(V2(side * 0.25, -0.6)), r: V2(0.45, 0.4), angle: 0), .dark, z: f.faceZ + 0.2,
                                    group: 1))
            }
        }
        let tb = f.c + V2(back ? 0 : 3, f.r.y * 0.2)
        let sway = pose.tail * 1.2
        let flip = back ? 0.0 : 1.0
        b.parts.append(Part(.polygon([tb + V2(-1.5, 1), tb + V2(1.5, 1), tb + V2(2 + sway + flip * 2, -6), tb + V2(-1 + sway + flip, -7)]),
                            .secondary, z: back ? 1.5 : -1, group: 5))
        return b
    }
}
