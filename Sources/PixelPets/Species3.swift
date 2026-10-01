import Foundation

// Wave 3 species: hamster, puppy, chick, sheep, snail, koala, panda, squirrel, otter, goat.
// Most share the four-legged frame in Species.swift and add each animal's defining parts; the
// chick and the snail have their own small frames.

extension SpeciesRig {
    /// Side rigs for this wave. Returns nil for any other shape.
    static func buildWave3(_ shape: BodyShape, pose: Pose) -> Built? {
        switch shape {
        case .hamster: return w3Hamster(pose)
        case .puppy: return w3Puppy(pose)
        case .chick: return w3Chick(pose)
        case .sheep: return w3Sheep(pose)
        case .snail: return w3Snail(pose)
        case .koala: return w3Koala(pose)
        case .panda: return w3Panda(pose)
        case .squirrel: return w3Squirrel(pose)
        case .otter: return w3Otter(pose)
        case .goat: return w3Goat(pose)
        default: return nil
        }
    }

    /// Repaints every part with `role` in a fixed ramp (sheep legs, panda legs...).
    fileprivate static func w3Recolor(_ b: inout Built, role: Part.Role, to ramp: Ramp, bias: Int = 0) {
        for i in b.parts.indices where b.parts[i].role == role {
            b.parts[i].ramp = ramp
            b.parts[i].patterned = false
            b.parts[i].toneBias += bias
        }
    }

    /// Hooves or paws capping the end of each leg.
    fileprivate static func w3Feet(_ b: inout Built, ramp: Ramp, scale: Double = 1.15) {
        for part in b.parts where part.role == .limb {
            if case let .capsule(_, f, _, rb) = part.shape {
                b.parts.append(Part(.ellipse(c: f, r: V2(rb * scale, rb * 0.9), angle: 0), ramp, z: part.z + 0.01,
                                    group: part.group, toneBias: part.toneBias))
            }
        }
    }

    // MARK: Hamster

    static func w3Hamster(_ pose: Pose) -> Built {
        var spec = QuadSpec()
        spec.bodyR = V2(7.2, 6.4)
        spec.bodyX = 14.5
        spec.legLen = 1.4
        spec.legR = (1.3, 1.1)
        spec.legX = (4.4, -4.4)
        spec.headR = 5.4
        spec.headOffset = V2(5.2, 2.8)
        spec.bellyR = V2(4.8, 3)
        let q = quadruped(spec, pose)
        var b = q.built
        // Tiny round ears.
        for (c, z, bias) in [(V2(-0.75, 0.75), 0.9, 1), (V2(-0.3, 0.92), 1.2, 0)] {
            b.parts.append(Part(.ellipse(c: b.onHead(c), r: V2(1.6, 1.6), angle: 0), .body, z: z, group: 6, patterned: true,
                                toneBias: bias, role: .extremity))
            b.parts.append(Part(.ellipse(c: b.onHead(c) + V2(0.2, -0.2), r: V2(0.8, 0.8), angle: 0), .pink, z: z + 0.01,
                                group: 6, toneBias: bias, innerOutline: false))
        }
        // Chubby cheek pouch bulging past the jaw, a pale muzzle and a pink nose.
        let puff = pose.mouth == .chew ? 0.3 : 0
        b.parts.append(Part(.ellipse(c: b.onHead(V2(0.3, -0.5)), r: V2(3 + puff, 2.6 + puff), angle: 0), .body, z: 1.1, group: 26,
                            patterned: true, toneBias: -1))
        b.parts.append(Part(.ellipse(c: b.onHead(V2(0.85, -0.3)), r: V2(1.7, 1.3), angle: 0), .white, z: 1.15, group: 26,
                            innerOutline: false))
        b.parts.append(Part(.ellipse(c: b.onHead(V2(1.05, -0.08)), r: V2(0.7, 0.6), angle: 0), .pink, z: 1.2, group: 27))
        // A little nub of a tail.
        b.parts.append(Part(.ellipse(c: q.bodyC + rotate(V2(-q.bodyR.x * 0.98, -0.5), by: q.angle), r: V2(1.2, 1), angle: 0),
                            .body, z: -0.5, group: 5, patterned: true))
        b.eyeX = (0.3, 0.7)
        b.eyeY = 0.2
        b.mouth = V2(0.95, -0.42)
        b.cheek = V2(0.25, -0.5)
        return b
    }

    // MARK: Puppy

    static func w3Puppy(_ pose: Pose) -> Built {
        var spec = QuadSpec()
        spec.bodyR = V2(7.4, 5)
        spec.legLen = 4
        spec.legR = (1.6, 1.3)
        spec.headR = 5.2
        spec.headOffset = V2(7.6, 5.6)
        spec.bellyR = V2(3.8, 2)
        let q = quadruped(spec, pose)
        var b = q.built
        // Muzzle and a big dark nose.
        b.parts.append(Part(.ellipse(c: b.onHead(V2(0.78, -0.38)), r: V2(2.6, 1.8), angle: b.headAngle), .secondary, z: 1.1, group: 1))
        b.parts.append(Part(.ellipse(c: b.onHead(V2(1.32, -0.12)), r: V2(1, 0.75), angle: 0), .dark, z: 1.2, group: 27))
        // Floppy ears hanging down the side of the head; they bounce with the tail.
        let flap = pose.tail * 0.12 + pose.dangle * 0.35 - pose.lying * 0.3
        for (c, z, bias) in [(V2(-0.85, 0.25), 0.9, 1), (V2(-0.4, 0.05), 1.2, 0)] {
            b.parts.append(Part(.ellipse(c: b.onHead(c), r: V2(1.9, 3.4), angle: b.headAngle + 0.3 + flap), .body, z: z, group: 6,
                                patterned: true, toneBias: bias + 1, role: .extremity))
        }
        // Wagging tail held high.
        let base = q.bodyC + rotate(V2(-q.bodyR.x * 0.85, q.bodyR.y * 0.35), by: q.angle)
        b.parts += tail(from: base, angle: 1.9 + pose.tail * 0.55 - pose.dangle * 1.6 - pose.lying * 1.6, curl: -0.3,
                        segments: 3, length: 2.3, radius: (1.2, 0.8), ramp: .body, z: -1)
        b.eyeX = (0.3, 0.72)
        b.eyeY = 0.18
        b.mouth = V2(1.0, -0.6)
        return b
    }

