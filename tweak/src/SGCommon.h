// Shared declarations for every spotifyglass source file.
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <os/log.h>

// iOS 26 API, absent from the SDK Theos builds against. Resolved at runtime.
@interface UIGlassEffect : UIVisualEffect
@property (nonatomic, copy) UIColor *tintColor;
@property (nonatomic, getter=isInteractive) BOOL interactive;
@end

@interface NSObject (SGiOS26)
+ (id)capsuleConfiguration;
+ (id)configurationWithUniformRadius:(id)radius;
+ (id)fixedRadius:(CGFloat)radius;
- (void)setCornerConfiguration:(id)configuration;
@end

@interface UIView (SGPrivate)
- (NSString *)recursiveDescription;
@end

@interface UIViewController (SGPrivate)
- (NSString *)_printHierarchy;
@end

// %{public}s so idevicesyslog on the Mac sees the text instead of <private>.
#define SGLog(fmt, ...) os_log_with_type(OS_LOG_DEFAULT, OS_LOG_TYPE_DEFAULT, "[spotifyglass] %{public}s", [NSString stringWithFormat:(fmt), ##__VA_ARGS__].UTF8String)
void SGLogLong(NSString *tag, NSString *text);
void SGRequireClasses(NSArray<NSString *> *names);

// View tree
void SGForEachView(UIView *view, void (^fn)(UIView *));
CGRect SGFrameIn(UIView *view, UIView *target);
BOOL SGIsInside(UIView *view, UIView *root);
BOOL SGKeepsColor(UIView *view);
void SGStripBackgrounds(UIView *view);
BOOL SGIsVisibleColor(CGColorRef color);
BOOL SGIsLightColor(CGColorRef color);

// Glass panes
UIVisualEffectView *SGGlassFor(UIView *host, const void *key);
UIVisualEffectView *SGGlassAt(UIView *host, NSUInteger index);
void SGShapeGlass(UIView *glass, CGFloat radius, BOOL capsule);

// Areas kept transparent by ui/Repaint.x, set by the tweaks that own them.
extern __weak UIView *sg_nowPlayingRoot;
extern __weak UIView *sg_tabBarRoot;
extern __weak UIView *sg_nowPlayingCard;
BOOL SGLooksLikeCard(UIView *view, CGColorRef color);

// Diagnostics (SGDiagnostics.x)
BOOL SGIsDebugBuild(void);
void SGDumpScreen(NSString *reason);
