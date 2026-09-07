// Full screen player: glass where Liquid Glass belongs and nowhere else.
//
// Glass is the navigation layer floating over content, so only the header's two round buttons get
// a pane, the way the Music app keeps its chrome. The playlist name between them is a label, and
// shuffle, repeat, previous, next and the footer (connect, share, queue) are bare glyphs over the
// artwork next to Spotify's white play disc: a pane each turned both rows into a strip of glass
// discs sampling one another, which is the one thing the material cannot do. The cards below the
// player are surfaces rather than controls; the lyrics one is in ui/Lyrics.x.
//
// Tree (trees/now-playing.txt): NowPlaying_ModesImpl units, each a child controller whose view
// holds one UIStackView row; the header row is chevron 48x48, playlist name 110x48, more 48x48.
#import "SGCommon.h"

static const CGFloat kButtonMin = 36, kButtonMax = 48;

// A glass circle per round button in the unit's row: children about as wide as they are tall.
// The playlist name is 110 wide against 48 tall, so it keeps no pane, and neither do the children
// ui/Declutter.x made invisible.
static void glassBehindRoundButtons(UIViewController *unit) {
    if (!SGEnabled(SGKeyPlayer)) return;
    UIView *host = unit.viewIfLoaded;
    UIStackView *row = SGRowIn(host);
    if (!row) return;
    [row layoutIfNeeded];
    NSUInteger index = 0;
    for (UIView *child in row.arrangedSubviews) {
        CGRect f = SGFrameIn(child, host);
        if (child.hidden || child.alpha == 0 || f.size.width < 20 || f.size.height < 20) continue;
        if (f.size.width > f.size.height * 1.4) continue;
        CGFloat side = MAX(kButtonMin, MIN(MAX(f.size.width, f.size.height), kButtonMax));
        UIVisualEffectView *glass = SGGlassAt(host, index++);
        glass.frame = CGRectMake(CGRectGetMidX(f) - side / 2, CGRectGetMidY(f) - side / 2, side, side);
        SGShapeGlass(glass, side / 2, YES);
    }
    SGHideGlassFrom(host, index);
}

%hook _TtC20NowPlaying_ModesImpl18HeaderElementsUnit
- (void)viewDidLayoutSubviews {
    %orig;
    glassBehindRoundButtons((UIViewController *)self);
}
%end

%ctor {
    %init;
    SGRequireClasses(@[@"_TtC20NowPlaying_ModesImpl18HeaderElementsUnit"]);
}
