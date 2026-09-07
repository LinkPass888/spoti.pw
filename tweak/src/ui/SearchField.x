// Search page: the white search field becomes a glass capsule with white text.
//
// Tree (trees/search.txt): a 370x48 Encore tertiary button, bg white, r=6, holding an
// SPTEncoreIconView and the placeholder label. The class is shared app-wide, so only a wide, light
// instance is touched.
#import "SGCommon.h"

static char kStyledKey;

static void styleSearchField(UIView *button) {
    CGSize size = button.bounds.size;
    if (size.width < 200 || size.height < 40 || size.height > 60) return;
    BOOL styled = [objc_getAssociatedObject(button, &kStyledKey) boolValue];
    if (!styled && !SGIsLightColor(button.layer.backgroundColor)) return;
    objc_setAssociatedObject(button, &kStyledKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    button.layer.backgroundColor = NULL;
    button.layer.cornerRadius = size.height / 2;
    button.layer.cornerCurve = kCACornerCurveContinuous;

    UIVisualEffectView *glass = SGGlassAt(button, 0);
    glass.frame = button.bounds;
    SGShapeGlass(glass, size.height / 2, YES);

    SGForEachView(button, ^(UIView *v) {
        if ([v isKindOfClass:UILabel.class]) ((UILabel *)v).textColor = UIColor.whiteColor;
        else if ([NSStringFromClass(v.class) containsString:@"IconView"]) v.tintColor = UIColor.whiteColor;
    });
}

%hook _TtCCE16Encore_ButtonKitO16EncoreFoundation6Encore6Button8Tertiary
- (void)layoutSubviews {
    %orig;
    styleSearchField((UIView *)self);
}
%end

%ctor {
    %init;
    SGRequireClasses(@[@"_TtCCE16Encore_ButtonKitO16EncoreFoundation6Encore6Button8Tertiary"]);
}
