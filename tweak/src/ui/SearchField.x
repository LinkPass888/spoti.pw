// Search page: the white search field becomes a glass capsule with white text.
//
// Tree (trees/search.txt): SearchHeaderFind.SearchBar, a 370x48 Encore tertiary button painted
// white, r=6, holding SearchHeaderFind.SearchBarIcon and the placeholder label. The button class is
// shared app-wide, so the identifier names the one instance the page owns, with a wide light button
// as the fallback for a build that stops setting it.
//
// Two things about the colours. The glyph is an SPTEncoreIconView, which bakes its colour into what
// it draws, so tintColor never reaches it and setForegroundColor: is the way in. And coming back
// from the full screen search (trees/search opened.txt, a page of its own that this leaves alone)
// Spotify configures the field for a white background again, black glyph and black text, after the
// layout pass that styled it: both are then invisible on the glass until the next pass, a second or
// so later. So the two setters are refused for as long as the field is a capsule.
#import "SGCommon.h"

// Spotify's glyph view, resolved at runtime; declared on UIView so the call and the hook below
// share one declaration.
@interface UIView (SGEncoreIcon)
- (void)setForegroundColor:(UIColor *)color;
@end

static char kStyledKey;
static __weak UIView *sg_searchField;

static BOOL isSearchField(UIView *button) {
    if ([button.accessibilityIdentifier isEqualToString:@"SearchHeaderFind.SearchBar"]) return YES;
    return SGIsLightColor(button.layer.backgroundColor);
}

static void whiten(UIView *view) {
    if ([view isKindOfClass:UILabel.class]) {
        ((UILabel *)view).textColor = UIColor.whiteColor;
    } else if ([NSStringFromClass(view.class) containsString:@"IconView"]) {
        if ([view respondsToSelector:@selector(setForegroundColor:)]) [view setForegroundColor:UIColor.whiteColor];
        else view.tintColor = UIColor.whiteColor;
    }
}

// Debug builds only. The second the field stays invisible after the full screen search closes is
// too short to catch in a tree, so every pass over the field says what it looked like, and the
// silence before the first line says the field did not exist yet.
static void traceField(UIView *button, NSString *when) {
    if (!SGIsDebugBuild()) return;
    UIView *pane = nil, *dim = nil;
    for (UIView *sub in button.subviews) {
        if ([sub isKindOfClass:UIVisualEffectView.class]) pane = sub;
    }
    for (UIView *v = button; v && !dim; v = v.superview) {
        if (v.hidden || v.alpha < 0.99) dim = v;
    }
    SGLog(@"search field %@: window %d, %@, pane %@, hidden by %@", when, button.window != nil,
          NSStringFromCGSize(button.bounds.size), pane ? @"attached" : @"missing",
          dim ? NSStringFromClass(dim.class) : @"nothing");
}

static void styleSearchField(UIView *button) {
    if (!SGEnabled(SGKeySearchField)) return;
    CGSize size = button.bounds.size;
    if (size.width < 200 || size.height < 40 || size.height > 60) return;
    BOOL styled = [objc_getAssociatedObject(button, &kStyledKey) boolValue];
    if (!styled && !isSearchField(button)) return;
    objc_setAssociatedObject(button, &kStyledKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    if (sg_searchField != button) sg_searchField = button;

    button.layer.backgroundColor = NULL;
    button.layer.cornerRadius = size.height / 2;
    button.layer.cornerCurve = kCACornerCurveContinuous;

    UIVisualEffectView *glass = SGGlassAt(button, 0);
    glass.frame = button.bounds;
    SGShapeGlass(glass, size.height / 2, YES);

    SGForEachView(button, ^(UIView *v) { whiten(v); });
    traceField(button, @"styled");
}

%hook _TtCCE16Encore_ButtonKitO16EncoreFoundation6Encore6Button8Tertiary
- (void)layoutSubviews {
    %orig;
    styleSearchField((UIView *)self);
}
// Back from the full screen search the field is styled before it draws, not a layout pass later.
- (void)didMoveToWindow {
    %orig;
    if (isSearchField((UIView *)self)) traceField((UIView *)self, @"moved");
    styleSearchField((UIView *)self);
}
// Spotify builds the field's content again when the page comes back, which can take the pane out
// with it; waiting for the next layout pass to put it back would leave the capsule blank.
- (void)didAddSubview:(UIView *)subview {
    %orig;
    if (![subview isKindOfClass:UIVisualEffectView.class]) styleSearchField((UIView *)self);
}
%end

%hook UILabel
- (void)setTextColor:(UIColor *)color {
    %orig(SGIsInside((UIView *)self, sg_searchField) ? UIColor.whiteColor : color);
}
%end

%hook SPTEncoreIconView
- (void)setForegroundColor:(UIColor *)color {
    %orig(SGIsInside((UIView *)self, sg_searchField) ? UIColor.whiteColor : color);
}
%end

%ctor {
    %init;
    SGRequireClasses(@[@"_TtCCE16Encore_ButtonKitO16EncoreFoundation6Encore6Button8Tertiary", @"SPTEncoreIconView"]);
}
