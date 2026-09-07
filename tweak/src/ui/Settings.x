// Settings: a Mod Settings row at the end of Spotify's settings list opens the mod's own pages,
// Mod Settings (UI Tweaks, a note about the mod) > UI Tweaks (a switch per tweak). The tweaks
// read the switches when they run, so a change shows after Spotify restarts.
//
// Tree (trees/settings.txt): SettingsListViewController.view > SettingsListCollectionView of
//   Element_List cells 402x56: 24pt icon at x 12, 13pt white title and 11pt grey subtitle at
//   x 48, 12pt chevron on the right. A pushed page (trees/settings notifications opened.txt) is a
//   UITableView bg #121212: header with an 11pt grey description at (16, 24), 53pt cells with the
//   title and subtitle at (16, 10) and a 16pt disclosure chevron at x 370.
#import "SGCommon.h"

static const CGFloat kRowHeight = 56;
static char kRowKey, kInsetKey;
static UIFont *sg_titleFont, *sg_subtitleFont;

static UIColor *grey(void) { return [UIColor colorWithWhite:0xB3 / 255.0 alpha:1]; }
static UIFont *titleFont(void) { return sg_titleFont ?: [UIFont systemFontOfSize:13 weight:UIFontWeightBold]; }
static UIFont *subtitleFont(void) { return sg_subtitleFont ?: [UIFont systemFontOfSize:11]; }

static UIImageView *symbol(NSString *name, CGFloat size, UIImageSymbolWeight weight, CGFloat box) {
    UIImage *image = [UIImage systemImageNamed:name withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:size weight:weight]];
    UIImageView *view = [[UIImageView alloc] initWithImage:image];
    view.tintColor = UIColor.whiteColor;
    view.contentMode = UIViewContentModeCenter;
    view.frame = CGRectMake(0, 0, box, box);
    return view;
}

// A grey note in a wrapper view, for the table header and footer.
static UIView *note(NSString *text) {
    UILabel *label = [UILabel new];
    label.text = text;
    label.font = subtitleFont();
    label.textColor = grey();
    label.numberOfLines = 0;
    UIView *wrapper = [UIView new];
    [wrapper addSubview:label];
    return wrapper;
}

// Header and footer views keep the height they are given, so size them to their text. Only the
// size is compared: the table moves the footer's origin itself, and reassigning on that would
// loop forever.
static void fitNote(UITableView *table, UIView *wrapper, CGFloat top, CGFloat bottom) {
    UILabel *label = wrapper.subviews.firstObject;
    CGFloat width = table.bounds.size.width - 32;
    CGFloat height = ceil([label sizeThatFits:CGSizeMake(width, CGFLOAT_MAX)].height);
    label.frame = CGRectMake(16, top, width, height);
    CGSize size = CGSizeMake(table.bounds.size.width, top + height + bottom);
    if (CGSizeEqualToSize(wrapper.bounds.size, size)) return;
    wrapper.frame = (CGRect){wrapper.frame.origin, size};
    if (wrapper == table.tableHeaderView) table.tableHeaderView = wrapper;
    else table.tableFooterView = wrapper;
}

#pragma mark - pages

// A row is a switch when it has a key, a link to another page when it has a page.
@interface SGModRow : NSObject
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSString *subtitle;
@property (nonatomic, copy) NSString *key;
@property (nonatomic, copy) UIViewController *(^page)(void);
@end

@implementation SGModRow
@end

static SGModRow *switchRow(NSString *title, NSString *subtitle, NSString *key) {
    SGModRow *row = [SGModRow new];
    row.title = title;
    row.subtitle = subtitle;
    row.key = key;
    return row;
}

static SGModRow *pageRow(NSString *title, NSString *subtitle, UIViewController *(^page)(void)) {
    SGModRow *row = [SGModRow new];
    row.title = title;
    row.subtitle = subtitle;
    row.page = page;
    return row;
}

@interface SGModPage : UITableViewController
- (instancetype)initWithTitle:(NSString *)title intro:(NSString *)intro rows:(NSArray<SGModRow *> *)rows footer:(NSString *)footer;
@end

@implementation SGModPage {
    NSArray<SGModRow *> *_rows;
    UIView *_intro;
    UIView *_footer;
}

