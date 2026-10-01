import Foundation

// MARK: - Animations

enum PetAnim: Int, CaseIterable {
    case idle, walk, sleep, eat, hop, sick, held, hurt, attack

    var frameCount: Int {
        switch self {
        case .idle: return 4
        case .walk: return 8
        case .sleep: return 4
        case .eat: return 4
        case .hop: return 6
        case .sick: return 4
        case .held: return 4
        case .hurt: return 2
        case .attack: return 6
        }
    }

    var fps: Double {
        switch self {
        case .idle: return 3
        case .walk: return 10
        case .sleep: return 1.5
        case .eat: return 6
        case .hop: return 9
        case .sick: return 4
        case .held: return 5
        case .hurt: return 8
        case .attack: return 12
        }
    }

    /// Index of this animation's first frame in a pet's frame list.
    var offset: Int { PetAnim.allCases.prefix(while: { $0 != self }).reduce(0) { $0 + $1.frameCount } }

    static let totalFrames = PetAnim.allCases.reduce(0) { $0 + $1.frameCount }
}

enum EyeState { case open, half, closed, squint, hurt, wide }
enum Mouth { case none, smile, open, chew, frown }

/// Everything an animation frame says about a body. Species read it to place their parts.
struct Pose {
    var t = 0.0
    var bob = 0.0
    var squash = 1.0
    var lean = 0.0
    var headDip = 0.0
    var headTilt = 0.0
    /// Walk phase, -1...1: near front leg forward when positive.
    var stride = 0.0
    var lift = 0.0
    var tail = 0.0
    var wing = 0.0
    var lying = 0.0
    var dangle = 0.0
    var sway = 0.0
    var lunge = 0.0
    var paw = 0.0
    var eyes = EyeState.open
    var mouth = Mouth.none
    var blush = true

    static func of(_ anim: PetAnim, frame i: Int) -> Pose {
        var p = Pose()
        let n = Double(anim.frameCount)
        let t = Double(i) / n
        let s = sin(2 * .pi * t), c = cos(2 * .pi * t)
        p.t = t
        switch anim {
        case .idle:
            p.squash = 1 + 0.035 * s
            p.tail = 0.5 * s
            p.wing = 0.15 * s
            p.headTilt = 0.03 * s
            if i == 3 { p.eyes = .closed }
        case .walk:
            p.stride = s
            p.bob = (1 - abs(s)) * 0.9
            p.lean = 0.04
            p.tail = 0.7 * c
            p.wing = 0.3 * c
            p.headTilt = -0.04 * abs(s)
            p.squash = 1 + 0.03 * abs(c)
        case .sleep:
            p.lying = 1
            p.squash = 1 + 0.04 * s
            p.eyes = .closed
            p.tail = 0.15
            p.wing = -0.6
            p.blush = false
        case .eat:
            p.headDip = [1, 3, 3.5, 2][i]
            p.lean = 0.08
            p.mouth = i % 2 == 0 ? .open : .chew
            p.eyes = i == 2 ? .squint : .open
            p.tail = 0.6 * s
        case .hop:
            let frames: [(Double, Double)] = [(0.84, 0), (1.12, 2), (1.04, 4.5), (1.0, 5), (1.06, 2.5), (0.88, 0)]
            p.squash = frames[i].0
            p.lift = frames[i].1
            p.eyes = .squint
            p.mouth = .open
            p.wing = i == 2 || i == 3 ? 1 : -0.3
            p.tail = i % 2 == 0 ? 0.8 : -0.4
            p.stride = i == 2 || i == 3 ? 0.6 : 0
        case .sick:
            p.sway = 0.07 * s
            p.squash = 0.96
            p.headDip = 1
            p.eyes = .half
            p.mouth = .frown
            p.blush = false
            p.tail = -0.4
            p.wing = -0.5
        case .held:
            p.dangle = 1
            p.sway = 0.12 * s
            p.lift = 2
            p.eyes = .wide
            p.mouth = .open
            p.tail = -0.6 + 0.3 * s
            p.wing = 0.6 * s
        case .hurt:
            p.squash = i == 0 ? 0.86 : 0.94
            p.lean = i == 0 ? -0.18 : -0.08
            p.eyes = .hurt
            p.mouth = .open
            p.blush = false
            p.tail = -0.5
        case .attack:
            let lean: [Double] = [-0.12, -0.2, 0.14, 0.22, 0.12, 0]
            let lunge: [Double] = [-0.5, -1, 2, 3.5, 2, 0.5]
            let paw: [Double] = [0, 0.3, 1, 0.8, 0.4, 0]
            p.lean = lean[i]
            p.lunge = lunge[i]
            p.paw = paw[i]
            p.eyes = i >= 2 && i <= 4 ? .squint : .open
            p.mouth = i >= 2 && i <= 4 ? .open : .none
            p.tail = 0.8
            p.wing = i >= 2 ? 1 : -0.4
            p.squash = i == 1 ? 0.92 : 1
        }
        return p
    }
}

// MARK: - Species

/// A posed body: its parts, and where the face and accessory go.
struct Built {
    var parts: [Part] = []
    var headC = V2(16, 16)
    var headR = 5.0
    var headAngle = 0.0
    var headZ = 1.0
    /// Eye positions across the head, in head radii (near eye, far eye).
    var eyeX = (0.25, 0.78)
    var eyeY = 0.12
    var mouth = V2(0.82, -0.45)
    var cheek = V2(0.22, -0.4)
    var topOverride: V2?

    func onHead(_ v: V2) -> V2 { headC + rotate(v * headR, by: headAngle) }
    var top: V2 { topOverride ?? onHead(V2(-0.12, 1.0)) }
}

enum SpeciesRig {
    static let ground = 1.0

    static func build(_ shape: BodyShape, pose: Pose) -> Built {
        switch shape {
        case .blob: return blob(pose)
        case .bird: return bird(pose)
        case .cat: return cat(pose)
        case .bunny: return bunny(pose)
        case .frog: return frog(pose)
        case .bear: return bear(pose)
        case .ghost: return ghost(pose)
        case .fox: return fox(pose)
        case .dragon: return dragon(pose)
        default: return buildMore(shape, pose: pose) ?? buildWave3(shape, pose: pose) ?? buildWave4(shape, pose: pose)
            ?? buildWave5(shape, pose: pose) ?? cat(pose)
        }
    }

    // MARK: Four-legged frame shared by cat, fox, bear, bunny and dragon.

    struct QuadSpec {
        var bodyR = V2(7.5, 5)
        var bodyX = 14.5
        var legLen = 4.5
        var legR = (1.7, 1.4)
        var legX = (4.5, -4.5)
        var headR = 5.3
        var headOffset = V2(7.5, 5.5)
        var bellyR = V2(4, 2.2)
        var hindLegs = true
    }

    struct Quad {
        var built = Built()
        var bodyC = V2.zero
        var bodyR = V2.zero
        var angle = 0.0
    }

    static func quadruped(_ spec: QuadSpec, _ pose: Pose) -> Quad {
        var q = Quad()
        let legLen = spec.legLen * (1 - 0.8 * pose.lying) * (1 + 0.2 * pose.dangle)
        let bodyR = V2(spec.bodyR.x / pose.squash.squareRoot(), spec.bodyR.y * pose.squash)
        let angle = pose.lean + pose.sway
        let bodyC = V2(spec.bodyX + pose.lunge, ground + legLen + bodyR.y * 0.72 + pose.bob + pose.lift)
        q.bodyC = bodyC
        q.bodyR = bodyR
        q.angle = angle

        var parts: [Part] = []
        parts.append(Part(.ellipse(c: bodyC, r: bodyR, angle: angle), .body, z: 0, group: 0, patterned: true, role: .torso))
        parts.append(Part(.ellipse(c: bodyC + rotate(V2(1.5, -bodyR.y * 0.42), by: angle), r: spec.bellyR, angle: angle),
                          .secondary, z: 0.1, group: 0))

        let legs: [(x: Double, front: Bool)] = spec.hindLegs ? [(spec.legX.0, true), (spec.legX.1, false)] : [(spec.legX.0, true)]
        for leg in legs {
            for near in [true, false] {
                let hip = bodyC + rotate(V2(leg.x + (near ? 0 : -1.2), -bodyR.y * 0.45), by: angle)
                let swing = pose.stride * (leg.front ? 1 : -1) * (near ? 1 : -1)
                var foot = V2(hip.x + swing * legLen * 0.55, ground + spec.legR.1 + pose.lift)
                if pose.dangle > 0 {
                    foot = hip + V2(sin(pose.sway * 3 + (near ? 0 : 1)) * 0.8, -legLen * 1.1)
                } else if pose.lying > 0 {
                    foot = V2(hip.x + (leg.front ? 2.5 : -1.5), ground + spec.legR.1)
                } else if pose.paw > 0 && leg.front && near {
                    foot = hip + rotate(V2(legLen * 0.95, 0), by: -1.2 + pose.paw * 1.5)
                }
                parts.append(Part(.capsule(a: hip, b: foot, ra: spec.legR.0, rb: spec.legR.1), .body,
                                  z: near ? 2 : -2, group: near ? 3 : 4, patterned: true,
                                  toneBias: near ? 0 : 1, role: .limb))
            }
        }

        let headAngle = angle * 0.5 + pose.headTilt - pose.lying * 0.15
        let lyingDrop = pose.lying * 2.5
        let headC = bodyC + rotate(spec.headOffset, by: angle)
            + V2(pose.headDip * 0.4 + pose.lying * 1.5, -pose.headDip - lyingDrop)
        parts.append(Part(.ellipse(c: headC, r: V2(spec.headR * 1.04, spec.headR), angle: headAngle), .body,
                          z: 1, group: 1, patterned: true, role: .head))

        q.built.parts = parts
        q.built.headC = headC
        q.built.headR = spec.headR
        q.built.headAngle = headAngle
        return q
    }

