// Keeps the areas other tweaks stripped transparent when Spotify repaints them, and learns which
// view is the now playing card from the album-colour paint.
#import "SGCommon.h"

%hook CALayer
- (void)setBackgroundColor:(CGColorRef)color {
    if (color && (sg_nowPlayingRoot || sg_tabBarRoot || sg_lyricsCardRoot || sg_lyricsPageRoot || sg_homeRoot || sg_npvBackdropRoot)) {
        UIView *view = (UIView *)self.delegate;
        if ([view isKindOfClass:UIView.class] && view.layer == self && !SGKeepsColor(view)) {
            if (SGIsInside(view, sg_nowPlayingRoot)) {
                if (SGLooksLikeCard(view, color) && sg_nowPlayingCard != view) {
                    sg_nowPlayingCard = view;
                    UIView *bar = sg_nowPlayingRoot;
                    dispatch_async(dispatch_get_main_queue(), ^{ [bar.superview setNeedsLayout]; });
                }
                if (view == sg_nowPlayingCard) SGRememberCardColor(color);
                // While the full screen player animates, the bar is Spotify's own again.
                if (!sg_nowPlayingStock) color = NULL;
            } else if (SGIsInside(view, sg_tabBarRoot) || SGIsInside(view, sg_lyricsCardRoot)
                       || SGIsInside(view, sg_lyricsPageRoot)) {
                color = NULL;
            } else if (SGIsInside(view, sg_npvBackdropRoot)) {
                // The album colour arrives on the plane per track, outside any layout pass.
                color = NULL;
            } else if (SGIsBaseSurface(color) && SGIsInside(view, sg_homeRoot)) {
                // Home keeps its cards and its placeholders; only the base surface the gradient
                // of ui/HomeGradient.x sits behind goes.
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