- (instancetype)initWithTitle:(NSString *)title intro:(NSString *)intro rows:(NSArray<SGModRow *> *)rows footer:(NSString *)footer {
    if (!(self = [super initWithStyle:UITableViewStylePlain])) return nil;
    self.title = title;
    _rows = rows;
    _intro = intro ? note(intro) : nil;
    _footer = footer ? note(footer) : nil;
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.overrideUserInterfaceStyle = UIUserInterfaceStyleDark;
    self.tableView.backgroundColor = [UIColor colorWithWhite:0x12 / 255.0 alpha:1];
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    self.tableView.tableHeaderView = _intro;
    self.tableView.tableFooterView = _footer;
}

- (void)viewWillLayoutSubviews {
    [super viewWillLayoutSubviews];
    if (_intro) fitNote(self.tableView, _intro, 24, 8);
    if (_footer) fitNote(self.tableView, _footer, 16, 24);
}

- (NSInteger)tableView:(UITableView *)table numberOfRowsInSection:(NSInteger)section {
    return (NSInteger)_rows.count;
}

- (UITableViewCell *)tableView:(UITableView *)table cellForRowAtIndexPath:(NSIndexPath *)path {
    UITableViewCell *cell = [table dequeueReusableCellWithIdentifier:@"row"]
        ?: [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"row"];
    SGModRow *row = _rows[(NSUInteger)path.row];

    UIListContentConfiguration *content = [UIListContentConfiguration subtitleCellConfiguration];
    content.text = row.title;
    content.secondaryText = row.subtitle;
    content.textProperties.font = titleFont();
    content.textProperties.color = UIColor.whiteColor;
    content.secondaryTextProperties.font = subtitleFont();
    content.secondaryTextProperties.color = grey();
    content.textToSecondaryTextVerticalPadding = 0;
    content.directionalLayoutMargins = NSDirectionalEdgeInsetsMake(10, 16, 10, 16);
    cell.contentConfiguration = content;
    cell.backgroundColor = UIColor.clearColor;

    if (row.key) {
        UISwitch *toggle = [UISwitch new];
        toggle.onTintColor = [UIColor colorWithRed:0x1E / 255.0 green:0xD7 / 255.0 blue:0x60 / 255.0 alpha:1];
        toggle.on = SGEnabled(row.key);
        toggle.tag = path.row;
        [toggle addTarget:self action:@selector(toggled:) forControlEvents:UIControlEventValueChanged];
        cell.accessoryView = toggle;
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
    } else {
        cell.accessoryView = symbol(@"chevron.right", 13, UIImageSymbolWeightSemibold, 16);
        cell.selectionStyle = UITableViewCellSelectionStyleDefault;
    }
    return cell;
}

- (void)tableView:(UITableView *)table didSelectRowAtIndexPath:(NSIndexPath *)path {
    SGModRow *row = _rows[(NSUInteger)path.row];
    if (row.page) [self.navigationController pushViewController:row.page() animated:YES];
}

- (void)toggled:(UISwitch *)toggle {
    SGSetEnabled(_rows[(NSUInteger)toggle.tag].key, toggle.on);
}

@end

static UIViewController *uiTweaksPage(void) {
    return [[SGModPage alloc] initWithTitle:@"UI Tweaks" intro:@"Changes apply after you restart Spotify." rows:@[
        switchRow(@"Now playing bar", @"Glass card with round artwork", SGKeyNowPlayingBar),
        switchRow(@"Tab bar", @"Glass pill behind the tabs, no labels", SGKeyTabBar),
        switchRow(@"Player controls", @"Glass behind the buttons of the full screen player", SGKeyPlayer),
        switchRow(@"Search field", @"Glass capsule instead of the white field", SGKeySearchField),
        switchRow(@"Spotify's own Liquid Glass", @"Turns on the glass navigation bar Spotify ships switched off", SGKeySpotifyGlass),
        switchRow(@"AMOLED background", @"Pure black instead of Spotify's dark grey", SGKeyAmoled),
    ] footer:nil];
}

