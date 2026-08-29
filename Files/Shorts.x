#import "Headers.h"

// ============================================================
// MARK: - هوكات جودة الفيديو
// ============================================================
%hook YTHotConfig
- (BOOL)enableOmitAdvancedMenuInShortsVideoQualityPicker { 
    return IS_ENABLED(EnablesShortsQuality) ? YES : %orig; 
}
- (BOOL)enableShortsVideoQualityPicker { 
    return IS_ENABLED(EnablesShortsQuality) ? YES : %orig; 
}
- (BOOL)iosEnableImmersiveLivePlayerVideoQuality { 
    return IS_ENABLED(EnablesShortsQuality) ? YES : %orig; 
}
- (BOOL)iosEnableShortsPlayerVideoQuality { 
    return IS_ENABLED(EnablesShortsQuality) ? YES : %orig; 
}
- (BOOL)iosEnableShortsPlayerVideoQualityRestartVideo { 
    return IS_ENABLED(EnablesShortsQuality) ? YES : %orig; 
}
- (BOOL)iosEnableSimplerTitleInShortsVideoQualityPicker { 
    return IS_ENABLED(EnablesShortsQuality) ? YES : %orig; 
}
- (BOOL)enablePlayerBarForVerticalVideoWhenControlsHiddenInFullscreen { 
    return IS_ENABLED(ShowShortsSeekbar) ? YES : %orig; 
}
%end

// ============================================================
// MARK: - هوكات شريط التقدم (Seekbar)
// ============================================================
%hook YTShortsPlayerViewController
- (BOOL)shouldAlwaysEnablePlayerBar { 
    return IS_ENABLED(ShowShortsSeekbar) ? YES : %orig; 
}
- (BOOL)shouldEnablePlayerBarOnlyOnPause { 
    return IS_ENABLED(ShowShortsSeekbar) ? NO : %orig; 
}
%end

%hook YTReelPlayerViewControllerSub
- (BOOL)shouldAlwaysEnablePlayerBar { 
    return IS_ENABLED(ShowShortsSeekbar) ? YES : %orig; 
}
- (BOOL)shouldEnablePlayerBarOnlyOnPause { 
    return IS_ENABLED(ShowShortsSeekbar) ? NO : %orig; 
}
%end

%hook YTColdConfig
- (BOOL)iosEnableVideoPlayerScrubber { 
    return IS_ENABLED(ShowShortsSeekbar) ? YES : %orig; 
}
- (BOOL)mobileShortsTabInlinedExpandWatchOnDismiss { 
    return IS_ENABLED(ShowShortsSeekbar) ? YES : %orig; 
}
%end

// ============================================================
// MARK: - إجراءات نهاية الفيديو (Auto Next / Auto Pause)
// ============================================================
static void YouModMakeAShortsAction(YTReelPlayerViewController *self, YTSingleVideoController *video, YTSingleVideoTime *time) {
    if (INTFORVAL(ShortsActionIndex) == 0) return;
    
    if (time.time >= video.totalMediaTime - 0.1) {
        id contentView = [self valueForKey:@"contentView"];
        if (!contentView) return;
        
        if (INTFORVAL(ShortsActionIndex) == 1) {
            if ([contentView respondsToSelector:@selector(reelContentViewRequestsAdvanceToNextVideo:)]) {
                [contentView reelContentViewRequestsAdvanceToNextVideo:nil];
            }
        } else if (INTFORVAL(ShortsActionIndex) == 2) {
            if ([contentView respondsToSelector:@selector(reelContentViewRequestsPlayPauseToggle:)]) {
                [contentView reelContentViewRequestsPlayPauseToggle:nil];
            }
        }
    }
}

static BOOL isShortsOnlyOn = YES;
static BOOL isFullscreenEnabled = NO;

// ============================================================
// MARK: - هوك YTReelPlayerViewController (الرئيسي)
// ============================================================
%hook YTReelPlayerViewController
- (BOOL)shouldAlwaysEnablePlayerBar { 
    return IS_ENABLED(ShowShortsSeekbar) ? YES : %orig; 
}
- (BOOL)shouldEnablePlayerBarOnlyOnPause { 
    return IS_ENABLED(ShowShortsSeekbar) ? NO : %orig; 
}