    /// A tail as a chain of capsules starting at `base`, curling by `curl` per segment.
    static func tail(from base: V2, angle start: Double, curl: Double, segments: Int, length: Double,
                     radius: (Double, Double), ramp: Ramp, z: Double, tipRamp: Ramp? = nil) -> [Part] {
        var parts: [Part] = []
        var p = base
        var a = start
        for i in 0..<segments {
            let next = p + rotate(V2(length, 0), by: a)
            let f0 = Double(i) / Double(segments), f1 = Double(i + 1) / Double(segments)
            let r0 = radius.0 + (radius.1 - radius.0) * f0, r1 = radius.0 + (radius.1 - radius.0) * f1
            let isTip = i == segments - 1
            parts.append(Part(.capsule(a: p, b: next, ra: r0, rb: r1), isTip ? (tipRamp ?? ramp) : ramp,
                              z: z, group: 5, patterned: tipRamp == nil, role: .extremity))
            p = next
            a += curl
        }
        return parts
    }

    /// A triangle in head-local units (head radii).
    static func headPolygon(_ b: Built, _ points: [V2]) -> Shape {
        .polygon(points.map { b.onHead($0) })
    }

    // MARK: Cat

    static func cat(_ pose: Pose) -> Built {
        var q = quadruped(QuadSpec(), pose)
        var b = q.built
        // Ears
        b.parts.append(Part(headPolygon(b, [V2(-0.75, 0.55), V2(-0.1, 0.9), V2(-0.62, 1.55)]), .body,
                            z: 0.9, group: 6, patterned: true, toneBias: 1, role: .extremity))
        b.parts.append(Part(headPolygon(b, [V2(0.0, 0.85), V2(0.62, 0.6), V2(0.4, 1.5)]), .body,
                            z: 1.2, group: 6, patterned: true, role: .extremity))
        b.parts.append(Part(headPolygon(b, [V2(0.14, 0.86), V2(0.5, 0.72), V2(0.38, 1.25)]), .pink,
                            z: 1.25, group: 6, innerOutline: false))
        // Muzzle
        b.parts.append(Part(.ellipse(c: b.onHead(V2(0.62, -0.35)), r: V2(2.3, 1.6), angle: b.headAngle), .secondary,
                            z: 1.1, group: 1))
        // Tail
        let base = q.bodyC + rotate(V2(-q.bodyR.x * 0.85, q.bodyR.y * 0.25), by: q.angle)
        b.parts += tail(from: base, angle: 2.3 + pose.tail * 0.3 - pose.dangle * 1.2 - pose.lying * 0.8,
                        curl: -0.45 + pose.tail * 0.15, segments: 3, length: 3.2, radius: (1.3, 1.0), ramp: .body, z: -1)
        b.mouth = V2(0.92, -0.5)
        q.built = b
        return b
    }

    // MARK: Fox

    static func fox(_ pose: Pose) -> Built {
        var spec = QuadSpec()
        spec.legLen = 4.8
        spec.legR = (1.6, 1.3)
        spec.headR = 5
        spec.bellyR = V2(3.5, 2)
        let q = quadruped(spec, pose)
        var b = q.built
        // Dark socks over the lower legs.
        for part in b.parts where part.role == .limb {
            if case let .capsule(a, f, _, rb) = part.shape {
                let knee = a + (f - a) * 0.55
                b.parts.append(Part(.capsule(a: knee, b: f, ra: rb * 1.05, rb: rb * 1.05), .dark,
                                    z: part.z + 0.01, group: part.group, toneBias: part.toneBias))
            }
        }
        // Big ears with dark tips.
        for (pts, z, bias) in [([V2(-0.8, 0.5), V2(-0.1, 0.9), V2(-0.75, 1.85)], 0.9, 1),
                               ([V2(-0.05, 0.85), V2(0.65, 0.55), V2(0.35, 1.8)], 1.2, 0)] {
            b.parts.append(Part(headPolygon(b, pts), .body, z: z, group: 6, patterned: true, toneBias: bias, role: .extremity))
            let tip = pts[2]
            let tipPts = [tip, tip + (pts[0] - tip) * 0.3, tip + (pts[1] - tip) * 0.3]
            b.parts.append(Part(headPolygon(b, tipPts), .dark, z: z + 0.01, group: 6, toneBias: bias, innerOutline: false))
        }
        // Long snout and white chin and chest.
        b.parts.append(Part(headPolygon(b, [V2(0.35, 0.15), V2(1.65, -0.35), V2(1.5, -0.6), V2(0.35, -0.75)]), .body,
                            z: 1.1, group: 1, patterned: true))
        b.parts.append(Part(headPolygon(b, [V2(0.2, -0.35), V2(1.45, -0.55), V2(0.3, -0.95)]), .white, z: 1.15, group: 1))
        b.parts.append(Part(.ellipse(c: q.bodyC + rotate(V2(q.bodyR.x * 0.55, 0), by: q.angle), r: V2(3, 3.6), angle: q.angle),
                            .white, z: 0.2, group: 0))
        // Bushy tail with a white tip.
        let base = q.bodyC + rotate(V2(-q.bodyR.x * 0.85, q.bodyR.y * 0.1), by: q.angle)
        var a = 2.75 + pose.tail * 0.25 - pose.dangle * 1.1 - pose.lying * 0.9
        var p = base
        for i in 0..<3 {
            let next = p + rotate(V2(3.2, 0), by: a)
            let r = [2.2, 2.8, 2.4][i]
            b.parts.append(Part(.ellipse(c: (p + next) / 2, r: V2(2.6, r), angle: a), i == 2 ? .white : .body,
                                z: -1, group: 5, patterned: i < 2, role: .extremity))
            p = next
            a -= 0.35
        }
        b.mouth = V2(1.2, -0.55)
        b.eyeX = (0.3, 0.75)
        return b
    }

    // MARK: Bear

    static func bear(_ pose: Pose) -> Built {
        var spec = QuadSpec()
        spec.bodyR = V2(8.5, 6.3)
        spec.legLen = 3.4
        spec.legR = (2.4, 2.2)
        spec.legX = (4.8, -5)
        spec.headR = 5.8
        spec.headOffset = V2(7.2, 6.3)
        spec.bellyR = V2(5, 3)
        let q = quadruped(spec, pose)
        var b = q.built
        for (c, z, bias) in [(V2(-0.6, 0.8), 0.9, 1), (V2(0.25, 0.92), 1.2, 0)] {
            b.parts.append(Part(.ellipse(c: b.onHead(c), r: V2(2.1, 2.1), angle: 0), .body, z: z, group: 6,
                                patterned: true, toneBias: bias, role: .extremity))
            b.parts.append(Part(.ellipse(c: b.onHead(c) + V2(0.2, -0.2), r: V2(1, 1), angle: 0), .secondary,
                                z: z + 0.01, group: 6, toneBias: bias, innerOutline: false))
        }
        b.parts.append(Part(.ellipse(c: b.onHead(V2(0.72, -0.3)), r: V2(2.8, 2.1), angle: b.headAngle), .secondary,
                            z: 1.1, group: 1))
        b.parts.append(Part(.ellipse(c: q.bodyC + rotate(V2(-q.bodyR.x * 0.95, q.bodyR.y * 0.2), by: q.angle),
                                     r: V2(1.6, 1.6), angle: 0), .body, z: -1, group: 5, patterned: true))
        b.mouth = V2(1.05, -0.55)
        b.eyeX = (0.22, 0.68)
        b.eyeY = 0.2
        return b
    }

    // MARK: Bunny

