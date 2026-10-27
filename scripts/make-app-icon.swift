// Builds the app icon from flat, square, full-bleed artwork (1024×1024, no rounded corners).
// Run: swift scripts/make-app-icon.swift docs/icons/3d6.png

import AppKit

let art = NSImage(contentsOfFile: CommandLine.arguments[1])!.cgImage(forProposedRect: nil, context: nil, hints: nil)!
let iconSet = "App/Assets.xcassets/AppIcon.appiconset"

// Draws the art on the macOS icon grid: an 824pt rounded tile, centered, with a drop shadow.
func render(_ px: Int) -> Data {
    let ctx = CGContext(data: nil, width: px, height: px, bitsPerComponent: 8, bytesPerRow: 0,
                        space: CGColorSpace(name: CGColorSpace.sRGB)!,
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.scaleBy(x: CGFloat(px) / 1024, y: CGFloat(px) / 1024)
    ctx.interpolationQuality = .high

    let tile = CGRect(x: 100, y: 100, width: 824, height: 824)
    let tilePath = CGPath(roundedRect: tile, cornerWidth: 185, cornerHeight: 185, transform: nil)
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -12), blur: 28, color: NSColor.black.withAlphaComponent(0.35).cgColor)
    ctx.addPath(tilePath); ctx.setFillColor(NSColor.gray.cgColor); ctx.fillPath()
    ctx.restoreGState()
    ctx.addPath(tilePath); ctx.clip()
    ctx.draw(art, in: tile)

    return NSBitmapImageRep(cgImage: ctx.makeImage()!).representation(using: .png, properties: [:])!
}

for size in [16, 32, 128, 256, 512] {
    try! render(size).write(to: URL(fileURLWithPath: "\(iconSet)/icon_\(size)x\(size).png"))
    try! render(size * 2).write(to: URL(fileURLWithPath: "\(iconSet)/icon_\(size)x\(size)@2x.png"))
}
