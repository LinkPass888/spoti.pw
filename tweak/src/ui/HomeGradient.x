// Home gradient: a green wash behind the top of the Home tab, strongest under the avatar and the
// pills and out by the second shelf, like the gradient Spotify's own Home used to have. The wash
// is a layer inside the page's scroll view, under its content, so it scrolls away with the
// shelves; the base grey the page and the shelves paint over it goes clear in ui/Repaint.x, and
// Spotify's own scrim behind the header goes with it, since it would only mute the colour.
//
// Tree (trees/home.txt): FunkisViewController.view holds the page, a 402x112 wrapper around
// LiquidGlass.GradientView (the scrim under the avatar and the pills) and HomeHeaderView. Four
// views down, EvoLoadableResourceViewController.view holds the one
// Home_CarouselKit.TouchCancellingCollectionView of the page, full screen and inset 112pt at the
// top for the header, painted #121212; the shelves inside it are collection views of their own,
// painted #121212 as well.
#import "SGCommon.h"

// Sampled off the design: #0B4110 at the top of the screen, level behind the header, gone by 390pt.
static UIColor *tint(void) { return [UIColor colorWithRed:0x0B / 255.0 green:0x41 / 255.0 blue:0x10 / 255.0 alpha:1]; }
static const CGFloat kFadeHeight = 390;
static const CGFloat kLevelHeight = 52;
// Colour above the content as well, for the rubber band of an overscroll to pull down into.
static const CGFloat kOverscroll = 600;

static char kGradientKey, kStrippedKey;

// A view of its own, so the wash follows the page's layout passes instead of animating itself
// through CoreAnimation whenever the inset changes.
@interface SGHomeGradientView : UIView
@end

@implementation SGHomeGradientView
+ (Class)layerClass {
    return CAGradientLayer.class;
}
@end

// The shelves and the shortcuts grid are lists of their own, each painting the base surface over
// the wash. A cell paints itself before the page puts it in, where the hook in ui/Repaint.x cannot
// see that it belongs to Home, so every cell is stripped once as it turns up; the repaints it
// takes later, in the page by then, go through the hook. The page's own paint is behind the wash.
static void stripCells(UIScrollView *list) {
    for (UIView *cell in list.subviews) {
        if (objc_getAssociatedObject(cell, &kStrippedKey)) continue;
        objc_setAssociatedObject(cell, &kStrippedKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        SGForEachView(cell, ^(UIView *v) {
            if (SGIsBaseSurface(v.layer.backgroundColor)) v.layer.backgroundColor = NULL;
        });
    }
}

static SGHomeGradientView *gradientIn(UIScrollView *list) {
    SGHomeGradientView *view = objc_getAssociatedObject(list, &kGradientKey);
    if (!view) {
        view = [SGHomeGradientView new];
        view.userInteractionEnabled = NO;
        CGFloat height = kOverscroll + kFadeHeight;
        CAGradientLayer *gradient = (CAGradientLayer *)view.layer;
        gradient.colors = @[(id)tint().CGColor, (id)tint().CGColor, (id)[tint() colorWithAlphaComponent:0].CGColor];
        gradient.locations = @[@0, @((kOverscroll + kLevelHeight) / height), @1];
        // A list puts its cells in at index 0, so that its scroll indicators stay on top of them;
        // the subview order alone would push the wash over the content. Depth settles it instead.
        view.layer.zPosition = -1;
        objc_setAssociatedObject(list, &kGradientKey, view, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        SGLog(@"home gradient behind %@", NSStringFromClass(list.class));
    }
    if (view.superview != list) [list insertSubview:view atIndex:0];
    return view;
}

// Content coordinates: the content starts below the header, so the wash starts at minus the inset,
// where the top of the screen is when the list sits still.
static void layoutGradient(UIScrollView *list) {
    SGHomeGradientView *view = gradientIn(list);
    if (sg_homeRoot != list) sg_homeRoot = list;
    stripCells(list);
    CGRect frame = CGRectMake(0, -kOverscroll - list.adjustedContentInset.top,
                              list.bounds.size.width, kOverscroll + kFadeHeight);
    if (!CGRectEqualToRect(view.frame, frame)) view.frame = frame;
}

// The one collection view of the page; the shelves are collection views nested inside it.
static UIScrollView *pageList(UIView *view) {
    for (UIView *sub in view.subviews) {
        if ([sub isKindOfClass:UICollectionView.class]) return (UIScrollView *)sub;
    }
    return nil;
}

%hook _TtC16Home_EvoPageImpl33EvoLoadableResourceViewController
- (void)viewDidLayoutSubviews {
    %orig;
    UIScrollView *list = pageList(((UIViewController *)self).viewIfLoaded);
    if (list) layoutGradient(list);
}
%end

// The list lays out on every scroll too, which is when the bars change its inset. Album, artist
// and playlist pages are lists of the same class, hence the check for the one Home owns.
%hook _TtC16Home_CarouselKit29TouchCancellingCollectionView
- (void)layoutSubviews {
    %orig;
    if ((UIView *)self == sg_homeRoot) layoutGradient((UIScrollView *)self);
}
%end

// The scrim is a gradient view one view under the page's own; the gradients of the cards sit far
// deeper than that, so two levels cannot reach them.
%hook _TtC19Home_FunkisPageImpl20FunkisViewController
- (void)viewDidLayoutSubviews {
    %orig;
    for (UIView *wrapper in ((UIViewController *)self).viewIfLoaded.subviews) {
        for (UIView *view in wrapper.subviews) {
            if ([NSStringFromClass(view.class) containsString:@"GradientView"]) view.hidden = YES;
        }
    }
}
%end

%ctor {
    if (!SGFlag(SGKeyHomeGradient, NO)) return;
    %init;
    SGRequireClasses(@[
        @"_TtC16Home_EvoPageImpl33EvoLoadableResourceViewController",
        @"_TtC16Home_CarouselKit29TouchCancellingCollectionView",
        @"_TtC19Home_FunkisPageImpl20FunkisViewController",
    ]);
}