    // MARK: Chick

    static func w3Chick(_ pose: Pose) -> Built {
        var b = Built()
        let squash = pose.squash
        let bodyR = V2(6.4 / squash.squareRoot(), 5.6 * squash)
        let legLen = 1.8 * (1 - pose.lying) * (1 + 0.3 * pose.dangle)
        let angle = pose.lean + pose.sway
        let bodyC = V2(15 + pose.lunge, ground + legLen + bodyR.y * 0.85 + pose.bob + pose.lift)
        b.parts.append(Part(.ellipse(c: bodyC, r: bodyR, angle: angle), .body, z: 0, group: 0, patterned: true, role: .torso))
        // Paler fluffy breast.
        b.parts.append(Part(.ellipse(c: bodyC + rotate(V2(1.8, -1.4), by: angle), r: V2(bodyR.x * 0.58, bodyR.y * 0.6), angle: angle),
                            .body, z: 0.1, group: 0, toneBias: -1))
        // A big round head right on top of the body.
        let headC = bodyC + rotate(V2(2.6, bodyR.y * 0.95), by: angle) + V2(pose.headDip * 0.6, -pose.headDip - pose.lying * 1.5)
        b.headC = headC
        b.headR = 4.7
        b.headAngle = angle * 0.5 + pose.headTilt
        b.parts.append(Part(.ellipse(c: headC, r: V2(4.8, 4.7), angle: b.headAngle), .body, z: 1, group: 1, patterned: true,
                            role: .head))
        // Fluffy tuft on top.
        let tuftRoot = b.onHead(V2(-0.15, 0.85))
        for (a, l) in [(1.2, 2.4), (1.75, 2.8), (2.3, 2.0)] {
            let dir = a + pose.headTilt + sin(pose.t * 2 * .pi) * 0.08
            b.parts.append(Part(.capsule(a: tuftRoot, b: tuftRoot + V2(cos(dir), sin(dir)) * l, ra: 0.7, rb: 0.4), .body, z: 0.95,
                                group: 1, role: .extremity))
        }
        // Little beak.
        let open = pose.mouth == .open ? 0.3 : 0
        b.parts.append(Part(headPolygon(b, [V2(0.82, 0.02), V2(1.45, -0.18 + open * 0.3), V2(0.84, -0.32)]), .gold, z: 1.3, group: 27))
        b.parts.append(Part(headPolygon(b, [V2(0.84, -0.28), V2(1.3, -0.36 - open), V2(0.84, -0.5)]), .gold, z: 1.29, group: 27,
                            toneBias: 1))
        // Stubby wing that flaps.
        b.parts.append(Part(.ellipse(c: bodyC + rotate(V2(-1.2, 0.2 + pose.wing * 0.9), by: angle), r: V2(3.1, 2.1),
                                     angle: angle - 0.45 + pose.wing * 0.8), .body, z: 0.5, group: 7, role: .extremity))
        // Tail fluff
        b.parts.append(Part(.polygon([bodyC + rotate(V2(-5, 1), by: angle), bodyC + rotate(V2(-8.2, 2.6 + pose.tail * 0.6), by: angle),
                                      bodyC + rotate(V2(-6, -1.2), by: angle)]), .body, z: -1, group: 5, patterned: true,
                            role: .extremity))
        // Thin orange legs with three-toed feet.
        for near in [true, false] {
            let hip = bodyC + rotate(V2(near ? 1 : -1, -bodyR.y * 0.8), by: angle)
            let swing = pose.stride * (near ? 1 : -1)
            var foot = V2(hip.x + swing * 1.5, ground + 0.5 + pose.lift)
            if pose.dangle > 0 { foot = hip + V2(0.3, -legLen * 1.2 - 1) }
            if pose.lying > 0 { foot = hip + V2(1, -0.4) }
            let z = near ? 2.0 : -2.0
            if legLen > 0.5 {
                b.parts.append(Part(.capsule(a: hip, b: foot, ra: 0.6, rb: 0.5), .gold, z: z, group: near ? 3 : 4,
                                    toneBias: near ? 0 : 1, innerOutline: false))
            }
            b.parts.append(Part(.ellipse(c: foot + V2(1, 0), r: V2(1.7, 0.7), angle: 0), .gold, z: z, group: near ? 3 : 4,
                                toneBias: near ? 0 : 1))
        }
        b.eyeX = (0.3, 0.7)
        b.eyeY = 0.18
        b.mouth = V2(2, 2) // the beak is the mouth
        return b
    }

    // MARK: Sheep

