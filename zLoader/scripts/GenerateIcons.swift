import AppKit
import CoreGraphics
let root = URL(fileURLWithPath: CommandLine.arguments[1])
func image(_ size: Int, _ variant: Int) -> Data {
    let ctx = CGContext(data:nil,width:size,height:size,bitsPerComponent:8,bytesPerRow:0,space:CGColorSpaceCreateDeviceRGB(),bitmapInfo:CGImageAlphaInfo.noneSkipLast.rawValue)!
    let s=CGFloat(size)
    let dark=variant != 1
    let bottom: [CGFloat]=dark ? [0.035,0.11,0.09,1.0] : [0.84,0.96,0.90,1.0]
    let top: [CGFloat]=dark ? [0.14,0.32,0.25,1.0] : [0.98,1.0,0.98,1.0]
    let colors=[CGColor(colorSpace:CGColorSpaceCreateDeviceRGB(),components:bottom)!,CGColor(colorSpace:CGColorSpaceCreateDeviceRGB(),components:top)!] as CFArray
    let gradient=CGGradient(colorsSpace:CGColorSpaceCreateDeviceRGB(),colors:colors,locations:[0,1])!
    ctx.drawLinearGradient(gradient,start:CGPoint(x:0,y:0),end:CGPoint(x:s,y:s),options:[.drawsBeforeStartLocation,.drawsAfterEndLocation])
    let card=CGPath(roundedRect:CGRect(x:s*0.14,y:s*0.14,width:s*0.72,height:s*0.72),cornerWidth:s*0.18,cornerHeight:s*0.18,transform:nil)
    ctx.addPath(card);ctx.setFillColor(CGColor(gray:1,alpha:dark ? 0.09 : 0.50));ctx.fillPath()
    ctx.addPath(card);ctx.setStrokeColor(CGColor(gray:1,alpha:0.25));ctx.setLineWidth(s*0.003);ctx.strokePath()
    ctx.setStrokeColor(CGColor(colorSpace:CGColorSpaceCreateDeviceRGB(),components:dark ? [0.47,0.94,0.74,1] : [0.08,0.40,0.30,1])!)
    ctx.setLineWidth(s*0.073);ctx.setLineCap(.round);ctx.setLineJoin(.round)
    ctx.move(to:CGPoint(x:s*0.32,y:s*0.67));ctx.addLine(to:CGPoint(x:s*0.67,y:s*0.67));ctx.addLine(to:CGPoint(x:s*0.33,y:s*0.34));ctx.addLine(to:CGPoint(x:s*0.68,y:s*0.34));ctx.strokePath()
    if variant==2 {ctx.setStrokeColor(CGColor(gray:1,alpha:0.22));ctx.setLineWidth(s*0.009);ctx.strokeEllipse(in:CGRect(x:s*0.22,y:s*0.22,width:s*0.56,height:s*0.56))}
    return NSBitmapImageRep(cgImage:ctx.makeImage()!).representation(using:.png,properties:[:])!
}
let fm=FileManager.default
for case let url as URL in fm.enumerator(at:root,includingPropertiesForKeys:nil)! where url.pathExtension=="png" {
 let size=NSBitmapImageRep(data:try Data(contentsOf:url))!.pixelsWide
 let variant=url.path.contains("Dark") || url.path.contains("Storm") ? 2 : (url.path.contains("Snow") || url.path.contains("Winter") ? 1 : 0)
 try image(size,variant).write(to:url)
}
for (name,variant) in [("Mint",0),("Frost",1),("Night",2)] {try image(1024,variant).write(to:URL(fileURLWithPath:"zLoader/Branding/Icons/zLoader-\(name).png"))}
