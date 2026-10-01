// Pixel Pets: a family of pixel-art pets that live on the macOS desktop.
// Build with ./build.sh (needs Xcode Command Line Tools). macOS 13+.

import AppKit
import Carbon.HIToolbox
import Metal
import MetalKit
import QuartzCore
import ServiceManagement
import UserNotifications

/// Time of Day override from the menu, in local hours; nil follows the clock. A global so the
/// simulation's clock closure can read it.
var timeOfDayOverride: Double?

/// A menu item's action as a closure, so menu rows can carry their own pet or item.
final class MenuAction: NSObject {
    let run: @MainActor () -> Void
    init(_ run: @escaping @MainActor () -> Void) { self.run = run }
}

@main
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory) // menu bar only, no Dock icon
        withExtendedLifetime(delegate) { app.run() }
    }

    static weak var shared: AppDelegate?

    private enum Key {
        static let fps = "fps"
        static let notifications = "notifications"
        static let background = "background"
        static let timeOfDay = "timeOfDay"
        static let weather = "weather"
    }

    private static let timesOfDay: [(String, Double?)] = [("Live", nil), ("Dawn", 6.5), ("Day", 12), ("Dusk", 19.3), ("Night", 23.5)]

    // MARK: State

    /// Replaced by the saved world at launch.
    var world = World(seed: 0)
    private(set) var playMode = false
    private(set) var renderer: PetsRenderer?
    private(set) var regions = PetSpriteRegions()
    let playUI = PlayUI()
    /// Hit bursts currently on screen.
    private(set) var effects: [SceneEffect] = []
    private(set) var dayPhase: Float = 0.5
    private(set) var backgroundTexture: MTLTexture?
    private var auroraTonight = false

    /// For SceneUniforms.background: x flags (1 image, 2 aurora), y and z the image size.
    var backgroundInfo: SIMD3<UInt32> {
        var flags: UInt32 = auroraTonight ? 2 : 0
        guard let image = backgroundTexture else { return SIMD3(flags, 0, 0) }
        flags |= 1
        return SIMD3(flags, UInt32(image.width), UInt32(image.height))
    }

    static var backgroundsFolder: URL {
        SaveStore.defaultURL.deletingLastPathComponent().appendingPathComponent("Backgrounds", isDirectory: true)
    }

    private var windows: [CGDirectDisplayID: WallpaperWindow] = [:]
    private var statusItem: NSStatusItem!
    private var userPaused = false
    private var screensAsleep = false
    private var lastTick = CACurrentMediaTime()
    private var lastInput = CACurrentMediaTime()
    private let startTime = CACurrentMediaTime()
    private var hotKey: EventHotKeyRef?
    private let defaults = UserDefaults.standard
    private let saveURL = SaveStore.defaultURL
    private var loadOutcome = SaveStore.Outcome.created
    /// Debug speed-up: PIXELPETS_SPEED=600 multiplies simulated time.
    private let speed = AppDelegate.readSpeed()

    private var fps: Int { defaults.integer(forKey: Key.fps) }
    private var notificationsOn: Bool { defaults.bool(forKey: Key.notifications) }
    private var running: Bool { !userPaused && !screensAsleep }
    /// Animation time. It stands still during a hit-stop, so a big blow lands with a jolt.
    var renderTime: Double {
        let t = CACurrentMediaTime()
        return (t < freezeEnd ? freezeStart : t - (freezeEnd - freezeStart)) - startTime - frozenTotal
    }
    private var freezeStart = 0.0, freezeEnd = 0.0, frozenTotal = 0.0
    private var shakeUntil = 0.0, shakeAmount: Float = 0
    private var flashStart = -10.0
    private var boltX: Float = -1

    /// Holds every animation still for a moment.
    private func hitStop(_ seconds: Double) {
        let t = CACurrentMediaTime()
        if t >= freezeEnd {
            frozenTotal += freezeEnd - freezeStart
            freezeStart = t
            freezeEnd = t + seconds
        } else {
            freezeEnd = max(freezeEnd, t + seconds)
        }
    }

    private func shake(_ amount: Float, for seconds: Double) {
        shakeUntil = max(shakeUntil, CACurrentMediaTime() + seconds)
        shakeAmount = max(shakeAmount, amount)
    }

    /// Grid pixels to nudge the scene by this frame.
    var shakeOffset: SIMD2<Float> {
        let t = CACurrentMediaTime()
        guard t < shakeUntil else { shakeAmount = 0; return .zero }
        let a = shakeAmount * Float(min(1, (shakeUntil - t) / 0.15))
        return SIMD2((Float.random(in: -1...1) * a).rounded(), (Float.random(in: -1...1) * a).rounded())
    }

    /// Lightning: a bright double flicker that fades, and the bolt's position.
    var lightningFlash: (flash: Float, bolt: Float) {
        let age = CACurrentMediaTime() - flashStart
        guard age < 0.7 else { return (0, -1) }
        let flicker: Double = age < 0.08 ? 1 : age < 0.14 ? 0.2 : age < 0.22 ? 0.9 : max(0, 0.6 * (1 - (age - 0.22) / 0.48))
        return (Float(flicker), age < 0.3 ? boltX : -1)
    }

    nonisolated private static func readSpeed() -> Double {
        max(1, Double(ProcessInfo.processInfo.environment["PIXELPETS_SPEED"] ?? "") ?? 1)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        AppDelegate.shared = self
        (world, loadOutcome) = SaveStore.load(from: saveURL, newSeed: UInt64.random(in: 1...UInt64.max))
        timeOfDayOverride = Self.timesOfDay.first { $0.0 == defaults.string(forKey: Key.timeOfDay) }?.1
        world.localHour = { timeOfDayOverride ?? World.systemLocalHour() }
        world.weatherOverride = defaults.string(forKey: Key.weather).flatMap(Weather.init(rawValue:))
        defaults.register(defaults: [Key.fps: 30, Key.notifications: true])

        guard let renderer = PetsRenderer() else {
            showAlert("Pixel Pets can't start", info: "It needs a Mac with Metal, and Shaders.metal inside the app. Run the app from Terminal to see details.")
            NSApp.terminate(nil)
            return
        }
        self.renderer = renderer
        try? FileManager.default.createDirectory(at: Self.backgroundsFolder, withIntermediateDirectories: true)
        loadBackground()

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu

        updateDayPhase()
        syncSprites()
        syncWindows()

        let nc = NotificationCenter.default
        nc.addObserver(self, selector: #selector(screensChanged),
                       name: NSApplication.didChangeScreenParametersNotification, object: nil)
        let wnc = NSWorkspace.shared.notificationCenter
        wnc.addObserver(self, selector: #selector(screensSlept), name: NSWorkspace.screensDidSleepNotification, object: nil)
        wnc.addObserver(self, selector: #selector(screensWoke), name: NSWorkspace.screensDidWakeNotification, object: nil)
        wnc.addObserver(self, selector: #selector(screensSlept), name: NSWorkspace.sessionDidResignActiveNotification, object: nil)
        wnc.addObserver(self, selector: #selector(screensWoke), name: NSWorkspace.sessionDidBecomeActiveNotification, object: nil)

        registerHotKey()
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }

        // 30 Hz, so thrown pets fly smoothly.
        let sim = Timer(timeInterval: 1.0 / 30, target: self, selector: #selector(simTick), userInfo: nil, repeats: true)
        RunLoop.main.add(sim, forMode: .common)
        let saver = Timer(timeInterval: 30, target: self, selector: #selector(autosave), userInfo: nil, repeats: true)
        RunLoop.main.add(saver, forMode: .common)

        if case .recovered(let moved) = loadOutcome {
            petsLog("save file was unreadable; moved to \(moved.path)")
            notify("Your saved pets couldn't be read", "A new egg has appeared. The old file was kept as \(moved.lastPathComponent).")
        }
        if speed > 1 { petsLog("running at \(speed)x speed") }
        applyRunning()
        updateStatusIcon()
    }

    func applicationWillTerminate(_ notification: Notification) {
        save()
    }

    // MARK: Simulation

    @objc private func simTick() {
        let now = CACurrentMediaTime()
        let dt = min(now - lastTick, 1)
        lastTick = now
        updateDayPhase()
        guard running else { return }
        guard now >= freezeEnd else { return } // hit-stop: the world holds its breath

        world.advance(by: dt * speed)
        let events = world.events
        world.events.removeAll()
        for event in events { handle(event) }
        showHits()
        showLightning()
        syncSprites()

        if playMode && now - lastInput > 120 { setPlayMode(false) }
        updateStatusIcon()
    }

    /// Composes new pets' sprites on a background thread (about half a second each), then
    /// writes them into the atlas on the main thread. Pets show up once their frames are ready.
    private func syncSprites() {
        guard renderer != nil else { return }
        regions.releaseGone(world.pets)
        for pet in world.pets where !regions.isAssigned(pet.id) {
            guard let region = regions.reserve(pet.id) else { continue }
            let id = pet.id, looks = pet.looks
            Task.detached(priority: .userInitiated) { [weak self] in
                let frames = PetComposer.frames(for: looks)
                await self?.installSprites(frames, id: id, region: region)
            }
        }
    }

    /// Writes a pet's freshly composed frames into the atlas, unless its region was freed meanwhile.
    private func installSprites(_ frames: [PixelSprite], id: UUID, region: Int) {
        guard let renderer, regions.isReserved(id, region: region) else { return }
        renderer.atlas.write(frames, region: region)
        regions.markReady(id)
        renderer.uploadAtlas()
    }

    private func updateDayPhase() {
        let c = Calendar.current.dateComponents([.hour, .minute, .second], from: Date())
        let seconds = (c.hour ?? 12) * 3600 + (c.minute ?? 0) * 60 + (c.second ?? 0)
        dayPhase = timeOfDayOverride.map { Float($0 / 24) } ?? Float(seconds) / 86_400
        // About one night in three has an aurora. Nights are counted from noon to noon.
        let night = Int((Date().timeIntervalSince1970 + Double(TimeZone.current.secondsFromGMT()) - 43_200) / 86_400)
        auroraTonight = (UInt64(truncatingIfNeeded: night) &* 2_654_435_761) % 3 == 0
    }

    // MARK: Background images

    private func backgroundFiles() -> [URL] {
        let types: Set<String> = ["png", "jpg", "jpeg", "gif", "bmp", "tif", "tiff", "heic", "webp"]
        let files = (try? FileManager.default.contentsOfDirectory(at: Self.backgroundsFolder, includingPropertiesForKeys: nil)) ?? []
        return files.filter { types.contains($0.pathExtension.lowercased()) }
            .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
    }

    /// Loads the chosen picture, or clears it to use the drawn landscape.
    private func loadBackground() {
        backgroundTexture = nil
        guard let renderer, let name = defaults.string(forKey: Key.background) else { return }
        let url = Self.backgroundsFolder.appendingPathComponent(name)
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        do {
            backgroundTexture = try MTKTextureLoader(device: renderer.device).newTexture(URL: url, options: [.SRGB: false])
        } catch {
            petsLog("could not load background \(name): \(error)")
        }
    }

    private func backgroundMenu() -> NSMenuItem {
        let item = NSMenuItem(title: "Background", action: nil, keyEquivalent: "")
        let sub = NSMenu()
        let current = defaults.string(forKey: Key.background)
        let drawn = action("Meadow (drawn)") { [unowned self] in
            defaults.removeObject(forKey: Key.background)
            loadBackground()
        }
        drawn.state = backgroundTexture == nil ? .on : .off
        sub.addItem(drawn)
        let files = backgroundFiles()
        if !files.isEmpty { sub.addItem(.separator()) }
        for file in files {
            let name = file.lastPathComponent
            let row = action(file.deletingPathExtension().lastPathComponent) { [unowned self] in
                defaults.set(name, forKey: Key.background)
                loadBackground()
            }
            row.state = name == current && backgroundTexture != nil ? .on : .off
            sub.addItem(row)
        }
        sub.addItem(.separator())
        sub.addItem(action("Open Backgrounds Folder…") {
            try? FileManager.default.createDirectory(at: Self.backgroundsFolder, withIntermediateDirectories: true)
            NSWorkspace.shared.open(Self.backgroundsFolder)
        })
        sub.addItem(info("Add PNG or JPG pictures to that folder."))
        item.submenu = sub
        return item
    }

    @objc private func autosave() {
        save()
    }

    private func save() {
        do {
            try SaveStore.save(world, to: saveURL)
        } catch {
            petsLog("save failed: \(error)")
        }
    }

    func noteInput() {
        lastInput = CACurrentMediaTime()
    }

    // MARK: Windows

    private func displayID(_ screen: NSScreen) -> CGDirectDisplayID? {
        screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID
    }

    /// Adds a window for a new display, drops one for a removed display, and only resizes the
    /// rest, so plugging a display in or out never resets anything.
    private func syncWindows() {
        guard let renderer else { return }
        let mainID = NSScreen.screens.first.flatMap(displayID)
        var seen = Set<CGDirectDisplayID>()
        for screen in NSScreen.screens {
            guard let id = displayID(screen) else { continue }
            seen.insert(id)
            let window: WallpaperWindow
            if let existing = windows[id] {
                window = existing
                if window.frame != screen.frame { window.setFrame(screen.frame, display: true) }
            } else {
                window = WallpaperWindow.make(screen: screen, app: self, renderer: renderer)
                window.orderFront(nil)
                windows[id] = window
                petsLog("window for \(screen.localizedName) at \(screen.frame)")
            }
            window.petsView.isMain = id == mainID
            window.petsView.preferredFramesPerSecond = fps
            window.setPlayMode(playMode && id == mainID)
        }
        for (id, window) in windows where !seen.contains(id) {
            window.petsView.isPaused = true
            window.orderOut(nil)
            windows[id] = nil
        }
        applyRunning()
    }

    /// Draws unless paused or the screens are off. Never pauses for being covered.
    private func applyRunning() {
        for window in windows.values { window.petsView.isPaused = !running }
    }

    @objc private func screensChanged() {
        syncWindows()
    }

    @objc private func screensSlept() {
        screensAsleep = true
        save()
        applyRunning()
    }

    @objc private func screensWoke() {
        screensAsleep = false
        lastTick = CACurrentMediaTime()
        applyRunning()
    }

    // MARK: Play mode

    /// Apps hidden when play mode started, and the one that was in front, to bring back after.
    private var hiddenForPlay: [NSRunningApplication] = []
    private var frontBeforePlay: NSRunningApplication?

    /// Hides every other app's windows for play mode, and on the way out shows exactly those
    /// again, with the app that was in front back in front. Apps the user had hidden stay hidden.
    private func clearDesk(_ on: Bool) {
        if on {
            guard UserDefaults.standard.object(forKey: "hideAppsInPlay") as? Bool ?? true else { return }
            frontBeforePlay = NSWorkspace.shared.frontmostApplication
            hiddenForPlay = NSWorkspace.shared.runningApplications.filter {
                $0.activationPolicy == .regular && !$0.isHidden && $0 != NSRunningApplication.current
            }
            for app in hiddenForPlay { app.hide() }
        } else {
            for app in hiddenForPlay where !app.isTerminated { app.unhide() }
            hiddenForPlay = []
            if let front = frontBeforePlay, !front.isTerminated, front != NSRunningApplication.current {
                front.activate(options: [])
            }
            frontBeforePlay = nil
        }
    }

    @objc func togglePlayMode() {
        setPlayMode(!playMode)
    }

    func setPlayMode(_ on: Bool) {
        let changed = on != playMode
        playMode = on
        noteInput()
        if changed { clearDesk(on) }
        let mainID = NSScreen.screens.first.flatMap(displayID)
        if on { NSApp.activate(ignoringOtherApps: true) }
        for (id, window) in windows {
            window.setPlayMode(on && id == mainID)
        }
        // Tuck the Dock away while playing so the pets get the whole screen.
        NSApp.presentationOptions = on ? [.autoHideDock] : []
    }

    private func registerHotKey() {
        // ⌥⌘P. RegisterEventHotKey needs no Accessibility permission.
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        _ = InstallEventHandler(GetApplicationEventTarget(), { _, _, _ -> OSStatus in
            Task { @MainActor in AppDelegate.shared?.togglePlayMode() }
            return noErr
        }, 1, &spec, nil, nil)
        let id = EventHotKeyID(signature: OSType(0x5050_4554), id: 1) // 'PPET'
        let status = RegisterEventHotKey(UInt32(kVK_ANSI_P), UInt32(cmdKey | optionKey), id,
                                         GetApplicationEventTarget(), 0, &hotKey)
        if status != noErr { petsLog("could not register ⌥⌘P (status \(status))") }
    }

    private func showLightning() {
        guard let x = world.lightning.last else { return }
        world.lightning.removeAll()
        flashStart = CACurrentMediaTime()
        // The shader draws the bolt in landscape design units (480 across).
        boltX = Float(x / World.width * 480)
        shake(1, for: 0.25)
    }

    /// Turns the blows landed this tick into bursts and, in play mode, damage numbers.
    /// Crits, heavy blows and the finishing blow stop time for an instant and shake the scene.
    private func showHits() {
        let now = renderTime
        effects.removeAll { now - $0.born > SceneEffect.duration }
        let ground = windows.values.first { $0.petsView.isMain }?.petsView.groundY ?? 120
        for hit in world.hits {
            let x = Float(hit.x) * SceneBuilder.worldScale
            let y = ground + Float(hit.height) * SceneBuilder.worldScale + 20
            effects.append(SceneEffect(x: x, y: y, born: now, big: hit.crit || hit.finishing || hit.heavy))
            if hit.finishing {
                hitStop(0.22)
                shake(4, for: 0.35)
            } else if hit.crit || hit.heavy {
                hitStop(0.09)
                shake(hit.heavy ? 3 : 2, for: 0.2)
            } else {
                hitStop(0.045)
            }
            if playMode {
                let text = hit.finishing ? "K.O.!" : hit.crit ? "CRIT -\(Int(hit.damage.rounded()))" : "-\(Int(hit.damage.rounded()))"
                let ink = hit.finishing || hit.crit ? Ink.make(.gold, .light) : hit.onMonster ? PlayUI.white : Ink.make(.red, .light)
                playUI.toast(text, ink: ink, atGrid: SIMD2(x, y + 40))
            }
        }
        world.hits.removeAll()
    }

    /// Opens a chest or picks up a bag, with the item reveal.
    func openLoot(id: UUID) {
        guard let loot = world.loot.first(where: { $0.id == id }) else { return }
        let items = world.collectLoot(id: id)
        let title: String
        switch loot.kind {
        case .dailyChest: title = world.dailyStreak > 1 ? "DAILY CHEST! DAY \(world.dailyStreak)" : "DAILY CHEST!"
        case .reward: title = "PETDEX REWARD!"
        case .bag: title = "LOOT!"
        }
        playUI.showReveal(title: title, items: items,
                          atGridX: Float(loot.x) * SceneBuilder.worldScale)
        flushEvents()
    }

    /// Floating text over a pet, in play mode.
    private func toast(_ text: String, ink: UInt8 = PlayUI.white, pet name: String? = nil) {
        let x = name.flatMap { n in world.pets.first { $0.name == n } }.map { Float($0.x) * SceneBuilder.worldScale }
        playUI.toast(text, ink: ink, atGrid: x.map { SIMD2($0, 200) })
    }

    // MARK: Notifications

    private func handle(_ event: WorldEvent) {
        switch event {
        case .hatched(let name, _): toast("\(name) hatched!", ink: PlayUI.ink(.rare), pet: name)
        case .laidEgg(let parent): toast("\(parent) laid an egg!", ink: PlayUI.ink(.uncommon), pet: parent)
        case .died(let name, _): toast("\(name) died", ink: PlayUI.grey)
        case .monsterArrived(let kind): toast("a \(kind.rawValue) appears!", ink: Ink.make(.red, .light))
        case .monsterDefeated: toast("victory! loot dropped", ink: Ink.make(.gold, .light))
        case .monsterAte(let kind): toast("the \(kind.rawValue) ate your food", ink: Ink.make(.red, .light))
        case .revived(let name): toast("\(name) rose from the ashes!", ink: Ink.make(.gold, .light), pet: name)
        case .dailyChestArrived: toast("a daily chest appeared!", ink: Ink.make(.gold, .light))
        case .lootCollected(let items, _): toast("+\(items.count) items", ink: PlayUI.ink(.uncommon))
        case .needsCare(let name, let reason): toast(reason == .starving ? "\(name) is starving!" : "\(name) is sick",
                                                     ink: Ink.make(.red, .light), pet: name)
        case .levelUp(let name, let level): toast("level up! \(name) is lv \(level)", ink: Ink.make(.blue, .light), pet: name)
        case .discovered(let name, let entries):
            toast("new in dex: " + entries.prefix(2).joined(separator: ", ") + (entries.count > 2 ? " +\(entries.count - 2)" : ""),
                  ink: Ink.make(.purple, .light), pet: name)
        case .dexReward(let found): toast("\(found) found! a petdex chest dropped", ink: Ink.make(.purple, .light))
        case .weaponBroke(let name, let item): toast("\(name)'s \(item.title) broke!", ink: Ink.make(.red, .light), pet: name)
        }
        notify(event)
    }

    private func notify(_ event: WorldEvent) {
        switch event {
        case .hatched(let name, let mutations):
            let rarity = world.pets.first { $0.name == name }?.looks.rarity ?? .common
            var body = "Say hello to \(name)!"
            if rarity >= .rare { body += " A \(rarity.title.lowercased()) one \(rarity.stars)" }
            if !mutations.isEmpty { body += " Mutations: \(mutations.joined(separator: ", "))." }
            notify("An egg hatched", body)
        case .laidEgg(let parent):
            notify("A new egg", "\(parent) laid an egg.")
        case .died(let name, let cause):
            notify("\(name) has died", "Cause: \(cause.title). Their gravestone will turn into an egg.")
        case .monsterArrived(let kind):
            notify("A \(kind.rawValue) is coming!", "Press ⌥⌘P to help your pets fight.")
        case .needsCare(let name, let reason):
            notify(reason == .starving ? "\(name) is starving" : "\(name) is sick",
                   reason == .starving ? "Press ⌥⌘P, hold F and click the ground to feed." : "Try an Antidote or Tonic from the Bag.")
        case .revived(let name):
            notify("\(name) came back!", "Their Phoenix Feather burned up to save them.")
        case .dailyChestArrived:
            notify("A daily chest appeared", "Open it from the menu bar, or click it in play mode.")
        case .lootCollected(let items, let fromChest):
            let best = items.max { $0.rarity < $1.rarity }
            if fromChest || (best?.rarity ?? .common) >= .rare {
                notify(fromChest ? "Daily chest opened" : "Loot!", items.map { "\($0.title) (\($0.rarity.title))" }.joined(separator: ", "))
            }
        case .dexReward(let found):
            notify("Petdex milestone", "\(found) of \(DexEntry.total) found. A reward chest dropped.")
        case .weaponBroke(let name, let item):
            notify("\(item.title) broke", "\(name) needs a new weapon from the Bag.")
        case .monsterDefeated, .monsterAte, .levelUp, .discovered:
            break
        }
    }

    private func notify(_ title: String, _ body: String) {
        guard notificationsOn else { return }
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request) { _ in }
    }

    // MARK: Menu bar icon

    private func updateStatusIcon() {
        let alert = world.pets.contains { $0.hunger <= 0 || $0.sickRemaining > 0 } || world.monster?.phase == .attacking
        let treasure = !world.loot.isEmpty
        let state = alert ? 2 : treasure ? 1 : 0
        guard statusItem?.button?.tag != state + 1 else { return }
        statusItem?.button?.tag = state + 1
        statusItem?.button?.image = Self.pawImage(dot: alert ? .systemRed : treasure ? .systemYellow : nil)
    }

    /// A pixel paw, with an optional dot in the corner.
    private static func pawImage(dot: NSColor?) -> NSImage {
        let rows = [
            "..##..##..",
            "..##..##..",
            "##......##",
            "##..##..##",
            "...####...",
            "..######..",
            "..######..",
            "...####...",
        ]
        let image = NSImage(size: NSSize(width: 18, height: 18), flipped: true) { _ in
            NSColor.labelColor.setFill()
            let px: CGFloat = 1.6
            for (y, row) in rows.enumerated() {
                for (x, c) in row.enumerated() where c == "#" {
                    NSRect(x: 1 + CGFloat(x) * px, y: 3 + CGFloat(y) * px, width: px, height: px).fill()
                }
            }
            if let dot {
                dot.setFill()
                NSBezierPath(ovalIn: NSRect(x: 12, y: 0, width: 6, height: 6)).fill()
            }
            return true
        }
        image.isTemplate = dot == nil
        image.accessibilityDescription = "Pixel Pets"
        return image
    }

    // MARK: Menu

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        let play = action("Play Mode", key: "p") { [unowned self] in togglePlayMode() }
        play.keyEquivalentModifierMask = [.command, .option]
        play.state = playMode ? .on : .off
        menu.addItem(play)

        let chests = world.loot.filter { $0.kind != .bag }
        let bags = world.loot.filter { $0.kind == .bag }
        for chest in chests {
            menu.addItem(action(chest.kind == .reward ? "Open Petdex Chest" : "Open Daily Chest") { [unowned self] in
                if !playMode { setPlayMode(true) }
                openLoot(id: chest.id)
            })
        }
        if !bags.isEmpty {
            menu.addItem(action(bags.count == 1 ? "Pick Up Loot Bag" : "Pick Up \(bags.count) Loot Bags") { [unowned self] in
                for bag in bags { world.collectLoot(id: bag.id) }
                flushEvents()
            })
        }

        menu.addItem(.separator())
        menu.addItem(header("Pets"))
        for pet in world.pets { menu.addItem(petRow(pet)) }
        for egg in world.eggs { menu.addItem(eggRow(egg)) }
        for grave in world.graves { menu.addItem(info("Gravestone of \(grave.name)")) }

        menu.addItem(bagMenu())

        let graveyard = NSMenuItem(title: "Graveyard", action: nil, keyEquivalent: "")
        let gsub = NSMenu()
        if world.graveyard.isEmpty { gsub.addItem(info("No one yet")) }
        for entry in world.graveyard.prefix(50) {
            gsub.addItem(info("\(entry.name), lived \(Self.age(entry.age)), \(entry.cause.title)"))
        }
        graveyard.submenu = gsub
        menu.addItem(graveyard)

        menu.addItem(.separator())
        menu.addItem(backgroundMenu())
        let times = NSMenuItem(title: "Time of Day", action: nil, keyEquivalent: "")
        let tsub = NSMenu()
        for (name, hour) in Self.timesOfDay {
            let row = action(name) { [unowned self] in
                timeOfDayOverride = hour
                defaults.set(name, forKey: Key.timeOfDay)
                updateDayPhase()
            }
            row.state = timeOfDayOverride == hour ? .on : .off
            tsub.addItem(row)
        }
        times.submenu = tsub
        menu.addItem(times)
        let weather = NSMenuItem(title: "Weather", action: nil, keyEquivalent: "")
        let wsub = NSMenu()
        for choice in [nil] + Weather.allCases.map(Optional.some) {
            let row = action(choice?.title ?? "Live") { [unowned self] in
                world.weatherOverride = choice
                defaults.set(choice?.rawValue, forKey: Key.weather)
            }
            row.state = world.weatherOverride == choice ? .on : .off
            wsub.addItem(row)
        }
        weather.submenu = wsub
        menu.addItem(weather)
        menu.addItem(action(userPaused ? "Resume" : "Pause") { [unowned self] in
            userPaused.toggle()
            lastTick = CACurrentMediaTime()
            applyRunning()
        })
        let rate = NSMenuItem(title: "Frame Rate", action: nil, keyEquivalent: "")
        let rsub = NSMenu()
        for value in [15, 24, 30, 60] {
            let item = action("\(value) fps") { [unowned self] in
                defaults.set(value, forKey: Key.fps)
                for window in windows.values { window.petsView.preferredFramesPerSecond = value }
            }
            item.state = value == fps ? .on : .off
            rsub.addItem(item)
        }
        rate.submenu = rsub
        menu.addItem(rate)
        let notes = action("Notifications") { [unowned self] in defaults.set(!notificationsOn, forKey: Key.notifications) }
        notes.state = notificationsOn ? .on : .off
        let hideApps = defaults.object(forKey: "hideAppsInPlay") as? Bool ?? true
        let hide = action("Hide Other Apps in Play Mode") { [unowned self] in self.defaults.set(!hideApps, forKey: "hideAppsInPlay") }
        hide.state = hideApps ? .on : .off
        menu.addItem(notes)
        menu.addItem(hide)
        let login = action("Launch at Login") { [unowned self] in toggleLaunchAtLogin() }
        login.state = SMAppService.mainApp.status == .enabled ? .on : .off
        menu.addItem(login)

        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit Pixel Pets", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
    }

    private func petRow(_ pet: Pet) -> NSMenuItem {
        let rarity = pet.looks.rarity
        let row = NSMenuItem(title: "\(pet.name), \(Self.age(pet.age)), \(pet.feeling.title)", action: nil, keyEquivalent: "")
        let sub = NSMenu()
        sub.addItem(info("\(rarity.stars) \(rarity.title) · \(pet.looks.summary)"))
        var lineage = "Generation \(pet.generation)"
        if let parent = pet.parentName { lineage += ", child of \(parent)" }
        sub.addItem(info(lineage))
        if !pet.mutations.isEmpty { sub.addItem(info("Mutations: \(pet.mutations.joined(separator: ", "))")) }
        sub.addItem(info(pet.traits.names.joined(separator: " · ")))
        sub.addItem(.separator())
        for (label, value) in [("Health", pet.health), ("Hunger", pet.hunger), ("Happiness", pet.happiness), ("Energy", pet.energy)] {
            sub.addItem(info("\(label) \(Int(value.rounded()))%"))
        }
        sub.addItem(info("Wins \(pet.wins) · \(pet.stage.rawValue.capitalized)"))
        for buff in pet.buffs {
            sub.addItem(info("\(buff.kind.rawValue.capitalized) buff, \(Int(ceil(buff.remaining / 60))) min left"))
        }

        sub.addItem(.separator())
        for (category, equipped) in [(ItemCategory.weapon, pet.weapon), (.relic, pet.relic)] {
            let label = category == .weapon ? "Weapon" : "Relic"
            if let equipped {
                let item = NSMenuItem(title: "\(label): \(equipped.title) (\(equipped.blurb))", action: nil, keyEquivalent: "")
                let unequip = NSMenu()
                unequip.addItem(action("Put Back in Bag") { [unowned self] in world.unequip(category, fromPet: pet.id) })
                item.submenu = unequip
                sub.addItem(item)
            } else {
                sub.addItem(info("\(label): none"))
            }
        }

        let give = NSMenuItem(title: "Give from Bag", action: nil, keyEquivalent: "")
        let giveSub = NSMenu()
        for item in bagItems() where !item.targetsEgg {
            giveSub.addItem(action(itemTitle(item)) { [unowned self] in
                if item.category == .potion { world.use(item, onPet: pet.id) } else { world.equip(item, onPet: pet.id) }
            })
        }
        if giveSub.items.isEmpty { giveSub.addItem(info("The bag is empty")) }
        give.submenu = giveSub
        sub.addItem(give)

        row.submenu = sub
        return row
    }

    private func eggRow(_ egg: Egg) -> NSMenuItem {
        let minutes = Int(ceil(egg.remaining / 60))
        let row = NSMenuItem(title: "Egg, hatches in \(minutes) min\(egg.mutated ? " ✨" : "")", action: nil, keyEquivalent: "")
        let sub = NSMenu()
        if let parent = egg.genes.parentName {
            sub.addItem(info("Laid by \(parent), generation \(egg.genes.generation)"))
        } else {
            sub.addItem(info("A wild egg"))
        }
        for item in bagItems() where item.targetsEgg {
            sub.addItem(action("Use \(itemTitle(item))") { [unowned self] in world.use(item, onEgg: egg.id) })
        }
        row.submenu = sub
        return row
    }

    private func bagMenu() -> NSMenuItem {
        let total = world.inventory.values.reduce(0, +)
        let bag = NSMenuItem(title: total == 0 ? "Bag" : "Bag (\(total))", action: nil, keyEquivalent: "")
        let sub = NSMenu()
        for category in ItemCategory.allCases {
            let items = bagItems().filter { $0.category == category }
            guard !items.isEmpty else { continue }
            if !sub.items.isEmpty { sub.addItem(.separator()) }
            sub.addItem(header(category.title))
            for item in items {
                let row = NSMenuItem(title: "\(itemTitle(item)): \(item.blurb)", action: nil, keyEquivalent: "")
                let targets = NSMenu()
                if item.targetsEgg {
                    for (i, egg) in world.eggs.enumerated() {
                        targets.addItem(action("Use on Egg \(i + 1)") { [unowned self] in world.use(item, onEgg: egg.id) })
                    }
                } else {
                    for pet in world.pets {
                        let verb = item.category == .potion ? "Give to" : "Equip on"
                        targets.addItem(action("\(verb) \(pet.name)") { [unowned self] in
                            if item.category == .potion { world.use(item, onPet: pet.id) } else { world.equip(item, onPet: pet.id) }
                        })
                    }
                }
                if targets.items.isEmpty { targets.addItem(info(item.targetsEgg ? "No eggs right now" : "No pets right now")) }
                row.submenu = targets
                sub.addItem(row)
            }
        }
        if sub.items.isEmpty { sub.addItem(info("Empty. Win fights and open daily chests to find items.")) }
        bag.submenu = sub
        return bag
    }

    /// Items in the bag, rarest first.
    private func bagItems() -> [Item] {
        world.inventory.keys.sorted { $0.rarity != $1.rarity ? $0.rarity > $1.rarity : $0.title < $1.title }
    }

    private func itemTitle(_ item: Item) -> String {
        let n = world.count(of: item)
        return "\(item.title)\(n > 1 ? " ×\(n)" : "") \(item.rarity.stars)"
    }

    /// Hands any events from a menu action straight to notifications.
    private func flushEvents() {
        let events = world.events
        world.events.removeAll()
        for event in events { handle(event) }
        updateStatusIcon()
    }

    private func action(_ title: String, key: String = "", _ run: @escaping @MainActor () -> Void) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: #selector(performMenuAction(_:)), keyEquivalent: key)
        item.target = self
        item.representedObject = MenuAction(run)
        return item
    }

    @objc private func performMenuAction(_ sender: NSMenuItem) {
        (sender.representedObject as? MenuAction)?.run()
    }

    private func info(_ title: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        return item
    }

    private func header(_ title: String) -> NSMenuItem {
        let item = info(title)
        item.attributedTitle = NSAttributedString(string: title, attributes: [
            .font: NSFont.boldSystemFont(ofSize: NSFont.smallSystemFontSize),
            .foregroundColor: NSColor.secondaryLabelColor,
        ])
        return item
    }

    static func age(_ seconds: Double) -> String {
        if seconds < 3600 { return "\(Int(seconds / 60)) min" }
        if seconds < 48 * 3600 { return "\(Int(seconds / 3600)) h" }
        return "\(Int(seconds / 86_400)) days"
    }

    private func toggleLaunchAtLogin() {
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            showAlert("Couldn't change Launch at Login",
                      info: "\(error.localizedDescription)\n\nMove Pixel Pets to Applications and try again, or add it in System Settings → General → Login Items.")
        }
    }

    private func showAlert(_ title: String, info: String) {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = info
        alert.runModal()
    }
}