    static func w3Sheep(_ pose: Pose) -> Built {
        var spec = QuadSpec()
        spec.bodyR = V2(7.8, 5.4)
        spec.legLen = 3.8
        spec.legR = (1.1, 0.95)
        spec.legX = (4.6, -4.6)
        spec.headR = 4.1
        spec.headOffset = V2(8.4, 4.4)
        let q = quadruped(spec, pose)
        var b = q.built
        b.parts.removeAll { $0.ramp == .secondary } // no belly: it's all wool
        // Dark legs and a dusky face (stone, so the eyes still show).
        w3Recolor(&b, role: .limb, to: .dark)
        w3Recolor(&b, role: .head, to: .stone, bias: 1)
        w3Feet(&b, ramp: .dark, scale: 1.1)
        // Wool: a ring of puffs around the body makes a scalloped cloud, with a few curls inside.
        for k in 0..<12 {
            let a = Double(k) / 12 * 2 * .pi + 0.2
            let v = V2(cos(a) * q.bodyR.x * 0.86, sin(a) * q.bodyR.y * 0.84)
            b.parts.append(Part(.ellipse(c: q.bodyC + rotate(v, by: q.angle), r: V2(2.7, 2.5), angle: 0), .body, z: 0.05, group: 0,
                                patterned: true, role: .torso))
        }
        for v in [V2(-3.5, 2), V2(0, 2.8), V2(3, 1.6), V2(-1.5, -0.5), V2(2, -1.5)] {
            b.parts.append(Part(.ring(c: q.bodyC + rotate(v, by: q.angle), r: V2(1.1, 0.9), width: 0.55), .body, z: 0.06, group: 0,
                                toneBias: 1, innerOutline: false))
        }
        // Woolly cap on the head.
        for (c, r) in [(V2(-0.45, 0.7), 2.3), (V2(0.15, 0.9), 1.9)] {
            b.parts.append(Part(.ellipse(c: b.onHead(c), r: V2(r, r * 0.9), angle: 0), .body, z: 1.15, group: 28, patterned: true))
        }
        // Ears sticking out sideways.
        for (c, z, bias) in [(V2(-0.95, 0.15), 0.9, 1), (V2(-0.55, 0.05), 1.2, 0)] {
            b.parts.append(Part(.ellipse(c: b.onHead(c), r: V2(2, 0.85), angle: b.headAngle - 0.45 - pose.dangle * 0.4), .stone, z: z,
                                group: 6, toneBias: bias + 1, role: .extremity))
        }
        // Wool puff of a tail.
        b.parts.append(Part(.ellipse(c: q.bodyC + rotate(V2(-q.bodyR.x - 0.8, q.bodyR.y * 0.3 + pose.tail * 0.3), by: q.angle),
                                     r: V2(1.8, 1.8), angle: 0), .body, z: -0.5, group: 5, patterned: true))
        b.eyeX = (0.3, 0.7)
        b.eyeY = 0.1
        b.mouth = V2(0.85, -0.6)
        b.topOverride = b.onHead(V2(-0.2, 1.3))
        return b
    }

    // MARK: Snail

    static func w3Snail(_ pose: Pose) -> Built {
        var b = Built()
        let squash = pose.squash
        // The foot stretches and bunches as it glides.
        let stretch = 1 + 0.07 * pose.stride
        let angle = pose.sway + pose.lean * 0.4
        let footC = V2(15 + pose.lunge, ground + 2.3 * squash + pose.lift + pose.dangle * 2)
        let footR = V2(9.5 * stretch / squash.squareRoot(), 2.3 * squash)
        b.parts.append(Part(.ellipse(c: footC, r: footR, angle: angle), .body, z: 0, group: 0, patterned: true, role: .torso))
        b.parts.append(Part(.capsule(a: footC + rotate(V2(-footR.x * 0.6, 0), by: angle),
                                     b: footC + rotate(V2(-footR.x - 2.5, -1.2 + pose.dangle * -2), by: angle), ra: 2.1, rb: 0.6),
                            .body, z: 0, group: 0, patterned: true, role: .torso))
        // Neck rising to the head; it tucks into the shell when asleep.
        let tuck = pose.lying
        let headC = footC + rotate(V2(footR.x * 0.85 - tuck * 3.5, 5.2 * squash - tuck * 2.2), by: angle)
            + V2(pose.headDip * 0.5, -pose.headDip)
        b.headC = headC
        b.headR = 4
        b.headAngle = angle * 0.5 + pose.headTilt
        b.parts.append(Part(.capsule(a: footC + rotate(V2(footR.x * 0.5, 0.5), by: angle), b: headC + V2(-0.4, -2), ra: 2.3, rb: 2.6),
                            .body, z: 0.5, group: 0, patterned: true))
        b.parts.append(Part(.ellipse(c: headC, r: V2(4.1, 4), angle: b.headAngle), .body, z: 1, group: 1, patterned: true, role: .head))
        // Two antennae with knobbly tips.
        let wiggle = sin(pose.t * 2 * .pi) * 0.12
        for (x, z, bias, lean) in [(-0.35, 0.9, 1, 0.45), (0.1, 1.2, 0, 0.15)] {
            let root = b.onHead(V2(x, 0.8))
            let dir = .pi / 2 - lean + wiggle - pose.tail * 0.05 + tuck * 0.6
            let tip = root + V2(cos(dir), sin(dir)) * (3.6 - tuck * 1.5)
            b.parts.append(Part(.capsule(a: root, b: tip, ra: 0.55, rb: 0.45), .body, z: z, group: 6, toneBias: bias, role: .extremity))
            b.parts.append(Part(.ellipse(c: tip, r: V2(1, 1), angle: 0), .body, z: z + 0.01, group: 6, toneBias: bias, role: .extremity))
        }
        // The big spiral shell on its back.
        let shellC = footC + rotate(V2(-1.8, 6.8 * squash), by: angle)
        b.parts.append(Part(.ellipse(c: shellC, r: V2(6.6, 6.4) * squash.squareRoot(), angle: angle), .secondary, z: 1.5, group: 7))
        b.parts += w3Spiral(at: shellC + V2(0.6, -0.4), radius: 5.2, z: 1.6, group: 8, turns: 1.7, phase: angle)
        b.eyeX = (0.35, 0.75)
        b.eyeY = 0.1
        b.mouth = V2(0.85, -0.45)
        b.cheek = V2(0.3, -0.4)
        return b
    }

