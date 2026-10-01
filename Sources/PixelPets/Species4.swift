import Foundation

// Wave 4 species: seal, redPanda, lion, chameleon, pangolin, fruitBat, peacock, kitsune, griffin, pegasus.

extension SpeciesRig {
    /// Side rigs for this wave. Returns nil for any other shape.
    static func buildWave4(_ shape: BodyShape, pose: Pose) -> Built? {
        switch shape {
        default: return nil
        }
    }

    /// Fully custom front or back views, for animals the shared FrontProfile can't express.
    /// Returns nil to use the profile from `FrontProfile.wave4`.
    static func frontalWave4(_ shape: BodyShape, pose: Pose, back: Bool) -> Built? {
        nil
    }
}

extension FrontProfile {
    /// Front and back profiles for this wave.
    static func wave4(_ shape: BodyShape) -> FrontProfile? {
        nil
    }
}
