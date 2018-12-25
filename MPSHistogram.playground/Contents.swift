import AppKit
import PlaygroundSupport

// Apply a MPSHistogram filter on the file.
guard let nsImage = applyFilter(named: "sky.jpg")
else {
    fatalError("Couldn't apply a MPSImageHistogram filter on the image")
}

let size = nsImage.size

// Prepare to display the image
let ratio = size.height < size.width ? size.height/size.width : size.width/size.height

let frame = NSRect(x: 0, y: 0,
                   width: ratio*size.width, height: ratio*size.height)
let view = NSImageView(frame: frame)
view.image = nsImage
PlaygroundPage.current.liveView = view