- (void)singleVideo:(YTSingleVideoController *)video currentVideoTimeDidChange:(YTSingleVideoTime *)time {
    %orig;
    YouModMakeAShortsAction(self, video, time);
}

- (void)loadPlayerBar {
    %orig;
    
    if ((isShortsOnlyOn && IS_ENABLED(ShortsOnly)) || (isFullscreenEnabled && IS_ENABLED(FullScreenShorts))) {
        id pivotBarProvider = [self valueForKey:@"_pivotBarProvider"];
        if (pivotBarProvider && [pivotBarProvider respondsToSelector:@selector(hidePivotBar)]) {
            [pivotBarProvider performSelector:@selector(hidePivotBar)];
        }
    }
    
    YTPlayerViewController *main = self.player;
    if (!main) return;
    
    if (INTFORVAL(CaptionTrack) != 0) {
        SEL captionsSelector = NSSelectorFromString(@"YouModAutoCaptions");
        if ([main respondsToSelector:captionsSelector]) {
            [main performSelector:captionsSelector withObject:nil afterDelay:0.5];
        }
    }
    
    if (INTFORVAL(AutoSpeedIndex) != 0) {
        SEL speedSelector = NSSelectorFromString(@"YouModSetAutoSpeed");
        if ([main respondsToSelector:speedSelector]) {
            [main performSelector:speedSelector withObject:nil afterDelay:0.5];
        }
    }
    
    if (INTFORVAL(AudioTrack) != 0) {
        SEL audioSelector = NSSelectorFromString(@"YouModAutoAudioTrack:");
        if ([self respondsToSelector:audioSelector]) {
            [self performSelector:audioSelector withObject:main afterDelay:0.5];
        }
    }
}

%new
- (void)YouModAutoAudioTrack:(YTPlayerViewController *)pv {
    if (!pv) return;
    
    NSInteger selectedIndex = INTFORVAL(AudioTrackLangIndex);
    NSArray *langCodes = getAllSystemLanguageValues();
    if (selectedIndex >= langCodes.count) return;
    NSString *userTargetLang = langCodes[selectedIndex];
    
    id switchcon = self.audioTrackController;
    if (!switchcon) return;
    
    NSArray *availableTracks = [switchcon valueForKey:@"_availableAudioTracks"];
    if (!availableTracks || availableTracks.count == 0) return;
    
    YTIAudioTrack *matchedTrack = nil;
    
    if (INTFORVAL(AudioTrack) == 1) {
        for (YTIAudioTrack *track in availableTracks) {
            if ([track.id_p hasSuffix:@".4"]) {
                matchedTrack = track;
                break;
            }
        }
    } else if (INTFORVAL(AudioTrack) == 2) {
        for (YTIAudioTrack *track in availableTracks) {
            if ([track.id_p hasPrefix:userTargetLang]) {
                matchedTrack = track;
                break;
            }
        }
        
        if (matchedTrack && [matchedTrack isAutoDubbed] && IS_ENABLED(NoDubbedAudioTrack)) {
            matchedTrack = nil;
        }
        
        if (!matchedTrack && IS_ENABLED(NoDubbedAudioTrack)) {
            for (YTIAudioTrack *track in availableTracks) {
                if ([track.id_p hasSuffix:@".4"]) {
                    matchedTrack = track;
                    break;
                }
            }
        }
    }
    
    if (matchedTrack && [pv respondsToSelector:@selector(setAudioTrack:source:)]) {
        [pv setAudioTrack:matchedTrack source:0];
    }
}
%end

// ============================================================
// MARK: - هوك YTReelTopBarView (إخفاء الشريط العلوي)
// ============================================================
%hook YTReelTopBarView
- (void)didMoveToWindow {
    %orig;
    if (IS_ENABLED(HideShortsTopbar)) {
        if (self.superview) {
            [self removeFromSuperview];
        }
    } else if (IS_ENABLED(HideShortsSubbar)) {
        UIView *subbar = [self valueForKey:@"_pausedStateCarouselView"];
        if (subbar && subbar.superview) {
            [subbar removeFromSuperview];
        }
    }
}
%end

