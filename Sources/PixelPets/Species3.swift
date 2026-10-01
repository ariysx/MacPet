import Foundation

// Wave 3 species: hamster, puppy, chick, sheep, snail, koala, panda, squirrel, otter, goat.

extension SpeciesRig {
    /// Side rigs for this wave. Returns nil for any other shape.
    static func buildWave3(_ shape: BodyShape, pose: Pose) -> Built? {
        switch shape {
        default: return nil
        }
    }

    /// Fully custom front or back views, for animals the shared FrontProfile can't express.
    /// Returns nil to use the profile from `FrontProfile.wave3`.
    static func frontalWave3(_ shape: BodyShape, pose: Pose, back: Bool) -> Built? {
        nil
    }
}

extension FrontProfile {
    /// Front and back profiles for this wave.
    static func wave3(_ shape: BodyShape) -> FrontProfile? {
        nil
    }
}
