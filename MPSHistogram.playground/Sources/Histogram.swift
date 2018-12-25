import MetalKit
import MetalPerformanceShaders
import PlaygroundSupport

// Instantiate an MTLTexture object which serves as the source texture.
func loadResources(named filename: String, device: MTLDevice) -> MTLTexture? {
    let strSeqs = filename.split(separator: ".")
    let name = String(strSeqs[0])
    let fileExt = String(strSeqs[1])
    let url = Bundle.main.url(forResource: name,
                              withExtension: fileExt)
    let textureLoader = MTKTextureLoader(device: device)
    var texture: MTLTexture? = nil
    do {
        texture = try textureLoader.newTexture(URL: url!,
                                               options: [.SRGB: false as NSObject,
                                                         .origin: true as NSObject])
    }
    catch let error {
        print("Can't instantiate the source texture:", error)
        return nil
    }
    return texture
}

// Main module
public func applyFilter(named filename: String) -> NSImage? {
    let device = MTLCreateSystemDefaultDevice()!
    guard let sourceTexture = loadResources(named: filename, device: device)
    else {
        return nil
    }
    let destTextureDesc = sourceTexture.matchingDescriptor()
    destTextureDesc.usage.formUnion(.shaderWrite)
    destTextureDesc.pixelFormat = .bgra8Unorm
    let destTexture = device.makeTexture(descriptor: destTextureDesc)

    let commandQueue = device.makeCommandQueue()!
    let commandBuffer = commandQueue.makeCommandBuffer()!

    // Lifted from Apple's documentation
    // Create a histogram filter
    var histogramInfo = MPSImageHistogramInfo(numberOfHistogramEntries: 256,
                                              histogramForAlpha: false,
                                              minPixelValue: float4(0,0,0,0),
                                              maxPixelValue: float4(1,1,1,1))

    let calculation = MPSImageHistogram(device: device,
                                        histogramInfo: &histogramInfo)

    let bufferLength = calculation.histogramSize(forSourceFormat: sourceTexture.pixelFormat)
    let histogramInfoBuffer = device.makeBuffer(length: bufferLength,
                                                options: [.storageModePrivate])!

     calculation.encode(to: commandBuffer,
                       sourceTexture: sourceTexture,
                       histogram: histogramInfoBuffer,
                       histogramOffset: 0)

    // The histogramInfoBuffer contains the histogram information.
    // Now apply an equalisation filter on the histogram.
    let histogramEqualizer = MPSImageHistogramEqualization(device: device,
                                                           histogramInfo: &histogramInfo)
    
    histogramEqualizer.encodeTransform(to: commandBuffer,
                                       sourceTexture: sourceTexture,
                                       histogram: histogramInfoBuffer,
                                       histogramOffset: 0)

    histogramEqualizer.encode(commandBuffer: commandBuffer,
                              sourceTexture: sourceTexture,
                              destinationTexture: destTexture!)

    commandBuffer.commit()

    // Code lifted from the article "Histogram Equalisation with Metal Performance Shaders"
    // Instantiate an NSImage object from the destination texture.
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let ciImage = CIImage(mtlTexture: destTexture!,
                          options: [kCIImageColorSpace: colorSpace])

    let ciContext = CIContext(mtlDevice: device)
    let cgImage = ciContext.createCGImage(ciImage!,
                                          from: ciImage!.extent)
    let size = NSMakeSize(CGFloat(cgImage!.width),
                          CGFloat(cgImage!.height))
    let nsImage = NSImage(cgImage: cgImage!,
                          size: size)
    return nsImage
}

// The code below is lifted from MetalByExample's Performance Shaders demo.
extension MTLTexture {
    func matchingDescriptor() -> MTLTextureDescriptor {
        let descriptor = MTLTextureDescriptor()
        descriptor.textureType = self.textureType
        descriptor.pixelFormat = self.pixelFormat
        descriptor.width = self.width
        descriptor.height = self.height
        descriptor.depth = self.depth
        descriptor.mipmapLevelCount = self.mipmapLevelCount
        descriptor.arrayLength = self.arrayLength

        // NOTE: We don't set resourceOptions here, since we explicitly set cache
        // and storage modes below.
        descriptor.cpuCacheMode = self.cpuCacheMode
        descriptor.storageMode = self.storageMode
        descriptor.usage = self.usage
        return descriptor
    }
}
