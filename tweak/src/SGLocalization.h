//
//  SGLocalization.h
//  spoti.pw - Chinese Localization Support
//

#ifndef SGLocalization_h
#define SGLocalization_h

#import <Foundation/Foundation.h>

#pragma mark - Localization Macros

// Main localization macro
#define SG_LOCALIZE(key) \
    [SGLocalization localizedStringForKey:key]

#pragma mark - Common UI Strings (Chinese)

// Main menu
extern NSString *const SGStrModSettings;
extern NSString *const SGStrModSettingsSubtitle;

// Page titles
extern NSString *const SGStrUITweaks;
extern NSString *const SGStrNavbar;
extern NSString *const SGStrHome;
extern NSString *const SGStrPlaylist;
extern NSString *const SGStrNowPlaying;
extern NSString *const SGStrPrivacy;
extern NSString *const SGStrAllFlags;

// UI Tweaks page
extern NSString *const SGStrLiquidGlass;
extern NSString *const SGStrTabBar;
extern NSString *const SGStrSearchField;
extern NSString *const SGStrSpotifyGlass;
extern NSString *const SGStrTheme;
extern NSString *const SGStrAmoledBackground;

// Home page
extern NSString *const SGStrGradient;
extern NSString *const SGStrHide;
extern NSString *const SGStrFilterPills;
extern NSString *const SGStrShortcutsGrid;
extern NSString *const SGStrPromoCards;
extern NSString *const SGStrPreviewCards;
extern NSString *const SGStrDJCard;

// Playlist page
extern NSString *const SGStrHideInHeader;
extern NSString *const SGStrCoverArtwork;
extern NSString *const SGStrDescription;
extern NSString *const SGStrCreatorAndCollaborators;
extern NSString *const SGStrLengthAndSaves;
extern NSString *const SGStrHideHeaderButtons;
extern NSString *const SGStrVideo;
extern NSString *const SGStrAddToLibrary;
extern NSString *const SGStrDownload;
extern NSString *const SGStrShare;
extern NSString *const SGStrMore;
extern NSString *const SGStrHideOverTracks;
extern NSString *const SGStrCurationPills;
extern NSString *const SGStrFindAndSortBar;

// Now Playing page
extern NSString *const SGStrNowPlayingBar;
extern NSString *const SGStrArtworkBackground;
extern NSString *const SGStrHeaderButtons;
extern NSString *const SGStrLyrics;
extern NSString *const SGStrSpotifyFlags;
extern NSString *const SGStrSheetStylePlayer;
extern NSString *const SGStrQueueAsBottomSheet;
extern NSString *const SGStrQueueFlipTransition;
extern NSString *const SGStrMiniPlayerTransitions;
extern NSString *const SGStrBarToCoverArtAnimation;
extern NSString *const SGStrWhiteHeartButton;
extern NSString *const SGStrExpandStickyHeader;
extern NSString *const SGStrCoverArtInHeader;
extern NSString *const SGStrRedesignedHeader;
extern NSString *const SGStrPictureInPicture;
extern NSString *const SGStrVideoInMiniPlayer;
extern NSString *const SGStrHideButtons;
extern NSString *const SGStrShuffle;
extern NSString *const SGStrRepeat;
extern NSString *const SGStrConnectToDevice;
extern NSString *const SGStrQueueButton;
extern NSString *const SGStrAddToPlaylist;
extern NSString *const SGStrUnderArtwork;
extern NSString *const SGStrLyricsPreview;
extern NSString *const SGStrHideCardsBelowPlayer;
extern NSString *const SGStrAboutArtist;
extern NSString *const SGStrRelatedVideos;
extern NSString *const SGStrSongDNA;
extern NSString *const SGStrLiveEvents;
extern NSString *const SGStrExploreArtist;
extern NSString *const SGStrCredits;
extern NSString *const SGStrMerch;
extern NSString *const SGStrRecommendations;

// Privacy page
extern NSString *const SGStrTelemetry;
extern NSString *const SGStrBlockTelemetry;
extern NSString *const SGStrBlockedSoFar;
extern NSString *const SGStrTotal;
extern NSString *const SGStrResetCounters;

// About section
extern NSString *const SGStrAbout;
extern NSString *const SGStrVersion;
extern NSString *const SGStrUpdates;
extern NSString *const SGStrWebsite;
extern NSString *const SGStrGitHub;
extern NSString *const SGStrTelegram;

// Navbar page
extern NSString *const SGStrCustomNavbar;
extern NSString *const SGStrUseSpotifyOrder;
extern NSString *const SGStrAddATab;
extern NSString *const SGStrAnyLink;

// Flags page
extern NSString *const SGStrFlags;

// Common strings
extern NSString *const SGStrChangesApplyAfterRestart;
extern NSString *const SGStrOn;
extern NSString *const SGStrOff;
extern NSString *const SGStrAuto;
extern NSString *const SGStrCancel;
extern NSString *const SGStrForce;
extern NSString *const SGStrReset;
extern NSString *const SGStrAdd;
extern NSString *const SGStrChecking;
extern NSString *const SGStrUpToDate;
extern NSString *const SGStrNotChecked;

@interface SGLocalization : NSObject

+ (NSString *)localizedStringForKey:(NSString *)key;

@end

#endif /* SGLocalization_h */
