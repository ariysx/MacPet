import Foundation

/// Every random roll in the simulation goes through this, so tests can use a fixed seed.
protocol RandomSource {
    mutating func nextUInt64() -> UInt64
}

extension RandomSource {
    /// A value in 0..<1.
    mutating func nextDouble() -> Double {
        Double(nextUInt64() >> 11) * (1.0 / 9_007_199_254_740_992.0)
    }

    mutating func chance(_ probability: Double) -> Bool {
        nextDouble() < probability
    }

    mutating func double(in range: ClosedRange<Double>) -> Double {
        range.lowerBound + (range.upperBound - range.lowerBound) * nextDouble()
    }

    mutating func int(below n: Int) -> Int {
        precondition(n > 0)
        return Int(nextUInt64() % UInt64(n))
    }

    mutating func coin() -> Bool {
        nextUInt64() & 1 == 1
    }

    mutating func pick<T>(_ items: [T]) -> T {
        items[int(below: items.count)]
    }
}

/// SplitMix64. Small, fast and Codable, so its state is part of the save file.
struct SeededRandom: RandomSource, Codable, Equatable {
    var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func nextUInt64() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}
