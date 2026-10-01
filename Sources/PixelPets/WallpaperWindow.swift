import AppKit

/// A borderless window that sits at desktop level on one display, under the icons and every
/// normal window. In play mode the main display's window rises above the desktop icons and
/// widgets (still below normal windows) and takes clicks and keys.
@MainActor
final class WallpaperWindow: NSWindow {
    private(set) var petsView: PetsView!
    private(set) var playMode = false

    override var canBecomeKey: Bool { playMode }
    override var canBecomeMain: Bool { false }

    static func make(screen: NSScreen, app: AppDelegate, renderer: PetsRenderer) -> WallpaperWindow {
        let window = WallpaperWindow(contentRect: screen.frame, styleMask: .borderless,
                                     backing: .buffered, defer: false, screen: screen)
        window.setFrame(screen.frame, display: false)
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenNone]
        window.hasShadow = false
        window.isOpaque = true
        window.backgroundColor = .black
        window.isReleasedWhenClosed = false
        window.acceptsMouseMovedEvents = true
        let view = PetsView(frame: NSRect(origin: .zero, size: screen.frame.size), app: app, renderer: renderer)
        view.autoresizingMask = [.width, .height]
        window.petsView = view
        window.contentView = view
        window.setPlayMode(false)
        return window
    }

    override func resignKey() {
        super.resignKey()
        petsView?.resetKeys()
    }

    func setPlayMode(_ on: Bool) {
        playMode = on
        petsView?.resetKeys()
        if on {
            // Just below normal windows: above the desktop icons and widgets (macOS 14+ puts
            // widgets above the icon level), but under every app window.
            level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.normalWindow)) - 1)
            ignoresMouseEvents = false
            makeKeyAndOrderFront(nil)
            makeFirstResponder(petsView)
        } else {
            level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopWindow)))
            ignoresMouseEvents = true
            if isKeyWindow { resignKey() }
            orderFront(nil)
        }
    }
}
