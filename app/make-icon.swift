// Draws the 1024x1024 app icon: a blue rounded square with a white Dock symbol.
// Usage: make-icon <output.png>
import AppKit

let output = URL(fileURLWithPath: CommandLine.arguments[1])
let side = 1024
let canvas = NSRect(x: 0, y: 0, width: side, height: side)

let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil, pixelsWide: side, pixelsHigh: side, bitsPerSample: 8,
    samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
    bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

// Apple's icon grid leaves a 100 px margin around an 824 px rounded square.
let tile = NSBezierPath(roundedRect: canvas.insetBy(dx: 100, dy: 100), xRadius: 185, yRadius: 185)
NSGradient(colors: [
    NSColor(srgbRed: 0.33, green: 0.62, blue: 1.00, alpha: 1),
    NSColor(srgbRed: 0.09, green: 0.33, blue: 0.86, alpha: 1),
])!.draw(in: tile, angle: -90)

let config = NSImage.SymbolConfiguration(pointSize: 400, weight: .medium)
if let symbol = NSImage(systemSymbolName: "dock.rectangle", accessibilityDescription: nil)?
    .withSymbolConfiguration(config)
{
    let size = symbol.size
    let white = NSImage(size: size, flipped: false) { rect in
        symbol.draw(in: rect)
        NSColor.white.set()
        rect.fill(using: .sourceAtop)
        return true
    }
    white.draw(in: NSRect(
        x: canvas.midX - size.width / 2, y: canvas.midY - size.height / 2,
        width: size.width, height: size.height))
}

NSGraphicsContext.restoreGraphicsState()
try rep.representation(using: .png, properties: [:])!.write(to: output)
