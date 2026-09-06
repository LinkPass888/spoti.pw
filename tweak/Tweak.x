#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <os/log.h>

// iOS 26 API, absent from the SDK Theos builds against. Resolved at runtime.
@interface UIGlassEffect : UIVisualEffect
@property (nonatomic, copy) UIColor *tintColor;
@property (nonatomic, getter=isInteractive) BOOL interactive;
@end

@interface NSObject (SpotifyGlassIOS26)
+ (id)capsuleConfiguration;
+ (id)configurationWithUniformRadius:(id)radius;
+ (id)fixedRadius:(CGFloat)radius;
- (void)setCornerConfiguration:(id)configuration;
@end

@interface UIView (SpotifyGlassPrivate)
- (NSString *)recursiveDescription;
@end

@interface UIViewController (SpotifyGlassPrivate)
- (NSString *)_printHierarchy;
@end

// %{public}s so idevicesyslog on the Mac sees the text instead of <private>.
#define SGLog(fmt, ...) os_log_with_type(OS_LOG_DEFAULT, OS_LOG_TYPE_DEFAULT, "[spotifyglass] %{public}s", [NSString stringWithFormat:(fmt), ##__VA_ARGS__].UTF8String)

// The unified log cuts a message at about 1 KB, so long dumps go out as numbered parts.
static void SGLogLong(NSString *tag, NSString *text) {
    NSMutableArray<NSString *> *parts = [NSMutableArray array];
    NSMutableString *current = [NSMutableString string];
    for (NSString *line in [text componentsSeparatedByString:@"\n"]) {
        if (current.length && [current lengthOfBytesUsingEncoding:NSUTF8StringEncoding] + [line lengthOfBytesUsingEncoding:NSUTF8StringEncoding] > 900) {
            [parts addObject:[current copy]];
            [current setString:@""];
        }
        [current appendFormat:@"%@\n", line];
    }
    if (current.length) [parts addObject:current];
    [parts enumerateObjectsUsingBlock:^(NSString *part, NSUInteger i, BOOL *stop) {
        SGLog(@"%@ %lu/%lu\n%@", tag, (unsigned long)i + 1, (unsigned long)parts.count, part);
    }];
}

static const CGFloat kCardRadius = 24;
static const CGFloat kTabPillHeight = 56;
static const CGFloat kTabSearchSize = 52;

// Views whose subtree must stay transparent so the glass behind them shows.
static __weak UIView *sg_nowPlayingRoot;
static __weak UIView *sg_tabBarRoot;
// The view Spotify paints with the album colour, refreshed from the layer hook on every repaint.
static __weak UIView *sg_nowPlayingCard;

static char kNowPlayingGlassKey, kTabPillKey, kTabSearchKey;

#pragma mark - helpers

static void forEachView(UIView *view, void (^fn)(UIView *)) {
    fn(view);
    for (UIView *sub in view.subviews) forEachView(sub, fn);
}

static CGRect frameIn(UIView *view, UIView *target) {
    return [view.superview convertRect:view.frame toView:target];
}

static BOOL isInside(UIView *view, UIView *root) {
    if (!root) return NO;
    for (UIView *v = view; v; v = v.superview) {
        if ([v isKindOfClass:UIVisualEffectView.class]) return NO;
        if (v == root) return YES;
    }
    return NO;
}

// Artwork, glyphs, text and thin lines (progress bar) keep their colour, everything else goes clear.
static BOOL keepsColor(UIView *view) {
    return [view isKindOfClass:UIImageView.class] || [view isKindOfClass:UILabel.class] || view.bounds.size.height <= 4;
}

static void stripBackgrounds(UIView *view) {
    if ([view isKindOfClass:UIVisualEffectView.class]) return;
    if (!keepsColor(view)) view.layer.backgroundColor = NULL;
    if ([view.layer isKindOfClass:CAGradientLayer.class] || [NSStringFromClass(view.class) containsString:@"GradientView"]) view.hidden = YES;
    for (CALayer *layer in view.layer.sublayers) {
        if ([layer isKindOfClass:CAGradientLayer.class]) layer.hidden = YES;
    }
    for (UIView *sub in view.subviews) stripBackgrounds(sub);
}

