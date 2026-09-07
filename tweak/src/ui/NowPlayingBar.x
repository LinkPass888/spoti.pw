// Now playing bar: the album-coloured card becomes a glass card with round artwork and the
// progress line under the text. Spotify's own labels, buttons and gestures stay in place.
//
// The full screen player does not fade in over the bar, it morphs the bar's own card and artwork
// into the cover art, so for the length of that animation the bar is handed back: the rounding
// this file applied is undone, the album colour returns through ui/Repaint.x and the glass fades
// out. Without that the card animates from a transparent circle-artwork bar into the player and
// reads as a cut. Coming back the glass dissolves in as the artwork settles.
//
// Tree (trees/home.txt): NowPlayingBarContainerViewController.view 402x56 > NowPlayingBarViewController.view
//   at {8,0} 386x56 > UIView 386x56 (the painted card) > artwork 40x40 r=4, title stack,
//   progress line 370x2 at the bottom. The glass pane goes on the container's view.
#import "SGCommon.h"

static const CGFloat kCardRadius = 24;
static const NSTimeInterval kFadeOut = 0.12, kFadeIn = 0.2;
static char kGlassKey, kRadiusKey;

// The view carrying the glass pane, so the transition hooks reach it without the controllers.
static __weak UIView *sg_barGlassHost = nil;
// Open and close tapped in quick succession overlap; only the newest animation takes the bar back.
static NSUInteger sg_barTransition = 0;

static UIView *detectColoredCard(UIView *bar) {
    __block UIView *best = nil;
    __block CGFloat bestArea = 0;
    SGForEachView(bar, ^(UIView *v) {
        if ([v isKindOfClass:UIVisualEffectView.class] || SGKeepsColor(v) || !SGLooksLikeCard(v, v.layer.backgroundColor)) return;
        CGFloat area = v.bounds.size.width * v.bounds.size.height;
        if (area > bestArea) { bestArea = area; best = v; }
    });
    return best;
}

// Fallback when nothing is painted: the box around artwork, text and the small buttons.
static CGRect contentBounds(UIView *bar, UIView *target) {
    __block CGRect box = CGRectNull;
    SGForEachView(bar, ^(UIView *v) {
        if (v.hidden || v.alpha == 0) return;
        CGFloat width = v.bounds.size.width;
        BOOL content = ([v isKindOfClass:UIImageView.class] && width >= 20 && width <= 120)
            || [v isKindOfClass:UILabel.class]
            || ([v isKindOfClass:UIControl.class] && width <= 100);
        if (content) box = CGRectUnion(box, SGFrameIn(v, target));
    });
    return CGRectIsNull(box) ? box : CGRectInset(box, -10, -8);
}

