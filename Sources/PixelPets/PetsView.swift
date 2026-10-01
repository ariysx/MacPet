import AppKit
import Metal
import MetalKit
import QuartzCore
import simd

/// Diagnostics: run PixelPets.app/Contents/MacOS/PixelPets from Terminal to see these.
func petsLog(_ message: String) {
    let stamp = String(format: "%.3f", CACurrentMediaTime())
    FileHandle.standardError.write("\(stamp) \(message)\n".data(using: .utf8)!)
}

// MARK: - Renderer (shared by every display)

@MainActor
final class PetsRenderer {
    let device: MTLDevice
    private let queue: MTLCommandQueue
    private let pipeline: MTLRenderPipelineState
    private let atlasTexture: MTLTexture
    /// Bound when there is no background image, so texture(1) is always valid.
    private let blank: MTLTexture
    private var uiTexture: MTLTexture?
    var atlas: SpriteAtlas

    init?() {
        guard let device = MTLCreateSystemDefaultDevice(), let queue = device.makeCommandQueue() else {
            petsLog("no Metal device")
            return nil
        }
        guard let url = Bundle.main.url(forResource: "Shaders", withExtension: "metal"),
              let source = try? String(contentsOf: url, encoding: .utf8) else {
            petsLog("Shaders.metal is missing from the app bundle")
            return nil
        }
        do {
            let library = try device.makeLibrary(source: source, options: nil)
            let descriptor = MTLRenderPipelineDescriptor()
            descriptor.vertexFunction = library.makeFunction(name: "petsVertex")
            descriptor.fragmentFunction = library.makeFunction(name: "petsFragment")
            descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
            pipeline = try device.makeRenderPipelineState(descriptor: descriptor)
        } catch {
            petsLog("shader did not compile: \(error)")
            return nil
        }

        atlas = SpriteAtlas.build()
        let td = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .r8Uint, width: atlas.width,
                                                          height: atlas.height, mipmapped: false)
        td.usage = .shaderRead
        guard let texture = device.makeTexture(descriptor: td) else {
            petsLog("could not make the atlas texture")
            return nil
        }
        atlasTexture = texture
        let bd = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba8Unorm, width: 1, height: 1, mipmapped: false)
        bd.usage = .shaderRead
        guard let blank = device.makeTexture(descriptor: bd) else { return nil }
        self.blank = blank
        self.device = device
        self.queue = queue
        uploadAtlas()
        petsLog("renderer ready on \(device.name), atlas \(atlas.width)x\(atlas.height)")
    }

    func uploadAtlas() {
        let width = atlas.width, height = atlas.height
        atlas.pixels.withUnsafeBytes { bytes in
            atlasTexture.replace(region: MTLRegionMake2D(0, 0, width, height), mipmapLevel: 0,
                                 withBytes: bytes.baseAddress!, bytesPerRow: width)
        }
    }

    struct UIUniforms {
        var primary: SIMD4<Float> = .zero
        var secondary: SIMD4<Float> = .zero
        var enabled: UInt32 = 0
        var pad: SIMD3<UInt32> = .zero
    }

    /// Uploads the play-mode UI canvas (one byte per pixel).
    func uploadUI(_ canvas: UICanvas) {
        if uiTexture?.width != canvas.width || uiTexture?.height != canvas.height {
            let d = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .r8Uint, width: canvas.width, height: canvas.height,
                                                             mipmapped: false)
            d.usage = .shaderRead
            uiTexture = device.makeTexture(descriptor: d)
        }
        canvas.pixels.withUnsafeBytes { bytes in
            uiTexture?.replace(region: MTLRegionMake2D(0, 0, canvas.width, canvas.height), mipmapLevel: 0,
                               withBytes: bytes.baseAddress!, bytesPerRow: canvas.width)
        }
    }

    func draw(in view: MTKView, uniforms: SceneUniforms, items: [SceneItem], background: MTLTexture?,
              ui: UIUniforms = UIUniforms()) {
        guard let pass = view.currentRenderPassDescriptor,
              let drawable = view.currentDrawable,
              let commands = queue.makeCommandBuffer(),
              let encoder = commands.makeRenderCommandEncoder(descriptor: pass) else { return }

        var u = uniforms
        // Always bind a full array so the shader never reads past the end.
        var padded = Array(items.prefix(SceneItem.maxCount))
        padded += Array(repeating: SceneItem(), count: SceneItem.maxCount - padded.count)

        encoder.setRenderPipelineState(pipeline)
        encoder.setFragmentBytes(&u, length: MemoryLayout<SceneUniforms>.stride, index: 0)
        padded.withUnsafeBytes { bytes in
            encoder.setFragmentBytes(bytes.baseAddress!, length: bytes.count, index: 1)
        }
        encoder.setFragmentTexture(atlasTexture, index: 0)
        encoder.setFragmentTexture(background ?? blank, index: 1)
        var uiu = ui
        if uiTexture == nil { uiu.enabled = 0 }
        encoder.setFragmentTexture(uiTexture ?? atlasTexture, index: 2)
        encoder.setFragmentBytes(&uiu, length: MemoryLayout<UIUniforms>.stride, index: 2)
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
        encoder.endEncoding()
        commands.present(drawable)
        commands.commit()
    }
}

