import Foundation

// Side rigs for the second wave of species. They share the four-legged and bird frames in
// Species.swift and add each animal's defining parts.

extension SpeciesRig {
    static func buildMore(_ shape: BodyShape, pose: Pose) -> Built? {
        switch shape {
        case .mouse: return mouse(pose)
        case .pig: return pig(pose)
        case .deer: return deer(pose, unicorn: false)
        case .unicorn: return deer(pose, unicorn: true)
        case .hedgehog: return hedgehog(pose)
        case .raccoon: return raccoon(pose)
        case .turtle: return turtle(pose)
        case .axolotl: return axolotl(pose)
        case .duck: return upright(pose, kind: .duck)
        case .owl: return upright(pose, kind: .owl)
        case .penguin: return upright(pose, kind: .penguin)
        default: return nil
        }
    }

    /// A curl of thin tail.
    private static func thinTail(_ q: Quad, _ pose: Pose, start: Double, curl: Double, segments: Int = 4, length: Double = 2.8,
                                 radius: (Double, Double) = (0.9, 0.6), ramp: Ramp = .body) -> [Part] {
        let base = q.bodyC + rotate(V2(-q.bodyR.x * 0.9, q.bodyR.y * 0.1), by: q.angle)
        return tail(from: base, angle: start + pose.tail * 0.3 - pose.dangle * 1.0, curl: curl, segments: segments,
                    length: length, radius: radius, ramp: ramp, z: -1)
    }

    // MARK: Mouse

    static func mouse(_ pose: Pose) -> Built {
        var spec = QuadSpec()
        spec.bodyR = V2(6.8, 4.6)
        spec.bodyX = 15
        spec.legLen = 2.2
        spec.legR = (1.1, 0.9)
        spec.legX = (4, -4)
        spec.headR = 4.4
        spec.headOffset = V2(6.8, 3.4)
        spec.bellyR = V2(3.6, 1.8)
        let q = quadruped(spec, pose)
        var b = q.built
        for (c, z, bias) in [(V2(-0.55, 0.85), 0.9, 1), (V2(0.1, 0.95), 1.2, 0)] {
            b.parts.append(Part(.ellipse(c: b.onHead(c), r: V2(2.9, 2.9), angle: 0), .body, z: z, group: 6, patterned: true,
                                toneBias: bias, role: .extremity))
            b.parts.append(Part(.ellipse(c: b.onHead(c) + V2(0.3, -0.2), r: V2(1.8, 1.8), angle: 0), .pink, z: z + 0.01,
                                group: 6, toneBias: bias, innerOutline: false))
        }
        b.parts.append(Part(headPolygon(b, [V2(0.4, 0.2), V2(1.6, -0.35), V2(0.4, -0.75)]), .body, z: 1.1, group: 1, patterned: true))
        b.parts.append(Part(.ellipse(c: b.onHead(V2(1.55, -0.35)), r: V2(0.8, 0.8), angle: 0), .pink, z: 1.2, group: 2))
        b.parts += thinTail(q, pose, start: 3.0, curl: -0.35, segments: 5, ramp: .pink)
        b.mouth = V2(1.2, -0.65)
        b.eyeX = (0.35, 0.8)
        return b
    }

    // MARK: Pig

