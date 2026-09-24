#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import "Headers.h"

static char HPlusGestureKey;

@interface HPlusDebugHelper : NSObject
+ (instancetype)sharedInstance;
- (void)handleLongPress:(UILongPressGestureRecognizer *)sender;
- (void)setupGestureForWindow:(UIWindow *)window;
- (UIViewController *)topViewController;
- (BOOL)shouldIgnoreView:(UIView *)view;
- (BOOL)isInteractiveView:(UIView *)view;
- (NSString *)getViewID:(UIView *)view;
- (NSString *)getViewLabel:(UIView *)view;
- (NSString *)getViewText:(UIView *)view;
- (NSString *)getTraitsString:(UIView *)view;
- (NSString *)buildViewTreeFromView:(UIView *)view;
- (NSString *)getFrameInfoForView:(UIView *)view;
- (NSString *)getAdditionalInfoForView:(UIView *)view;
@end

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

+ (instancetype)sharedInstance {
    static HPlusDebugHelper *sharedInstance = nil;
    static dispatch_once_t onceToken;

    dispatch_once(&onceToken, ^{
        sharedInstance = [[HPlusDebugHelper alloc] init];
    });

    return sharedInstance;
}

- (BOOL)shouldIgnoreView:(UIView *)view {
    if (!view) return YES;

    NSString *className = NSStringFromClass(view.class);

    NSArray *ignoredClasses = @[
        @"_UIAlertControllerView",
        @"_UIKeyboardLayout",
        @"_UIRemoteKeyboardPlaceholderView",
        @"UIAlertController",
        @"UIKeyboard",
        @"UIRemoteKeyboard"
    ];

    for (NSString *ignoredClass in ignoredClasses) {
        if ([className containsString:ignoredClass]) {
            return YES;
        }
    }

    return NO;
}