// MARK: - The view

/// One per display. The drawable is exactly the virtual grid (320 wide), and the layer scales
/// it up with nearest-neighbour filtering, so every pixel is a crisp block.
@MainActor
final class PetsView: MTKView {
    static let gridWidth = CGFloat(SceneBuilder.gridWidth)

    private unowned let app: AppDelegate
    private let renderer: PetsRenderer
    /// The main display holds the pets; the others show the landscape only.
    var isMain = false
    private var lastFrame = SceneFrame()

    private struct Press {
        var target: HitBox.Target
        var box: HitBox
        var start: SIMD2<Float>
        var pickedUp = false
        var lastX: Float
        var lastDirection = 0
        var turns: [CFTimeInterval] = []
        var rubbed = false
    }
    private var press: Press?
    private var feedKeyDown = false

    init(frame: CGRect, app: AppDelegate, renderer: PetsRenderer) {
        self.app = app
        self.renderer = renderer
        super.init(frame: frame, device: renderer.device)
        colorPixelFormat = .bgra8Unorm
        colorspace = CGColorSpace(name: CGColorSpace.sRGB)
        framebufferOnly = true
        autoResizeDrawable = false
        enableSetNeedsDisplay = false
        clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)
        layer?.magnificationFilter = .nearest
        updateDrawableSize()
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    // MARK: Size

