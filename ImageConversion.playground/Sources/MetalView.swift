import MetalKit
import MetalPerformanceShaders

public class MetalView: MTKView {
    var commandQueue: MTLCommandQueue? = nil
    var rps: MTLRenderPipelineState? = nil

    // Buffer variables for the quad
    var vertexBuffer: MTLBuffer? = nil
    var indexBuffer: MTLBuffer? = nil

    var srcTexture: MTLTexture? = nil
    var destTexture: MTLTexture? = nil
    // color spaces of source and destination textures.
    var srcColorSpace: CGColorSpace? = nil
    var dstColorSpace: CGColorSpace? = nil

    // Filter
    var conversion: MPSImageConversion? = nil

    public override init(frame frameRect: CGRect,
                         device: MTLDevice?) {
        super.init(frame: frameRect, device: device)
        commandQueue = device!.makeCommandQueue()
        if !setup() {
            fatalError("Can't setup the demo.")
        }
     }

    public required init(coder: NSCoder) {
        super.init(coder: coder)
    }

    // Override the method inherited from its parent class NSView.
    public override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        // Apply the linear gamma conversion first.
        let commandBuffer = commandQueue!.makeCommandBuffer()!
        // Note: the encoding call must be made before the if-branch below.
        conversion!.encode(commandBuffer: commandBuffer,
                           sourceTexture: srcTexture!,
                           destinationTexture: destTexture!)
 
