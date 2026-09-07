#import "SGCommon.h"

__weak UIView *sg_nowPlayingRoot = nil;
__weak UIView *sg_tabBarRoot = nil;
__weak UIView *sg_nowPlayingCard = nil;
__weak UIView *sg_lyricsCardRoot = nil;
__weak UIView *sg_lyricsPageRoot = nil;
__weak UIView *sg_homeRoot = nil;

BOOL sg_nowPlayingStock = NO;
CGColorRef sg_nowPlayingCardColor = NULL;

// ui/Repaint.x takes the album colour off the card on every repaint; the expand animation of the
// full screen player needs it back, so the last one is kept. Only the main thread writes it, so
// the read in ui/NowPlayingBar.x cannot see a released colour.
void SGRememberCardColor(CGColorRef color) {
    if (!NSThread.isMainThread || color == sg_nowPlayingCardColor) return;
    CGColorRef kept = color ? CGColorRetain(color) : NULL;
    CGColorRelease(sg_nowPlayingCardColor);
    sg_nowPlayingCardColor = kept;
}

#pragma mark - logging

// The unified log cuts a message at about 1 KB, so long dumps go out as numbered parts.
void SGLogLong(NSString *tag, NSString *text) {
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

void SGRequireClasses(NSArray<NSString *> *names) {
    for (NSString *name in names) {
        if (!NSClassFromString(name)) SGLog(@"class %@ not found, its hooks are inactive", name);
    }
}

#pragma mark - switches

NSString *const SGKeyNowPlayingBar = @"spotifyglass.nowPlayingBar";
NSString *const SGKeyTabBar = @"spotifyglass.tabBar";
NSString *const SGKeyPlayer = @"spotifyglass.player";
NSString *const SGKeyLyricsCard = @"spotifyglass.lyricsCard";
NSString *const SGKeySearchField = @"spotifyglass.searchField";
NSString *const SGKeySpotifyGlass = @"spotifyglass.spotifyGlass";
NSString *const SGKeyAmoled = @"spotifyglass.amoled";
NSString *const SGKeyHomeGradient = @"spotifyglass.homeGradient";

BOOL SGFlag(NSString *key, BOOL fallback) {
    id value = [NSUserDefaults.standardUserDefaults objectForKey:key];
    return value ? [value boolValue] : fallback;
}

BOOL SGEnabled(NSString *key) {
    return SGFlag(key, YES);
}

BOOL SGHidden(NSString *key) {
    return SGFlag(key, NO);
}

void SGSetEnabled(NSString *key, BOOL on) {
    [NSUserDefaults.standardUserDefaults setBool:on forKey:key];
}

NSString *const SGKeyNavbar = @"spotifyglass.navbar";
NSString *const SGNavbarID = @"id";
NSString *const SGNavbarTitle = @"title";
NSString *const SGNavbarURI = @"uri";
NSString *const SGNavbarIcon = @"icon";
NSString *const SGNavbarHidden = @"hidden";

static NSString *const kNavbarLayout = @"spotifyglass.navbar.layout";
static NSString *const kNavbarStock = @"spotifyglass.navbar.stock";

// Only property list types go in, so a corrupt read cannot be anything but an array of dictionaries.
static NSArray *listOfKind(NSString *key, Class kind) {
    NSArray *list = [NSUserDefaults.standardUserDefaults arrayForKey:key];
    for (id item in list) if (![item isKindOfClass:kind]) return @[];
    return list ?: @[];
}

NSArray<NSDictionary *> *SGNavbarLayout(void) {
    return listOfKind(kNavbarLayout, NSDictionary.class);
}

void SGSetNavbarLayout(NSArray<NSDictionary *> *layout) {
    [NSUserDefaults.standardUserDefaults setObject:layout ?: @[] forKey:kNavbarLayout];
}

NSArray<NSString *> *SGNavbarStock(void) {
    return listOfKind(kNavbarStock, NSString.class);
}

void SGSetNavbarStock(NSArray<NSString *> *stock) {
    [NSUserDefaults.standardUserDefaults setObject:stock ?: @[] forKey:kNavbarStock];
}

NSString *const SGFlagOverridePrefix = @"spotifyglass.flag.";

id SGFlagOverride(NSString *key) {
    return [NSUserDefaults.standardUserDefaults objectForKey:[SGFlagOverridePrefix stringByAppendingString:key]];
}

void SGSetFlagOverride(NSString *key, id value) {
    key = [SGFlagOverridePrefix stringByAppendingString:key];
    if (value) [NSUserDefaults.standardUserDefaults setObject:value forKey:key];
    else [NSUserDefaults.standardUserDefaults removeObjectForKey:key];
}

#pragma mark - view tree

void SGForEachView(UIView *view, void (^fn)(UIView *)) {
    fn(view);
    for (UIView *sub in view.subviews) SGForEachView(sub, fn);
}

CGRect SGFrameIn(UIView *view, UIView *target) {
    return [view.superview convertRect:view.frame toView:target];
}

BOOL SGIsInside(UIView *view, UIView *root) {
    if (!root) return NO;
    for (UIView *v = view; v; v = v.superview) {
        if ([v isKindOfClass:UIVisualEffectView.class]) return NO;
        if (v == root) return YES;
    }
    return NO;
}

// Artwork, glyphs, text and thin lines (progress bar) keep their colour, everything else goes clear.
BOOL SGKeepsColor(UIView *view) {
    return [view isKindOfClass:UIImageView.class] || [view isKindOfClass:UILabel.class] || view.bounds.size.height <= 4;
}

void SGStripBackgrounds(UIView *view) {
    if ([view isKindOfClass:UIVisualEffectView.class]) return;
    if (!SGKeepsColor(view)) view.layer.backgroundColor = NULL;
    if ([view.layer isKindOfClass:CAGradientLayer.class] || [NSStringFromClass(view.class) containsString:@"GradientView"]) view.hidden = YES;
    for (CALayer *layer in view.layer.sublayers) {
        if ([layer isKindOfClass:CAGradientLayer.class]) layer.hidden = YES;
    }
    for (UIView *sub in view.subviews) SGStripBackgrounds(sub);
}

BOOL SGIsVisibleColor(CGColorRef color) {
    if (!color || CGColorGetAlpha(color) < 0.05) return NO;
    const CGFloat *c = CGColorGetComponents(color);
    size_t n = CGColorGetNumberOfComponents(color);
    CGFloat brightest = 0;
    for (size_t i = 0; i + 1 < n; i++) brightest = MAX(brightest, c[i]);
    return brightest > 0.08;
}

BOOL SGIsLightColor(CGColorRef color) {
    if (!color || CGColorGetAlpha(color) < 0.5) return NO;
    const CGFloat *c = CGColorGetComponents(color);
    size_t n = CGColorGetNumberOfComponents(color);
    for (size_t i = 0; i + 1 < n; i++) if (c[i] < 0.85) return NO;
    return YES;
}

// Spotify's base surface: the neutral #121212 it paints its pages with, or the black ui/Amoled.x
// turns that into. Lighter greys (#1F1F1F placeholders, #292929 cards) and translucent paint stay.
BOOL SGIsBaseSurface(CGColorRef color) {
    if (!color || CFGetTypeID(color) != CGColorGetTypeID() || CGColorGetAlpha(color) < 0.95) return NO;
    const CGFloat *c = CGColorGetComponents(color);
    size_t n = CGColorGetNumberOfComponents(color);
    if (n == 2) return c[0] <= 0.10;
    if (n < 3) return NO;
    return c[0] <= 0.10 && fabs(c[0] - c[1]) < 0.02 && fabs(c[1] - c[2]) < 0.02;
}

BOOL SGHasClass(UIView *root, NSString *marker) {
    __block BOOL found = NO;
    SGForEachView(root, ^(UIView *v) {
        if (!found && [NSStringFromClass(v.class) containsString:marker]) found = YES;
    });
    return found;
}

// The first wide stack view under `host` with at least two arranged children: a player row, or
// the row of items in the tab bar.
UIStackView *SGRowIn(UIView *host) {
    __block UIStackView *row = nil;
    SGForEachView(host, ^(UIView *v) {
        if (!row && [v isKindOfClass:UIStackView.class] && v.bounds.size.width > 200 && ((UIStackView *)v).arrangedSubviews.count >= 2) row = (UIStackView *)v;
    });
    return row;
}

BOOL SGLooksLikeCard(UIView *view, CGColorRef color) {
    CGSize size = view.bounds.size;
    return size.height >= 40 && size.height <= 140 && size.width >= 200 && SGIsVisibleColor(color);
}

#pragma mark - glass

static UIVisualEffect *glassEffect(void) {
    Class glass = NSClassFromString(@"UIGlassEffect");
    if (glass) return [[glass alloc] init];
    return [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemChromeMaterialDark];
}

static UIVisualEffectView *newPane(void) {
    UIVisualEffectView *glass = [[UIVisualEffectView alloc] initWithEffect:glassEffect()];
    glass.userInteractionEnabled = NO;
    return glass;
}

// One pane per host and key, kept behind the host's own content.
UIVisualEffectView *SGGlassFor(UIView *host, const void *key) {
    UIVisualEffectView *glass = objc_getAssociatedObject(host, key);
    if (!glass) {
        glass = newPane();
        objc_setAssociatedObject(host, key, glass, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    if (glass.superview != host) [host insertSubview:glass atIndex:0];
    return glass;
}

// Several panes on one host, addressed by index.
static char kPanesKey;

UIVisualEffectView *SGGlassAt(UIView *host, NSUInteger index) {
    NSMutableArray<UIVisualEffectView *> *panes = objc_getAssociatedObject(host, &kPanesKey);
    if (!panes) {
        panes = [NSMutableArray array];
        objc_setAssociatedObject(host, &kPanesKey, panes, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    while (panes.count <= index) [panes addObject:newPane()];
    UIVisualEffectView *glass = panes[index];
    glass.hidden = NO;
    if (glass.superview != host) [host insertSubview:glass atIndex:0];
    return glass;
}

// Panes past `count` belonged to children that are gone now.
void SGHideGlassFrom(UIView *host, NSUInteger count) {
    NSArray<UIVisualEffectView *> *panes = objc_getAssociatedObject(host, &kPanesKey);
    for (NSUInteger i = count; i < panes.count; i++) panes[i].hidden = YES;
}

// Glass takes its shape from cornerConfiguration on iOS 26; layer.cornerRadius is the fallback.
void SGShapeGlass(UIView *glass, CGFloat radius, BOOL capsule) {
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
