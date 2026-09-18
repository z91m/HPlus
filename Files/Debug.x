#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <os/log.h> // 🟢 تم إضافة مكتبة السجلات الرسمية

// مفتاح فريد للـ Associated Object
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
- (UIView *)nearestLogicalElementForView:(UIView *)view maxDepth:(int)maxDepth;
- (BOOL)shouldIgnoreView:(UIView *)view;
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
    
    if ([view respondsToSelector:@selector(text)]) {
        id textValue = [view performSelector:@selector(text)];
        if ([textValue isKindOfClass:[NSString class]] && [(NSString *)textValue length] > 0) {
            return textValue;
        }
    }
    
    return nil;
}

- (NSString *)getImageInfoForView:(UIView *)view {
    if (!view) return nil;
    
    if ([view isKindOfClass:[UIImageView class]]) {
        UIImageView *imgView = (UIImageView *)view;
        if (imgView.image) {
            return [NSString stringWithFormat:@"Size: %.0fx%.0f", 
                    imgView.image.size.width, imgView.image.size.height];
        }
    }
    return nil;
}

- (UIView *)nearestLogicalElementForView:(UIView *)view maxDepth:(int)maxDepth {
    UIView *currentV = view;
    int depth = 0;
    UIView *lastValid = view;
    while (currentV != nil && depth < maxDepth) {
        if ([currentV isKindOfClass:[UIControl class]] ||
            [currentV isKindOfClass:[UITableViewCell class]] ||
            [currentV isKindOfClass:[UICollectionViewCell class]]) {
            return currentV;
        }
        lastValid = currentV;
        currentV = currentV.superview;
        depth++;
    }
    return lastValid;
}

- (NSString *)extractIdentifierFromView:(UIView *)view {
    if (!view) return nil;
    if (view.accessibilityIdentifier.length > 0) return view.accessibilityIdentifier;
    
    UIView *logicalElement = [self nearestLogicalElementForView:view maxDepth:4];
    if (logicalElement != view && logicalElement.accessibilityIdentifier.length > 0) {
        return logicalElement.accessibilityIdentifier;
    }
    return nil;
}

- (NSString *)getAccessibilityInfoForView:(UIView *)view {
    if (!view) return nil;
    NSMutableString *info = [NSMutableString string];
    
    NSString *identifier = view.accessibilityIdentifier;
    NSString *label = view.accessibilityLabel;
    
    if (!identifier.length || !label.length) {
        UIView *logicalElement = [self nearestLogicalElementForView:view maxDepth:4];
        if (logicalElement != view) {
            if (!identifier.length) identifier = logicalElement.accessibilityIdentifier;
            if (!label.length) label = logicalElement.accessibilityLabel;
        }
    }
    
    if (identifier.length > 0) [info appendFormat:@"ID: %@", identifier];
    if (label.length > 0) {
        if (info.length > 0) [info appendString:@" | "];
        [info appendFormat:@"Label: %@", label];
    }
    
    return info.length > 0 ? info : nil;
}

- (NSString *)getFrameInfoForView:(UIView *)view {
    if (!view) return nil;
    return [NSString stringWithFormat:@"Frame: (%.0f, %.0f, %.0f, %.0f)",
            view.frame.origin.x, view.frame.origin.y,
            view.frame.size.width, view.frame.size.height];
}

- (NSString *)getAdditionalInfoForView:(UIView *)view {
    if (!view) return nil;
    return [NSString stringWithFormat:@"Alpha: %.2f | Hidden: %@",
            view.alpha, view.hidden ? @"Yes" : @"No"];
}

- (void)handleLongPress:(UILongPressGestureRecognizer *)sender {
    if (sender.state != UIGestureRecognizerStateBegan) return;
    if (![sender.view isKindOfClass:[UIWindow class]]) return;
    
    UIWindow *window = (UIWindow *)sender.view;
    CGPoint point = [sender locationInView:window];
    
    UIView *hitView = [window hitTest:point withEvent:nil];
    if (!hitView) return;
    if ([self shouldIgnoreView:hitView]) return;
    
    UIView *targetView = [self nearestLogicalElementForView:hitView maxDepth:4];
    
    NSString *classChain = [self getClassChainForView:targetView];
    NSString *extractedText = [self extractTextFromView:targetView];
    NSString *frameInfo = [self getFrameInfoForView:targetView];
    NSString *identifier = [self extractIdentifierFromView:targetView];
    
    NSMutableString *message = [NSMutableString string];
    [message appendFormat:@"🎯 Target Class: %@\n\n", NSStringFromClass([targetView class])];
    [message appendFormat:@"📊 Class Hierarchy:\n%@\n\n", classChain];
    if (identifier.length > 0) [message appendFormat:@"🔑 ID: %@\n\n", identifier];
    [message appendFormat:@"📝 Text: %@\n\n", (extractedText.length > 0) ? extractedText : @"(None)"];
    [message appendFormat:@"📍 %@\n", frameInfo];
    
    NSString *bestToCopy = identifier.length > 0 ? identifier : 
                          (extractedText.length > 0 ? extractedText : 
                           NSStringFromClass([targetView class]));
    
    // 🟢 الحل الصحيح: طباعة السجل عبر os_log بصيغة public لكي يظهر في idevicesyslog بوضوح وبدون <private>
        os_log(OS_LOG_DEFAULT, "[HPlusInspector] %{public}s", [message UTF8String]);
    
    // إظهار النافذة المنبهة على الجوال
    UIAlertController *alert = [UIAlertController 
        alertControllerWithTitle:@"🔍 HPlus Inspector" 
        message:message 
        preferredStyle:UIAlertControllerStyleAlert];
    
    [alert addAction:[UIAlertAction actionWithTitle:@"📋 Copy Info" 
        style:UIAlertActionStyleDefault 
        handler:^(UIAlertAction * _Nonnull action) {
            [UIPasteboard generalPasteboard].string = bestToCopy;
        }]];
    
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
        }
    });
}

@end

%ctor {
    [HPlusDebugHelper sharedInstance];
}
