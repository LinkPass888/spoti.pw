// Playlist: hides parts of a playlist page, one switch each in Mod Settings > Playlist. Album and
// artist pages are built by another framework and are left alone.
//
// The header parts are hidden from the layout pass that places them, not from the view
// controller's: the elements arrive after the page does, and a controller whose own view is not
// dirty never hears about it, so anything hidden a level up flashes first.
//
// Tree (trees/playlist.txt): HeaderContentLayout holds the cover in a ShadowContainer over a block
// of title, description, the creator row, the length and the button row, a UIStackView of
// ActionViews -- the video deck, add, download, share and more. Each names itself by what it holds
// except share and more, which are plain icon buttons and go by their place in the row, more being
// the last. Find on page and Sort are a header view of their own, over the list.
//
// The header's height is not measured from what it shows: -[SPTFreeTierPlaylistEncoreHeaderViewController
// update] adds three numbers into a stored fullHeaderHeight and pins headerViewHeightConstraint to
// it, so a hidden cover leaves the room it was counted for. collapseCover() takes that room back.
#import "SGCommon.h"

@interface NSObject (SGPlaylistHeader)
- (NSLayoutConstraint *)headerViewHeightConstraint;
- (NSLayoutConstraint *)layoutGuideHeightConstraint;
@end

static UIView *viewNamed(UIView *root, NSString *marker) {
    __block UIView *found = nil;
    SGForEachView(root, ^(UIView *v) {
        if (!found && [NSStringFromClass(v.class) containsString:marker]) found = v;
    });
    return found;
}

// Only ever hides. A switch turned off again shows after Spotify restarts, like every other one.
static void hide(UIView *view, NSString *key) {
    if (view && SGHidden(key)) view.hidden = YES;
}

// The header layout is Encore's own class, so the hook asks whose page it is before touching it.
static UIViewController *playlistHeaderOf(UIView *view) {
    for (UIResponder *r = view; r; r = r.nextResponder) {
        if (![r isKindOfClass:UIViewController.class]) continue;
        return [NSStringFromClass(r.class) containsString:@"FreeTierPlaylist"] ? (UIViewController *)r : nil;
    }
    return nil;
}

static UIView *coverIn(UIView *layout) {
    for (UIView *v in layout.subviews) {
        if ([NSStringFromClass(v.class) containsString:@"ShadowContainer"]) return v;
    }
    return nil;
}

// Title, description, the creator row and the length share one column, and only the description
// names a class of its own, so the column is reached through it and its rows go by what they hold.
// The length is the last row rather than the second stack: a byline without faces is a stack too.
static void applyColumn(UIView *header) {
    UIView *column = nil;
    for (UIView *v = viewNamed(header, @"ExpandableTextView"); v && v != header; v = v.superview) {
        if (![NSStringFromClass(v.superview.class) containsString:@"AutoLayoutStackView"]) continue;
        column = v;
        break;
    }
    for (UIView *row in column.subviews) {
        BOOL last = row == column.subviews.lastObject && [NSStringFromClass(row.class) containsString:@"StackView"];
        if (SGHasClass(row, @"ExpandableTextView")) hide(row, SGHidePlaylistDescription);
        else if (SGHasClass(row, @"FacepileView")) hide(row, SGHidePlaylistCreator);
        else if (last) hide(row, SGHidePlaylistLength);
    }
}

// The button row is a real stack view, so a hidden button leaves no gap behind it. Buttons Spotify
// hides itself stay in the count, so that hiding more never shifts share into its place.
static void applyActions(UIView *header) {
    __block UIStackView *row = nil;
    SGForEachView(header, ^(UIView *v) {
        if (row || ![v isKindOfClass:UIStackView.class]) return;
        for (UIView *item in ((UIStackView *)v).arrangedSubviews) {
            if ([NSStringFromClass(item.class) containsString:@"ActionView"]) row = (UIStackView *)v;
        }
    });
    NSMutableArray<UIView *> *plain = [NSMutableArray array];
    for (UIView *action in row.arrangedSubviews) {
        if (SGHasClass(action, @"WatchFeed")) hide(action, SGHidePlaylistVideo);
        else if (SGHasClass(action, @"AddToButton")) hide(action, SGHidePlaylistAddTo);
        else if (SGHasClass(action, @"GranularDownloadButton")) hide(action, SGHidePlaylistDownload);
        else [plain addObject:action];
    }
    for (UIView *action in plain) {
        hide(action, action == plain.lastObject ? SGHidePlaylistMore : SGHidePlaylistShare);
    }
}

