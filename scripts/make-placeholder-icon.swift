// Draws the placeholder app icon. Run: swift scripts/make-placeholder-icon.swift

import AppKit

let size: CGFloat = 1024
let image = NSImage(size: NSSize(width: size, height: size))
image.lockFocus()
let ctx = NSGraphicsContext.current!.cgContext

// Background tile on the macOS icon grid.
let tile = CGRect(x: 100, y: 100, width: 824, height: 824)
let tilePath = CGPath(roundedRect: tile, cornerWidth: 185, cornerHeight: 185, transform: nil)
ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -12), blur: 28, color: NSColor.black.withAlphaComponent(0.35).cgColor)
ctx.addPath(tilePath); ctx.setFillColor(NSColor(red: 0.42, green: 0.09, blue: 0.11, alpha: 1).cgColor); ctx.fillPath()
ctx.restoreGState()
ctx.saveGState()
ctx.addPath(tilePath); ctx.clip()
let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: [
    NSColor(red: 0.62, green: 0.15, blue: 0.16, alpha: 1).cgColor,
    NSColor(red: 0.36, green: 0.07, blue: 0.10, alpha: 1).cgColor] as CFArray, locations: [0, 1])!
ctx.drawLinearGradient(gradient, start: CGPoint(x: 512, y: 924), end: CGPoint(x: 512, y: 100), options: [])

// The character sheet, slightly turned.
ctx.translateBy(x: 470, y: 512)
ctx.rotate(by: 0.07)
let sheet = CGRect(x: -230, y: -300, width: 460, height: 600)
ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -10), blur: 24, color: NSColor.black.withAlphaComponent(0.4).cgColor)
ctx.addPath(CGPath(roundedRect: sheet, cornerWidth: 22, cornerHeight: 22, transform: nil))
ctx.setFillColor(NSColor(red: 0.97, green: 0.93, blue: 0.83, alpha: 1).cgColor)
ctx.fillPath()
ctx.restoreGState()
let ink = NSColor(red: 0.30, green: 0.22, blue: 0.16, alpha: 1).cgColor
// Name bar
ctx.setFillColor(ink); ctx.fill(CGRect(x: -180, y: 205, width: 250, height: 30))
// Ability boxes
ctx.setStrokeColor(ink); ctx.setLineWidth(9)
for row in 0..<3 { for col in 0..<2 {
    ctx.stroke(CGRect(x: -180 + CGFloat(col) * 120, y: 95 - CGFloat(row) * 100, width: 92, height: 72))
}}
// Ruled lines
ctx.setLineWidth(8)
for i in 0..<4 {
    let y = 120 - CGFloat(i) * 70
    ctx.move(to: CGPoint(x: 70, y: y)); ctx.addLine(to: CGPoint(x: 180, y: y))
}
for i in 0..<2 {
    let y = -215 - CGFloat(i) * 45
    ctx.move(to: CGPoint(x: -180, y: y)); ctx.addLine(to: CGPoint(x: 60, y: y))
}
ctx.strokePath()
ctx.restoreGState()

// A d20, gold, overlapping the corner.
let center = CGPoint(x: 700, y: 330), r: CGFloat = 165
var hex: [CGPoint] = (0..<6).map { i in
    let a = CGFloat.pi / 2 + CGFloat(i) * .pi / 3
    return CGPoint(x: center.x + r * cos(a), y: center.y + r * sin(a))
}
ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -8), blur: 20, color: NSColor.black.withAlphaComponent(0.45).cgColor)
ctx.addLines(between: hex); ctx.closePath()
ctx.setFillColor(NSColor(red: 0.93, green: 0.72, blue: 0.27, alpha: 1).cgColor); ctx.fillPath()
ctx.restoreGState()
let inner: [CGPoint] = (0..<3).map { i in
    let a = CGFloat.pi / 2 + CGFloat(i) * 2 * .pi / 3
    return CGPoint(x: center.x + r * 0.55 * cos(a), y: center.y + r * 0.55 * sin(a) - 8)
}
ctx.setStrokeColor(NSColor(red: 0.55, green: 0.36, blue: 0.08, alpha: 1).cgColor)
ctx.setLineWidth(9); ctx.setLineJoin(.round)
ctx.addLines(between: inner); ctx.closePath(); ctx.strokePath()
for (i, p) in inner.enumerated() {
    ctx.move(to: p); ctx.addLine(to: hex[i * 2])
    ctx.move(to: p); ctx.addLine(to: hex[(i * 2 + 1) % 6])
    ctx.move(to: p); ctx.addLine(to: hex[(i * 2 + 5) % 6])
}
ctx.strokePath()
ctx.addLines(between: hex); ctx.closePath(); ctx.strokePath()

image.unlockFocus()
let rep = NSBitmapImageRep(data: image.tiffRepresentation!)!
// Writes a 2048 px image on Retina Macs; scale it with `sips -z 1024 1024`.
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: "icon_1024.png"))
