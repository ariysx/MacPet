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
            let data = migrate(try Data(contentsOf: url))
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

    /// Saves from older versions lack fields added since. Fill each missing key from a freshly
    /// made object of the same kind, so an old save loads instead of looking corrupt.
    static func migrate(_ data: Data) -> Data {
        guard var root = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              var world = root["world"] as? [String: Any] else { return data }
        var template = World.newWorld(seed: 1)
        template.localHour = { 12 }
        template.advance(by: 20 * 60 + 1) // hatch the egg so there is a pet to copy
        template.addEgg(at: 10, genes: nil)
        template.loot.append(Loot(id: UUID(), kind: .bag, x: 0, items: []))
        guard let encoded = try? JSONEncoder.pets.encode(SaveFile(version: SaveFile.currentVersion, world: template)),
              let t = (try? JSONSerialization.jsonObject(with: encoded)) as? [String: Any],
              let tw = t["world"] as? [String: Any] else { return data }

        func fill(_ object: [String: Any], from defaults: [String: Any]?) -> [String: Any] {
            guard let defaults else { return object }
            var out = object
            for (key, value) in defaults where out[key] == nil { out[key] = value }
            return out
        }
        func first(_ key: String) -> [String: Any]? { (tw[key] as? [[String: Any]])?.first }

        // Missing lists start empty rather than copying the template's contents.
        var topDefaults = tw
        for key in ["pets", "eggs", "graves", "loot", "graveyard"] { topDefaults[key] = [Any]() }
        world = fill(world, from: topDefaults)
        for key in ["pets", "eggs", "graves", "loot"] {
            if let list = world[key] as? [[String: Any]] { world[key] = list.map { fill($0, from: first(key)) } }
        }
        root["world"] = world
        return (try? JSONSerialization.data(withJSONObject: root)) ?? data
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
