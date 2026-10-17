// Private Silksong overlay: verified desktop bindings, UIKit touch and GC input.
#import <UIKit/UIKit.h>
#import <GameController/GameController.h>
#import <objc/runtime.h>
#import <math.h>
#import <dlfcn.h>
extern UIImage *HollowPublicGlyph(NSString *);
extern int ShimTargetFPS(void);
extern unsigned ShimPresentedFPS(void);
extern void ShimPostVirtualKey(unsigned short, BOOL, NSString *);
static BOOL SKUtilityTag(NSInteger t){return t==-101||t==53||t==34||t==1||t==3||t==46;}
@interface SKHUDButton : UIButton @end
@implementation SKHUDButton
- (CGRect)imageRectForContentRect:(CGRect)r {
 if(!SKUtilityTag(self.tag)||!self.currentImage)return [super imageRectForContentRect:r];
 CGRect box=CGRectInset(r,8,7);CGSize size=self.currentImage.size;if(size.width<=0||size.height<=0)return box;
 CGFloat scale=MIN(box.size.width/size.width,box.size.height/size.height);CGSize fit=CGSizeMake(size.width*scale,size.height*scale);
 return CGRectMake(CGRectGetMidX(box)-fit.width/2,CGRectGetMidY(box)-fit.height/2,fit.width,fit.height);
}
@end
@interface SKControls : UIView
@property UIView *stick,*knob;
@property UITouch *stickTouch;
@property NSMutableSet<NSNumber *> *touchKeys,*padKeys,*sentKeys;
@property NSMutableArray<UIButton *> *buttons;
@property UIButton *modeButton;
@property BOOL gameplay,showFPS,hideOptions;
@property NSInteger inputMode,layoutMode;
@property UIView *panel;
@property UILabel *fpsLabel;
@property NSTimer *statusTimer;
@property CADisplayLink *poll;
@property BOOL editing;
@property NSMutableDictionary *customLayouts;
@property NSDictionary *layoutSnapshot;
@property UIView *editorBar,*selectedControl;
@property UILabel *editLabel;
@property UISlider *sizeSlider,*opacitySlider;
@property UISwitch *visibleSwitch;
@property CGPoint dragStart;
@property CGRect selectedBaseFrame;
@end
@implementation SKControls
- (NSString *)characters:(NSInteger)c {
 NSDictionary *s=@{@6:@"z",@7:@"x",@8:@"c",@0:@"a",@1:@"s",@2:@"d",@3:@"f",@9:@"v",@46:@"m",@38:@"j",@12:@"q",@17:@"t",@34:@"i",@48:@"\t",@36:@"\r",@53:@"\x1b"};
 if(s[@(c)])return s[@(c)]; unichar ch=c==123?0xf702:c==124?0xf703:c==125?0xf701:0xf700;return [NSString stringWithCharacters:&ch length:1];
}
- (void)sync {
 NSMutableSet *next=[self.touchKeys mutableCopy];[next unionSet:self.padKeys];
 for(NSNumber *k in self.sentKeys)if(![next containsObject:k])ShimPostVirtualKey(k.unsignedShortValue,NO,[self characters:k.integerValue]);
 for(NSNumber *k in next)if(![self.sentKeys containsObject:k])ShimPostVirtualKey(k.unsignedShortValue,YES,[self characters:k.integerValue]);
 self.sentKeys=next;
}
- (void)releaseAll { [self.touchKeys removeAllObjects];[self.padKeys removeAllObjects];[self sync];self.stickTouch=nil;self.knob.center=CGPointMake(self.stick.bounds.size.width/2,self.stick.bounds.size.height/2); }
- (instancetype)initWithFrame:(CGRect)frame {
 if((self=[super initWithFrame:frame])) {
 self.autoresizingMask=UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;self.multipleTouchEnabled=YES;self.customLayouts=[[NSUserDefaults.standardUserDefaults dictionaryForKey:@"SKCustomLayoutsV1"] mutableCopy]?:[NSMutableDictionary new];
 self.touchKeys=[NSMutableSet new];self.padKeys=[NSMutableSet new];self.sentKeys=[NSMutableSet new];self.buttons=[NSMutableArray new];
 self.stick=[[UIImageView alloc]initWithImage:[self icon:@"Ring"]];self.stick.tag=-100;self.stick.accessibilityLabel=@"Movement joystick";self.stick.tintColor=UIColor.whiteColor;self.stick.userInteractionEnabled=NO;[self addSubview:self.stick];
 self.knob=[[UIImageView alloc]initWithImage:[self icon:@"Knob"]];self.knob.tintColor=UIColor.whiteColor;self.knob.bounds=CGRectMake(0,0,34,34);[self.stick addSubview:self.knob];[self installEditGestures:self.stick];
 NSArray *titles=@[@"OK",@"Pause / Back",@"Jump",@"Attack",@"Dash",@"Bind",@"Inventory",@"Harpoon",@"Skill / Tool",@"Needolin",@"Challenge",@"Map (hold)"];
 NSArray *codes=@[@36,@53,@6,@7,@8,@0,@34,@1,@3,@2,@9,@46];
 NSDictionary *icons=@{@53:@"Options",@6:@"Jump",@7:@"Attack",@8:@"Dash",@0:@"Cast",@34:@"InventoryGlyph",@1:@"SuperDash",@3:@"QuickCast",@2:@"DreamNail",@9:@"Taunt",@46:@"MapRectFantasy"};
 for(NSUInteger i=0;i<codes.count;i++){
 UIButton *b=[[SKHUDButton alloc]initWithFrame:CGRectZero];b.tag=[codes[i] integerValue];b.accessibilityLabel=titles[i];b.tintColor=UIColor.whiteColor;
 UIImage *image=[self icon:icons[codes[i]]];if(image){[b setImage:image forState:UIControlStateNormal];b.imageView.contentMode=UIViewContentModeScaleAspectFit;}else{[b setTitle:titles[i] forState:UIControlStateNormal];b.titleLabel.font=[UIFont systemFontOfSize:15 weight:UIFontWeightSemibold];b.layer.borderWidth=1;b.layer.borderColor=UIColor.whiteColor.CGColor;b.layer.cornerRadius=8;}
 [b addTarget:self action:@selector(down:) forControlEvents:UIControlEventTouchDown];[b addTarget:self action:@selector(up:) forControlEvents:UIControlEventTouchUpInside|UIControlEventTouchUpOutside|UIControlEventTouchCancel];[self installEditGestures:b];[self.buttons addObject:b];[self addSubview:b];}
 NSUserDefaults *defaults=NSUserDefaults.standardUserDefaults;if(![defaults boolForKey:@"SKUniformUtilitiesV1"]){[defaults setBool:NO forKey:@"SKHideOptions"];[defaults setBool:YES forKey:@"SKUniformUtilitiesV1"];}self.gameplay=[defaults boolForKey:@"SKGameplayControls"];self.showFPS=[defaults boolForKey:@"SKShowFPS"];self.hideOptions=[defaults boolForKey:@"SKHideOptions"];self.inputMode=[defaults integerForKey:@"SKInputMode"];self.layoutMode=[defaults integerForKey:@"SKLayout"];
 self.modeButton=[[SKHUDButton alloc]initWithFrame:CGRectZero];[self.modeButton setImage:[self icon:@"PortOptionsGlyph"] forState:UIControlStateNormal];self.modeButton.tintColor=UIColor.whiteColor;self.modeButton.imageView.contentMode=UIViewContentModeScaleAspectFit;self.modeButton.backgroundColor=UIColor.clearColor;self.modeButton.layer.cornerRadius=12;self.modeButton.layer.borderWidth=1.25;self.modeButton.layer.borderColor=UIColor.whiteColor.CGColor;[self.modeButton addTarget:self action:@selector(showSettings) forControlEvents:UIControlEventTouchUpInside];self.modeButton.tag=-101;self.modeButton.accessibilityLabel=@"Port Options";[self installEditGestures:self.modeButton];[self addSubview:self.modeButton];
 self.fpsLabel=[UILabel new];self.fpsLabel.textColor=UIColor.whiteColor;self.fpsLabel.backgroundColor=UIColor.clearColor;self.fpsLabel.textAlignment=NSTextAlignmentRight;self.fpsLabel.layer.shadowColor=UIColor.blackColor.CGColor;self.fpsLabel.layer.shadowOpacity=.8;self.fpsLabel.layer.shadowRadius=2;self.fpsLabel.layer.shadowOffset=CGSizeMake(0,1);self.fpsLabel.font=[UIFont monospacedDigitSystemFontOfSize:12 weight:UIFontWeightMedium];[self addSubview:self.fpsLabel];
 __weak SKControls *weak=self;self.statusTimer=[NSTimer scheduledTimerWithTimeInterval:.5 repeats:YES block:^(NSTimer *timer){SKControls *v=weak;if(!v){[timer invalidate];return;}v.fpsLabel.text=[NSString stringWithFormat:@"%u FPS",ShimPresentedFPS()];if(!v.editing){NSDictionary *entry=v.customLayouts[[v layoutKey:v.modeButton]];v.modeButton.alpha=v.hideOptions&&!v.panel?.02:(entry[@"alpha"]?[entry[@"alpha"] doubleValue]:.65);}}];
 self.poll=[CADisplayLink displayLinkWithTarget:self selector:@selector(controllerTick:)];self.poll.preferredFrameRateRange=CAFrameRateRangeMake(30,30,30);[self.poll addToRunLoop:NSRunLoop.mainRunLoop forMode:NSRunLoopCommonModes];
 [self applyFPS];
 [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(releaseAll) name:UIApplicationWillResignActiveNotification object:nil];
 }return self;
}
- (void)saveSettings {
 NSUserDefaults *d=NSUserDefaults.standardUserDefaults;[d setBool:self.gameplay forKey:@"SKGameplayControls"];[d setBool:self.showFPS forKey:@"SKShowFPS"];[d setBool:self.hideOptions forKey:@"SKHideOptions"];[d setInteger:self.inputMode forKey:@"SKInputMode"];[d setInteger:self.layoutMode forKey:@"SKLayout"];
 [self setNeedsLayout];
}
- (void)applyFPS {
 int fps=ShimTargetFPS();self.poll.preferredFrameRateRange=CAFrameRateRangeMake(fps==120?80:60,fps,fps);
 Dl_info info={0};if(dladdr((const void *)ShimPostVirtualKey,&info)&&info.dli_fname){NSString *path=[[@(info.dli_fname) stringByDeletingLastPathComponent] stringByAppendingPathComponent:@"libShim_CoreVideo.dylib"];void *h=dlopen(path.UTF8String,RTLD_LAZY|RTLD_NOLOAD);void(*setFPS)(int)=h?dlsym(h,"ShimCVSetTargetFPS"):NULL;if(setFPS)setFPS(fps);else NSLog(@"SHIM frame-rate adapter unavailable");}
 NSLog(@"SHIM Silksong requested frame rate %d",fps);
}
- (void)changed:(UIControl *)c {
 [self releaseAll];switch(c.tag){case 100:self.inputMode=((UISegmentedControl *)c).selectedSegmentIndex;break;case 101:self.layoutMode=((UISegmentedControl *)c).selectedSegmentIndex;break;case 102:self.gameplay=((UISegmentedControl *)c).selectedSegmentIndex==1;break;case 103:self.showFPS=((UISwitch *)c).on;break;case 104:self.hideOptions=((UISwitch *)c).on;break;case 105:[NSUserDefaults.standardUserDefaults setInteger:((UISegmentedControl *)c).selectedSegmentIndex==1?120:60 forKey:@"SKTargetFPS"];[self applyFPS];break;}[self saveSettings];
}
- (void)closeSettings {[self.panel removeFromSuperview];self.panel=nil;[self releaseAll];[self setNeedsLayout];}
- (void)addLabel:(NSString *)text stack:(UIStackView *)stack {UILabel *l=[UILabel new];l.text=text;l.numberOfLines=0;l.textColor=UIColor.whiteColor;l.font=[UIFont systemFontOfSize:14];[stack addArrangedSubview:l];}
- (void)showSettings {
 if(self.editing)return;[self releaseAll];if(self.panel){[self closeSettings];return;}
 self.modeButton.alpha=1;self.panel=[UIView new];self.panel.backgroundColor=[UIColor colorWithWhite:.07 alpha:.98];self.panel.layer.cornerRadius=18;self.panel.frame=CGRectInset(self.bounds,MAX(20,self.safeAreaInsets.left+10),12);[self addSubview:self.panel];
 UIScrollView *scroll=[[UIScrollView alloc]initWithFrame:self.panel.bounds];scroll.autoresizingMask=UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;[self.panel addSubview:scroll];UIStackView *stack=[UIStackView new];stack.axis=UILayoutConstraintAxisVertical;stack.spacing=11;stack.translatesAutoresizingMaskIntoConstraints=NO;[scroll addSubview:stack];
 [NSLayoutConstraint activateConstraints:@[[stack.leadingAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.leadingAnchor constant:20],[stack.trailingAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.trailingAnchor constant:-20],[stack.topAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.topAnchor constant:16],[stack.bottomAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.bottomAnchor constant:-16],[stack.widthAnchor constraintEqualToAnchor:scroll.frameLayoutGuide.widthAnchor constant:-40]]];
 [self addLabel:@"Silksong • Controls & Display" stack:stack];
 NSArray *labels=@[@"Input",@"Button layout",@"Controls",@"Show actual FPS",@"Hide Options button",@"Frame rate"];
 for(NSInteger i=0;i<6;i++){[self addLabel:labels[i] stack:stack];UIControl *control;
 if(i==3||i==4){UISwitch *v=[UISwitch new];v.on=i==3?self.showFPS:self.hideOptions;control=v;}else{NSArray *names=i==0?@[@"Touch + controller",@"Controller only",@"Touch only"]:i==1?@[@"Right hand",@"Left hand",@"Compact"]:i==2?@[@"Menu",@"Play"]:@[@"60 Hz",@"120 Hz"];UISegmentedControl *v=[[UISegmentedControl alloc]initWithItems:names];v.backgroundColor=[UIColor colorWithWhite:.8 alpha:1];v.selectedSegmentIndex=i==0?self.inputMode:i==1?self.layoutMode:i==2?self.gameplay:ShimTargetFPS()==120;if(i==5)[v setEnabled:UIScreen.mainScreen.maximumFramesPerSecond>=120 forSegmentAtIndex:1];control=v;}control.tag=100+i;[control addTarget:self action:@selector(changed:) forControlEvents:UIControlEventValueChanged];[stack addArrangedSubview:control];}
 UIButton *edit=[UIButton buttonWithType:UIButtonTypeSystem];[edit setTitle:@"Customize button positions, size & opacity" forState:UIControlStateNormal];[edit addTarget:self action:@selector(beginEditing) forControlEvents:UIControlEventTouchUpInside];[stack addArrangedSubview:edit];
 [self addLabel:@"Tap the Options spot to reopen a hidden button. Switch Menu/Play controls here. Hold Map after obtaining a map in the game. Connect a controller in iPhone Bluetooth settings. 120 Hz requests a higher rate; the FPS counter shows what is actually presented." stack:stack];
 UIButton *done=[UIButton buttonWithType:UIButtonTypeSystem];[done setTitle:@"Done" forState:UIControlStateNormal];[done addTarget:self action:@selector(closeSettings) forControlEvents:UIControlEventTouchUpInside];[stack addArrangedSubview:done];[self setNeedsLayout];
}
- (UIImage *)icon:(NSString *)name {
 if(!name)return nil;Dl_info info={0};if(!dladdr((const void *)ShimPostVirtualKey,&info)||!info.dli_fname)return nil;
 NSString *app=[[@(info.dli_fname) stringByDeletingLastPathComponent] stringByDeletingLastPathComponent];
 NSString *path=[[app stringByAppendingPathComponent:@"SilksongControls"] stringByAppendingPathComponent:[name stringByAppendingPathExtension:@"png"]];
 UIImage *image=[UIImage imageWithContentsOfFile:path];if(!image)return HollowPublicGlyph(name);
 CGRect crop=CGRectMake(0,0,1,1);
 if([name isEqualToString:@"SuperDash"]||[name isEqualToString:@"QuickCast"])crop=CGRectMake(.07,.13,.86,.74);
 else if([name isEqualToString:@"Options"])crop=CGRectMake(.10,.08,.80,.82);
 else if([name isEqualToString:@"MapRectFantasy"])crop=CGRectMake(.15,.16,.70,.70);
 else if([name isEqualToString:@"InventoryGlyph"])crop=CGRectMake(.18,.16,.70,.66);
 else if([name isEqualToString:@"PortOptionsGlyph"])crop=CGRectMake(.13,.12,.74,.76);
 if(!CGRectEqualToRect(crop,CGRectMake(0,0,1,1))){size_t w=CGImageGetWidth(image.CGImage),h=CGImageGetHeight(image.CGImage);CGImageRef clipped=CGImageCreateWithImageInRect(image.CGImage,CGRectMake(crop.origin.x*w,crop.origin.y*h,crop.size.width*w,crop.size.height*h));if(clipped){image=[UIImage imageWithCGImage:clipped];CGImageRelease(clipped);}}
 return [image imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
}
- (BOOL)isUtility:(UIView *)v {return SKUtilityTag(v.tag);}
- (CGFloat)normalBorder:(UIView *)v {return [self isUtility:v]?1.25:v.tag==36?1:0;}
- (NSString *)layoutKey:(UIView *)v {return [NSString stringWithFormat:@"%ld.%@.%ld",(long)self.layoutMode,self.gameplay?@"play":@"menu",(long)v.tag];}
- (void)applyCustom:(UIView *)v {
 NSDictionary *d=self.customLayouts[[self layoutKey:v]];
 CGFloat W=self.bounds.size.width,H=self.bounds.size.height,m=MIN(W,H);
 if(d&&W>0&&H>0){CGFloat w=MAX(24,MIN(W,[d[@"w"] doubleValue]*m)),h=MAX(24,MIN(H,[d[@"h"] doubleValue]*m));CGFloat x=MAX(w/2,MIN(W-w/2,[d[@"x"] doubleValue]*W)),y=MAX(h/2,MIN(H-h/2,[d[@"y"] doubleValue]*H));v.bounds=CGRectMake(0,0,w,h);v.center=CGPointMake(x,y);}
 CGFloat alpha=d[@"alpha"]?MAX(.15,MIN(1,[d[@"alpha"] doubleValue])):.65;
 v.alpha=self.editing?MAX(.4,alpha):alpha;
 if(v!=self.modeButton&&[d[@"hidden"] boolValue]){if(self.editing){if(!v.hidden)v.alpha=.25;}else v.hidden=YES;}
 if(self.editing&&v==self.selectedControl){v.layer.borderWidth=2;v.layer.borderColor=UIColor.systemCyanColor.CGColor;}
}
- (void)storeCustom:(UIView *)v {
 CGFloat W=self.bounds.size.width,H=self.bounds.size.height,m=MIN(W,H);if(m<=0)return;
 NSMutableDictionary *d=[self.customLayouts[[self layoutKey:v]] mutableCopy]?:[NSMutableDictionary new];
 d[@"x"]=@(v.center.x/W);d[@"y"]=@(v.center.y/H);d[@"w"]=@(v.bounds.size.width/m);d[@"h"]=@(v.bounds.size.height/m);
 if(!d[@"alpha"])d[@"alpha"]=@.65;self.customLayouts[[self layoutKey:v]]=d;
}
- (void)installEditGestures:(UIView *)v {
 UIPanGestureRecognizer *pan=[[UIPanGestureRecognizer alloc]initWithTarget:self action:@selector(dragControl:)];pan.enabled=NO;pan.maximumNumberOfTouches=1;[v addGestureRecognizer:pan];
 UITapGestureRecognizer *tap=[[UITapGestureRecognizer alloc]initWithTarget:self action:@selector(selectControl:)];tap.enabled=NO;[tap requireGestureRecognizerToFail:pan];[v addGestureRecognizer:tap];
}
- (void)selectView:(UIView *)v {
 if(self.selectedControl){self.selectedControl.layer.borderWidth=[self normalBorder:self.selectedControl];self.selectedControl.layer.borderColor=UIColor.whiteColor.CGColor;}
 self.selectedControl=v;self.selectedBaseFrame=v.frame;v.layer.borderWidth=2;v.layer.borderColor=UIColor.systemCyanColor.CGColor;
 self.editLabel.text=v.accessibilityLabel?:@"Control";self.sizeSlider.value=v.bounds.size.width;
 NSDictionary *d=self.customLayouts[[self layoutKey:v]];self.opacitySlider.value=d[@"alpha"]?[d[@"alpha"] floatValue]:.65;self.visibleSwitch.on=v==self.modeButton?YES:![d[@"hidden"] boolValue];self.visibleSwitch.enabled=v!=self.modeButton;
}
- (void)selectControl:(UITapGestureRecognizer *)g {if(self.editing)[self selectView:g.view];}
- (void)dragControl:(UIPanGestureRecognizer *)g {
 if(!self.editing)return;UIView *v=g.view;
 if(g.state==UIGestureRecognizerStateBegan){[self selectView:v];self.dragStart=v.center;}
 CGPoint d=[g translationInView:self];CGFloat w=v.bounds.size.width,h=v.bounds.size.height;
 v.center=CGPointMake(MAX(w/2,MIN(self.bounds.size.width-w/2,self.dragStart.x+d.x)),MAX(h/2,MIN(self.bounds.size.height-h/2,self.dragStart.y+d.y)));
 [self storeCustom:v];
}
- (void)editValueChanged:(UIControl *)c {
 UIView *v=self.selectedControl;if(!v)return;[self storeCustom:v];NSMutableDictionary *d=[self.customLayouts[[self layoutKey:v]] mutableCopy];
 if(c==self.sizeSlider){CGFloat aspect=v.bounds.size.height/MAX(1,v.bounds.size.width),w=self.sizeSlider.value;v.bounds=CGRectMake(0,0,w,w*aspect);[self storeCustom:v];d=[self.customLayouts[[self layoutKey:v]] mutableCopy];}
 if(c==self.opacitySlider)d[@"alpha"]=@(self.opacitySlider.value);
 if(c==self.visibleSwitch)d[@"hidden"]=@(!self.visibleSwitch.on);
 self.customLayouts[[self layoutKey:v]]=d;[self setNeedsLayout];
}
- (UIButton *)editorButton:(NSString *)title action:(SEL)action {
 UIButton *b=[UIButton buttonWithType:UIButtonTypeSystem];[b setTitle:title forState:UIControlStateNormal];[b setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];b.titleLabel.font=[UIFont systemFontOfSize:13 weight:UIFontWeightSemibold];[b addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];return b;
}
- (void)beginEditing {
 [self closeSettings];[self releaseAll];self.layoutSnapshot=[self.customLayouts copy];self.editing=YES;
 NSMutableArray *controls=[self.buttons mutableCopy];[controls addObjectsFromArray:@[self.stick,self.modeButton]];
 for(UIView *v in controls)for(UIGestureRecognizer *g in v.gestureRecognizers)g.enabled=YES;
 self.editorBar=[UIView new];self.editorBar.backgroundColor=[UIColor colorWithWhite:.04 alpha:.94];self.editorBar.layer.cornerRadius=12;[self addSubview:self.editorBar];
 UIStackView *stack=[UIStackView new];stack.axis=UILayoutConstraintAxisVertical;stack.spacing=4;stack.translatesAutoresizingMaskIntoConstraints=NO;[self.editorBar addSubview:stack];
 [NSLayoutConstraint activateConstraints:@[[stack.leadingAnchor constraintEqualToAnchor:self.editorBar.leadingAnchor constant:10],[stack.trailingAnchor constraintEqualToAnchor:self.editorBar.trailingAnchor constant:-10],[stack.topAnchor constraintEqualToAnchor:self.editorBar.topAnchor constant:6],[stack.bottomAnchor constraintEqualToAnchor:self.editorBar.bottomAnchor constant:-6]]];
 UIStackView *top=[UIStackView new];top.axis=UILayoutConstraintAxisHorizontal;top.spacing=10;self.editLabel=[UILabel new];self.editLabel.text=@"Drag a control • tap to select";self.editLabel.textColor=UIColor.whiteColor;self.editLabel.font=[UIFont systemFontOfSize:12];[top addArrangedSubview:self.editLabel];[top addArrangedSubview:[self editorButton:@"Reset" action:@selector(resetEditingLayout)]];[top addArrangedSubview:[self editorButton:@"Cancel" action:@selector(cancelEditing)]];[top addArrangedSubview:[self editorButton:@"Save" action:@selector(saveEditing)]];[stack addArrangedSubview:top];
 for(int i=0;i<2;i++){UIStackView *row=[UIStackView new];row.axis=UILayoutConstraintAxisHorizontal;row.spacing=8;UILabel *label=[UILabel new];label.text=i?@"Opacity":@"Size";label.textColor=UIColor.whiteColor;label.font=[UIFont systemFontOfSize:12];[label.widthAnchor constraintEqualToConstant:48].active=YES;[row addArrangedSubview:label];UISlider *slider=[UISlider new];slider.minimumValue=i?.15:30;slider.maximumValue=i?1:230;[slider addTarget:self action:@selector(editValueChanged:) forControlEvents:UIControlEventValueChanged];[row addArrangedSubview:slider];if(i){self.opacitySlider=slider;UILabel *visible=[UILabel new];visible.text=@"Visible";visible.font=[UIFont systemFontOfSize:12];visible.textColor=UIColor.whiteColor;[row addArrangedSubview:visible];self.visibleSwitch=[UISwitch new];[self.visibleSwitch addTarget:self action:@selector(editValueChanged:) forControlEvents:UIControlEventValueChanged];[row addArrangedSubview:self.visibleSwitch];}else self.sizeSlider=slider;[stack addArrangedSubview:row];}
 [self setNeedsLayout];[self layoutIfNeeded];[self selectView:self.stick];
}
- (void)finishEditing {
 self.editing=NO;[self releaseAll];if(self.selectedControl){self.selectedControl.layer.borderWidth=[self normalBorder:self.selectedControl];self.selectedControl.layer.borderColor=UIColor.whiteColor.CGColor;}self.selectedControl=nil;
 NSMutableArray *controls=[self.buttons mutableCopy];[controls addObjectsFromArray:@[self.stick,self.modeButton]];for(UIView *v in controls)for(UIGestureRecognizer *g in v.gestureRecognizers)g.enabled=NO;
 [self.editorBar removeFromSuperview];self.editorBar=nil;self.layoutSnapshot=nil;[self setNeedsLayout];
}
- (void)saveEditing {[NSUserDefaults.standardUserDefaults setObject:self.customLayouts forKey:@"SKCustomLayoutsV1"];[self finishEditing];}
- (void)cancelEditing {self.customLayouts=[self.layoutSnapshot mutableCopy]?:[NSMutableDictionary new];[self finishEditing];}
- (void)resetEditingLayout {
 NSString *prefix=[NSString stringWithFormat:@"%ld.%@.",(long)self.layoutMode,self.gameplay?@"play":@"menu"];
 for(NSString *k in [self.customLayouts.allKeys copy])if([k hasPrefix:prefix])[self.customLayouts removeObjectForKey:k];[self setNeedsLayout];[self layoutIfNeeded];if(self.selectedControl)[self selectView:self.selectedControl];
}

- (void)layoutSubviews {
 [super layoutSubviews];CGFloat l=MAX(16,self.safeAreaInsets.left+8),r=self.bounds.size.width-MAX(16,self.safeAreaInsets.right+8),h=self.bounds.size.height,b=MAX(14,self.safeAreaInsets.bottom+8),t=MAX(10,self.safeAreaInsets.top+6),u=self.layoutMode==2?.82:1;
 self.stick.hidden=NO;self.modeButton.hidden=NO;self.stick.frame=CGRectMake(l+16,h-b-114,90,90);self.modeButton.frame=CGRectMake(l+212,t+36,100,52);
 for(UIButton *v in self.buttons){v.hidden=!self.gameplay;CGFloat x=0,y=0,w=64,ht=64;
 switch(v.tag){
 case 36:x=r-76;y=h-b-68;w=76;ht=62;v.hidden=self.gameplay;break;
 case 53:x=r-100;y=t+36;w=100;ht=52;v.hidden=NO;break;
 case 6:x=r-125;y=h-b-160;break;
 case 7:x=r-125;y=h-b-90;break;
 case 8:x=r-58;y=h-b-119;break;
 case 0:x=r-58;y=h-b-188;break;
 case 2:x=r-192;y=h-b-135;break;
 case 9:x=r-192;y=h-b-65;break;
 case 1:x=l;y=t+36;w=100;ht=52;break;
 case 3:x=r-312;y=t+36;w=100;ht=52;break;
 case 48:x=l+106;y=t+36;w=100;ht=52;break;
 case 46:x=r-206;y=t+36;w=100;ht=52;break;
 case 34:x=l+106;y=t+36;w=100;ht=52;break;
 }
 if(self.layoutMode==2&&![self isUtility:v]){x=r-(r-x)*u;y=h-b-(h-b-y)*u;w*=u;ht*=u;}
 v.frame=CGRectMake(x,y,w,ht);if(self.layoutMode==1){CGRect f=v.frame;f.origin.x=self.bounds.size.width-CGRectGetMaxX(f);v.frame=f;}
 if([self isUtility:v]){v.layer.borderWidth=1.25;v.layer.borderColor=UIColor.whiteColor.CGColor;v.layer.cornerRadius=12;}
 [self applyCustom:v];if(self.inputMode==1&&!self.editing)v.hidden=YES;
 }
 if(self.layoutMode==1){CGRect f=self.stick.frame;f.origin.x=self.bounds.size.width-CGRectGetMaxX(f);self.stick.frame=f;}
 if(self.layoutMode==1){CGRect f=self.modeButton.frame;f.origin.x=self.bounds.size.width-CGRectGetMaxX(f);self.modeButton.frame=f;}
 self.modeButton.layer.borderWidth=1.25;self.modeButton.layer.borderColor=UIColor.whiteColor.CGColor;[self applyCustom:self.stick];[self applyCustom:self.modeButton];if(self.inputMode==1&&!self.editing)self.stick.hidden=YES;
 self.stick.userInteractionEnabled=self.editing;if(!self.stickTouch){CGFloat z=self.stick.bounds.size.width;self.knob.bounds=CGRectMake(0,0,z*.32,z*.32);self.knob.center=CGPointMake(z/2,self.stick.bounds.size.height/2);}
 self.fpsLabel.frame=CGRectMake(r-90,t,90,22);self.fpsLabel.hidden=!self.showFPS||self.editing;
 if(self.panel){self.panel.frame=CGRectInset(self.bounds,MAX(20,self.safeAreaInsets.left+10),12);[self bringSubviewToFront:self.panel];}
 if(self.editorBar){CGFloat w=MIN(500,self.bounds.size.width-self.safeAreaInsets.left-self.safeAreaInsets.right-24);self.editorBar.frame=CGRectMake((self.bounds.size.width-w)/2,h-116-MAX(8,self.safeAreaInsets.bottom),w,116);[self bringSubviewToFront:self.editorBar];}
}
- (UIView *)hitTest:(CGPoint)p withEvent:(UIEvent *)e {if(!self.editing&&CGRectContainsPoint(self.modeButton.frame,p)&&self.modeButton.alpha<.1){self.modeButton.alpha=1;return self.modeButton;}UIView *v=[super hitTest:p withEvent:e];if(v!=self)return v;if(self.panel)return self.panel;if(self.editing)return self;return !self.stick.hidden&&CGRectContainsPoint(CGRectInset(self.stick.frame,-15,-15),p)?self:nil;}
// Keep tag46 as the saved-layout identity; its action is now QuickMap (Tab).
- (NSInteger)keyForButton:(UIButton *)b {return b.tag==46?48:b.tag;}
- (void)down:(UIButton *)b {if(self.editing)return;[self.touchKeys addObject:@([self keyForButton:b])];[self sync];}
- (void)up:(UIButton *)b {if(self.editing)return;[self.touchKeys removeObject:@([self keyForButton:b])];[self sync];}
- (void)moveStick:(UITouch *)t {CGPoint p=[t locationInView:self.stick];CGFloat mid=self.stick.bounds.size.width/2;CGFloat x=(p.x-mid)/(mid*.82),y=(p.y-mid)/(mid*.82),d=hypot(x,y);if(d>1){x/=d;y/=d;}self.knob.center=CGPointMake(mid+x*mid*.65,mid+y*mid*.65);
 for(NSNumber *k in @[@123,@124,@125,@126])[self.touchKeys removeObject:k];if(x<-.3)[self.touchKeys addObject:@123];if(x>.3)[self.touchKeys addObject:@124];if(y<-.3)[self.touchKeys addObject:@126];if(y>.3)[self.touchKeys addObject:@125];[self sync];}
- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)e {if(self.editing||self.stickTouch)return;for(UITouch *t in touches)if(CGRectContainsPoint(CGRectInset(self.stick.frame,-15,-15),[t locationInView:self])){self.stickTouch=t;[self moveStick:t];break;}}
- (void)touchesMoved:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)e {if(self.stickTouch&&[touches containsObject:self.stickTouch])[self moveStick:self.stickTouch];}
- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)e {if(self.stickTouch&&[touches containsObject:self.stickTouch]){self.stickTouch=nil;for(NSNumber *k in @[@123,@124,@125,@126])[self.touchKeys removeObject:k];self.knob.center=CGPointMake(self.stick.bounds.size.width/2,self.stick.bounds.size.height/2);[self sync];}}
- (void)touchesCancelled:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)e {[self touchesEnded:touches withEvent:e];}
- (void)controllerTick:(CADisplayLink *)link {
 [self.padKeys removeAllObjects];if(self.panel||self.editing||self.inputMode==2){[self sync];return;}if(UIApplication.sharedApplication.applicationState!=UIApplicationStateActive){[self sync];return;}
 for(GCController *c in GCController.controllers){GCExtendedGamepad *p=c.extendedGamepad;if(!p)continue;
 if(p.dpad.left.pressed||p.leftThumbstick.xAxis.value<-.35)[self.padKeys addObject:@123];if(p.dpad.right.pressed||p.leftThumbstick.xAxis.value>.35)[self.padKeys addObject:@124];if(p.dpad.up.pressed||p.leftThumbstick.yAxis.value>.35)[self.padKeys addObject:@126];if(p.dpad.down.pressed||p.leftThumbstick.yAxis.value<-.35)[self.padKeys addObject:@125];
 if(p.buttonA.pressed)[self.padKeys addObject:self.gameplay?@6:@36];
 if(p.buttonB.pressed)[self.padKeys addObject:self.gameplay?@0:@53];
 if(self.gameplay){
 if(p.buttonX.pressed)[self.padKeys addObject:@7];
 if(p.buttonY.pressed)[self.padKeys addObject:@2];
 if(p.rightTrigger.pressed)[self.padKeys addObject:@8];
 if(p.leftTrigger.pressed)[self.padKeys addObject:@1];
 if(p.rightShoulder.pressed)[self.padKeys addObject:@3];
 if(p.leftShoulder.pressed)[self.padKeys addObject:@48];
 if(p.rightThumbstickButton.pressed)[self.padKeys addObject:@9];
 }
 if(p.buttonMenu.pressed)[self.padKeys addObject:@53];
 if(p.buttonOptions.pressed)[self.padKeys addObject:@34];
 if([p isKindOfClass:GCDualShockGamepad.class]&&((GCDualShockGamepad *)p).touchpadButton.pressed)[self.padKeys addObject:@34];
 if([p isKindOfClass:GCDualSenseGamepad.class]&&((GCDualSenseGamepad *)p).touchpadButton.pressed)[self.padKeys addObject:@34];}
 [self sync];
}
- (void)dealloc {[self.poll invalidate];[self.statusTimer invalidate];[NSNotificationCenter.defaultCenter removeObserver:self];}
@end
__attribute__((constructor)) static void SKInstallControls(void) {
 dispatch_async(dispatch_get_main_queue(),^{__block SKControls *overlay;__block NSUInteger attempts=0;
 [NSTimer scheduledTimerWithTimeInterval:1 repeats:YES block:^(NSTimer *timer){for(UIScene *s in UIApplication.sharedApplication.connectedScenes){if(![s isKindOfClass:UIWindowScene.class])continue;for(UIWindow *w in ((UIWindowScene *)s).windows){if(!w.isKeyWindow||!w.rootViewController.view)continue;UIView *root=w.rootViewController.view;if(!overlay){overlay=[[SKControls alloc]initWithFrame:root.bounds];[root addSubview:overlay];NSLog(@"SHIM Silksong touch menu/gameplay controls installed");}[root bringSubviewToFront:overlay];return;}}if(!overlay&&++attempts>30)[timer invalidate];}];});
}
