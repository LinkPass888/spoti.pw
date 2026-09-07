// Home gradient: a green wash behind the top of the Home tab, strongest under the avatar and the
// pills and out by the second shelf, like the gradient Spotify's own Home used to have. The wash
// is a layer inside the page's scroll view, under its content, so it scrolls away with the
// shelves; the base grey the page and the shelves paint over it goes clear in ui/Repaint.x, and
// Spotify's own scrim behind the header goes with it, since it would only mute the colour.
//
// Tree (trees/home.txt): HomePageHostingViewController.view holds the Evo page, a 402x112 wrapper
// around LiquidGlass.GradientView (the scrim under the avatar and the pills) and HomeHeaderView.
// The Evo page's own view holds one Home_CarouselKit.TouchCancellingCollectionView, full screen
// and inset 112pt at the top for the header, painted #121212; the shelves inside it are
// collection views painted #121212 of their own.
#import "SGCommon.h"

// Sampled off the design: #0B4110 at the top of the screen, level behind the header, gone by 390pt.
static UIColor *tint(void) { return [UIColor colorWithRed:0x0B / 255.0 green:0x41 / 255.0 blue:0x10 / 255.0 alpha:1]; }
static const CGFloat kFadeHeight = 390;
static const CGFloat kLevelHeight = 52;
// Colour above the content as well, for the rubber band of an overscroll to pull down into.
static const CGFloat kOverscroll = 600;

static char kGradientKey;

// A view of its own, so the wash follows the page's layout passes instead of animating itself
// through CoreAnimation whenever the inset changes.
@interface SGHomeGradientView : UIView
@end

@implementation SGHomeGradientView
+ (Class)layerClass {
    return CAGradientLayer.class;
}
@end

static SGHomeGradientView *gradientIn(UIScrollView *list) {
    SGHomeGradientView *view = objc_getAssociatedObject(list, &kGradientKey);
    if (!view) {
        view = [SGHomeGradientView new];
        view.userInteractionEnabled = NO;
        CGFloat height = kOverscroll + kFadeHeight;
        CAGradientLayer *gradient = (CAGradientLayer *)view.layer;
        gradient.colors = @[(id)tint().CGColor, (id)tint().CGColor, (id)[tint() colorWithAlphaComponent:0].CGColor];
        gradient.locations = @[@0, @((kOverscroll + kLevelHeight) / height), @1];
        objc_setAssociatedObject(list, &kGradientKey, view, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

        // Whatever the page painted before the wash was there; ui/Repaint.x keeps it clear from now.
        sg_homeRoot = list;
        SGForEachView(list, ^(UIView *v) {
            if (SGIsBaseSurface(v.layer.backgroundColor)) v.layer.backgroundColor = NULL;
        });
        SGLog(@"home gradient behind %@", NSStringFromClass(list.class));
    }
    // Cells are added on top of it, so index 0 stays the bottom of the list.
    if (view.superview != list) [list insertSubview:view atIndex:0];
    return view;
}

// Content coordinates: the content starts below the header, so the wash starts at minus the inset,
// where the top of the screen is when the list sits still.
static void layoutGradient(UIScrollView *list) {
    SGHomeGradientView *view = gradientIn(list);
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

// Everything beside the page in the host view is the header and its scrim, both of them shallow.
%hook _TtC19Home_FunkisPageImpl29HomePageHostingViewController
- (void)viewDidLayoutSubviews {
    %orig;
    UIView *host = ((UIViewController *)self).viewIfLoaded;
    for (UIView *sub in host.subviews) {
        if (sub.bounds.size.height > host.bounds.size.height / 2) continue;
        SGForEachView(sub, ^(UIView *v) {
            if ([NSStringFromClass(v.class) containsString:@"GradientView"]) v.hidden = YES;
        });
    }
}
%end

%ctor {
    if (!SGFlag(SGKeyHomeGradient, NO)) return;
    %init;
    SGRequireClasses(@[
        @"_TtC16Home_EvoPageImpl33EvoLoadableResourceViewController",
        @"_TtC16Home_CarouselKit29TouchCancellingCollectionView",
        @"_TtC19Home_FunkisPageImpl29HomePageHostingViewController",
    ]);
}
