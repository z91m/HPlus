#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <os/log.h>
#import "Headers.h"

static char kHPlusGestureKey;

@interface HPlusDebugHelper : NSObject
+ (instancetype)sharedInstance;
- (void)handleLongPress:(UILongPressGestureRecognizer *)sender;
- (void)setupGestureForWindow:(UIWindow *)window;
- (UIViewController *)topViewController;
- (NSString *)getClassChainForView:(UIView *)view;
- (NSString *)extractTextFromView:(UIView *)view;
- (NSString *)getImageInfoForView:(UIView *)view;
- (NSString *)getAccessibilityInfoForView:(UIView *)view;
- (NSString *)getFrameInfoForView:(UIView *)view;
- (NSString *)getAdditionalInfoForView:(UIView *)view;
- (NSString *)extractIdentifierFromView:(UIView *)view;
- (BOOL)shouldIgnoreView:(UIView *)view;
- (BOOL)isGeneralOrIgnoredIdentifier:(NSString *)identifier;
- (NSString *)findDeepChildIdentifierInView:(UIView *)view depth:(int)currentDepth;
@end

%hook UIWindow

- (void)makeKeyAndVisible {
    %orig;
    [[HPlusDebugHelper sharedInstance] setupGestureForWindow:self];
}

- (void)becomeKeyWindow {
    %orig;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.05 * NSEC_PER_SEC)), 
                  dispatch_get_main_queue(), ^{
        [[HPlusDebugHelper sharedInstance] setupGestureForWindow:self];
    });
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
    
    NSString *className = NSStringFromClass([view class]);
    
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
    if (!window) return;
    
    if ([self shouldIgnoreView:window]) return;
    
    NSString *windowClass = NSStringFromClass([window class]);
    if ([windowClass containsString:@"Alert"] || 
        [windowClass containsString:@"Keyboard"]) {
        return;
    }
    
    id existingGesture = objc_getAssociatedObject(window, &kHPlusGestureKey);
    if (existingGesture) return;
    
    UILongPressGestureRecognizer *longPress = 
        [[UILongPressGestureRecognizer alloc] 
         initWithTarget:self 
         action:@selector(handleLongPress:)];
    longPress.minimumPressDuration = 0.4;
    longPress.cancelsTouchesInView = NO;
    longPress.delaysTouchesBegan = NO;
    longPress.delaysTouchesEnded = NO;
    [window addGestureRecognizer:longPress];
    
    objc_setAssociatedObject(window, &kHPlusGestureKey, longPress, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (UIViewController *)topViewController {
    UIViewController *topVC = nil;
    
    for (UIWindow *window in [UIApplication sharedApplication].windows) {
        if (window.isKeyWindow && !window.hidden && window.rootViewController) {
            topVC = window.rootViewController;
            break;
        }
    }
    
    if (!topVC) {
        if (@available(iOS 13.0, *)) {
            NSSet *connectedScenes = [UIApplication sharedApplication].connectedScenes;
            for (UIScene *scene in connectedScenes) {
                if ([scene isKindOfClass:[UIWindowScene class]]) {
                    UIWindowScene *windowScene = (UIWindowScene *)scene;
                    for (UIWindow *window in windowScene.windows) {
                        if (window.isKeyWindow && window.rootViewController) {
                            topVC = window.rootViewController;
                            break;
                        }
                    }
                    if (topVC) break;
                }
            }
        }
    }
    
    if (!topVC) {
        for (UIWindow *window in [UIApplication sharedApplication].windows) {
            if (!window.hidden && window.rootViewController) {
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

- (NSString *)getClassChainForView:(UIView *)view {
    if (!view) return @"(None)";
    
    NSMutableString *chain = [NSMutableString string];
    UIView *tempView = view;
    int depth = 0;
    
    while (tempView != nil && depth < 6) {
        if (chain.length > 0) {
            [chain appendString:@"\n     ↓ "];
        }
        [chain appendString:NSStringFromClass([tempView class])];
        tempView = tempView.superview;
        depth++;
    }
    
    return chain;
}

- (NSString *)extractTextFromView:(UIView *)view {
    if (!view) return nil;
    
    if ([view isKindOfClass:[UILabel class]]) {
        UILabel *label = (UILabel *)view;
        if (label.text.length > 0) return label.text;
    }
    
    if ([view isKindOfClass:[UITextField class]]) {
        UITextField *textField = (UITextField *)view;
        if (textField.text.length > 0) return textField.text;
        if (textField.placeholder.length > 0) {
            return [NSString stringWithFormat:@"Placeholder: %@", textField.placeholder];
        }
    }
    
    if ([view isKindOfClass:[UITextView class]]) {
        UITextView *textView = (UITextView *)view;
        if (textView.text.length > 0) return textView.text;
    }
    
    if ([view isKindOfClass:[UIButton class]]) {
        UIButton *button = (UIButton *)view;
        if (button.currentTitle.length > 0) return button.currentTitle;
        if (button.currentAttributedTitle.string.length > 0) return button.currentAttributedTitle.string;
        if (button.titleLabel.text.length > 0) return button.titleLabel.text;
    }
    
    if (view.accessibilityLabel.length > 0) {
        return view.accessibilityLabel;
    }
    
    if ([view respondsToSelector:@selector(text)] && [view performSelector:@selector(text)]) {
        id val = [view performSelector:@selector(text)];
        if ([val isKindOfClass:[NSString class]] && [val length] > 0) return val;
    }
    
    for (UIView *subview in view.subviews) {
        NSString *subText = [self extractTextFromView:subview];
        if (subText.length > 0) return subText;
    }
    
    return nil;
}

- (NSString *)getImageInfoForView:(UIView *)view {
    if (!view) return nil;
    
    if ([view isKindOfClass:[UIImageView class]]) {
        UIImageView *imgView = (UIImageView *)view;
        if (imgView.image) {
            NSMutableString *info = [NSMutableString string];
            [info appendFormat:@"Size: %.0fx%.0f", imgView.image.size.width, imgView.image.size.height];
            if (imgView.image.scale > 1) {
                [info appendFormat:@" @%.1fx", imgView.image.scale];
            }
            return info;
        }
    }
    
    if ([view isKindOfClass:[UIButton class]]) {
        UIButton *button = (UIButton *)view;
        if (button.currentImage) {
            return [NSString stringWithFormat:@"Image: %.0fx%.0f", button.currentImage.size.width, button.currentImage.size.height];
        }
    }
    
    return nil;
}

// نظام فحص ذكي بالكلمات المفتاحية لتغطية أي معرف عام مستقبلي تلقائياً
- (BOOL)isGeneralOrIgnoredIdentifier:(NSString *)identifier {
    if (identifier.length == 0) return YES;
    
    NSArray *ignoredKeywords = @[
        @"reel_overlay",
        @"elements.list_item",
        @"app.view",
        @"container",
        @"wrapper"
    ];
    
    for (NSString *keyword in ignoredKeywords) {
        if ([identifier containsString:keyword]) {
            return YES;
        }
    }
    return NO;
}

- (NSString *)findDeepChildIdentifierInView:(UIView *)view depth:(int)currentDepth {
    if (!view || currentDepth > 6) return nil;
    
    NSString *uID = view.accessibilityIdentifier;
    if (uID.length > 0 && ![self isGeneralOrIgnoredIdentifier:uID]) {
        return uID;
    }
    
    for (UIView *sub in view.subviews) {
        NSString *res = [self findDeepChildIdentifierInView:sub depth:currentDepth + 1];
        if (res.length > 0) return res;
    }
    
    return nil;
}

- (NSString *)extractIdentifierFromView:(UIView *)view {
    if (!view) return nil;
    
    NSString *childID = [self findDeepChildIdentifierInView:view depth:0];
    if (childID.length > 0) {
        return childID;
    }
    
    UIView *currentV = view;
    while (currentV != nil) {
        NSString *currID = currentV.accessibilityIdentifier;
        if (currID.length > 0 && ![self isGeneralOrIgnoredIdentifier:currID]) {
            return currID;
        }
        currentV = currentV.superview;
    }
    
    return nil;
}

- (NSString *)getAccessibilityInfoForView:(UIView *)view {
    if (!view) return nil;
    
    NSMutableString *info = [NSMutableString string];
    NSString *identifier = [self extractIdentifierFromView:view];
    NSString *label = view.accessibilityLabel;
    NSString *value = view.accessibilityValue;
    NSString *hint = view.accessibilityHint;
    
    if (identifier.length > 0) {
        [info appendFormat:@"ID: %@", identifier];
    }
    
    if (label.length > 0) {
        if (info.length > 0) [info appendString:@" | "];
        [info appendFormat:@"Label: %@", label];
    }
    
    if (value.length > 0) {
        if (info.length > 0) [info appendString:@" | "];
        [info appendFormat:@"Value: %@", value];
    }
    
    if (hint.length > 0) {
        if (info.length > 0) [info appendString:@" | "];
        [info appendFormat:@"Hint: %@", hint];
    }
    
    return info.length > 0 ? info : nil;
}

- (NSString *)getFrameInfoForView:(UIView *)view {
    if (!view) return nil;
    return [NSString stringWithFormat:@"Frame: (%.0f, %.0f, %.0f, %.0f) | Bounds: (%.0f, %.0f, %.0f, %.0f)",
            view.frame.origin.x, view.frame.origin.y, view.frame.size.width, view.frame.size.height,
            view.bounds.origin.x, view.bounds.origin.y, view.bounds.size.width, view.bounds.size.height];
}

- (NSString *)getAdditionalInfoForView:(UIView *)view {
    if (!view) return nil;
    NSMutableString *info = [NSMutableString string];
    [info appendFormat:@"Alpha: %.2f | Hidden: %@ | UserInteraction: %@",
     view.alpha, view.hidden ? @"Yes" : @"No", view.userInteractionEnabled ? @"Yes" : @"No"];
    
    if (view.tag != 0) {
        [info appendFormat:@" | Tag: %ld", (long)view.tag];
    }
    if (view.layer.cornerRadius > 0) {
        [info appendFormat:@" | Corner: %.1f", view.layer.cornerRadius];
    }
    return info;
}

- (void)handleLongPress:(UILongPressGestureRecognizer *)sender {
    if (sender.state != UIGestureRecognizerStateBegan) return;
    if (![sender.view isKindOfClass:[UIWindow class]]) return;
    
    UIWindow *window = (UIWindow *)sender.view;
    CGPoint point = [sender locationInView:window];
    
    UIView *targetView = [window hitTest:point withEvent:nil];
    if (!targetView) return;
    
    if ([self shouldIgnoreView:targetView]) return;
    
    NSString *classChain = [self getClassChainForView:targetView];
    NSString *accessibilityInfo = [self getAccessibilityInfoForView:targetView];
    NSString *extractedText = [self extractTextFromView:targetView];
    NSString *imageInfo = [self getImageInfoForView:targetView];
    NSString *frameInfo = [self getFrameInfoForView:targetView];
    NSString *additionalInfo = [self getAdditionalInfoForView:targetView];
    NSString *identifier = [self extractIdentifierFromView:targetView];
    
    NSMutableString *message = [NSMutableString string];
    
    [message appendFormat:@"🎯 Target Class: %@\n\n", NSStringFromClass([targetView class])];
    [message appendFormat:@"📊 Class Hierarchy:\n%@\n\n", classChain];
    
    if (identifier.length > 0) {
        [message appendFormat:@"🔑 ID: %@\n\n", identifier];
    } else if (accessibilityInfo.length > 0) {
        [message appendFormat:@"🔑 %@\n\n", accessibilityInfo];
    }
    
    [message appendFormat:@"📝 Text: %@\n\n", (extractedText.length > 0) ? extractedText : @"(None)"];
    
    if (imageInfo) {
        [message appendFormat:@"🖼️ %@\n\n", imageInfo];
    }
    
    [message appendFormat:@"📍 %@\n\n", frameInfo];
    [message appendFormat:@"⚙️ %@\n", additionalInfo];
    
    NSString *bestToCopy = identifier.length > 0 ? identifier : 
                          (extractedText.length > 0 ? extractedText : 
                           NSStringFromClass([targetView class]));
    
    UIAlertController *alert = [UIAlertController 
        alertControllerWithTitle:@"🔍 HPlus Inspector" 
        message:message 
        preferredStyle:UIAlertControllerStyleAlert];
    
    // خيار نسخ المعرف أو النص الأساسي
    [alert addAction:[UIAlertAction actionWithTitle:@"📋 Copy ID/Text" 
        style:UIAlertActionStyleDefault 
        handler:^(UIAlertAction * _Nonnull action) {
            [UIPasteboard generalPasteboard].string = bestToCopy;
        }]];
    
    // خيار جديد ومهم: نسخ سلسلة الـ Classes فقط لاستخدامها في بناء الـ Hooks
    [alert addAction:[UIAlertAction actionWithTitle:@"📊 Copy Hierarchy" 
        style:UIAlertActionStyleDefault 
        handler:^(UIAlertAction * _Nonnull action) {
            [UIPasteboard generalPasteboard].string = classChain;
        }]];
    
    // خيار نسخ كل المعلومات
    [alert addAction:[UIAlertAction actionWithTitle:@"📄 Copy All" 
        style:UIAlertActionStyleDefault 
        handler:^(UIAlertAction * _Nonnull action) {
            [UIPasteboard generalPasteboard].string = message;
        }]];
    
    [alert addAction:[UIAlertAction actionWithTitle:@"👌 OK" 
        style:UIAlertActionStyleCancel 
        handler:nil]];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        UIViewController *topVC = [self topViewController];
        
        if (topVC) {
            [topVC presentViewController:alert animated:YES completion:nil];
        } else {
            UIWindow *alertWindow = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
            alertWindow.rootViewController = [[UIViewController alloc] init];
            alertWindow.windowLevel = UIWindowLevelAlert + 1;
            alertWindow.backgroundColor = [UIColor clearColor];
            [alertWindow makeKeyAndVisible];
            
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), 
                          dispatch_get_main_queue(), ^{
                [alertWindow.rootViewController presentViewController:alert animated:YES completion:nil];
            });
        }
    });
}

@end

%ctor {
    [HPlusDebugHelper sharedInstance];
}
