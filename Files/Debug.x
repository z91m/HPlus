#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <QuartzCore/QuartzCore.h>
#import "Headers.h"
static char HPlusGestureKey;
#ifndef HPlusInspector
#define HPlusInspector @"HPlusInspector"
#endif
@interface HPlusDebugHelper : NSObject
+ (instancetype)sharedInstance;
- (void)setupGestureForWindow:(UIWindow *)window;
- (void)removeInspectorGestures;
- (void)refreshInspector;
- (void)handleLongPress:(UILongPressGestureRecognizer *)sender;
- (BOOL)isInspectorEnabled;
- (BOOL)shouldIgnoreView:(UIView *)view;
- (BOOL)isInteractiveView:(UIView *)view;
- (UIWindow *)activeWindow;
- (UIViewController *)topViewController;
- (NSString *)safeString:(id)value;
- (NSString *)classNameForObject:(id)object;
- (NSString *)getViewID:(UIView *)view;
- (NSString *)getViewLabel:(UIView *)view;
- (NSString *)getViewText:(UIView *)view;
- (NSString *)getTraitsString:(UIView *)view;
- (NSString *)getFrameInfoForView:(UIView *)view;
- (NSString *)getViewControllerInfo:(UIView *)view;
- (NSString *)getWindowInfo:(UIView *)view;
- (NSString *)getLayerInfo:(UIView *)view;
- (NSString *)getSuperviewChain:(UIView *)view;
- (NSString *)getSubviewsInfo:(UIView *)view;
- (NSString *)getSiblingInfo:(UIView *)view;
- (NSString *)getRuntimeInfoForObject:(id)object;
- (NSString *)getSuperclassChainForClass:(Class)cls;
- (NSString *)getProtocolsForClass:(Class)cls;
- (NSString *)getPropertiesForClass:(Class)cls;
- (NSString *)getIvarsForClass:(Class)cls;
- (NSString *)getMethodsForClass:(Class)cls;
- (NSString *)getGestureInfo:(UIView *)view;
- (NSString *)getControlInfo:(UIView *)view;
- (NSString *)getYouTubeInfoForObject:(id)object;
- (NSString *)buildViewTreeFromView:(UIView *)view;
- (NSString *)buildRecursiveSubtree:(UIView *)view
                              depth:(NSInteger)depth
                           maxDepth:(NSInteger)maxDepth;
- (NSString *)getDeepAccessibilityInfo:(UIView *)view;
- (NSString *)getAccessibilityPath:(UIView *)view;
/*
 * ID RESOLUTION
 */
- (BOOL)viewHasUsefulAccessibilityData:(UIView *)view;
- (BOOL)viewHasDirectID:(UIView *)view;
- (UIView *)findViewWithIDInSubtree:(UIView *)view
                         maxDepth:(NSInteger)maxDepth;
- (UIView *)resolveExactTargetFromHitView:(UIView *)hitView
                                   window:(UIWindow *)window;
- (void)collectViewsWithIDs:(UIView *)view
                     result:(NSMutableArray *)result
                   maxDepth:(NSInteger)maxDepth;
- (NSString *)buildFullReportForView:(UIView *)view
                           hitTarget:(UIView *)hitTarget
                     resolvedTarget:(UIView *)resolvedTarget;
