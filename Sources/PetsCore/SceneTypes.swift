import Foundation

// The frame data handed to Shaders.metal. These layouts must match the Metal structs
// exactly; PetsCoreTests checks the strides (64 and 80 bytes).

struct SceneUniforms {          // buffer(0)
    var resolution: SIMD2<Float>   // drawable size in real pixels
    var grid: SIMD2<Float>         // virtual grid size, e.g. 320 x 200
    var time: Float                // seconds, wraps every 6 h
    var dayPhase: Float            // 0..1, local midnight to midnight
    var rain: Float                // 0..1 intensity
    var playMode: Float            // 0 or 1
    var itemCount: UInt32
    var pad: SIMD3<UInt32> = .zero
}

struct SceneItem {              // buffer(1), array of up to 24
    // 4 pets + 4 weapons + monster + 6 pellets + smoke + loot, with room to spare.
    static let maxCount = 24

    struct Flags: OptionSet {
        let rawValue: UInt32
        static let flipX = Flags(rawValue: 1 << 0)
        static let hurtFlash = Flags(rawValue: 1 << 1)
        static let blinkHealth = Flags(rawValue: 1 << 2)
        static let eggBar = Flags(rawValue: 1 << 3)
        static let monsterBar = Flags(rawValue: 1 << 4)
    }

    var position: SIMD2<Float> = .zero     // grid px, bottom-centre of the sprite
    var tile: UInt32 = 0                   // atlas tile index for this frame
    var tileSpan: UInt32 = 1               // 1 for 16x16, 2 for 32x32 (ogre)
    var primary: SIMD4<Float> = .zero      // body colour (b)
    var secondary: SIMD4<Float> = .zero    // secondary colour (s)
    var bars: SIMD4<Float> = SIMD4(-1, -1, -1, -1) // health, hunger, happiness, 0..1; negative = hidden
    var icon: Int32 = -1                   // feeling icon tile, -1 = none
    var flags: UInt32 = 0
    var pad: SIMD2<UInt32> = .zero
}