    static func pig(_ pose: Pose) -> Built {
        var spec = QuadSpec()
        spec.bodyR = V2(8.8, 6)
        spec.legLen = 2.8
        spec.legR = (1.8, 1.5)
        spec.legX = (5, -5.5)
        spec.headR = 5.2
        spec.headOffset = V2(8, 3.2)
        spec.bellyR = V2(5, 2.4)
        let q = quadruped(spec, pose)
        var b = q.built
        // Floppy ears that flap forward.
        for (base, z, bias) in [(V2(-0.6, 0.6), 0.9, 1), (V2(0.0, 0.75), 1.2, 0)] {
            let flap = 0.15 * pose.tail
            b.parts.append(Part(headPolygon(b, [base, base + V2(0.7, 0.25 + flap), base + V2(0.75, -0.25 + flap)]), .body,
                                z: z, group: 6, patterned: true, toneBias: bias, role: .extremity))
        }
        // Snout
        b.parts.append(Part(.ellipse(c: b.onHead(V2(1.05, -0.3)), r: V2(1.6, 2.2), angle: b.headAngle), .pink, z: 1.2, group: 2))
        // Curly tail
        let base = q.bodyC + rotate(V2(-q.bodyR.x * 0.95, q.bodyR.y * 0.3), by: q.angle)
        b.parts.append(Part(.ring(c: base + V2(-1.5, 1.5), r: V2(1.6, 1.6), width: 1), .pink, z: -1, group: 5))
        b.eyeX = (0.25, 0.65)
        b.eyeY = 0.25
        b.mouth = V2(0.8, -0.85)
        return b
    }

    // MARK: Deer and unicorn

    static func deer(_ pose: Pose, unicorn: Bool) -> Built {
        var spec = QuadSpec()
        spec.bodyR = unicorn ? V2(8.6, 5.4) : V2(8, 4.8)
        spec.bodyX = 13.5
        spec.legLen = unicorn ? 7 : 6.6
        spec.legR = unicorn ? (1.5, 1.1) : (1.2, 0.9)
        spec.legX = (5.5, -5.5)
        spec.headR = unicorn ? 4.2 : 4.0
        spec.headOffset = V2(8.6, 9)
        spec.bellyR = V2(4.5, 2)
        let q = quadruped(spec, pose)
        var b = q.built
        // Neck
        let neckBase = q.bodyC + rotate(V2(q.bodyR.x * 0.6, q.bodyR.y * 0.3), by: q.angle)
        b.parts.append(Part(.capsule(a: neckBase, b: b.headC + V2(-1.5, -1.5), ra: 2.6, rb: 2), .body, z: 0.5, group: 1,
                            patterned: true, role: .plain))
        // Muzzle
        b.parts.append(Part(.ellipse(c: b.onHead(V2(1.0, -0.45)), r: V2(2.6, 1.8), angle: b.headAngle - 0.3), .body, z: 1.1,
                            group: 1, patterned: true))
        b.parts.append(Part(.ellipse(c: b.onHead(V2(1.55, -0.55)), r: V2(0.8, 0.7), angle: 0), .dark, z: 1.2, group: 2))
        // Ears out to the side
        for (base, z, bias) in [(V2(-0.7, 0.7), 0.9, 1), (V2(-0.3, 0.85), 1.2, 0)] {
            b.parts.append(Part(.ellipse(c: b.onHead(base) + V2(-1.8, 0.6), r: V2(2.6, 1.1), angle: 0.5), .body, z: z, group: 6,
                                patterned: true, toneBias: bias, role: .extremity))
        }
        if unicorn {
            // Hooves, mane, flowing tail and a golden horn.
            for part in b.parts where part.role == .limb {
                if case let .capsule(_, f, _, rb) = part.shape {
                    b.parts.append(Part(.ellipse(c: f, r: V2(rb * 1.2, rb), angle: 0), .gold, z: part.z + 0.01, group: part.group,
                                        toneBias: part.toneBias))
                }
            }
            let maneTop = b.onHead(V2(-0.5, 0.9))
            b.parts.append(Part(.polygon([maneTop, maneTop + V2(-2, 1), neckBase + V2(-2.5, 3), neckBase + V2(-0.5, -1),
                                          b.onHead(V2(-1, 0))]), .secondary, z: 1.3, group: 7))
            let tailBase = q.bodyC + rotate(V2(-q.bodyR.x * 0.9, q.bodyR.y * 0.4), by: q.angle)
            let sway = pose.tail * 1.5
            b.parts.append(Part(.polygon([tailBase + V2(0, 1), tailBase + V2(-4, 0 + sway * 0.5), tailBase + V2(-5 + sway, -7),
                                          tailBase + V2(-2, -5), tailBase + V2(0.5, -1)]), .secondary, z: -1, group: 5))
            let hornBase = b.onHead(V2(0.35, 0.85))
            b.parts.append(Part(.polygon([hornBase + V2(-1.1, 0), hornBase + V2(1.1, 0), hornBase + V2(2.8, 7)]), .gold, z: 1.4, group: 8))
            b.parts.append(Part(.capsule(a: hornBase + V2(-0.2, 2), b: hornBase + V2(1.5, 2.6), ra: 0.35, rb: 0.35), .white, z: 1.41,
                                group: 8, innerOutline: false))
            b.parts.append(Part(.capsule(a: hornBase + V2(0.6, 4.3), b: hornBase + V2(2.1, 4.9), ra: 0.3, rb: 0.3), .white, z: 1.41,
                                group: 8, innerOutline: false))
        } else {
            // Fawn spots and a white tail flick.
            for v in [V2(-4, 2.5), V2(-1, 3.4), V2(2, 2.8), V2(-2.5, 0.6), V2(1, 1)] {
                b.parts.append(Part(.ellipse(c: q.bodyC + rotate(v, by: q.angle), r: V2(0.9, 0.8), angle: 0), .white, z: 0.2,
                                    group: 0, innerOutline: false))
            }
            let tailBase = q.bodyC + rotate(V2(-q.bodyR.x * 0.95, q.bodyR.y * 0.5), by: q.angle)
            b.parts.append(Part(.ellipse(c: tailBase + V2(-0.5, 0.5 + pose.tail * 0.5), r: V2(1.4, 2), angle: 0.4), .white, z: -0.5, group: 5))
        }
        b.eyeX = (0.2, 0.6)
        b.eyeY = 0.2
        b.mouth = V2(1.4, -0.8)
        b.topOverride = b.onHead(V2(-0.3, 1.0))
        return b
    }

