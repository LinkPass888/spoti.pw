// The lyrics card under the player and the page it expands into, both on glass.
//
// Card (trees/now-playing.txt): a Lyrics_CardElementImpl.CardView inside an
// Element_List.CollectionViewCell 370x316. The cell is the painted surface with the 16pt corners,
// so the pane fills it and the cell's own clipping cuts the corners.
//
// Page (trees/lyrics.txt): a page of its own, presented over the player by a
// _UIOverFullscreenPresentationController, which is why the card's glass stops at the card's edge.
// Tome_PageTemplateImpl paints the template view #121212 and FullscreenView paints itself the
// album colour on top, both opaque; clearing them lets the player's blurred artwork through, so
// the card reads as having grown to the screen.
//
// The album colour is the stubborn one: it arrives per track, after the page has laid out, and it
// comes back through a path ui/Repaint.x never sees, so a sweep at layout time loses the race.
// FullscreenView is asked not to keep it at all instead. The pane goes inside FullscreenView, in
// front of whatever that view still fills itself with, rather than behind the whole page.
#import "SGCommon.h"

static const CGFloat kCardRadius = 16;
static char kCardGlassKey, kPageGlassKey;

#pragma mark - the card in the player's scroll list

// The cell around the card, the view Spotify paints and rounds.
static UIView *cellAround(UIView *view) {
    Class cell = NSClassFromString(@"_TtC12Element_List18CollectionViewCell");
    for (UIView *v = view; v; v = v.superview) {
        if ([v isKindOfClass:cell]) return v;
    }
    return nil;
}

%hook _TtC22Lyrics_CardElementImpl8CardView
- (void)layoutSubviews {
    %orig;
    if (!SGEnabled(SGKeyLyricsCard)) return;
    UIView *cell = cellAround((UIView *)self);
    // A card ui/Declutter.x collapsed reports no height; leave it alone.
    if (!cell || cell.bounds.size.height < 40) return;
    // Spotify repaints the card with the album colour when the track changes, which is no layout
    // pass of its own; ui/Repaint.x keeps it clear in between.
    sg_lyricsCardRoot = cell;
    SGStripBackgrounds(cell);
    UIVisualEffectView *glass = SGGlassFor(cell, &kCardGlassKey);
    glass.frame = cell.bounds;
    glass.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    SGShapeGlass(glass, kCardRadius, NO);
}
%end

#pragma mark - the expanded page

// Up to the presentation: the template views in between paint themselves opaque once, at setup.
// Only the chain is cleared, not the subtree -- nothing else on the page is painted.
static UIView *clearAncestors(UIView *view) {
    UIView *top = view;
    for (UIView *v = view; v && ![v isKindOfClass:UIWindow.class]
            && ![NSStringFromClass(v.class) hasPrefix:@"UITransition"]; v = v.superview) {
        v.layer.backgroundColor = NULL;
        top = v;
    }
    return top;
}

%hook _TtC32Lyrics_FullscreenElementPageImpl14FullscreenView
// A colour kept here is re-applied whenever UIKit feels like it, so it is refused outright.
- (void)setBackgroundColor:(UIColor *)color {
    static dispatch_once_t once;
    dispatch_once(&once, ^{ SGLog(@"lyrics page paints itself %@ through UIView", color); });
    %orig(SGEnabled(SGKeyLyricsCard) ? nil : color);
}

- (void)layoutSubviews {
    %orig;
    if (!SGEnabled(SGKeyLyricsCard)) return;
    UIView *page = (UIView *)self;
    if (page.bounds.size.height < 200) return;

    page.layer.backgroundColor = NULL;
    sg_lyricsPageRoot = clearAncestors(page);

    UIVisualEffectView *glass = SGGlassFor(page, &kPageGlassKey);
    glass.frame = page.bounds;
    glass.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    // Full bleed, so the shape is spelled out: a fresh pane does not promise square corners.
    SGShapeGlass(glass, 0, NO);
}
%end

%ctor {
    %init;
    SGRequireClasses(@[
        @"_TtC22Lyrics_CardElementImpl8CardView",
        @"_TtC12Element_List18CollectionViewCell",
        @"_TtC32Lyrics_FullscreenElementPageImpl14FullscreenView",
    ]);
}
