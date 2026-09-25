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
- (NSString *)buildFullReportForView:(UIView *)view;

@end


#pragma mark - UIWindow Hooks

%hook UIWindow

- (void)makeKeyAndVisible {
    %orig;

    dispatch_async(dispatch_get_main_queue(), ^{
        [[HPlusDebugHelper sharedInstance] setupGestureForWindow:self];
    });
}

- (void)becomeKeyWindow {
    %orig;

    dispatch_after(
        dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.05 * NSEC_PER_SEC)),
        dispatch_get_main_queue(),
        ^{
            [[HPlusDebugHelper sharedInstance] setupGestureForWindow:self];
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

                for (UIWindow *window in windowScene.windows) {
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

            for (UIWindow *window in windowScene.windows) {

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


#pragma mark - Basic Helpers

- (NSString *)safeString:(id)value {

    if (!value || value == [NSNull null]) {
        return @"(None)";
    }

    @try {

        NSString *description =
            [value description];

        if (!description ||
            description.length == 0) {

            return @"(None)";
        }

        return description;

    } @catch (...) {

        return @"(Unavailable)";
    }
}

- (NSString *)classNameForObject:(id)object {

    if (!object) {
        return @"(None)";
    }

    Class cls = object_getClass(object);

    if (!cls) {
        return @"(Unknown)";
    }

    return NSStringFromClass(cls);
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

    UIWindow *result = nil;

    if (@available(iOS 13.0, *)) {

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
            }

            for (UIWindow *window
                 in windowScene.windows) {

                if (!window.hidden &&
                    window.alpha > 0.01 &&
                    window.rootViewController) {

                    result = window;
                    break;
                }
            }

            if (result) {
                return result;
            }
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

            result = window;
            break;
        }
    }

#pragma clang diagnostic pop

    return result;
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

    while (vc.presentedViewController &&
           !vc.presentedViewController.isBeingDismissed) {

        vc = vc.presentedViewController;
    }

    BOOL changed = YES;

    while (changed) {

        changed = NO;

        if ([vc isKindOfClass:
            [UINavigationController class]]) {

            UIViewController *visible =
                [(UINavigationController *)vc
                 visibleViewController];

            if (visible && visible != vc) {
                vc = visible;
                changed = YES;
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

        if (vc.presentedViewController &&
            !vc.presentedViewController.isBeingDismissed) {

            vc = vc.presentedViewController;
            changed = YES;
        }
    }

    return vc;
}


#pragma mark - Setup Gesture

- (void)setupGestureForWindow:(UIWindow *)window {

    if (![self isInspectorEnabled]) {
        return;
    }

    if (!window) {
        return;
    }

    if ([self shouldIgnoreView:window]) {
        return;
    }

    NSString *windowClass =
        NSStringFromClass(window.class);

    if ([windowClass containsString:@"Keyboard"] ||
        [windowClass containsString:@"Alert"]) {

        return;
    }

    if (objc_getAssociatedObject(
            window,
            &HPlusGestureKey)) {

        return;
    }

    UILongPressGestureRecognizer *longPress =
        [[UILongPressGestureRecognizer alloc]
            initWithTarget:self
            action:@selector(handleLongPress:)];

    longPress.minimumPressDuration = 0.4;
    longPress.cancelsTouchesInView = NO;
    longPress.delaysTouchesBegan = NO;
    longPress.delaysTouchesEnded = NO;

    [window addGestureRecognizer:longPress];

    objc_setAssociatedObject(
        window,
        &HPlusGestureKey,
        longPress,
        OBJC_ASSOCIATION_RETAIN_NONATOMIC
    );
}


#pragma mark - Accessibility

- (NSString *)getViewID:(UIView *)view {

    if (!view) {
        return nil;
    }

    NSString *identifier =
        view.accessibilityIdentifier;

    return identifier.length > 0
        ? identifier
        : nil;
}

- (NSString *)getViewLabel:(UIView *)view {

    if (!view) {
        return nil;
    }

    NSString *label =
        view.accessibilityLabel;

    return label.length > 0
        ? label
        : nil;
}

- (NSString *)getViewText:(UIView *)view {

    if (!view) {
        return nil;
    }

    if ([view isKindOfClass:[UILabel class]]) {

        UILabel *label =
            (UILabel *)view;

        if (label.text.length > 0) {
            return label.text;
        }
    }

    if ([view isKindOfClass:[UIButton class]]) {

        UIButton *button =
            (UIButton *)view;

        if (button.currentTitle.length > 0) {
            return button.currentTitle;
        }

        if (button.currentAttributedTitle.string.length > 0) {
            return button.currentAttributedTitle.string;
        }

        if (button.titleLabel.text.length > 0) {
            return button.titleLabel.text;
        }
    }

    if ([view isKindOfClass:[UITextField class]]) {

        UITextField *field =
            (UITextField *)view;

        if (field.text.length > 0) {
            return field.text;
        }

        if (field.placeholder.length > 0) {
            return field.placeholder;
        }
    }

    if ([view isKindOfClass:[UITextView class]]) {

        UITextView *textView =
            (UITextView *)view;

        if (textView.text.length > 0) {
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

    if (traits.count == 0) {
        return [NSString stringWithFormat:
            @"0x%llx",
            (unsigned long long)traits];
    }

    return [items componentsJoinedByString:@", "];
}


#pragma mark - Interactive

- (BOOL)isInteractiveView:(UIView *)view {

    if (!view) {
        return NO;
    }

    if (!view.userInteractionEnabled) {
        return NO;
    }

    if ([view isKindOfClass:[UIControl class]]) {

        UIControl *control =
            (UIControl *)view;

        if (control.enabled) {
            return YES;
        }
    }

    if (view.gestureRecognizers.count > 0) {
        return YES;
    }

    return NO;
}


#pragma mark - Geometry

- (NSString *)getFrameInfoForView:(UIView *)view {

    if (!view) {
        return @"(Unavailable)";
    }

    CGRect localFrame =
        view.frame;

    CGRect bounds =
        view.bounds;

    CGRect windowFrame =
        CGRectZero;

    CGRect screenFrame =
        CGRectZero;

    if (view.window) {

        windowFrame =
            [view convertRect:view.bounds
                      toView:view.window];

        screenFrame =
            [view convertRect:view.bounds
                      toView:nil];

    } else {

        screenFrame =
            [view convertRect:view.bounds
                      toView:nil];

        windowFrame =
            screenFrame;
    }

    return [NSString stringWithFormat:
        @"Local Frame: (%.1f, %.1f, %.1f, %.1f)\n"
         "Window Frame: (%.1f, %.1f, %.1f, %.1f)\n"
         "Screen Frame: (%.1f, %.1f, %.1f, %.1f)\n"
         "Bounds: (%.1f, %.1f, %.1f, %.1f)\n"
         "Center: (%.1f, %.1f)\n"
         "Transform: %@",

        localFrame.origin.x,
        localFrame.origin.y,
        localFrame.size.width,
        localFrame.size.height,

        windowFrame.origin.x,
        windowFrame.origin.y,
        windowFrame.size.width,
        windowFrame.size.height,

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

        if ([responder
             isKindOfClass:
             [UIViewController class]]) {

            vc =
                (UIViewController *)responder;

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

        vc.title.length > 0
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

    int depth = 0;

    while (current && depth < 40) {

        NSString *identifier =
            [self getViewID:current];

        [result appendFormat:
            @"%02d | %@ | ID: %@\n",

            depth,

            NSStringFromClass(current.class),

            identifier.length > 0
                ? identifier
                : @"(None)"];

        current =
            current.superview;

        depth++;
    }

    return result.length > 0
        ? result
        : @"(None)";
}


#pragma mark - Subviews

- (NSString *)getSubviewsInfo:(UIView *)view {

    if (!view ||
        view.subviews.count == 0) {

        return @"(None)";
    }

    NSMutableString *result =
        [NSMutableString string];

    NSUInteger index = 0;

    for (UIView *subview
         in view.subviews) {

        NSString *identifier =
            [self getViewID:subview];

        NSString *label =
            [self getViewLabel:subview];

        [result appendFormat:
            @"[%lu] %@\n"
             "    ID: %@\n"
             "    Label: %@\n"
             "    Frame: %@\n"
             "    Interactive: %@\n\n",

            (unsigned long)index,

            NSStringFromClass(subview.class),

            identifier.length > 0
                ? identifier
                : @"(None)",

            label.length > 0
                ? label
                : @"(None)",

            NSStringFromCGRect(
                subview.frame),

            [self isInteractiveView:subview]
                ? @"YES"
                : @"NO"];

        index++;
    }

    return result;
}


#pragma mark - Runtime Superclasses

- (NSString *)getSuperclassChainForClass:(Class)cls {

    if (!cls) {
        return @"(None)";
    }

    NSMutableString *result =
        [NSMutableString string];

    Class current =
        cls;

    int depth = 0;

    while (current && depth < 40) {

        [result appendFormat:
            @"[%02d] %@\n",
            depth,
            NSStringFromClass(current)];

        current =
            class_getSuperclass(current);

        depth++;
    }

    return result;
}


#pragma mark - Protocols

- (NSString *)getProtocolsForClass:(Class)cls {

    if (!cls) {
        return @"(None)";
    }

    NSMutableString *result =
        [NSMutableString string];

    unsigned int count = 0;

    Protocol *__unsafe_unretained *protocols =
        class_copyProtocolList(
            cls,
            &count
        );

    for (unsigned int i = 0;
         i < count;
         i++) {

        Protocol *protocol =
            protocols[i];

        if (protocol) {

            [result appendFormat:
                @"• %@\n",
                NSStringFromProtocol(protocol)];
        }
    }

    if (protocols) {
        free(protocols);
    }

    return result.length > 0
        ? result
        : @"(None)";
}


#pragma mark - Properties

- (NSString *)getPropertiesForClass:(Class)cls {

    if (!cls) {
        return @"(None)";
    }

    NSMutableString *result =
        [NSMutableString string];

    unsigned int count = 0;

    objc_property_t *properties =
        class_copyPropertyList(
            cls,
            &count
        );

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

                attributes
                    ? attributes
                    : "(Unknown)"];
        }
    }

    if (properties) {
        free(properties);
    }

    return result.length > 0
        ? result
        : @"(None)";
}


#pragma mark - Ivars

- (NSString *)getIvarsForClass:(Class)cls {

    if (!cls) {
        return @"(None)";
    }

    NSMutableString *result =
        [NSMutableString string];

    unsigned int count = 0;

    Ivar *ivars =
        class_copyIvarList(
            cls,
            &count
        );

    for (unsigned int i = 0;
         i < count;
         i++) {

        Ivar ivar =
            ivars[i];

        const char *name =
            ivar_getName(ivar);

        const char *type =
            ivar_getTypeEncoding(ivar);

        ptrdiff_t offset =
            ivar_getOffset(ivar);

        if (name) {

            [result appendFormat:
                @"• %s | Type: %s | Offset: %td\n",

                name,

                type
                    ? type
                    : "(Unknown)",

                offset];
        }
    }

    if (ivars) {
        free(ivars);
    }

    return result.length > 0
        ? result
        : @"(None)";
}


#pragma mark - Methods

- (NSString *)getMethodsForClass:(Class)cls {

    if (!cls) {
        return @"(None)";
    }

    NSMutableString *result =
        [NSMutableString string];

    unsigned int count = 0;

    Method *methods =
        class_copyMethodList(
            cls,
            &count
        );

    for (unsigned int i = 0;
         i < count;
         i++) {

        Method method =
            methods[i];

        SEL selector =
            method_getName(method);

        const char *types =
            method_getTypeEncoding(method);

        if (selector) {

            [result appendFormat:
                @"• -[%@ %@] | %s\n",

                NSStringFromClass(cls),

                NSStringFromSelector(selector),

                types
                    ? types
                    : "(Unknown)"];
        }
    }

    if (methods) {
        free(methods);
    }

    return result.length > 0
        ? result
        : @"(None)";
}


#pragma mark - Runtime Info

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

    [result appendString:
        @"SUPERCLASS CHAIN\n"];

    [result appendString:
        [self getSuperclassChainForClass:cls]];

    [result appendString:
        @"\nPROTOCOLS\n"];

    [result appendString:
        [self getProtocolsForClass:cls]];

    [result appendString:
        @"\nPROPERTIES\n"];

    [result appendString:
        [self getPropertiesForClass:cls]];

    [result appendString:
        @"\nIVARS\n"];

    [result appendString:
        [self getIvarsForClass:cls]];

    [result appendString:
        @"\nMETHODS\n"];

    [result appendString:
        [self getMethodsForClass:cls]];

    return result;
}


#pragma mark - Gestures

- (NSString *)getGestureInfo:(UIView *)view {

    if (!view ||
        view.gestureRecognizers.count == 0) {

        return @"(None)";
    }

    NSMutableString *result =
        [NSMutableString string];

    NSUInteger index = 0;

    for (UIGestureRecognizer *gesture
         in view.gestureRecognizers) {

        NSString *state =
            @"Unknown";

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


#pragma mark - UIControl

- (NSString *)getControlInfo:(UIView *)view {

    if (![view isKindOfClass:[UIControl class]]) {
        return @"Not a UIControl";
    }

    UIControl *control =
        (UIControl *)view;

    NSMutableString *result =
        [NSMutableString string];

    [result appendFormat:
        @"Control Class: %@\n"
         "Enabled: %@\n"
         "Selected: %@\n"
         "Highlighted: %@\n"
         "Focused: %@\n"
         "State: %lu\n"
         "Events: 0x%lx\n",

        NSStringFromClass(control.class),

        control.enabled ? @"YES" : @"NO",

        control.selected ? @"YES" : @"NO",

        control.highlighted ? @"YES" : @"NO",

        control.isFocused ? @"YES" : @"NO",

        (unsigned long)control.state,

        (unsigned long)control.allControlEvents];

    return result;
}


#pragma mark - YouTube Detection

- (NSString *)getYouTubeInfoForObject:(id)object {

    if (!object) {
        return @"(None)";
    }

    Class cls =
        object_getClass(object);

    if (!cls) {
        return @"(None)";
    }

    NSString *className =
        NSStringFromClass(cls);

    NSArray *youtubePrefixes = @[
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

    NSString *matchedPrefix =
        nil;

    for (NSString *prefix
         in youtubePrefixes) {

        if ([className hasPrefix:prefix]) {

            matchedPrefix =
                prefix;

            break;
        }
    }

    if (!matchedPrefix) {

        if (![className containsString:@"YouTube"] &&
            ![className containsString:@"YT"]) {

            return
                @"Not identified as a YouTube-family class";
        }
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

    } else {

        [result appendString:
            @"Family: YouTube-related\n"];
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

    [result appendString:
        @"Header Repository: YouTubeHeader\n"];

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

    int depth = 0;

    while (current && depth < 40) {

        NSString *className =
            NSStringFromClass(current.class);

        NSString *identifier =
            [self getViewID:current];

        NSString *label =
            [self getViewLabel:current];

        NSString *text =
            [self getViewText:current];

        NSString *traits =
            [self getTraitsString:current];

        BOOL interactive =
            [self isInteractiveView:current];

        CGRect screenFrame =
            [current convertRect:current.bounds
                          toView:nil];

        NSMutableString *indent =
            [NSMutableString string];

        for (int i = 0; i < depth; i++) {
            [indent appendString:@"    "];
        }

        [tree appendFormat:
            @"%@%@%@\n",

            indent,

            depth == 0
                ? @"🎯 "
                : @"└── ",

            className];

        [tree appendFormat:
            @"%@    🔑 ID: %@\n",

            indent,

            identifier.length > 0
                ? identifier
                : @"(None)"];

        [tree appendFormat:
            @"%@    ♿ Label: %@\n",

            indent,

            label.length > 0
                ? label
                : @"(None)"];

        [tree appendFormat:
            @"%@    📝 Text: %@\n",

            indent,

            text.length > 0
                ? text
                : @"(None)"];

        [tree appendFormat:
            @"%@    🧩 Traits: %@\n",

            indent,

            traits.length > 0
                ? traits
                : @"(None)"];

        [tree appendFormat:
            @"%@    🎮 Interactive: %@\n",

            indent,

            interactive
                ? @"YES"
                : @"NO"];

        [tree appendFormat:
            @"%@    📍 Screen: (%.0f, %.0f, %.0f, %.0f)\n",

            indent,

            screenFrame.origin.x,
            screenFrame.origin.y,
            screenFrame.size.width,
            screenFrame.size.height];

        [tree appendFormat:
            @"%@    👁️ Subviews: %lu\n",

            indent,

            (unsigned long)
            current.subviews.count];

        if (current.gestureRecognizers.count > 0) {

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


#pragma mark - Full Report

- (NSString *)buildFullReportForView:(UIView *)view {

    if (!view) {
        return @"No View";
    }

    NSString *className =
        NSStringFromClass(view.class);

    NSString *identifier =
        [self getViewID:view];

    NSString *label =
        [self getViewLabel:view];

    NSString *text =
        [self getViewText:view];

    NSString *traits =
        [self getTraitsString:view];

    BOOL interactive =
        [self isInteractiveView:view];

    NSMutableString *report =
        [NSMutableString string];

    [report appendString:
        @"🎯 SELECTED VIEW\n"
         "══════════════════════════════\n\n"];

    [report appendFormat:
        @"Class: %@\n",
        className];

    [report appendFormat:
        @"Object Class: %@\n",
        [self classNameForObject:view]];

    [report appendFormat:
        @"Text: %@\n",
        text.length > 0
            ? text
            : @"(None)"];

    [report appendString:@"\n"];

    [report appendString:
        @"♿ ACCESSIBILITY\n"
         "══════════════════════════════\n\n"];

    [report appendFormat:
        @"ID: %@\n"
         "Label: %@\n"
         "Value: %@\n"
         "Hint: %@\n"
         "Traits: %@\n"
         "Interactive: %@",

        identifier.length > 0
            ? identifier
            : @"(None)",

        label.length > 0
            ? label
            : @"(None)",

        view.accessibilityValue.length > 0
            ? view.accessibilityValue
            : @"(None)",

        view.accessibilityHint.length > 0
            ? view.accessibilityHint
            : @"(None)",

        traits.length > 0
            ? traits
            : @"(None)",

        interactive
            ? @"YES"
            : @"NO"];

    [report appendString:@"\n\n"];

    [report appendString:
        @"📐 GEOMETRY\n"
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
         "⬆️ SUPERVIEW CHAIN\n"
         "══════════════════════════════\n\n"];

    [report appendString:
        [self getSuperviewChain:view]];

    [report appendString:
        @"\n══════════════════════════════\n"
         "⬇️ DIRECT SUBVIEWS\n"
         "══════════════════════════════\n\n"];

    [report appendString:
        [self getSubviewsInfo:view]];

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

    if (![sender.view
         isKindOfClass:[UIWindow class]]) {

        return;
    }

    UIWindow *window =
        (UIWindow *)sender.view;

    CGPoint point =
        [sender locationInView:window];

    UIView *target =
        [window hitTest:point
              withEvent:nil];

    if (!target) {
        return;
    }

    if ([self shouldIgnoreView:target]) {
        return;
    }

    if (target == window) {
        return;
    }

    NSString *report =
        [self buildFullReportForView:target];

    NSString *tree =
        [self buildViewTreeFromView:target];

    NSString *directID =
        [self getViewID:target];

    if (!directID.length) {
        directID = @"(No Direct ID)";
    }

    UIAlertController *alert =
        [UIAlertController
            alertControllerWithTitle:
                @"🔍 Hamad Inspector"
            message:report
            preferredStyle:
                UIAlertControllerStyleAlert];

    [alert addAction:
        [UIAlertAction
            actionWithTitle:@"📋 Copy ID"
            style:UIAlertActionStyleDefault
            handler:^(UIAlertAction *action) {

                [UIPasteboard generalPasteboard].string =
                    directID;
            }]
    ];

    [alert addAction:
        [UIAlertAction
            actionWithTitle:@"🌳 Copy Tree"
            style:UIAlertActionStyleDefault
            handler:^(UIAlertAction *action) {

                [UIPasteboard generalPasteboard].string =
                    tree;
            }]
    ];

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


#pragma mark - Settings Observer

%hook NSUserDefaults

- (void)setBool:(BOOL)value forKey:(NSString *)defaultName {

    %orig;

    if ([defaultName isEqualToString:HPlusInspector]) {

        dispatch_async(
            dispatch_get_main_queue(),
            ^{

            [[HPlusDebugHelper sharedInstance]
                refreshInspector];
        });
    }
}

%end


#pragma mark - Constructor

%ctor {

    [[HPlusDebugHelper sharedInstance]
        refreshInspector];
}