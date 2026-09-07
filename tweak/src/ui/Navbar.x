// Navbar: which tabs the bar shows, in what order, and tabs of the mod's own that open any
// spotify: URI. Spotify keeps its four items (Home, Search, Library, Create) as the arranged
// subviews of one stack view, each item handling its own tap, so the order is ours to change:
// this file rewrites the stack on every layout pass, hides the items switched off and slots its
// own item views between them. Spotify's own updates to the bar are undone on the pass after.
//
// A tap on an item of the mod's own goes through Spotify's link dispatcher, the same route the
// app takes for a link it opens itself, so any URI that resolves to a page works.
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

static __weak SGLinkDispatcher *sg_linkDispatcher;
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

// The item keeps Spotify's own geometry, and follows ui/TabBar.x when the glass tab bar is on:
// no label, the icon centred in the item instead.
- (void)layoutSubviews {
    [super layoutSubviews];
    BOOL glass = SGEnabled(SGKeyTabBar);
    CGSize size = self.bounds.size;
    _title.hidden = glass;
    _title.font = sg_tabFont ?: [UIFont systemFontOfSize:10];
    _title.frame = CGRectMake(0, kLabelTop, size.width, kLabelHeight);
    CGFloat top = glass ? (size.height - kIconSize) / 2 : kIconTop;
    _icon.frame = CGRectMake((size.width - kIconSize) / 2, top, kIconSize, kIconSize);
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

static void rememberFont(UIView *item) {
    if (sg_tabFont) return;
    SGForEachView(item, ^(UIView *v) {
        if (!sg_tabFont && [v isKindOfClass:UILabel.class] && ((UILabel *)v).text.length) sg_tabFont = ((UILabel *)v).font;
    });
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

    NSMutableDictionary<NSString *, UIView *> *stockViews = [NSMutableDictionary dictionary];
    for (UIView *item in stack.arrangedSubviews) {
        if ([item isKindOfClass:SGTabItemView.class]) continue;
        NSString *ident = stockID(item);
        if (stockViews[ident]) continue;
        stockViews[ident] = item;
        rememberFont(item);
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

    for (NSUInteger i = 0; i < wanted.count; i++) {
        UIView *item = wanted[i];
        if (item.superview == stack && [stack.arrangedSubviews indexOfObject:item] == i) continue;
        [stack insertArrangedSubview:item atIndex:i];
    }
}

// The dispatcher is a singleton the app builds at startup; this is the last call of its setup.
%hook SPTLinkDispatcherImplementation
- (void)setMainUILoaded:(BOOL)loaded {
    %orig;
    sg_linkDispatcher = (SGLinkDispatcher *)self;
}
%end

%ctor {
    %init;
    SGRequireClasses(@[@"SPTLinkDispatcherImplementation", @"SPTEncoreIcon", @"SPTEncoreIconView"]);
}