// Find on page and Sort sit in a header view of their own, one that holds nothing else.
static void applyFindBar(UIView *header) {
    for (UIView *v = viewNamed(header, @"EncoreTextField"); v && v != header; v = v.superview) {
        if (![NSStringFromClass(v.class) containsString:@"HeaderView"]) continue;
        hide(v, SGHidePlaylistFind);
        return;
    }
}

// Takes back the room the hidden cover was measured into: everything beside the cover moves up to
// where the cover began, and the header's height constraints come down by what that frees. Both
// numbers are read back from the frames Spotify has just set, so once the header has shrunk the
// next pass finds nothing left to take and stops. The constraint is only touched when it is the
// one sizing this layout; otherwise the room stays and the log says why.
static void collapseCover(UIViewController *headerVC, UIView *layout, UIView *cover) {
    if (![headerVC respondsToSelector:@selector(headerViewHeightConstraint)]) return;
    NSLayoutConstraint *height = [headerVC headerViewHeightConstraint];
    CGFloat full = CGRectGetHeight(layout.bounds);
    if (fabs(height.constant - full) > 1) {
        static dispatch_once_t once;
        dispatch_once(&once, ^{ SGLog(@"playlist header: constraint %.0f does not size the %.0f layout", height.constant, full); });
        return;
    }

    CGFloat top = CGFLOAT_MAX, bottom = 0;
    for (UIView *v in layout.subviews) {
        if (v == cover) continue;
        top = MIN(top, CGRectGetMinY(v.frame));
        bottom = MAX(bottom, CGRectGetMaxY(v.frame));
    }
    if (top == CGFLOAT_MAX) return;

    CGFloat coverTop = CGRectGetMinY(cover.frame);
    CGFloat shift = coverTop > 0 && coverTop < top ? top - coverTop : 0;
    for (UIView *v in layout.subviews) {
        if (v != cover && shift > 0) v.frame = CGRectOffset(v.frame, 0, -shift);
    }
    CGFloat drop = full - (bottom - shift);
    if (drop < 1) return;
    height.constant -= drop;
    if ([headerVC respondsToSelector:@selector(layoutGuideHeightConstraint)]) {
        NSLayoutConstraint *guide = [headerVC layoutGuideHeightConstraint];
        if (guide.constant > drop) guide.constant -= drop;
    }
    static dispatch_once_t once;
    dispatch_once(&once, ^{ SGLog(@"playlist header: %.0f -> %.0f, cover took %.0f", full, full - drop, drop); });
}

%hook _TtC28EncoreConsumerMobile_BaseKit19HeaderContentLayout
- (void)layoutSubviews {
    %orig;
    UIViewController *headerVC = playlistHeaderOf((UIView *)self);
    if (!headerVC) return;
    UIView *layout = (UIView *)self, *cover = coverIn(layout);
    hide(cover, SGHidePlaylistArtwork);
    applyColumn(layout);
    applyActions(layout);
    if (cover.hidden) collapseCover(headerVC, layout, cover);
}
%end

// The find bar is not in the header layout, and it fades in on its own rather than appearing, so
// the controller's pass is soon enough for it.
%hook SPTFreeTierPlaylistEncoreHeaderViewController
- (void)viewDidLayoutSubviews {
    %orig;
    UIView *header = ((UIViewController *)self).viewIfLoaded;
    if (header) applyFindBar(header);
}
%end

%hook _TtC35ListUXPlatform_FreeTierPlaylistImpl25ElementCollectionViewCell
- (UICollectionViewLayoutAttributes *)preferredLayoutAttributesFittingAttributes:(UICollectionViewLayoutAttributes *)attributes {
    UICollectionViewLayoutAttributes *result = %orig;
    if (!SGHidden(SGHidePlaylistPills) || !SGHasClass((UIView *)self, @"CurationActionsToolbar")) return result;
    result.size = CGSizeMake(result.size.width, 0);
    ((UIView *)self).clipsToBounds = YES;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ SGLog(@"collapsed the curation pills"); });
    return result;
}
%end

%ctor {
    %init;
    SGRequireClasses(@[
        @"_TtC28EncoreConsumerMobile_BaseKit19HeaderContentLayout",
        @"SPTFreeTierPlaylistEncoreHeaderViewController",
        @"_TtC35ListUXPlatform_FreeTierPlaylistImpl25ElementCollectionViewCell",
    ]);
}
