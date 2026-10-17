// Original vector fallback icons. No APK sprites or game textures are embedded.
#import <UIKit/UIKit.h>
UIImage *HollowPublicGlyph(NSString *name) {
 CGSize size=CGSizeMake(128,128);
 UIGraphicsImageRenderer *r=[[UIGraphicsImageRenderer alloc]initWithSize:size];
 return [[r imageWithActions:^(UIGraphicsImageRendererContext *ctx){
  CGContextRef c=ctx.CGContext;CGContextSetStrokeColorWithColor(c,UIColor.whiteColor.CGColor);CGContextSetFillColorWithColor(c,UIColor.whiteColor.CGColor);CGContextSetLineWidth(c,3);CGContextSetLineCap(c,kCGLineCapRound);CGContextSetLineJoin(c,kCGLineJoinRound);
  if([name isEqualToString:@"Ring"]){CGContextStrokeEllipseInRect(c,CGRectMake(6,6,116,116));CGContextStrokeEllipseInRect(c,CGRectMake(12,12,104,104));return;}
  if([name isEqualToString:@"Knob"]){CGContextFillEllipseInRect(c,CGRectMake(20,20,88,88));return;}
  if([name isEqualToString:@"Options"]||[name isEqualToString:@"PortOptionsGlyph"]){for(int y=40;y<=88;y+=24){CGContextMoveToPoint(c,32,y);CGContextAddLineToPoint(c,96,y);CGContextStrokePath(c);}return;}
  BOOL wide=[name isEqualToString:@"SuperDash"]||[name isEqualToString:@"QuickCast"];
  if(wide)CGContextStrokeRect(c,CGRectMake(5,29,118,70));else CGContextStrokeEllipseInRect(c,CGRectMake(6,6,116,116));
  if([name isEqualToString:@"Attack"]){CGContextMoveToPoint(c,37,92);CGContextAddLineToPoint(c,89,34);CGContextAddLineToPoint(c,76,71);CGContextClosePath(c);CGContextFillPath(c);CGContextMoveToPoint(c,31,75);CGContextAddLineToPoint(c,53,96);CGContextStrokePath(c);}
  else if([name isEqualToString:@"Jump"]){CGContextMoveToPoint(c,41,67);CGContextAddLineToPoint(c,64,38);CGContextAddLineToPoint(c,87,67);CGContextStrokePath(c);CGContextMoveToPoint(c,64,40);CGContextAddLineToPoint(c,64,93);CGContextStrokePath(c);}
  else if([name isEqualToString:@"Dash"]||wide){for(int y=48;y<=80;y+=16){CGContextMoveToPoint(c,28,y);CGContextAddLineToPoint(c,70,y);CGContextStrokePath(c);}CGContextMoveToPoint(c,66,39);CGContextAddLineToPoint(c,99,64);CGContextAddLineToPoint(c,66,89);CGContextClosePath(c);CGContextFillPath(c);}
  else if([name isEqualToString:@"Cast"]){CGContextMoveToPoint(c,64,32);CGContextAddCurveToPoint(c,36,58,36,83,64,96);CGContextAddCurveToPoint(c,92,83,92,58,64,32);CGContextFillPath(c);}
  else {CGContextMoveToPoint(c,64,29);CGContextAddLineToPoint(c,72,55);CGContextAddLineToPoint(c,99,64);CGContextAddLineToPoint(c,72,73);CGContextAddLineToPoint(c,64,99);CGContextAddLineToPoint(c,56,73);CGContextAddLineToPoint(c,29,64);CGContextAddLineToPoint(c,56,55);CGContextClosePath(c);CGContextFillPath(c);}
 }] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
}