    // MARK: Hedgehog

    static func hedgehog(_ pose: Pose) -> Built {
        var spec = QuadSpec()
        spec.bodyR = V2(7.6, 5.2)
        spec.legLen = 1.8
        spec.legR = (1, 0.9)
        spec.legX = (4, -4)
        spec.headR = 3.9
        spec.headOffset = V2(6.5, 1.2)
        spec.bellyR = V2(4, 2)
        let q = quadruped(spec, pose)
        var b = q.built
        b.parts.append(Part(headPolygon(b, [V2(0.2, 0.4), V2(1.9, -0.4), V2(0.2, -0.9)]), .secondary, z: 1.1, group: 1))
        b.parts.append(Part(.ellipse(c: b.onHead(V2(1.85, -0.4)), r: V2(0.75, 0.7), angle: 0), .dark, z: 1.2, group: 2))
        // Spines: overlapping darker triangles over the back and head.
        for k in 0..<11 {
            let a = 0.2 + Double(k) / 10 * 2.6 + pose.lying * 0.2
            let root = q.bodyC + rotate(V2(cos(a) * q.bodyR.x * 0.75, sin(a) * q.bodyR.y * 0.75), by: q.angle)
            let out = V2(cos(a + 0.35), sin(a + 0.35))
            let side = V2(-out.y, out.x)
            b.parts.append(Part(.polygon([root + side * 1.6, root - side * 1.6, root + out * 5]), .secondary, z: 0.3 + Double(k) * 0.001,
                                group: 9, toneBias: k % 2))
        }
        b.mouth = V2(1.5, -0.8)
        b.eyeX = (0.35, 0.7)
        b.eyeY = 0.25
        return b
    }

    // MARK: Raccoon