@end
#pragma mark - UIWindow Hooks
%hook UIWindow
- (void)makeKeyAndVisible {
    %orig;
    dispatch_async(dispatch_get_main_queue(), ^{
        [[HPlusDebugHelper sharedInstance]
            setupGestureForWindow:self];
    });
}
- (void)becomeKeyWindow {
    %orig;
    dispatch_after(
        dispatch_time(DISPATCH_TIME_NOW,
                      (int64_t)(0.05 * NSEC_PER_SEC)),
        dispatch_get_main_queue(),
        ^{
            [[HPlusDebugHelper sharedInstance]
                setupGestureForWindow:self];
        }
    );
}
%end
@implementation HPlusDebugHelper
#pragma mark - Singleton
+ (instancetype)sharedInstance {
    static HPlusDebugHelper *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[HPlusDebugHelper alloc] init];
    });
    return sharedInstance;
}
#pragma mark - Settings
- (BOOL)isInspectorEnabled {
    return [[NSUserDefaults standardUserDefaults]
        boolForKey:HPlusInspector];
}
- (void)refreshInspector {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (![self isInspectorEnabled]) {
            [self removeInspectorGestures];
            return;
        }
        if (@available(iOS 13.0, *)) {
            for (UIScene *scene
                 in UIApplication.sharedApplication.connectedScenes) {
                if (![scene isKindOfClass:[UIWindowScene class]]) {
                    continue;
                }
                UIWindowScene *windowScene =
                    (UIWindowScene *)scene;
                if (windowScene.activationState ==
                    UISceneActivationStateUnattached) {
                    continue;
                }
                for (UIWindow *window
                     in windowScene.windows) {
                    [self setupGestureForWindow:window];
                }
            }
        } else {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
            for (UIWindow *window
                 in UIApplication.sharedApplication.windows) {
                [self setupGestureForWindow:window];
            }
#pragma clang diagnostic pop
        }
    });
}
#pragma mark - Remove Gestures
- (void)removeInspectorGestures {
    if (@available(iOS 13.0, *)) {
        for (UIScene *scene
             in UIApplication.sharedApplication.connectedScenes) {
            if (![scene isKindOfClass:[UIWindowScene class]]) {
                continue;
            }
            UIWindowScene *windowScene =
                (UIWindowScene *)scene;
            for (UIWindow *window
                 in windowScene.windows) {
                UILongPressGestureRecognizer *gesture =
                    objc_getAssociatedObject(
                        window,
                        &HPlusGestureKey
                    );
                if (gesture) {
                    [window removeGestureRecognizer:gesture];
                    objc_setAssociatedObject(
                        window,
                        &HPlusGestureKey,
                        nil,
                        OBJC_ASSOCIATION_RETAIN_NONATOMIC
                    );
                }
            }
        }
    } else {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        for (UIWindow *window
             in UIApplication.sharedApplication.windows) {
            UILongPressGestureRecognizer *gesture =
                objc_getAssociatedObject(
                    window,
                    &HPlusGestureKey
                );
            if (gesture) {
                [window removeGestureRecognizer:gesture];
                objc_setAssociatedObject(
                    window,
                    &HPlusGestureKey,
                    nil,
                    OBJC_ASSOCIATION_RETAIN_NONATOMIC
                );
            }
        }
#pragma clang diagnostic pop
    }
}
#pragma mark - Ignore Views
- (BOOL)shouldIgnoreView:(UIView *)view {
    if (!view) {
        return YES;
    }
    NSString *className =
        NSStringFromClass(view.class);
    NSArray *ignoredClasses = @[
        @"_UIAlertControllerView",
        @"UIAlertController",
        @"_UIKeyboardLayout",
        @"_UIRemoteKeyboardPlaceholderView",
        @"UIKeyboard",
        @"UIRemoteKeyboard",
        @"UITextEffectsWindow"
    ];
    for (NSString *ignoredClass
         in ignoredClasses) {
        if ([className containsString:ignoredClass]) {
            return YES;
        }
    }
    return NO;
}
#pragma mark - Active Window
- (UIWindow *)activeWindow {
    if (@available(iOS 13.0, *)) {
        UIWindow *fallback = nil;
        for (UIScene *scene
             in UIApplication.sharedApplication.connectedScenes) {
            if (![scene isKindOfClass:[UIWindowScene class]]) {
                continue;
            }
            UIWindowScene *windowScene =
                (UIWindowScene *)scene;
            if (windowScene.activationState !=
                UISceneActivationStateForegroundActive) {
                continue;
            }
            for (UIWindow *window
                 in windowScene.windows) {
                if (window.isKeyWindow &&
                    !window.hidden &&
                    window.alpha > 0.01 &&
                    window.rootViewController) {
                    return window;
                }
                if (!fallback &&
                    !window.hidden &&
                    window.alpha > 0.01 &&
                    window.rootViewController) {
                    fallback = window;
                }
            }
        }
        if (fallback) {
            return fallback;
        }
    }
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    for (UIWindow *window
         in UIApplication.sharedApplication.windows) {
        if (window.isKeyWindow &&
            !window.hidden &&
            window.alpha > 0.01 &&
            window.rootViewController) {
            return window;
        }
    }
    for (UIWindow *window
         in UIApplication.sharedApplication.windows) {
        if (!window.hidden &&
            window.alpha > 0.01 &&
            window.rootViewController) {
            return window;
        }
    }
#pragma clang diagnostic pop
    return nil;
}
#pragma mark - Top View Controller
- (UIViewController *)topViewController {
    UIWindow *window =
        [self activeWindow];
    if (!window) {
        return nil;
    }
    UIViewController *vc =
        window.rootViewController;
    if (!vc) {
        return nil;
    }
    BOOL changed = YES;
    while (changed) {
        changed = NO;
        if (vc.presentedViewController &&
            !vc.presentedViewController.isBeingDismissed) {
            vc = vc.presentedViewController;
            changed = YES;
            continue;
        }
        if ([vc isKindOfClass:
            [UINavigationController class]]) {
            UIViewController *visible =
                [(UINavigationController *)vc
                    visibleViewController];
            if (visible && visible != vc) {
                vc = visible;
                changed = YES;
                continue;
            }
        }
        if ([vc isKindOfClass:
            [UITabBarController class]]) {
            UIViewController *selected =
                [(UITabBarController *)vc
                    selectedViewController];
            if (selected && selected != vc) {
                vc = selected;
                changed = YES;
                continue;
            }
        }
        if ([vc isKindOfClass:
            [UISplitViewController class]]) {
            UIViewController *last =
                ((UISplitViewController *)vc)
                    .viewControllers.lastObject;
            if (last && last != vc) {
                vc = last;
                changed = YES;
            }
        }
    }
    return vc;
}
#pragma mark - Setup Gesture
- (void)setupGestureForWindow:(UIWindow *)window {
    if (![self isInspectorEnabled] ||
        !window) {
        return;
    }
    if ([self shouldIgnoreView:window]) {
        return;
    }
    NSString *className =
        NSStringFromClass(window.class);
    if ([className containsString:@"Keyboard"] ||
        [className containsString:@"Alert"]) {
        return;
    }
    if (objc_getAssociatedObject(
            window,
            &HPlusGestureKey)) {
        return;
    }
    UILongPressGestureRecognizer *gesture =
        [[UILongPressGestureRecognizer alloc]
            initWithTarget:self
            action:@selector(handleLongPress:)];
    gesture.minimumPressDuration = 0.4;
    gesture.cancelsTouchesInView = NO;
    gesture.delaysTouchesBegan = NO;
    gesture.delaysTouchesEnded = NO;
    [window addGestureRecognizer:gesture];
    objc_setAssociatedObject(
        window,
        &HPlusGestureKey,
        gesture,
        OBJC_ASSOCIATION_RETAIN_NONATOMIC
    );
}
#pragma mark - Basic Helpers
- (NSString *)safeString:(id)value {
    if (!value || value == [NSNull null]) {
        return @"(None)";
    }
    @try {
        NSString *string =
            [value description];
        if (!string.length) {
            return @"(None)";
        }
        return string;
    } @catch (...) {
        return @"(Unavailable)";
    }
}
- (NSString *)classNameForObject:(id)object {
    if (!object) {
        return @"(None)";
    }
    Class cls =
        object_getClass(object);
    return cls
        ? NSStringFromClass(cls)
        : @"(Unknown)";
}
#pragma mark - Accessibility
- (NSString *)getViewID:(UIView *)view {
    if (!view) {
        return nil;
    }
    NSString *identifier =
        view.accessibilityIdentifier;
    return identifier.length
        ? identifier
        : nil;
}
- (NSString *)getViewLabel:(UIView *)view {
    if (!view) {
        return nil;
    }
    NSString *label =
        view.accessibilityLabel;
    return label.length
        ? label
        : nil;
}
- (NSString *)getViewText:(UIView *)view {
    if (!view) {
        return nil;
    }
    if ([view isKindOfClass:[UILabel class]]) {
        UILabel *label = (UILabel *)view;
        if (label.text.length) {
            return label.text;
        }
    }
    if ([view isKindOfClass:[UIButton class]]) {
        UIButton *button = (UIButton *)view;
        NSString *title =
            [button currentTitle];
        if (title.length) {
            return title;
        }
        NSAttributedString *attributed =
            [button currentAttributedTitle];
        if (attributed.string.length) {
            return attributed.string;
        }
        if (button.titleLabel.text.length) {
            return button.titleLabel.text;
        }
    }
    if ([view isKindOfClass:[UITextField class]]) {
        UITextField *field = (UITextField *)view;
        if (field.text.length) {
            return field.text;
        }
        if (field.placeholder.length) {
            return field.placeholder;
        }
    }
    if ([view isKindOfClass:[UITextView class]]) {
        UITextView *textView = (UITextView *)view;
        if (textView.text.length) {
            return textView.text;
        }
    }
    return nil;
}
#pragma mark - Traits
- (NSString *)getTraitsString:(UIView *)view {
    if (!view) {
        return nil;
    }
    UIAccessibilityTraits traits =
        view.accessibilityTraits;
    if (traits == 0) {
        return nil;
    }
    NSMutableArray *items =
        [NSMutableArray array];
    if (traits & UIAccessibilityTraitButton)
        [items addObject:@"Button"];
    if (traits & UIAccessibilityTraitLink)
        [items addObject:@"Link"];
    if (traits & UIAccessibilityTraitSelected)
        [items addObject:@"Selected"];
    if (traits & UIAccessibilityTraitAdjustable)
        [items addObject:@"Adjustable"];
    if (traits & UIAccessibilityTraitHeader)
        [items addObject:@"Header"];
    if (traits & UIAccessibilityTraitImage)
        [items addObject:@"Image"];
    if (traits & UIAccessibilityTraitSearchField)
        [items addObject:@"SearchField"];
    if (traits & UIAccessibilityTraitKeyboardKey)
        [items addObject:@"KeyboardKey"];
    if (items.count) {
        return [items componentsJoinedByString:@", "];
    }
    return [NSString stringWithFormat:
        @"0x%llx",
        (unsigned long long)traits];
}
#pragma mark - Interactive
- (BOOL)isInteractiveView:(UIView *)view {
    if (!view ||
        !view.userInteractionEnabled) {
        return NO;
    }
    if ([view isKindOfClass:[UIControl class]]) {
        UIControl *control =
            (UIControl *)view;
        if (control.enabled) {
            return YES;
        }
    }
    if (view.gestureRecognizers.count) {
        return YES;
    }
    if (view.isAccessibilityElement) {
        return YES;
    }
    return NO;
}
#pragma mark - Exact ID Resolver
/*
 * هل الـ View يحمل ID مباشرة؟
 */