    static func bunny(_ pose: Pose) -> Built {
        var spec = QuadSpec()
        spec.bodyR = V2(6.8, 5.8)
        spec.bodyX = 14
        spec.legLen = 2.6
        spec.legR = (1.4, 1.2)
        spec.legX = (4, -4)
        spec.headR = 5
        spec.headOffset = V2(6.2, 6)
        spec.bellyR = V2(3.5, 2.6)
        spec.hindLegs = false
        let q = quadruped(spec, pose)
        var b = q.built
        // Big back legs.
        for near in [true, false] {
            let thigh = q.bodyC + rotate(V2(-2.8 - (near ? 0 : 1), -q.bodyR.y * 0.35), by: q.angle)
            let footX = thigh.x + (near ? 1 : 0) - pose.stride * (near ? 1.5 : -1.5)
            let footY = pose.dangle > 0 ? thigh.y - 5 : ground + 1.2 + pose.lift
            b.parts.append(Part(.ellipse(c: thigh, r: V2(3.6, 3.2), angle: 0.2), .body, z: near ? 1.5 : -1.5,
                                group: near ? 3 : 4, patterned: true, toneBias: near ? 0 : 1, role: .limb))
            b.parts.append(Part(.ellipse(c: V2(footX, footY), r: V2(3, 1.2), angle: 0), .body, z: near ? 1.6 : -1.6,
                                group: near ? 3 : 4, patterned: true, toneBias: near ? 0 : 1, role: .limb))
        }
        // Long ears; they flop back when asleep or dangling.
        let flop = pose.lying * 1.2 + pose.dangle * 0.6 + pose.headDip * 0.08
        for (x, z, bias) in [(-0.55, 0.9, 1), (-0.05, 1.2, 0)] {
            let root = b.onHead(V2(x, 0.75))
            let tip = root + rotate(V2(0, 8.5), by: 0.35 + flop + (bias == 1 ? 0.25 : 0) + pose.tail * 0.05)
            b.parts.append(Part(.capsule(a: root, b: tip, ra: 1.6, rb: 1.4), .body, z: z, group: 6,
                                patterned: true, toneBias: bias, role: .extremity))
            if bias == 0 {
                b.parts.append(Part(.capsule(a: root + (tip - root) * 0.2, b: tip - (tip - root) * 0.12, ra: 0.6, rb: 0.6),
                                    .pink, z: z + 0.01, group: 6, innerOutline: false))
            }
        }
        // Cotton tail.
        b.parts.append(Part(.ellipse(c: q.bodyC + rotate(V2(-q.bodyR.x * 0.95, q.bodyR.y * 0.25), by: q.angle),
                                     r: V2(2.3, 2.3), angle: 0), .white, z: -0.5, group: 5))
        b.mouth = V2(0.9, -0.5)
        return b
    }

    // MARK: Dragon

    static func dragon(_ pose: Pose) -> Built {
        var spec = QuadSpec()
        spec.bodyR = V2(7.8, 5.8)
        spec.legLen = 3.8
        spec.legR = (2.1, 1.8)
        spec.headR = 4.7
        spec.headOffset = V2(8.3, 6.3)
        spec.bellyR = V2(4.5, 2.6)
        let q = quadruped(spec, pose)
        var b = q.built
        // Snout and horns.
        b.parts.append(Part(.ellipse(c: b.onHead(V2(0.95, -0.25)), r: V2(3.2, 2.2), angle: b.headAngle), .body,
                            z: 1.1, group: 1, patterned: true))
        for (base, z, bias) in [(V2(-0.7, 0.55), 0.9, 1), (V2(-0.25, 0.8), 1.2, 0)] {
            b.parts.append(Part(headPolygon(b, [base, base + V2(0.45, 0.1), base + V2(-0.55, 0.95)]), .gold,
                                z: z, group: 6, toneBias: bias))
        }
        // Wings: far one behind the body, near one over it.
        let flap = pose.wing
        for near in [false, true] {
            let root = q.bodyC + rotate(V2(-1 - (near ? 0 : 1.5), q.bodyR.y * 0.55), by: q.angle)
            let pts = [root, root + V2(2, 2), root + V2(-2 + flap, 8 + flap * 3), root + V2(-7, 6 + flap * 2.5),
                       root + V2(-8.5, 1 + flap)]
            b.parts.append(Part(.polygon(pts), .secondary, z: near ? 0.5 : -1.5, group: near ? 7 : 8,
                                toneBias: near ? 0 : 1))
        }
        // Back spikes.
        for i in 0..<3 {
            let base = q.bodyC + rotate(V2(-3.5 + Double(i) * 3, q.bodyR.y * 0.9), by: q.angle)
            b.parts.append(Part(.polygon([base + V2(-1.2, -0.5), base + V2(1.2, -0.5), base + V2(-0.4, 2.2)]), .gold,
                                z: -0.2, group: 9))
        }
        // Tail with a spade.
        let base = q.bodyC + rotate(V2(-q.bodyR.x * 0.85, 0), by: q.angle)
        let tailParts = tail(from: base, angle: 3.3 + pose.tail * 0.2 - pose.lying * 0.4, curl: -0.25,
                             segments: 3, length: 3.6, radius: (2, 0.9), ramp: .body, z: -1)
        b.parts += tailParts
        if case let .capsule(_, tip, _, _) = tailParts.last!.shape {
            b.parts.append(Part(.polygon([tip + V2(1, 1), tip + V2(-2.5, 1.5), tip + V2(-1.5, -1.5)]), .secondary,
                                z: -0.9, group: 5))
        }
        b.mouth = V2(1.45, -0.55)
        b.eyeX = (0.15, 0.62)
        b.eyeY = 0.25
        return b
    }

    // MARK: Bird

    static func bird(_ pose: Pose) -> Built {
        var b = Built()
        let squash = pose.squash
        let bodyR = V2(6.8 / squash.squareRoot(), 6 * squash)
        let legLen = 3.2 * (1 - pose.lying) * (1 + 0.3 * pose.dangle)
        let angle = pose.lean + pose.sway
        let bodyC = V2(15 + pose.lunge, ground + legLen + bodyR.y * 0.85 + pose.bob + pose.lift)
        b.parts.append(Part(.ellipse(c: bodyC, r: bodyR, angle: angle), .body, z: 0, group: 0, patterned: true, role: .torso))
        b.parts.append(Part(.ellipse(c: bodyC + rotate(V2(2, -2.2), by: angle), r: V2(3.8, 3), angle: angle), .secondary,
                            z: 0.1, group: 0))
        // Head
        let headC = bodyC + rotate(V2(4.2, 6.6), by: angle) + V2(pose.headDip * 0.6, -pose.headDip - pose.lying * 2)
        let headAngle = angle * 0.5 + pose.headTilt
        b.headC = headC
        b.headR = 4.8
        b.headAngle = headAngle
        b.parts.append(Part(.ellipse(c: headC, r: V2(4.9, 4.8), angle: headAngle), .body, z: 1, group: 1, patterned: true,
                            role: .head))
        let open = pose.mouth == .open ? 0.5 : 0
        b.parts.append(Part(headPolygon(b, [V2(0.75, 0.15), V2(1.75, -0.12 + open * 0.3), V2(0.8, -0.35)]), .gold, z: 1.3, group: 2))
        b.parts.append(Part(headPolygon(b, [V2(0.75, -0.3), V2(1.5, -0.42 - open * 0.4), V2(0.8, -0.6)]), .gold, z: 1.29,
                            group: 2, toneBias: 1))
        // Tail feathers
        b.parts.append(Part(.polygon([bodyC + rotate(V2(-4.5, 1.5), by: angle), bodyC + rotate(V2(-10.5, 4.5 + pose.tail), by: angle),
                                      bodyC + rotate(V2(-10, 1 + pose.tail), by: angle), bodyC + rotate(V2(-5, -1.5), by: angle)]),
                            .body, z: -1, group: 5, patterned: true, role: .extremity))
        // Wing
        let wingAngle = -0.35 + pose.wing * 0.7
        b.parts.append(Part(.ellipse(c: bodyC + rotate(V2(-1.3, 0.6 + pose.wing * 0.8), by: angle), r: V2(4.6, 3),
                                     angle: angle + wingAngle), .secondary, z: 0.5, group: 6, role: .extremity))
        // Legs
        for near in [true, false] {
            let hip = bodyC + rotate(V2(near ? 1 : -0.8, -bodyR.y * 0.75), by: angle)
            let swing = pose.stride * (near ? 1 : -1)
            var foot = V2(hip.x + swing * 1.8, ground + 0.6 + pose.lift)
            if pose.dangle > 0 { foot = hip + V2(0.3, -legLen * 1.2) }
            if pose.lying > 0 { foot = hip + V2(1, -0.6) }
            let z = near ? 2.0 : -2.0
            b.parts.append(Part(.capsule(a: hip, b: foot, ra: 0.7, rb: 0.6), .gold, z: z, group: near ? 3 : 4,
                                toneBias: near ? 0 : 1, innerOutline: false))
            b.parts.append(Part(.capsule(a: foot, b: foot + V2(1.8, 0), ra: 0.6, rb: 0.5), .gold, z: z, group: near ? 3 : 4,
                                toneBias: near ? 0 : 1, innerOutline: false))
        }
        b.eyeX = (0.3, 0.75)
        b.eyeY = 0.18
        b.mouth = V2(2, 2) // the beak is the mouth
        return b
    }

    // MARK: Blob