    static func raccoon(_ pose: Pose) -> Built {
        var spec = QuadSpec()
        spec.bodyR = V2(8, 5.6)
        spec.legLen = 3.6
        spec.legR = (1.6, 1.3)
        spec.headR = 4.9
        spec.headOffset = V2(7.6, 4.8)
        let q = quadruped(spec, pose)
        var b = q.built
        for (pts, z, bias) in [([V2(-0.75, 0.55), V2(-0.15, 0.85), V2(-0.6, 1.35)], 0.9, 1),
                               ([V2(-0.05, 0.85), V2(0.55, 0.6), V2(0.3, 1.3)], 1.2, 0)] {
            b.parts.append(Part(headPolygon(b, pts), .body, z: z, group: 6, toneBias: bias))
        }
        b.parts.append(Part(headPolygon(b, [V2(0.3, 0.05), V2(1.6, -0.35), V2(1.5, -0.6), V2(0.3, -0.75)]), .white, z: 1.1, group: 1))
        b.parts.append(Part(.ellipse(c: b.onHead(V2(1.55, -0.45)), r: V2(0.8, 0.7), angle: 0), .dark, z: 1.2, group: 2))
        // The bandit mask, drawn on the head so the eye sits in it.
        b.parts.append(Part(headPolygon(b, [V2(-0.1, 0.45), V2(1.1, 0.3), V2(1.1, -0.05), V2(0.2, -0.15), V2(-0.4, 0.05)]),
                            .dark, z: 1.05, group: 1))
        // Ringed tail
        let base = q.bodyC + rotate(V2(-q.bodyR.x * 0.85, q.bodyR.y * 0.2), by: q.angle)
        var a = 2.7 + pose.tail * 0.3 - pose.dangle
        var p = base
        for k in 0..<5 {
            let next = p + rotate(V2(2.4, 0), by: a)
            b.parts.append(Part(.capsule(a: p, b: next, ra: 2, rb: 1.9), k % 2 == 0 ? .body : .dark, z: -1 - Double(k) * 0.01, group: 5))
            p = next
            a -= 0.25
        }
        b.eyeX = (0.4, 0.8)
        b.eyeY = 0.18
        b.mouth = V2(1.2, -0.75)
        return b
    }

    // MARK: Turtle

    static func turtle(_ pose: Pose) -> Built {
        var spec = QuadSpec()
        spec.bodyR = V2(7.5, 3.6)
        spec.legLen = 2
        spec.legR = (1.8, 1.6)
        spec.legX = (5, -5)
        spec.headR = 3.8
        spec.headOffset = V2(9, 1.6)
        spec.bellyR = V2(5, 1.5)
        let q = quadruped(spec, pose)
        var b = q.built
        // Neck and a domed shell with plates.
        b.parts.append(Part(.capsule(a: q.bodyC + V2(4, 0), b: b.headC + V2(-1.5, -0.5), ra: 2, rb: 1.8), .body, z: 0.5, group: 1,
                            patterned: true))
        let shellC = q.bodyC + rotate(V2(-0.5, q.bodyR.y * 0.55), by: q.angle)
        b.parts.append(Part(.ellipse(c: shellC, r: V2(9.5, 6.5), angle: q.angle), .secondary, z: 1.6, group: 7))
        b.parts.append(Part(.ellipse(c: shellC + V2(0, -5.2), r: V2(9.8, 1.4), angle: q.angle), .secondary, z: 1.65, group: 8, toneBias: 1))
        for v in [V2(-4.5, 1.5), V2(0, 2.8), V2(4.5, 1.5), V2(-2.2, -1.5), V2(2.2, -1.5)] {
            let c = shellC + rotate(v, by: q.angle)
            let hex = (0..<6).map { k -> V2 in c + V2(cos(Double(k) / 6 * 2 * .pi), sin(Double(k) / 6 * 2 * .pi)) * 1.9 }
            b.parts.append(Part(.polygon(hex), .secondary, z: 1.7, group: 9 + Int(v.x + 10), toneBias: -1))
        }
        b.parts += thinTail(q, pose, start: 3.4, curl: 0, segments: 1, length: 2.4, radius: (1.2, 0.6))
        b.eyeX = (0.3, 0.75)
        b.mouth = V2(1.0, -0.55)
        b.topOverride = shellC + V2(0, 6.5)
        return b
    }

