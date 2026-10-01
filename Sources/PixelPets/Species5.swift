import Foundation

// Wave 5 species: jackalope, qilin, mothkin, wyvern, phoenix, spiritStag, skyWhale, thunderbird, sphinx, cerberus.
// Epic animals are plainly magical. Legendary ones carry glowing details in fixed ramps (gold, red, blue,
// white) so they look legendary whatever their body colour.


extension SpeciesRig {
    /// Side rigs for this wave. Returns nil for any other shape.
    static func buildWave5(_ shape: BodyShape, pose: Pose) -> Built? {
        switch shape {
        case .jackalope: return w5Jackalope(pose)
        case .qilin: return w5Qilin(pose)
        case .mothkin: return w5Mothkin(pose)
        case .wyvern: return w5Wyvern(pose)
        case .phoenix: return w5Phoenix(pose)
        case .spiritStag: return w5Stag(pose)
        case .skyWhale: return w5Whale(pose)
        case .thunderbird: return w5Thunderbird(pose)
        case .sphinx: return w5Sphinx(pose)
        case .cerberus: return w5Cerberus(pose)
        default: return nil
        }
    }

    /// Fully custom front or back views, for animals the shared FrontProfile can't express.
    /// Returns nil to use the profile from `FrontProfile.wave5`.
    static func frontalWave5(_ shape: BodyShape, pose: Pose, back: Bool) -> Built? {
        switch shape {
        case .skyWhale:
            return w5WhaleFront(pose, back: back)
        case .jackalope, .qilin, .mothkin, .wyvern, .phoenix, .spiritStag, .thunderbird, .sphinx, .cerberus:
            // Draw the shared body from the profile, then add what the profile can't express.
            var b = frontal(shape, pose: pose, back: back, custom: false)
            w5DecorateFront(shape, &b, pose: pose, back: back)
            return b
        default:
            return nil
        }
    }

    // MARK: Shared pieces

    /// A curve of `steps` equal steps, turning by `curl` each step.
    private static func w5Curve(from p0: V2, angle: Double, curl: Double, steps: Int, step: Double) -> [V2] {
        var pts = [p0]
        var p = p0
        var a = angle
        for _ in 0..<steps {
            p += rotate(V2(step, 0), by: a)
            pts.append(p)
            a += curl
        }
        return pts
    }

    /// A strip of varying half-width along a spine: manes, feathers, antennae.
    private static func w5Ribbon(_ spine: [V2], _ widths: [Double]) -> Shape {
        var left: [V2] = [], right: [V2] = []
        for i in spine.indices {
            let d = spine[min(spine.count - 1, i + 1)] - spine[max(0, i - 1)]
            let l = max(0.001, (d.x * d.x + d.y * d.y).squareRoot())
            let n = V2(-d.y, d.x) / l
            let w = widths[min(i, widths.count - 1)]
            left.append(spine[i] + n * w)
            right.append(spine[i] - n * w)
        }
        return .polygon(left + right.reversed())
    }

    /// Points given in a local frame (x forward, y up), mirrored by `flip` and turned by `angle` about `origin`.
    private static func w5Local(_ origin: V2, _ angle: Double, _ pts: [V2], flip: Double = 1, scale: V2 = V2(1, 1)) -> [V2] {
        pts.map { origin + rotate(V2($0.x * flip * scale.x, $0.y * scale.y), by: angle) }
    }

    /// A flickering flame: a tongue with a bright core, pointing along `dir`.
    private static func w5Flame(_ base: V2, dir: Double, length: Double, width: Double, flicker: Double,
                                outer: Ramp = .red, inner: Ramp = .gold, z: Double, group: Int) -> [Part] {
        let f = V2(cos(dir), sin(dir)), n = V2(-f.y, f.x)
        func tongue(_ at: V2, _ k: Double) -> [V2] {
            let l = length * k, w = width * k
            return [at - n * w, at + f * l * 0.45 - n * w * 0.8, at + f * l + n * flicker * k, at + f * l * 0.5 + n * w * 0.9,
                    at + n * w, at - f * w * 0.8]
        }
        return [Part(.polygon(tongue(base, 1)), outer, z: z, group: group, fixedTone: .base),
                Part(.polygon(tongue(base + f * width * 0.3, 0.55)), inner, z: z + 0.01, group: group, innerOutline: false,
                     fixedTone: .light)]
    }

    /// Branching antlers as (from, to, radius from, radius to) in local units: x forward, y up.
    private typealias W5Branches = [(V2, V2, Double, Double)]

    private static let w5HareAntler: W5Branches = [
        (V2(0, 0), V2(0.2, 2.4), 0.65, 0.55), (V2(0.2, 2.4), V2(-0.5, 4.6), 0.55, 0.45),
        (V2(0.2, 2.4), V2(1.8, 3.8), 0.5, 0.45), (V2(0, 1.2), V2(-1.4, 2.1), 0.5, 0.45),
    ]
    private static let w5QilinHorn: W5Branches = [
        (V2(0, 0), V2(-0.9, 2.6), 0.8, 0.6), (V2(-0.9, 2.6), V2(-2.8, 4.5), 0.6, 0.45),
        (V2(-0.9, 2.6), V2(0.5, 4.3), 0.55, 0.45), (V2(-0.4, 1.3), V2(0.9, 2.1), 0.5, 0.45),
    ]
    private static let w5StagAntler: W5Branches = [
        (V2(0, 0), V2(-0.7, 2.8), 1.0, 0.85), (V2(-0.7, 2.8), V2(-1.0, 5.6), 0.85, 0.75),
        (V2(-1.0, 5.6), V2(-2.8, 7.8), 0.75, 0.6), (V2(-1.0, 5.6), V2(0.8, 8.0), 0.7, 0.6),
        (V2(-0.3, 1.2), V2(1.9, 2.6), 0.75, 0.6), (V2(-0.9, 3.8), V2(1.4, 5.1), 0.7, 0.6),
        (V2(-0.9, 4.2), V2(-3.2, 5.0), 0.7, 0.65), (V2(-3.2, 5.0), V2(-4.2, 6.8), 0.65, 0.6),
    ]

    private static func w5Antler(_ branches: W5Branches, root: V2, scale k: Double, lean: Double, flip: Double = 1,
                                 ramp: Ramp, z: Double, group: Int, bias: Int = 0, glow: Tone? = nil) -> [Part] {
        branches.map { s in
            let a = root + rotate(V2(s.0.x * flip, s.0.y) * k, by: lean)
            let b = root + rotate(V2(s.1.x * flip, s.1.y) * k, by: lean)
            return Part(.capsule(a: a, b: b, ra: s.2 * k, rb: s.3 * k), ramp, z: z, group: group, toneBias: bias, fixedTone: glow)
        }
    }

    /// Hooves over the end of every leg.
    private static func w5Hooves(_ b: inout Built, ramp: Ramp) {
        for part in b.parts where part.role == .limb {
            if case let .capsule(_, f, _, rb) = part.shape {
                b.parts.append(Part(.ellipse(c: f, r: V2(rb * 1.3, rb * 1.05), angle: 0), ramp, z: part.z + 0.01, group: part.group,
                                    toneBias: part.toneBias))
            }
        }
    }

    /// A small eye for heads the face system doesn't know about.
    private static func w5Eye(_ at: V2, pose: Pose, z: Double, group: Int) -> [Part] {
        if pose.eyes == .closed {
            return [Part(.capsule(a: at + V2(-0.6, 0.1), b: at + V2(0.6, 0.1), ra: 0.3, rb: 0.3), .dark, z: z, group: group,
                         innerOutline: false, fixedTone: .base)]
        }
        return [Part(.ellipse(c: at, r: V2(0.65, 0.9), angle: 0), .dark, z: z, group: group, innerOutline: false, fixedTone: .base),
                Part(.ellipse(c: at + V2(-0.2, 0.3), r: V2(0.3, 0.3), angle: 0), .white, z: z + 0.01, group: group,
                     innerOutline: false, fixedTone: .light)]
    }

    /// Glowing motes drifting around a body: embers, wisps, sparks.
    private static func w5Motes(_ pose: Pose, around c: V2, spread: V2, ramp: Ramp, core: Ramp, count: Int = 3, rise: Bool,
                                z: Double = 3) -> [Part] {
        var parts: [Part] = []
        for k in 0..<count {
            let ph = pose.t + Double(k) / Double(count)
            let x = c.x + spread.x * cos(Double(k) * 2.1 + 0.6)
            let y = rise ? c.y - spread.y + (ph - ph.rounded(.down)) * spread.y * 2
                : c.y + spread.y * sin(2 * .pi * ph + Double(k))
            let p = V2(x + sin(2 * .pi * ph) * 0.8, y)
            let front = k % 2 == 0
            parts.append(Part(.capsule(a: p, b: p + V2(-0.6, rise ? -1.4 : -0.5), ra: 0.85, rb: 0.45), ramp,
                              z: front ? z : -z, group: 15 + k, fixedTone: .base))
            parts.append(Part(.ellipse(c: p, r: V2(0.45, 0.45), angle: 0), core, z: (front ? z : -z) + 0.01, group: 15 + k,
                              innerOutline: false, fixedTone: .light))
        }
        return parts
    }

    private static func w5Torso(_ b: Built) -> (c: V2, r: V2) {
        for p in b.parts where p.role == .torso {
            if case let .ellipse(c, r, _) = p.shape { return (c, r) }
        }
        return (V2(16, 10), V2(6, 5))
    }

    // MARK: Jackalope

    static func w5Jackalope(_ pose: Pose) -> Built {
        var b = bunny(pose)
        // A hare's ears instead of the bunny's: laid further back, with dark tips.
        b.parts.removeAll { $0.group == 6 }
        let flop = pose.lying * 0.9 + pose.dangle * 0.5 + pose.headDip * 0.06
        for (x, z, bias) in [(-0.65, 0.9, 1), (-0.2, 1.2, 0)] {
            let root = b.onHead(V2(x, 0.7))
            let tip = root + rotate(V2(0, 7.4), by: 0.6 + flop + (bias == 1 ? 0.22 : 0) + pose.tail * 0.05)
            b.parts.append(Part(.capsule(a: root, b: tip, ra: 1.5, rb: 1.1), .body, z: z, group: 6, patterned: true,
                                toneBias: bias, role: .extremity))
            b.parts.append(Part(.capsule(a: root + (tip - root) * 0.8, b: tip, ra: 1.25, rb: 1.1), .dark, z: z + 0.01, group: 6,
                                toneBias: bias, innerOutline: false))
            if bias == 0 {
                b.parts.append(Part(.capsule(a: root + (tip - root) * 0.2, b: root + (tip - root) * 0.7, ra: 0.6, rb: 0.5), .pink,
                                    z: z + 0.01, group: 6, innerOutline: false))
            }
        }
        // Little antlers between the ears.
        let lean = b.headAngle - 0.1 + pose.lying * 0.3
        b.parts += w5Antler(w5HareAntler, root: b.onHead(V2(-0.3, 0.85)), scale: 1.3, lean: lean + 0.15, ramp: .wood, z: 0.85,
                            group: 41, bias: 1)
        b.parts += w5Antler(w5HareAntler, root: b.onHead(V2(0.15, 0.88)), scale: 1.3, lean: lean, ramp: .wood, z: 1.25, group: 40)
        b.topOverride = b.onHead(V2(-0.1, 1.0))
        return b
    }

    // MARK: Qilin