    static func blob(_ pose: Pose) -> Built {
        var b = Built()
        let squash = pose.squash * (1 - 0.15 * pose.lying)
        let r = V2(9.2 / squash.squareRoot(), 7.4 * squash)
        let angle = pose.lean * 0.6 + pose.sway
        let c = V2(16 + pose.lunge, ground + 1 + r.y + pose.bob * 0.6 + pose.lift + pose.dangle * 1.5)
        b.parts.append(Part(.ellipse(c: c, r: r, angle: angle), .body, z: 0, group: 0, patterned: true, role: .torso))
        b.parts.append(Part(.ellipse(c: c + rotate(V2(2.2, -r.y * 0.45), by: angle), r: V2(5, 3), angle: angle), .secondary,
                            z: 0.1, group: 0))
        // Feet
        for near in [true, false] {
            let swing = pose.stride * (near ? 1 : -1)
            var foot = V2(c.x + (near ? 3 : -3.5) + swing * 1.8, ground + 1.1 + pose.lift)
            if pose.dangle > 0 { foot = V2(c.x + (near ? 2.5 : -2.5), c.y - r.y - 1) }
            b.parts.append(Part(.ellipse(c: foot, r: V2(2.6, 1.4), angle: 0), .body, z: near ? 1 : -1,
                                group: near ? 3 : 4, patterned: true, toneBias: near ? 0 : 1, role: .limb))
        }
        // Arm nubs
        let armUp = pose.paw * 1.2 + pose.dangle * 0.8 + max(0, pose.wing) * 0.6
        b.parts.append(Part(.ellipse(c: c + rotate(V2(r.x * 0.55, -1 + armUp * 2), by: angle), r: V2(2.2, 1.6),
                                     angle: 0.4 + armUp), .body, z: 1.5, group: 6, patterned: true, role: .limb))
        b.parts.append(Part(.ellipse(c: c + rotate(V2(-r.x * 0.9, -0.5 + armUp * 1.5), by: angle), r: V2(2, 1.5),
                                     angle: -0.4 - armUp), .body, z: -1, group: 7, patterned: true, toneBias: 1, role: .limb))
        b.headC = c + V2(2, 1.8)
        b.headR = r.y * 0.85
        b.headAngle = angle
        b.eyeX = (0.3, 0.85)
        b.eyeY = 0.18
        b.cheek = V2(0.18, -0.35)
        b.topOverride = c + V2(-0.5, r.y)
        return b
    }

    // MARK: Ghost

    static func ghost(_ pose: Pose) -> Built {
        var b = Built()
        let float = 2.5 + sin(pose.t * 2 * .pi) * 1 + pose.lift
        let squash = pose.squash
        let angle = pose.lean + pose.sway + pose.stride * 0.05
        let c = V2(16 + pose.lunge, ground + 9 * squash + float - pose.lying * 2)
        let r = V2(7.2 / squash.squareRoot(), 8.6 * squash)
        b.parts.append(Part(.ellipse(c: c, r: r, angle: angle), .body, z: 0, group: 0, patterned: true, role: .torso))
        // Wavy hem.
        for i in 0..<4 {
            let x = -5.4 + Double(i) * 3.6
            let wave = sin(pose.t * 2 * .pi + Double(i) * 1.6) * 0.8
            b.parts.append(Part(.ellipse(c: c + rotate(V2(x, -r.y * 0.78 + wave), by: angle), r: V2(1.9, 2.2), angle: 0),
                                .body, z: 0.05, group: 0, patterned: true, role: .torso))
        }
        let armUp = pose.paw + pose.dangle * 0.6
        b.parts.append(Part(.ellipse(c: c + rotate(V2(r.x * 0.75, -1 + armUp * 2.5), by: angle), r: V2(2.4, 1.5),
                                     angle: 0.5 + armUp), .body, z: 1, group: 6, patterned: true, role: .limb))
        b.parts.append(Part(.ellipse(c: c + rotate(V2(-r.x * 0.85, -0.5), by: angle), r: V2(2.2, 1.4), angle: -0.5),
                            .body, z: -1, group: 7, patterned: true, toneBias: 1, role: .limb))
        b.headC = c + V2(1.5, 3)
        b.headR = 5.2
        b.headAngle = angle
        b.eyeX = (0.3, 0.9)
        b.eyeY = 0.1
        b.topOverride = c + V2(-0.5, r.y)
        return b
    }

    // MARK: Frog

    static func frog(_ pose: Pose) -> Built {
        var b = Built()
        let squash = pose.squash
        let r = V2(9.5 / squash.squareRoot(), 5.4 * squash)
        let angle = pose.lean * 0.7 + pose.sway
        let c = V2(16 + pose.lunge, ground + 2 + r.y + pose.bob * 0.5 + pose.lift + pose.dangle * 2 - pose.lying)
        b.parts.append(Part(.ellipse(c: c, r: r, angle: angle), .body, z: 0, group: 0, patterned: true, role: .torso))
        b.parts.append(Part(.ellipse(c: c + rotate(V2(2.5, -r.y * 0.4), by: angle), r: V2(6, 2.8), angle: angle), .secondary,
                            z: 0.1, group: 0))
        // Eye bumps on top.
        let bumpY = r.y * 0.82 - pose.headDip * 0.5
        b.parts.append(Part(.ellipse(c: c + rotate(V2(1.5, bumpY), by: angle), r: V2(2.9, 2.9), angle: 0), .body,
                            z: -0.5, group: 6, patterned: true, toneBias: 1, role: .head))
        b.parts.append(Part(.ellipse(c: c + rotate(V2(5.8, bumpY - 0.3), by: angle), r: V2(3.1, 3.1), angle: 0), .body,
                            z: 0.5, group: 7, patterned: true, role: .head))
        // Back legs: thigh and a long foot.
        for near in [true, false] {
            let thigh = c + rotate(V2(-5.5 - (near ? 0 : 1), -r.y * 0.3), by: angle)
            var foot = V2(thigh.x + 3.5 - pose.stride * (near ? 2 : -2), ground + 1 + pose.lift)
            if pose.dangle > 0 { foot = thigh + V2(0.5, -7) }
            b.parts.append(Part(.ellipse(c: thigh, r: V2(3.8, 3), angle: 0.3), .body, z: near ? 1 : -1,
                                group: near ? 3 : 4, patterned: true, toneBias: near ? 0 : 1, role: .limb))
            b.parts.append(Part(.capsule(a: thigh + V2(1.5, -2), b: foot, ra: 1.3, rb: 1.5), .body, z: near ? 1.1 : -1.1,
                                group: near ? 3 : 4, patterned: true, toneBias: near ? 0 : 1, role: .limb))
            // Front leg
            let shoulder = c + rotate(V2(4.5 - (near ? 0 : 1), -r.y * 0.5), by: angle)
            var hand = V2(shoulder.x + 1.5 + pose.stride * (near ? 1 : -1), ground + 0.9 + pose.lift)
            if pose.paw > 0 && near { hand = shoulder + V2(3.5, pose.paw * 3) }
            if pose.dangle > 0 { hand = shoulder + V2(0.5, -4) }
            b.parts.append(Part(.capsule(a: shoulder, b: hand, ra: 1.2, rb: 1.1), .body, z: near ? 1.2 : -1.2,
                                group: near ? 5 : 8, patterned: true, toneBias: near ? 0 : 1, role: .limb))
        }
        b.headC = c + rotate(V2(4.8, bumpY - 0.6), by: angle)
        b.headR = 3
        b.headAngle = 0
        b.eyeX = (0.1, -1.25)
        b.eyeY = 0.0
        b.mouth = V2(1.4, -2.4)
        b.cheek = V2(0.6, -1.8)
        b.topOverride = c + rotate(V2(3.5, r.y + 2.5), by: angle)
        return b
    }
}

// MARK: - Faces

enum Face {
    /// Eyes drawn at full 64-pixel resolution.
    static func eyes(_ style: EyeStyle, _ state: EyeState) -> (near: [String], far: [String]) {
        switch state {
        case .closed: return (["k...k", ".kkk."], ["k..k", ".kk."])
        case .half: return (["OOOO", "kWkk", "kkkk"], ["OOO", "Wkk"])
        case .squint: return ([".kk.", "k..k", "k..k"], [".k.", "k.k"])
        case .hurt: return (["k...k", ".k.k.", "..k..", ".k.k.", "k...k"], ["k..k", ".kk.", "k..k"])
        case .wide: return ([".www.", "wWkkw", "wkkkw", "wkkkw", ".www."], [".ww.", "wkkw", ".ww."])
        case .open: break
        }
        switch style {
        case .dot: return ([".kk.", "kWkk", "kkkk", ".kk."], ["kk", "Wk", "kk"])
        case .wide: return (["..kk..", ".kWWkk", "kkWkkk", "kkkkkk", ".kkkk.", "..kk.."], [".kk", "kWk", "kkk", ".k."])
        case .sleepy: return (["OOOOO", ".kWkk", ".kkkk", "..kk."], ["OOO", "kWk", ".k."])
        case .happy: return ([".kkk.", "k...k", "k...k"], [".kk.", "k..k"])
        case .sparkly: return (["kkkkk", "kWkkk", "kkkkk", "kkkWk", ".kkk."], ["kkk", "Wkk", "kkW"])
        case .angry: return (["OO....", ".OOO..", "..OOO.", ".kWkk.", ".kkkk.", "..kk.."], ["O..", ".OO", "kWk", "kkk"])
        case .cyclops: return (["..xxxx..", ".xwwwwx.", "xwwkkkwx", "xwkWkkwx", "xwkkkkwx", ".xwkkwx.", "..xxxx.."], [])
        case .hearts: return ([".R.R.", "RRrrr", "rrrrr", ".rrr.", "..r.."], ["R.R", "rrr", ".r."])
        case .starry: return (["..y..", "..Y..", "yYWYy", ".YYY.", ".y.y."], [".y.", "yWy", ".y."])
        }
    }

