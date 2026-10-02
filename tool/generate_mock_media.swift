// Generates the Mock Device Kit test media in example/assets/mock:
//   mock_feed_h265.mp4  504x896, 24 fps, 4 s, H.265 (mock camera feed)
//   mock_photo.jpg/png  640x480 (mock captured photo)
//
//   swift tool/generate_mock_media.swift example/assets/mock
//
// Synthetic content (colour bars and a moving square), so the files carry
// no third-party licence. Requires macOS (AVFoundation HEVC encoder).

import AVFoundation
import CoreGraphics
import CoreImage
import Foundation
import ImageIO
import UniformTypeIdentifiers

let outDir = CommandLine.arguments[1]
let width = 504, height = 896, fps: Int32 = 24, frames = 96

func drawFrame(_ ctx: CGContext, _ i: Int) {
  let colors: [(CGFloat, CGFloat, CGFloat)] = [(0.9,0.2,0.2),(0.2,0.8,0.2),(0.2,0.3,0.9),(0.9,0.8,0.1),(0.6,0.2,0.8),(0.1,0.8,0.8)]
  let bar = CGFloat(width) / CGFloat(colors.count)
  for (n, c) in colors.enumerated() {
    ctx.setFillColor(red: c.0, green: c.1, blue: c.2, alpha: 1)
    ctx.fill(CGRect(x: CGFloat(n) * bar, y: 0, width: bar, height: CGFloat(height)))
  }
  // moving square so consecutive frames differ
  ctx.setFillColor(red: 1, green: 1, blue: 1, alpha: 1)
  let y = CGFloat((i * 8) % (height - 80))
  ctx.fill(CGRect(x: CGFloat(width) / 2 - 40, y: y, width: 80, height: 80))
}

// HEVC video
let url = URL(fileURLWithPath: "\(outDir)/mock_feed_h265.mp4")
try? FileManager.default.removeItem(at: url)
let writer = try AVAssetWriter(outputURL: url, fileType: .mp4)
let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
  AVVideoCodecKey: AVVideoCodecType.hevc,
  AVVideoWidthKey: width,
  AVVideoHeightKey: height,
  AVVideoCompressionPropertiesKey: [AVVideoAverageBitRateKey: 800_000, AVVideoMaxKeyFrameIntervalKey: 24],
])
input.expectsMediaDataInRealTime = false
let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [
  kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
  kCVPixelBufferWidthKey as String: width, kCVPixelBufferHeightKey as String: height,
])
writer.add(input)
writer.startWriting()
writer.startSession(atSourceTime: .zero)
for i in 0..<frames {
  while !input.isReadyForMoreMediaData { usleep(1000) }
  var pb: CVPixelBuffer?
  CVPixelBufferPoolCreatePixelBuffer(nil, adaptor.pixelBufferPool!, &pb)
  let buffer = pb!
  CVPixelBufferLockBaseAddress(buffer, [])
  let ctx = CGContext(data: CVPixelBufferGetBaseAddress(buffer), width: width, height: height, bitsPerComponent: 8,
    bytesPerRow: CVPixelBufferGetBytesPerRow(buffer), space: CGColorSpaceCreateDeviceRGB(),
    bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue)!
  drawFrame(ctx, i)
  CVPixelBufferUnlockBaseAddress(buffer, [])
  adaptor.append(buffer, withPresentationTime: CMTime(value: CMTimeValue(i), timescale: fps))
}
input.markAsFinished()
let done = DispatchSemaphore(value: 0)
writer.finishWriting { done.signal() }
done.wait()
print("video:", writer.status == .completed ? "ok" : "failed \(String(describing: writer.error))")

// Still images (JPEG + PNG)
let ctx = CGContext(data: nil, width: 640, height: 480, bitsPerComponent: 8, bytesPerRow: 0,
  space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
drawFrame(ctx, 10)
let image = ctx.makeImage()!
for (name, type) in [("mock_photo.jpg", UTType.jpeg), ("mock_photo.png", UTType.png)] {
  let dest = CGImageDestinationCreateWithURL(URL(fileURLWithPath: "\(outDir)/\(name)") as CFURL, type.identifier as CFString, 1, nil)!
  CGImageDestinationAddImage(dest, image, nil)
  print(name, CGImageDestinationFinalize(dest) ? "ok" : "failed")
}
