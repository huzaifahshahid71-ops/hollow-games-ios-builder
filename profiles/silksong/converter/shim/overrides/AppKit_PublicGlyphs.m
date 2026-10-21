// Project-authored needle-and-silk silhouettes. No APK sprites or game textures.
#import <UIKit/UIKit.h>
static void HPNeedle(CGContextRef c,CGFloat x,CGFloat y,CGFloat angle,CGFloat length){
 CGContextSaveGState(c);CGContextTranslateCTM(c,x,y);CGContextRotateCTM(c,angle);
 CGContextMoveToPoint(c,-length*.52,0);CGContextAddLineToPoint(c,length*.32,-5);CGContextAddLineToPoint(c,length*.23,0);CGContextAddLineToPoint(c,length*.32,5);CGContextClosePath(c);CGContextFillPath(c);
 CGContextStrokeEllipseInRect(c,CGRectMake(length*.27,-4,10,8));CGContextRestoreGState(c);
}
static void HPFigure(CGContextRef c,CGFloat angle,BOOL airborne){
 CGContextSaveGState(c);CGContextTranslateCTM(c,64,64);CGContextRotateCTM(c,angle);
 // Curved horns, mask and pointed travelling cloak.
 CGContextMoveToPoint(c,-13,-12);CGContextAddCurveToPoint(c,-29,-24,-25,-40,-22,-44);CGContextAddCurveToPoint(c,-16,-40,-10,-31,-8,-22);CGContextAddCurveToPoint(c,-3,-24,3,-24,7,-22);CGContextAddCurveToPoint(c,10,-34,15,-42,21,-46);CGContextAddCurveToPoint(c,23,-32,22,-20,13,-12);CGContextAddCurveToPoint(c,9,-1,-9,0,-13,-12);CGContextFillPath(c);
 CGContextMoveToPoint(c,-7,-2);CGContextAddCurveToPoint(c,-15,5,-22,20,-28,28);CGContextAddCurveToPoint(c,-14,22,-9,26,-2,28);CGContextAddLineToPoint(c,10,42);CGContextAddLineToPoint(c,9,24);CGContextAddLineToPoint(c,29,30);CGContextAddCurveToPoint(c,16,16,10,7,5,-2);CGContextClosePath(c);CGContextFillPath(c);
 CGContextSetLineWidth(c,3);CGContextMoveToPoint(c,-2,25);CGContextAddLineToPoint(c,airborne?-15:-8,airborne?39:46);CGContextMoveToPoint(c,6,24);CGContextAddLineToPoint(c,airborne?25:16,airborne?32:44);CGContextStrokePath(c);
 // Transparent eye cutouts retain a single white silhouette.
 CGContextSetBlendMode(c,kCGBlendModeClear);CGContextFillEllipseInRect(c,CGRectMake(-11,-16,5,8));CGContextFillEllipseInRect(c,CGRectMake(6,-16,5,8));CGContextSetBlendMode(c,kCGBlendModeNormal);CGContextRestoreGState(c);
}
UIImage *HollowPublicGlyph(NSString *name){
 UIGraphicsImageRendererFormat *format=[UIGraphicsImageRendererFormat defaultFormat];format.scale=2;format.opaque=NO;
 return [[[[UIGraphicsImageRenderer alloc]initWithSize:CGSizeMake(128,128) format:format] imageWithActions:^(UIGraphicsImageRendererContext *ctx){
 CGContextRef c=ctx.CGContext;CGContextSetStrokeColorWithColor(c,UIColor.whiteColor.CGColor);CGContextSetFillColorWithColor(c,UIColor.whiteColor.CGColor);CGContextSetLineWidth(c,2);CGContextSetLineCap(c,kCGLineCapRound);CGContextSetLineJoin(c,kCGLineJoinRound);
 if([name isEqual:@"Ring"]||[name isEqual:@"Knob"]){
  if([name isEqual:@"Knob"]){CGContextSetLineWidth(c,8);CGContextStrokeEllipseInRect(c,CGRectMake(24,24,80,80));return;}
  CGContextSetLineWidth(c,3);CGContextStrokeEllipseInRect(c,CGRectMake(4,4,120,120));CGContextSetLineWidth(c,1.2);CGContextStrokeEllipseInRect(c,CGRectMake(11,11,106,106));
  for(int i=0;i<4;i++){CGContextSaveGState(c);CGContextTranslateCTM(c,64,64);CGContextRotateCTM(c,i*M_PI_2);CGContextMoveToPoint(c,-2,-44);CGContextAddLineToPoint(c,0,-46);CGContextAddLineToPoint(c,2,-44);CGContextStrokePath(c);CGContextRestoreGState(c);}return;
 }
 if([name isEqual:@"Options"]||[name isEqual:@"PortOptionsGlyph"]){
  CGContextSaveGState(c);CGContextTranslateCTM(c,64,48);
  for(int i=0;i<12;i++){CGContextRotateCTM(c,M_PI/6);CGContextMoveToPoint(c,-3,-17);CGContextAddQuadCurveToPoint(c,0,-32,3,-17);CGContextStrokePath(c);}
  CGContextStrokeEllipseInRect(c,CGRectMake(-17,-17,34,34));CGContextStrokeEllipseInRect(c,CGRectMake(-10,-10,20,20));CGContextRestoreGState(c);
  [@"MENU" drawInRect:CGRectMake(24,87,80,24) withAttributes:@{NSFontAttributeName:[UIFont fontWithName:@"Georgia" size:17]?:[UIFont systemFontOfSize:17],NSForegroundColorAttributeName:UIColor.whiteColor}];return;
 }
 BOOL wide=[name isEqual:@"SuperDash"]||[name isEqual:@"QuickCast"];
 if(!wide)CGContextStrokeEllipseInRect(c,CGRectMake(5,5,118,118));
 if([name isEqual:@"Attack"]){HPNeedle(c,65,66,.78,80);}
 else if([name isEqual:@"Jump"]){CGContextSaveGState(c);CGContextTranslateCTM(c,10,0);CGContextScaleCTM(c,.85,.85);HPFigure(c,-.42,YES);CGContextRestoreGState(c);}
 else if([name isEqual:@"Dash"]){CGContextSaveGState(c);CGContextTranslateCTM(c,4,3);CGContextScaleCTM(c,.9,.9);HPFigure(c,M_PI_2,YES);CGContextRestoreGState(c);}
 else if([name isEqual:@"Cast"]){CGContextSaveGState(c);CGContextTranslateCTM(c,9,12);CGContextScaleCTM(c,.83,.83);HPFigure(c,.2,NO);CGContextRestoreGState(c);HPNeedle(c,67,78,-.8,66);CGContextMoveToPoint(c,31,44);CGContextAddCurveToPoint(c,12,9,108,20,87,66);CGContextStrokePath(c);}
 else if([name isEqual:@"DreamNail"]){HPNeedle(c,66,72,.7,65);CGContextMoveToPoint(c,64,52);CGContextAddCurveToPoint(c,123,10,105,102,39,47);CGContextAddCurveToPoint(c,-4,17,96,52,64,52);CGContextStrokePath(c);}
 else if([name isEqual:@"QuickCast"]){HPNeedle(c,68,64,0,100);CGContextMoveToPoint(c,20,45);CGContextAddCurveToPoint(c,51,42,54,91,82,67);CGContextStrokePath(c);}
 else if([name isEqual:@"SuperDash"]){CGContextSaveGState(c);CGContextTranslateCTM(c,-10,14);CGContextScaleCTM(c,.7,.7);HPFigure(c,.3,YES);CGContextRestoreGState(c);HPNeedle(c,83,69,0,69);CGContextMoveToPoint(c,31,42);CGContextAddCurveToPoint(c,46,10,55,93,86,62);CGContextStrokePath(c);}
 else {CGContextSaveGState(c);CGContextTranslateCTM(c,9,13);CGContextScaleCTM(c,.83,.83);HPFigure(c,-.9,YES);CGContextRestoreGState(c);CGContextMoveToPoint(c,29,39);CGContextAddCurveToPoint(c,108,11,109,104,36,85);CGContextStrokePath(c);}
 }] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
}
