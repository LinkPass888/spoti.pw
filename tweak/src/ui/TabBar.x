// Tab bar: gradient and labels go, icons centre, a glass capsule sits behind Home, Search and
// Library and a glass circle behind Create. Spotify maps taps by position, so the item order stays.
//
// Tree (trees/home.txt): NavigationUI_TabBarImpl.TabBarView > TabBarCompactView > TabBarGradientView
//   + UIStackView 402x49 of four ElementContentView<TabBarItemElement> 100x49, each with an
//   SPTEncoreIconView 24x24 and an SPTEncoreLabel.
#import "SGCommon.h"

static const CGFloat kPillHeight = 56;
static const CGFloat kCircleSize = 52;
static char kPillKey, kCircleKey;

static NSArray<UIView *> *tabItems(UIView *tabBar) {
    NSMutableArray<UIView *> *items = [NSMutableArray array];
    SGForEachView(tabBar, ^(UIView *v) {
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
    SGStripBackgrounds(tabBar);
    tabBar.superview.layer.backgroundColor = NULL;

    NSArray<UIView *> *items = tabItems(tabBar);
    static dispatch_once_t once;
    dispatch_once(&once, ^{ SGLog(@"tab bar %@ with %lu items", tabBar.class, (unsigned long)items.count); });
    if (items.count < 2) return;

    NSArray<UIView *> *sorted = [items sortedArrayUsingComparator:^NSComparisonResult(UIView *a, UIView *b) {
        return [@(SGFrameIn(a, tabBar).origin.x) compare:@(SGFrameIn(b, tabBar).origin.x)];
    }];
    CGRect first = SGFrameIn(sorted.firstObject, tabBar);
    CGRect lastMain = SGFrameIn(sorted[sorted.count - 2], tabBar);
    CGRect last = SGFrameIn(sorted.lastObject, tabBar);
    CGFloat midY = CGRectGetMidY(first);

    UIVisualEffectView *pill = SGGlassFor(tabBar, &kPillKey);
    CGFloat left = MAX(12, first.origin.x + 12);
    pill.frame = CGRectMake(left, midY - kPillHeight / 2, CGRectGetMaxX(lastMain) + 4 - left, kPillHeight);
    SGShapeGlass(pill, kPillHeight / 2, YES);

    UIVisualEffectView *circle = SGGlassFor(tabBar, &kCircleKey);
    circle.frame = CGRectMake(CGRectGetMidX(last) - kCircleSize / 2, midY - kCircleSize / 2, kCircleSize, kCircleSize);
    SGShapeGlass(circle, kCircleSize / 2, YES);
}

// Items lay out their own icon and label, after the bar; hide the label, centre the icon, then
// restyle the bar, whose own pass ran before the items had frames.
static void styleTabItem(UIView *item) {
    CGFloat midY = CGRectGetMidY(item.bounds);
    SGForEachView(item, ^(UIView *v) {
        if ([v isKindOfClass:UILabel.class]) {
            v.alpha = 0;
        } else if ([NSStringFromClass(v.class) containsString:@"IconView"]) {
            CGPoint target = [item convertPoint:CGPointMake(0, midY) toView:v.superview];
            v.center = CGPointMake(v.center.x, target.y);
        }
    });
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
    styleTabItem((UIView *)self);
}
%end

%hook _TtC25CreateMenu_TabBarItemImpl24CreateMenuTabBarItemView
- (void)layoutSubviews {
    %orig;
    styleTabItem((UIView *)self);
}
%end

%ctor {
    %init;
    SGRequireClasses(@[
        @"_TtC23NavigationUI_TabBarImpl10TabBarView",
        @"_TtC23NavigationUI_TabBarImpl21TabBarItemElementView",
        @"_TtC25CreateMenu_TabBarItemImpl24CreateMenuTabBarItemView",
    ]);
}