    // MARK: Axolotl

    static func axolotl(_ pose: Pose) -> Built {
        var spec = QuadSpec()
        spec.bodyR = V2(8, 3.6)
        spec.bodyX = 15
        spec.legLen = 1.8
        spec.legR = (0.9, 0.8)
        spec.legX = (4.5, -4)
        spec.headR = 4.8
        spec.headOffset = V2(8.5, 2.5)
        spec.bellyR = V2(5, 1.4)
        let q = quadruped(spec, pose)
        var b = q.built
        // Frilly gills fanning out behind the head.
        for (k, a) in [2.0, 2.5, 3.0].enumerated() {
            let root = b.onHead(V2(-0.6, 0.2))
            for (z, bias) in [(0.9, 1), (1.2, 0)] {
                let dir = a + (bias == 1 ? 0.3 : 0) + sin(pose.t * 2 * .pi + Double(k)) * 0.1
                b.parts.append(Part(.capsule(a: root, b: root + V2(cos(dir), sin(dir)) * 5.5, ra: 1.1, rb: 0.6), .secondary,
                                    z: z, group: 6, toneBias: bias, role: .extremity))
            }
        }
        // Finned tail
        let base = q.bodyC + rotate(V2(-q.bodyR.x * 0.85, 0), by: q.angle)
        let wag = pose.tail * 1.5
        b.parts.append(Part(.polygon([base + V2(0, 2.5), base + V2(-9, 2 + wag), base + V2(-10, -0.5 + wag), base + V2(0, -2)]),
                            .body, z: -1, group: 5, patterned: true))
        b.parts.append(Part(.polygon([base + V2(-1, 2.6), base + V2(-9.5, 3.4 + wag), base + V2(-9, 1.6 + wag)]), .secondary,
                            z: -0.9, group: 5, innerOutline: false))
        b.eyeX = (0.45, 0.85)
        b.eyeY = 0.25
        b.mouth = V2(0.95, -0.35)
        return b
    }

    // MARK: Duck, owl and penguin

    enum UprightKind { case duck, owl, penguin }