// Spotify's own radius is kept the first time each view is rounded, so the bar can be put back
// the way it was laid out for the player's expand animation.
static void roundView(UIView *view, CGFloat radius) {
    if (!objc_getAssociatedObject(view, &kRadiusKey)) {
        objc_setAssociatedObject(view, &kRadiusKey, @(view.layer.cornerRadius), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    view.layer.cornerRadius = radius;
    view.layer.cornerCurve = kCACornerCurveContinuous;
}

static void restoreRounding(UIView *root) {
    SGForEachView(root, ^(UIView *v) {
        NSNumber *saved = objc_getAssociatedObject(v, &kRadiusKey);
        if (saved) v.layer.cornerRadius = saved.doubleValue;
    });
}

static void restyleCardContent(UIView *card) {
    SGForEachView(card, ^(UIView *v) {
        CGSize size = v.bounds.size;
        BOOL square = size.width >= 36 && size.width <= 48 && fabs(size.width - size.height) < 1;
        if (!square || v.layer.cornerRadius <= 0 || v.layer.cornerRadius >= size.width / 2) return;
        for (UIView *u = v; u && u != card && CGSizeEqualToSize(u.bounds.size, size); u = u.superview) {
            roundView(u, size.width / 2);
            u.clipsToBounds = YES;
        }
    });
    SGForEachView(card, ^(UIView *v) {
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
    if (!SGEnabled(SGKeyNowPlayingBar)) return;
    UIViewController *barVC = container.childViewControllers.firstObject;
    UIView *bar = barVC.viewIfLoaded ?: container.view;
    sg_nowPlayingRoot = bar;
    sg_barGlassHost = container.view;
    // Mid-transition the bar is Spotify's; its layout runs untouched so the progress line, the
    // corners and the paint are whatever the animation needs.
    if (sg_nowPlayingStock) return;

    UIView *card = sg_nowPlayingCard;
    if (!card || !SGIsInside(card, bar)) card = sg_nowPlayingCard = detectColoredCard(bar);

    container.view.layer.backgroundColor = NULL;
    SGStripBackgrounds(bar);

    CGRect frame = card ? SGFrameIn(card, container.view) : contentBounds(bar, container.view);
    if (CGRectIsNull(frame)) return;
    frame.size.height = MIN(frame.size.height, 80);
    if (frame.size.height < 30 || frame.size.width < 100) return;

    CGFloat radius = MIN(kCardRadius, frame.size.height / 2);
    if (card) {
        roundView(card, radius);
        restyleCardContent(card);
    }

    UIVisualEffectView *glass = SGGlassFor(container.view, &kGlassKey);
    glass.frame = frame;
    SGShapeGlass(glass, radius, NO);

    static dispatch_once_t once;
    dispatch_once(&once, ^{
        SGLog(@"now playing card %@ at %@ (bar %@, container %@)", card.class, NSStringFromCGRect(frame),
              NSStringFromCGRect(bar.frame), NSStringFromCGRect(container.view.bounds));
    });
}

#pragma mark - the player's expand and close animations

// `stock` gives the bar back to Spotify for the length of an animation, and takes it again after.
static void barStock(BOOL stock, NSTimeInterval fade) {
    UIView *host = sg_barGlassHost;
    if (!host || !SGEnabled(SGKeyNowPlayingBar) || sg_nowPlayingStock == stock) return;
    sg_nowPlayingStock = stock;

    if (stock) {
        restoreRounding(host);
        if (sg_nowPlayingCardColor) sg_nowPlayingCard.layer.backgroundColor = sg_nowPlayingCardColor;
    }
    // A layout pass with the flag already set puts the bar in the state the flag asks for: the
    // hook above either stands aside or restyles from scratch.
    [host setNeedsLayout];
    [host layoutIfNeeded];

    UIVisualEffectView *glass = objc_getAssociatedObject(host, &kGlassKey);
    [UIView animateWithDuration:fade animations:^{ glass.alpha = stock ? 0 : 1; }];
}

// Both animators are UIViewControllerAnimatedTransitioning. The bar is Spotify's own from the
// first frame and glass again once the animation has had its duration; on the way up it is behind
// the player by then, on the way down the dissolve lands with the artwork.
static void playerTransition(id<UIViewControllerAnimatedTransitioning> animator, id<UIViewControllerContextTransitioning> context) {
    NSTimeInterval duration = MAX(0.1, [animator transitionDuration:context]);
    NSUInteger generation = ++sg_barTransition;
    barStock(YES, MIN(kFadeOut, duration / 3));
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(duration * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (generation == sg_barTransition) barStock(NO, kFadeIn);
    });
    static dispatch_once_t once;
    dispatch_once(&once, ^{ SGLog(@"player transition %@ over %.2fs", [animator class], duration); });
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

%hook _TtC23NowPlaying_ViewPageImpl35ShowFullscreenAnimatedTransitioning
- (void)animateTransition:(id<UIViewControllerContextTransitioning>)context {
    playerTransition((id)self, context);
    %orig;
}
%end

%hook _TtC23NowPlaying_ViewPageImpl36CloseFullScreenAnimatedTransitioning
- (void)animateTransition:(id<UIViewControllerContextTransitioning>)context {
    playerTransition((id)self, context);
    %orig;
}
%end

%ctor {
    %init;
    SGRequireClasses(@[
        @"_TtC18NowPlaying_BarImpl36NowPlayingBarContainerViewController",
        @"_TtC18NowPlaying_BarImpl27NowPlayingBarViewController",
        @"_TtC23NowPlaying_ViewPageImpl35ShowFullscreenAnimatedTransitioning",
        @"_TtC23NowPlaying_ViewPageImpl36CloseFullScreenAnimatedTransitioning",
    ]);
}