    static func w5Qilin(_ pose: Pose) -> Built {
        var spec = QuadSpec()
        spec.bodyR = V2(8.2, 5.2)
        spec.bodyX = 14.6
        spec.legLen = 6
        spec.legR = (1.6, 1.1)
        spec.legX = (5.5, -5.5)
        spec.headR = 4.2
        spec.headOffset = V2(8.2, 8.2)
        spec.bellyR = V2(4.5, 2)
        var p = pose
        p.lift *= 0.8
        let q = quadruped(spec, p)
        var b = q.built
        // Scales over the back and flank: little lit domes, back rows first.
        for (row, y) in [2.8, 0.9].enumerated() {
            for k in 0..<5 {
                let x = -5.2 + Double(k) * 2.4 + (row == 0 ? 0 : 1.2)
                let c = q.bodyC + rotate(V2(x, y), by: q.angle)
                b.parts.append(Part(.ellipse(c: c, r: V2(1.35, 1.05), angle: q.angle), .body, z: 0.05 + Double(row) * 0.01,
                                    group: 0, innerOutline: false))
            }
        }
        // Neck and a dragon's snout with a nostril.
        let neckBase = q.bodyC + rotate(V2(q.bodyR.x * 0.6, q.bodyR.y * 0.3), by: q.angle)
        b.parts.append(Part(.capsule(a: neckBase, b: b.headC + V2(-1.5, -1.5), ra: 2.8, rb: 2.1), .body, z: 0.5, group: 1,
                            patterned: true))
        b.parts.append(Part(.ellipse(c: b.onHead(V2(1.0, -0.4)), r: V2(2.9, 1.9), angle: b.headAngle - 0.15), .body, z: 1.1,
                            group: 1, patterned: true))
        b.parts.append(Part(.ellipse(c: b.onHead(V2(1.55, -0.3)), r: V2(0.6, 0.5), angle: 0), .dark, z: 1.2, group: 1))
        // Flowing mane down the neck, in licks like flames.
        let top = b.onHead(V2(-0.35, 0.9)), bottom = neckBase + V2(-3, 2.6)
        var mane: [V2] = []
        for i in 0...4 {
            let f = Double(i) / 4
            let on = top + (bottom - top) * f
            mane.append(on)
            if i < 4 {
                let wave = sin(2 * .pi * pose.t + Double(i)) * 0.5
                mane.append(on + (bottom - top) * 0.12 + V2(-2.6 - Double(i) * 0.2, 1.4 + wave))
            }
        }
        mane += [bottom + V2(2, -1), b.onHead(V2(-0.9, -0.3))]
        b.parts.append(Part(.polygon(mane), .secondary, z: 0.7, group: 7))
        // A tuft at the forehead.
        b.parts.append(Part(headPolygon(b, [V2(-0.1, 0.8), V2(0.75, 0.75), V2(-0.4, 1.35)]), .secondary, z: 1.3, group: 7))
        // Antler-horns, swept back.
        let lean = b.headAngle + 0.35
        b.parts += w5Antler(w5QilinHorn, root: b.onHead(V2(-0.45, 0.8)), scale: 1, lean: lean + 0.15, ramp: .gold, z: 0.85,
                            group: 41, bias: 1)
        b.parts += w5Antler(w5QilinHorn, root: b.onHead(V2(-0.05, 0.85)), scale: 1, lean: lean, ramp: .gold, z: 1.3, group: 40)
        // Golden hooves, each with a blue flame wisp at the fetlock.
        w5Hooves(&b, ramp: .gold)
        var k = 0
        for part in b.parts where part.role == .limb {
            if case let .capsule(_, f, _, _) = part.shape {
                let flicker = sin(2 * .pi * (pose.t * 2) + Double(k) * 1.7) * 0.6
                b.parts += w5Flame(f + V2(-0.9, 1.8), dir: 2.0, length: 3.8, width: 1.0, flicker: flicker, outer: .blue,
                                   inner: .white, z: part.z + 0.02, group: 10 + k)
                k += 1
            }
        }
        // A lion's tail ending in a flame-like tuft.
        let base = q.bodyC + rotate(V2(-q.bodyR.x * 0.9, q.bodyR.y * 0.3), by: q.angle)
        let tailParts = tail(from: base, angle: 2.95 + pose.tail * 0.3 - pose.dangle, curl: -0.35, segments: 3, length: 1.8,
                             radius: (1.0, 0.7), ramp: .body, z: -1)
        b.parts += tailParts
        if case let .capsule(_, tip, _, _) = tailParts.last!.shape {
            let spine = w5Curve(from: tip + V2(0.5, 0.3), angle: 1.6 + pose.tail * 0.3, curl: -0.4, steps: 3, step: 1.4)
            b.parts.append(Part(w5Ribbon(spine, [1.2, 1.6, 1.2, 0.3]), .secondary, z: -0.9, group: 5))
        }
        b.eyeX = (0.2, 0.6)
        b.eyeY = 0.2
        b.mouth = V2(1.45, -0.8)
        b.topOverride = b.onHead(V2(-0.3, 1.0))
        return b
    }

    // MARK: Mothkin

    /// Forewing and hindwing outlines, and where their eye-spots sit, in a local frame from the wing root.
    private static let w5Forewing = [V2(1.2, 0), V2(2.4, 4), V2(1.6, 9.2), V2(-1.4, 11.2), V2(-5, 9.6), V2(-5.2, 5), V2(-2.5, 1)]
    private static let w5Hindwing = [V2(-1, 0), V2(-2.6, 4.2), V2(-6, 6), V2(-9, 4.4), V2(-8.6, 1.4), V2(-5, -0.6)]

    private static func w5MothWing(_ root: V2, angle: Double, flip: Double = 1, scale: V2 = V2(1, 1), z: Double, group: Int,
                                   bias: Int) -> [Part] {
        var parts: [Part] = []
        for (k, outline) in [w5Hindwing, w5Forewing].enumerated() {
            let zz = z + Double(k) * 0.05, g = group + k * 4
            let centre = outline.reduce(V2.zero, +) / Double(outline.count)
            let inner = outline.map { centre + ($0 - centre) * 0.7 }
            let spot = k == 0 ? V2(-6, 3) : V2(-1.6, 6.6)
            let r = k == 0 ? 1.4 : 1.9
            let at = w5Local(root, angle, [spot], flip: flip, scale: scale)[0]
            parts.append(Part(.polygon(w5Local(root, angle, outline, flip: flip, scale: scale)), .body, z: zz, group: g,
                              toneBias: bias))
            parts.append(Part(.polygon(w5Local(root, angle, inner, flip: flip, scale: scale)), .secondary, z: zz + 0.01, group: g,
                              toneBias: bias, innerOutline: false))
            // Eye-spot: a gold ring, a dark pupil and a glint.
            parts.append(Part(.ellipse(c: at, r: V2(r, r) * min(1, scale.x * 1.2), angle: 0), .gold, z: zz + 0.02, group: g,
                              toneBias: bias, innerOutline: false, fixedTone: .base))
            parts.append(Part(.ellipse(c: at, r: V2(r, r) * 0.55 * min(1, scale.x * 1.2), angle: 0), .dark, z: zz + 0.03,
                              group: g, innerOutline: false, fixedTone: .base))
            parts.append(Part(.ellipse(c: at + V2(-0.3, 0.3), r: V2(0.35, 0.35), angle: 0), .white, z: zz + 0.04, group: g,
                              innerOutline: false, fixedTone: .light))
        }
        return parts
    }

    /// A feathery antenna curling from `root`.
    private static func w5Antenna(_ root: V2, angle: Double, curl: Double, z: Double, group: Int, bias: Int) -> [Part] {
        let spine = w5Curve(from: root, angle: angle, curl: curl, steps: 5, step: 1.35)
        return [Part(w5Ribbon(spine, [0.35, 0.9, 1.3, 1.3, 0.9, 0.4]), .secondary, z: z, group: group, toneBias: bias),
                Part(w5Ribbon(spine, [0.3, 0.3, 0.3, 0.3, 0.3, 0.2]), .dark, z: z + 0.01, group: group, innerOutline: false)]
    }

    static func w5Mothkin(_ pose: Pose) -> Built {
        var spec = QuadSpec()
        spec.bodyR = V2(5.8, 4.8)
        spec.bodyX = 15.5
        spec.legLen = 2.4
        spec.legR = (1.1, 0.9)
        spec.legX = (3, -2.6)
        spec.headR = 4.8
        spec.headOffset = V2(6, 4.4)
        spec.bellyR = V2(3.4, 2)
        let q = quadruped(spec, pose)
        var b = q.built
        // A striped abdomen behind.
        let abdomen = q.bodyC + rotate(V2(-6, -0.4), by: q.angle)
        b.parts.append(Part(.ellipse(c: abdomen, r: V2(4.2, 3.4), angle: q.angle - 0.15), .body, z: -0.05, group: 0, patterned: true,
                            role: .torso))
        for (dx, h) in [(-0.6, 2.6), (-2.7, 2.0)] {
            let c = abdomen + rotate(V2(dx, 0), by: q.angle - 0.15)
            b.parts.append(Part(.capsule(a: c + V2(0, h), b: c - V2(0, h), ra: 0.7, rb: 0.7), .secondary, z: -0.04, group: 0,
                                innerOutline: false))
        }
        // Wings fold up over the back and flutter.
        let flutter = sin(2 * .pi * pose.t) * 0.06
        let wingAngle = q.angle + 0.12 - pose.wing * 0.45 + pose.lying * 0.6 + flutter
        let root = q.bodyC + rotate(V2(-1, q.bodyR.y * 0.75), by: q.angle)
        b.parts += w5MothWing(root + V2(-1.2, 0.4), angle: wingAngle + 0.45, scale: V2(1.1, 1.1), z: -1.6, group: 8, bias: 1)
        b.parts += w5MothWing(root, angle: wingAngle, scale: V2(1.1, 1.1), z: 0.55, group: 7, bias: 0)
        // Fluffy white collar.
        let neck = b.headC + V2(-0.6, -3.6)
        for (k, (o, r)) in [(V2(-3.4, 0.6), 1.8), (V2(-1.8, -0.6), 1.9), (V2(0, -1.2), 1.8), (V2(1.8, -1.2), 1.5)].enumerated() {
            b.parts.append(Part(.ellipse(c: neck + o, r: V2(r, r * 0.9), angle: 0), .white, z: 1.05 + Double(k) * 0.001, group: 10))
        }
        // Feathery antennae.
        let sway = pose.tail * 0.06 + pose.lying * 0.6
        b.parts += w5Antenna(b.onHead(V2(-0.3, 0.9)), angle: 1.75 + sway, curl: 0.22, z: 0.9, group: 41, bias: 1)
        b.parts += w5Antenna(b.onHead(V2(0.15, 0.92)), angle: 1.45 + sway, curl: 0.24, z: 1.2, group: 40, bias: 0)
        b.eyeX = (0.3, 0.75)
        b.eyeY = 0.1
        b.mouth = V2(0.95, -0.45)
        return b
    }

    // MARK: Wyvern