- (void)setupGestureForWindow:(UIWindow *)window {
    if (!window || [self shouldIgnoreView:window]) {
        return;
    }

    NSString *windowClass = NSStringFromClass(window.class);

    if ([windowClass containsString:@"Alert"] ||
        [windowClass containsString:@"Keyboard"]) {
        return;
    }

    if (objc_getAssociatedObject(window, &HPlusGestureKey)) {
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

- (UIViewController *)topViewController {
    UIViewController *topVC = nil;

    if (@available(iOS 13.0, *)) {
        for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
            if (![scene isKindOfClass:[UIWindowScene class]]) {
                continue;
            }

            UIWindowScene *windowScene = (UIWindowScene *)scene;

            for (UIWindow *window in windowScene.windows) {
                if (window.isKeyWindow &&
                    !window.hidden &&
                    window.rootViewController) {

                    topVC = window.rootViewController;
                    break;
                }
            }

            if (topVC) break;
        }
    }

    if (!topVC) {
        for (UIWindow *window in UIApplication.sharedApplication.windows) {
            if (window.isKeyWindow &&
                !window.hidden &&
                window.rootViewController) {

                topVC = window.rootViewController;
                break;
            }
        }
    }

    if (!topVC) {
        for (UIWindow *window in UIApplication.sharedApplication.windows) {
            if (!window.hidden &&
                window.rootViewController) {

                topVC = window.rootViewController;
                break;
            }
        }
    }

    if (!topVC) return nil;

    while (topVC.presentedViewController) {
        topVC = topVC.presentedViewController;
    }

    if ([topVC isKindOfClass:[UINavigationController class]]) {
        topVC = [(UINavigationController *)topVC visibleViewController];
    }

    if ([topVC isKindOfClass:[UITabBarController class]]) {
        topVC = [(UITabBarController *)topVC selectedViewController];

        if ([topVC isKindOfClass:[UINavigationController class]]) {
            topVC = [(UINavigationController *)topVC visibleViewController];
        }
    }

    if ([topVC isKindOfClass:[UISplitViewController class]]) {
        UISplitViewController *splitVC = (UISplitViewController *)topVC;
        topVC = splitVC.viewControllers.lastObject;

        if ([topVC isKindOfClass:[UINavigationController class]]) {
            topVC = [(UINavigationController *)topVC visibleViewController];
        }
    }

    return topVC;
}

- (BOOL)isInteractiveView:(UIView *)view {
    if (!view) return NO;

    if ([view isKindOfClass:[UIButton class]]) {
        return YES;
    }

    if ([view isKindOfClass:[UIControl class]]) {
        UIControl *control = (UIControl *)view;

        if (control.enabled && control.userInteractionEnabled) {
            return YES;
        }
    }

    return view.gestureRecognizers.count > 0;
}

- (NSString *)getViewID:(UIView *)view {
    if (!view) return nil;

    NSString *identifier = view.accessibilityIdentifier;

    return identifier.length > 0 ? identifier : nil;
}

- (NSString *)getViewLabel:(UIView *)view {
    if (!view) return nil;

    NSString *label = view.accessibilityLabel;

    return label.length > 0 ? label : nil;
}

- (NSString *)getViewText:(UIView *)view {
    if (!view) return nil;

    if ([view isKindOfClass:[UILabel class]]) {
        UILabel *label = (UILabel *)view;

        if (label.text.length > 0) {
            return label.text;
        }
    }

    if ([view isKindOfClass:[UIButton class]]) {
        UIButton *button = (UIButton *)view;

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
        UITextField *textField = (UITextField *)view;

        if (textField.text.length > 0) {
            return textField.text;
        }

        if (textField.placeholder.length > 0) {
            return textField.placeholder;
        }
    }

    if ([view isKindOfClass:[UITextView class]]) {
        UITextView *textView = (UITextView *)view;

        if (textView.text.length > 0) {
            return textView.text;
        }
    }

    return nil;
}

- (NSString *)getTraitsString:(UIView *)view {
    if (!view) return nil;

    UIAccessibilityTraits traits = view.accessibilityTraits;

    if (traits == 0) return nil;

    NSMutableArray *items = [NSMutableArray array];

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

    if (items.count == 0) {
        return [NSString stringWithFormat:@"0x%llx",
                (unsigned long long)traits];
    }

    return [items componentsJoinedByString:@", "];
}

- (NSString *)buildViewTreeFromView:(UIView *)view {
    if (!view) return @"(No View)";

    NSMutableString *tree = [NSMutableString string];

    UIView *currentView = view;
    int depth = 0;

    while (currentView && depth < 20) {
        NSString *className = NSStringFromClass(currentView.class);
        NSString *identifier = [self getViewID:currentView];
        NSString *label = [self getViewLabel:currentView];
        NSString *text = [self getViewText:currentView];
        NSString *traits = [self getTraitsString:currentView];

        BOOL interactive = [self isInteractiveView:currentView];

        CGRect frame = currentView.frame;

        NSMutableString *indent = [NSMutableString string];

        for (int i = 0; i < depth; i++) {
            [indent appendString:@"    "];
        }

        NSString *prefix = depth == 0 ? @"🎯 " : @"└── ";

        [tree appendFormat:@"%@%@%@\n",
            indent,
            prefix,
            className];

        [tree appendFormat:@"%@    🔑 ID: %@\n",
            indent,
            identifier.length > 0 ? identifier : @"(None)"];

        if (label.length > 0) {
            [tree appendFormat:@"%@    ♿ Label: %@\n",
                indent,
                label];
        }

        if (text.length > 0) {
            [tree appendFormat:@"%@    📝 Text: %@\n",
                indent,
                text];
        }

        if (traits.length > 0) {
            [tree appendFormat:@"%@    🧩 Traits: %@\n",
                indent,
                traits];
        }

        [tree appendFormat:@"%@    🎮 Interactive: %@\n",
            indent,
            interactive ? @"YES" : @"NO"];

        [tree appendFormat:@"%@    📍 Frame: (%.0f, %.0f, %.0f, %.0f)\n",
            indent,
            frame.origin.x,
            frame.origin.y,
            frame.size.width,
            frame.size.height];

        if (currentView.gestureRecognizers.count > 0) {
            [tree appendFormat:@"%@    👆 Gestures: %lu\n",
                indent,
                (unsigned long)currentView.gestureRecognizers.count];
        }

        [tree appendString:@"\n"];

        currentView = currentView.superview;
        depth++;
    }

    return tree;
}

- (NSString *)getFrameInfoForView:(UIView *)view {
    if (!view) return nil;

    CGRect frame = view.frame;
    CGRect bounds = view.bounds;

    return [NSString stringWithFormat:
        @"Frame: (%.0f, %.0f, %.0f, %.0f) | Bounds: (%.0f, %.0f, %.0f, %.0f)",
        frame.origin.x,
        frame.origin.y,
        frame.size.width,
        frame.size.height,
        bounds.origin.x,
        bounds.origin.y,
        bounds.size.width,
        bounds.size.height];
}

- (NSString *)getAdditionalInfoForView:(UIView *)view {
    if (!view) return nil;

    NSMutableString *info = [NSMutableString string];

    [info appendFormat:
        @"Alpha: %.2f | Hidden: %@ | UserInteraction: %@",
        view.alpha,
        view.hidden ? @"Yes" : @"No",
        view.userInteractionEnabled ? @"Yes" : @"No"];

    if (view.tag != 0) {
        [info appendFormat:@" | Tag: %ld", (long)view.tag];
    }

    if (view.layer.cornerRadius > 0) {
        [info appendFormat:@" | Corner: %.1f",
            view.layer.cornerRadius];
    }

    if ([view isKindOfClass:[UIControl class]]) {
        UIControl *control = (UIControl *)view;

        [info appendFormat:@" | Enabled: %@",
            control.enabled ? @"Yes" : @"No"];
    }

    return info;
}

- (void)handleLongPress:(UILongPressGestureRecognizer *)sender {
    if (sender.state != UIGestureRecognizerStateBegan) {
        return;
    }

    if (![sender.view isKindOfClass:[UIWindow class]]) {
        return;
    }

    UIWindow *window = (UIWindow *)sender.view;

    CGPoint point = [sender locationInView:window];

    UIView *targetView = [window hitTest:point withEvent:nil];

    if (!targetView || [self shouldIgnoreView:targetView]) {
        return;
    }

    NSString *targetClass = NSStringFromClass(targetView.class);
    NSString *targetID = [self getViewID:targetView];
    NSString *targetLabel = [self getViewLabel:targetView];
    NSString *targetText = [self getViewText:targetView];

    NSString *viewTree = [self buildViewTreeFromView:targetView];

    NSString *accessibilityInfo =
        [NSString stringWithFormat:
            @"ID: %@ | Label: %@ | Value: %@ | Hint: %@",
            targetView.accessibilityIdentifier.length > 0
                ? targetView.accessibilityIdentifier
                : @"(None)",
            targetView.accessibilityLabel.length > 0
                ? targetView.accessibilityLabel
                : @"(None)",
            targetView.accessibilityValue.length > 0
                ? targetView.accessibilityValue
                : @"(None)",
            targetView.accessibilityHint.length > 0
                ? targetView.accessibilityHint
                : @"(None)"];

    NSString *frameInfo = [self getFrameInfoForView:targetView];
    NSString *additionalInfo = [self getAdditionalInfoForView:targetView];

    NSMutableString *message = [NSMutableString string];

    [message appendFormat:@"🎯 HIT VIEW\n%@\n\n", targetClass];

    [message appendFormat:@"🔑 HIT VIEW ID\n%@\n\n",
        targetID.length > 0 ? targetID : @"(None)"];

    [message appendFormat:@"♿ HIT VIEW LABEL\n%@\n\n",
        targetLabel.length > 0 ? targetLabel : @"(None)"];

    [message appendFormat:@"📝 HIT VIEW TEXT\n%@\n\n",
        targetText.length > 0 ? targetText : @"(None)"];

    [message appendString:
        @"══════════════════════════════\n"
         "🌳 VIEW / ID TREE\n"
         "══════════════════════════════\n\n"];

    [message appendString:viewTree];

    [message appendString:
        @"\n══════════════════════════════\n"
         "♿ ACCESSIBILITY\n"
         "══════════════════════════════\n\n"];

    [message appendFormat:@"%@\n\n", accessibilityInfo];

    [message appendFormat:@"📍 %@\n\n", frameInfo];
    [message appendFormat:@"⚙️ %@", additionalInfo];

    NSString *bestID =
        targetID.length > 0
            ? targetID
            : @"(No Direct ID on Hit View)";

    UIAlertController *alert =
        [UIAlertController
            alertControllerWithTitle:@"🔍 Hamad Inspector"
            message:message
            preferredStyle:UIAlertControllerStyleAlert];

    [alert addAction:
        [UIAlertAction
            actionWithTitle:@"📋 Copy Direct ID"
            style:UIAlertActionStyleDefault
            handler:^(UIAlertAction *action) {
                [UIPasteboard generalPasteboard].string = bestID;
            }]];

    [alert addAction:
        [UIAlertAction
            actionWithTitle:@"🌳 Copy ID Tree"
            style:UIAlertActionStyleDefault
            handler:^(UIAlertAction *action) {
                [UIPasteboard generalPasteboard].string = viewTree;
            }]];

    [alert addAction:
        [UIAlertAction
            actionWithTitle:@"📄 Copy All"
            style:UIAlertActionStyleDefault
            handler:^(UIAlertAction *action) {
                [UIPasteboard generalPasteboard].string = message;
            }]];

    [alert addAction:
        [UIAlertAction
            actionWithTitle:@"👌 OK"
            style:UIAlertActionStyleCancel
            handler:nil]];

    dispatch_async(dispatch_get_main_queue(), ^{
        UIViewController *topVC = [self topViewController];

        if (topVC) {
            [topVC presentViewController:alert
                                 animated:YES
                               completion:nil];
        } else {
            UIWindow *alertWindow =
                [[UIWindow alloc]
                    initWithFrame:UIScreen.mainScreen.bounds];

            alertWindow.rootViewController =
                [[UIViewController alloc] init];

            alertWindow.windowLevel =
                UIWindowLevelAlert + 1;

            alertWindow.backgroundColor =
                UIColor.clearColor;

            [alertWindow makeKeyAndVisible];

            dispatch_after(
                dispatch_time(DISPATCH_TIME_NOW,
                              (int64_t)(0.1 * NSEC_PER_SEC)),
                dispatch_get_main_queue(),
                ^{
                    [alertWindow.rootViewController
                        presentViewController:alert
                        animated:YES
                        completion:nil];
                });
        }
    });
}

@end

%ctor {
    [HPlusDebugHelper sharedInstance];
}