// ============================================================
// MARK: - تصفية الأزرار (طريقة آمنة باستخدام hidden)
// ============================================================
static void YouModFilterShortsButtons(UIView *self, NSString *iden) {
    NSDictionary *buttonsList = @{
        @"id.reel_like_button": @(IS_ENABLED(RemoveShortsLikeButton)),
        @"id.reel_like_toggled_button": @(IS_ENABLED(RemoveShortsLikeButton)),
        @"id.reel_comment_button": @(IS_ENABLED(RemoveShortsCommentButton)),
        @"id.reel_share_button": @(IS_ENABLED(RemoveShortsShareButton)),
        @"id.reel_remix_button" : @(IS_ENABLED(RemoveShortsRemixButton)),
        @"id.reels_smv_player_title_label": @(IS_ENABLED(RemoveShortsTitle)),
        @"id.reel_pivot_button": @(IS_ENABLED(RemoveShortsSoundMetadataButton))
    };
    
    for (NSString *button in buttonsList) {
        if ([iden isEqualToString:button] && [buttonsList[button] boolValue]) {
            self.hidden = YES;
            self.userInteractionEnabled = NO;
            break;
        }
    }
}

static void YouModFilterShortsPausedHeader(UIView *self, NSString *iden) {
    NSDictionary *buttonsList = @{
        @"id.ui.shorts_paused_state.subscriptions_button": @(IS_ENABLED(RemoveShortsPausedSubButton)),
        @"id.ui.shorts_paused_state.live_button": @(IS_ENABLED(RemoveShortsPausedLiveButton)),
        @"id.ui.shorts_paused_state.lens_button": @(IS_ENABLED(RemoveShortsPausedLensButton)),
        @"id.ui.shorts_paused_state.trends_button" : @(IS_ENABLED(RemoveShortsPausedTrendsButton))
    };
    
    for (NSString *button in buttonsList) {
        if ([iden isEqualToString:button] && [buttonsList[button] boolValue]) {
            self.hidden = YES;
            self.userInteractionEnabled = NO;
            break;
        }
    }
}

// ============================================================
// MARK: - هوك _ASDisplayView (تصفية العناصر)
// ============================================================
%hook _ASDisplayView
- (void)didMoveToWindow {
    %orig;
    
    NSString *iden = self.accessibilityIdentifier;
    if (!iden || iden.length == 0) return;
    
    NSDictionary *elements = @{
        @"product_sticker.main_target": @(IS_ENABLED(HideShortsProducts)),
        @"product_sticker.secondary_target": @(IS_ENABLED(HideShortsProducts)),
        @"id.elements.components.suggested_action": @(IS_ENABLED(HideShortsRecbar))
    };
    
    if ([elements[iden] boolValue]) {
        self.hidden = YES;
        self.userInteractionEnabled = NO;
        return;
    }
    
    if ([iden isEqualToString:@"eml.reel_sponsor_button"] && IS_ENABLED(RemoveChannelSponsorAll)) {
        if (self.superview) {
            self.superview.hidden = YES;
            self.superview.userInteractionEnabled = NO;
        }
        return;
    }
    
    YouModFilterShortsButtons(self, iden);
    YouModFilterShortsPausedHeader(self, iden);
    YouModFilterShortsDescription(self, iden);
    YouModFilterShortsDisclosure(self, iden);
}
%end

// ============================================================
// MARK: - هوك إخفاء Pivot Bar عند التفعيل
// ============================================================
%hook YTAppDelegate
- (void)appDidBecomeActive {
    %orig;
    if ((isFullscreenEnabled && IS_ENABLED(FullScreenShorts)) || (isShortsOnlyOn && IS_ENABLED(ShortsOnly))) {
        id appVC = [self valueForKey:@"_appViewController"];
        if (appVC && [appVC respondsToSelector:@selector(hidePivotBar)]) {
            [appVC performSelector:@selector(hidePivotBar)];
        }
    }
}
%end

// ============================================================
// MARK: - هوك ملء الشاشة (Fullscreen via Pinch Gesture)
// ============================================================
%hook YTReelWatchPlaybackOverlayView
%property (nonatomic, retain) UIPinchGestureRecognizer *YouModFullscreenGesture;

- (void)didMoveToWindow {
    %orig;
    if (!IS_ENABLED(FullScreenShorts)) return;
    if (!self.YouModFullscreenGesture) {
        self.YouModFullscreenGesture = [[UIPinchGestureRecognizer alloc] initWithTarget:self action:@selector(YouModFullscreenGestureHandler:)];
        self.YouModFullscreenGesture.delegate = (id<UIGestureRecognizerDelegate>)self;
        [self addGestureRecognizer:self.YouModFullscreenGesture];
    }
}