    static func w5Wyvern(_ pose: Pose) -> Built {
        var b = Built()
        let squash = pose.squash
        let legLen = 5.0 * (1 - 0.75 * pose.lying) * (1 + 0.2 * pose.dangle)
        let angle = 0.2 + pose.lean + pose.sway - pose.lying * 0.2
        let bodyR = V2(6 / squash.squareRoot(), 4.4 * squash)
        let bodyC = V2(15.4 + pose.lunge, ground + legLen + bodyR.y * 0.8 + pose.bob + pose.lift * 0.8)
        b.parts.append(Part(.ellipse(c: bodyC, r: bodyR, angle: angle), .body, z: 0, group: 0, patterned: true, role: .torso))
        // Belly plates.
        let belly = bodyC + rotate(V2(1.4, -1.9), by: angle)
        b.parts.append(Part(.ellipse(c: belly, r: V2(4.2, 2.3), angle: angle), .secondary, z: 0.1, group: 0))
        for dx in [-1.6, 0.6, 2.8] {
            let c = belly + rotate(V2(dx, 0), by: angle)
            b.parts.append(Part(.capsule(a: c + rotate(V2(0.4, 1.6), by: angle), b: c + rotate(V2(-0.4, -1.6), by: angle), ra: 0.3,
                                         rb: 0.3), .secondary, z: 0.11, group: 0, innerOutline: false, fixedTone: .shade))
        }
        // Long neck and the head.
        let headAngle = angle * 0.4 + pose.headTilt - pose.lying * 0.1
        let headC = bodyC + rotate(V2(6.2, 7.2), by: angle * 0.6) + V2(pose.headDip * 0.5 + pose.lying * 1.5,
                                                                         -pose.headDip - pose.lying * 3)
        b.headC = headC
        b.headR = 4
        b.headAngle = headAngle
        b.parts.append(Part(.capsule(a: bodyC + rotate(V2(3.6, 1.6), by: angle), b: headC + V2(-1.2, -1.6), ra: 2.8, rb: 2),
                            .body, z: 0.5, group: 1, patterned: true))
        b.parts.append(Part(.ellipse(c: headC, r: V2(4.1, 3.8), angle: headAngle), .body, z: 1, group: 1, patterned: true, role: .head))
        b.parts.append(Part(.ellipse(c: b.onHead(V2(1.0, -0.3)), r: V2(3, 2), angle: headAngle), .body, z: 1.1, group: 1,
                            patterned: true))
        b.parts.append(Part(.ellipse(c: b.onHead(V2(1.6, -0.15)), r: V2(0.5, 0.45), angle: 0), .dark, z: 1.2, group: 1))
        // Horns swept back, and a cheek frill.
        for (x, z, bias, g) in [(-0.6, 0.9, 1, 41), (-0.2, 1.2, 0, 40)] {
            let r0 = b.onHead(V2(x, 0.7))
            let r1 = r0 + rotate(V2(-2.2, 2.2), by: headAngle)
            let r2 = r1 + rotate(V2(-2.6, 0.5), by: headAngle)
            b.parts.append(Part(.capsule(a: r0, b: r1, ra: 1.1, rb: 0.75), .white, z: z, group: g, toneBias: bias))
            b.parts.append(Part(.capsule(a: r1, b: r2, ra: 0.75, rb: 0.45), .white, z: z, group: g, toneBias: bias))
        }
        b.parts.append(Part(headPolygon(b, [V2(-0.6, 0.2), V2(-1.6, 0.6), V2(-1.2, -0.1), V2(-1.7, -0.5), V2(-0.5, -0.5)]),
                            .secondary, z: 0.95, group: 42))
        // Back spikes along the spine.
        for i in 0..<4 {
            let base = bodyC + rotate(V2(-4 + Double(i) * 2.4, bodyR.y * 0.92 - abs(Double(i) - 1.5) * 0.3), by: angle)
            b.parts.append(Part(.polygon([base + V2(-1, -0.4), base + V2(1, -0.4), base + V2(-0.6, 1.8)]), .secondary, z: -0.2,
                                group: 9))
        }
        // Legs: thick thighs, shins and clawed feet.
        for near in [true, false] {
            let hip = bodyC + rotate(V2(-1.6 - (near ? 0 : 1.2), -1.4), by: angle)
            let swing = pose.stride * (near ? 1 : -1)
            var foot = V2(hip.x + 0.6 + swing * 2.6, ground + 0.9 + pose.lift)
            if pose.dangle > 0 { foot = hip + V2(1 + sin(pose.sway * 3 + (near ? 0 : 1)) * 0.6, -legLen * 1.1) }
            if pose.lying > 0 { foot = V2(hip.x + 2.6, ground + 0.9) }
            let knee = hip + V2(2.2, -legLen * 0.35)
            let z = near ? 2.0 : -2.0
            let g = near ? 3 : 4, bias = near ? 0 : 1
            b.parts.append(Part(.ellipse(c: hip + V2(0.4, -0.2), r: V2(2.6, 3.1), angle: 0.4), .body, z: z, group: g, patterned: true,
                                toneBias: bias, role: .limb))
            b.parts.append(Part(.capsule(a: knee, b: foot, ra: 1.4, rb: 1.0), .body, z: z, group: g, patterned: true, toneBias: bias,
                                role: .limb))
            b.parts.append(Part(.ellipse(c: foot + V2(0.9, -0.1), r: V2(2, 0.9), angle: 0), .body, z: z + 0.01, group: g,
                                patterned: true, toneBias: bias))
            for dx in [2.6, 1.4] {
                let t = foot + V2(dx, -0.1)
                b.parts.append(Part(.polygon([t + V2(-0.5, 0.6), t + V2(0.9, -0.3), t + V2(-0.4, -0.5)]), .white, z: z + 0.02,
                                    group: g, toneBias: bias, innerOutline: false))
            }
        }
        // Wings are its forelimbs: an arm with a clawed wrist, and fingers holding the membrane.
        let flap = pose.wing
        for near in [false, true] {
            let shoulder = bodyC + rotate(V2(2 - (near ? 0 : 1.4), 3.2 + (near ? 0 : 1)), by: angle)
            let wa = angle * 0.5 - (near ? 0 : 0.22) - flap * 0.15
            let fy = 1 + flap * 0.08 - pose.lying * 0.2
            let elbow = V2(-2.2, 3.4), wrist = V2(0.2, 7.6)
            let f1 = V2(-3.2, 11), f2 = V2(-7.6, 9.6), f3 = V2(-9.8, 5.2)
            let membrane = w5Local(shoulder, wa, [V2(0.6, 0), wrist, f1, V2(-4.6, 8.4), f2, V2(-7.6, 6.4), f3, V2(-6.6, 3.4),
                                                  V2(-3.2, 1.8)], scale: V2(1, fy))
            let z = near ? 0.6 : -1.5
            let g = near ? 7 : 8, bias = near ? 0 : 1
            b.parts.append(Part(.polygon(membrane), .secondary, z: z, group: g, toneBias: bias))
            let bones = w5Local(shoulder, wa, [V2(0, 0), elbow, wrist, f1, f2, f3], scale: V2(1, fy))
            for (i, j, ra) in [(0, 1, 1.1), (1, 2, 0.9), (2, 3, 0.6), (2, 4, 0.55), (2, 5, 0.55)] {
                b.parts.append(Part(.capsule(a: bones[i], b: bones[j], ra: ra, rb: 0.45), .body, z: z + 0.01, group: g,
                                    patterned: true, toneBias: bias))
            }
            b.parts.append(Part(.polygon([bones[2] + V2(-0.4, 0), bones[2] + V2(1.6, 0.9), bones[2] + V2(0.3, 0.8)]), .white,
                                z: z + 0.02, group: g, toneBias: bias))
        }
        // Long tail ending in a spade.
        let base = bodyC + rotate(V2(-bodyR.x * 0.85, -0.4), by: angle)
        let tailParts = tail(from: base, angle: 3.45 + pose.tail * 0.2 - pose.lying * 0.3 - pose.dangle * 0.6, curl: -0.4,
                             segments: 4, length: 1.9, radius: (2, 0.7), ramp: .body, z: -1)
        b.parts += tailParts
        if case let .capsule(a, tip, _, _) = tailParts.last!.shape {
            let d = (tip - a) / max(0.001, ((tip - a).x * (tip - a).x + (tip - a).y * (tip - a).y).squareRoot())
            let n = V2(-d.y, d.x)
            b.parts.append(Part(.polygon([tip - d * 0.4, tip + n * 1.8 + d * 0.4, tip + d * 3, tip - n * 1.8 + d * 0.4]), .secondary,
                                z: -0.9, group: 5))
        }
        b.eyeX = (0.12, 0.6)
        b.eyeY = 0.25
        b.mouth = V2(1.45, -0.55)
        b.topOverride = b.onHead(V2(-0.2, 1.0))
        return b
    }

    // MARK: Phoenix

    static func w5Phoenix(_ pose: Pose) -> Built {
        var b = Built()
        let squash = pose.squash
        let legLen = 3.4 * (1 - pose.lying) * (1 + 0.3 * pose.dangle)
        let angle = pose.lean + pose.sway
        let bodyR = V2(4.8 / squash.squareRoot(), 5.4 * squash)
        let bodyC = V2(18 + pose.lunge, ground + legLen + bodyR.y * 0.8 + pose.bob + pose.lift * 0.75)
        b.parts.append(Part(.ellipse(c: bodyC, r: bodyR, angle: angle - 0.45), .body, z: 0, group: 0, patterned: true, role: .torso))
        b.parts.append(Part(.ellipse(c: bodyC + rotate(V2(2, 0), by: angle), r: V2(2.6, 4.4), angle: angle - 0.45), .gold, z: 0.1,
                            group: 0))
        // A long, proud neck.
        let headC = bodyC + rotate(V2(3.8, 8.6), by: angle) + V2(pose.headDip * 0.8, -pose.headDip * 1.4 - pose.lying * 3.5)
        b.headC = headC
        b.headR = 3.6
        b.headAngle = angle * 0.5 + pose.headTilt
        b.parts.append(Part(.capsule(a: bodyC + rotate(V2(1.6, 2.6), by: angle), b: headC + V2(-0.4, -1.4), ra: 2.5, rb: 1.8), .body,
                            z: 0.5, group: 1, patterned: true))
        b.parts.append(Part(.capsule(a: bodyC + rotate(V2(2.6, 2.4), by: angle), b: headC + V2(0.6, -2), ra: 1.4, rb: 1), .gold,
                            z: 0.51, group: 1, innerOutline: false))
        b.parts.append(Part(.ellipse(c: headC, r: V2(3.75, 3.6), angle: b.headAngle), .body, z: 1, group: 1, patterned: true,
                            role: .head))
        // Red mark sweeping back from the eye.
        b.parts.append(Part(.capsule(a: b.onHead(V2(0.2, -0.05)), b: b.onHead(V2(-0.75, 0.25)), ra: 0.55, rb: 0.3), .red, z: 1.05,
                            group: 1, innerOutline: false))
        // Hooked golden beak.
        let open = pose.mouth == .open ? 0.4 : 0
        b.parts.append(Part(headPolygon(b, [V2(0.7, 0.3), V2(1.55, 0.1), V2(1.9, -0.5), V2(1.5, -0.32), V2(0.75, -0.3)]), .gold,
                            z: 1.3, group: 42))
        b.parts.append(Part(headPolygon(b, [V2(0.75, -0.3), V2(1.35, -0.42 - open), V2(0.8, -0.6)]), .gold, z: 1.29, group: 42,
                            toneBias: 1))
        // Flame crest streaming back.
        let flick = 2 * .pi * pose.t * 2
        for (k, (dir, len)) in [(1.9, 4.6), (2.35, 6.0), (2.8, 5.0)].enumerated() {
            b.parts += w5Flame(b.onHead(V2(-0.2 - Double(k) * 0.3, 0.75 - Double(k) * 0.2)), dir: dir + b.headAngle - pose.lying * 0.3,
                               length: len, width: 1.05, flicker: sin(flick + Double(k) * 2) * 0.7, z: 0.9 - Double(k) * 0.01,
                               group: 44 + k)
        }
        // Long trailing tail plumes of red and gold, each ending in a golden eye.
        let rump = bodyC + rotate(V2(-2.6, -3), by: angle)
        for (k, (start, curl, steps)) in [(2.6, 0.1, 6), (3.05, 0.02, 7), (3.45, -0.12, 6)].enumerated() {
            let a = start + pose.tail * 0.1 + pose.dangle * 0.8 - pose.lying * 0.3 + angle
            let wave = sin(2 * .pi * pose.t + Double(k)) * 0.03
            let spine = w5Curve(from: rump, angle: a, curl: curl + wave, steps: steps, step: 1.9)
            let z = -1 - Double(k) * 0.02
            b.parts.append(Part(w5Ribbon(spine, [0.8, 1.0, 1.1, 1.1, 1.0, 0.8, 0.4]), .red, z: z, group: 10 + k))
            b.parts.append(Part(w5Ribbon(spine, [0.2, 0.4, 0.45, 0.45, 0.4, 0.3, 0.1]), .gold, z: z + 0.01, group: 10 + k,
                                innerOutline: false, fixedTone: .light))
            let eye = spine[steps - 1]
            b.parts.append(Part(.ellipse(c: eye, r: V2(1.25, 1.25), angle: 0), .gold, z: z + 0.02, group: 10 + k, fixedTone: .light))
            b.parts.append(Part(.ellipse(c: eye, r: V2(0.6, 0.6), angle: 0), .red, z: z + 0.03, group: 10 + k, innerOutline: false,
                                fixedTone: .base))
        }
        // Wing folded along the side, flight feathers turning to flame.
        let shoulder = bodyC + rotate(V2(0.6, 2.4), by: angle)
        let wa = angle + 0.15 - pose.wing * 0.6 + pose.lying * 0.1
        let wing = [V2(1.4, 0.4), V2(0, 2.2), V2(-3.6, 2.2), V2(-7.4, 0.2), V2(-6, -1.6), V2(-2.6, -2.4), V2(0, -1.4)]
        let coverts = [V2(1.4, 0.4), V2(0, 2.2), V2(-3.6, 2.2), V2(-4.4, 0.6), V2(-1.4, -0.6)]
        for (k, (x, y, len)) in [(-7.0, 0.0, 4.6), (-5.6, -1.4, 3.8), (-3.6, -2.1, 3.0)].enumerated() {
            let at = w5Local(shoulder, wa, [V2(x, y)])[0]
            b.parts += w5Flame(at, dir: wa + 3.5 - Double(k) * 0.25, length: len, width: 1,
                               flicker: sin(flick + Double(k) * 1.3) * 0.6, z: 0.55 - Double(k) * 0.001, group: 13 + k)
        }
        b.parts.append(Part(.polygon(w5Local(shoulder, wa, wing)), .body, z: 0.6, group: 6, patterned: true, role: .extremity))
        b.parts.append(Part(.polygon(w5Local(shoulder, wa, coverts)), .gold, z: 0.61, group: 6))
        // Legs with golden talons and feathered thighs.
        for near in [true, false] {
            let hip = bodyC + rotate(V2(near ? 0.6 : -0.8, -bodyR.y * 0.7), by: angle)
            let swing = pose.stride * (near ? 1 : -1)
            var foot = V2(hip.x + swing * 1.8, ground + 0.6 + pose.lift * 0.75)
            if pose.dangle > 0 { foot = hip + V2(0.3, -legLen * 1.2 - 1) }
            if pose.lying > 0 { foot = hip + V2(1, -0.6) }
            let z = near ? 2.0 : -2.0
            let g = near ? 3 : 4, bias = near ? 0 : 1
            b.parts.append(Part(.ellipse(c: hip + V2(0, 0.6), r: V2(1.9, 2.1), angle: 0.3), .body, z: z, group: g, patterned: true,
                                toneBias: bias, role: .limb))
            if legLen > 0.5 {
                b.parts.append(Part(.capsule(a: hip, b: foot, ra: 0.75, rb: 0.6), .gold, z: z - 0.01, group: g, toneBias: bias,
                                    innerOutline: false))
            }
            b.parts.append(Part(.capsule(a: foot + V2(-0.6, 0), b: foot + V2(1.8, 0), ra: 0.65, rb: 0.5), .gold, z: z, group: g,
                                toneBias: bias, innerOutline: false))
        }
        b.parts += w5Motes(pose, around: bodyC + V2(-2, 8), spread: V2(8, 5), ramp: .red, core: .gold, count: 2, rise: true)
        b.eyeX = (0.3, 0.75)
        b.eyeY = 0.18
        b.mouth = V2(2, 2)
        b.topOverride = b.onHead(V2(-0.1, 1.0))
        return b
    }

