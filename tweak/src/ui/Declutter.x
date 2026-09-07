// Declutter: hides parts of the full screen player and of Home, one switch each in Mod Settings.
// Cards under the player and sections on Home are Element_List cells; a hidden one reports zero
// height when the list sizes it, so the list closes up around it (the 24pt gap between cards
// stays). Player buttons go invisible but keep their place, so their row stays centred.
//
// Trees (trees/now-playing*.txt, trees/home*.txt): every card is a CollectionViewCell whose
// content view names the page (NowPlaying_ScrollAPI, Home_EvoPageImpl) and whose subtree names
// the card. Player rows are the UIStackView of each NowPlaying_ModesImpl unit: playback controls
// hold shuffle, previous, play, next, repeat; the footer holds connect, a hidden button, share
// and the queue; track info ends with the add-to button.
#import "SGCommon.h"

#pragma mark - cards and sections

static const struct { __unsafe_unretained NSString *page, *marker, *key; } cards[] = {
    {@"NowPlaying_ScrollAPI", @"Lyrics_CardElementImpl", SGHideLyricsCard},
    {@"NowPlaying_ScrollAPI", @"CreatorBiography", SGHideAboutArtist},
    {@"NowPlaying_ScrollAPI", @"VideoRecommendations", SGHideRelatedVideos},
    {@"NowPlaying_ScrollAPI", @"SongDNA_", SGHideSongDNA},
    {@"NowPlaying_ScrollAPI", @"LiveEvents_", SGHideLiveEvents},
    {@"NowPlaying_ScrollAPI", @"WatchFeed_", SGHideExploreArtist},
    {@"NowPlaying_ScrollAPI", @"Creator_Credits", SGHideCredits},
    {@"NowPlaying_ScrollAPI", @"Merch_", SGHideMerch},
    {@"NowPlaying_ScrollAPI", @"RelatedContentRecommendations", SGHideRecommendations},
    {@"Home_EvoPageImpl", @"Home_AnchorsAndShortcutsKit", SGHideHomeShortcuts},
    {@"Home_EvoPageImpl", @"Discovery_PromoElement", SGHideHomePromo},
    {@"Home_EvoPageImpl", @"Discovery_PreviewElement", SGHideHomePreviews},
    {@"Home_EvoPageImpl", @"Discovery_DJElement", SGHideHomeDJ},
};

// Class names of everything in the cell. Lists nested in the cell are laid out first so the
// cells that name the card (shortcut tiles, video cards) exist.
static NSString *classNamesIn(UIView *cell) {
    NSMutableString *names = [NSMutableString string];
    SGForEachView(cell, ^(UIView *v) {
        if (v != cell && [v isKindOfClass:UICollectionView.class]) [v layoutIfNeeded];
        [names appendString:NSStringFromClass(v.class)];
        [names appendString:@"\n"];
    });
    return names;
}

static NSString *hiddenKeyFor(UICollectionViewCell *cell) {
    // A cell inside another card's list: the outer card decides.
    for (UIView *v = cell.superview; v; v = v.superview) {
        if ([v isKindOfClass:cell.class]) return nil;
    }
    NSString *names = nil;
    for (size_t i = 0; i < sizeof(cards) / sizeof(cards[0]); i++) {
        if (!SGHidden(cards[i].key)) continue;
        if (!names) names = classNamesIn(cell);
        if ([names containsString:cards[i].page] && [names containsString:cards[i].marker]) return cards[i].key;
    }
    return nil;
}

%hook _TtC12Element_List18CollectionViewCell
- (UICollectionViewLayoutAttributes *)preferredLayoutAttributesFittingAttributes:(UICollectionViewLayoutAttributes *)attributes {
    UICollectionViewLayoutAttributes *result = %orig;
    NSString *key = hiddenKeyFor((UICollectionViewCell *)self);
    if (!key) return result;
    result.size = CGSizeMake(result.size.width, 0);
    ((UIView *)self).clipsToBounds = YES;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ SGLog(@"collapsed the first card, %@", key); });
    return result;
}
%end

#pragma mark - player buttons

static BOOL vanish(UIView *view) {
    if (!view || view.alpha == 0) return NO;
    view.alpha = 0;
    view.userInteractionEnabled = NO;
    return YES;
}

// Re-layout once something went invisible, so the glass panes of ui/NowPlayingView.x follow.
static void finish(UIViewController *unit, BOOL changed) {
    if (changed) [unit.viewIfLoaded setNeedsLayout];
}

%hook _TtC20NowPlaying_ModesImpl28PlaybackControlsElementsUnit
- (void)viewDidLayoutSubviews {
    %orig;
    NSArray<UIView *> *items = SGRowIn(((UIViewController *)self).viewIfLoaded).arrangedSubviews;
    if (items.count != 5 || !SGHasClass(items[2], @"PlayButton")) return;
    BOOL changed = NO;
    if (SGHidden(SGHideShuffle)) changed |= vanish(items[0]);
    if (SGHidden(SGHideRepeat)) changed |= vanish(items[4]);
    finish((UIViewController *)self, changed);
}
%end

%hook _TtC20NowPlaying_ModesImpl18FooterElementsUnit
- (void)viewDidLayoutSubviews {
    %orig;
    BOOL changed = NO;
    for (UIView *item in SGRowIn(((UIViewController *)self).viewIfLoaded).arrangedSubviews) {
        if (item.hidden || item.bounds.size.width < 20) continue;
        if (SGHasClass(item, @"Connect")) {
            if (SGHidden(SGHideConnect)) changed |= vanish(item);
        } else if (SGHasClass(item, @"QueueButton")) {
            if (SGHidden(SGHideQueue)) changed |= vanish(item);
        } else if (item.bounds.size.width <= 48 && SGHasClass(item, @"EncoreButton")) {
            if (SGHidden(SGHideShare)) changed |= vanish(item);
        }
    }
    finish((UIViewController *)self, changed);
}
%end

%hook _TtC20NowPlaying_ModesImpl23InformationElementsUnit
- (void)viewDidLayoutSubviews {
    %orig;
    if (!SGHidden(SGHideAddTo)) return;
    BOOL changed = NO;
    for (UIView *item in SGRowIn(((UIViewController *)self).viewIfLoaded).arrangedSubviews) {
        if (SGHasClass(item, @"AddToButton")) changed |= vanish(item);
    }
    finish((UIViewController *)self, changed);
}
%end

#pragma mark - lyrics under the artwork, Home filter pills

%hook _TtC22Lyrics_NPVContainerKit19LyricsContainerView
- (void)setHidden:(BOOL)hidden {
    %orig(SGHidden(SGHideLyricsInline) ? YES : hidden);
}
- (void)didMoveToWindow {
    %orig;
    if (SGHidden(SGHideLyricsInline)) ((UIView *)self).hidden = YES;
}
%end

%hook _TtC14Home_PillUIKit14PillScrollView
- (void)didMoveToWindow {
    %orig;
    if (SGHidden(SGHideHomePills)) ((UIView *)self).hidden = YES;
}
%end

%ctor {
    %init;
    SGRequireClasses(@[
        @"_TtC12Element_List18CollectionViewCell",
        @"_TtC20NowPlaying_ModesImpl28PlaybackControlsElementsUnit",
        @"_TtC20NowPlaying_ModesImpl18FooterElementsUnit",
        @"_TtC20NowPlaying_ModesImpl23InformationElementsUnit",
        @"_TtC22Lyrics_NPVContainerKit19LyricsContainerView",
        @"_TtC14Home_PillUIKit14PillScrollView",
    ]);
}