- (BOOL)viewHasDirectID:(UIView *)view {
    if (!view) {
        return NO;
    }
    NSString *identifier =
        view.accessibilityIdentifier;
    return identifier.length > 0;
}
/*
 * أي بيانات Accessibility مفيدة.
 */
- (BOOL)viewHasUsefulAccessibilityData:(UIView *)view {
    if (!view) {
        return NO;
    }
    if ([self viewHasDirectID:view]) {
        return YES;
    }
    if (view.accessibilityLabel.length)
        return YES;
    if (view.accessibilityValue.length)
        return YES;
    if (view.accessibilityHint.length)
        return YES;
    if (view.accessibilityTraits != 0)
        return YES;
    if (view.isAccessibilityElement)
        return YES;
    return NO;
}
/*
 * يجمع جميع الـ Views التي تحمل ID.
 */
- (void)collectViewsWithIDs:(UIView *)view
                     result:(NSMutableArray *)result
                   maxDepth:(NSInteger)maxDepth {
    if (!view ||
        !result ||
        maxDepth < 0) {
        return;
    }
    if ([self viewHasDirectID:view]) {
        if (![result containsObject:view]) {
            [result addObject:view];
        }
    }
    if (maxDepth == 0) {
        return;
    }
    /*
     * accessibilityElements قد تحتوي على عناصر ليست
     * مباشرة في subviews.
     */
    NSArray *accessibilityElements =
        view.accessibilityElements;
    if ([accessibilityElements isKindOfClass:[NSArray class]]) {
        for (id element in accessibilityElements) {
            if ([element isKindOfClass:[UIView class]]) {
                UIView *elementView =
                    (UIView *)element;
                if ([self viewHasDirectID:elementView] &&
                    ![result containsObject:elementView]) {
                    [result addObject:elementView];
                }
            }
        }
    }
    for (UIView *subview in view.subviews) {
        [self collectViewsWithIDs:subview
                           result:result
                         maxDepth:maxDepth - 1];
    }
}
/*
 * يبحث عن أول View يحمل ID داخل subtree.
 */
- (UIView *)findViewWithIDInSubtree:(UIView *)view
                          maxDepth:(NSInteger)maxDepth {
    if (!view ||
        maxDepth < 0) {
        return nil;
    }
    /*
     * الأولوية للـ View نفسه.
     */
    if ([self viewHasDirectID:view]) {
        return view;
    }
    /*
     * ثم accessibilityElements.
     */
    NSArray *elements =
        view.accessibilityElements;
    if ([elements isKindOfClass:[NSArray class]]) {
        for (id element in elements) {
            if (![element isKindOfClass:[UIView class]]) {
                continue;
            }
            UIView *candidate =
                (UIView *)element;
            if ([self viewHasDirectID:candidate]) {
                return candidate;
            }
        }
    }
    if (maxDepth == 0) {
        return nil;
    }
    /*
     * نبحث من آخر subview إلى الأول لأن
     * UIKit يرسم/يختبر الأعلى عادةً في الأعلى.
     */
    for (UIView *subview
         in [view.subviews reverseObjectEnumerator]) {
        UIView *found =
            [self findViewWithIDInSubtree:subview
                                 maxDepth:maxDepth - 1];
        if (found) {
            return found;
        }
    }
    return nil;
}
/*
 * أهم دالة في الفاحص.
 *
 * الهدف:
 * 1. نبدأ بالـ hitTest الحقيقي.
 * 2. نبحث داخل الـ hit subtree عن ID.
 * 3. نبحث في accessibilityElements.
 * 4. إذا لم نجد ID، نصعد للأعلى.
 * 5. أخيراً نرجع hitView.
 */
