import Foundation

// Wave 5 species: jackalope, qilin, mothkin, wyvern, phoenix, spiritStag, skyWhale, thunderbird, sphinx, cerberus.

extension SpeciesRig {
    /// Side rigs for this wave. Returns nil for any other shape.
    static func buildWave5(_ shape: BodyShape, pose: Pose) -> Built? {
        switch shape {
        default: return nil
        }
    }

    /// Fully custom front or back views, for animals the shared FrontProfile can't express.
    /// Returns nil to use the profile from `FrontProfile.wave5`.
    static func frontalWave5(_ shape: BodyShape, pose: Pose, back: Bool) -> Built? {
        nil
    }
}

extension FrontProfile {
    /// Front and back profiles for this wave.
    static func wave5(_ shape: BodyShape) -> FrontProfile? {
        nil
    }
}