static BOOL isVisibleColor(CGColorRef color) {
    if (!color || CGColorGetAlpha(color) < 0.05) return NO;
    const CGFloat *c = CGColorGetComponents(color);
    size_t n = CGColorGetNumberOfComponents(color);
    CGFloat brightest = 0;
    for (size_t i = 0; i + 1 < n; i++) brightest = MAX(brightest, c[i]);
    return brightest > 0.08;
}

#pragma mark - glass

static UIVisualEffect *glassEffect(void) {
    Class glass = NSClassFromString(@"UIGlassEffect");
    if (glass) return [[glass alloc] init];
    return [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemChromeMaterialDark];
}

static UIVisualEffectView *glassFor(UIView *host, const void *key) {
    UIVisualEffectView *glass = objc_getAssociatedObject(host, key);
    if (!glass) {
        glass = [[UIVisualEffectView alloc] initWithEffect:glassEffect()];
        glass.userInteractionEnabled = NO;
        objc_setAssociatedObject(host, key, glass, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    if (glass.superview != host) [host insertSubview:glass atIndex:0];
    return glass;
}

// Several glass panes on one host, addressed by index, all kept behind the host's own content.
static UIVisualEffectView *glassAt(UIView *host, NSUInteger index) {
    static char kPanesKey;
    NSMutableArray<UIVisualEffectView *> *panes = objc_getAssociatedObject(host, &kPanesKey);
    if (!panes) {
        panes = [NSMutableArray array];
        objc_setAssociatedObject(host, &kPanesKey, panes, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    while (panes.count <= index) {
        UIVisualEffectView *glass = [[UIVisualEffectView alloc] initWithEffect:glassEffect()];
        glass.userInteractionEnabled = NO;
        [panes addObject:glass];
    }
    UIVisualEffectView *glass = panes[index];
    if (glass.superview != host) [host insertSubview:glass atIndex:0];
    return glass;
}

static void shapeGlass(UIView *glass, CGFloat radius, BOOL capsule) {
    Class config = NSClassFromString(@"UICornerConfiguration");
    Class cornerRadius = NSClassFromString(@"UICornerRadius");
    id shape = nil;
    if (config && [glass respondsToSelector:@selector(setCornerConfiguration:)]) {
        if (capsule && [config respondsToSelector:@selector(capsuleConfiguration)]) {
            shape = [config capsuleConfiguration];
        } else if ([config respondsToSelector:@selector(configurationWithUniformRadius:)] && [cornerRadius respondsToSelector:@selector(fixedRadius:)]) {
            shape = [config configurationWithUniformRadius:[cornerRadius fixedRadius:radius]];
        }
    }
    if (shape) {
        [glass setCornerConfiguration:shape];
        glass.clipsToBounds = NO;
    } else {
        glass.layer.cornerRadius = capsule ? glass.bounds.size.height / 2 : radius;
        glass.layer.cornerCurve = kCACornerCurveContinuous;
        glass.clipsToBounds = YES;
    }
}

#pragma mark - now playing bar

static BOOL looksLikeCard(UIView *view, CGColorRef color) {
    CGSize size = view.bounds.size;
    return size.height >= 40 && size.height <= 140 && size.width >= 200 && isVisibleColor(color);
}

static UIView *detectColoredCard(UIView *bar) {
    __block UIView *best = nil;
    __block CGFloat bestArea = 0;
    forEachView(bar, ^(UIView *v) {
        if ([v isKindOfClass:UIVisualEffectView.class] || keepsColor(v) || !looksLikeCard(v, v.layer.backgroundColor)) return;
        CGFloat area = v.bounds.size.width * v.bounds.size.height;
        if (area > bestArea) { bestArea = area; best = v; }
    });
    return best;
}

// Fallback when nothing is painted: the box around artwork, text and the small buttons.
static CGRect contentBounds(UIView *bar, UIView *target) {
    __block CGRect box = CGRectNull;
    forEachView(bar, ^(UIView *v) {
        if (v.hidden || v.alpha == 0) return;
        CGFloat width = v.bounds.size.width;
        BOOL content = ([v isKindOfClass:UIImageView.class] && width >= 20 && width <= 120)
            || [v isKindOfClass:UILabel.class]
            || ([v isKindOfClass:UIControl.class] && width <= 100);
        if (content) box = CGRectUnion(box, frameIn(v, target));
    });
    return CGRectIsNull(box) ? box : CGRectInset(box, -10, -8);
}

// Round artwork (a 40pt square with a small radius, no image view inside) and move the progress
// line from the card's bottom edge to right under the text, like the reference.
static void restyleCardContent(UIView *card) {
    forEachView(card, ^(UIView *v) {
        CGSize size = v.bounds.size;
        BOOL square = size.width >= 36 && size.width <= 48 && fabs(size.width - size.height) < 1;
        if (!square || v.layer.cornerRadius <= 0 || v.layer.cornerRadius >= size.width / 2) return;
        for (UIView *u = v; u && u != card && CGSizeEqualToSize(u.bounds.size, size); u = u.superview) {
            u.layer.cornerRadius = size.width / 2;
            u.clipsToBounds = YES;
        }
    });
    forEachView(card, ^(UIView *v) {
        CGRect f = v.frame;
        if (f.size.height > 3 || f.size.width < 200 || v.superview.bounds.size.height < 40) return;
        CGRect target = CGRectMake(52, card.bounds.size.height - 6, 226, 2);
        if (CGRectEqualToRect(f, target)) return;
        v.frame = target;
        [v setNeedsLayout];
        [v layoutIfNeeded];
    });
}

static void styleNowPlayingBar(UIViewController *container) {
    UIViewController *barVC = container.childViewControllers.firstObject;
    UIView *bar = barVC.viewIfLoaded ?: container.view;
    sg_nowPlayingRoot = bar;

    UIView *card = sg_nowPlayingCard;
    if (!card || !isInside(card, bar)) card = sg_nowPlayingCard = detectColoredCard(bar);

    container.view.layer.backgroundColor = NULL;
    stripBackgrounds(bar);

    CGRect frame = card ? frameIn(card, container.view) : contentBounds(bar, container.view);
    if (CGRectIsNull(frame)) return;
    frame.size.height = MIN(frame.size.height, 80);
    if (frame.size.height < 30 || frame.size.width < 100) return;

    CGFloat radius = MIN(kCardRadius, frame.size.height / 2);
    if (card) {
        card.layer.cornerRadius = radius;
        card.layer.cornerCurve = kCACornerCurveContinuous;
        restyleCardContent(card);
    }

    UIVisualEffectView *glass = glassFor(container.view, &kNowPlayingGlassKey);
    glass.frame = frame;
    shapeGlass(glass, radius, NO);

    static dispatch_once_t once;
    dispatch_once(&once, ^{
        SGLog(@"now playing card %@ at %@ (bar %@, container %@)", card.class, NSStringFromCGRect(frame),
              NSStringFromCGRect(bar.frame), NSStringFromCGRect(container.view.bounds));
    });
}

%hook _TtC18NowPlaying_BarImpl36NowPlayingBarContainerViewController
- (void)viewDidLayoutSubviews {
    %orig;
    styleNowPlayingBar((UIViewController *)self);
}
%end

%hook _TtC18NowPlaying_BarImpl27NowPlayingBarViewController
- (void)viewDidLayoutSubviews {
    %orig;
    UIViewController *parent = ((UIViewController *)self).parentViewController;
    if ([NSStringFromClass(parent.class) containsString:@"NowPlayingBarContainer"]) styleNowPlayingBar(parent);
}
%end

#pragma mark - tab bar (NavigationUI_TabBarImpl.TabBarView: gradient + stack of 4 item elements)
// Spotify maps taps by position, so the items stay in their order: Home, Search, Library in the
// capsule and Create in its own circle.

static NSArray<UIView *> *tabItems(UIView *tabBar) {
    NSMutableArray<UIView *> *items = [NSMutableArray array];
    forEachView(tabBar, ^(UIView *v) {
        if (v != tabBar && v.bounds.size.width >= 20 && [NSStringFromClass(v.class) containsString:@"TabBarItemElement"]) [items addObject:v];
    });
    // Element wrappers nest; keep the outermost per item.
    return [items filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(UIView *v, id _) {
        for (UIView *u = v.superview; u && u != tabBar; u = u.superview) if ([items containsObject:u]) return NO;
        return YES;
    }]];
}

static void styleTabBar(UIView *tabBar) {
    sg_tabBarRoot = tabBar;
    stripBackgrounds(tabBar);
    tabBar.superview.layer.backgroundColor = NULL;

    NSArray<UIView *> *items = tabItems(tabBar);
    static dispatch_once_t once;
    dispatch_once(&once, ^{ SGLog(@"tab bar %@ with %lu items", tabBar.class, (unsigned long)items.count); });
    if (items.count < 2) return;

    NSArray<UIView *> *sorted = [items sortedArrayUsingComparator:^NSComparisonResult(UIView *a, UIView *b) {
        return [@(frameIn(a, tabBar).origin.x) compare:@(frameIn(b, tabBar).origin.x)];
    }];
    CGRect first = frameIn(sorted.firstObject, tabBar);
    CGRect lastMain = frameIn(sorted[sorted.count - 2], tabBar);
    CGRect last = frameIn(sorted.lastObject, tabBar);
    CGFloat midY = CGRectGetMidY(first);

    UIVisualEffectView *pill = glassFor(tabBar, &kTabPillKey);
    CGFloat left = MAX(12, first.origin.x + 12);
    pill.frame = CGRectMake(left, midY - kTabPillHeight / 2, CGRectGetMaxX(lastMain) + 4 - left, kTabPillHeight);
    shapeGlass(pill, kTabPillHeight / 2, YES);

    UIVisualEffectView *circle = glassFor(tabBar, &kTabSearchKey);
    circle.frame = CGRectMake(CGRectGetMidX(last) - kTabSearchSize / 2, midY - kTabSearchSize / 2, kTabSearchSize, kTabSearchSize);
    shapeGlass(circle, kTabSearchSize / 2, YES);
}

// Items lay out their own icon and label; hide the label and centre the icon after each pass.
static void styleTabItem(UIView *item) {
    CGFloat midY = CGRectGetMidY(item.bounds);
    forEachView(item, ^(UIView *v) {
        if ([v isKindOfClass:UILabel.class]) {
            v.alpha = 0;
        } else if ([NSStringFromClass(v.class) containsString:@"IconView"]) {
            CGPoint target = [item convertPoint:CGPointMake(0, midY) toView:v.superview];
            v.center = CGPointMake(v.center.x, target.y);
        }
    });
}

// Items lay out after the bar, so the bar's own pass sees no item frames; restyle from the items too.
static void styleTabItemAndBar(UIView *item) {
    styleTabItem(item);
    Class barClass = NSClassFromString(@"_TtC23NavigationUI_TabBarImpl10TabBarView");
    for (UIView *v = item.superview; v; v = v.superview) {
        if ([v isKindOfClass:barClass]) { styleTabBar(v); return; }
    }
}

%hook _TtC23NavigationUI_TabBarImpl10TabBarView
- (void)layoutSubviews {
    %orig;
    for (UIView *sub in ((UIView *)self).subviews) [sub layoutIfNeeded];
    styleTabBar((UIView *)self);
}
%end

%hook _TtC23NavigationUI_TabBarImpl21TabBarItemElementView
- (void)layoutSubviews {
    %orig;
    styleTabItemAndBar((UIView *)self);
}
%end

%hook _TtC25CreateMenu_TabBarItemImpl24CreateMenuTabBarItemView
- (void)layoutSubviews {
    %orig;
    styleTabItemAndBar((UIView *)self);
}
%end

#pragma mark - full screen player (NowPlaying_ModesImpl units: header, playback controls, footer)

// A glass pane per direct child of the unit's row: circles for square children, capsules for wide
// ones. `fixedSize` forces every pane to one size; children matching `skip` get none.
static void glassBehindRowChildren(UIViewController *unit, CGFloat minSize, CGFloat fixedSize, NSString *skip) {
    UIView *host = unit.viewIfLoaded;
    __block UIStackView *row = nil;
    forEachView(host, ^(UIView *v) {
        if (!row && [v isKindOfClass:UIStackView.class] && v.bounds.size.width > 200 && ((UIStackView *)v).arrangedSubviews.count >= 2) row = (UIStackView *)v;
    });
    if (!row) return;
    [row layoutIfNeeded];
    NSUInteger index = 0;
    for (UIView *child in row.arrangedSubviews) {
        CGRect f = frameIn(child, host);
        if (child.hidden || f.size.width < 20 || f.size.height < 20) continue;
        __block BOOL skipped = NO;
        if (skip) forEachView(child, ^(UIView *v) { if ([NSStringFromClass(v.class) containsString:skip]) skipped = YES; });
        if (skipped) continue;
        CGFloat height = fixedSize ?: MAX(minSize, MIN(f.size.height, 48));
        CGFloat width = fixedSize ?: MAX(f.size.width, height);
        CGRect frame = CGRectMake(CGRectGetMidX(f) - width / 2, CGRectGetMidY(f) - height / 2, width, height);
        UIVisualEffectView *glass = glassAt(host, index++);
        glass.frame = frame;
        shapeGlass(glass, height / 2, YES);
    }
}

%hook _TtC20NowPlaying_ModesImpl18HeaderElementsUnit
- (void)viewDidLayoutSubviews {
    %orig;
    glassBehindRowChildren((UIViewController *)self, 36, 0, nil);
}
%end

// Shuffle, previous, next and repeat each get a circle; the white play button stays as it is.
%hook _TtC20NowPlaying_ModesImpl28PlaybackControlsElementsUnit
- (void)viewDidLayoutSubviews {
    %orig;
    glassBehindRowChildren((UIViewController *)self, 0, 52, @"PlayButton");
}
%end

%hook _TtC20NowPlaying_ModesImpl18FooterElementsUnit
- (void)viewDidLayoutSubviews {
    %orig;
    glassBehindRowChildren((UIViewController *)self, 36, 0, nil);
}
%end

#pragma mark - keep the stripped areas transparent when Spotify repaints them

%hook CALayer
- (void)setBackgroundColor:(CGColorRef)color {
    if (color && (sg_nowPlayingRoot || sg_tabBarRoot)) {
        UIView *view = (UIView *)self.delegate;
        if ([view isKindOfClass:UIView.class] && view.layer == self && !keepsColor(view)) {
            if (isInside(view, sg_nowPlayingRoot)) {
                if (looksLikeCard(view, color) && sg_nowPlayingCard != view) {
                    sg_nowPlayingCard = view;
                    UIView *bar = sg_nowPlayingRoot;
                    dispatch_async(dispatch_get_main_queue(), ^{ [bar.superview setNeedsLayout]; });
                }
                color = NULL;
            } else if (isInside(view, sg_tabBarRoot)) {
                color = NULL;
            }
        }
    }
    %orig(color);
}
%end

#pragma mark - Spotify's own Liquid Glass (Reprise_LiquidGlassKit)

%hook _TtC33Reprise_LiquidGlassPropertiesImpl25LiquidGlassPropertiesImpl
- (BOOL)isContextMenuInNavigationBarEnabled { return YES; }
%end

%hook SPTHubViewController
- (BOOL)prefersLiquidGlassNavigationBar { return YES; }
%end

#pragma mark - screen dumps (debug builds only, when FLEX is injected)

static NSString *hexColor(CGColorRef color) {
    CGFloat r = 0, g = 0, b = 0, a = 0;
    [[UIColor colorWithCGColor:color] getRed:&r green:&g blue:&b alpha:&a];
    return [NSString stringWithFormat:@"#%02X%02X%02X@%.2f", (int)(r * 255), (int)(g * 255), (int)(b * 255), a];
}

static void appendTree(UIView *view, NSUInteger depth, NSMutableString *out) {
    NSMutableString *line = [NSMutableString stringWithFormat:@"%*s%@ %@", (int)depth * 2, "", NSStringFromClass(view.class), NSStringFromCGRect(view.frame)];
    CGColorRef bg = view.layer.backgroundColor;
    if (bg && CGColorGetAlpha(bg) > 0) [line appendFormat:@" bg=%@", hexColor(bg)];
    if (view.layer.cornerRadius > 0) [line appendFormat:@" r=%.1f", view.layer.cornerRadius];
    if (view.alpha < 1) [line appendFormat:@" a=%.2f", view.alpha];
    if (view.hidden) [line appendString:@" hidden"];
    if (view.layer.mask) [line appendString:@" masked"];
    if (view.clipsToBounds) [line appendString:@" clips"];
    if ([view isKindOfClass:UILabel.class]) {
        UILabel *label = (UILabel *)view;
        [line appendFormat:@" \"%@\" %.0fpt %@", label.text, label.font.pointSize, hexColor(label.textColor.CGColor)];
    }
    if ([view isKindOfClass:UIImageView.class] && ((UIImageView *)view).image) {
        CGSize size = ((UIImageView *)view).image.size;
        [line appendFormat:@" img=%.0fx%.0f", size.width, size.height];
    }
    [out appendString:line];
    [out appendString:@"\n"];
    for (UIView *sub in view.subviews) appendTree(sub, depth + 1, out);
}

static void dumpScreen(NSString *reason) {
    NSMutableString *out = [NSMutableString string];
    UIViewController *root = nil;
    for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
        if (![scene isKindOfClass:UIWindowScene.class]) continue;
        for (UIWindow *window in ((UIWindowScene *)scene).windows) {
            if (window.hidden || [NSStringFromClass(window.class) containsString:@"FLEX"]) continue;
            if (!root || window.isKeyWindow) root = window.rootViewController;
            [out appendFormat:@"== window %@ level %.0f\n", window.class, window.windowLevel];
            appendTree(window, 0, out);
        }
    }
    if ([root respondsToSelector:@selector(_printHierarchy)]) {
        [out appendFormat:@"== view controllers\n%@\n", [root _printHierarchy]];
    }
    SGLogLong([@"screen dump " stringByAppendingString:reason], out);
}

static BOOL isDebugBuild(void) {
    return NSClassFromString(@"FLEXManager") != nil;
}

// Full screen player: dump its tree once it has appeared, so no background trick is needed.
%hook _TtC21NowPlaying_ScrollImpl23NPVScrollViewController
- (void)viewDidAppear:(BOOL)animated {
    %orig;
    if (!isDebugBuild()) return;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            dumpScreen(@"now playing view");
        });
    });
}
%end

