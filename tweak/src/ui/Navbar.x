// Navbar: which tabs the bar shows, in what order, and tabs of the mod's own that open any
// spotify: URI. Spotify keeps its four items (Home, Search, Library, Create) as the arranged
// subviews of one stack view, but a tap on one of them is answered by counting the row off from
// the left, not by asking the item what it is: moved in the stack, an item takes the tap of
// whatever used to stand there. So the stack's own order is left exactly as Spotify built it.
//
// The row is split into equal slots instead, and the wanted order is a translation per item:
// hit testing goes by frame, so the touch follows the icon, while Spotify still counts its items
// off in the order it put them in. Items of the mod's own go on the end of the stack, past that
// count, and are translated into place with the rest. A tap on one goes through Spotify's link
// dispatcher, the same route the app takes for a link it opens itself, so any URI works.
//
// Tree (trees/home.txt): NavigationUI_TabBarImpl.TabBarView > TabBarCompactView > UIStackView
//   402x49 of four ElementContentView<TabBarItemElement> 100x49, each an SPTEncoreIconView 24x24
//   at y 12.5 over an SPTEncoreLabel at y 35.
#import "SGCommon.h"
#import <objc/message.h>

// Spotify's own, resolved at runtime: SpotifyShared has the icons, the app the link dispatcher.
@interface SPTEncoreIconView : UIView
- (instancetype)initWithIcon:(id)icon;
- (void)setForegroundColor:(UIColor *)color;
@end

@interface SGLinkDispatcher : NSObject
- (void)navigateToURI:(NSURL *)uri options:(long long)options interactionID:(id)interactionID;
@end

static const CGFloat kIconSize = 24;
static const CGFloat kIconTop = 12.5;
static const CGFloat kLabelTop = 35;
static const CGFloat kLabelHeight = 14;
static char kCustomKey;

// Where Spotify's own items keep their icon and label, read off one of them every pass. ui/TabBar.x
// moves the icons when the glass bar is on, and this follows a pass later, so an item of the mod's
// own sits on the same line as its neighbours either way.
static CGRect sg_iconBox = {{0, kIconTop}, {kIconSize, kIconSize}};
static CGRect sg_labelBox = {{0, kLabelTop}, {0, kLabelHeight}};

static __weak SGLinkDispatcher *sg_linkDispatcher;
static __weak UIView *sg_navbarRoot;
static UIFont *sg_tabFont;
// Spotify's own tabs in Spotify's order, from the first layout pass of this launch, before
// anything below has moved them.
static NSMutableArray<NSString *> *sg_stockOrder;

static UIColor *itemColor(void) { return [UIColor colorWithWhite:0xB3 / 255.0 alpha:1]; }

#pragma mark - the mod's own items

// One of the 538 glyphs SPTEncoreIcon exposes, one class method each ("podcasts", "heart"), so an
// item of the mod's own is drawn the same way as Spotify's. An SF Symbol stands in if the name is
// not one of them.
static UIView *iconView(NSString *name) {
    Class icon = NSClassFromString(@"SPTEncoreIcon");
    Class view = NSClassFromString(@"SPTEncoreIconView");
    SEL glyphSel = NSSelectorFromString(name.length ? name : @"star");
    if (icon && view && [icon respondsToSelector:glyphSel]) {
        id (*glyphFor)(id, SEL) = (id (*)(id, SEL))objc_msgSend;
        id glyph = glyphFor(icon, glyphSel);
        SPTEncoreIconView *encore = glyph ? [[view alloc] initWithIcon:glyph] : nil;
        if (encore) {
            [encore setForegroundColor:itemColor()];
            return encore;
        }
    }
    UIImage *image = [UIImage systemImageNamed:@"star.fill" withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:19 weight:UIImageSymbolWeightSemibold]];
    UIImageView *fallback = [[UIImageView alloc] initWithImage:image];
    fallback.tintColor = itemColor();
    fallback.contentMode = UIViewContentModeCenter;
    return fallback;
}

