/*
 Playground to demonstrate how to setup a MPSImageConversion filter to map
 the color intensity from the sRGB color space to a linear gamma curve.
 Requirements: XCode 9.x
 Problem running under XCode 10.x - destination texture not writable
 
 */
import PlaygroundSupport
import MetalKit

var metalDevice: MTLDevice! = nil
metalDevice = MTLCreateSystemDefaultDevice()

let frame = NSRect(x: 0, y: 0,
                   width: 256, height: 256)
let view = MetalView(frame: frame, device: metalDevice)
PlaygroundPage.current.liveView = view