    /// A spiral line drawn as a chain of thin capsules; each capsule is all edge, so it renders as a dark line.
    fileprivate static func w3Spiral(at c: V2, radius: Double, z: Double, group: Int, turns: Double, phase: Double,
                                     ramp: Ramp = .secondary) -> [Part] {
        var parts: [Part] = []
        let steps = Int(turns * 18)
        let total = turns * 2 * .pi
        func point(_ i: Int) -> V2 {
            let t = Double(i) / Double(steps)
            let a = phase + .pi * 0.9 - t * total
            return c + V2(cos(a), sin(a)) * radius * (1 - t * 0.85)
        }
        for i in 0..<steps {
            parts.append(Part(.capsule(a: point(i), b: point(i + 1), ra: 0.4, rb: 0.4), ramp, z: z, group: group))
        }
        return parts
    }

    // MARK: Koala

    static func w3Koala(_ pose: Pose) -> Built {
        var spec = QuadSpec()
        spec.bodyR = V2(7.6, 6)
        spec.legLen = 2.8
        spec.legR = (2, 1.8)
        spec.legX = (4.4, -4.6)
        spec.headR = 5.6
        spec.headOffset = V2(6.8, 6.2)
        spec.bellyR = V2(4.6, 2.8)
        let q = quadruped(spec, pose)
        var b = q.built
        // Big fluffy ears with white tufts, poking out past the head.
        for (c, z, bias) in [(V2(-0.95, 0.55), 0.9, 1), (V2(-0.35, 0.82), 1.2, 0)] {
            let ec = b.onHead(c)
            b.parts.append(Part(.ellipse(c: ec, r: V2(3.4, 3.2), angle: 0), .body, z: z, group: 6, patterned: true,
                                toneBias: bias, role: .extremity))
            for (k, a) in [0.6, 1.4, 2.2, 3.0].enumerated() where bias == 0 || k > 1 {
                b.parts.append(Part(.ellipse(c: ec + V2(cos(a), sin(a)) * 2.9, r: V2(1.2, 1.2), angle: 0), .body, z: z,
                                    group: 6, patterned: true, toneBias: bias, role: .extremity))
            }
            b.parts.append(Part(.ellipse(c: ec + V2(0.3, -0.1), r: V2(1.9, 1.9), angle: 0), .white, z: z + 0.01, group: 6,
                                toneBias: bias, innerOutline: false))
        }
        // The big dark nose.
        b.parts.append(Part(.ellipse(c: b.onHead(V2(0.88, -0.22)), r: V2(1.6, 2.2), angle: b.headAngle), .dark, z: 1.2, group: 27))
        b.eyeX = (0.15, 0.55)
        b.eyeY = 0.2
        b.mouth = V2(0.75, -0.72)
        b.cheek = V2(0.15, -0.35)
        return b
    }

    // MARK: Panda

    static func w3Panda(_ pose: Pose) -> Built {
        var spec = QuadSpec()
        spec.bodyR = V2(8.4, 6)
        spec.legLen = 3
        spec.legR = (2.3, 2.1)
        spec.legX = (4.8, -5)
        spec.headR = 5.6
        spec.headOffset = V2(7.4, 6)
        let q = quadruped(spec, pose)
        var b = q.built
        b.parts.removeAll { $0.ramp == .secondary }
        w3Recolor(&b, role: .limb, to: .dark)
        // A dark band over the shoulders.
        b.parts.append(Part(.capsule(a: q.bodyC + rotate(V2(2.4, q.bodyR.y * 0.8), by: q.angle),
                                     b: q.bodyC + rotate(V2(4.4, -q.bodyR.y * 0.45), by: q.angle), ra: 2.9, rb: 2.6), .dark,
                            z: 0.2, group: 0))
        // Round dark ears.
        for (c, z, bias) in [(V2(-0.65, 0.78), 0.9, 1), (V2(0.15, 0.95), 1.2, 0)] {
            b.parts.append(Part(.ellipse(c: b.onHead(c), r: V2(2.1, 2.1), angle: 0), .dark, z: z, group: 6, toneBias: bias,
                                role: .extremity))
        }
        // Eye patch, muzzle and nose.
        b.parts.append(Part(.ellipse(c: b.onHead(V2(0.45, 0.08)), r: V2(1.5, 1.9), angle: b.headAngle - 0.6), .dark, z: 1.05,
                            group: 1, toneBias: -1))
        b.parts.append(Part(.ellipse(c: b.onHead(V2(0.85, -0.42)), r: V2(2.2, 1.6), angle: b.headAngle), .body, z: 1.1, group: 1,
                            toneBias: -1))
        b.parts.append(Part(.ellipse(c: b.onHead(V2(1.2, -0.22)), r: V2(0.9, 0.65), angle: 0), .dark, z: 1.2, group: 27))
        b.parts.append(Part(.ellipse(c: q.bodyC + rotate(V2(-q.bodyR.x * 0.95, q.bodyR.y * 0.2), by: q.angle), r: V2(1.6, 1.6),
                                     angle: 0), .body, z: -1, group: 5, patterned: true))
        b.eyeX = (0.3, 0.6)
        b.eyeY = 0.1
        b.mouth = V2(1.0, -0.62)
        b.cheek = V2(0.3, -0.45)
        return b
    }

    // MARK: Squirrel

