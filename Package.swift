// swift-tools-version:5.9
// Used only to run the PetsCore tests (`swift test`). The app itself is built by build.sh.
import PackageDescription

let package = Package(
    name: "PixelPets",
    platforms: [.macOS(.v13)],
    targets: [
        .target(name: "PetsCore", path: "Sources/PetsCore"),
        .testTarget(name: "PetsCoreTests", dependencies: ["PetsCore"], path: "Tests/PetsCoreTests"),
    ]
)