    private func updateDrawableSize() {
        guard bounds.width > 0, bounds.height > 0 else { return }
        let height = max(100, (Self.gridWidth * bounds.height / bounds.width).rounded())
        let size = CGSize(width: Self.gridWidth, height: height)
        if drawableSize != size { drawableSize = size }
        layer?.magnificationFilter = .nearest
    }

    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        updateDrawableSize()
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        updateDrawableSize()
    }

    /// Matches the shader's walking line (22% up), on the landscape's 2-pixel grid.
    var groundY: Float {
        let k = Float(Self.gridWidth) / 480
        return floor(Float(drawableSize.height) * 0.22 / k) * k
    }

    // MARK: Drawing

    override func draw(_ dirtyRect: NSRect) {
        let grid = SIMD2<Float>(Float(drawableSize.width), Float(drawableSize.height))
        guard grid.x > 0, grid.y > 0 else { return }
        var items: [SceneItem] = []
        if isMain {
            lastFrame = SceneBuilder.build(world: app.world, groundY: groundY, time: app.renderTime,
                                           playMode: app.playMode, atlas: renderer.atlas, regions: app.regions)
            items = lastFrame.items
        }
        let uniforms = SceneUniforms(resolution: grid,
                                     grid: grid,
                                     time: Float(app.renderTime.truncatingRemainder(dividingBy: 6 * 3600)),
                                     dayPhase: app.dayPhase,
                                     rain: Float(app.world.rain),
                                     playMode: app.playMode ? 1 : 0,
                                     itemCount: UInt32(items.count),
                                     background: app.backgroundInfo)
        var ui = PetsRenderer.UIUniforms()
        if isMain && app.playMode {
            let playUI = app.playUI
            playUI.resize(gridWidth: Int(grid.x), gridHeight: Int(grid.y))
            if let colours = playUI.render(world: app.world, hits: lastFrame.hits, atlas: renderer.atlas,
                                           regions: app.regions, time: app.renderTime, groundY: groundY) {
                ui.primary = PetPalette.rgba(colours.primary)
                ui.secondary = PetPalette.rgba(colours.secondary)
            }
            renderer.uploadUI(playUI.canvas)
            ui.enabled = 1
        }
        renderer.draw(in: self, uniforms: uniforms, items: items, background: app.backgroundTexture, ui: ui)
    }

    // MARK: Input (play mode, main display only)

    override var acceptsFirstResponder: Bool { true }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        for area in trackingAreas { removeTrackingArea(area) }
        addTrackingArea(NSTrackingArea(rect: bounds, options: [.mouseMoved, .activeAlways, .inVisibleRect],
                                       owner: self, userInfo: nil))
    }

    private func gridPoint(_ event: NSEvent) -> SIMD2<Float> {
        let p = convert(event.locationInWindow, from: nil)
        return SIMD2(Float(p.x / max(bounds.width, 1)) * Float(drawableSize.width),
                     Float(p.y / max(bounds.height, 1)) * Float(drawableSize.height))
    }

    /// Grid pixels to simulation units.
    private func worldX(_ p: SIMD2<Float>) -> Double { Double(p.x / SceneBuilder.worldScale) }

    /// Height above the ground, in simulation units, for a pet hanging from the pointer.
    private func heldHeight(_ p: SIMD2<Float>) -> Double {
        Double(max(0, p.y - groundY - 30) / SceneBuilder.worldScale)
    }

    override func keyDown(with event: NSEvent) {
        if event.charactersIgnoringModifiers?.lowercased() == "f" {
            feedKeyDown = true
        } else if event.keyCode == 53 { // Escape
            app.setPlayMode(false)
        }
        app.noteInput()
    }

    override func keyUp(with event: NSEvent) {
        if event.charactersIgnoringModifiers?.lowercased() == "f" { feedKeyDown = false }
    }

    override func mouseMoved(with event: NSEvent) {
        app.noteInput()
        let p = gridPoint(event)
        app.playUI.gridPointer = p
        app.playUI.pointer = app.playUI.toCanvas(p)
    }

    override func rightMouseDown(with event: NSEvent) {
        guard isMain, app.playMode else { return }
        app.noteInput()
        app.playUI.rightClick(grid: gridPoint(event), hits: lastFrame.hits)
    }

    override func mouseDown(with event: NSEvent) {
        guard isMain, app.playMode else { return }
        app.noteInput()
        let p = gridPoint(event)
        app.playUI.gridPointer = p
        if app.playUI.mouseDown(at: app.playUI.toCanvas(p), world: &app.world) { return }
        if event.modifierFlags.contains(.control) {
            app.playUI.rightClick(grid: p, hits: lastFrame.hits)
            return
        }
        if feedKeyDown || event.modifierFlags.contains(.option) {
            app.world.dropPellet(x: worldX(p))
            return
        }
        guard let hit = lastFrame.hits.first(where: { $0.contains(p) }) else { return }
        switch hit.target {
        case .monster:
            app.world.playerHitMonster()
        case .egg(let id):
            app.world.petEgg(id: id)
        case .loot(let id):
            app.openLoot(id: id)
        case .pet:
            press = Press(target: hit.target, box: hit, start: p, lastX: p.x)
        }
    }

    override func mouseDragged(with event: NSEvent) {
        guard isMain, app.playMode else { return }
        let p = gridPoint(event)
        app.playUI.gridPointer = p
        if app.playUI.mouseDragged(at: app.playUI.toCanvas(p)) { app.noteInput(); return }
        guard var pr = press, case .pet(let id) = pr.target else { return }
        app.noteInput()
        if pr.pickedUp {
            app.world.moveHeld(id: id, x: worldX(p), height: heldHeight(p))
            press = pr
            return
        }
        // Wiggling side to side over the pet is a rub; leaving it or lifting up picks it up.
        let movedUp = p.y - pr.start.y > 6
        let distance = simd_length(p - pr.start)
        if (movedUp || !pr.box.contains(p, margin: 4)) && distance > 6 {
            pr.pickedUp = true
            app.world.pickUp(id: id)
            app.world.moveHeld(id: id, x: worldX(p), height: heldHeight(p))
        } else {
            let dx = p.x - pr.lastX
            if abs(dx) >= 2 {
                let direction = dx > 0 ? 1 : -1
                let now = CACurrentMediaTime()
                if pr.lastDirection != 0 && direction != pr.lastDirection { pr.turns.append(now) }
                pr.lastDirection = direction
                pr.lastX = p.x
                pr.turns.removeAll { now - $0 > 1 }
                if pr.turns.count >= 3 {
                    app.world.petPet(id: id, times: 3)
                    pr.turns.removeAll()
                    pr.rubbed = true
                }
            }
        }
        press = pr
    }

    override func mouseUp(with event: NSEvent) {
        defer { press = nil }
        guard isMain, app.playMode else { return }
        let p = gridPoint(event)
        if app.playUI.mouseUp(at: app.playUI.toCanvas(p), grid: p, hits: lastFrame.hits, world: &app.world) { return }
        guard let pr = press, case .pet(let id) = pr.target else { return }
        if pr.pickedUp {
            app.world.throwHeld(id: id)
        } else if !pr.rubbed {
            app.world.petPet(id: id)
        }
    }
}
