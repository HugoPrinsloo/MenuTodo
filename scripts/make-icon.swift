// Renders the MenuTodo app icon: a neutral paper square with an ink checkbox-and-checkmark glyph.
// Run: swift scripts/make-icon.swift
import AppKit

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let outDir = root.appendingPathComponent("MenuTodo/Assets.xcassets/AppIcon.appiconset")
let canvas: CGFloat = 1024
let paper = NSColor(srgbRed: 0xF7 / 255.0, green: 0xF7 / 255.0, blue: 0xF5 / 255.0, alpha: 1)
let ink = NSColor(srgbRed: 0x1D / 255.0, green: 0x1D / 255.0, blue: 0x1F / 255.0, alpha: 1)

let symbolConfig = NSImage.SymbolConfiguration(pointSize: 640, weight: .bold)
guard let glyph = NSImage(systemSymbolName: "checkmark.square", accessibilityDescription: nil)?
    .withSymbolConfiguration(symbolConfig),
    let glyphCGImage = glyph.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
    fatalError("could not load checkmark.square symbol")
}

func render(_ px: Int) -> Data {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px, bitsPerSample: 8, samplesPerPixel: 4,
                               hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    let gc = NSGraphicsContext(bitmapImageRep: rep)!
    NSGraphicsContext.saveGraphicsState(); NSGraphicsContext.current = gc
    let ctx = gc.cgContext
    ctx.clear(CGRect(x: 0, y: 0, width: px, height: px))
    ctx.interpolationQuality = .high
    let k = CGFloat(px) / canvas
    ctx.scaleBy(x: k, y: k)
    // macOS icon grid: 824pt squircle on a 1024pt canvas (~10% margin all round).
    let iconRect = CGRect(x: 100, y: 100, width: 824, height: 824)
    let shape = CGPath(roundedRect: iconRect, cornerWidth: 185, cornerHeight: 185, transform: nil)
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -12), blur: 28, color: CGColor(gray: 0, alpha: 0.35))
    ctx.addPath(shape); ctx.setFillColor(paper.cgColor); ctx.fillPath()
    ctx.restoreGState()
    ctx.addPath(shape); ctx.clip()

    // Ink checkbox-with-checkmark glyph, centered and tinted via an alpha mask.
    let glyphSize = glyph.size
    let maxGlyph: CGFloat = 620
    let fit = min(maxGlyph / glyphSize.width, maxGlyph / glyphSize.height)
    let drawSize = CGSize(width: glyphSize.width * fit, height: glyphSize.height * fit)
    let glyphRect = CGRect(x: iconRect.midX - drawSize.width / 2, y: iconRect.midY - drawSize.height / 2,
                            width: drawSize.width, height: drawSize.height)
    ctx.saveGState()
    ctx.clip(to: glyphRect, mask: glyphCGImage)
    ctx.setFillColor(ink.cgColor)
    ctx.fill(glyphRect)
    ctx.restoreGState()

    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

try? FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)
let sizes: [(Int, Int)] = [(16, 1), (16, 2), (32, 1), (32, 2), (128, 1), (128, 2), (256, 1), (256, 2), (512, 1), (512, 2)]
var images: [[String: String]] = []
for (pt, scale) in sizes {
    let name = "icon_\(pt)x\(pt)@\(scale)x.png"
    try! render(pt * scale).write(to: outDir.appendingPathComponent(name))
    images.append(["idiom": "mac", "size": "\(pt)x\(pt)", "scale": "\(scale)x", "filename": name])
}
let contents: [String: Any] = ["images": images, "info": ["author": "xcode", "version": 1]]
try! JSONSerialization.data(withJSONObject: contents, options: [.prettyPrinted, .sortedKeys]).write(to: outDir.appendingPathComponent("Contents.json"))
try! FileManager.default.createDirectory(at: root.appendingPathComponent("docs"), withIntermediateDirectories: true)
try! render(512).write(to: root.appendingPathComponent("docs/icon-preview.png"))
print("wrote \(images.count) icons")