    static func mouth(_ mouth: Mouth) -> [String]? {
        switch mouth {
        case .none: return nil
        case .smile: return ["k...", ".kkk"]
        case .open: return ["kkkk", "kppk", ".kk."]
        case .chew: return ["kkk"]
        case .frown: return [".kkk", "k..."]
        }
    }

    static func decals(for built: Built, looks: Looks, pose: Pose, front: Bool = false) -> [Decal] {
        var decals: [Decal] = []
        let (near, far) = eyes(looks.eyes, pose.eyes)
        let stamp = { (rows: [String]) in
            PixelSprite(stamp: rows.map { $0 })
        }
        // Face decals are drawn at full resolution, so they are placed without upscaling.
        func hd(_ rows: [String], _ at: V2) -> Decal { Decal(sprite: stamp(rows), at: at, upscale: false) }
        if front {
            let x = built.eyeX.0
            if looks.eyes == .cyclops && pose.eyes == .open {
                decals.append(hd(near, built.onHead(V2(0, built.eyeY))))
            } else {
                decals.append(hd(near, built.onHead(V2(-x, built.eyeY))))
                decals.append(hd(near, built.onHead(V2(x, built.eyeY))))
            }
            if pose.blush && looks.shape != .ghost {
                decals.append(hd(["ppp"], built.onHead(V2(-x - 0.12, built.eyeY - 0.45))))
                decals.append(hd(["ppp"], built.onHead(V2(x + 0.12, built.eyeY - 0.45))))
            }
            if looks.shape != .bird, let rows = mouth(pose.mouth == .none ? .smile : pose.mouth) {
                let rows = pose.mouth == .none ? ["k..k", ".kk."] : rows
                decals.append(hd(rows, built.onHead(V2(0, looks.shape == .frog ? -1.4 : -0.5))))
            }
            return decals
        }
        if looks.eyes == .cyclops && pose.eyes == .open {
            decals.append(hd(near, built.onHead(V2((built.eyeX.0 + built.eyeX.1) / 2, built.eyeY))))
        } else {
            if looks.shape == .frog {
                // A frog's eyes sit up on bumps, so both show from the side.
                if !far.isEmpty { decals.append(hd(far, built.onHead(V2(built.eyeX.1, built.eyeY + 0.05)))) }
                decals.append(hd(near, built.onHead(V2(built.eyeX.0, built.eyeY))))
            } else {
                // In profile only the near eye is visible.
                decals.append(hd(near, built.onHead(V2((built.eyeX.0 + built.eyeX.1) / 2, built.eyeY))))
            }
        }
        if pose.blush && looks.shape != .ghost {
            decals.append(hd(["ppp"], built.onHead(built.cheek)))
        }
        if looks.shape != .bird, let rows = mouth(pose.mouth) {
            decals.append(hd(rows, built.onHead(built.mouth)))
        }
        return decals
    }
}

// MARK: - Accessories

enum AccessoryRig {
    static func parts(_ accessory: Accessory, on b: Built, pose: Pose) -> [Part] {
        let top = b.top
        let z = b.headZ + 0.5
        let a = b.headAngle
        func at(_ v: V2) -> V2 { top + rotate(v, by: a) }
        func poly(_ pts: [V2], _ ramp: Ramp, _ dz: Double = 0, group: Int = 20) -> Part {
            Part(.polygon(pts.map(at)), ramp, z: z + dz, group: group)
        }
        func blob(_ c: V2, _ r: V2, _ ramp: Ramp, _ dz: Double = 0, group: Int = 20) -> Part {
            Part(.ellipse(c: at(c), r: r, angle: a), ramp, z: z + dz, group: group)
        }
        let t = pose.t * 2 * .pi
        switch accessory {
        case .none:
            return []
        case .leaf:
            return [Part(.capsule(a: at(V2(0, -1)), b: at(V2(0.5, 1.5)), ra: 0.5, rb: 0.5), .wood, z: z, group: 20),
                    poly([V2(0.3, 1), V2(3.5, 3.8), V2(6, 3.5), V2(3.5, 0.8)], .green, 0.1)]
        case .bow:
            let c = V2(-2.5, -0.5)
            return [poly([c, c + V2(-3.5, 2.2), c + V2(-3.5, -2)], .red),
                    poly([c, c + V2(3.2, 2), c + V2(3.2, -2.2)], .red),
                    blob(c, V2(1.2, 1.2), .red, 0.1)]
        case .antenna:
            let tip = V2(2 + sin(t) * 0.8, 6)
            return [Part(.capsule(a: at(V2(0, -1)), b: at(tip), ra: 0.45, rb: 0.45), .dark, z: z, group: 20, innerOutline: false),
                    blob(tip, V2(1.6, 1.6), .gold, 0.1)]
        case .horns:
            return [Part(.capsule(a: at(V2(-2.8, -1.5)), b: at(V2(-4.5, 4.5)), ra: 1.4, rb: 0.4), .white, z: z - 0.1, group: 20, toneBias: 1),
                    Part(.capsule(a: at(V2(1.2, -1.2)), b: at(V2(2.2, 5)), ra: 1.5, rb: 0.4), .white, z: z, group: 21)]
        case .crest:
            return [poly([V2(-1, -1), V2(-5, 5), V2(-2.5, 1)], .red, -0.1),
                    poly([V2(-0.5, -1), V2(-1.5, 7), V2(0.8, 0.5)], .red),
                    poly([V2(0, -1), V2(2.8, 5.5), V2(1.8, -0.5)], .red, 0.05)]
        case .flower:
            let c = V2(-3, 0)
            var out = (0..<5).map { i -> Part in
                let ang = Double(i) / 5 * 2 * .pi
                return blob(c + V2(cos(ang), sin(ang)) * 1.7, V2(1.4, 1.4), .pink, 0, group: 20 + i)
            }
            out.append(blob(c, V2(1.1, 1.1), .gold, 0.2, group: 30))
            return out
        case .sprout:
            let tip = V2(0.5 + sin(t) * 0.5, 4)
            return [Part(.capsule(a: at(V2(0, -1)), b: at(tip), ra: 0.5, rb: 0.5), .green, z: z, group: 20),
                    Part(.ellipse(c: at(tip + V2(-1.8, 0.8)), r: V2(2, 1), angle: a + 0.4), .green, z: z + 0.1, group: 21),
                    Part(.ellipse(c: at(tip + V2(1.8, 1)), r: V2(2, 1), angle: a - 0.4), .green, z: z + 0.1, group: 22)]
        case .tophat:
            return [blob(V2(0, 0.3), V2(5.5, 1.2), .dark),
                    poly([V2(-3.5, 0.5), V2(3.5, 0.5), V2(3.2, 8), V2(-3.2, 8)], .dark, 0.1),
                    poly([V2(-3.45, 1), V2(3.45, 1), V2(3.4, 2.6), V2(-3.4, 2.6)], .red, 0.2)]
        case .cap:
            return [blob(V2(-0.5, 0.8), V2(4.8, 3.2), .red),
                    poly([V2(2.5, 0), V2(8.5, -0.8), V2(8.5, 0.6), V2(2.5, 1.6)], .red, 0.1, group: 21)]
        case .mushroom:
            return [blob(V2(0, 0.8), V2(1.6, 2.4), .white),
                    blob(V2(0, 3.2), V2(5.6, 3.2), .red, 0.1, group: 21),
                    blob(V2(-2.4, 4), V2(1, 0.9), .white, 0.2, group: 22),
                    blob(V2(1.8, 4.6), V2(1.1, 1), .white, 0.2, group: 23),
                    blob(V2(0, 2.4), V2(0.8, 0.7), .white, 0.2, group: 24)]
        case .unihorn:
            return [poly([V2(-1.7, -0.5), V2(1.7, -0.5), V2(1.6, 9.5)], .gold),
                    Part(.capsule(a: at(V2(-1, 2)), b: at(V2(1.4, 3)), ra: 0.45, rb: 0.45), .white, z: z + 0.1, group: 20,
                         innerOutline: false),
                    Part(.capsule(a: at(V2(-0.3, 5)), b: at(V2(1.5, 5.8)), ra: 0.4, rb: 0.4), .white, z: z + 0.1, group: 20,
                         innerOutline: false)]
        case .crown:
            return [poly([V2(-4.2, 0), V2(4.2, 0), V2(4.2, 5), V2(2.6, 2.8), V2(1, 5.6), V2(-0.6, 2.8), V2(-2.2, 5.6),
                          V2(-3.4, 2.8), V2(-4.2, 5)], .gold),
                    blob(V2(0, 1.4), V2(0.9, 0.9), .red, 0.1, group: 21),
                    blob(V2(-2.7, 1.4), V2(0.7, 0.7), .blue, 0.1, group: 22),
                    blob(V2(2.7, 1.4), V2(0.7, 0.7), .blue, 0.1, group: 23)]
        case .halo:
            let lift = 4 + sin(t) * 0.8
            return [Part(.ring(c: at(V2(0, lift)), r: V2(5, 2.2), width: 1.0), .gold, z: z, group: 20, fixedTone: .light)]
        case .flame:
            let f = sin(t * 2) * 0.8
            return [poly([V2(-3.5, -0.5), V2(3.5, -0.5), V2(2.5, 4), V2(0.5 + f, 9), V2(-1, 5), V2(-3 - f, 6.5)], .red),
                    poly([V2(-2, 0), V2(2, 0), V2(1.2, 3.5), V2(0.2 - f, 6.2), V2(-1.3, 3)], .gold, 0.1, group: 21)]
        }
    }
}