    static func upright(_ pose: Pose, kind: UprightKind) -> Built {
        var b = Built()
        let squash = pose.squash
        let tall = kind == .penguin ? 1.35 : kind == .owl ? 1.15 : 1.0
        let bodyR = V2((kind == .duck ? 7.4 : 6.4) / squash.squareRoot(), 5.8 * squash * tall)
        let legLen = (kind == .penguin ? 1.2 : 2.6) * (1 - pose.lying) * (1 + 0.3 * pose.dangle)
        let angle = pose.lean * (kind == .penguin ? 0.5 : 1) + pose.sway + (kind == .penguin ? pose.stride * 0.12 : 0)
        let bodyC = V2(15 + pose.lunge, ground + legLen + bodyR.y * 0.85 + pose.bob + pose.lift)
        b.parts.append(Part(.ellipse(c: bodyC, r: bodyR, angle: angle), .body, z: 0, group: 0, patterned: true, role: .torso))
        let belly: Ramp = kind == .penguin ? .white : .secondary
        b.parts.append(Part(.ellipse(c: bodyC + rotate(V2(kind == .penguin ? 2.2 : 1.8, -1.2), by: angle),
                                     r: V2(bodyR.x * 0.6, bodyR.y * 0.72), angle: angle), belly, z: 0.1, group: 0))
        // Head: the owl's sits right on its body, the duck's on a neck.
        let headOffset: V2 = kind == .owl ? V2(1.5, bodyR.y * 0.95) : kind == .penguin ? V2(1.8, bodyR.y * 0.95) : V2(4.5, 6.5)
        let headC = bodyC + rotate(headOffset, by: angle) + V2(pose.headDip * 0.6, -pose.headDip - pose.lying * 2)
        let headR = kind == .owl ? 5.6 : 4.6
        b.headC = headC
        b.headR = headR
        b.headAngle = angle * 0.5 + pose.headTilt
        b.parts.append(Part(.ellipse(c: headC, r: V2(headR * 1.04, headR), angle: b.headAngle), .body, z: 1, group: 1, patterned: true,
                            role: .head))
        let open = pose.mouth == .open ? 0.4 : 0
        switch kind {
        case .duck:
            b.parts.append(Part(headPolygon(b, [V2(0.65, 0.05), V2(1.9, -0.05 + open * 0.3), V2(1.95, -0.3), V2(0.7, -0.4)]), .gold,
                                z: 1.3, group: 2))
            b.parts.append(Part(headPolygon(b, [V2(0.7, -0.35), V2(1.8, -0.4 - open), V2(0.7, -0.6)]), .gold, z: 1.29, group: 2, toneBias: 1))
        case .owl:
            b.parts.append(Part(.ellipse(c: b.onHead(V2(0.35, 0.05)), r: V2(4, 4.2), angle: 0), .secondary, z: 1.05, group: 1))
            for (base, z, bias) in [(V2(-0.75, 0.6), 0.9, 1), (V2(0.1, 0.8), 1.2, 0)] {
                b.parts.append(Part(headPolygon(b, [base, base + V2(0.45, 0.1), base + V2(0.05, 0.75)]), .body, z: z, group: 6,
                                    toneBias: bias, role: .extremity))
            }
            b.parts.append(Part(headPolygon(b, [V2(0.55, -0.05), V2(0.95, -0.15), V2(0.6, -0.55)]), .gold, z: 1.3, group: 2))
        case .penguin:
            b.parts.append(Part(.ellipse(c: b.onHead(V2(0.4, -0.2)), r: V2(2.8, 2.5), angle: 0), .white, z: 1.05, group: 1))
            b.parts.append(Part(headPolygon(b, [V2(0.85, 0.0), V2(1.6, -0.18 + open * 0.2), V2(0.85, -0.35)]), .gold, z: 1.3, group: 2))
        }
        // Wing or flipper
        let wingAngle = (kind == .penguin ? -0.15 : -0.35) + pose.wing * (kind == .penguin ? 0.9 : 0.7)
        b.parts.append(Part(.ellipse(c: bodyC + rotate(V2(-1.4, 0.4 + pose.wing * 0.8), by: angle),
                                     r: kind == .penguin ? V2(1.8, 4.8) : V2(4.4, 2.9), angle: angle + wingAngle),
                            kind == .penguin ? .body : .secondary, z: 0.5, group: 6, role: .extremity))
        // Tail
        if kind != .penguin {
            b.parts.append(Part(.polygon([bodyC + rotate(V2(-4, 0.5), by: angle), bodyC + rotate(V2(-9, 3 + pose.tail), by: angle),
                                          bodyC + rotate(V2(-8.5, -0.5 + pose.tail), by: angle), bodyC + rotate(V2(-4.5, -2), by: angle)]),
                                .body, z: -1, group: 5, patterned: true, role: .extremity))
        }
        // Legs and feet
        for near in [true, false] {
            let hip = bodyC + rotate(V2(near ? 1 : -0.8, -bodyR.y * 0.8), by: angle)
            let swing = pose.stride * (near ? 1 : -1)
            var foot = V2(hip.x + swing * 1.6, ground + 0.6 + pose.lift)
            if pose.dangle > 0 { foot = hip + V2(0.3, -legLen * 1.2 - 1) }
            if pose.lying > 0 { foot = hip + V2(1, -0.6) }
            let z = near ? 2.0 : -2.0
            if legLen > 0.5 {
                b.parts.append(Part(.capsule(a: hip, b: foot, ra: 0.7, rb: 0.6), .gold, z: z, group: near ? 3 : 4,
                                    toneBias: near ? 0 : 1, innerOutline: false))
            }
            b.parts.append(Part(.ellipse(c: foot + V2(1.2, 0), r: V2(kind == .penguin ? 2 : 1.8, 0.8), angle: 0), .gold, z: z,
                                group: near ? 3 : 4, toneBias: near ? 0 : 1))
        }
        b.eyeX = kind == .owl ? (0.1, 0.8) : (0.3, 0.75)
        b.eyeY = kind == .owl ? 0.15 : 0.18
        b.mouth = V2(2, 2)
        return b
    }
}

