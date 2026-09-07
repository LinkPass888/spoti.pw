// Keeps the areas other tweaks stripped transparent when Spotify repaints them, and learns which
// view is the now playing card from the album-colour paint.
#import "SGCommon.h"

%hook CALayer
- (void)setBackgroundColor:(CGColorRef)color {
    if (color && (sg_nowPlayingRoot || sg_tabBarRoot)) {
        UIView *view = (UIView *)self.delegate;
        if ([view isKindOfClass:UIView.class] && view.layer == self && !SGKeepsColor(view)) {
            if (SGIsInside(view, sg_nowPlayingRoot)) {
                if (SGLooksLikeCard(view, color) && sg_nowPlayingCard != view) {
                    sg_nowPlayingCard = view;
                    UIView *bar = sg_nowPlayingRoot;
                    dispatch_async(dispatch_get_main_queue(), ^{ [bar.superview setNeedsLayout]; });
                }
                color = NULL;
            } else if (SGIsInside(view, sg_tabBarRoot)) {
                color = NULL;
            }
        }
    }
    %orig(color);
}
%end

%ctor {
    %init;
}
