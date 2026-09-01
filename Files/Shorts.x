#import "Headers.h"

// Enables shorts quality - works best with YTClassicVideoQuality
%hook YTHotConfig
- (BOOL)enableOmitAdvancedMenuInShortsVideoQualityPicker { return IS_ENABLED(EnablesShortsQuality) ? YES : %orig; }
- (BOOL)enableShortsVideoQualityPicker { return IS_ENABLED(EnablesShortsQuality) ? YES : %orig; }
- (BOOL)iosEnableImmersiveLivePlayerVideoQuality { return IS_ENABLED(EnablesShortsQuality) ? YES : %orig; }
- (BOOL)iosEnableShortsPlayerVideoQuality { return IS_ENABLED(EnablesShortsQuality) ? YES : %orig; }
- (BOOL)iosEnableShortsPlayerVideoQualityRestartVideo { return IS_ENABLED(EnablesShortsQuality) ? YES : %orig; }
- (BOOL)iosEnableSimplerTitleInShortsVideoQualityPicker { return IS_ENABLED(EnablesShortsQuality) ? YES : %orig; }
- (BOOL)enablePlayerBarForVerticalVideoWhenControlsHiddenInFullscreen { return IS_ENABLED(ShowShortsSeekbar) ? YES : %orig; }
%end

// Always show Shorts seekbar
%hook YTShortsPlayerViewController
- (BOOL)shouldAlwaysEnablePlayerBar { return IS_ENABLED(ShowShortsSeekbar) ? YES : %orig; }
- (BOOL)shouldEnablePlayerBarOnlyOnPause { return IS_ENABLED(ShowShortsSeekbar) ? NO : %orig; }
%end

%hook YTReelPlayerViewControllerSub
- (BOOL)shouldAlwaysEnablePlayerBar { return IS_ENABLED(ShowShortsSeekbar) ? YES : %orig; }
- (BOOL)shouldEnablePlayerBarOnlyOnPause { return IS_ENABLED(ShowShortsSeekbar) ? NO : %orig; }
%end

%hook YTColdConfig
- (BOOL)iosEnableVideoPlayerScrubber { return IS_ENABLED(ShowShortsSeekbar) ? YES : %orig; }
- (BOOL)mobileShortsTablnlinedExpandWatchOnDismiss { return IS_ENABLED(ShowShortsSeekbar) ? YES : %orig; }
%end

static void HPlusMakeAShortsAction(YTReelPlayerViewController *self, YTSingleVideoController *video, YTSingleVideoTime *time) {
    if (INTFORVAL(ShortsActionIndex) == 0) return;

    if (floor(time.time) >= floor(video.totalMediaTime)) {
        if (INTFORVAL(ShortsActionIndex) == 1) {
            [self reelContentViewRequestsAdvanceToNextVideo:nil];
        } else if (INTFORVAL(ShortsActionIndex) == 2) {
            [self reelContentViewRequestsPlayPauseToggle:nil];
        }
    }
}

static BOOL isShortsOnlyOn = YES;
static BOOL isFullscreenEnabled = NO;

%hook YTReelPlayerViewController
- (BOOL)shouldAlwaysEnablePlayerBar { return IS_ENABLED(ShowShortsSeekbar) ? YES : %orig; }
- (BOOL)shouldEnablePlayerBarOnlyOnPause { return IS_ENABLED(ShowShortsSeekbar) ? NO : %orig; }
- (void)singleVideo:(YTSingleVideoController *)video currentVideoTimeDidChange:(YTSingleVideoTime *)time {
    %orig;
    HPlusMakeAShortsAction(self, video, time);
}
- (void)loadPlayerBar {
    %orig;
    if ((isShortsOnlyOn && IS_ENABLED(ShortsOnly)) || (isFullscreenEnabled && IS_ENABLED(FullScreenShorts))) [[self valueForKey:@"_pivotBarProvider"] performSelector:@selector(hidePivotBar)];
    YTPlayerViewController *main = self.player;
    if (INTFORVAL(CaptionTrack) != 0) [main performSelector:@selector(HPlusAutoCaptions) withObject:nil afterDelay:0.5];
    if (INTFORVAL(AutoSpeedIndex) != 0) [main performSelector:@selector(HPlusSetAutoSpeed) withObject:nil afterDelay:0.5];
    if (INTFORVAL(AudioTrack) != 0) [self performSelector:@selector(HPlusAutoAudioTrack:) withObject:main afterDelay:0.5];
}
%new
- (void)HPlusAutoAudioTrack:(YTPlayerViewController *)pv {
    NSInteger selectedIndex = INTFORVAL(AudioTrackLangIndex);
    NSArray *langCodes = getAllSystemLanguageValues();
    NSString *userTargetLang = langCodes[selectedIndex];
    id switchcon = self.audioTrackController;
    NSArray *availableTracks = [switchcon valueForKey:@"_availableAudioTracks"];
    if (!availableTracks || availableTracks.count == 0) return;
    YTIAudioTrack *matchedTrack = nil;

    if (INTFORVAL(AudioTrack) == 1) {
        // Loop for all tracks
        for (YTIAudioTrack *track in availableTracks) {
            if ([track.id_p hasSuffix:@".4"]) {
                matchedTrack = track;
                break;
            }
        }
    } else if (INTFORVAL(AudioTrack) == 2) {
        // Loop for all tracks
        for (YTIAudioTrack *track in availableTracks) {
            if ([track.id_p hasPrefix:userTargetLang]) {
                matchedTrack = track;
                break;
            }
        }

        // Check if it's dubbed
        if (matchedTrack && [matchedTrack isAutoDubbed] && IS_ENABLED(NoDubbedAudioTrack)) matchedTrack = nil;

        if (!matchedTrack && IS_ENABLED(NoDubbedAudioTrack)) {
            for (YTIAudioTrack *track in availableTracks) {
                if ([track.id_p hasSuffix:@".4"]) {
                    matchedTrack = track;
                    break;
                }
            }
        }
    }

    // If found, change to it
    if (matchedTrack) {
        [pv setAudioTrack:matchedTrack source:0];
    }
}
%end

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