static UIViewController *modSettingsPage(void) {
    NSString *spotify = [NSBundle.mainBundle objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
    NSString *about = [NSString stringWithFormat:@"spotifyglass %s · Spotify %@\n"
                       "Liquid Glass and other UI tweaks for the Spotify iOS app, a Theos tweak injected into the decrypted IPA.", SG_VERSION, spotify];
    return [[SGModPage alloc] initWithTitle:@"Mod Settings" intro:nil rows:@[
        pageRow(@"UI Tweaks", @"Liquid Glass • AMOLED background", ^UIViewController *{ return uiTweaksPage(); }),
    ] footer:about];
}

#pragma mark - row in the settings list

@interface SGModSettingsRow : UIControl
@end

@implementation SGModSettingsRow {
    UIImageView *_icon;
    UILabel *_title;
    UILabel *_subtitle;
    UIImageView *_chevron;
}

- (instancetype)initWithFrame:(CGRect)frame {
    if (!(self = [super initWithFrame:frame])) return nil;
    _icon = symbol(@"slider.horizontal.3", 20, UIImageSymbolWeightRegular, 24);
    _title = [UILabel new];
    _title.text = @"Mod Settings";
    _title.textColor = UIColor.whiteColor;
    _subtitle = [UILabel new];
    _subtitle.text = @"UI Tweaks";
    _subtitle.textColor = grey();
    _chevron = symbol(@"chevron.right", 11, UIImageSymbolWeightSemibold, 12);
    for (UIView *v in @[_icon, _title, _subtitle, _chevron]) [self addSubview:v];
    [self addTarget:self action:@selector(open) forControlEvents:UIControlEventTouchUpInside];
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    _title.font = titleFont();
    _subtitle.font = subtitleFont();
    CGFloat width = self.bounds.size.width;
    _icon.frame = CGRectMake(12, 16, 24, 24);
    _title.frame = CGRectMake(48, 9, width - 96, 18);
    _subtitle.frame = CGRectMake(48, 31, width - 96, 16);
    _chevron.frame = CGRectMake(width - 24, 22, 12, 12);
}

- (void)setHighlighted:(BOOL)highlighted {
    [super setHighlighted:highlighted];
    self.alpha = highlighted ? 0.5 : 1;
}

- (void)open {
    UIViewController *owner = nil;
    for (UIResponder *r = self; r && !owner; r = r.nextResponder) {
        if ([r isKindOfClass:UIViewController.class]) owner = (UIViewController *)r;
    }
    UIViewController *page = modSettingsPage();
    if (owner.navigationController) [owner.navigationController pushViewController:page animated:YES];
    else [owner presentViewController:[[UINavigationController alloc] initWithRootViewController:page] animated:YES completion:nil];
}

@end

static CGFloat brightness(UIColor *color) {
    CGFloat white = 0;
    [color getWhite:&white alpha:NULL];
    return white;
}

// Spotify's list labels carry its typeface: 13pt titles and 11pt grey subtitles.
static void captureFonts(UIView *list, UIView *row) {
    SGForEachView(list, ^(UIView *v) {
        if (![v isKindOfClass:UILabel.class] || SGIsInside(v, row)) return;
        UILabel *label = (UILabel *)v;
        if (label.text.length < 2) return;
        CGFloat size = label.font.pointSize, white = brightness(label.textColor);
        if (size == 13 && !sg_titleFont) sg_titleFont = label.font;
        if (size == 11 && !sg_subtitleFont && white > 0.3 && white < 0.95) sg_subtitleFont = label.font;
    });
}

static void placeRow(UICollectionView *list, SGModSettingsRow *row) {
    if (!sg_titleFont || !sg_subtitleFont) captureFonts(list, row);
    CGFloat bottom = list.contentSize.height;
    row.hidden = bottom <= 0;
    row.frame = CGRectMake(0, bottom, list.bounds.size.width, kRowHeight);

    // Room to scroll to the row, added again whenever Spotify resets the inset.
    UIEdgeInsets inset = list.contentInset;
    NSValue *applied = objc_getAssociatedObject(list, &kInsetKey);
    if (applied && UIEdgeInsetsEqualToEdgeInsets(inset, applied.UIEdgeInsetsValue)) return;
    inset.bottom += kRowHeight;
    objc_setAssociatedObject(list, &kInsetKey, [NSValue valueWithUIEdgeInsets:inset], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    list.contentInset = inset;
}

%hook _TtC21Settings_PlatformImpl26SettingsListViewController
- (void)viewDidLayoutSubviews {
    %orig;
    for (UIView *sub in ((UIViewController *)self).view.subviews) {
        if (![sub isKindOfClass:UICollectionView.class] || objc_getAssociatedObject(sub, &kRowKey)) continue;
        SGModSettingsRow *row = [[SGModSettingsRow alloc] initWithFrame:CGRectZero];
        objc_setAssociatedObject(sub, &kRowKey, row, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        [sub addSubview:row];
    }
}
%end

// The list lays out after its controller and again whenever its content changes.
%hook UICollectionView
- (void)layoutSubviews {
    %orig;
    SGModSettingsRow *row = objc_getAssociatedObject(self, &kRowKey);
    if (row) placeRow(self, row);
}
%end

%ctor {
    %init;
    SGRequireClasses(@[@"_TtC21Settings_PlatformImpl26SettingsListViewController"]);
}
