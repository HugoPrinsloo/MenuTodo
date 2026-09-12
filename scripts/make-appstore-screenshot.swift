#!/usr/bin/env swift
//
// make-appstore-screenshot.swift
//
// Builds an App Store sized Mac screenshot (2560x1600) from the existing
// docs/screenshot.png capture: the app's "Paper" background color filled
// full-bleed, with the capture scaled up 2x (Lanczos) and centered, plus a
// subtle drop shadow.
//
// Usage: swift scripts/make-appstore-screenshot.swift

import AppKit
import CoreGraphics
import CoreImage
import Foundation

let repoRoot = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()
    .deletingLastPathComponent()
let sourcePath = repoRoot.appendingPathComponent("docs/screenshot.png")
let outDir = repoRoot.appendingPathComponent("docs/appstore")
let outPath = outDir.appendingPathComponent("screenshot-1.png")

// MARK: - Load source capture

guard let sourceCGImage = NSImage(contentsOf: sourcePath)?.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
    FileHandle.standardError.write("Failed to load \(sourcePath.path)\n".data(using: .utf8)!)
    exit(1)
}

let sourceWidth = CGFloat(sourceCGImage.width)
let sourceHeight = CGFloat(sourceCGImage.height)

// MARK: - Canvas / layout constants

let canvasWidth = 2560
let canvasHeight = 1600
let scale: CGFloat = 2.0
let targetWidth = sourceWidth * scale   // 2012
let targetHeight = sourceHeight * scale // 1008

// "Paper" light color from MenuTodo/Assets.xcassets/Paper.colorset (sRGB 0.969, 0.969, 0.961)
let paperColor = CGColor(red: 0.969, green: 0.969, blue: 0.961, alpha: 1.0)

// MARK: - High-quality (Lanczos) upscale via Core Image

let ciContext = CIContext()
let sourceCIImage = CIImage(cgImage: sourceCGImage)
guard let lanczosFilter = CIFilter(name: "CILanczosScaleTransform") else {
    FileHandle.standardError.write("CILanczosScaleTransform unavailable\n".data(using: .utf8)!)
    exit(1)
}
lanczosFilter.setValue(sourceCIImage, forKey: kCIInputImageKey)
lanczosFilter.setValue(scale, forKey: kCIInputScaleKey)
lanczosFilter.setValue(1.0, forKey: kCIInputAspectRatioKey)

guard let scaledCIImage = lanczosFilter.outputImage,
      let scaledCGImage = ciContext.createCGImage(scaledCIImage, from: CGRect(x: 0, y: 0, width: targetWidth, height: targetHeight)) else {
    FileHandle.standardError.write("Failed to render Lanczos-scaled image\n".data(using: .utf8)!)
    exit(1)
}

// MARK: - Compose onto full-bleed canvas, no alpha channel

let colorSpace = CGColorSpaceCreateDeviceRGB()
guard let context = CGContext(
    data: nil,
    width: canvasWidth,
    height: canvasHeight,
    bitsPerComponent: 8,
    bytesPerRow: 0,
    space: colorSpace,
    bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
) else {
    FileHandle.standardError.write("Failed to create bitmap context\n".data(using: .utf8)!)
    exit(1)
}

context.setFillColor(paperColor)
context.fill(CGRect(x: 0, y: 0, width: canvasWidth, height: canvasHeight))

let originX = (CGFloat(canvasWidth) - targetWidth) / 2
let originY = (CGFloat(canvasHeight) - targetHeight) / 2
let imageRect = CGRect(x: originX, y: originY, width: targetWidth, height: targetHeight)

context.interpolationQuality = .high
context.saveGState()
context.setShadow(
    offset: CGSize(width: 0, height: -10),
    blur: 40,
    color: CGColor(red: 0, green: 0, blue: 0, alpha: 0.28)
)
context.draw(scaledCGImage, in: imageRect)
context.restoreGState()

guard let finalCGImage = context.makeImage() else {
    FileHandle.standardError.write("Failed to make final image\n".data(using: .utf8)!)
    exit(1)
}

// MARK: - Write PNG

try? FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)

let rep = NSBitmapImageRep(cgImage: finalCGImage)
guard let pngData = rep.representation(using: .png, properties: [:]) else {
    FileHandle.standardError.write("Failed to encode PNG\n".data(using: .utf8)!)
    exit(1)
}

do {
    try pngData.write(to: outPath)
    print("Wrote \(outPath.path)")
} catch {
    FileHandle.standardError.write("Failed to write \(outPath.path): \(error)\n".data(using: .utf8)!)
    exit(1)
}