    static func w3Squirrel(_ pose: Pose) -> Built {
        var spec = QuadSpec()
        spec.bodyR = V2(6, 4.8)
        spec.bodyX = 17
        spec.legLen = 2.6
        spec.legR = (1.2, 1)
        spec.legX = (3.4, -3.4)
        spec.headR = 4.6
        spec.headOffset = V2(6, 4.8)
        spec.bellyR = V2(3, 1.8)
        let q = quadruped(spec, pose)
        var b = q.built
        // Tufted pointy ears.
        for (pts, z, bias) in [([V2(-0.7, 0.55), V2(-0.15, 0.85), V2(-0.6, 1.5)], 0.9, 1),
                               ([V2(-0.1, 0.85), V2(0.45, 0.65), V2(0.1, 1.55)], 1.2, 0)] {
            b.parts.append(Part(headPolygon(b, pts), .body, z: z, group: 6, patterned: true, toneBias: bias, role: .extremity))
        }
        // Short snout with a dark nose.
        b.parts.append(Part(.ellipse(c: b.onHead(V2(0.85, -0.3)), r: V2(1.8, 1.4), angle: b.headAngle), .body, z: 1.1, group: 1,
                            patterned: true))
        b.parts.append(Part(.ellipse(c: b.onHead(V2(1.22, -0.18)), r: V2(0.6, 0.5), angle: 0), .dark, z: 1.2, group: 27))
        // Big bushy tail curling up behind in an S.
        let base = q.bodyC + rotate(V2(-q.bodyR.x * 0.8, -0.5), by: q.angle)
        let droop = pose.dangle * 1.4 + pose.lying * 0.5
        let angles = [2.3 - droop, 1.75 - droop * 0.6, 1.5 - droop * 0.3, 0.7, -0.5].map { $0 + pose.tail * 0.12 }
        let radii = [2.2, 2.7, 3.0, 2.9, 2.3]
        var p = base
        for (i, a) in angles.enumerated() {
            let next = p + rotate(V2(3.1, 0), by: a)
            b.parts.append(Part(.ellipse(c: (p + next) / 2, r: V2(2.8, radii[i]), angle: a), .body, z: -1 - Double(i) * 0.01,
                                group: 5, patterned: true, role: .extremity))
            p = next
        }
        b.mouth = V2(1.0, -0.55)
        b.eyeX = (0.3, 0.72)
        b.eyeY = 0.2
        b.cheek = V2(0.3, -0.35)
        return b
    }

    // MARK: Otter

    static func w3Otter(_ pose: Pose) -> Built {
        var spec = QuadSpec()
        spec.bodyR = V2(9.4, 3.9)
        spec.bodyX = 15.5
        spec.legLen = 2.2
        spec.legR = (1.3, 1.1)
        spec.legX = (5.6, -5.8)
        spec.headR = 4
        spec.headOffset = V2(9.6, 3.4)
        spec.bellyR = V2(6, 1.6)
        let q = quadruped(spec, pose)
        var b = q.built
        // Neck
        b.parts.append(Part(.capsule(a: q.bodyC + rotate(V2(q.bodyR.x * 0.6, 0.4), by: q.angle), b: b.headC + V2(-1.2, -1),
                                     ra: 3.2, rb: 3), .body, z: 0.5, group: 0, patterned: true))
        // Small round ears.
        for (c, z, bias) in [(V2(-0.75, 0.6), 0.9, 1), (V2(-0.4, 0.82), 1.2, 0)] {
            b.parts.append(Part(.ellipse(c: b.onHead(c), r: V2(1.1, 1.1), angle: 0), .body, z: z, group: 6, toneBias: bias,
                                role: .extremity))
        }
        // Pale whiskery muzzle and nose.
        b.parts.append(Part(.ellipse(c: b.onHead(V2(0.78, -0.38)), r: V2(2.3, 1.7), angle: b.headAngle), .secondary, z: 1.1, group: 1))
        b.parts.append(Part(.ellipse(c: b.onHead(V2(1.3, -0.1)), r: V2(0.85, 0.65), angle: 0), .dark, z: 1.2, group: 27))
        let root = b.onHead(V2(1.05, -0.4))
        for a in [0.35, 0.0, -0.35] {
            b.parts.append(Part(.capsule(a: root, b: root + rotate(V2(2.8, 0), by: a + b.headAngle), ra: 0.22, rb: 0.2), .dark,
                                z: 1.3, group: 29, innerOutline: false))
        }
        // Long flat tail tapering to a point.
        let base = q.bodyC + rotate(V2(-q.bodyR.x * 0.8, 0), by: q.angle)
        b.parts += tail(from: base, angle: 3.3 + pose.tail * 0.12 - pose.dangle * 1.2 + pose.lying * 0.1, curl: -0.08,
                        segments: 2, length: 4.4, radius: (2.6, 0.7), ramp: .body, z: -1)
        b.eyeX = (0.3, 0.7)
        b.eyeY = 0.22
        b.mouth = V2(1.0, -0.62)
        b.cheek = V2(0.3, -0.3)
        return b
    }

    // MARK: Goat

    static func w3Goat(_ pose: Pose) -> Built {
        var spec = QuadSpec()
        spec.bodyR = V2(7.6, 5)
        spec.bodyX = 14
        spec.legLen = 5.2
        spec.legR = (1.3, 1.0)
        spec.legX = (5, -5)
        spec.headR = 4.2
        spec.headOffset = V2(8.2, 7.6)
        spec.bellyR = V2(4, 1.8)
        let q = quadruped(spec, pose)
        var b = q.built
        w3Feet(&b, ramp: .dark)
        // Neck
        let neckBase = q.bodyC + rotate(V2(q.bodyR.x * 0.6, q.bodyR.y * 0.3), by: q.angle)
        b.parts.append(Part(.capsule(a: neckBase, b: b.headC + V2(-1.5, -1.5), ra: 2.6, rb: 2), .body, z: 0.5, group: 1,
                            patterned: true))
        // Long muzzle with a little nose, and a beard under the chin.
        b.parts.append(Part(.ellipse(c: b.onHead(V2(0.95, -0.42)), r: V2(2.6, 1.7), angle: b.headAngle - 0.35), .body, z: 1.1,
                            group: 1, patterned: true))
        b.parts.append(Part(.ellipse(c: b.onHead(V2(1.5, -0.45)), r: V2(0.55, 0.45), angle: 0), .dark, z: 1.2, group: 27))
        b.parts.append(Part(headPolygon(b, [V2(0.55, -0.75), V2(1.1, -0.85), V2(0.75, -1.65)]), .body, z: 1.12, group: 26,
                            toneBias: 1))
        // Ears out to the side.
        for (c, z, bias) in [(V2(-0.95, 0.35), 0.9, 1), (V2(-0.6, 0.3), 1.2, 0)] {
            b.parts.append(Part(.ellipse(c: b.onHead(c), r: V2(2.2, 0.9), angle: b.headAngle - 0.35), .body, z: z, group: 6,
                                patterned: true, toneBias: bias, role: .extremity))
        }
        // Small horns curving back.
        for (x, z, bias) in [(-0.45, 0.85, 1), (-0.05, 1.25, 0)] {
            let r = b.onHead(V2(x, 0.82))
            let mid = r + rotate(V2(-0.4, 2.2), by: b.headAngle)
            let tip = mid + rotate(V2(-1.7, 1.0), by: b.headAngle)
            b.parts.append(Part(.capsule(a: r, b: mid, ra: 1.0, rb: 0.75), .stone, z: z, group: 28, toneBias: bias))
            b.parts.append(Part(.capsule(a: mid, b: tip, ra: 0.75, rb: 0.4), .stone, z: z, group: 28, toneBias: bias))
        }
        // Short tail flicked up.
        let tailBase = q.bodyC + rotate(V2(-q.bodyR.x * 0.92, q.bodyR.y * 0.5), by: q.angle)
        b.parts.append(Part(.ellipse(c: tailBase + V2(-0.6, 0.8 + pose.tail * 0.4), r: V2(1, 1.8), angle: -0.5 - pose.dangle),
                            .body, z: -0.5, group: 5, patterned: true))
        b.eyeX = (0.2, 0.6)
        b.eyeY = 0.2
        b.mouth = V2(1.3, -0.78)
        b.topOverride = b.onHead(V2(-0.3, 1.0))
        return b
    }