// MARK: - Composer

enum PetComposer {
    /// Pets are designed on a 32-unit canvas and rendered at 2x into 64 x 64 frames.
    static let size = 64
    static let renderScale = 2.0
    static let babyScale = 0.72

    /// One frame of a pet.
    static func frame(_ looks: Looks, view: PetView = .side, anim: PetAnim, frame i: Int, baby: Bool) -> PixelSprite {
        let pose = Pose.of(anim, frame: i)
        var built = view == .side ? SpeciesRig.build(looks.shape, pose: pose)
            : SpeciesRig.frontal(looks.shape, pose: pose, back: view == .back)
        built.parts += AccessoryRig.parts(looks.accessory, on: built, pose: pose)
        var decals = view == .back ? [] : Face.decals(for: built, looks: looks, pose: pose, front: view == .front)
        if baby {
            // Babies are smaller with a bigger head: scale the body around the feet, and grow
            // the head a little around its own centre.
            let s = babyScale
            let origin = V2(16, SpeciesRig.ground)
            let headC = built.headC
            let f: (V2) -> V2 = { origin + ($0 - origin) * s }
            built.parts = built.parts.map { part in
                var p = part
                let headish = part.role == .head || part.group == 1 || part.group == 6 || part.group >= 20
                if headish {
                    let g: (V2) -> V2 = { f(headC + ($0 - headC) * 1.22) }
                    p.shape = part.shape.transformed(g, scale: s * 1.22)
                } else {
                    p.shape = part.shape.transformed(f, scale: s)
                }
                return p
            }
            decals = decals.map { d in
                Decal(sprite: d.sprite, at: f(headC + (d.at - headC) * 1.22), upscale: d.upscale)
            }
        }
        let furry = ![.blob, .frog, .ghost].contains(looks.shape)
        return Rig.render(built.parts, decals: decals, size: size, scale: renderScale, pattern: looks.pattern, furry: furry)
    }

    /// All frames of one pet in `layout` order: the adult set, then the baby set.
    static func frames(for looks: Looks) -> [PixelSprite] {
        var out: [PixelSprite] = []
        for baby in [false, true] {
            for entry in layout {
                for i in 0..<entry.anim.frameCount {
                    out.append(frame(looks, view: entry.view, anim: entry.anim, frame: i, baby: baby))
                }
            }
        }
        return out
    }
}

// MARK: - Front and back views

/// How a species looks head-on. One generic rig draws every species from the front and back.
struct FrontProfile {
    enum Ears { case none, pointy(Double), round, long, darkTipped, bigRound, floppy, side, tufts }
    enum Snout { case none, muzzle(Double), beak, fox, bigSnout, pig, bill, nose(Ramp) }
    enum Tail { case none, thin, bushy, cotton, spade, feathers, curl, ringed }
    enum Body { case quadruped, biped, blob, ghost, frog }

    var body = Body.quadruped
    var bodyR = V2(6, 5.2)
    var headR = 5.3
    var headY = 6.0
    var legLen = 4.5
    var legR = (1.7, 1.4)
    var legGap = 2.8
    var ears = Ears.pointy(1)
    var snout = Snout.muzzle(1)
    var tail = Tail.thin
    var wings = false
    var batWings = false
    var socks = false
    var horns = false
    var chest: Ramp?
    var horn = false
    var mane = false
    var neck = false
    var spikes = false
    var mask = false
    var shell = false
    var gills = false
    var faceDisc = false
    var flippers = false

    static func of(_ shape: BodyShape) -> FrontProfile {
        if let p = more(shape) ?? wave3(shape) ?? wave4(shape) ?? wave5(shape) { return p }
        var p = FrontProfile()
        switch shape {
        case .blob:
            p.body = .blob; p.ears = .none; p.snout = .none; p.tail = .none
        case .ghost:
            p.body = .ghost; p.ears = .none; p.snout = .none; p.tail = .none
        case .frog:
            p.body = .frog; p.ears = .none; p.snout = .none; p.tail = .none
        case .bird:
            p.body = .biped; p.bodyR = V2(6.4, 6); p.headR = 4.8; p.headY = 6.8; p.legLen = 3.2; p.legR = (0.7, 0.6)
            p.legGap = 2.2; p.ears = .none; p.snout = .beak; p.tail = .feathers; p.wings = true
        case .cat:
            break
        case .fox:
            p.bodyR = V2(5.6, 5); p.headR = 5; p.legLen = 4.8; p.legR = (1.6, 1.3); p.ears = .darkTipped
            p.snout = .fox; p.tail = .bushy; p.socks = true; p.chest = .white
        case .bear:
            p.bodyR = V2(7.6, 6.3); p.headR = 5.8; p.headY = 6.6; p.legLen = 3.4; p.legR = (2.4, 2.2); p.legGap = 3.4
            p.ears = .round; p.snout = .bigSnout; p.tail = .cotton
        case .bunny:
            p.bodyR = V2(6.5, 6); p.headR = 5; p.headY = 6.4; p.legLen = 2.6; p.legR = (1.4, 1.2); p.legGap = 2.4
            p.ears = .long; p.snout = .muzzle(0.8); p.tail = .cotton
        case .dragon:
            p.bodyR = V2(6.4, 5.8); p.headR = 4.8; p.headY = 6.6; p.legLen = 3.8; p.legR = (2.1, 1.8); p.legGap = 3
            p.ears = .none; p.snout = .muzzle(1.2); p.tail = .spade; p.batWings = true; p.horns = true
        default:
            break
        }
        return p
    }
}

