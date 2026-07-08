import AppKit
import Foundation

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let assets = root.appendingPathComponent("Assets", isDirectory: true)
let iconset = assets.appendingPathComponent("AppIcon.iconset", isDirectory: true)
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

let iconFiles: [(String, Int)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024)
]

func color(_ hex: UInt32, alpha: CGFloat = 1) -> NSColor {
    NSColor(
        calibratedRed: CGFloat((hex >> 16) & 0xff) / 255,
        green: CGFloat((hex >> 8) & 0xff) / 255,
        blue: CGFloat(hex & 0xff) / 255,
        alpha: alpha
    )
}

func drawIcon(size: Int) throws -> Data {
    let scale = CGFloat(size) / 1024
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()

    guard let context = NSGraphicsContext.current?.cgContext else {
        throw NSError(domain: "Video2MP3Icon", code: 1)
    }
    context.setShouldAntialias(true)
    context.setAllowsAntialiasing(true)

    let canvas = CGRect(x: 0, y: 0, width: CGFloat(size), height: CGFloat(size))
    color(0x0b1020).setFill()
    NSBezierPath(rect: canvas).fill()

    let outer = CGRect(x: 80 * scale, y: 80 * scale, width: 864 * scale, height: 864 * scale)
    let radius = 190 * scale
    let bgPath = NSBezierPath(roundedRect: outer, xRadius: radius, yRadius: radius)
    let bgGradient = NSGradient(colors: [color(0x111827), color(0x162034), color(0x0b1020)])!
    bgGradient.draw(in: bgPath, angle: -45)

    let arc = NSBezierPath()
    arc.move(to: CGPoint(x: 248 * scale, y: 334 * scale))
    arc.curve(
        to: CGPoint(x: 456 * scale, y: 742 * scale),
        controlPoint1: CGPoint(x: 345 * scale, y: 459 * scale),
        controlPoint2: CGPoint(x: 406 * scale, y: 594 * scale)
    )
    arc.lineWidth = 40 * scale
    arc.lineCapStyle = .round
    color(0x38bdf8, alpha: 0.28).setStroke()
    arc.stroke()

    let play = NSBezierPath()
    play.move(to: CGPoint(x: 690 * scale, y: 796 * scale))
    play.line(to: CGPoint(x: 808 * scale, y: 728 * scale))
    play.line(to: CGPoint(x: 690 * scale, y: 660 * scale))
    play.close()
    color(0x22c55e, alpha: 0.92).setFill()
    play.fill()

    let waves = NSBezierPath()
    for (x1, x2) in [(230, 326), (358, 422), (454, 490)] {
        waves.move(to: CGPoint(x: CGFloat(x1) * scale, y: 282 * scale))
        waves.line(to: CGPoint(x: CGFloat(x2) * scale, y: 282 * scale))
    }
    waves.lineWidth = 26 * scale
    waves.lineCapStyle = .round
    color(0x38bdf8).setStroke()
    waves.stroke()

    let font = NSFont.systemFont(ofSize: 286 * scale, weight: .heavy)
    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = .center
    let shadow = NSShadow()
    shadow.shadowColor = color(0x000000, alpha: 0.32)
    shadow.shadowBlurRadius = 28 * scale
    shadow.shadowOffset = NSSize(width: 0, height: -24 * scale)
    let attributes: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: color(0xf8fafc),
        .paragraphStyle: paragraph,
        .kern: -10 * scale,
        .shadow: shadow
    ]
    let textRect = CGRect(x: 120 * scale, y: 335 * scale, width: 784 * scale, height: 330 * scale)
    NSString(string: "V23").draw(in: textRect, withAttributes: attributes)

    image.unlockFocus()

    guard let tiff = image.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiff),
          let png = bitmap.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "Video2MP3Icon", code: 2)
    }
    return png
}

for (filename, size) in iconFiles {
    let png = try drawIcon(size: size)
    try png.write(to: iconset.appendingPathComponent(filename))
}

let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
process.arguments = [
    "-c", "icns",
    iconset.path(percentEncoded: false),
    "-o", assets.appendingPathComponent("AppIcon.icns").path(percentEncoded: false)
]
try process.run()
process.waitUntilExit()

if process.terminationStatus != 0 {
    throw NSError(domain: "Video2MP3Icon", code: Int(process.terminationStatus))
}

print("Generated Assets/AppIcon.icns")