extern void HPlusConfigureDownloadButton(_ASDisplayView *view);

static void HPlusFilterShortsButtons(UIView *self, NSString *iden) {
    NSDictionary *buttonsList = @{
        @"id.reel_like_button": @(IS_ENABLED(RemoveShortsLikeButton)),
        @"id.reel_like_toggled_button": @(IS_ENABLED(RemoveShortsLikeButton)),
        @"id.reel_comment_button": @(IS_ENABLED(RemoveShortsCommentButton)),
        @"id.reel_share_button": @(IS_ENABLED(RemoveShortsShareButton)),
        @"id.reel_save_button": @(IS_ENABLED(RemoveShortsSaveButton)),
        @"id.reel_remix_button" : @(IS_ENABLED(RemoveShortsRemixButton)),
        @"id.reel_player_description_label_button": @(IS_ENABLED(RemoveShortsTitleButton)),
        @"id.reel_pivot_button": @(IS_ENABLED(RemoveShortsSoundMetadataButton))
    };
    for (NSString *button in buttonsList) {
        if ([iden isEqualToString:button] && [buttonsList[button] boolValue]) {
            _ASDisplayView *mainView = (_ASDisplayView *)self.superview;
            ASDisplayNode *node = mainView.keepalive_node;
            for (_ASDisplayView *view in node.yogaChildren) {
                if ([[view description] containsString:button]) {
                    [node removeYogaChild:view];
                    [self removeFromSuperview];
                    break;
                }
            }
            break;
        }
    }
}

static void HPlusFilterShortsPausedHeader(_ASDisplayView *self, NSString *iden) {
    NSDictionary *buttonsList = @{
        @"id.ui.shorts_paused_state.subscriptions_button": @(IS_ENABLED(RemoveShortsPausedSubButton)),
        @"id.ui.shorts_paused_state.live_button": @(IS_ENABLED(RemoveShortsPausedLiveButton)),
        @"id.ui.shorts_paused_state.lens_button": @(IS_ENABLED(RemoveShortsPausedLensButton)),
        @"id.ui.shorts_paused_state.trends_button" : @(IS_ENABLED(RemoveShortsPausedTrendsButton))
    };
    for (NSString *button in buttonsList) {
        if ([iden isEqualToString:button] && [buttonsList[button] boolValue]) {
            ASScrollView *mainView = (ASScrollView *)self.superview;
            ASDisplayNode *node = mainView.scrollNode;
            for (_ASDisplayView *view in node.yogaChildren) {
                if ([[view description] containsString:button]) {
                    [node removeYogaChild:view];
                    [self removeFromSuperview];
                    break;
                }
            }
            break;
        }
    }
}

static void HPlusFilterShortsDisclosure(_ASDisplayView *self, NSString *iden) {
    if (![self.accessibilityIdentifier isEqualToString:@"eml.shorts-disclosures"] || !IS_ENABLED(RemoveShortsDisclosure)) return;
    _ASDisplayView *dpView = (_ASDisplayView *)self.superview;
    ASDisplayNode *node = dpView.keepalive_node;
    _ASDisplayView *maindpView = (_ASDisplayView *)dpView.superview;
    ASDisplayNode *mainNode = maindpView.keepalive_node;
    [mainNode removeYogaChild:node];
    [maindpView removeFromSuperview];
}