%new
- (void)YouModFullscreenGestureHandler:(UIPinchGestureRecognizer *)gesture {
    if (gesture.state != UIGestureRecognizerStateBegan) return;
    if (isShortsOnlyOn && IS_ENABLED(ShortsOnly)) return;
    
    id appVC = [self valueForKey:@"_pivotBarProvider"];
    if (!appVC) return;
    
    BOOL isTabBarHidden = NO;
    if ([appVC respondsToSelector:@selector(isPivotBarHidden)]) {
        isTabBarHidden = [appVC performSelector:@selector(isPivotBarHidden)];
    }
    
    if (gesture.scale > 1.0) {
        if (!isTabBarHidden && [appVC respondsToSelector:@selector(hidePivotBar)]) {
            [appVC performSelector:@selector(hidePivotBar)];
            [UIView animateWithDuration:0.3 animations:^{
                self.alpha = 0;
            }];
            isFullscreenEnabled = YES;
        }
    } else if (gesture.scale < 1.0) {
        if (isTabBarHidden && [appVC respondsToSelector:@selector(showPivotBar)]) {
            [appVC performSelector:@selector(showPivotBar)];
            [UIView animateWithDuration:0.3 animations:^{
                self.alpha = 1;
            }];
            isFullscreenEnabled = NO;
        }
    }
}

%new
- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer {
    return gestureRecognizer == self.YouModFullscreenGesture;
}
%end

// ============================================================
// MARK: - هوك إلغاء وضع ShortsOnly (ضغطة مطولة بإصبعين)
// ============================================================
%hook YTReelContentView
%property (nonatomic, retain) UILongPressGestureRecognizer *YouModExitShortsOnlyGesture;

- (void)setPlaybackView:(id)arg1 {
    %orig;
    self.playbackOverlay.alpha = isFullscreenEnabled ? 0 : 1;
    
    if (!IS_ENABLED(ShortsOnly)) return;
    
    if (isShortsOnlyOn && !self.YouModExitShortsOnlyGesture) {
        self.YouModExitShortsOnlyGesture = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(YouModTurnOffShortsOnly:)];
        self.YouModExitShortsOnlyGesture.numberOfTouchesRequired = 2;
        self.YouModExitShortsOnlyGesture.minimumPressDuration = 0.5;
        self.YouModExitShortsOnlyGesture.delegate = (id<UIGestureRecognizerDelegate>)self;
        [self addGestureRecognizer:self.YouModExitShortsOnlyGesture];
    }
}

%new
- (void)YouModTurnOffShortsOnly:(UILongPressGestureRecognizer *)gesture {
    if (gesture.state != UIGestureRecognizerStateBegan) return;
    
    isShortsOnlyOn = NO;
    
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Shorts Only Disabled"
                                                                   message:@"You can now browse other content"
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
    
    // ✅ FIX: Suppress deprecation warning for keyWindow
    #pragma clang diagnostic push
    #pragma clang diagnostic ignored "-Wdeprecated-declarations"
    UIViewController *topVC = [UIApplication sharedApplication].keyWindow.rootViewController;
    #pragma clang diagnostic pop
    
    if (topVC) {
        [topVC presentViewController:alert animated:YES completion:nil];
    }
    
    id parentResponder = [self valueForKey:@"_parentResponder"];
    id delegate = [parentResponder valueForKey:@"_delegate"];
    id pivotBarProvider = [delegate valueForKey:@"_pivotBarProvider"];
    if (pivotBarProvider && [pivotBarProvider respondsToSelector:@selector(showPivotBar)]) {
        [pivotBarProvider performSelector:@selector(showPivotBar)];
    }
    
    [UIView animateWithDuration:0.3 animations:^{
        self.playbackOverlay.alpha = 1;
    }];
}

%new
- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldBeRequiredToFailByGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer {
    if (gestureRecognizer == self.YouModExitShortsOnlyGesture && [otherGestureRecognizer isKindOfClass:[UILongPressGestureRecognizer class]]) {
        return YES;
    }
    return NO;
}

%new
- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer {
    return gestureRecognizer != self.YouModExitShortsOnlyGesture;
}
%end