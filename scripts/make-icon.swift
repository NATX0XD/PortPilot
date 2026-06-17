import AppKit

// Renders a 1024x1024 app icon: iOS-style squircle, blue→purple gradient,
// glossy top highlight, white radiowaves glyph. Output path = argv[1].
let outPath = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "icon_1024.png"
let size: CGFloat = 1024

let image = NSImage(size: NSSize(width: size, height: size))
image.lockFocus()
let ctx = NSGraphicsContext.current!.cgContext

// Squircle clip (Apple-ish continuous corner ~ 0.2237 * size).
let rect = NSRect(x: 0, y: 0, width: size, height: size)
let radius: CGFloat = 228
NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).addClip()

// Diagonal blue → indigo → purple gradient.
let bg = CGGradient(
    colorsSpace: CGColorSpaceCreateDeviceRGB(),
    colors: [
        NSColor(srgbRed: 0.04, green: 0.52, blue: 1.00, alpha: 1).cgColor,
        NSColor(srgbRed: 0.40, green: 0.36, blue: 0.96, alpha: 1).cgColor,
        NSColor(srgbRed: 0.70, green: 0.35, blue: 0.96, alpha: 1).cgColor,
    ] as CFArray,
    locations: [0.0, 0.55, 1.0])!
ctx.drawLinearGradient(bg, start: CGPoint(x: 0, y: size), end: CGPoint(x: size, y: 0), options: [])

// Glossy top-left highlight for a glassy sheen.
let sheen = CGGradient(
    colorsSpace: CGColorSpaceCreateDeviceRGB(),
    colors: [NSColor(white: 1, alpha: 0.38).cgColor, NSColor(white: 1, alpha: 0).cgColor] as CFArray,
    locations: [0, 1])!
ctx.drawRadialGradient(sheen,
                       startCenter: CGPoint(x: size * 0.30, y: size * 0.80), startRadius: 0,
                       endCenter: CGPoint(x: size * 0.30, y: size * 0.80), endRadius: size * 0.65,
                       options: [])

// White radiowaves glyph, centered, tinted via sourceAtop.
let cfg = NSImage.SymbolConfiguration(pointSize: 540, weight: .semibold)
if let base = NSImage(systemSymbolName: "dot.radiowaves.left.and.right",
                      accessibilityDescription: nil)?.withSymbolConfiguration(cfg) {
    let glyph = NSImage(size: base.size)
    glyph.lockFocus()
    base.draw(in: NSRect(origin: .zero, size: base.size))
    NSColor.white.set()
    NSRect(origin: .zero, size: base.size).fill(using: .sourceAtop)
    glyph.unlockFocus()

    let gw = glyph.size.width, gh = glyph.size.height
    NSGraphicsContext.current!.cgContext.setShadow(
        offset: CGSize(width: 0, height: -10), blur: 24,
        color: NSColor(white: 0, alpha: 0.18).cgColor)
    glyph.draw(in: NSRect(x: (size - gw) / 2, y: (size - gh) / 2 - 8, width: gw, height: gh))
}

image.unlockFocus()

guard let tiff = image.tiffRepresentation,
      let bmp = NSBitmapImageRep(data: tiff),
      let png = bmp.representation(using: .png, properties: [:]) else {
    FileHandle.standardError.write("failed to render icon\n".data(using: .utf8)!)
    exit(1)
}
try! png.write(to: URL(fileURLWithPath: outPath))
print("wrote \(outPath)")
