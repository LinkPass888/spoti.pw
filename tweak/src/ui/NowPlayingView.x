// Full screen player: glass behind the header buttons, each transport control except play, and
// the footer buttons. Spotify's blurred artwork background stays underneath.
//
// Tree (trees/now-playing.txt): NowPlaying_ModesImpl units, each a child controller whose view holds
// one UIStackView row: header (chevron, title, more), playback controls (shuffle, previous, play,
// next, repeat), footer (connect, share, queue).
#import "SGCommon.h"

// A pane per direct child of the unit's row: circles for square children, capsules for wide ones.
// `fixedSize` forces every pane to one size; children containing a `skip` class get none, nor do
// the ones ui/Declutter.x made invisible.
static void glassBehindRowChildren(UIViewController *unit, CGFloat minSize, CGFloat fixedSize, NSString *skip) {
    if (!SGEnabled(SGKeyPlayer)) return;
    UIView *host = unit.viewIfLoaded;
    UIStackView *row = SGRowIn(host);
    if (!row) return;
    [row layoutIfNeeded];
    NSUInteger index = 0;
    for (UIView *child in row.arrangedSubviews) {
        CGRect f = SGFrameIn(child, host);
        if (child.hidden || child.alpha == 0 || f.size.width < 20 || f.size.height < 20) continue;
        __block BOOL skipped = NO;
        if (skip) SGForEachView(child, ^(UIView *v) { if ([NSStringFromClass(v.class) containsString:skip]) skipped = YES; });
        if (skipped) continue;
        CGFloat height = fixedSize ?: MAX(minSize, MIN(f.size.height, 48));
        CGFloat width = fixedSize ?: MAX(f.size.width, height);
        UIVisualEffectView *glass = SGGlassAt(host, index++);
        glass.frame = CGRectMake(CGRectGetMidX(f) - width / 2, CGRectGetMidY(f) - height / 2, width, height);
        SGShapeGlass(glass, height / 2, YES);
    }
    SGHideGlassFrom(host, index);
}

%hook _TtC20NowPlaying_ModesImpl18HeaderElementsUnit
- (void)viewDidLayoutSubviews {
    %orig;
    glassBehindRowChildren((UIViewController *)self, 36, 0, nil);
}
%end

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

%ctor {
    %init;
    SGRequireClasses(@[
        @"_TtC20NowPlaying_ModesImpl18HeaderElementsUnit",
        @"_TtC20NowPlaying_ModesImpl28PlaybackControlsElementsUnit",
        @"_TtC20NowPlaying_ModesImpl18FooterElementsUnit",
    ]);
}