    // MARK: Spirit stag

    static func w5Stag(_ pose: Pose) -> Built {
        var spec = QuadSpec()
        spec.bodyR = V2(8, 4.9)
        spec.bodyX = 13.5
        spec.legLen = 6
        spec.legR = (1.3, 0.95)
        spec.legX = (5.5, -5.5)
        spec.headR = 4.0
        spec.headOffset = V2(8.4, 7.2)
        spec.bellyR = V2(4.5, 2)
        var p = pose
        p.lift *= 0.6
        let q = quadruped(spec, p)
        var b = q.built
        // Neck with a white chest ruff.
        let neckBase = q.bodyC + rotate(V2(q.bodyR.x * 0.6, q.bodyR.y * 0.3), by: q.angle)
        b.parts.append(Part(.capsule(a: neckBase, b: b.headC + V2(-1.5, -1.5), ra: 2.6, rb: 2), .body, z: 0.5, group: 1,
                            patterned: true))
        b.parts.append(Part(.polygon([neckBase + V2(-0.5, 2.5), neckBase + V2(3, 1.6), neckBase + V2(2.4, -1.2),
                                      neckBase + V2(3.2, -2.4), neckBase + V2(0.6, -3.2)]), .white, z: 0.55, group: 1))
        // Muzzle and ears.
        b.parts.append(Part(.ellipse(c: b.onHead(V2(1.0, -0.45)), r: V2(2.6, 1.8), angle: b.headAngle - 0.3), .body, z: 1.1,
                            group: 1, patterned: true))
        b.parts.append(Part(.ellipse(c: b.onHead(V2(1.55, -0.55)), r: V2(0.8, 0.7), angle: 0), .dark, z: 1.2, group: 1))
        for (base, z, bias) in [(V2(-0.7, 0.6), 0.9, 1), (V2(-0.3, 0.75), 1.2, 0)] {
            b.parts.append(Part(.ellipse(c: b.onHead(base) + V2(-1.8, 0.4), r: V2(2.5, 1.1), angle: 0.4), .body, z: z, group: 6,
                                patterned: true, toneBias: bias, role: .extremity))
        }
        // Glowing markings: a mark on the brow, and swirls on the flank and haunch.
        b.parts.append(Part(headPolygon(b, [V2(0.0, 0.85), V2(0.3, 0.55), V2(0.05, 0.35), V2(-0.25, 0.55)]), .blue, z: 1.05,
                            group: 1, innerOutline: false, fixedTone: .light))
        for swirl in [[V2(4.6, 0.6), V2(2.2, 1.9), V2(-0.4, 1.4)], [V2(-2.2, 2.6), V2(-4.6, 1.2), V2(-6.0, -1.0)]] {
            let pts = swirl.map { q.bodyC + rotate($0, by: q.angle) }
            b.parts.append(Part(w5Ribbon(pts, [0.35, 0.55, 0.3]), .blue, z: 0.15, group: 0, innerOutline: false, fixedTone: .light))
        }
        // Silver hooves and a white flag of a tail.
        w5Hooves(&b, ramp: .stone)
        let tailBase = q.bodyC + rotate(V2(-q.bodyR.x * 0.95, q.bodyR.y * 0.5), by: q.angle)
        b.parts.append(Part(.ellipse(c: tailBase + V2(-0.5, 0.5 + pose.tail * 0.5), r: V2(1.4, 2), angle: 0.4), .white, z: -0.5,
                            group: 5))
        // Huge glowing antlers.
        let lean = b.headAngle + 0.15 + pose.lying * 0.25
        b.parts += w5Antler(w5StagAntler, root: b.onHead(V2(-0.45, 0.8)), scale: 0.88, lean: lean + 0.12, ramp: .blue, z: 0.85,
                            group: 41, glow: .base)
        b.parts += w5Antler(w5StagAntler, root: b.onHead(V2(-0.1, 0.85)), scale: 0.88, lean: lean, ramp: .blue, z: 1.3, group: 40,
                            glow: .light)
        b.parts += w5Motes(pose, around: q.bodyC + V2(1, 4), spread: V2(10, 3), ramp: .blue, core: .white, rise: false)
        b.eyeX = (0.2, 0.6)
        b.eyeY = 0.2
        b.mouth = V2(1.4, -0.8)
        b.topOverride = b.onHead(V2(-0.3, 1.0))
        return b
    }

    // MARK: Sky whale

    static func w5Whale(_ pose: Pose) -> Built {
        var b = Built()
        let squash = pose.squash
        let float = 4 + sin(pose.t * 2 * .pi) * 0.7 + pose.lift + pose.bob * 0.6 - pose.lying * 2.4 + pose.dangle
        let angle = pose.lean * 0.6 + pose.sway + pose.stride * 0.05 - pose.dangle * 0.12
        let r = V2(9 / squash.squareRoot(), 5.8 * squash)
        let c = V2(18.5 + pose.lunge, ground + r.y + float)
        // Puffy clouds it drifts on.
        b.parts += w5Clouds(pose, centre: c.x - 1, spread: 1)
        // Body tapering into the tail stock, and a fluke that sweeps as it swims.
        b.parts.append(Part(.ellipse(c: c, r: r, angle: angle), .body, z: 0, group: 0, patterned: true, role: .torso))
        let sweep = pose.stride * 1.4 + pose.tail * 0.6 - pose.dangle * 1.5
        let stock = c + rotate(V2(-r.x * 0.6, 0.6), by: angle)
        let tailEnd = c + rotate(V2(-r.x - 4.2, 1.8 + sweep * 0.5), by: angle)
        b.parts.append(Part(.capsule(a: stock, b: tailEnd, ra: 3.8, rb: 1.2), .body, z: -0.1, group: 0, patterned: true, role: .torso))
        let up = rotate(V2(0, 1), by: angle + sweep * 0.08), back = rotate(V2(-1, 0), by: angle + sweep * 0.08)
        b.parts.append(Part(.polygon([tailEnd + up * 0.6, tailEnd + back * 2 + up * 4.4, tailEnd + back * 3.8 + up * 3.2,
                                      tailEnd + back * 1.8 + up * 0.6, tailEnd + back * 3.4 - up * 2.4, tailEnd + back * 1.6 - up * 3,
                                      tailEnd - up * 0.6]), .body, z: -0.2, group: 5, patterned: true, role: .extremity))
        // Pale belly with grooves.
        let belly = c + rotate(V2(1.5, -r.y * 0.5), by: angle)
        b.parts.append(Part(.ellipse(c: belly, r: V2(7, 3), angle: angle), .secondary, z: 0.1, group: 0))
        for dy in [-0.2, -1.2, -2.1] {
            b.parts.append(Part(.capsule(a: belly + rotate(V2(-4.6 + abs(dy), dy), by: angle),
                                         b: belly + rotate(V2(5.4 - abs(dy) * 1.2, dy + 0.3), by: angle), ra: 0.3, rb: 0.3),
                                .secondary, z: 0.11, group: 0, innerOutline: false, fixedTone: .shade))
        }
        // Little dorsal fin and flippers.
        let fin = c + rotate(V2(-5.5, r.y * 0.85), by: angle)
        b.parts.append(Part(.polygon([fin + V2(-1.6, -0.6), fin + V2(-1.4, 1.6), fin + V2(1.8, -0.6)]), .body, z: -0.3, group: 9,
                            patterned: true))
        let flap = pose.wing * 0.5 + sin(2 * .pi * pose.t) * 0.15
        for near in [false, true] {
            let at = c + rotate(V2(near ? 2.6 : 3.8, -r.y * 0.45), by: angle)
            b.parts.append(Part(.ellipse(c: at + V2(-1.2, -1.2), r: V2(3.4, 1.4), angle: angle - 0.7 + flap), .body,
                                z: near ? 0.5 : -1, group: near ? 11 : 12, patterned: true, toneBias: near ? 0 : 1, role: .limb))
        }
        // A trail of glowing star-spots along its back.
        for (k, v) in [V2(-3.4, 0.82), V2(-0.8, 0.92), V2(1.8, 0.9), V2(4.2, 0.78)].enumerated() {
            let at = c + rotate(V2(v.x, r.y * v.y - 0.6), by: angle)
            b.parts.append(Part(.ellipse(c: at, r: V2(0.75, 0.75) * (k % 2 == 0 ? 1 : 0.8), angle: 0), .gold, z: 0.2, group: 0,
                                innerOutline: false, fixedTone: .light))
        }
        // A sparkling spout from the blowhole now and then.
        if pose.wing > 0.5 || (pose.t > 0.2 && pose.t < 0.3) {
            let hole = c + rotate(V2(3.5, r.y), by: angle)
            for (k, v) in [V2(0, 1.6), V2(-1.6, 3), V2(1.4, 3.2), V2(-0.2, 4.4)].enumerated() {
                b.parts.append(Part(.ellipse(c: hole + v, r: V2(0.8, 0.8), angle: 0), k == 3 ? .white : .blue, z: -0.4,
                                    group: 17, fixedTone: .light))
            }
        }
        b.headC = c + rotate(V2(5.4, -0.4), by: angle)
        b.headR = 4
        b.headAngle = angle
        b.eyeX = (0.25, 0.55)
        b.eyeY = 0.0
        b.mouth = V2(0.9, -0.75)
        b.cheek = V2(0.35, -0.55)
        b.topOverride = c + rotate(V2(3, r.y), by: angle)
        return b
    }

    /// A little bank of puffy clouds on the ground.
    private static func w5Clouds(_ pose: Pose, centre x: Double, spread: Double) -> [Part] {
        let puffs: [(Double, Double, Double)] = [(-7.5, 1.6, 1.6), (-4.6, 2.4, 2.3), (-1.4, 2.9, 2.6), (2, 2.5, 2.3), (5, 1.9, 1.9),
                                                 (7.4, 1.5, 1.4)]
        return puffs.enumerated().map { k, puff in
            let drift = sin(2 * .pi * pose.t + Double(k)) * 0.3
            return Part(.ellipse(c: V2(x + puff.0 * spread + drift, ground + puff.1 - 0.4), r: V2(puff.2 * 1.15, puff.2 * 0.85), angle: 0),
                        .white, z: 3 + Double(k % 2) * 0.01 - abs(puff.0) * 0.001, group: 16 + k % 2)
        }
    }