#pragma mark - diagnostics

%ctor {
    %init;
    NSArray *targets = @[
        @"_TtC33Reprise_LiquidGlassPropertiesImpl25LiquidGlassPropertiesImpl",
        @"SPTHubViewController",
        @"_TtC23NavigationUI_TabBarImpl10TabBarView",
        @"_TtC23NavigationUI_TabBarImpl21TabBarItemElementView",
        @"_TtC25CreateMenu_TabBarItemImpl24CreateMenuTabBarItemView",
        @"_TtC18NowPlaying_BarImpl36NowPlayingBarContainerViewController",
        @"_TtC18NowPlaying_BarImpl27NowPlayingBarViewController",
        @"_TtC21NowPlaying_ScrollImpl23NPVScrollViewController",
        @"_TtC20NowPlaying_ModesImpl18HeaderElementsUnit",
        @"_TtC20NowPlaying_ModesImpl28PlaybackControlsElementsUnit",
        @"_TtC20NowPlaying_ModesImpl18FooterElementsUnit",
    ];
    for (NSString *name in targets) {
        if (!NSClassFromString(name)) SGLog(@"class %@ not found, its hooks are inactive", name);
    }
    SGLog(@"loaded, UIGlassEffect %@", NSClassFromString(@"UIGlassEffect") ? @"available" : @"missing");
    if (isDebugBuild()) {
        [NSNotificationCenter.defaultCenter addObserverForName:UIApplicationDidEnterBackgroundNotification object:nil queue:nil usingBlock:^(NSNotification *note) {
            dumpScreen(@"on background");
        }];
        SGLog(@"debug build: backgrounding the app dumps the visible screen's view tree");
    }
}
