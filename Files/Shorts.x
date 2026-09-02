#import "Headers.h"

@interface _ASDisplayView (HPlusShorts)
- (void)HPlusProcessShortsElementAutomatically:(NSString *)iden;
@end

%hook _ASDisplayView

%new
- (void)HPlusProcessShortsElementAutomatically:(NSString *)iden {
    // جمع كافة المعرفات والنصوص المتاحة للعنصر لفحصها بدقة
    NSString *identifier = iden ?: @"";
    NSString *label = self.accessibilityLabel ?: @"";
    NSString *desc = [self description] ?: @"";
    
    // دمج النصوص للبحث الشامل
    NSString *fullContext = [NSString stringWithFormat:@"%@ %@ %@", identifier, label, desc];
    if (fullContext.length == 0) return;

    // 1. التعامل التلقائي مع النصوص والعناوين والوصف
    if ([identifier containsString:@"description"] || 
        [identifier containsString:@"title"] || 
        [identifier containsString:@"reel.player"] || 
        [identifier containsString:@"YTReelTitle"]) {
        if (IS_ENABLED(RemoveShortsTitleButton)) {
            self.hidden = YES;
            self.userInteractionEnabled = NO;
            self.alpha = 0.0;
        }
        return;
    }

    // 2. ارتباط الفيديو المرتبط (Related Video Link) - بحث أشمل
    if ([fullContext containsString:@"related_video"] || [fullContext containsString:@"reel_metadata"] || [fullContext containsString:@"related-video"]) {
        if (IS_ENABLED(RemoveShortsRelatedVideo)) {
            self.hidden = YES;
            self.userInteractionEnabled = NO;
            self.alpha = 0.0;
            return;
        }
    }

    // 3. اسم القناة / الحساب وزر الاشتراك (Channel Name & Subscribe) - بحث أشمل
    if ([fullContext containsString:@"channel_name"] || [fullContext containsString:@"owner"] || [fullContext containsString:@"subscribe"] || [fullContext containsString:@"author"]) {
        if (IS_ENABLED(RemoveShortsChannelName)) {
            self.hidden = YES;
            self.userInteractionEnabled = NO;
            self.alpha = 0.0;
            return;
        }
    }

    // 4. شريط الصوت / الأغنية (Audio / Sound Track) - بحث أشمل
    if ([fullContext containsString:@"audio"] || [fullContext containsString:@"sound"] || [fullContext containsString:@"track"] || [fullContext containsString:@"music"]) {
        if (IS_ENABLED(RemoveShortsSoundButton)) {
            self.hidden = YES;
            self.userInteractionEnabled = NO;
            self.alpha = 0.0;
            return;
        }
    }

    // 5. أزرار التفاعل (لايك، تعليق، مشاركة، حفظ، ريمكس...)
    if ([identifier containsString:@"reel_like"] || 
        [identifier containsString:@"reel_comment"] || 
        [identifier containsString:@"reel_share"] || 
        [identifier containsString:@"reel_save"] || 
        [identifier containsString:@"reel_remix"] || 
        [identifier containsString:@"reel_pivot"]) {
        
        BOOL shouldRemove = NO;
        if ([identifier containsString:@"like"] && IS_ENABLED(RemoveShortsLikeButton)) shouldRemove = YES;
        else if ([identifier containsString:@"comment"] && IS_ENABLED(RemoveShortsCommentButton)) shouldRemove = YES;
        else if ([identifier containsString:@"share"] && IS_ENABLED(RemoveShortsShareButton)) shouldRemove = YES;
        else if ([identifier containsString:@"save"] && IS_ENABLED(RemoveShortsSaveButton)) shouldRemove = YES;
        else if ([identifier containsString:@"remix"] && IS_ENABLED(RemoveShortsRemixButton)) shouldRemove = YES;
        else if ([identifier containsString:@"pivot"] && IS_ENABLED(RemoveShortsSoundMetadataButton)) shouldRemove = YES;

        if (shouldRemove) {
            ASDisplayNode *node = [self keepalive_node];
            if (node) {
                for (_ASDisplayView *view in node.yogaChildren) {
                    if ([[[view description] stringByAppendingString:view.accessibilityLabel ?: @""] containsString:identifier]) {
                        [node removeYogaChild:view];
                        [self removeFromSuperview];
                        break;
                    }
                }
            }
        }
        return;
    }

    // 6. القائمة المؤقتة للشورتز (Paused State)
    if ([identifier containsString:@"shorts_paused_state"]) {
        BOOL shouldRemove = NO;
        if ([identifier containsString:@"subscriptions"] && IS_ENABLED(RemoveShortsPausedSubButton)) shouldRemove = YES;
        else if ([identifier containsString:@"live"] && IS_ENABLED(RemoveShortsPausedLiveButton)) shouldRemove = YES;
        else if ([identifier containsString:@"lens"] && IS_ENABLED(RemoveShortsPausedLensButton)) shouldRemove = YES;
        else if ([identifier containsString:@"trends"] && IS_ENABLED(RemoveShortsPausedTrendsButton)) shouldRemove = YES;

        if (shouldRemove) {
            ASScrollView *scrollView = (ASScrollView *)self.superview;
            ASDisplayNode *node = [scrollView scrollNode];
            if (node) {
                for (_ASDisplayView *view in node.yogaChildren) {
                    if ([[[view description] stringByAppendingString:view.accessibilityLabel ?: @""] containsString:identifier]) {
                        [node removeYogaChild:view];
                        [self removeFromSuperview];
                        break;
                    }
                }
            }
        }
        return;
    }

    // 7. المنتجات والإعلانات والرعاة
    if ([identifier containsString:@"product_sticker"] && IS_ENABLED(HideShortsProducts)) {
        [self removeFromSuperview];
        return;
    }
    if ([identifier containsString:@"suggested_action"] && IS_ENABLED(HideShortsRecbar)) {
        if (self.superview) {
            [self.superview removeFromSuperview];
        } else {
            [self removeFromSuperview];
        }
        return;
    }
    if ([identifier containsString:@"reel_sponsor_button"] && IS_ENABLED(RemoveChannelSponsorAll)) {
        [self.superview removeFromSuperview];
        return;
    }

    // 8. الإفصاحات (Disclosures)
    if ([identifier containsString:@"shorts-disclosures"] && IS_ENABLED(RemoveShortsDisclosure)) {
        _ASDisplayView *dpView = (_ASDisplayView *)self.superview;
        ASDisplayNode *node = [dpView keepalive_node];
        _ASDisplayView *maindpView = (_ASDisplayView *)dpView.superview;
        ASDisplayNode *mainNode = [maindpView keepalive_node];
        [mainNode removeYogaChild:node];
        [maindpView removeFromSuperview];
        return;
    }
}

- (void)didMoveToWindow {
    %orig;
    [self HPlusProcessShortsElementAutomatically:self.accessibilityIdentifier];
}

%end