    static func w5WhaleFront(_ pose: Pose, back: Bool) -> Built {
        var b = Built()
        let squash = pose.squash
        let float = 4 + sin(pose.t * 2 * .pi) * 0.7 + pose.lift + pose.bob * 0.6 - pose.lying * 2.4 + pose.dangle
        let r = V2(8.2 / squash.squareRoot(), 6.6 * squash)
        let c = V2(16, ground + r.y + float)
        let angle = pose.sway
        b.parts += w5Clouds(pose, centre: c.x, spread: 0.85)
        b.parts.append(Part(.ellipse(c: c, r: r, angle: angle), .body, z: 0, group: 0, patterned: true, role: .torso))
        let sweep = pose.tail * 0.8 - pose.dangle
        if back {
            // The tail stock and fluke, in full view from behind.
            let flukeC = c + V2(0, r.y * 0.35 + sweep)
            let fluke = [V2(-0.6, -1.4), V2(-4, 0.4), V2(-7.6, 3.2), V2(-6.6, 4.6), V2(-3, 3), V2(0, 1.8), V2(3, 3), V2(6.6, 4.6),
                         V2(7.6, 3.2), V2(4, 0.4), V2(0.6, -1.4)]
            b.parts.append(Part(.polygon(fluke.map { flukeC + $0 * 1.15 }), .body, z: 1.6, group: 5, patterned: true, role: .extremity))
            b.parts.append(Part(.capsule(a: c, b: flukeC, ra: 3.6, rb: 1.6), .body, z: 1.5, group: 5, patterned: true))
        } else {
            let belly = c + V2(0, -r.y * 0.42)
            b.parts.append(Part(.ellipse(c: belly, r: V2(5.2, 3.4), angle: angle), .secondary, z: 0.1, group: 0))
            for dx in [-2.2, 0, 2.2] {
                b.parts.append(Part(.capsule(a: belly + V2(dx * 1.1, -2.4 + abs(dx) * 0.3), b: belly + V2(dx * 0.9, 1.2), ra: 0.3,
                                             rb: 0.3), .secondary, z: 0.11, group: 0, innerOutline: false, fixedTone: .shade))
            }
        }
        // Flippers out to the sides.
        let flap = pose.wing * 0.5 + sin(2 * .pi * pose.t) * 0.15 + pose.dangle * 0.4
        for s in [-1.0, 1.0] {
            b.parts.append(Part(.ellipse(c: c + V2(s * (r.x - 0.2), -2 + flap * 1.2), r: V2(1.6, 3.8), angle: s * (1.0 + flap)),
                                .body, z: 0.4, group: s < 0 ? 11 : 12, patterned: true, role: .limb))
        }
        // Glowing star-spots: a crown on its brow, a trail down its back.
        let spots: [V2] = back ? [V2(0, 0.85), V2(-2.2, 0.55), V2(2.2, 0.55), V2(0, 0.25)] : [V2(-2.6, 0.78), V2(0, 0.88), V2(2.6, 0.78)]
        for v in spots {
            b.parts.append(Part(.ellipse(c: c + V2(v.x, r.y * v.y), r: V2(0.75, 0.75), angle: 0), .gold, z: back ? 1.7 : 0.2,
                                group: back ? 18 : 0, innerOutline: false, fixedTone: .light))
        }
        b.headC = c + V2(0, 0.6)
        b.headR = 5.6
        b.headAngle = angle
        b.headZ = back ? -0.5 : 1
        b.eyeX = (0.62, 0)
        b.eyeY = -0.05
        b.topOverride = c + V2(0, r.y)
        return b
    }

    // MARK: Thunderbird

    /// A jagged lightning bolt through `pts`.
    private static func w5Bolt(_ pts: [V2], width: Double, ramp: Ramp, z: Double, group: Int) -> Part {
        Part(w5Ribbon(pts, pts.indices.map { i in i == pts.count - 1 ? 0.15 : width }), ramp, z: z, group: group, fixedTone: .light)
    }

    private static let w5StormWing = [V2(1.2, 0), V2(1.5, 4), V2(-0.5, 8.5), V2(-3.5, 11.5), V2(-4.4, 9.8), V2(-6.8, 11.2),
                                      V2(-7.4, 9), V2(-10, 9.6), V2(-9.8, 7.4), V2(-12, 6.8), V2(-10.4, 5), V2(-8, 2.8),
                                      V2(-4.6, 0.4), V2(-2, -1.6)]
    private static let w5StormCoverts = [V2(1.2, 0), V2(1.5, 4), V2(-0.5, 8.5), V2(-3.2, 7.8), V2(-3.8, 3.4), V2(-2, -1.6)]
    private static let w5StormBolt = [V2(-1.0, 8.2), V2(-4.4, 6.2), V2(-3.6, 5.4), V2(-7.4, 4.0), V2(-6.6, 3.2), V2(-9.2, 2.4)]

    static func w5Thunderbird(_ pose: Pose) -> Built {
        var b = Built()
        let squash = pose.squash
        let legLen = 3.2 * (1 - pose.lying) * (1 + 0.3 * pose.dangle)
        let angle = pose.lean + pose.sway
        let bodyR = V2(5.2 / squash.squareRoot(), 6.2 * squash)
        let bodyC = V2(15.8 + pose.lunge, ground + legLen + bodyR.y * 0.78 + pose.bob + pose.lift * 0.8)
        b.parts.append(Part(.ellipse(c: bodyC, r: bodyR, angle: angle - 0.3), .body, z: 0, group: 0, patterned: true, role: .torso))
        b.parts.append(Part(.ellipse(c: bodyC + rotate(V2(2, -0.6), by: angle), r: V2(2.8, 4.6), angle: angle - 0.3), .secondary,
                            z: 0.1, group: 0))
        // Head with a heavy hooked beak.
        let headC = bodyC + rotate(V2(3.4, 6.6), by: angle) + V2(pose.headDip * 0.6, -pose.headDip - pose.lying * 2.5)
        b.headC = headC
        b.headR = 4.2
        b.headAngle = angle * 0.5 + pose.headTilt
        b.parts.append(Part(.ellipse(c: headC, r: V2(4.3, 4.1), angle: b.headAngle), .body, z: 1, group: 1, patterned: true, role: .head))
        let open = pose.mouth == .open ? 0.35 : 0
        b.parts.append(Part(headPolygon(b, [V2(0.55, 0.4), V2(1.45, 0.3), V2(2.0, -0.1), V2(1.95, -0.8), V2(1.6, -0.45),
                                            V2(0.6, -0.35)]), .gold, z: 1.3, group: 42))
        b.parts.append(Part(headPolygon(b, [V2(0.65, -0.35), V2(1.45, -0.5 - open), V2(0.7, -0.7)]), .gold, z: 1.29, group: 42,
                            toneBias: 1))
        // Storm crest: jagged blue feathers with gold tips.
        for (k, (o, tip)) in [(V2(-0.2, 0.85), V2(-5.0, 3.4)), (V2(-0.6, 0.6), V2(-5.6, 1.4)), (V2(-0.85, 0.25), V2(-4.8, -0.6))]
            .enumerated() {
            let root = b.onHead(o)
            let t = root + rotate(tip + V2(0, pose.tail * 0.3), by: b.headAngle)
            let d = t - root
            let n = V2(-d.y, d.x) / max(0.001, (d.x * d.x + d.y * d.y).squareRoot())
            b.parts.append(Part(.polygon([root + n * 1.3, t, root - n * 1.3]), .blue, z: 0.9 - Double(k) * 0.01, group: 44 + k))
            b.parts.append(Part(.polygon([root + d * 0.62 + n * 0.5, t, root + d * 0.62 - n * 0.5]), .gold, z: 0.905 - Double(k) * 0.01,
                                group: 44 + k, innerOutline: false, fixedTone: .light))
        }
        // Great wings, half raised, each struck through with lightning.
        let flap = pose.wing
        for near in [false, true] {
            let shoulder = bodyC + rotate(V2(-1.2 - (near ? 0 : 1.4), 2.4 + (near ? 0 : 0.8)), by: angle)
            let wa = angle + 0.25 - flap * 0.3 - (near ? 0 : 0.28) + pose.lying * 0.5
            let sc = V2(1, 1 + flap * 0.12 - pose.lying * 0.3)
            let z = near ? 0.6 : -1.5
            let g = near ? 7 : 8, bias = near ? 0 : 1
            b.parts.append(Part(.polygon(w5Local(shoulder, wa, w5StormWing, scale: sc)), .secondary, z: z, group: g,
                                toneBias: bias, role: .extremity))
            b.parts.append(Part(.polygon(w5Local(shoulder, wa, w5StormCoverts, scale: sc)), .body, z: z + 0.01, group: g,
                                patterned: true, toneBias: bias))
            b.parts.append(w5Bolt(w5Local(shoulder, wa, w5StormBolt, scale: sc), width: 0.75, ramp: near ? .gold : .blue,
                                  z: z + 0.02, group: g + 30))
        }
        // Fanned tail.
        let rump = bodyC + rotate(V2(-3.2, -3), by: angle)
        b.parts.append(Part(.polygon([rump + V2(0, 1.6), rump + V2(-5.6, -0.6 + pose.tail), rump + V2(-6.4, -2.4 + pose.tail),
                                      rump + V2(-5, -3.8 + pose.tail), rump + V2(0, -1.4)]), .body, z: -1, group: 5, patterned: true,
                            role: .extremity))
        b.parts.append(Part(.polygon([rump + V2(-4.2, -0.2 + pose.tail), rump + V2(-5.6, -0.6 + pose.tail),
                                      rump + V2(-6.4, -2.4 + pose.tail), rump + V2(-5, -3.8 + pose.tail), rump + V2(-4, -2.6 + pose.tail)]),
                            .blue, z: -0.99, group: 5, innerOutline: false))
        // Feathered thighs and powerful taloned feet.
        for near in [true, false] {
            let hip = bodyC + rotate(V2(near ? 1 : -0.6, -bodyR.y * 0.62), by: angle)
            let swing = pose.stride * (near ? 1 : -1)
            var foot = V2(hip.x + swing * 1.8, ground + 0.8 + pose.lift * 0.8)
            if pose.dangle > 0 { foot = hip + V2(0.3, -legLen * 1.2 - 1.5) }
            if pose.lying > 0 { foot = hip + V2(1.2, -0.8) }
            if pose.paw > 0 && near { foot = hip + rotate(V2(4.5, 0), by: -1.3 + pose.paw * 1.5) }
            let z = near ? 2.0 : -2.0
            let g = near ? 3 : 4, bias = near ? 0 : 1
            b.parts.append(Part(.ellipse(c: hip + V2(0, 0.4), r: V2(2.2, 2.6), angle: 0.3), .body, z: z, group: g, patterned: true,
                                toneBias: bias, role: .limb))
            if legLen > 0.5 || pose.paw > 0 {
                b.parts.append(Part(.capsule(a: hip, b: foot, ra: 1, rb: 0.8), .gold, z: z - 0.01, group: g, toneBias: bias))
            }
            for (k, dx) in [2.0, 0.6, -1.0].enumerated() {
                let toe = foot + V2(dx * 0.9, 0)
                b.parts.append(Part(.capsule(a: foot, b: toe, ra: 0.75, rb: 0.6), .gold, z: z, group: g, toneBias: bias))
                let s: Double = k == 2 ? -1 : 1
                b.parts.append(Part(.polygon([toe + V2(0, 0.5), toe + V2(s * 1.1, -0.2), toe + V2(s * 0.2, -0.8)]), .dark, z: z + 0.01,
                                    group: g, toneBias: bias))
            }
        }
        // Sparks crackle off the wingtips when it beats them.
        if flap > 0.5 {
            b.parts.append(w5Bolt([V2(5.5, 26), V2(3.8, 23.6), V2(4.8, 23.4), V2(2.8, 20.4)], width: 0.5, ramp: .gold, z: 3,
                                  group: 15))
            b.parts.append(w5Bolt([V2(9.5, 28.4), V2(8.6, 26.6), V2(9.5, 26.4), V2(8.4, 24.4)], width: 0.45, ramp: .blue, z: 3,
                                  group: 16))
        }
        b.eyeX = (0.3, 0.7)
        b.eyeY = 0.2
        b.mouth = V2(2, 2)
        b.topOverride = b.onHead(V2(-0.1, 1.0))
        return b
    }

    // MARK: Sphinx

    /// A wedge of a ring around `c`, from `a0` to `a1`.
    private static func w5Wedge(_ c: V2, r0: Double, r1: Double, a0: Double, a1: Double, angle: Double = 0, squash: Double = 1)
        -> Shape {
        let n = 4
        let outer = (0...n).map { i -> V2 in
            let a = a0 + (a1 - a0) * Double(i) / Double(n)
            return c + rotate(V2(cos(a) * r1, sin(a) * r1 * squash), by: angle)
        }
        let inner = (0...n).reversed().map { i -> V2 in
            let a = a0 + (a1 - a0) * Double(i) / Double(n)
            return c + rotate(V2(cos(a) * r0, sin(a) * r0 * squash), by: angle)
        }
        return .polygon(outer + inner)
    }