@interface SGTabItemView : UIControl
@property (nonatomic, copy) NSString *uri;
- (instancetype)initWithEntry:(NSDictionary *)entry;
- (void)applyEntry:(NSDictionary *)entry;
@end

@implementation SGTabItemView {
    NSString *_iconName;
    UIView *_icon;
    UILabel *_title;
}

- (instancetype)initWithEntry:(NSDictionary *)entry {
    if (!(self = [super initWithFrame:CGRectZero])) return nil;
    _title = [UILabel new];
    _title.textAlignment = NSTextAlignmentCenter;
    _title.textColor = itemColor();
    [self addSubview:_title];
    [self applyEntry:entry];
    [self addTarget:self action:@selector(open) forControlEvents:UIControlEventTouchUpInside];
    return self;
}

- (void)applyEntry:(NSDictionary *)entry {
    self.uri = entry[SGNavbarURI];
    _title.text = entry[SGNavbarTitle];
    NSString *name = entry[SGNavbarIcon] ?: @"star";
    if ([name isEqualToString:_iconName]) return;
    [_icon removeFromSuperview];
    _iconName = [name copy];
    _icon = iconView(name);
    // Encore's views lay themselves out from constraints; this one is placed by frame.
    _icon.translatesAutoresizingMaskIntoConstraints = YES;
    [self addSubview:_icon];
}

// Both boxes come off a neighbour, so whatever Spotify or ui/TabBar.x does to the row's line-up
// is copied rather than guessed at; only the horizontal centring is the item's own.
- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat width = self.bounds.size.width;
    _title.hidden = SGEnabled(SGKeyTabBar);
    _title.font = sg_tabFont ?: [UIFont systemFontOfSize:10];
    _title.frame = CGRectMake(0, CGRectGetMinY(sg_labelBox), width, CGRectGetHeight(sg_labelBox));
    _icon.frame = CGRectMake((width - CGRectGetWidth(sg_iconBox)) / 2, CGRectGetMinY(sg_iconBox),
                             CGRectGetWidth(sg_iconBox), CGRectGetHeight(sg_iconBox));
}

// A row that splits its width evenly ignores this, but one that sizes itself to its content would
// otherwise have nothing to go on for an item of ours.
- (CGSize)intrinsicContentSize {
    return CGSizeMake(kIconSize * 2, kLabelTop + kLabelHeight);
}

- (void)setHighlighted:(BOOL)highlighted {
    [super setHighlighted:highlighted];
    self.alpha = highlighted ? 0.5 : 1;
}

- (void)open {
    NSURL *url = self.uri.length ? [NSURL URLWithString:self.uri] : nil;
    SGLinkDispatcher *dispatcher = sg_linkDispatcher;
    if (!url || ![dispatcher respondsToSelector:@selector(navigateToURI:options:interactionID:)]) {
        SGLog(@"navbar: cannot open %@, dispatcher %@", self.uri, dispatcher);
        return;
    }
    [dispatcher navigateToURI:url options:0 interactionID:nil];
}

@end

#pragma mark - composition

// Spotify's items are told apart by the label under the icon: it survives the element views being
// rebuilt, and it is the name the Navbar page lists them under.
static NSString *stockID(UIView *item) {
    __block NSString *text = nil;
    SGForEachView(item, ^(UIView *v) {
        if (!text && [v isKindOfClass:UILabel.class] && ((UILabel *)v).text.length) text = ((UILabel *)v).text;
    });
    return text ?: NSStringFromClass(item.class);
}

static void measureItem(UIView *item) {
    __block UIView *icon = nil, *label = nil;
    SGForEachView(item, ^(UIView *v) {
        if (!icon && [NSStringFromClass(v.class) containsString:@"IconView"] && v.bounds.size.width > 1) icon = v;
        if (!label && [v isKindOfClass:UILabel.class] && ((UILabel *)v).text.length) label = v;
    });
    if (icon) sg_iconBox = SGFrameIn(icon, item);
    if (!label) return;
    sg_labelBox = SGFrameIn(label, item);
    if (!sg_tabFont) sg_tabFont = ((UILabel *)label).font;
}