    // MARK: Front and back views

    private static let w3BusyKey = "PixelPets.w3FrontalBusy"

    /// Fully custom front or back views, for animals the shared FrontProfile can't express.
    /// Returns nil to use the profile from `FrontProfile.wave3`.
    static func frontalWave3(_ shape: BodyShape, pose: Pose, back: Bool) -> Built? {
        if shape == .snail { return w3SnailFront(pose, back: back) }
        // The rest start from the shared profile rig and add their own features. `frontal` calls
        // back into this function, so a per-thread flag lets the inner call fall through.
        guard FrontProfile.wave3(shape) != nil else { return nil }
        let flags = Thread.current.threadDictionary
        if flags[w3BusyKey] != nil { return nil }
        flags[w3BusyKey] = true
        defer { flags.removeObject(forKey: w3BusyKey) }
        var b = frontal(shape, pose: pose, back: back)
        w3FrontFeatures(&b, shape, pose: pose, back: back)
        return b
    }

    private static func w3FrontFeatures(_ b: inout Built, _ shape: BodyShape, pose: Pose, back: Bool) {
        guard let torso = b.parts.first(where: { $0.role == .torso }), case let .ellipse(c, bodyR, _) = torso.shape else { return }
        let faceZ = back ? -0.5 : 1.0
        let earZ = back ? 0.5 : faceZ - 0.1
        func sym(_ f: (Double) -> Void) { f(-1); f(1) }
        func nose(_ ramp: Ramp, _ y: Double, _ r: V2) {
            if !back {
                b.parts.append(Part(.ellipse(c: b.onHead(V2(0, y)), r: r, angle: 0), ramp, z: faceZ + 0.2, group: 27))
            }
        }
        switch shape {
        case .hamster:
            if !back {
                sym { s in
                    b.parts.append(Part(.ellipse(c: b.onHead(V2(s * 0.62, -0.45)), r: V2(2.8, 2.4), angle: 0), .body, z: faceZ + 0.05,
                                        group: 26, patterned: true))
                }
                b.parts.append(Part(.ellipse(c: b.onHead(V2(0, -0.45)), r: V2(1.6, 1.3), angle: 0), .white, z: faceZ + 0.1,
                                    group: 26, innerOutline: false))
            } else {
                b.parts.append(Part(.ellipse(c: c + V2(0, -bodyR.y * 0.35), r: V2(1.1, 1), angle: 0), .body, z: 1.5, group: 5,
                                    patterned: true))
            }
            nose(.pink, -0.22, V2(0.75, 0.6))
        case .puppy:
            let flap = pose.tail * 0.1 + pose.dangle * 0.3
            sym { s in
                b.parts.append(Part(.ellipse(c: b.onHead(V2(s * 0.95, 0.2)), r: V2(1.8, 3.3), angle: s * (0.25 + flap)), .body,
                                    z: back ? 0.5 : faceZ + 0.15, group: 6, patterned: true, toneBias: 1, role: .extremity))
            }
            nose(.dark, -0.28, V2(1.1, 0.8))
        case .chick:
            w3Recolor(&b, role: .extremity, to: .body)
            for i in b.parts.indices where b.parts[i].ramp == .secondary {
                b.parts[i].ramp = .body
                b.parts[i].toneBias = -1
            }
            let root = b.onHead(V2(0, 0.85))
            for a in [1.2, 1.57, 1.95] {
                b.parts.append(Part(.capsule(a: root, b: root + V2(cos(a), sin(a)) * 2.5, ra: 0.7, rb: 0.4), .body,
                                    z: back ? 0.4 : faceZ - 0.05, group: 1))
            }
        case .sheep:
            w3Recolor(&b, role: .limb, to: .dark)
            w3Recolor(&b, role: .head, to: .stone, bias: 1)
            w3Recolor(&b, role: .extremity, to: .stone, bias: 1)
            b.parts.removeAll { $0.ramp == .secondary }
            w3Feet(&b, ramp: .dark, scale: 1.1)
            for k in 0..<12 {
                let a = Double(k) / 12 * 2 * .pi + 0.26
                b.parts.append(Part(.ellipse(c: c + V2(cos(a) * bodyR.x * 0.86, sin(a) * bodyR.y * 0.84), r: V2(2.6, 2.4), angle: 0),
                                    .body, z: 0.05, group: 0, patterned: true, role: .torso))
            }
            for v in [V2(-3, 1.5), V2(2.5, 2), V2(0, -1), V2(-2.5, -2.5), V2(3, -2)] {
                b.parts.append(Part(.ring(c: c + v, r: V2(1.1, 0.9), width: 0.55), .body, z: 0.06, group: 0, toneBias: 1,
                                    innerOutline: false))
            }
            for (x, y, r) in [(-0.45, 0.7, 2.1), (0.45, 0.7, 2.1), (0, 0.9, 2.2)] {
                b.parts.append(Part(.ellipse(c: b.onHead(V2(x, y)), r: V2(r, r * 0.9), angle: 0), .body,
                                    z: back ? faceZ + 0.1 : faceZ + 0.15, group: 28, patterned: true))
            }
            if back {
                b.parts.append(Part(.ellipse(c: c + V2(0, -bodyR.y * 0.2), r: V2(1.8, 1.8), angle: 0), .body, z: 1.5, group: 5,
                                    patterned: true))
            }
        case .koala:
            sym { s in
                let ec = b.onHead(V2(s * 0.95, 0.6))
                b.parts.append(Part(.ellipse(c: ec, r: V2(3.3, 3.1), angle: 0), .body, z: earZ, group: 6, patterned: true,
                                    role: .extremity))
                for a in [0.3, 0.9, 1.5] {
                    let d = V2(s * cos(a), sin(a))
                    b.parts.append(Part(.ellipse(c: ec + d * 2.9, r: V2(1.2, 1.2), angle: 0), .body, z: earZ, group: 6,
                                        patterned: true, role: .extremity))
                }
                if !back {
                    b.parts.append(Part(.ellipse(c: ec + V2(s * 0.3, -0.2), r: V2(1.9, 1.9), angle: 0), .white, z: earZ + 0.01,
                                        group: 6, innerOutline: false))
                }
            }
            nose(.dark, -0.28, V2(1.6, 2.1))
        case .panda:
            w3Recolor(&b, role: .limb, to: .dark)
            b.parts.append(Part(.capsule(a: c + V2(-bodyR.x * 0.75, bodyR.y * 0.35), b: c + V2(bodyR.x * 0.75, bodyR.y * 0.35),
                                         ra: 2.6, rb: 2.6), .dark, z: back ? 0.3 : 0.05, group: 0))
            sym { s in
                b.parts.append(Part(.ellipse(c: b.onHead(V2(s * 0.75, 0.78)), r: V2(2.1, 2.1), angle: 0), .dark, z: earZ, group: 6,
                                    role: .extremity))
                if !back {
                    b.parts.append(Part(.ellipse(c: b.onHead(V2(s * 0.42, 0.06)), r: V2(1.5, 1.9), angle: s * 0.5), .dark,
                                        z: faceZ + 0.05, group: 1, toneBias: -1))
                }
            }
            if !back {
                b.parts.append(Part(.ellipse(c: b.onHead(V2(0, -0.45)), r: V2(2.2, 1.6), angle: 0), .body, z: faceZ + 0.1, group: 1,
                                    toneBias: -1))
            }
            nose(.dark, -0.3, V2(0.9, 0.65))
        case .squirrel:
            // The big bushy tail rises behind the body; from the back it covers most of it.
            let sway = pose.tail * 0.6
            let x0 = back ? sway : 3.5
            let pts = back ? [V2(0, -1), V2(0.4, 3), V2(0.4, 7), V2(-1.6, 10.5), V2(-3.6, 11.5)]
                : [V2(0, 0), V2(1.4, 3.5), V2(1.8, 7), V2(0.6, 10.3), V2(-1.4, 11.6)]
            for (i, v) in pts.enumerated() {
                let r = [2.8, 3.3, 3.3, 3.0, 2.3][i]
                b.parts.append(Part(.ellipse(c: c + V2(x0 + v.x + sway * Double(i) * 0.2, v.y), r: V2(r, r), angle: 0), .body,
                                    z: back ? 1.5 : -1, group: 5, patterned: true, role: .extremity))
            }
        case .otter:
            sym { s in
                b.parts.append(Part(.ellipse(c: b.onHead(V2(s * 0.85, 0.62)), r: V2(1.2, 1.2), angle: 0), .body, z: earZ, group: 6,
                                    role: .extremity))
                if !back {
                    let root = b.onHead(V2(s * 0.42, -0.45))
                    for a in [0.3, -0.05] {
                        b.parts.append(Part(.capsule(a: root, b: root + V2(s * cos(a), sin(a)) * 3.2, ra: 0.22, rb: 0.2), .dark,
                                            z: faceZ + 0.3, group: 29, innerOutline: false))
                    }
                }
            }
            nose(.dark, -0.22, V2(0.95, 0.7))
            if back {
                b.parts += tail(from: c + V2(0, -bodyR.y * 0.2), angle: -1.3 + pose.tail * 0.2, curl: 0.15, segments: 2, length: 3.6,
                                radius: (2.4, 0.8), ramp: .body, z: 1.5)
            }
        case .goat:
            w3Feet(&b, ramp: .dark)
            sym { s in
                let r = b.onHead(V2(s * 0.42, 0.8))
                let mid = r + V2(s * 0.7, 2.2)
                b.parts.append(Part(.capsule(a: r, b: mid, ra: 1.0, rb: 0.75), .stone, z: back ? 0.6 : faceZ + 0.1, group: 28))
                b.parts.append(Part(.capsule(a: mid, b: mid + V2(s * 1.6, 0.8), ra: 0.75, rb: 0.4), .stone,
                                    z: back ? 0.6 : faceZ + 0.1, group: 28))
            }
            if !back {
                b.parts.append(Part(headPolygon(b, [V2(-0.3, -0.8), V2(0.3, -0.8), V2(0, -1.55)]), .body, z: faceZ + 0.15, group: 26,
                                    toneBias: 1))
            }
            nose(.dark, -0.35, V2(0.7, 0.5))
        default:
            break
        }
    }