extension FrontProfile {
    /// Front and back profiles for the second wave of species.
    static func more(_ shape: BodyShape) -> FrontProfile? {
        var p = FrontProfile()
        switch shape {
        case .mouse:
            p.bodyR = V2(5.4, 4.4); p.headR = 4.6; p.headY = 5.2; p.legLen = 2.2; p.legR = (1.1, 0.9); p.legGap = 2.2
            p.ears = .bigRound; p.snout = .nose(.pink); p.tail = .thin
        case .pig:
            p.bodyR = V2(7.6, 6); p.headR = 5.4; p.headY = 5.6; p.legLen = 2.8; p.legR = (1.7, 1.5); p.legGap = 3
            p.ears = .floppy; p.snout = .pig; p.tail = .curl
        case .duck:
            p.body = .biped; p.bodyR = V2(6.8, 5.8); p.headR = 4.6; p.headY = 7; p.legLen = 2.6; p.legR = (0.7, 0.6)
            p.legGap = 2.2; p.ears = .none; p.snout = .bill; p.tail = .feathers; p.wings = true
        case .deer, .unicorn:
            p.bodyR = V2(5.4, 4.8); p.headR = 4.2; p.headY = 8.6; p.legLen = 6.6; p.legR = (1.2, 1.0); p.legGap = 2.4
            p.ears = .side; p.snout = .muzzle(0.85); p.tail = shape == .deer ? .cotton : .bushy
            p.horn = shape == .unicorn; p.mane = shape == .unicorn; p.neck = true
            if shape == .unicorn { p.legR = (1.5, 1.2) }
        case .hedgehog:
            p.bodyR = V2(7, 5); p.headR = 4.2; p.headY = 3.6; p.legLen = 1.8; p.legR = (1, 0.9); p.legGap = 2.6
            p.ears = .round; p.snout = .nose(.dark); p.tail = .none; p.spikes = true
        case .raccoon:
            p.bodyR = V2(6, 5.4); p.headR = 5; p.legLen = 3.6; p.legR = (1.6, 1.3); p.ears = .pointy(0.8)
            p.snout = .muzzle(0.75); p.tail = .ringed; p.mask = true
        case .turtle:
            p.bodyR = V2(6, 3.6); p.headR = 4; p.headY = 4.2; p.legLen = 2; p.legR = (1.8, 1.6); p.legGap = 4.2
            p.ears = .none; p.snout = .none; p.tail = .none; p.shell = true
        case .axolotl:
            p.bodyR = V2(6, 3.8); p.headR = 5.4; p.headY = 4.6; p.legLen = 1.8; p.legR = (1, 0.9); p.legGap = 3.2
            p.ears = .none; p.snout = .none; p.tail = .none; p.gills = true
        case .owl:
            p.body = .biped; p.bodyR = V2(7, 6.6); p.headR = 5.6; p.headY = 6.6; p.legLen = 1.6; p.legR = (0.7, 0.6)
            p.legGap = 2.4; p.ears = .tufts; p.snout = .beak; p.tail = .feathers; p.wings = true; p.faceDisc = true
        case .penguin:
            p.body = .biped; p.bodyR = V2(6, 7.6); p.headR = 4.6; p.headY = 7.6; p.legLen = 1.2; p.legR = (0.7, 0.6)
            p.legGap = 2.4; p.ears = .none; p.snout = .beak; p.tail = .none; p.flippers = true; p.chest = .white
        default:
            return nil
        }
        return p
    }
}