    static func w5Sphinx(_ pose: Pose) -> Built {
        var spec = QuadSpec()
        spec.bodyR = V2(8.2, 5.2)
        spec.bodyX = 14.8
        spec.legLen = 4.2
        spec.legR = (2, 1.7)
        spec.legX = (4.8, -5)
        spec.headR = 4.7
        spec.headOffset = V2(8, 6.4)
        spec.bellyR = V2(4.6, 2.2)
        // At rest it lies proud like the statue, forepaws stretched out in front.
        let resting = pose.stride == 0 && pose.lift == 0 && pose.dangle == 0 && pose.lunge == 0 && pose.headDip == 0
            && pose.lean == 0 && pose.lying == 0
        var p = pose
        if resting { p.lying = 0.7 }
        let q = quadruped(spec, p)
        var b = q.built
        if resting {
            // Raise the head back up proudly and reach the forelegs out.
            let lift = V2(-0.8, 1.6)
            for i in b.parts.indices where b.parts[i].role == .head {
                if case let .ellipse(c, r, _) = b.parts[i].shape { b.parts[i].shape = .ellipse(c: c + lift, r: r, angle: 0) }
            }
            b.headC += lift
            b.headAngle = 0
            for i in [2, 3] {
                if case let .capsule(a, _, ra, rb) = b.parts[i].shape {
                    b.parts[i].shape = .capsule(a: a, b: V2(a.x + 6, ground + rb), ra: ra, rb: rb)
                }
            }
        }
        // Muzzle and chin.
        b.parts.append(Part(.ellipse(c: b.onHead(V2(0.7, -0.4)), r: V2(2.6, 2), angle: b.headAngle), .secondary, z: 1.1, group: 1))
        b.parts.append(Part(.ellipse(c: b.onHead(V2(1.05, -0.15)), r: V2(0.7, 0.55), angle: 0), .dark, z: 1.15, group: 1))
        // Folded wings along the back: gold coverts over blue flight feathers.
        let wingRoot = q.bodyC + rotate(V2(3.6, q.bodyR.y * 0.55), by: q.angle)
        let wa = q.angle - 0.05 - pose.wing * 0.12
        let wing = [V2(0.6, -0.4), V2(-0.2, 2.6), V2(-3.4, 3.6), V2(-8, 2.6), V2(-12, 0.4), V2(-10.6, -0.4), V2(-11, -1.4),
                    V2(-9, -1.2), V2(-9, -2.2), V2(-6.4, -1.6), V2(-3, -1.8)]
        let coverts = [V2(0.6, -0.4), V2(-0.2, 2.6), V2(-3.4, 3.6), V2(-6.2, 3.0), V2(-5.2, 0.6), V2(-2.4, -0.8)]
        for near in [false, true] {
            let root = wingRoot + (near ? V2(0, 0) : V2(-1, 1.2))
            let z = near ? 0.6 : -0.5
            let g = near ? 7 : 8, bias = near ? 0 : 1
            b.parts.append(Part(.polygon(w5Local(root, wa + (near ? 0 : 0.08), wing)), .blue, z: z, group: g, toneBias: bias))
            b.parts.append(Part(.polygon(w5Local(root, wa + (near ? 0 : 0.08), coverts)), .gold, z: z + 0.01, group: g,
                                toneBias: bias))
            if near {
                for x in [-6.5, -8.8] {
                    let pts = w5Local(root, wa, [V2(x, 1.6), V2(x - 1.4, -0.8)])
                    b.parts.append(Part(.capsule(a: pts[0], b: pts[1], ra: 0.3, rb: 0.3), .blue, z: z + 0.02, group: g,
                                        innerOutline: false, fixedTone: .shade))
                }
            }
        }
        // The nemes headdress: a striped cap and a lappet falling behind the head.
        let hc = b.headC, hr = b.headR
        for k in 0..<6 {
            let a0 = 0.6 + Double(k) * 0.45, a1 = a0 + 0.45
            b.parts.append(Part(w5Wedge(hc, r0: 0, r1: hr * 1.14, a0: a0, a1: a1, angle: b.headAngle), k % 2 == 0 ? .gold : .blue,
                                z: 1.3, group: 43))
        }
        for k in 0..<4 {
            let y0 = -0.1 - Double(k) * 0.42, y1 = y0 - 0.42
            b.parts.append(Part(headPolygon(b, [V2(-1.15, y0), V2(-0.35, y0 + 0.05), V2(-0.3 + Double(k) * 0.02, y1), V2(-1.1, y1)]),
                                k % 2 == 0 ? .blue : .gold, z: 1.3, group: 43))
        }
        // Brow band and a cobra at the brow.
        b.parts.append(Part(w5Wedge(hc, r0: hr * 0.9, r1: hr * 1.14, a0: 0.45, a1: 0.95, angle: b.headAngle), .gold, z: 1.31,
                            group: 43))
        let brow = b.onHead(V2(0.78, 0.72))
        b.parts.append(Part(.capsule(a: brow, b: brow + V2(0.5, 1.5), ra: 0.6, rb: 0.5), .gold, z: 1.35, group: 44))
        b.parts.append(Part(.ellipse(c: brow + V2(0.15, 0.5), r: V2(0.45, 0.45), angle: 0), .red, z: 1.36, group: 44,
                            innerOutline: false, fixedTone: .light))
        // Pharaoh's beard and a broad collar.
        let chin = b.onHead(V2(0.6, -0.9))
        b.parts.append(Part(.capsule(a: chin, b: chin + V2(-0.3, -2.4), ra: 0.75, rb: 0.65), .blue, z: 1.2, group: 45))
        b.parts.append(Part(.capsule(a: chin + V2(-0.1, -0.8), b: chin + V2(-0.2, -1.5), ra: 0.8, rb: 0.75), .gold, z: 1.21, group: 45,
                            innerOutline: false))
        b.parts.append(Part(w5Wedge(hc, r0: hr * 0.95, r1: hr * 1.5, a0: -1.9, a1: -0.75, angle: b.headAngle), .gold, z: 0.95,
                            group: 46))
        b.parts.append(Part(w5Wedge(hc, r0: hr * 1.15, r1: hr * 1.3, a0: -1.85, a1: -0.8, angle: b.headAngle), .blue, z: 0.96,
                            group: 46, innerOutline: false))
        // A lion's tail with a dark tuft.
        let base = q.bodyC + rotate(V2(-q.bodyR.x * 0.9, q.bodyR.y * 0.1), by: q.angle)
        let tailParts = tail(from: base, angle: 2.9 + pose.tail * 0.3 - pose.dangle - (resting ? 0.2 : 0), curl: -0.5,
                             segments: 3, length: 2.2, radius: (0.9, 0.7), ramp: .body, z: -1)
        b.parts += tailParts
        if case let .capsule(_, tip, _, _) = tailParts.last!.shape {
            b.parts.append(Part(.ellipse(c: tip, r: V2(1.5, 1.5), angle: 0), .dark, z: -0.9, group: 5))
        }
        b.eyeX = (0.3, 0.7)
        b.eyeY = 0.15
        b.mouth = V2(0.95, -0.6)
        b.cheek = V2(0.2, -0.35)
        b.topOverride = b.onHead(V2(-0.1, 1.15))
        return b
    }

    // MARK: Cerberus

    /// One of the extra heads: a hound's head with its own muzzle, ear and eye.
    private static func w5HoundHead(_ c: V2, r: Double, angle: Double, flip: Double = 1, z: Double, group: Int, bias: Int,
                                    pose: Pose) -> [Part] {
        func at(_ v: V2) -> V2 { c + rotate(V2(v.x * flip, v.y) * r, by: angle) }
        var parts: [Part] = []
        parts.append(Part(.ellipse(c: c, r: V2(r * 1.04, r), angle: angle), .body, z: z, group: group, patterned: true,
                          toneBias: bias, role: .head))
        parts.append(Part(.ellipse(c: at(V2(0.85, -0.38)), r: V2(r * 0.62, r * 0.44), angle: angle * flip), .secondary, z: z + 0.01,
                          group: group, toneBias: bias))
        parts.append(Part(.ellipse(c: at(V2(1.38, -0.22)), r: V2(0.75, 0.65), angle: 0), .dark, z: z + 0.02, group: group))
        parts.append(Part(.polygon([at(V2(-0.6, 0.5)), at(V2(0.05, 0.8)), at(V2(-0.55, 1.6))]), .body, z: z + 0.03, group: group + 5,
                          patterned: true, toneBias: bias, role: .extremity))
        parts += w5Eye(at(V2(0.45, 0.15)), pose: pose, z: z + 0.02, group: group)
        return parts
    }

    static func w5Cerberus(_ pose: Pose) -> Built {
        var spec = QuadSpec()
        spec.bodyR = V2(7.6, 5.2)
        spec.bodyX = 13.9
        spec.legLen = 4.4
        spec.legR = (1.8, 1.4)
        spec.legX = (4.4, -4.6)
        spec.headR = 4.2
        spec.headOffset = V2(7.8, 4.6)
        spec.bellyR = V2(4, 2)
        let q = quadruped(spec, pose)
        var b = q.built
        // Main head: pointed ears, a long muzzle.
        for (pts, z, bias) in [([V2(-0.75, 0.5), V2(-0.1, 0.85), V2(-0.65, 1.7)], 0.9, 1),
                               ([V2(-0.05, 0.8), V2(0.6, 0.55), V2(0.3, 1.65)], 1.2, 0)] {
            b.parts.append(Part(headPolygon(b, pts), .body, z: z, group: 6, patterned: true, toneBias: bias, role: .extremity))
        }
        b.parts.append(Part(headPolygon(b, [V2(0.35, 0.1), V2(1.6, -0.2), V2(1.6, -0.75), V2(0.3, -0.85)]), .secondary, z: 1.1,
                            group: 1))
        b.parts.append(Part(.ellipse(c: b.onHead(V2(1.6, -0.25)), r: V2(0.8, 0.7), angle: 0), .dark, z: 1.2, group: 1))
        // Two more heads, up and behind, each on its own neck, bobbing out of step.
        let neckRoot = q.bodyC + rotate(V2(4.4, 2.6), by: q.angle)
        for (k, off) in [V2(-1.4, 6.2), V2(-6.6, 3.8)].enumerated() {
            let ph = 2 * .pi * pose.t + Double(k + 1) * 2.1
            let c = b.headC + off + V2(0, sin(ph) * 0.4 * (1 - pose.lying)) + V2(0, -pose.lying * Double(k + 1) * 0.8)
            let z = 0.8 - Double(k) * 0.15, g = 47 + k
            let tilt = (k == 0 ? b.headAngle + 0.12 : -0.15) + sin(ph) * 0.05
            b.parts.append(Part(.capsule(a: neckRoot + V2(-Double(k) * 2, 0), b: c + V2(k == 0 ? -0.6 : 0.6, -1.4), ra: 2.4, rb: 2), .body,
                                z: z - 0.01, group: g, patterned: true, toneBias: k))
            b.parts += w5HoundHead(c, r: 3.6, angle: tilt, flip: k == 0 ? 1 : -1, z: z, group: g, bias: k, pose: pose)
        }
        // Spiked collar where the necks meet the chest.
        let ca = q.bodyC + rotate(V2(4.6, 4.2), by: q.angle), cb = q.bodyC + rotate(V2(7.4, -0.6), by: q.angle)
        b.parts.append(Part(.capsule(a: ca, b: cb, ra: 1.2, rb: 1.2), .dark, z: 0.95, group: 10))
        let d = (cb - ca) / max(0.001, ((cb - ca).x * (cb - ca).x + (cb - ca).y * (cb - ca).y).squareRoot())
        let n = V2(-d.y, d.x) * -1
        for t in [0.15, 0.5, 0.85] {
            let p = ca + (cb - ca) * t + n * 0.8
            b.parts.append(Part(.polygon([p + d * 0.8, p - d * 0.8, p + n * 2]), .stone, z: 0.96, group: 10))
            b.parts.append(Part(.ellipse(c: p - n * 0.8, r: V2(0.45, 0.45), angle: 0), .red, z: 0.97, group: 10, innerOutline: false,
                                fixedTone: .light))
        }
        // A tail that burns at its tip.
        let base = q.bodyC + rotate(V2(-q.bodyR.x * 0.85, q.bodyR.y * 0.25), by: q.angle)
        let tailParts = tail(from: base, angle: 2.4 + pose.tail * 0.3 - pose.dangle * 1.2 - pose.lying * 0.8, curl: -0.35,
                             segments: 3, length: 2.3, radius: (1.3, 0.9), ramp: .body, z: -1)
        b.parts += tailParts
        if case let .capsule(a, tip, _, _) = tailParts.last!.shape {
            let dir = atan2(tip.y - a.y, tip.x - a.x)
            b.parts += w5Flame(tip, dir: dir, length: 3.6, width: 1.3, flicker: sin(2 * .pi * pose.t * 2) * 0.7, z: -0.95, group: 11)
        }
        b.mouth = V2(1.2, -0.6)
        b.eyeX = (0.3, 0.75)
        return b
    }