// _ASDisplayView filters
%hook _ASDisplayView
- (void)didMoveToWindow {
    %orig;
    HPlusConfigureDownloadButton(self);
    NSString *iden = self.accessibilityIdentifier;
    if (!iden || iden.length == 0) return;
    NSDictionary *elements = @{
        @"product_sticker.main_target": @(IS_ENABLED(HideShortsProducts)),
        @"product_sticker.secondary_target": @(IS_ENABLED(HideShortsProducts)),
        @"id.elements.components.suggested_action": @(IS_ENABLED(HideShortsRecbar))
    };
    if ([elements[iden] boolValue]) {
        [self removeFromSuperview];
        return;
    }
    if ([iden isEqualToString:@"eml.reel_sponsor_button"] && IS_ENABLED(RemoveChannelSponsorAll)) {
        [self.superview removeFromSuperview];
        return;
    }
    
    HPlusFilterShortsButtons(self, iden);
    HPlusFilterShortsPausedHeader(self, iden);
    HPlusFilterShortsDisclosure(self, iden);
}
%end

%hook YTAppDelegate
- (void)appDidBecomeActive {
    %orig;
    if ((isFullscreenEnabled && IS_ENABLED(FullScreenShorts)) || (isShortsOnlyOn && IS_ENABLED(ShortsOnly))) {
        [[self valueForKey:@"_appViewController"] performSelector:@selector(hidePivotBar)];
    }
}
%end

%hook YTReelWatchPlaybackOverlayView
%property (nonatomic, retain) UIPinchGestureRecognizer *HPlusFullscreenGesture;
- (void)didMoveToWindow {
    %orig;
    if (!IS_ENABLED(FullScreenShorts)) return;
    if (!self.HPlusFullscreenGesture) {
        self.HPlusFullscreenGesture = [[UIPinchGestureRecognizer alloc] initWithTarget:self action:@selector(HPlusFullscrrenGestureHandler:)];
        self.HPlusFullscreenGesture.delegate = (id<UIGestureRecognizerDelegate>)self;
        [self.superview addGestureRecognizer:self.HPlusFullscreenGesture];
    }
}
%new
- (void)HPlusFullscrrenGestureHandler:(UIPinchGestureRecognizer *)gesture {
    if (gesture.state != UIGestureRecognizerStateBegan || (isShortsOnlyOn && IS_ENABLED(ShortsOnly))) return;
    UIViewController *appVC = [self valueForKey:@"_pivotBarProvider"];
    BOOL isTabBarHidden = [appVC performSelector:@selector(isPivotBarHidden)];
    if (gesture.scale > 1.0) {
        if (!isTabBarHidden) {
            [appVC performSelector:@selector(hidePivotBar)];
            [UIView animateWithDuration:0.3 animations:^{
                self.alpha = 0;
            }];
            isFullscreenEnabled = YES;
        }
    } else if (gesture.scale < 1.0) {
        if (isTabBarHidden) {
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
    if (gestureRecognizer == self.HPlusFullscreenGesture) {
        return YES;
    }
    return NO;
}
%end

%hook YTReelContentView
%property (nonatomic, retain) UILongPressGestureRecognizer *HPlusExitShortsOnlyGesture;
- (void)setPlaybackView:(id)arg1 {
    %orig;
    self.playbackOverlay.alpha = !isFullscreenEnabled;
    if (!IS_ENABLED(ShortsOnly)) return;
    if (isShortsOnlyOn) {
        self.HPlusExitShortsOnlyGesture = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(HPlusTurnOffShortsOnly:)];
        self.HPlusExitShortsOnlyGesture.numberOfTouchesRequired = 2;
        self.HPlusExitShortsOnlyGesture.minimumPressDuration = 0.5;
        self.HPlusExitShortsOnlyGesture.delegate = (id<UIGestureRecognizerDelegate>)self;
        [self addGestureRecognizer:self.HPlusExitShortsOnlyGesture];
    }
}
%new
- (void)HPlusTurnOffShortsOnly:(UILongPressGestureRecognizer *)gesture {
    if (gesture.state != UIGestureRecognizerStateBegan) return;
    isShortsOnlyOn = NO;
    UIView *parent = sbGetNotificationParent();
    [SBSkipNotificationView showSuccessInView:parent message:LOC(@"SHORTS_ONLY_DISABLED") duration:3.0];

    [[[[self valueForKey:@"_parentResponder"] valueForKey:@"_delegate"] valueForKey:@"_pivotBarProvider"] performSelector:@selector(showPivotBar)];
    [UIView animateWithDuration:0.3 animations:^{
        self.playbackOverlay.alpha = 1;
    }];
}
%new
- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldBeRequiredToFailByGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer {
    if (gestureRecognizer == self.HPlusExitShortsOnlyGesture && [otherGestureRecognizer isKindOfClass:[UILongPressGestureRecognizer class]]) {
        return YES;
    }
    return NO;
}
%new
- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer {
    if (gestureRecognizer == self.HPlusExitShortsOnlyGesture) {
        return NO;
    }
    return YES;
}
%end