    /// The snail head-on: a foot along the ground, its head up front, and the shell behind.
    /// From the back the spiral shell fills the view.
    static func w3SnailFront(_ pose: Pose, back: Bool) -> Built {
        var b = Built()
        let squash = pose.squash
        let angle = pose.sway
        let base = V2(16, ground + pose.lift + pose.dangle * 2)
        let faceZ = back ? -0.5 : 1.0
        b.parts.append(Part(.ellipse(c: base + V2(0, 2.2 * squash), r: V2(5.2 / squash.squareRoot(), 2.2 * squash), angle: angle),
                            .body, z: 0, group: 0, patterned: true, role: .torso))
        // From the front the shell rises behind the head like a dome; from the back its spiral shows.
        let shellC = base + V2(0, (back ? 9 : 11.5) * squash)
        b.parts.append(Part(.ellipse(c: shellC, r: (back ? V2(7.2, 7) : V2(5.6, 6.8)) * squash.squareRoot(), angle: angle), .secondary,
                            z: back ? 1.5 : -1, group: 7, toneBias: back ? 0 : 1))
        if back {
            b.parts += w3Spiral(at: shellC + V2(0.4, -0.3), radius: 5.8, z: 1.6, group: 8, turns: 1.7, phase: angle)
        }
        let tuck = pose.lying
        let headC = base + V2(0, 8.5 * squash - tuck * 3) + V2(0, -pose.headDip)
        b.headC = headC
        b.headR = 4.2
        b.headAngle = angle * 0.6 + pose.headTilt
        b.headZ = faceZ
        b.parts.append(Part(.capsule(a: base + V2(0, 2.5), b: headC + V2(0, -2), ra: 3, rb: 3), .body, z: back ? -0.6 : 0.5,
                            group: 0, patterned: true))
        b.parts.append(Part(.ellipse(c: headC, r: V2(4.4, 4.2), angle: b.headAngle), .body, z: faceZ, group: 1, patterned: true,
                            role: .head))
        let wiggle = sin(pose.t * 2 * .pi) * 0.1
        for s in [-1.0, 1.0] {
            let root = b.onHead(V2(s * 0.4, 0.8))
            let dir = .pi / 2 - s * (0.4 + wiggle) - s * tuck * 0.6
            let tip = root + V2(cos(dir), sin(dir)) * (3.6 - tuck * 1.5)
            b.parts.append(Part(.capsule(a: root, b: tip, ra: 0.55, rb: 0.45), .body, z: back ? 0.4 : faceZ - 0.1, group: 6,
                                role: .extremity))
            b.parts.append(Part(.ellipse(c: tip, r: V2(1, 1), angle: 0), .body, z: back ? 0.4 : faceZ - 0.1, group: 6,
                                role: .extremity))
        }
        b.eyeX = (0.42, 0)
        b.eyeY = 0.12
        return b
    }
}