    // MARK: Front and back views

    private static func w5DecorateFront(_ shape: BodyShape, _ b: inout Built, pose: Pose, back: Bool) {
        let (c, r) = w5Torso(b)
        let faceZ: Double = back ? -0.5 : 1
        let sides = [-1.0, 1.0]
        let flick = 2 * .pi * pose.t * 2
        switch shape {
        case .jackalope:
            let flop = pose.lying * 0.9 + pose.dangle * 0.5
            for s in sides {
                let root = b.onHead(V2(s * 0.45, 0.7))
                let tip = root + rotate(V2(0, 6.4), by: -s * (0.5 + flop))
                let earZ = back ? 0.5 : faceZ - 0.1
                b.parts.append(Part(.capsule(a: root, b: tip, ra: 1.5, rb: 1.1), .body, z: earZ, group: 6, patterned: true,
                                    role: .extremity))
                b.parts.append(Part(.capsule(a: root + (tip - root) * 0.8, b: tip, ra: 1.25, rb: 1.1), .dark, z: earZ + 0.01, group: 6,
                                    innerOutline: false))
                if !back {
                    b.parts.append(Part(.capsule(a: root + (tip - root) * 0.2, b: root + (tip - root) * 0.7, ra: 0.6, rb: 0.5), .pink,
                                        z: earZ + 0.01, group: 6, innerOutline: false))
                }
                b.parts += w5Antler(w5HareAntler, root: b.onHead(V2(s * 0.2, 0.88)), scale: 1.2, lean: -s * 0.35, flip: s,
                                    ramp: .wood, z: back ? 0.6 : faceZ + 0.2, group: s < 0 ? 40 : 41)
            }
        case .qilin:
            for s in sides {
                b.parts += w5Antler(w5QilinHorn, root: b.onHead(V2(s * 0.45, 0.78)), scale: 0.9, lean: -s * 0.35, flip: -s, ramp: .gold,
                                    z: back ? 0.6 : faceZ - 0.15, group: s < 0 ? 40 : 41)
            }
            w5Hooves(&b, ramp: .gold)
            var k = 0
            for part in b.parts where part.role == .limb {
                if case let .capsule(_, f, _, _) = part.shape {
                    let s: Double = f.x < 16 ? -1 : 1
                    b.parts += w5Flame(f + V2(s * 1.3, 1.6), dir: .pi / 2 - s * 0.5, length: 3.6, width: 1.0,
                                       flicker: sin(flick + Double(k) * 1.7) * 0.6, outer: .blue, inner: .white, z: part.z + 0.02,
                                       group: 10 + k)
                    k += 1
                }
            }
        case .mothkin:
            let flutter = pose.wing * 0.25 + sin(2 * .pi * pose.t) * 0.05 - pose.lying * 0.2
            for s in sides {
                let root = c + V2(s * 1.2, r.y * 0.45)
                // Spread wings: the side-view outlines turned on their side.
                let fore = [V2(0, 0), V2(3.6, 5.6), V2(8.6, 9.2), V2(11.6, 7.4), V2(11, 3.2), V2(7, 0.4), V2(3, -0.6)]
                let hind = [V2(0, -1), V2(5.6, -1.4), V2(8.6, -4.4), V2(6.6, -7), V2(3, -6.4), V2(0.6, -3.4)]
                let z = back ? 1.5 : -1.5
                for (k, (outline, spot, rr)) in [(hind, V2(5, -3.6), 1.4), (fore, V2(7.4, 4.4), 1.9)].enumerated() {
                    let zz = z + Double(k) * 0.05, g = (s < 0 ? 7 : 8) + k * 4
                    let pts = w5Local(root, s * flutter, outline, flip: s)
                    let centre = pts.reduce(V2.zero, +) / Double(pts.count)
                    b.parts.append(Part(.polygon(pts), .body, z: zz, group: g))
                    b.parts.append(Part(.polygon(pts.map { centre + ($0 - centre) * 0.7 }), .secondary, z: zz + 0.01, group: g,
                                        innerOutline: false))
                    let at = w5Local(root, s * flutter, [spot], flip: s)[0]
                    b.parts.append(Part(.ellipse(c: at, r: V2(rr, rr), angle: 0), .gold, z: zz + 0.02, group: g, innerOutline: false,
                                        fixedTone: .base))
                    b.parts.append(Part(.ellipse(c: at, r: V2(rr, rr) * 0.55, angle: 0), .dark, z: zz + 0.03, group: g,
                                        innerOutline: false, fixedTone: .base))
                    b.parts.append(Part(.ellipse(c: at + V2(-0.3, 0.3), r: V2(0.35, 0.35), angle: 0), .white, z: zz + 0.04, group: g,
                                        innerOutline: false, fixedTone: .light))
                }
                b.parts += w5Antenna(b.onHead(V2(s * 0.3, 0.88)), angle: .pi / 2 - s * 0.3, curl: -s * 0.2,
                                     z: back ? 0.6 : faceZ - 0.1, group: s < 0 ? 40 : 41, bias: 0)
            }
            // Fluffy collar under the chin.
            for (k, x) in [-3.6, -1.6, 0.0, 1.6, 3.6].enumerated() {
                let at = b.headC + V2(x, -b.headR * 0.85 + abs(x) * 0.35)
                b.parts.append(Part(.ellipse(c: at, r: V2(2, 1.8), angle: 0), .white, z: (back ? 0.3 : faceZ - 0.05) + Double(k) * 0.001,
                                    group: 10))
            }
        case .wyvern:
            // Strong scaly legs rather than the bird legs the biped profile gives.
            for i in b.parts.indices where b.parts[i].role == .limb && b.parts[i].ramp == .gold {
                b.parts[i].ramp = .body
                b.parts[i].patterned = true
                b.parts[i].innerOutline = true
                if case let .capsule(hip, foot, _, _) = b.parts[i].shape {
                    b.parts.append(Part(.ellipse(c: hip + V2(0, 0.3), r: V2(2.4, 2.8), angle: 0), .body, z: b.parts[i].z,
                                        group: b.parts[i].group, patterned: true, role: .limb))
                    b.parts.append(Part(.ellipse(c: foot + V2(0, -0.2), r: V2(1.9, 1), angle: 0), .body, z: b.parts[i].z + 0.01,
                                        group: b.parts[i].group, patterned: true))
                }
            }
            for s in sides {
                let r0 = b.onHead(V2(s * 0.55, 0.65))
                let r1 = r0 + V2(s * 2.2, 2.2), r2 = r1 + V2(s * 1.4, 2.0)
                let z = back ? 0.6 : faceZ - 0.1
                b.parts.append(Part(.capsule(a: r0, b: r1, ra: 1.1, rb: 0.75), .white, z: z, group: s < 0 ? 40 : 41))
                b.parts.append(Part(.capsule(a: r1, b: r2, ra: 0.75, rb: 0.45), .white, z: z, group: s < 0 ? 40 : 41))
            }
            if !back {
                b.parts.append(Part(.ellipse(c: b.onHead(V2(-0.25, -0.35)), r: V2(0.45, 0.4), angle: 0), .dark, z: faceZ + 0.2,
                                    group: 1))
                b.parts.append(Part(.ellipse(c: b.onHead(V2(0.25, -0.35)), r: V2(0.45, 0.4), angle: 0), .dark, z: faceZ + 0.2,
                                    group: 1))
            }
        case .phoenix:
            for (k, dir) in [Double.pi / 2 + 0.5, .pi / 2, .pi / 2 - 0.5].enumerated() {
                b.parts += w5Flame(b.onHead(V2((Double(k) - 1) * 0.35, 0.8)), dir: dir, length: k == 1 ? 6.2 : 5, width: 1.15,
                                   flicker: sin(flick + Double(k) * 2) * 0.6, z: faceZ + (back ? 0.05 : -0.1) - Double(k) * 0.001,
                                   group: 44 + k)
            }
            for s in sides {
                // Tail plumes fanning out low behind, each ending in a golden eye.
                for (k, (a, curl)) in [(-0.2, 0.16), (-0.7, 0.26)].enumerated() {
                    let spine = w5Curve(from: c + V2(s * 1.2, -r.y * 0.35), angle: s > 0 ? a : .pi - a, curl: s * curl, steps: 5,
                                        step: 1.8)
                    let z = (back ? 1.4 : -1.2) - Double(k) * 0.02
                    let g = 10 + k + (s < 0 ? 0 : 2)
                    b.parts.append(Part(w5Ribbon(spine, [0.8, 1.0, 1.1, 1.0, 0.8, 0.4]), .red, z: z, group: g))
                    b.parts.append(Part(w5Ribbon(spine, [0.2, 0.4, 0.45, 0.4, 0.3, 0.1]), .gold, z: z + 0.01, group: g,
                                        innerOutline: false, fixedTone: .light))
                    b.parts.append(Part(.ellipse(c: spine[4], r: V2(1.25, 1.25), angle: 0), .gold, z: z + 0.02, group: g,
                                        fixedTone: .light))
                    b.parts.append(Part(.ellipse(c: spine[4], r: V2(0.6, 0.6), angle: 0), .red, z: z + 0.03, group: g,
                                        innerOutline: false, fixedTone: .base))
                }
                // Wings held out low, their flight feathers turning to flame.
                let root = c + V2(s * 3.4, r.y * 0.3)
                let wa = s * (-0.45 + pose.wing * 0.9 - pose.lying * 0.3)
                let wing = [V2(1.4, 0.4), V2(0, 2.2), V2(-3.6, 2.2), V2(-7.4, 0.2), V2(-6, -1.6), V2(-2.6, -2.4), V2(0, -1.4)]
                let coverts = [V2(1.4, 0.4), V2(0, 2.2), V2(-3.6, 2.2), V2(-4.4, 0.6), V2(-1.4, -0.6)]
                let z = back ? 0.6 : -0.4
                let g = s < 0 ? 7 : 8
                for (k, (x, y, len)) in [(-7.0, 0.0, 4.2), (-5.6, -1.4, 3.6), (-3.6, -2.1, 2.8)].enumerated() {
                    let at = w5Local(root, wa, [V2(x, y)], flip: -s)[0]
                    let d = rotate(V2(-s * cos(3.5 - Double(k) * 0.25), sin(3.5 - Double(k) * 0.25)), by: wa)
                    b.parts += w5Flame(at, dir: atan2(d.y, d.x), length: len, width: 1, flicker: sin(flick + Double(k) * 1.3) * 0.6,
                                       z: z - 0.05 - Double(k) * 0.001, group: 14 + k + (s < 0 ? 0 : 3))
                }
                b.parts.append(Part(.polygon(w5Local(root, wa, wing, flip: -s)), .body, z: z, group: g, patterned: true,
                                    role: .extremity))
                b.parts.append(Part(.polygon(w5Local(root, wa, coverts, flip: -s)), .gold, z: z + 0.01, group: g))
            }
            b.parts += w5Motes(pose, around: c + V2(0, 6), spread: V2(10, 6), ramp: .red, core: .gold, rise: true)
        case .spiritStag:
            for s in sides {
                b.parts += w5Antler(w5StagAntler, root: b.onHead(V2(s * 0.45, 0.75)), scale: 0.78, lean: -s * 0.3, flip: -s, ramp: .blue,
                                    z: back ? 0.6 : faceZ - 0.15, group: s < 0 ? 40 : 41, glow: .light)
            }
            if !back {
                b.parts.append(Part(headPolygon(b, [V2(0, 0.8), V2(0.2, 0.55), V2(0, 0.35), V2(-0.2, 0.55)]), .blue, z: faceZ + 0.05,
                                    group: 1, innerOutline: false, fixedTone: .light))
            }
            w5Hooves(&b, ramp: .stone)
            b.parts += w5Motes(pose, around: c + V2(0, 5), spread: V2(11, 3), ramp: .blue, core: .white, rise: false)
        case .thunderbird:
            let flap = pose.wing
            for s in sides {
                let root = c + V2(s * 4.2, r.y * 0.35)
                let wa = s * (0.3 + flap * 0.25 - pose.lying * 0.4)
                let sc = V2(0.85, 0.8 + flap * 0.08)
                let z = back ? 1.5 : -1.5
                let g = s < 0 ? 7 : 8
                b.parts.append(Part(.polygon(w5Local(root, wa, w5StormWing, flip: -s, scale: sc)), .secondary, z: z, group: g,
                                    role: .extremity))
                b.parts.append(Part(.polygon(w5Local(root, wa, w5StormCoverts, flip: -s, scale: sc)), .body, z: z + 0.01, group: g,
                                    patterned: true))
                b.parts.append(w5Bolt(w5Local(root, wa, w5StormBolt, flip: -s, scale: sc), width: 0.7, ramp: .gold, z: z + 0.02,
                                      group: g + 30))
                // Crest feathers flaring out on both sides.
                let base = b.onHead(V2(s * 0.5, 0.75))
                let tip = base + V2(s * 3.6, 3.4 + pose.tail * 0.3)
                b.parts.append(Part(.polygon([base + V2(-1.1, 0), tip, base + V2(1.1, -0.3)]), .blue,
                                    z: back ? 0.6 : faceZ - 0.1, group: 44))
                b.parts.append(Part(.polygon([base + (tip - base) * 0.6 + V2(-0.4, 0), tip, base + (tip - base) * 0.6 + V2(0.4, -0.2)]),
                                    .gold, z: (back ? 0.6 : faceZ - 0.1) + 0.01, group: 44, innerOutline: false, fixedTone: .light))
            }
            // Feathered thighs over the legs, and dark talons.
            for part in b.parts where part.role == .limb && part.ramp == .gold {
                if case let .capsule(hip, foot, _, _) = part.shape {
                    b.parts.append(Part(.ellipse(c: hip + V2(0, 0.4), r: V2(2.4, 2.6), angle: 0), .body, z: part.z + 0.01,
                                        group: part.group + 10, patterned: true))
                    for dx in [-1.0, 0.0, 1.0] {
                        let t = foot + V2(dx * 1.1, -0.6)
                        b.parts.append(Part(.polygon([t + V2(-0.45, 0.4), t + V2(0.45, 0.4), t + V2(dx * 0.3, -0.8)]), .dark,
                                            z: part.z + 0.02, group: part.group))
                    }
                }
            }
        case .sphinx:
            let hc = b.headC, hr = b.headR
            if back {
                for k in 0..<8 {
                    let a0 = -0.5 + Double(k) * 0.52
                    b.parts.append(Part(w5Wedge(hc, r0: 0, r1: hr * 1.14, a0: a0, a1: a0 + 0.52), k % 2 == 0 ? .gold : .blue, z: -0.4,
                                        group: 43))
                }
            } else {
                for k in 0..<6 {
                    let a0 = 0.45 + Double(k) * 0.375
                    b.parts.append(Part(w5Wedge(hc, r0: hr * 0.62, r1: hr * 1.14, a0: a0, a1: a0 + 0.375, squash: 1),
                                        k % 2 == 0 ? .gold : .blue, z: faceZ + 0.3, group: 43))
                }
                b.parts.append(Part(w5Wedge(hc, r0: hr * 0.5, r1: hr * 0.72, a0: 0.4, a1: .pi - 0.4), .gold, z: faceZ + 0.31,
                                    group: 43))
                let brow = b.onHead(V2(0, 0.72))
                b.parts.append(Part(.capsule(a: brow, b: brow + V2(0, 1.6), ra: 0.6, rb: 0.5), .gold, z: faceZ + 0.35, group: 44))
                b.parts.append(Part(.ellipse(c: brow + V2(0, 0.5), r: V2(0.45, 0.45), angle: 0), .red, z: faceZ + 0.36, group: 44,
                                    innerOutline: false, fixedTone: .light))
                let chin = b.onHead(V2(0, -0.95))
                b.parts.append(Part(.capsule(a: chin, b: chin + V2(0, -2.4), ra: 0.75, rb: 0.65), .blue, z: faceZ + 0.2, group: 45))
                b.parts.append(Part(.capsule(a: chin + V2(0, -0.8), b: chin + V2(0, -1.5), ra: 0.8, rb: 0.75), .gold, z: faceZ + 0.21,
                                    group: 45, innerOutline: false))
                b.parts.append(Part(w5Wedge(hc, r0: hr * 0.9, r1: hr * 1.45, a0: -2.5, a1: -0.64), .gold, z: faceZ - 0.05, group: 46))
                b.parts.append(Part(w5Wedge(hc, r0: hr * 1.1, r1: hr * 1.26, a0: -2.45, a1: -0.7), .blue, z: faceZ - 0.04, group: 46,
                                    innerOutline: false))
                b.parts.append(Part(.ellipse(c: b.onHead(V2(0, -0.32)), r: V2(0.7, 0.55), angle: 0), .dark, z: faceZ + 0.2, group: 1))
            }
            for s in sides {
                // Lappets falling either side of the face.
                for k in 0..<4 {
                    let y0 = 0.2 - Double(k) * 0.45, y1 = y0 - 0.45
                    b.parts.append(Part(headPolygon(b, [V2(s * 0.78, y0), V2(s * 1.22, y0), V2(s * 1.2, y1), V2(s * 0.8, y1)]),
                                        k % 2 == 0 ? .blue : .gold, z: back ? -0.41 : faceZ + 0.3, group: 43))
                }
                // Folded wings rising over the shoulders.
                let root = c + V2(s * 2.5, r.y * 0.45)
                let wing = [V2(0, -1.5), V2(2.4, 2.5), V2(5.2, 3.8), V2(7.6, 2.4), V2(6.8, -1.2), V2(5, -4), V2(2.6, -3.4)]
                let coverts = [V2(0, -1.5), V2(2.4, 2.5), V2(5.2, 3.8), V2(5.4, 0.6), V2(2.6, -1.6)]
                let wa = s * pose.wing * 0.15
                b.parts.append(Part(.polygon(w5Local(root, wa, wing, flip: s)), .blue, z: back ? 1.5 : -1.5, group: s < 0 ? 7 : 8))
                b.parts.append(Part(.polygon(w5Local(root, wa, coverts, flip: s)), .gold, z: back ? 1.51 : -1.49, group: s < 0 ? 7 : 8))
            }
        case .cerberus:
            for s in sides {
                let ph = 2 * .pi * pose.t + (s < 0 ? 2.1 : 4.2)
                let hc = b.headC + V2(s * 6.6, -1 + sin(ph) * 0.4 * (1 - pose.lying))
                let hr = 3.9
                let z = faceZ - 0.2
                let g = s < 0 ? 47 : 48
                let tilt = s * 0.15
                func at(_ v: V2) -> V2 { hc + rotate(v * hr, by: tilt) }
                b.parts.append(Part(.capsule(a: c + V2(s * 3, r.y * 0.3), b: hc + V2(-s * 0.6, -1.4), ra: 2.4, rb: 2), .body,
                                    z: back ? -0.6 : z - 0.01, group: g, patterned: true))
                b.parts.append(Part(.ellipse(c: hc, r: V2(hr * 1.04, hr), angle: tilt), .body, z: z, group: g, patterned: true,
                                    role: .head))
                for e in [-1.0, 1.0] {
                    b.parts.append(Part(.polygon([at(V2(e * 0.25, 0.8)), at(V2(e * 0.85, 0.5)), at(V2(e * 0.72, 1.55))]), .body,
                                        z: back ? z + 0.03 : z - 0.02, group: g + 5, patterned: true, role: .extremity))
                }
                if !back {
                    b.parts.append(Part(.ellipse(c: at(V2(0, -0.42)), r: V2(2.1, 1.5), angle: tilt), .secondary, z: z + 0.01, group: g))
                    b.parts.append(Part(.ellipse(c: at(V2(0, -0.22)), r: V2(0.8, 0.6), angle: 0), .dark, z: z + 0.02, group: g))
                    for e in [-1.0, 1.0] { b.parts += w5Eye(at(V2(e * 0.42, 0.18)), pose: pose, z: z + 0.02, group: g) }
                }
            }
            if !back {
                b.parts.append(Part(.ellipse(c: b.onHead(V2(0, -0.22)), r: V2(0.85, 0.65), angle: 0), .dark, z: faceZ + 0.2, group: 1))
            }
            // Spiked collar across the chest.
            let collar = c + V2(0, r.y * 0.55 - 1.4)
            b.parts.append(Part(w5Wedge(collar + V2(0, 5), r0: 5.8, r1: 7.2, a0: -2.5, a1: -0.64), .dark, z: back ? 0.3 : 0.95, group: 10))
            if !back {
                for a in [-2.1, -1.57, -1.04] {
                    let p = collar + V2(0, 5) + V2(cos(a), sin(a)) * 7
                    let out = V2(cos(a), sin(a)), side = V2(-out.y, out.x)
                    b.parts.append(Part(.polygon([p + side * 0.8, p - side * 0.8, p + out * 1.9]), .stone, z: 0.96, group: 10))
                    b.parts.append(Part(.ellipse(c: p - out * 0.7, r: V2(0.45, 0.45), angle: 0), .red, z: 0.97, group: 10,
                                        innerOutline: false, fixedTone: .light))
                }
            }
        default:
            break
        }
    }
}

