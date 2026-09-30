import Foundation
#if canImport(Darwin)
import Darwin
#else
import Glibc
#endif

struct SaveFile: Codable {
    static let currentVersion = 1
    var version: Int
    var world: World
}

enum SaveStore {
    enum Outcome: Equatable {
        case loaded
        case created
        /// The old file was unreadable and was moved to this path.
        case recovered(movedTo: URL)
    }

    static var defaultURL: URL {
        URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent("Library/Application Support/PixelPets/world.json")
    }

    /// Loads the world. A missing file starts a new world; a corrupt one is renamed
    /// to `world.corrupt-<date>.json` and a new world starts with one egg.
    static func load(from url: URL, newSeed: UInt64, date: Date = Date()) -> (World, Outcome) {
        let fm = FileManager.default
        guard fm.fileExists(atPath: url.path) else {
            return (World.newWorld(seed: newSeed), .created)
        }
        do {
            let data = try Data(contentsOf: url)
            let file = try JSONDecoder.pets.decode(SaveFile.self, from: data)
            guard file.version <= SaveFile.currentVersion else {
                throw CocoaError(.fileReadCorruptFile)
            }
            var world = file.world
            world.resetTransientState()
            return (world, .loaded)
        } catch {
            let moved = corruptURL(for: url, date: date)
            try? fm.moveItem(at: url, to: moved)
            return (World.newWorld(seed: newSeed), .recovered(movedTo: moved))
        }
    }

    /// Writes a temp file next to the save, then renames it into place.
    static func save(_ world: World, to url: URL) throws {
        let fm = FileManager.default
        try fm.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let data = try JSONEncoder.pets.encode(SaveFile(version: SaveFile.currentVersion, world: world))
        let temp = url.deletingLastPathComponent().appendingPathComponent(".\(url.lastPathComponent).tmp")
        try data.write(to: temp)
        guard rename(temp.path, url.path) == 0 else {
            throw CocoaError(.fileWriteUnknown)
        }
    }

    static func corruptURL(for url: URL, date: Date) -> URL {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd-HHmmss"
        let base = url.deletingPathExtension().lastPathComponent
        return url.deletingLastPathComponent()
            .appendingPathComponent("\(base).corrupt-\(formatter.string(from: date)).json")
    }
}

extension JSONEncoder {
    static var pets: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}

extension JSONDecoder {
    static var pets: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