static NSMutableDictionary<NSString *, SGTabItemView *> *customItems(UIStackView *stack) {
    NSMutableDictionary *items = objc_getAssociatedObject(stack, &kCustomKey);
    if (!items) {
        items = [NSMutableDictionary dictionary];
        objc_setAssociatedObject(stack, &kCustomKey, items, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return items;
}

void SGComposeTabBar(UIView *tabBar) {
    UIStackView *stack = SGRowIn(tabBar);
    if (!stack) return;
    sg_navbarRoot = tabBar;

    NSMutableDictionary<NSString *, UIView *> *stockViews = [NSMutableDictionary dictionary];
    for (UIView *item in stack.arrangedSubviews) {
        if ([item isKindOfClass:SGTabItemView.class]) continue;
        NSString *ident = stockID(item);
        if (stockViews[ident]) continue;
        stockViews[ident] = item;
        measureItem(item);
        if (!sg_stockOrder) sg_stockOrder = [NSMutableArray array];
        if (![sg_stockOrder containsObject:ident]) [sg_stockOrder addObject:ident];
    }
    if (sg_stockOrder && ![sg_stockOrder isEqualToArray:SGNavbarStock()]) SGSetNavbarStock(sg_stockOrder);

    NSMutableDictionary<NSString *, SGTabItemView *> *custom = customItems(stack);
    NSMutableArray<UIView *> *wanted = [NSMutableArray array];
    NSMutableSet<NSString *> *placed = [NSMutableSet set];
    NSMutableSet<NSString *> *keep = [NSMutableSet set];

    if (SGEnabled(SGKeyNavbar)) {
        for (NSDictionary *entry in SGNavbarLayout()) {
            NSString *ident = entry[SGNavbarID];
            if (![ident isKindOfClass:NSString.class] || [placed containsObject:ident]) continue;
            [placed addObject:ident];
            BOOL hidden = [entry[SGNavbarHidden] boolValue];
            if (entry[SGNavbarURI]) {
                if (hidden) continue;
                SGTabItemView *item = custom[ident];
                if (item) [item applyEntry:entry];
                else custom[ident] = item = [[SGTabItemView alloc] initWithEntry:entry];
                [keep addObject:ident];
                [wanted addObject:item];
            } else if (stockViews[ident]) {
                stockViews[ident].hidden = hidden;
                [wanted addObject:stockViews[ident]];
            }
        }
    }
    // Tabs of Spotify's the list does not name — or named before Spotify had built them — keep
    // Spotify's own place, at the end, shown.
    for (NSString *ident in sg_stockOrder) {
        UIView *item = stockViews[ident];
        if (!item || [wanted containsObject:item]) continue;
        item.hidden = NO;
        [wanted addObject:item];
    }
    for (NSString *ident in custom.allKeys) {
        if ([keep containsObject:ident]) continue;
        [custom[ident] removeFromSuperview];
        [custom removeObjectForKey:ident];
    }

    // A bar with nothing on it would strand whoever emptied it, so the last word is Spotify's.
    BOOL empty = YES;
    for (UIView *item in wanted) if (!item.hidden) empty = NO;
    if (empty) for (UIView *item in wanted) item.hidden = NO;

    // Items of the mod's own join the stack at the end, where they are past whatever Spotify
    // counts, and Spotify's own keep the places it gave them.
    for (UIView *item in wanted) {
        if ([item isKindOfClass:SGTabItemView.class] && item.superview != stack) [stack addArrangedSubview:item];
    }
    // Spotify sizes the row for the four items it ships; equal slots for whatever is on it now
    // keeps a fifth from running off the right edge, and makes the order a whole slot's shift.
    if (stack.distribution != UIStackViewDistributionFillEqually) stack.distribution = UIStackViewDistributionFillEqually;

    NSMutableArray<UIView *> *slots = [NSMutableArray array];
    for (UIView *item in stack.arrangedSubviews) if (!item.hidden) [slots addObject:item];
    NSMutableArray<UIView *> *order = [NSMutableArray array];
    for (UIView *item in wanted) if (!item.hidden && [slots containsObject:item]) [order addObject:item];
    CGFloat slotWidth = slots.count ? stack.bounds.size.width / slots.count : 0;

    for (UIView *item in stack.arrangedSubviews) {
        NSUInteger from = [slots indexOfObject:item], to = [order indexOfObject:item];
        CGAffineTransform shift = from == NSNotFound || to == NSNotFound
            ? CGAffineTransformIdentity
            : CGAffineTransformMakeTranslation(((CGFloat)to - (CGFloat)from) * slotWidth, 0);
        if (!CGAffineTransformEqualToTransform(item.transform, shift)) item.transform = shift;
    }
}

void SGRefreshTabBar(void) {
    [sg_navbarRoot setNeedsLayout];
}

// What the row settled on, logged whenever it changes: `make log` then says whether the items fit,
// what is holding their width, and in what order the bar ended up.
void SGLogTabBarRow(UIView *tabBar) {
    UIStackView *stack = SGRowIn(tabBar);
    if (!stack) return;
    NSMutableString *out = [NSMutableString stringWithFormat:@"row in %@ %@, icon %@ label %@, stack %@ axis %ld dist %ld align %ld spacing %.1f autolayout %d",
                            NSStringFromClass(tabBar.class), NSStringFromCGRect(tabBar.frame),
                            NSStringFromCGRect(sg_iconBox), NSStringFromCGRect(sg_labelBox), NSStringFromCGRect(stack.frame),
                            (long)stack.axis, (long)stack.distribution, (long)stack.alignment, stack.spacing,
                            !stack.translatesAutoresizingMaskIntoConstraints];
    NSUInteger index = 0;
    for (UIView *item in stack.arrangedSubviews) {
        [out appendFormat:@"\n  %lu %@ %@%@ shift %.1f autolayout %d", (unsigned long)index++, NSStringFromClass(item.class),
             NSStringFromCGRect(item.frame), item.hidden ? @" hidden" : @"", item.transform.tx,
             !item.translatesAutoresizingMaskIntoConstraints];
        for (NSLayoutConstraint *c in item.constraints) {
            if (c.firstAttribute == NSLayoutAttributeWidth || c.secondAttribute == NSLayoutAttributeWidth) [out appendFormat:@"\n    %@", c];
        }
    }
    for (NSLayoutConstraint *c in stack.constraints) [out appendFormat:@"\n  own %@", c];
    for (NSLayoutConstraint *c in stack.superview.constraints) {
        if (c.firstItem == stack || c.secondItem == stack) [out appendFormat:@"\n  held %@", c];
    }
    static NSString *last;
    if ([out isEqualToString:last]) return;
    last = [out copy];
    SGLogLong(@"navbar", out);
}

// Whether Spotify reads its own item list through this ObjC bridge decides whether the bar can be
// composed at the model level, where the order, the taps and the widths would all follow by
// themselves, instead of by moving views about. Silence in the log says it cannot.
%hook _TtC28NavigationUI_TabBarItemsImpl29TabBarItemsNavigationListImpl
- (NSArray *)items {
    NSArray *items = %orig;
    NSMutableString *out = [NSMutableString stringWithFormat:@"list read, %lu items", (unsigned long)items.count];
    for (id item in items) [out appendFormat:@"\n  %@ · %@", [item valueForKey:@"title"], [item valueForKey:@"viewURI"]];
    static NSString *last;
    if (![out isEqualToString:last]) {
        last = [out copy];
        SGLogLong(@"navbar", out);
    }
    return items;
}
%end

// The dispatcher is a singleton the app builds at startup; this is the last call of its setup.
%hook SPTLinkDispatcherImplementation
- (void)setMainUILoaded:(BOOL)loaded {
    %orig;
    sg_linkDispatcher = (SGLinkDispatcher *)self;
}
%end

%ctor {
    %init;
    SGRequireClasses(@[
        @"SPTLinkDispatcherImplementation",
        @"SPTEncoreIcon",
        @"SPTEncoreIconView",
        @"_TtC28NavigationUI_TabBarItemsImpl29TabBarItemsNavigationListImpl",
    ]);
}
