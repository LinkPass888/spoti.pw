// Tab bar: gradient and labels go, icons centre, a glass capsule sits behind the tabs and a glass
// circle behind Create when Create is the last of them. ui/Navbar.x owns which items are on the
// bar and in what order; this file only paints whatever it left there.
//
// Tree (trees/home.txt): NavigationUI_TabBarImpl.TabBarView > TabBarCompactView > TabBarGradientView
//   + UIStackView 402x49 of four ElementContentView<TabBarItemElement> 100x49, each with an
//   SPTEncoreIconView 24x24 and an SPTEncoreLabel.
#import "SGCommon.h"

static const CGFloat kPillHeight = 56;
static const CGFloat kCircleSize = 52;
static char kPillKey, kCircleKey;

// The items the bar shows, left to right. ui/Navbar.x leaves the stack in Spotify's order and
// shifts the items across it, so the row reads by position on screen, not by arranged order.
static NSArray<UIView *> *tabItems(UIView *tabBar) {
    NSMutableArray<UIView *> *items = [NSMutableArray array];
    for (UIView *item in SGRowIn(tabBar).arrangedSubviews) {
        if (!item.hidden && item.bounds.size.width >= 20) [items addObject:item];
    }
    return [items sortedArrayUsingComparator:^NSComparisonResult(UIView *a, UIView *b) {
        return [@(SGFrameIn(a, tabBar).origin.x) compare:@(SGFrameIn(b, tabBar).origin.x)];
    }];
}

static void styleTabBar(UIView *tabBar) {
    if (!SGEnabled(SGKeyTabBar)) return;
    sg_tabBarRoot = tabBar;
    SGStripBackgrounds(tabBar);
    tabBar.superview.layer.backgroundColor = NULL;

    NSArray<UIView *> *items = tabItems(tabBar);
    static dispatch_once_t once;
    dispatch_once(&once, ^{ SGLog(@"tab bar %@ with %lu items", tabBar.class, (unsigned long)items.count); });
    if (items.count < 2) return;

    // Create is a round button of its own, but only where Spotify puts it: last. Moved in among
    // the others by ui/Navbar.x it joins them under the capsule instead.
    BOOL circled = SGHasClass(items.lastObject, @"CreateMenu");
    NSArray<UIView *> *capsuled = circled ? [items subarrayWithRange:NSMakeRange(0, items.count - 1)] : items;
    CGRect first = SGFrameIn(items.firstObject, tabBar);
    CGFloat midY = CGRectGetMidY(first);

    UIVisualEffectView *pill = SGGlassFor(tabBar, &kPillKey);
    pill.hidden = capsuled.count == 0;
    if (capsuled.count) {
        CGFloat left = MAX(12, first.origin.x + 12);
        pill.frame = CGRectMake(left, midY - kPillHeight / 2, CGRectGetMaxX(SGFrameIn(capsuled.lastObject, tabBar)) + 4 - left, kPillHeight);
        SGShapeGlass(pill, kPillHeight / 2, YES);
    }

    UIVisualEffectView *circle = SGGlassFor(tabBar, &kCircleKey);
    circle.hidden = !circled;
    if (circled) {
        CGRect last = SGFrameIn(items.lastObject, tabBar);
        circle.frame = CGRectMake(CGRectGetMidX(last) - kCircleSize / 2, midY - kCircleSize / 2, kCircleSize, kCircleSize);
        SGShapeGlass(circle, kCircleSize / 2, YES);
    }
}

static UIView *tabBarOf(UIView *item) {
    Class barClass = NSClassFromString(@"_TtC23NavigationUI_TabBarImpl10TabBarView");
    for (UIView *v = item.superview; v; v = v.superview) if ([v isKindOfClass:barClass]) return v;
    return nil;
}

// Items lay out their own icon and label, after the bar; hide the label, centre the icon, then
// restyle the bar, whose own pass ran before the items had frames.
static void styleTabItem(UIView *item) {
    if (!SGEnabled(SGKeyTabBar)) return;
    CGFloat midY = CGRectGetMidY(item.bounds);
    SGForEachView(item, ^(UIView *v) {
        if ([v isKindOfClass:UILabel.class]) {
            v.alpha = 0;
        } else if ([NSStringFromClass(v.class) containsString:@"IconView"]) {
            CGPoint target = [item convertPoint:CGPointMake(0, midY) toView:v.superview];
            v.center = CGPointMake(v.center.x, target.y);
        }
    });
    UIView *bar = tabBarOf(item);
    if (bar) styleTabBar(bar);
}

%hook _TtC23NavigationUI_TabBarImpl10TabBarView
- (void)layoutSubviews {
    %orig;
    // After Spotify's own pass, so whatever it did to the row of items is undone before the glass
    // is measured against it; the layoutIfNeeded below gives the moved items their frames.
    SGComposeTabBar((UIView *)self);
    for (UIView *sub in ((UIView *)self).subviews) [sub layoutIfNeeded];
    styleTabBar((UIView *)self);
    SGLogTabBarRow((UIView *)self);
}
%end

// The bar's own pass runs once, before Spotify has filled the row, and does not run again until
// something touches it; the items lay out as they arrive, which is when the order is ours to set.
static void itemDidLayOut(UIView *item) {
    UIView *bar = tabBarOf(item);
    if (!bar) return;
    SGComposeTabBar(bar);
    styleTabItem(item);
    SGLogTabBarRow(bar);
}

%hook _TtC23NavigationUI_TabBarImpl21TabBarItemElementView
- (void)layoutSubviews {
    %orig;
    itemDidLayOut((UIView *)self);
}
%end

%hook _TtC25CreateMenu_TabBarItemImpl24CreateMenuTabBarItemView
- (void)layoutSubviews {
    %orig;
    itemDidLayOut((UIView *)self);
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
