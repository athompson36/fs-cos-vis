import AppKit
import CoreGraphics
import Foundation

/// Copies imported overlays into Application Support so paths stay valid if the original file moves.
enum OverlayFileSupport {
    private static var overlaysDirectory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent(AppIdentity.applicationSupportFolderName, isDirectory: true)
            .appendingPathComponent("Overlays", isDirectory: true)
    }

    static func copyImportedOverlayToAppSupport(from sourceURL: URL, assetID: UUID) throws -> URL {
        try FileManager.default.createDirectory(at: overlaysDirectory, withIntermediateDirectories: true)
        let ext = sourceURL.pathExtension.isEmpty ? "png" : sourceURL.pathExtension
        let dest = overlaysDirectory.appendingPathComponent("\(assetID.uuidString).\(ext.lowercased())")
        if FileManager.default.fileExists(atPath: dest.path) {
            try FileManager.default.removeItem(at: dest)
        }
        try FileManager.default.copyItem(at: sourceURL, to: dest)
        return dest
    }
}

/// Turns near-black pixels transparent and writes an RGBA PNG.
enum OverlayBlackBackgroundKnockout {
    /// Pixels where max(R,G,B) is below this (linear 0…1) become fully transparent. Default ~14/255.
    static let defaultThreshold: Float = 14 / 255

    static func knockOutBlackBackground(sourceURL: URL, destinationURL: URL, threshold: Float = defaultThreshold) throws {
        guard let image = NSImage(contentsOf: sourceURL),
              let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil)
        else {
            throw NSError(domain: "OverlayBlackBackgroundKnockout", code: 1, userInfo: [NSLocalizedDescriptionKey: "Could not load image"])
        }

        let w = cgImage.width
        let h = cgImage.height
        guard w > 0, h > 0 else {
            throw NSError(domain: "OverlayBlackBackgroundKnockout", code: 2, userInfo: [NSLocalizedDescriptionKey: "Invalid image size"])
        }

        var data = [UInt8](repeating: 0, count: w * h * 4)
        var rasterized = false
        data.withUnsafeMutableBufferPointer { buf in
            guard let base = buf.baseAddress else { return }
            guard let ctx = CGContext(
                data: base,
                width: w,
                height: h,
                bitsPerComponent: 8,
                bytesPerRow: w * 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { return }
            ctx.translateBy(x: 0, y: CGFloat(h))
            ctx.scaleBy(x: 1, y: -1)
            ctx.draw(cgImage, in: CGRect(x: 0, y: 0, width: w, height: h))
            rasterized = true
        }
        guard rasterized else {
            throw NSError(domain: "OverlayBlackBackgroundKnockout", code: 3, userInfo: [NSLocalizedDescriptionKey: "Could not rasterize image"])
        }

        for i in stride(from: 0, to: data.count, by: 4) {
            let rf = Float(data[i]) / 255
            let gf = Float(data[i + 1]) / 255
            let bf = Float(data[i + 2]) / 255
            let mx = max(rf, max(gf, bf))
            if mx < threshold {
                data[i] = 0
                data[i + 1] = 0
                data[i + 2] = 0
                data[i + 3] = 0
            }
        }

        // Keep buffer row order as rasterized (CGContext flip above yields a top-down image suitable for PNG).
        // Do not flip again here — an extra flip produced upside-down files in Preview and other apps.

        let outData = Data(data)
        let provider = CGDataProvider(data: outData as CFData)!
        guard let outCG = CGImage(
            width: w,
            height: h,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: w * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
            provider: provider,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
        ) else {
            throw NSError(domain: "OverlayBlackBackgroundKnockout", code: 4, userInfo: [NSLocalizedDescriptionKey: "Could not create image"])
        }

        let rep = NSBitmapImageRep(cgImage: outCG)
        guard let pngData = rep.representation(using: .png, properties: [:]) else {
            throw NSError(domain: "OverlayBlackBackgroundKnockout", code: 5, userInfo: [NSLocalizedDescriptionKey: "Could not encode PNG"])
        }
        try pngData.write(to: destinationURL, options: .atomic)
    }
}
