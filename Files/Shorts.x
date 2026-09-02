#import "Headers.h"

// دالة ذكية تلقائية بالكامل تبحث وتتعامل مع العناصر دون الحاجة لقوائم أو دوال مسبقة
static void HPlusProcessShortsElementAutomatically(_ASDisplayView *self, NSString *iden) {
    if (!iden || iden.length == 0) return;

    // 1. التعامل التلقائي مع النصوص والعناوين والوصف
    if ([iden containsString:@"description"] || 
        [iden containsString:@"title"] || 
        [iden containsString:@"reel.player"] || 
        [iden containsString:@"YTReelTitle"]) {
        if (IS_ENABLED(RemoveShortsTitleButton)) {
            self.hidden = YES;
            self.userInteractionEnabled = NO;
            self.alpha = 0.0;
        }
        return;
    }

    // 2. التعامل التلقائي مع أزرار التفاعل (لايك، تعليق، مشاركة، حفظ، ريمكس، صوت...)
    if ([iden containsString:@"reel_like"] || 
        [iden containsString:@"reel_comment"] || 
        [iden containsString:@"reel_share"] || 
        [iden containsString:@"reel_save"] || 
        [iden containsString:@"reel_remix"] || 
        [iden containsString:@"reel_pivot"]) {
        
        // فحص ذكي لتحديد الزر المرتبط بناءً على محتوى المعرف
        BOOL shouldRemove = NO;
        if ([iden containsString:@"like"] && IS_ENABLED(RemoveShortsLikeButton)) shouldRemove = YES;
        else if ([iden containsString:@"comment"] && IS_ENABLED(RemoveShortsCommentButton)) shouldRemove = YES;
        else if ([iden containsString:@"share"] && IS_ENABLED(RemoveShortsShareButton)) shouldRemove = YES;
        else if ([iden containsString:@"save"] && IS_ENABLED(RemoveShortsSaveButton)) shouldRemove = YES;
        else if ([iden containsString:@"remix"] && IS_ENABLED(RemoveShortsRemixButton)) shouldRemove = YES;
        else if ([iden containsString:@"pivot"] && IS_ENABLED(RemoveShortsSoundMetadataButton)) shouldRemove = YES;

        if (shouldRemove) {
            id mainView = self.superview;
            ASDisplayNode *node = [(_ASDisplayView *)mainView keepalive_node];
            if (node) {
                for (_ASDisplayView *view in node.yogaChildren) {
                    if ([[view description] containsString:iden]) {
                        [node removeYogaChild:view];
                        [self removeFromSuperview];
                        break;
                    }
                }
            }
        }
        return;
    }

    // 3. التعامل التلقائي مع القائمة المؤقتة للشورتز (Paused State)
    if ([iden containsString:@"shorts_paused_state"]) {
        BOOL shouldRemove = NO;
        if ([iden containsString:@"subscriptions"] && IS_ENABLED(RemoveShortsPausedSubButton)) shouldRemove = YES;
        else if ([iden containsString:@"live"] && IS_ENABLED(RemoveShortsPausedLiveButton)) shouldRemove = YES;
        else if ([iden containsString:@"lens"] && IS_ENABLED(RemoveShortsPausedLensButton)) shouldRemove = YES;
        else if ([iden containsString:@"trends"] && IS_ENABLED(RemoveShortsPausedTrendsButton)) shouldRemove = YES;

        if (shouldRemove) {
            ASScrollView *scrollView = (ASScrollView *)self.superview;
            ASDisplayNode *node = scrollView.scrollNode;
            if (node) {
                for (_ASDisplayView *view in node.yogaChildren) {
                    if ([[view description] containsString:iden]) {
                        [node removeYogaChild:view];
                        [self removeFromSuperview];
                        break;
                    }
                }
            }
        }
        return;
    }

    // 4. التعامل التلقائي مع المنتجات والإعلانات والرعاة
    if ([iden containsString:@"product_sticker"] && IS_ENABLED(HideShortsProducts)) {
        [self removeFromSuperview];
        return;
    }
    if ([iden containsString:@"suggested_action"] && IS_ENABLED(HideShortsRecbar)) {
        [self removeFromSuperview];
        return;
    }
    if ([iden containsString:@"reel_sponsor_button"] && IS_ENABLED(RemoveChannelSponsorAll)) {
        [self.superview removeFromSuperview];
        return;
    }

    // 5. الإفصاحات (Disclosures)
    if ([iden containsString:@"shorts-disclosures"] && IS_ENABLED(RemoveShortsDisclosure)) {
        _ASDisplayView *dpView = (_ASDisplayView *)self.superview;
        ASDisplayNode *node = dpView.keepalive_node;
        _ASDisplayView *maindpView = (_ASDisplayView *)dpView.superview;
        ASDisplayNode *mainNode = maindpView.keepalive_node;
        [mainNode removeYogaChild:node];
        [maindpView removeFromSuperview];
        return;
    }
}

// نقطة الحقن العامة لالتقاط العناصر تلقائياً مع تحديثات يوتيوب
%hook _ASDisplayView
- (void)didMoveToWindow {
    %orig;
    HPlusProcessShortsElementAutomatically(self, self.accessibilityIdentifier);
}
%end