extension FrontProfile {
    /// Front and back profiles for this wave.
    static func wave5(_ shape: BodyShape) -> FrontProfile? {
        var p = FrontProfile()
        switch shape {
        case .jackalope:
            p.bodyR = V2(6.5, 6); p.headR = 5; p.headY = 6.4; p.legLen = 2.6; p.legR = (1.4, 1.2); p.legGap = 2.4
            p.ears = .none; p.snout = .muzzle(0.8); p.tail = .cotton
        case .qilin:
            p.bodyR = V2(5.6, 5.2); p.headR = 4.2; p.headY = 8.4; p.legLen = 6; p.legR = (1.6, 1.1); p.legGap = 2.4
            p.ears = .side; p.snout = .muzzle(0.95); p.tail = .bushy; p.neck = true
        case .mothkin:
            p.bodyR = V2(6, 5); p.headR = 5; p.headY = 5.4; p.legLen = 2.4; p.legR = (1.1, 0.9); p.legGap = 2.4
            p.ears = .none; p.snout = .none; p.tail = .none
        case .wyvern:
            p.body = .biped; p.bodyR = V2(5.6, 5); p.headR = 4.3; p.headY = 8; p.legLen = 5; p.legR = (1.6, 1.2); p.legGap = 2.8
            p.ears = .none; p.snout = .muzzle(1.1); p.tail = .spade; p.batWings = true; p.neck = true
        case .phoenix:
            p.body = .biped; p.bodyR = V2(5.6, 5.6); p.headR = 4.2; p.headY = 7.2; p.legLen = 3.4; p.legR = (0.7, 0.6)
            p.legGap = 2.2; p.ears = .none; p.snout = .beak; p.tail = .none; p.neck = true; p.chest = .gold
        case .spiritStag:
            p.bodyR = V2(5.4, 4.9); p.headR = 4; p.headY = 7.2; p.legLen = 5.6; p.legR = (1.3, 0.95); p.legGap = 2.4
            p.ears = .side; p.snout = .muzzle(0.85); p.tail = .cotton; p.neck = true; p.chest = .white
        case .thunderbird:
            p.body = .biped; p.bodyR = V2(6, 6.2); p.headR = 4.4; p.headY = 7.4; p.legLen = 3.2; p.legR = (0.95, 0.8)
            p.legGap = 2.4; p.ears = .none; p.snout = .beak; p.tail = .feathers
        case .sphinx:
            p.bodyR = V2(6.6, 5.2); p.headR = 4.7; p.headY = 6.2; p.legLen = 4.2; p.legR = (2, 1.7); p.legGap = 3
            p.ears = .none; p.snout = .muzzle(0.95); p.tail = .thin
        case .cerberus:
            p.bodyR = V2(6.2, 5.2); p.headR = 4.4; p.headY = 6.2; p.legLen = 4.4; p.legR = (1.8, 1.4); p.legGap = 2.8
            p.ears = .pointy(1.1); p.snout = .muzzle(0.9); p.tail = .thin
        default:
            return nil
        }
        return p
    }
}
