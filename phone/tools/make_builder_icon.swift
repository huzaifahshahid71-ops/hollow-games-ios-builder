import AppKit
// Original vector mark: two source cards joined into a phone-shaped output.
let out = CommandLine.arguments[1]
let image = NSImage(size:NSSize(width:1024,height:1024))
image.lockFocus()
NSColor(calibratedRed:0.035,green:0.06,blue:0.12,alpha:1).setFill()
NSBezierPath(rect:NSRect(x:0,y:0,width:1024,height:1024)).fill()
NSColor(calibratedRed:0.16,green:0.72,blue:0.82,alpha:1).setFill()
NSBezierPath(roundedRect:NSRect(x:160,y:310,width:320,height:440),xRadius:40,yRadius:40).fill()
NSColor(calibratedRed:0.3,green:0.38,blue:0.75,alpha:1).setFill()
NSBezierPath(roundedRect:NSRect(x:235,y:230,width:320,height:440),xRadius:40,yRadius:40).fill()
NSColor.white.setStroke()
let phone = NSBezierPath(roundedRect:NSRect(x:505,y:190,width:350,height:630),xRadius:65,yRadius:65)
phone.lineWidth=28; phone.stroke()
let screen = NSBezierPath();screen.move(to:NSPoint(x:610,y:750));screen.line(to:NSPoint(x:750,y:750));screen.lineWidth=15;screen.lineCapStyle = .round;screen.stroke()
let arrow=NSBezierPath();arrow.move(to:NSPoint(x:365,y:490));arrow.line(to:NSPoint(x:710,y:490));arrow.move(to:NSPoint(x:620,y:580));arrow.line(to:NSPoint(x:710,y:490));arrow.line(to:NSPoint(x:620,y:400));arrow.lineWidth=36;arrow.lineJoinStyle = .round;arrow.lineCapStyle = .round;arrow.stroke()
image.unlockFocus()
let bitmap=NSBitmapImageRep(data:image.tiffRepresentation!)!
try bitmap.representation(using:.png,properties:[:])!.write(to:URL(fileURLWithPath:out))