- (UIView *)resolveExactTargetFromHitView:(UIView *)hitView
                                   window:(UIWindow *)window {
    if (!hitView) {
        return nil;
    }
    /*
     * STEP 1
     * الـ hit نفسه يحمل ID.
     */
    if ([self viewHasDirectID:hitView]) {
        return hitView;
    }
    /*
     * STEP 2
     * ابحث داخل descendants.
     *
     * هذا هو الجزء المهم لحالات مثل:
     *
     * _ASDisplayView
     *   └── YTELMView
     *       └── YTSpacerButton
     *
     * حيث قد يكون الـ ID على descendant.
     */
    UIView *inside =
        [self findViewWithIDInSubtree:hitView
                             maxDepth:20];
    if (inside) {
        return inside;
    }
    /*
     * STEP 3
     * ابحث في accessibilityElements الخاصة
     * بالـ hit view وأبنائه.
     */
    NSMutableArray *idViews =
        [NSMutableArray array];
    [self collectViewsWithIDs:hitView
                       result:idViews
                     maxDepth:20];
    if (idViews.count) {
        /*
         * اختر أقرب عنصر للـ hitView
         * بناءً على المسافة في شجرة الـ superview.
         */
        UIView *best = nil;
        NSInteger bestDistance = NSIntegerMax;
        for (UIView *candidate in idViews) {
            NSInteger distance = 0;
            UIView *current = candidate;
            while (current &&
                   current != hitView &&
                   distance < 100) {
                current = current.superview;
                distance++;
            }
            if (current == hitView &&
                distance < bestDistance) {
                best = candidate;
                bestDistance = distance;
            }
        }
        if (best) {
            return best;
        }
        return idViews.firstObject;
    }
    /*
     * STEP 4
     * إذا لم يوجد ID داخل subtree،
     * نصعد في superview chain.
     */
    UIView *current =
        hitView.superview;
    NSInteger parentDepth = 0;
    while (current &&
           parentDepth < 30) {
        if ([self viewHasDirectID:current]) {
            return current;
        }
        /*
         * أحياناً الـ parent نفسه ليس ID element
         * لكن لديه accessibilityElements تحتوي على ID.
         */
        UIView *nested =
            [self findViewWithIDInSubtree:current
                                 maxDepth:5];
        if (nested) {
            return nested;
        }
        current = current.superview;
        parentDepth++;
    }
    /*
     * STEP 5
     * window fallback.
     */
    if (window) {
        UIView *windowTarget =
            [self findViewWithIDInSubtree:window
                                 maxDepth:12];
        if (windowTarget) {
            return windowTarget;
        }
    }
    /*
     * لا يوجد ID.
     */
    return hitView;
}
#pragma mark - Geometry
- (NSString *)getFrameInfoForView:(UIView *)view {
    if (!view) {
        return @"(Unavailable)";
    }
    CGRect frame =
        view.frame;
    CGRect bounds =
        view.bounds;
    CGRect screenFrame =
        [view convertRect:view.bounds
                  toView:nil];
    return [NSString stringWithFormat:
        @"Local Frame: (%.1f, %.1f, %.1f, %.1f)\n"
         "Screen Frame: (%.1f, %.1f, %.1f, %.1f)\n"
         "Bounds: (%.1f, %.1f, %.1f, %.1f)\n"
         "Center: (%.1f, %.1f)\n"
         "Transform: %@",
        frame.origin.x,
        frame.origin.y,
        frame.size.width,
        frame.size.height,
        screenFrame.origin.x,
        screenFrame.origin.y,
        screenFrame.size.width,
        screenFrame.size.height,
        bounds.origin.x,
        bounds.origin.y,
        bounds.size.width,
        bounds.size.height,
        view.center.x,
        view.center.y,
        NSStringFromCGAffineTransform(view.transform)];
}
#pragma mark - Layer
- (NSString *)getLayerInfo:(UIView *)view {
    if (!view) {
        return @"(Unavailable)";
    }
    CALayer *layer =
        view.layer;
    return [NSString stringWithFormat:
        @"Layer Class: %@\n"
         "Z Position: %.2f\n"
         "Opacity: %.2f\n"
         "Hidden: %@\n"
         "Corner Radius: %.2f\n"
         "Border Width: %.2f\n"
         "Masks To Bounds: %@\n"
         "Sublayer Count: %lu",
        NSStringFromClass(layer.class),
        layer.zPosition,
        layer.opacity,
        layer.hidden ? @"YES" : @"NO",
        layer.cornerRadius,
        layer.borderWidth,
        layer.masksToBounds ? @"YES" : @"NO",
        (unsigned long)layer.sublayers.count];
}
#pragma mark - Window Info
- (NSString *)getWindowInfo:(UIView *)view {
    UIWindow *window =
        view.window;
    if (!window) {
        return @"Window: (None)";
    }
    NSString *sceneState =
        @"N/A";
    if (@available(iOS 13.0, *)) {
        switch (window.windowScene.activationState) {
            case UISceneActivationStateUnattached:
                sceneState = @"Unattached";
                break;
            case UISceneActivationStateForegroundInactive:
                sceneState = @"ForegroundInactive";
                break;
            case UISceneActivationStateForegroundActive:
                sceneState = @"ForegroundActive";
                break;
            case UISceneActivationStateBackground:
                sceneState = @"Background";
                break;
            default:
                sceneState = @"Unknown";
                break;
        }
    }
    return [NSString stringWithFormat:
        @"Window Class: %@\n"
         "Window Level: %.1f\n"
         "Key Window: %@\n"
         "Hidden: %@\n"
         "Alpha: %.2f\n"
         "Scene State: %@",
        NSStringFromClass(window.class),
        window.windowLevel,
        window.isKeyWindow ? @"YES" : @"NO",
        window.hidden ? @"YES" : @"NO",
        window.alpha,
        sceneState];
}
#pragma mark - View Controller
- (NSString *)getViewControllerInfo:(UIView *)view {
    UIViewController *vc = nil;
    UIResponder *responder =
        view;
    while (responder) {
        responder =
            [responder nextResponder];
        if ([responder isKindOfClass:
             [UIViewController class]]) {
            vc = (UIViewController *)responder;
            break;
        }
    }
    if (!vc) {
        return @"View Controller: (None)";
    }
    return [NSString stringWithFormat:
        @"View Controller: %@\n"
         "Title: %@\n"
         "Presented: %@\n"
         "Being Presented: %@\n"
         "Being Dismissed: %@",
        NSStringFromClass(vc.class),
        vc.title.length
            ? vc.title
            : @"(None)",
        vc.presentedViewController
            ? NSStringFromClass(
                vc.presentedViewController.class)
            : @"(None)",
        vc.isBeingPresented
            ? @"YES"
            : @"NO",
        vc.isBeingDismissed
            ? @"YES"
            : @"NO"];
}
#pragma mark - Superview Chain
- (NSString *)getSuperviewChain:(UIView *)view {
    NSMutableString *result =
        [NSMutableString string];
    UIView *current =
        view;
    NSInteger depth = 0;
    while (current && depth < 50) {
        NSString *identifier =
            [self getViewID:current];
        NSString *label =
            [self getViewLabel:current];
        [result appendFormat:
            @"[%02ld] %@\n"
             "    ID: %@\n"
             "    Label: %@\n"
             "    Frame: %@\n\n",
            (long)depth,
            NSStringFromClass(current.class),
            identifier.length
                ? identifier
                : @"(None)",
            label.length
                ? label
                : @"(None)",
            NSStringFromCGRect(current.frame)];
        current =
            current.superview;
        depth++;
    }
    return result.length
        ? result
        : @"(None)";
}
#pragma mark - Direct Subviews
- (NSString *)getSubviewsInfo:(UIView *)view {
    if (!view ||
        !view.subviews.count) {
        return @"(None)";
    }
    NSMutableString *result =
        [NSMutableString string];
    NSUInteger index = 0;
    for (UIView *subview in view.subviews) {
        NSString *identifier =
            [self getViewID:subview];
        NSString *label =
            [self getViewLabel:subview];
        NSString *text =
            [self getViewText:subview];
        CGRect frame =
            [subview convertRect:subview.bounds
                          toView:nil];
        [result appendFormat:
            @"[%lu] %@\n"
             "    ID: %@\n"
             "    Label: %@\n"
             "    Text: %@\n"
             "    Traits: %@\n"
             "    Interactive: %@\n"
             "    Frame: %@\n\n",
            (unsigned long)index,
            NSStringFromClass(subview.class),
            identifier.length
                ? identifier
                : @"(None)",
            label.length
                ? label
                : @"(None)",
            text.length
                ? text
                : @"(None)",
            [self getTraitsString:subview] ?: @"(None)",
            [self isInteractiveView:subview]
                ? @"YES"
                : @"NO",
            NSStringFromCGRect(frame)];
        index++;
    }
    return result;
}
#pragma mark - Siblings
- (NSString *)getSiblingInfo:(UIView *)view {
    UIView *parent =
        view.superview;
    if (!parent) {
        return @"(No siblings)";
    }
    NSMutableString *result =
        [NSMutableString string];
    NSArray *siblings =
        parent.subviews;
    for (NSUInteger i = 0;
         i < siblings.count;
         i++) {
        UIView *sibling =
            siblings[i];
        CGRect frame =
            [sibling convertRect:sibling.bounds
                          toView:nil];
        [result appendFormat:
            @"[%lu] %@%@\n"
             "    ID: %@\n"
             "    Label: %@\n"
             "    Text: %@\n"
             "    Traits: %@\n"
             "    Interactive: %@\n"
             "    Frame: (%.0f, %.0f, %.0f, %.0f)\n\n",
            (unsigned long)i,
            sibling == view ? @"🎯 " : @"",
            NSStringFromClass(sibling.class),
            [self getViewID:sibling] ?: @"(None)",
            [self getViewLabel:sibling] ?: @"(None)",
            [self getViewText:sibling] ?: @"(None)",
            [self getTraitsString:sibling] ?: @"(None)",
            [self isInteractiveView:sibling]
                ? @"YES"
                : @"NO",
            frame.origin.x,
            frame.origin.y,
            frame.size.width,
            frame.size.height];
    }
    return result.length
        ? result
        : @"(No siblings)";
}
#pragma mark - Runtime
- (NSString *)getSuperclassChainForClass:(Class)cls {
    if (!cls) {
        return @"(None)";
    }
    NSMutableString *result =
        [NSMutableString string];
    Class current = cls;
    NSInteger depth = 0;
    while (current && depth < 50) {
        [result appendFormat:
            @"[%02ld] %@\n",
            (long)depth,
            NSStringFromClass(current)];
        current =
            class_getSuperclass(current);
        depth++;
    }
    return result;
}
- (NSString *)getProtocolsForClass:(Class)cls {
    if (!cls) {
        return @"(None)";
    }
    NSMutableString *result =
        [NSMutableString string];
    unsigned int count = 0;
    Protocol *__unsafe_unretained *protocols =
        class_copyProtocolList(cls, &count);
    for (unsigned int i = 0;
         i < count;
         i++) {
        if (protocols[i]) {
            [result appendFormat:
                @"• %@\n",
                NSStringFromProtocol(protocols[i])];
        }
    }
    if (protocols) {
        free(protocols);
    }
    return result.length
        ? result
        : @"(None)";
}
- (NSString *)getPropertiesForClass:(Class)cls {
    if (!cls) {
        return @"(None)";
    }
    NSMutableString *result =
        [NSMutableString string];
    unsigned int count = 0;
    objc_property_t *properties =
        class_copyPropertyList(cls, &count);
    for (unsigned int i = 0;
         i < count;
         i++) {
        const char *name =
            property_getName(properties[i]);
        const char *attributes =
            property_getAttributes(properties[i]);
        if (name) {
            [result appendFormat:
                @"• %s | %s\n",
                name,
                attributes ?: "(Unknown)"];
        }
    }
    if (properties) {
        free(properties);
    }
    return result.length
        ? result
        : @"(None)";
}
- (NSString *)getIvarsForClass:(Class)cls {
    if (!cls) {
        return @"(None)";
    }
    NSMutableString *result =
        [NSMutableString string];
    unsigned int count = 0;
    Ivar *ivars =
        class_copyIvarList(cls, &count);
    for (unsigned int i = 0;
         i < count;
         i++) {
        const char *name =
            ivar_getName(ivars[i]);
        const char *type =
            ivar_getTypeEncoding(ivars[i]);
        ptrdiff_t offset =
            ivar_getOffset(ivars[i]);
        if (name) {
            [result appendFormat:
                @"• %s | Type: %s | Offset: %td\n",
                name,
                type ?: "(Unknown)",
                offset];
        }
    }
    if (ivars) {
        free(ivars);
    }
    return result.length
        ? result
        : @"(None)";
}
- (NSString *)getMethodsForClass:(Class)cls {
    if (!cls) {
        return @"(None)";
    }
    NSMutableString *result =
        [NSMutableString string];
    unsigned int count = 0;
    Method *methods =
        class_copyMethodList(cls, &count);
    for (unsigned int i = 0;
         i < count;
         i++) {
        SEL selector =
            method_getName(methods[i]);
        const char *types =
            method_getTypeEncoding(methods[i]);
        if (selector) {
            [result appendFormat:
                @"• -[%@ %@] | %s\n",
                NSStringFromClass(cls),
                NSStringFromSelector(selector),
                types ?: "(Unknown)"];
        }
    }
    if (methods) {
        free(methods);
    }
    return result.length
        ? result
        : @"(None)";
}
- (NSString *)getRuntimeInfoForObject:(id)object {
    if (!object) {
        return @"(None)";
    }
    Class cls =
        object_getClass(object);
    NSMutableString *result =
        [NSMutableString string];
    [result appendFormat:
        @"Runtime Class: %@\n\n",
        NSStringFromClass(cls)];
    [result appendString:@"SUPERCLASS CHAIN\n"];
    [result appendString:
        [self getSuperclassChainForClass:cls]];
    [result appendString:@"\nPROTOCOLS\n"];
    [result appendString:
        [self getProtocolsForClass:cls]];
    [result appendString:@"\nPROPERTIES\n"];
    [result appendString:
        [self getPropertiesForClass:cls]];
    [result appendString:@"\nIVARS\n"];
    [result appendString:
        [self getIvarsForClass:cls]];
    [result appendString:@"\nMETHODS\n"];
    [result appendString:
        [self getMethodsForClass:cls]];
    return result;
}
#pragma mark - Gestures
- (NSString *)getGestureInfo:(UIView *)view {
    if (!view ||
        !view.gestureRecognizers.count) {
        return @"(None)";
    }
    NSMutableString *result =
        [NSMutableString string];
    NSUInteger index = 0;
    for (UIGestureRecognizer *gesture
         in view.gestureRecognizers) {
        NSString *state = @"Unknown";
        switch (gesture.state) {
            case UIGestureRecognizerStatePossible:
                state = @"Possible";
                break;
            case UIGestureRecognizerStateBegan:
                state = @"Began";
                break;
            case UIGestureRecognizerStateChanged:
                state = @"Changed";
                break;
            case UIGestureRecognizerStateEnded:
                state = @"Ended";
                break;
            case UIGestureRecognizerStateCancelled:
                state = @"Cancelled";
                break;
            case UIGestureRecognizerStateFailed:
                state = @"Failed";
                break;
            default:
                break;
        }
        [result appendFormat:
            @"[%lu] %@\n"
             "    State: %@\n"
             "    Enabled: %@\n"
             "    Cancels Touches: %@\n"
             "    Delays Began: %@\n"
             "    Delays Ended: %@\n\n",
            (unsigned long)index,
            NSStringFromClass(gesture.class),
            state,
            gesture.enabled ? @"YES" : @"NO",
            gesture.cancelsTouchesInView
                ? @"YES"
                : @"NO",
            gesture.delaysTouchesBegan
                ? @"YES"
                : @"NO",
            gesture.delaysTouchesEnded
                ? @"YES"
                : @"NO"];
        index++;
    }
    return result;
}
#pragma mark - Control
- (NSString *)getControlInfo:(UIView *)view {
    if (![view isKindOfClass:[UIControl class]]) {
        return @"Not a UIControl";
    }
    UIControl *control =
        (UIControl *)view;
    return [NSString stringWithFormat:
        @"Control Class: %@\n"
         "Enabled: %@\n"
         "Selected: %@\n"
         "Highlighted: %@\n"
         "Focused: %@\n"
         "State: %lu\n"
         "Events: 0x%lx",
        NSStringFromClass(control.class),
        control.enabled ? @"YES" : @"NO",
        control.selected ? @"YES" : @"NO",
        control.highlighted ? @"YES" : @"NO",
        control.isFocused ? @"YES" : @"NO",
        (unsigned long)control.state,
        (unsigned long)control.allControlEvents];
}
#pragma mark - YouTube Detection
- (NSString *)getYouTubeInfoForObject:(id)object {
    if (!object) {
        return @"(None)";
    }
    Class cls =
        object_getClass(object);
    NSString *className =
        cls ? NSStringFromClass(cls) : @"";
    if (!className.length) {
        return @"(None)";
    }
    NSArray *prefixes = @[
        @"YT",
        @"AS",
        @"ELM",
        @"GOO",
        @"HAM",
        @"MDC",
        @"GIM",
        @"GCKN",
        @"GPB",
        @"ICN",
        @"MDX",
        @"ML"
    ];
    NSString *matchedPrefix = nil;
    for (NSString *prefix in prefixes) {
        if ([className hasPrefix:prefix]) {
            matchedPrefix = prefix;
            break;
        }
    }
    if (!matchedPrefix &&
        ![className containsString:@"YouTube"] &&
        ![className containsString:@"YT"]) {
        return @"Not identified as a YouTube-family class";
    }
    NSMutableString *result =
        [NSMutableString string];
    [result appendFormat:
        @"Detected Class: %@\n",
        className];
    if (matchedPrefix) {
        [result appendFormat:
            @"Family: %@*\n",
            matchedPrefix];
    }
    if ([className hasPrefix:@"AS"]) {
        [result appendString:
            @"Category: AsyncDisplayKit / Texture-style UI\n"];
    } else if ([className hasPrefix:@"ELM"]) {
        [result appendString:
            @"Category: ELM UI\n"];
    } else if ([className hasPrefix:@"GOO"]) {
        [result appendString:
            @"Category: GOO UI / Dialog / HUD\n"];
    } else if ([className hasPrefix:@"HAM"]) {
        [result appendString:
            @"Category: HAM media / playback\n"];
    } else if ([className hasPrefix:@"YT"]) {
        [result appendString:
            @"Category: YouTube UI / framework class\n"];
    }
    return result;
}
#pragma mark - View Tree
- (NSString *)buildViewTreeFromView:(UIView *)view {
    if (!view) {
        return @"(No View)";
    }
    NSMutableString *tree =
        [NSMutableString string];
    UIView *current =
        view;
    NSInteger depth = 0;
    while (current && depth < 50) {
        NSMutableString *indent =
            [NSMutableString string];
        for (NSInteger i = 0;
             i < depth;
             i++) {
            [indent appendString:@"    "];
        }
        CGRect screenFrame =
            [current convertRect:current.bounds
                          toView:nil];
        [tree appendFormat:
            @"%@%@%@\n"
             "%@    🔑 ID: %@\n"
             "%@    ♿ Label: %@\n"
             "%@    📝 Text: %@\n"
             "%@    🧩 Traits: %@\n"
             "%@    🎮 Interactive: %@\n"
             "%@    📍 Screen: (%.0f, %.0f, %.0f, %.0f)\n"
             "%@    👁️ Subviews: %lu\n",
            indent,
            depth == 0 ? @"🎯 " : @"└── ",
            NSStringFromClass(current.class),
            indent,
            [self getViewID:current] ?: @"(None)",
            indent,
            [self getViewLabel:current] ?: @"(None)",
            indent,
            [self getViewText:current] ?: @"(None)",
            indent,
            [self getTraitsString:current] ?: @"(None)",
            indent,
            [self isInteractiveView:current]
                ? @"YES"
                : @"NO",
            indent,
            screenFrame.origin.x,
            screenFrame.origin.y,
            screenFrame.size.width,
            screenFrame.size.height,
            indent,
            (unsigned long)current.subviews.count];
        if (current.gestureRecognizers.count) {
            [tree appendFormat:
                @"%@    👆 Gestures: %lu\n",
                indent,
                (unsigned long)
                    current.gestureRecognizers.count];
        }
        [tree appendString:@"\n"];
        current =
            current.superview;
        depth++;
    }
    return tree;
}
#pragma mark - Recursive Subtree
- (NSString *)buildRecursiveSubtree:(UIView *)view
                              depth:(NSInteger)depth
                           maxDepth:(NSInteger)maxDepth {
    if (!view ||
        depth > maxDepth) {
        return @"";
    }
    NSMutableString *result =
        [NSMutableString string];
    NSMutableString *indent =
        [NSMutableString string];
    for (NSInteger i = 0;
         i < depth;
         i++) {
        [indent appendString:@"    "];
    }
    CGRect screenFrame =
        [view convertRect:view.bounds
                  toView:nil];
    [result appendFormat:
        @"%@%@ %@\n"
         "%@    ID: %@\n"
         "%@    Label: %@\n"
         "%@    Text: %@\n"
         "%@    Value: %@\n"
         "%@    Hint: %@\n"
         "%@    Traits: %@\n"
         "%@    Interactive: %@\n"
         "%@    A11yElement: %@\n"
         "%@    Frame: (%.0f, %.0f, %.0f, %.0f)\n\n",
        indent,
        depth == 0 ? @"🎯" : @"└──",
        NSStringFromClass(view.class),
        indent,
        [self getViewID:view] ?: @"(None)",
        indent,
        [self getViewLabel:view] ?: @"(None)",
        indent,
        [self getViewText:view] ?: @"(None)",
        indent,
        view.accessibilityValue ?: @"(None)",
        indent,
        view.accessibilityHint ?: @"(None)",
        indent,
        [self getTraitsString:view] ?: @"(None)",
        indent,
        [self isInteractiveView:view]
            ? @"YES"
            : @"NO",
        indent,
        view.isAccessibilityElement
            ? @"YES"
            : @"NO",
        indent,
        screenFrame.origin.x,
        screenFrame.origin.y,
        screenFrame.size.width,
        screenFrame.size.height];
    if (depth < maxDepth) {
        for (UIView *subview in view.subviews) {
            [result appendString:
                [self buildRecursiveSubtree:subview
                                      depth:depth + 1
                                   maxDepth:maxDepth]];
        }
    }
    return result;
}
#pragma mark - Deep Accessibility
- (NSString *)getDeepAccessibilityInfo:(UIView *)view {
    if (!view) {
        return @"(None)";
    }
    NSMutableArray *elements =
        [NSMutableArray array];
    [self collectViewsWithIDs:view
                       result:elements
                     maxDepth:20];
    /*
     * إذا لم نجد IDs، نعرض accessibility
     * للعناصر المهمة.
     */
    if (!elements.count) {
        NSMutableArray *all =
            [NSMutableArray array];
        __block void (^collect)(UIView *, NSInteger);
        collect = ^(UIView *current,
                    NSInteger depth) {
            if (!current ||
                depth > 20) {
                return;
            }
            if ([self viewHasUsefulAccessibilityData:current]) {
                if (![all containsObject:current]) {
                    [all addObject:current];
                }
            }
            for (UIView *subview in current.subviews) {
                collect(subview, depth + 1);
            }
        };
        collect(view, 0);
        elements = all;
    }
    if (!elements.count) {
        return @"(No accessibility elements found)";
    }
    NSMutableString *result =
        [NSMutableString string];
    [result appendFormat:
        @"Accessibility Elements Found: %lu\n\n",
        (unsigned long)elements.count];
    NSUInteger index = 0;
    for (UIView *candidate in elements) {
        CGRect frame =
            [candidate convertRect:candidate.bounds
                            toView:nil];
        [result appendFormat:
            @"[%lu] %@\n"
             "    ID: %@\n"
             "    Label: %@\n"
             "    Value: %@\n"
             "    Hint: %@\n"
             "    Text: %@\n"
             "    Traits: %@\n"
             "    Interactive: %@\n"
             "    A11yElement: %@\n"
             "    Frame: (%.0f, %.0f, %.0f, %.0f)\n\n",
            (unsigned long)index,
            NSStringFromClass(candidate.class),
            [self getViewID:candidate] ?: @"(None)",
            candidate.accessibilityLabel.length
                ? candidate.accessibilityLabel
                : @"(None)",
            candidate.accessibilityValue.length
                ? candidate.accessibilityValue
                : @"(None)",
            candidate.accessibilityHint.length
                ? candidate.accessibilityHint
                : @"(None)",
            [self getViewText:candidate] ?: @"(None)",
            [self getTraitsString:candidate] ?: @"(None)",
            [self isInteractiveView:candidate]
                ? @"YES"
                : @"NO",
            candidate.isAccessibilityElement
                ? @"YES"
                : @"NO",
            frame.origin.x,
            frame.origin.y,
            frame.size.width,
            frame.size.height];
        index++;
    }
    return result;
}
#pragma mark - Accessibility Path
- (NSString *)getAccessibilityPath:(UIView *)view {
    if (!view) {
        return @"(None)";
    }
    NSMutableString *result =
        [NSMutableString string];
    UIView *current =
        view;
    NSInteger depth = 0;
    while (current && depth < 40) {
        [result appendFormat:
            @"[%02ld] %@ | ID=%@ | Label=%@ | Text=%@\n",
            (long)depth,
            NSStringFromClass(current.class),
            [self getViewID:current] ?: @"(None)",
            [self getViewLabel:current] ?: @"(None)",
            [self getViewText:current] ?: @"(None)"];
        current =
            current.superview;
        depth++;
    }
    return result;
}
#pragma mark - Full Report
- (NSString *)buildFullReportForView:(UIView *)view
                           hitTarget:(UIView *)hitTarget
                     resolvedTarget:(UIView *)resolvedTarget {
    if (!view) {
        return @"No View";
    }
    NSMutableString *report =
        [NSMutableString string];
    [report appendString:
        @"🎯 SELECTED VIEW\n"
         "══════════════════════════════\n\n"];
    [report appendFormat:
        @"Class: %@\n",
        NSStringFromClass(view.class)];
    [report appendFormat:
        @"Object Class: %@\n",
        [self classNameForObject:view]];
    [report appendFormat:
        @"Text: %@\n",
        [self getViewText:view] ?: @"(None)"];
    [report appendString:@"\n"];
    /*
     * مهم:
     * نعرض الـ hit الحقيقي والـ resolved الحقيقي.
     */
    [report appendString:
        @"🎯 TARGET RESOLUTION\n"
         "══════════════════════════════\n\n"];
    [report appendFormat:
        @"Hit Target Class: %@\n"
         "Hit Target ID: %@\n"
         "Resolved Target Class: %@\n"
         "Resolved Target ID: %@\n",
        hitTarget
            ? NSStringFromClass(hitTarget.class)
            : @"(None)",
        hitTarget
            ? ([self getViewID:hitTarget] ?: @"(None)")
            : @"(None)",
        resolvedTarget
            ? NSStringFromClass(resolvedTarget.class)
            : @"(None)",
        resolvedTarget
            ? ([self getViewID:resolvedTarget] ?: @"(None)")
            : @"(None)"];
    [report appendString:@"\n"];
    /*
     * Accessibility
     */
    [report appendString:
        @"♿ ACCESSIBILITY\n"
         "══════════════════════════════\n\n"];
    [report appendFormat:
        @"ID: %@\n"
         "Label: %@\n"
         "Value: %@\n"
         "Hint: %@\n"
         "Traits: %@\n"
         "Interactive: %@\n"
         "Is Accessibility Element: %@\n",
        [self getViewID:view] ?: @"(None)",
        [self getViewLabel:view] ?: @"(None)",
        view.accessibilityValue.length
            ? view.accessibilityValue
            : @"(None)",
        view.accessibilityHint.length
            ? view.accessibilityHint
            : @"(None)",
        [self getTraitsString:view] ?: @"(None)",
        [self isInteractiveView:view]
            ? @"YES"
            : @"NO",
        view.isAccessibilityElement
            ? @"YES"
            : @"NO"];
    [report appendString:
        @"\n📐 GEOMETRY\n"
         "══════════════════════════════\n\n"];
    [report appendString:
        [self getFrameInfoForView:view]];
    [report appendString:
        @"\n\n══════════════════════════════\n"
         "🌳 VIEW / ID TREE\n"
         "══════════════════════════════\n\n"];
    [report appendString:
        [self buildViewTreeFromView:view]];
    [report appendString:
        @"\n══════════════════════════════\n"
         "🌲 HIT TARGET SUBTREE\n"
         "══════════════════════════════\n\n"];
    [report appendString:
        [self buildRecursiveSubtree:
            hitTarget ?: view
            depth:0
            maxDepth:15]];
    [report appendString:
        @"\n══════════════════════════════\n"
         "🌲 RESOLVED TARGET SUBTREE\n"
         "══════════════════════════════\n\n"];
    [report appendString:
        [self buildRecursiveSubtree:
            resolvedTarget ?: view
            depth:0
            maxDepth:10]];
    [report appendString:
        @"\n══════════════════════════════\n"
         "⬆️ SUPERVIEW CHAIN\n"
         "══════════════════════════════\n\n"];
    [report appendString:
        [self getSuperviewChain:view]];
    [report appendString:
        @"\n══════════════════════════════\n"
         "↔️ SIBLINGS\n"
         "══════════════════════════════\n\n"];
    [report appendString:
        [self getSiblingInfo:view]];
    [report appendString:
        @"\n══════════════════════════════\n"
         "⬇️ DIRECT SUBVIEWS\n"
         "══════════════════════════════\n\n"];
    [report appendString:
        [self getSubviewsInfo:view]];
    [report appendString:
        @"\n══════════════════════════════\n"
         "♿ DEEP ACCESSIBILITY / IDS\n"
         "══════════════════════════════\n\n"];
    [report appendString:
        [self getDeepAccessibilityInfo:
            hitTarget ?: view]];
    [report appendString:
        @"\n══════════════════════════════\n"
         "🧭 ACCESSIBILITY PATH\n"
         "══════════════════════════════\n\n"];
    [report appendString:
        [self getAccessibilityPath:
            resolvedTarget ?: view]];
    [report appendString:
        @"\n══════════════════════════════\n"
         "🎮 CONTROL / INTERACTION\n"
         "══════════════════════════════\n\n"];
    [report appendString:
        [self getControlInfo:view]];
    [report appendString:
        @"\n\nGESTURES\n"];
    [report appendString:
        [self getGestureInfo:view]];
    [report appendString:
        @"\n══════════════════════════════\n"
         "🧬 RUNTIME CLASS\n"
         "══════════════════════════════\n\n"];
    [report appendString:
        [self getRuntimeInfoForObject:view]];
    [report appendString:
        @"\n══════════════════════════════\n"
         "📱 VIEW CONTROLLER\n"
         "══════════════════════════════\n\n"];
    [report appendString:
        [self getViewControllerInfo:view]];
    [report appendString:
        @"\n══════════════════════════════\n"
         "🪟 WINDOW\n"
         "══════════════════════════════\n\n"];
    [report appendString:
        [self getWindowInfo:view]];
    [report appendString:
        @"\n══════════════════════════════\n"
         "🎨 CALAYER\n"
         "══════════════════════════════\n\n"];
    [report appendString:
        [self getLayerInfo:view]];
    [report appendString:
        @"\n══════════════════════════════\n"
         "▶️ YOUTUBE DETECTION\n"
         "══════════════════════════════\n\n"];
    [report appendString:
        [self getYouTubeInfoForObject:view]];
    return report;
}
#pragma mark - Long Press
- (void)handleLongPress:
    (UILongPressGestureRecognizer *)sender {
    if (![self isInspectorEnabled]) {
        return;
    }
    if (sender.state !=
        UIGestureRecognizerStateBegan) {
        return;
    }
    UIWindow *window = nil;
    if ([sender.view isKindOfClass:[UIWindow class]]) {
        window = (UIWindow *)sender.view;
    }
    if (!window) {
        window = [self activeWindow];
    }
    if (!window) {
        return;
    }
    CGPoint point =
        [sender locationInView:window];
    /*
     * IMPORTANT:
     * استخدم hitTest الحقيقي.
     */
    UIView *hitTarget =
        [window hitTest:point
              withEvent:nil];
    if (!hitTarget) {
        return;
    }
    if ([self shouldIgnoreView:hitTarget]) {
        return;
    }
    if (hitTarget == window) {
        return;
    }
    /*
     * IMPORTANT:
     * هنا يتم حل الـ ID الحقيقي.
     */
    UIView *resolvedTarget =
        [self resolveExactTargetFromHitView:
            hitTarget
                                     window:window];
    if (!resolvedTarget) {
        resolvedTarget = hitTarget;
    }
    /*
     * التقرير الأساسي يستخدم العنصر الذي يحمل
     * الـ ID الحقيقي إذا وجد.
     */
    UIView *selectedView =
        [self viewHasDirectID:resolvedTarget]
            ? resolvedTarget
            : hitTarget;
    NSString *report =
        [self buildFullReportForView:selectedView
                           hitTarget:hitTarget
                     resolvedTarget:resolvedTarget];
    NSString *tree =
        [self buildRecursiveSubtree:
            hitTarget
            depth:0
            maxDepth:15];
    /*
     * هذا هو الـ ID النهائي الذي يتم نسخه.
     */
    NSString *directID =
        [self getViewID:resolvedTarget];
    if (!directID.length) {
        directID = @"(No Direct ID)";
    }
    NSString *resolvedClass =
        resolvedTarget
            ? NSStringFromClass(resolvedTarget.class)
            : @"(None)";
    NSString *title =
        [NSString stringWithFormat:
            @"🔍 Hamad Inspector\n%@", resolvedClass];
    UIAlertController *alert =
        [UIAlertController
            alertControllerWithTitle:title
            message:report
            preferredStyle:UIAlertControllerStyleAlert];
    /*
     * Copy Exact ID
     */
    [alert addAction:
        [UIAlertAction
            actionWithTitle:@"📋 Copy Exact ID"
            style:UIAlertActionStyleDefault
            handler:^(UIAlertAction *action) {
                [UIPasteboard generalPasteboard].string =
                    directID;
            }]
    ];
    /*
     * Copy Class + ID
     */
    [alert addAction:
        [UIAlertAction
            actionWithTitle:@"📋 Copy Class + ID"
            style:UIAlertActionStyleDefault
            handler:^(UIAlertAction *action) {
                NSString *value =
                    [NSString stringWithFormat:
                        @"Class: %@\nID: %@",
                        resolvedClass,
                        directID];
                [UIPasteboard generalPasteboard].string =
                    value;
            }]
    ];
    /*
     * Copy Tree
     */
    [alert addAction:
        [UIAlertAction
            actionWithTitle:@"🌳 Copy Tree"
            style:UIAlertActionStyleDefault
            handler:^(UIAlertAction *action) {
                [UIPasteboard generalPasteboard].string =
                    tree;
            }]
    ];
    /*
     * Copy All
     */
    [alert addAction:
        [UIAlertAction
            actionWithTitle:@"📄 Copy All"
            style:UIAlertActionStyleDefault
            handler:^(UIAlertAction *action) {
                [UIPasteboard generalPasteboard].string =
                    report;
            }]
    ];
    [alert addAction:
        [UIAlertAction
            actionWithTitle:@"👌 OK"
            style:UIAlertActionStyleCancel
            handler:nil]
    ];
    dispatch_async(
        dispatch_get_main_queue(),
        ^{
        UIViewController *vc =
            [self topViewController];
        if (!vc) {
            return;
        }
        UIViewController *presented =
            vc.presentedViewController;
        if ([presented
             isKindOfClass:
             [UIAlertController class]]) {
            return;
        }
        [vc presentViewController:alert
                           animated:YES
                         completion:nil];
    });
}
@end
#pragma mark - Constructor
%ctor {
    dispatch_async(
        dispatch_get_main_queue(),
        ^{
        [[HPlusDebugHelper sharedInstance]
            refreshInspector];
    });
}