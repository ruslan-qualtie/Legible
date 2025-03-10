import AppKit
import Accelerate
import CoreImage
import CoreImage.CIFilterBuiltins

func diff(_ old: Data, _ new: CGImage, size: NSSize) -> NSImage {
    diff(NSImage(data: old)!, NSImage(cgImage: new, size: size))
}

func diff(_ old: CGImage, _ new: CGImage) -> CICompositeOperation {
    diff(CIImage(cgImage: old), CIImage(cgImage: new))
}

func diff(_ old: CIImage, _ new: CIImage) -> CICompositeOperation {
    let differenceFilter: CICompositeOperation = CIFilter.differenceBlendMode()
    differenceFilter.inputImage = old
    differenceFilter.backgroundImage = new
    return differenceFilter
}

func histogramData(_ ciImage: CIImage) -> Data {
    let hist = CIFilter.areaHistogram()
    hist.inputImage = ciImage
    hist.setValue(CIVector(cgRect: ciImage.extent), forKey: kCIInputExtentKey)
    return hist.value(forKey: "outputData") as! Data
}

func maxColorDiff(histogram: [UInt32]) -> Float {
    let rgb = stride(from: 0, to: histogram.count, by: 4).map { (index: Int)-> UInt32 in
        histogram[index] + histogram[index + 1] + histogram[index + 2]
    }
    if let last = rgb.lastIndex(where: { $0 > 0 }) {
        return Float(last) / Float(rgb.count)
    } else {
        return 1.0
    }
}
func histogram(ciImage: CIImage) -> [UInt32] {
    let data = histogramData(ciImage)
    let count = data.count / MemoryLayout<UInt32>.stride
    let result: [UInt32] = data.withUnsafeBytes { (bytes: UnsafeRawBufferPointer) in
        let pointer = bytes.bindMemory(to: UInt32.self)
        return Array(UnsafeBufferPointer(start: pointer.baseAddress, count: count))
    }
    return result
}

func diff(_ old: NSImage, _ new: NSImage) -> NSImage {
    let differenceFilter = diff(
        old.cgImage(forProposedRect: nil, context: nil, hints: nil)!,
        new.cgImage(forProposedRect: nil, context: nil, hints: nil)!
    )
    let unionRect = CGRect(origin: .zero, size: old.size)
        .union(.init(origin: .zero, size: new.size))
    let unionSize = unionRect.size

    let rep = NSCIImageRep(ciImage: differenceFilter.outputImage!)
    let difference = NSImage(size: unionSize)
    difference.addRepresentation(rep)
    return difference
}

func significantlyDifferentImages(_ left: Data, _ right: CGImage) -> Bool {
    var leftBuffer = imageBuffer(data: left)
    var rightBuffer = imageBuffer(cgImage: right)
    defer {
        leftBuffer.free()
        rightBuffer.free()
    }
    guard leftBuffer.height == rightBuffer.height, leftBuffer.width == rightBuffer.width else {
        return true
    }
    let leftPixels = floatPixels(&leftBuffer)
    let rightPixels = floatPixels(&rightBuffer)
    let difference = vDSP.subtract(leftPixels, rightPixels)
    return vDSP.maximumMagnitude(difference) > 4 ||
        vDSP.rootMeanSquare(difference) > 0.5
}

func imageBuffer(cgImage: CGImage) -> vImage_Buffer {
    // TODO: fail on try
    try! vImage_Buffer(
        cgImage: cgImage,
        format: getFormat(cgImage)
    )
}

func imageBuffer(data: Data) -> vImage_Buffer {
    imageBuffer(nsImage: NSImage(data: data)!)
}
func imageBuffer(url: URL) -> vImage_Buffer {
    // TODO: fail on unwrap
    let nsImage = NSImage(contentsOf: url)!
    return imageBuffer(cgImage: cgImage(nsImage))
}

func imageBuffer(nsImage: NSImage) -> vImage_Buffer {
    imageBuffer(cgImage: cgImage(nsImage))
}


func cgImage(_ nsImage: NSImage) -> CGImage {
    nsImage.cgImage(forProposedRect: nil, context: nil, hints: nil)!
}

func getFormat(_ cgImage: CGImage) -> vImage_CGImageFormat {
    vImage_CGImageFormat(cgImage: cgImage)!
}

func floatPixels(_ imageBuffer: inout vImage_Buffer) -> [Float] {
    var floatPixels: [Float]
    let count = Int(imageBuffer.width) * Int(imageBuffer.height)
    let totalCount = count * 4
    let width = Int(imageBuffer.width)
    floatPixels = [Float](unsafeUninitializedCapacity: totalCount) { buffer, initializedCount in
        var minFloat = Float(UInt8.min)
        var maxFloat = Float(UInt8.max)
        var floatBuffers: [vImage_Buffer] = (0...3).map {
            vImage_Buffer(data: buffer.baseAddress!.advanced(by: $0 * count),
                          height: imageBuffer.height,
                          width: imageBuffer.width,
                          rowBytes: width * MemoryLayout<Float>.size)
        }

        vImageConvert_ARGB8888toPlanarF(&imageBuffer,
                                        &floatBuffers[0],
                                        &floatBuffers[1],
                                        &floatBuffers[2],
                                        &floatBuffers[3],
                                        &minFloat, &maxFloat,
                                        vImage_Flags(kvImageDoNotTile))

        initializedCount = totalCount
    }
    return floatPixels
}