extension FrontProfile {
    /// Front and back profiles for this wave.
    static func wave3(_ shape: BodyShape) -> FrontProfile? {
        var p = FrontProfile()
        switch shape {
        case .hamster:
            p.bodyR = V2(7.2, 6); p.headR = 5.4; p.headY = 4.8; p.legLen = 1.4; p.legR = (1.3, 1.1); p.legGap = 3
            p.ears = .round; p.snout = .none; p.tail = .none
        case .puppy:
            p.bodyR = V2(5.8, 5); p.headR = 5.2; p.headY = 6; p.legLen = 4; p.legR = (1.6, 1.3)
            p.ears = .none; p.snout = .muzzle(0.9); p.tail = .thin
        case .chick:
            p.body = .biped; p.bodyR = V2(6.4, 5.6); p.headR = 4.7; p.headY = 5.6; p.legLen = 1.8; p.legR = (0.6, 0.5)
            p.legGap = 2; p.ears = .none; p.snout = .beak; p.tail = .none; p.wings = true
        case .sheep:
            p.bodyR = V2(6.6, 5.4); p.headR = 4.3; p.headY = 5.8; p.legLen = 3.8; p.legR = (1.1, 0.95); p.legGap = 2.6
            p.ears = .side; p.snout = .none; p.tail = .none
        case .snail:
            p.body = .blob; p.ears = .none; p.snout = .none; p.tail = .none
        case .koala:
            p.bodyR = V2(7, 6); p.headR = 5.8; p.headY = 6.4; p.legLen = 2.8; p.legR = (2, 1.8); p.legGap = 3.2
            p.ears = .none; p.snout = .none; p.tail = .none
        case .panda:
            p.bodyR = V2(7.4, 6); p.headR = 5.6; p.headY = 6.4; p.legLen = 3; p.legR = (2.3, 2.1); p.legGap = 3.2
            p.ears = .none; p.snout = .none; p.tail = .cotton; p.chest = .white
        case .squirrel:
            p.bodyR = V2(5.6, 4.8); p.headR = 4.8; p.headY = 5.4; p.legLen = 2.6; p.legR = (1.2, 1); p.legGap = 2.2
            p.ears = .pointy(0.8); p.snout = .muzzle(0.7); p.tail = .none
        case .otter:
            p.bodyR = V2(5.4, 4.6); p.headR = 4.4; p.headY = 5.8; p.legLen = 2.2; p.legR = (1.3, 1.1); p.legGap = 2.4
            p.ears = .none; p.snout = .muzzle(0.85); p.tail = .none
        case .goat:
            p.bodyR = V2(5.4, 4.8); p.headR = 4.3; p.headY = 8.4; p.legLen = 5.2; p.legR = (1.3, 1); p.legGap = 2.4
            p.ears = .side; p.snout = .muzzle(0.8); p.tail = .cotton; p.neck = true
        default:
            return nil
        }
        return p
    }
}