extension SpeciesRig {
    /// `custom: false` builds the shared profile body only; the wave files use it as a base
    /// before adding their own parts.
    static func frontal(_ shape: BodyShape, pose: Pose, back: Bool, custom: Bool = true) -> Built {
        if custom, let built = frontalWave3(shape, pose: pose, back: back) ?? frontalWave4(shape, pose: pose, back: back)
            ?? frontalWave5(shape, pose: pose, back: back) {
            return built
        }
        let p = FrontProfile.of(shape)
        var b = Built()
        let squash = pose.squash
        let angle = pose.sway
        let faceZ: Double = back ? -0.5 : 1

        func sym(_ f: (Double) -> Void) { f(-1); f(1) }

        switch p.body {
        case .blob, .ghost, .frog:
            let ghost = p.body == .ghost, frog = p.body == .frog
            let r = frog ? V2(10 / squash.squareRoot(), 5.6 * squash)
                : ghost ? V2(7.4 / squash.squareRoot(), 8.6 * squash) : V2(9 / squash.squareRoot(), 7.6 * squash)
            let float = ghost ? 2.5 + sin(pose.t * 2 * .pi) + pose.lift : pose.lift
            let c = V2(16, ground + 1 + r.y + pose.bob * 0.6 + float + pose.dangle * 1.5 + (frog ? 1 : 0))
            b.parts.append(Part(.ellipse(c: c, r: r, angle: angle), .body, z: 0, group: 0, patterned: true, role: .torso))
            if !back && !ghost {
                b.parts.append(Part(.ellipse(c: c + V2(0, -r.y * 0.45), r: V2(r.x * 0.55, r.y * 0.4), angle: angle),
                                    .secondary, z: 0.1, group: 0))
            }
            if ghost {
                for i in 0..<4 {
                    let wave = sin(pose.t * 2 * .pi + Double(i) * 1.6) * 0.8
                    b.parts.append(Part(.ellipse(c: c + V2(-5.4 + Double(i) * 3.6, -r.y * 0.78 + wave), r: V2(1.9, 2.2), angle: 0),
                                        .body, z: 0.05, group: 0, patterned: true, role: .torso))
                }
            }
            let armUp = pose.paw + pose.dangle * 0.8 + max(0, pose.wing) * 0.5
            sym { s in
                if !frog {
                    b.parts.append(Part(.ellipse(c: c + V2(s * (r.x - 0.5), -1 + armUp * 2), r: V2(2, 1.5),
                                                 angle: s * (0.5 + armUp)), .body, z: 0.5, group: 6, patterned: true, role: .limb))
                }
                if p.body == .blob || frog {
                    let foot = pose.dangle > 0 ? V2(16 + s * 3, c.y - r.y - 1) : V2(16 + s * (frog ? 6.5 : 4), ground + 1.1 + pose.lift)
                    b.parts.append(Part(.ellipse(c: foot, r: V2(frog ? 3.2 : 2.6, 1.4), angle: 0), .body, z: 0.8,
                                        group: 3, patterned: true, role: .limb))
                }
                if frog {
                    b.parts.append(Part(.ellipse(c: c + V2(s * 4.5, r.y * 0.85), r: V2(3, 3), angle: 0), .body, z: -0.2,
                                        group: 7, patterned: true, role: .head))
                }
            }
            b.headC = frog ? c + V2(0, r.y * 0.85) : c + V2(0, ghost ? 3 : 1.5)
            b.headR = frog ? 4.5 : 5.5
            b.headAngle = angle
            b.topOverride = c + V2(0, r.y + (frog ? 2.5 : 0))
            b.eyeX = (frog ? 1 : 0.42, 0)
            b.eyeY = frog ? 0 : 0.15

        case .quadruped, .biped:
            let legLen = p.legLen * (1 + 0.2 * pose.dangle) * (1 - 0.7 * pose.lying)
            let bodyR = V2(p.bodyR.x / squash.squareRoot(), p.bodyR.y * squash)
            let c = V2(16, ground + legLen + bodyR.y * 0.72 + pose.bob + pose.lift)
            let biped = p.body == .biped
            b.parts.append(Part(.ellipse(c: c, r: bodyR, angle: angle), .body, z: 0, group: 0, patterned: true, role: .torso))
            if !back {
                b.parts.append(Part(.ellipse(c: c + V2(0, -bodyR.y * 0.3), r: V2(bodyR.x * 0.5, bodyR.y * 0.55), angle: angle),
                                    p.chest ?? .secondary, z: 0.1, group: 0))
            }
            // Legs: the near pair in full, the far pair peeking out at the sides.
            sym { s in
                let hip = c + rotate(V2(s * p.legGap, -bodyR.y * 0.5), by: angle)
                let step = pose.stride * s
                var foot = V2(hip.x + s * 0.3, ground + p.legR.1 + pose.lift + max(0, step) * 1.2)
                if pose.dangle > 0 { foot = hip + V2(s * 0.5 + sin(pose.sway * 3) * 0.6, -legLen * 1.1) }
                if pose.paw > 0 && s > 0 { foot = hip + V2(2, -legLen * 0.2 + pose.paw * 2.5) }
                let ramp: Ramp = biped ? .gold : .body
                b.parts.append(Part(.capsule(a: hip, b: foot, ra: p.legR.0, rb: p.legR.1), ramp, z: back ? -0.1 : 2,
                                    group: s < 0 ? 3 : 4, patterned: !biped, role: .limb, innerOutline: !biped))
                if p.socks {
                    b.parts.append(Part(.capsule(a: hip + (foot - hip) * 0.55, b: foot, ra: p.legR.1 * 1.05, rb: p.legR.1 * 1.05),
                                        .dark, z: (back ? -0.1 : 2) + 0.01, group: s < 0 ? 3 : 4))
                }
                if !biped {
                    let hind = c + rotate(V2(s * (p.legGap + 2), -bodyR.y * 0.4), by: angle)
                    b.parts.append(Part(.capsule(a: hind, b: V2(hind.x + s * 0.8, ground + p.legR.1 + pose.lift), ra: p.legR.0,
                                                 rb: p.legR.1), .body, z: back ? 2 : -1, group: s < 0 ? 5 : 8, patterned: true,
                                        toneBias: back ? 0 : 1, role: .limb))
                }
                if p.flippers {
                    let flap = pose.wing
                    b.parts.append(Part(.ellipse(c: c + V2(s * (bodyR.x - 0.2), -0.5 + flap), r: V2(1.6, 4.6),
                                                 angle: s * (0.25 + flap * 0.5)), .body, z: back ? 0.5 : 0.4,
                                        group: s < 0 ? 9 : 10, role: .extremity))
                }
                if p.wings {
                    let flap = pose.wing
                    b.parts.append(Part(.ellipse(c: c + V2(s * (bodyR.x - 0.5), 0.5 + flap), r: V2(2.6, 4.4),
                                                 angle: s * (-0.3 - flap * 0.6)), .secondary, z: back ? 0.5 : 0.4,
                                        group: s < 0 ? 9 : 10, role: .extremity))
                }
                if p.batWings {
                    let flap = pose.wing
                    let root = c + V2(s * 2.5, bodyR.y * 0.5)
                    b.parts.append(Part(.polygon([root, root + V2(s * 3.5, 7 + flap * 3), root + V2(s * 6, 5.5 + flap * 2),
                                                  root + V2(s * 10, 7.5 + flap * 2.5), root + V2(s * 9.5, 2),
                                                  root + V2(s * 6.5, 0.5), root + V2(s * 4, -1.5)]), .secondary, z: back ? 0.5 : -1.5,
                                        group: s < 0 ? 11 : 12, toneBias: back ? 0 : 1))
                }
            }
            // Head
            let headC = c + rotate(V2(0, p.headY), by: angle) + V2(0, -pose.headDip - pose.lying * 2)
            b.headC = headC
            b.headR = p.headR
            b.headAngle = angle * 0.6 + pose.headTilt
            b.headZ = faceZ
            b.parts.append(Part(.ellipse(c: headC, r: V2(p.headR * 1.06, p.headR), angle: b.headAngle), .body, z: faceZ,
                                group: 1, patterned: true, role: .head))
            // Ears
            let earZ = back ? 0.5 : faceZ - 0.1
            sym { s in
                switch p.ears {
                case .none:
                    break
                case .pointy, .darkTipped:
                    let big = { if case .darkTipped = p.ears { return 1.2 } else { return 1.0 } }()
                    let pts = [V2(s * 0.25, 0.85), V2(s * 0.85, 0.5), V2(s * 0.7, 0.5 + 1.05 * big)]
                    b.parts.append(Part(headPolygon(b, pts), .body, z: earZ, group: 6, patterned: true, role: .extremity))
                    if case .darkTipped = p.ears {
                        let tip = pts[2]
                        b.parts.append(Part(headPolygon(b, [tip, tip + (pts[0] - tip) * 0.32, tip + (pts[1] - tip) * 0.32]),
                                            .dark, z: earZ + 0.01, group: 6, innerOutline: false))
                    } else if !back {
                        b.parts.append(Part(headPolygon(b, [V2(s * 0.38, 0.86), V2(s * 0.75, 0.62), V2(s * 0.66, 1.2)]), .pink,
                                            z: earZ + 0.01, group: 6, innerOutline: false))
                    }
                case .bigRound:
                    let ec = b.onHead(V2(s * 0.78, 0.82))
                    b.parts.append(Part(.ellipse(c: ec, r: V2(3, 3), angle: 0), .body, z: earZ, group: 6, patterned: true,
                                        role: .extremity))
                    if !back {
                        b.parts.append(Part(.ellipse(c: ec, r: V2(1.9, 1.9), angle: 0), .pink, z: earZ + 0.01, group: 6,
                                            innerOutline: false))
                    }
                case .floppy:
                    let base = V2(s * 0.5, 0.7)
                    b.parts.append(Part(headPolygon(b, [base, base + V2(s * 0.55, 0.2), base + V2(s * 0.6, -0.5)]), .body,
                                        z: back ? 0.5 : faceZ + 0.15, group: 6, patterned: true, role: .extremity))
                case .side:
                    let ec = b.onHead(V2(s * 1.05, 0.55))
                    b.parts.append(Part(.ellipse(c: ec, r: V2(2.4, 1.1), angle: s * 0.35), .body, z: earZ, group: 6,
                                        patterned: true, role: .extremity))
                case .tufts:
                    let base = V2(s * 0.45, 0.75)
                    b.parts.append(Part(headPolygon(b, [base, base + V2(s * 0.45, 0), base + V2(s * 0.5, 0.8)]), .body, z: earZ,
                                        group: 6, role: .extremity))
                case .round:
                    let ec = b.onHead(V2(s * 0.72, 0.78))
                    b.parts.append(Part(.ellipse(c: ec, r: V2(2.1, 2.1), angle: 0), .body, z: earZ, group: 6, patterned: true,
                                        role: .extremity))
                    if !back {
                        b.parts.append(Part(.ellipse(c: ec, r: V2(1, 1), angle: 0), .secondary, z: earZ + 0.01, group: 6,
                                            innerOutline: false))
                    }
                case .long:
                    let flop = pose.lying * 1.2 + pose.dangle * 0.5
                    let root = b.onHead(V2(s * 0.4, 0.75))
                    let tip = root + rotate(V2(0, 8.5), by: -s * (0.15 + flop))
                    b.parts.append(Part(.capsule(a: root, b: tip, ra: 1.6, rb: 1.4), .body, z: earZ, group: 6, patterned: true,
                                        role: .extremity))
                    if !back {
                        b.parts.append(Part(.capsule(a: root + (tip - root) * 0.2, b: tip - (tip - root) * 0.12, ra: 0.6, rb: 0.6),
                                            .pink, z: earZ + 0.01, group: 6, innerOutline: false))
                    }
                }
                if p.horns {
                    let base = V2(s * 0.45, 0.75)
                    b.parts.append(Part(headPolygon(b, [base, base + V2(s * 0.4, 0), base + V2(s * 0.45, 0.9)]), .gold,
                                        z: earZ, group: 6))
                }
            }
            // Snout
            if !back {
                switch p.snout {
                case .none:
                    break
                case let .muzzle(size):
                    b.parts.append(Part(.ellipse(c: b.onHead(V2(0, -0.42)), r: V2(2.4, 1.7) * size, angle: b.headAngle),
                                        .secondary, z: faceZ + 0.1, group: 1))
                case .bigSnout:
                    b.parts.append(Part(.ellipse(c: b.onHead(V2(0, -0.4)), r: V2(3, 2.2), angle: b.headAngle), .secondary,
                                        z: faceZ + 0.1, group: 1))
                case .fox:
                    b.parts.append(Part(headPolygon(b, [V2(-0.55, -0.15), V2(0.55, -0.15), V2(0, -0.95)]), .white,
                                        z: faceZ + 0.1, group: 1))
                case .pig:
                    b.parts.append(Part(.ellipse(c: b.onHead(V2(0, -0.35)), r: V2(2.4, 1.8), angle: 0), .pink,
                                        z: faceZ + 0.2, group: 2))
                case .bill:
                    let open = pose.mouth == .open ? 0.2 : 0
                    b.parts.append(Part(headPolygon(b, [V2(-0.55, -0.15), V2(0.55, -0.15), V2(0.5, -0.6 - open), V2(-0.5, -0.6 - open)]),
                                        .gold, z: faceZ + 0.2, group: 2))
                case .nose(let ramp):
                    b.parts.append(Part(.ellipse(c: b.onHead(V2(0, -0.35)), r: V2(0.9, 0.75), angle: 0), ramp,
                                        z: faceZ + 0.2, group: 2))
                case .beak:
                    let open = pose.mouth == .open ? 0.25 : 0
                    b.parts.append(Part(headPolygon(b, [V2(-0.35, -0.2), V2(0.35, -0.2), V2(0, -0.75 - open)]), .gold,
                                        z: faceZ + 0.2, group: 2))
                }
            }
            // Tail: peeking out behind from the front, in full view from the back.
            let tailBase = c + rotate(V2(back ? 0 : 2.5, bodyR.y * 0.1), by: angle)
            let tailZ = back ? 1.5 : -1.0
            let wag = pose.tail * 0.3
            switch p.tail {
            case .none:
                break
            case .thin:
                b.parts += tail(from: tailBase, angle: 1.2 + wag, curl: 0.35, segments: 3, length: 3, radius: (1.3, 1), ramp: .body, z: tailZ)
            case .bushy:
                b.parts.append(Part(.ellipse(c: tailBase + V2(back ? wag * 4 : 5, 4), r: V2(2.8, 4.5), angle: 0.3 - wag),
                                    .body, z: tailZ, group: 5, patterned: true, role: .extremity))
                b.parts.append(Part(.ellipse(c: tailBase + V2(back ? wag * 4 : 5.6, 7.5), r: V2(2, 1.8), angle: 0), .white,
                                    z: tailZ + 0.01, group: 5))
            case .cotton:
                if back {
                    b.parts.append(Part(.ellipse(c: c + V2(wag, -bodyR.y * 0.2), r: V2(2.4, 2.4), angle: 0), .white, z: tailZ, group: 5))
                }
            case .spade:
                b.parts += tail(from: tailBase, angle: back ? -1.3 : -0.4, curl: 0.5 + wag, segments: 2, length: 3.6,
                                radius: (1.8, 1), ramp: .body, z: tailZ)
            case .curl:
                if back {
                    b.parts.append(Part(.ring(c: c + V2(0, -bodyR.y * 0.1), r: V2(1.6, 1.6), width: 1), .pink, z: tailZ, group: 5))
                }
            case .ringed:
                var tp = tailBase
                var a = (back ? -1.2 : 0.9) + wag
                for k in 0..<4 {
                    let next = tp + rotate(V2(2.4, 0), by: a)
                    b.parts.append(Part(.capsule(a: tp, b: next, ra: 2, rb: 1.9), k % 2 == 0 ? .body : .dark, z: tailZ + Double(k) * 0.01,
                                        group: 5))
                    tp = next
                    a += back ? -0.3 : 0.3
                }
            case .feathers:
                let fan = back ? 0.0 : 3.0
                b.parts.append(Part(.polygon([c + V2(-3 + fan, 2), c + V2(-5 + fan, 9), c + V2(0 + fan, 10), c + V2(5 + fan, 9),
                                              c + V2(3 + fan, 2)]), .body, z: back ? 1.5 : -1, group: 5, patterned: true,
                                    role: .extremity))
            }
            // Species features.
            if p.neck {
                b.parts.append(Part(.capsule(a: c + V2(0, bodyR.y * 0.4), b: headC + V2(0, -2), ra: 2.4, rb: 2), .body,
                                    z: back ? -0.6 : 0.6, group: 1, patterned: true))
            }
            if p.horn {
                let base = b.onHead(V2(0, 0.85))
                b.parts.append(Part(.polygon([base + V2(-1.1, 0), base + V2(1.1, 0), base + V2(0, 7.5)]), .gold, z: faceZ + 0.4, group: 21))
                b.parts.append(Part(.capsule(a: base + V2(-0.8, 2), b: base + V2(0.8, 2.6), ra: 0.35, rb: 0.35), .white, z: faceZ + 0.41,
                                    group: 21, innerOutline: false))
            }
            if p.mane {
                let top = b.onHead(V2(0, 1))
                b.parts.append(Part(.polygon([top + V2(-2.5, -0.5), top + V2(2.5, -0.5), top + V2(1.5, 1.8), top + V2(-1.5, 2)]),
                                    .secondary, z: faceZ + 0.3, group: 22))
                if back {
                    b.parts.append(Part(.polygon([top + V2(-2, 0), top + V2(2, 0), c + V2(1.5, bodyR.y * 0.6), c + V2(-1.5, bodyR.y * 0.6)]),
                                        .secondary, z: faceZ + 0.3, group: 22))
                }
            }
            if p.spikes {
                for k in 0..<13 {
                    let a = Double(k) / 12 * .pi
                    let root = c + V2(cos(a) * bodyR.x * 0.9, sin(a) * bodyR.y * 0.8 + 1)
                    let out = V2(cos(a), sin(a) + 0.3)
                    let side = V2(-out.y, out.x)
                    b.parts.append(Part(.polygon([root + side * 1.5, root - side * 1.5, root + out * 4.5]), .secondary,
                                        z: back ? 2 + Double(k) * 0.001 : -0.5, group: 23, toneBias: k % 2))
                }
            }
            if p.mask && !back {
                b.parts.append(Part(headPolygon(b, [V2(-0.95, 0.35), V2(0.95, 0.35), V2(0.9, -0.05), V2(0, -0.2), V2(-0.9, -0.05)]),
                                    .dark, z: faceZ + 0.05, group: 1))
            }
            if p.shell {
                b.parts.append(Part(.ellipse(c: c + V2(0, bodyR.y * 0.4), r: V2(bodyR.x * 1.3, bodyR.y * 1.25), angle: angle),
                                    .secondary, z: back ? 2.5 : -0.3, group: 24))
            }
            if p.gills {
                for side in [-1.0, 1.0] {
                    for (k, a) in [0.6, 1.0, 1.4].enumerated() {
                        let root = b.onHead(V2(side * 0.8, 0.1))
                        let dir = V2(side * cos(a - 0.4), sin(a - 0.4) + 0.2)
                        b.parts.append(Part(.capsule(a: root, b: root + dir * 5, ra: 1.1, rb: 0.6), .secondary,
                                            z: faceZ - 0.2 - Double(k) * 0.01, group: 25, role: .extremity))
                    }
                }
            }
            if p.faceDisc && !back {
                b.parts.append(Part(.ellipse(c: b.onHead(V2(0, -0.05)), r: V2(p.headR * 0.8, p.headR * 0.72), angle: 0), .secondary,
                                    z: faceZ + 0.02, group: 1))
            }
            b.eyeX = (0.42, 0)
            b.eyeY = 0.12
        }
        return b
    }
}

typealias PetView = PetFacing

extension PetComposer {
    /// Which animations each view has. Everything else falls back to the side view.
    static func anims(for view: PetView) -> [PetAnim] {
        switch view {
        case .side: return PetAnim.allCases
        case .front: return [.idle, .eat, .hop, .held, .sick, .sleep]
        case .back: return [.idle]
        }
    }

    /// Frame list layout for one pet: for baby false then true, for each view, each of its animations' frames.
    static let layout: [(view: PetView, anim: PetAnim)] = PetView.allCases.flatMap { v in anims(for: v).map { (v, $0) } }

    static let framesPerSet = layout.reduce(0) { $0 + $1.anim.frameCount }

    /// Index of the first frame of (`view`, `anim`) in a pet's frames, falling back to the side view.
    static func frameIndex(view: PetView, anim: PetAnim, frame: Int, baby: Bool) -> Int {
        let v = anims(for: view).contains(anim) ? view : .side
        var index = baby ? framesPerSet : 0
        for entry in layout {
            if entry.view == v && entry.anim == anim { return index + frame % anim.frameCount }
            index += entry.anim.frameCount
        }
        return 0
    }
}
