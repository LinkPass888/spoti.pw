// Shared declarations for every spotifyglass source file.
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <os/log.h>

// iOS 26 API, absent from the SDK Theos builds against. Resolved at runtime.
@interface UIGlassEffect : UIVisualEffect
@property (nonatomic, copy) UIColor *tintColor;
@property (nonatomic, getter=isInteractive) BOOL interactive;
@end

@interface NSObject (SGiOS26)
+ (id)capsuleConfiguration;
+ (id)configurationWithUniformRadius:(id)radius;
+ (id)fixedRadius:(CGFloat)radius;
- (void)setCornerConfiguration:(id)configuration;
@end

@interface UIView (SGPrivate)
- (NSString *)recursiveDescription;
@end

@interface UIViewController (SGPrivate)
- (NSString *)_printHierarchy;
@end

// %{public}s so idevicesyslog on the Mac sees the text instead of <private>.
#define SGLog(fmt, ...) os_log_with_type(OS_LOG_DEFAULT, OS_LOG_TYPE_DEFAULT, "[spotifyglass] %{public}s", [NSString stringWithFormat:(fmt), ##__VA_ARGS__].UTF8String)
void SGLogLong(NSString *tag, NSString *text);
void SGRequireClasses(NSArray<NSString *> *names);

// View tree
void SGForEachView(UIView *view, void (^fn)(UIView *));
CGRect SGFrameIn(UIView *view, UIView *target);
BOOL SGIsInside(UIView *view, UIView *root);
BOOL SGKeepsColor(UIView *view);
void SGStripBackgrounds(UIView *view);
BOOL SGIsVisibleColor(CGColorRef color);
BOOL SGIsLightColor(CGColorRef color);
BOOL SGIsBaseSurface(CGColorRef color);

BOOL SGHasClass(UIView *root, NSString *marker);
UIStackView *SGRowIn(UIView *host);

// Glass panes
UIVisualEffectView *SGGlassFor(UIView *host, const void *key);
UIVisualEffectView *SGGlassAt(UIView *host, NSUInteger index);
void SGHideGlassFrom(UIView *host, NSUInteger count);
void SGShapeGlass(UIView *glass, CGFloat radius, BOOL capsule);

// Areas kept transparent by ui/Repaint.x, set by the tweaks that own them.
extern __weak UIView *sg_nowPlayingRoot;
extern __weak UIView *sg_tabBarRoot;
extern __weak UIView *sg_nowPlayingCard;
extern __weak UIView *sg_lyricsCardRoot;
extern __weak UIView *sg_lyricsPageRoot;
extern __weak UIView *sg_homeRoot;  // ui/HomeGradient.x, the base surface only
BOOL SGLooksLikeCard(UIView *view, CGColorRef color);

// The full screen player morphs the now playing bar's own card into the cover art, so for the
// length of that animation ui/NowPlayingBar.x hands the bar back to Spotify: the flag lets the
// album colour through ui/Repaint.x again, and the last colour it took off is kept to restore.
extern BOOL sg_nowPlayingStock;
extern CGColorRef sg_nowPlayingCardColor;
void SGRememberCardColor(CGColorRef color);

// Switches from ui/Settings.x, one per tweak; an unset switch is on.
extern NSString *const SGKeyNowPlayingBar;
extern NSString *const SGKeyTabBar;
extern NSString *const SGKeyPlayer;
extern NSString *const SGKeyLyricsCard;
extern NSString *const SGKeySearchField;
extern NSString *const SGKeySpotifyGlass;
extern NSString *const SGKeyAmoled;
extern NSString *const SGKeyHomeGradient;  // off unless it is asked for
BOOL SGFlag(NSString *key, BOOL fallback);
BOOL SGEnabled(NSString *key);
void SGSetEnabled(NSString *key, BOOL on);

// The tab bar's own composition, from ui/Navbar.x and the Navbar settings page: an ordered list
// of entries, each a dictionary. An entry with a URI is a tab of the mod's own; one without names
// one of Spotify's, by the label under its icon. No list at all is Spotify's order, all shown.
extern NSString *const SGKeyNavbar;
extern NSString *const SGNavbarID;      // NSString, the entry's identity
extern NSString *const SGNavbarTitle;   // NSString, the name in the settings list and under the icon
extern NSString *const SGNavbarURI;     // NSString, the mod's own tabs only: what a tap opens
extern NSString *const SGNavbarIcon;    // NSString, an SPTEncoreIcon class method such as "podcasts"
extern NSString *const SGNavbarHidden;  // NSNumber
NSArray<NSDictionary *> *SGNavbarLayout(void);
void SGSetNavbarLayout(NSArray<NSDictionary *> *layout);
// Spotify's own tabs in Spotify's order, as ui/Navbar.x last saw them on the bar.
NSArray<NSString *> *SGNavbarStock(void);
void SGSetNavbarStock(NSArray<NSString *> *stock);

// ui/Navbar.x, called from the tab bar's layout pass in ui/TabBar.x.
void SGComposeTabBar(UIView *tabBar);

// Spotify's remote-config flags, generated into SGFlagList.m by scripts/extract-flags.py.
typedef NS_ENUM(NSInteger, SGFlagType) { SGFlagUnknown, SGFlagBool, SGFlagInt, SGFlagEnum };
typedef struct { const char *key; SGFlagType type; long value, lower, upper; } SGFlagDef;
extern const SGFlagDef SGFlagTable[];
extern const NSUInteger SGFlagCount;

// Overrides from the Flags page, stored under SGFlagOverridePrefix + key; nil keeps Spotify's value.
extern NSString *const SGFlagOverridePrefix;
id SGFlagOverride(NSString *key);
void SGSetFlagOverride(NSString *key, id value);

// Declutter switches from ui/Settings.x, read by ui/Declutter.x; an unset switch is off.
#define SGHideShuffle @"spotifyglass.hide.shuffle"
#define SGHideRepeat @"spotifyglass.hide.repeat"
#define SGHideConnect @"spotifyglass.hide.connect"
#define SGHideShare @"spotifyglass.hide.share"
#define SGHideQueue @"spotifyglass.hide.queue"
#define SGHideAddTo @"spotifyglass.hide.addTo"
#define SGHideLyricsInline @"spotifyglass.hide.lyricsInline"
#define SGHideLyricsCard @"spotifyglass.hide.lyricsCard"
#define SGHideAboutArtist @"spotifyglass.hide.aboutArtist"
#define SGHideRelatedVideos @"spotifyglass.hide.relatedVideos"
#define SGHideSongDNA @"spotifyglass.hide.songDNA"
#define SGHideLiveEvents @"spotifyglass.hide.liveEvents"
#define SGHideExploreArtist @"spotifyglass.hide.exploreArtist"
#define SGHideCredits @"spotifyglass.hide.credits"
#define SGHideMerch @"spotifyglass.hide.merch"
#define SGHideRecommendations @"spotifyglass.hide.recommendations"
#define SGHideHomeShortcuts @"spotifyglass.hide.homeShortcuts"
#define SGHideHomePills @"spotifyglass.hide.homePills"
#define SGHideHomePromo @"spotifyglass.hide.homePromo"
#define SGHideHomePreviews @"spotifyglass.hide.homePreviews"
#define SGHideHomeDJ @"spotifyglass.hide.homeDJ"
BOOL SGHidden(NSString *key);

// Diagnostics (SGDiagnostics.x)
BOOL SGIsDebugBuild(void);
NSString *SGScreenTree(void);
void SGDumpScreen(NSString *reason);