        if  let rpd = currentRenderPassDescriptor,
            let drawable = currentDrawable,
            let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: rpd) {

            // Render the quad with the destination texture.
            renderEncoder.setRenderPipelineState(rps!)
            renderEncoder.setVertexBuffer(vertexBuffer,
                                          offset:0,
                                          index:0)
            renderEncoder.setFragmentTexture(destTexture!,
                                             index:0)

            renderEncoder.drawIndexedPrimitives(type: .triangleStrip,
                                                indexCount: 4,
                                                indexType: .uint16,
                                                indexBuffer: indexBuffer!,
                                                indexBufferOffset: 0)
            renderEncoder.endEncoding()
            commandBuffer.present(drawable)
            commandBuffer.commit()
       }
   }

    // The code below is from Apple's documentation on MPSImageConversion.
    func setup() -> Bool {
        // Initialize the MPSImageConversion filter
        guard let srcColorSpace = CGColorSpace(name: CGColorSpace.sRGB),
              let dstColorSpace = CGColorSpace(name: CGColorSpace.linearSRGB)
        else {
            Swift.print("Cannot create the 2 color space objects")
            return false
        }
        let conversionInfo = CGColorConversionInfo(src: srcColorSpace,
                                                   dst: dstColorSpace)

        // "conversion" is an instance of MPSUnaryImageKernel; we can use the inherited methods.
        conversion = MPSImageConversion(device: device!,
                                        srcAlpha: .alphaIsOne,
                                        destAlpha: .alphaIsOne,
                                        backgroundColor: nil,
                                        conversionInfo: conversionInfo)
        guard let texture = loadTexture(device: device!)
        else {
            return false
        }
        srcTexture = texture
        let textureDescr = matchingDescriptor(srcTexture!)
        textureDescr.usage.formUnion(.shaderWrite)
        destTexture = device!.makeTexture(descriptor: textureDescr)
        do {
            rps = try buildRenderPipeline(device: device!,
                                          metalKitView: self)
        }
        catch let error {
            Swift.print("Can't create a render pipeline:", error)
            return false
        }
        setupBuffers()
        return true
    }

    func loadTexture(device: MTLDevice) -> MTLTexture? {
        let myBundle = Bundle.main
        let assetURL = myBundle.url(forResource: "flower",
                                    withExtension:"png")
        let textureLoader = MTKTextureLoader(device: device)
        var texture: MTLTexture! = nil
        let textureOptions = [
            MTKTextureLoader.Option.textureUsage        : NSNumber(value: MTLTextureUsage.shaderRead.rawValue),
            MTKTextureLoader.Option.textureStorageMode  : NSNumber(value: MTLStorageMode.private.rawValue),
            MTKTextureLoader.Origin.bottomLeft          : NSNumber(value: true),
            MTKTextureLoader.Option.SRGB                : NSNumber(value: true),] as [AnyHashable : Any
            ]
        do {
            texture = try textureLoader.newTexture(URL: assetURL!,
                                                   options: textureOptions as? [MTKTextureLoader.Option : Any])
        }
        catch {
            Swift.print("error loading texture")
            return nil
        }
        return texture
    }

    /// Build a render state pipeline object
   func buildRenderPipeline(device: MTLDevice,
                             metalKitView: MTKView) throws -> MTLRenderPipelineState? {
        let path = Bundle.main.path(forResource: "Shaders",
                                    ofType: "metal")
    
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        do {
            let input = try String(contentsOfFile: path!,
                                   encoding: String.Encoding.utf8)
            let library = try device.makeLibrary(source: input,
                                                 options: nil)
            let vertexFunction = library.makeFunction(name: "passThroughVertex")
            let fragmentFunction = library.makeFunction(name: "passThroughFragment")
            pipelineDescriptor.label = "RenderPipeline"
            pipelineDescriptor.vertexFunction = vertexFunction
            pipelineDescriptor.fragmentFunction = fragmentFunction
            
            pipelineDescriptor.colorAttachments[0].pixelFormat = metalKitView.colorPixelFormat
            pipelineDescriptor.sampleCount = metalKitView.sampleCount
        }
        catch let e {
            Swift.print("Error: \(e) - Can't load the shaders:")
            return nil
        }
        return try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
    }

    func setupBuffers() {
        // alignment=16 bytes; size=24 bytes; stride=32 bytes
        struct Vertex {
            let position: packed_float4     // 16 bytes
            let uv: packed_float2           //  8 bytes
        }
        var vertices = [Vertex]()
        vertices.append(Vertex(position: packed_float4( 1.0, -1.0, 0, 1),
                               uv: packed_float2(1, 1)))
        vertices.append(Vertex(position: packed_float4(-1.0, -1.0, 0, 1),
                               uv: packed_float2(0, 1)))
        vertices.append(Vertex(position: packed_float4(-1.0,  1.0, 0, 1),
                               uv: packed_float2(0, 0)))
        vertices.append(Vertex(position: packed_float4( 1.0,  1.0, 0, 1),
                               uv: packed_float2(1, 0)))
        // triangle strip
        let indices: [UInt16] = [0, 1, 3, 2]

        vertexBuffer = device!.makeBuffer(bytes: vertices,
                                          length: MemoryLayout<Vertex>.stride * vertices.count,
                                          options: [])
        indexBuffer = device!.makeBuffer(bytes: indices,
                                         length: MemoryLayout<UInt16>.stride * indices.count,
                                         options: [])
    }

    // From MetalByExample project "Performance Shaders" by Warren Moore.
    func matchingDescriptor(_ texture: MTLTexture) -> MTLTextureDescriptor {
        let descriptor = MTLTextureDescriptor()
        descriptor.textureType = texture.textureType
        // NOTE: We should be more careful to select a renderable pixel format here,
        // especially if operating on a compressed texture.
        descriptor.pixelFormat = texture.pixelFormat    // defaults to bgra8Unorm
        descriptor.width = texture.width
        descriptor.height = texture.height
        descriptor.depth = texture.depth
        descriptor.mipmapLevelCount = texture.mipmapLevelCount
        descriptor.arrayLength = texture.arrayLength

        // NOTE: We don't set resourceOptions here, since we explicitly set
        // the cache and storage modes below.
        descriptor.cpuCacheMode = texture.cpuCacheMode
        descriptor.storageMode = texture.storageMode
        descriptor.usage = texture.usage
        return descriptor
    }
}
