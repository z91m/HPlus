#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <os/log.h>
#import "Headers.h"
#import <Preferences/Preferences.h>
#import <AVFoundation/AVFoundation.h>
#import <CoreMedia/CoreMedia.h>

static char kHPlusTapGestureKey;
static char kHPlusLongPressGestureKey;

#pragma mark - Inspector Core

@interface HPlusInspector : NSObject
+ (instancetype)sharedInstance;
- (void)setupGesturesForWindow:(UIWindow *)window;
- (UIViewController *)topViewController;
- (NSString *)formattedReportForView:(UIView *)view;
- (NSString *)conciseReportForView:(UIView *)view;
- (NSString *)describeView:(UIView *)view;
- (NSString *)innerTextForView:(UIView *)view;
- (NSString *)bestIdentifierFromView:(UIView *)view;
@end

#pragma mark - Hook

%hook UIWindow

- (void)makeKeyAndVisible {
    %orig;
    [[HPlusInspector sharedInstance] setupGesturesForWindow:self];
}

- (void)becomeKeyWindow {
    %orig;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.05 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        [[HPlusInspector sharedInstance] setupGesturesForWindow:self];
    });
}

%end

#pragma mark - Implementation

@implementation HPlusInspector

+ (instancetype)sharedInstance {
    static HPlusInspector *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[HPlusInspector alloc] init];
    });
    return instance;
}

#pragma mark - Gesture Setup

- (void)setupGesturesForWindow:(UIWindow *)window {
    if (!window) return;
    
    // تجاهل النوافذ الخاصة بالتنبيهات والكيبورد
    NSString *windowClass = NSStringFromClass([window class]);
    if ([windowClass containsString:@"Alert"] ||
        [windowClass containsString:@"Keyboard"] ||
        [windowClass containsString:@"TextEffects"] ||
        [windowClass containsString:@"StatusBar"]) {
        return;
    }
    
    // ضغطة واحدة (Tap)
    if (!objc_getAssociatedObject(window, &kHPlusTapGestureKey)) {
        UITapGestureRecognizer *tap =
            [[UITapGestureRecognizer alloc] initWithTarget:self
                                                    action:@selector(handleTap:)];
        tap.cancelsTouchesInView = NO;
        tap.delaysTouchesBegan = NO;
        tap.delaysTouchesEnded = NO;
        tap.numberOfTapsRequired = 1;
        tap.numberOfTouchesRequired = 1;
        [window addGestureRecognizer:tap];
        objc_setAssociatedObject(window, &kHPlusTapGestureKey, tap,
                                 OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    
    // ضغطة مطولة (Long Press)
    if (!objc_getAssociatedObject(window, &kHPlusLongPressGestureKey)) {
        UILongPressGestureRecognizer *longPress =
            [[UILongPressGestureRecognizer alloc] initWithTarget:self
                                                          action:@selector(handleLongPress:)];
        longPress.minimumPressDuration = 0.5;
        longPress.cancelsTouchesInView = NO;
        longPress.delaysTouchesBegan = NO;
        longPress.delaysTouchesEnded = NO;
        [window addGestureRecognizer:longPress];
        objc_setAssociatedObject(window, &kHPlusLongPressGestureKey, longPress,
                                 OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
}

#pragma mark - Handlers

// ضغطة واحدة → طباعة فقط في الكونسول
- (void)handleTap:(UITapGestureRecognizer *)sender {
    if (sender.state != UIGestureRecognizerStateRecognized) return;
    if (![sender.view isKindOfClass:[UIWindow class]]) return;
    
    UIWindow *window = (UIWindow *)sender.view;
    CGPoint point = [sender locationInView:window];
    UIView *hitView = [window hitTest:point withEvent:nil];
    if (!hitView) return;
    
    NSString *report = [self conciseReportForView:hitView];
    os_log(OS_LOG_DEFAULT, "[HPlusInspector][TAP] %{public}@", report);
}

// ضغطة مطولة → عرض Alert بالمعلومات الكاملة + 5 أزرار نسخ
- (void)handleLongPress:(UILongPressGestureRecognizer *)sender {
    if (sender.state != UIGestureRecognizerStateBegan) return;
    if (![sender.view isKindOfClass:[UIWindow class]]) return;
    
    UIWindow *window = (UIWindow *)sender.view;
    CGPoint point = [sender locationInView:window];
    UIView *hitView = [window hitTest:point withEvent:nil];
    if (!hitView) return;
    
    NSString *report = [self formattedReportForView:hitView];
    
    // استخرج المعلومات المهمة للنسخ السريع
    NSString *bestID = [self bestIdentifierFromView:hitView];
    NSString *bestClass = NSStringFromClass([hitView class]);
    NSString *idOnly = bestID.length ? bestID : @"(no id)";
    NSString *classOnly = bestClass.length ? bestClass : @"(no class)";
    
    // اطبع نسخة في الكونسول أيضاً
    os_log(OS_LOG_DEFAULT, "[HPlusInspector][LONG] %{public}@", report);
    
    dispatch_async(dispatch_get_main_queue(), ^{
        UIViewController *topVC = [self topViewController];
        if (!topVC) return;
        
        UIAlertController *alert =
            [UIAlertController alertControllerWithTitle:@"🔍 HPlus Inspector"
                                                message:report
                                         preferredStyle:UIAlertControllerStyleAlert];
        
        // 1️⃣ نسخ الـ ID فقط
        [alert addAction:[UIAlertAction actionWithTitle:@"🔑 Copy ID Only"
                                                  style:UIAlertActionStyleDefault
                                                handler:^(UIAlertAction *action) {
            [UIPasteboard generalPasteboard].string = idOnly;
        }]];
        
        // 2️⃣ نسخ الكلاس فقط
        [alert addAction:[UIAlertAction actionWithTitle:@"🏷 Copy Class Only"
                                                  style:UIAlertActionStyleDefault
                                                handler:^(UIAlertAction *action) {
            [UIPasteboard generalPasteboard].string = classOnly;
        }]];
        
        // 3️⃣ نسخ الـ ID + الكلاس معاً
        [alert addAction:[UIAlertAction actionWithTitle:@"🔑🏷 Copy ID + Class"
                                                  style:UIAlertActionStyleDefault
                                                handler:^(UIAlertAction *action) {
            NSString *combined = [NSString stringWithFormat:@"%@ | %@", idOnly, classOnly];
            [UIPasteboard generalPasteboard].string = combined;
        }]];
        
        // 4️⃣ نسخ كل المعلومات
        [alert addAction:[UIAlertAction actionWithTitle:@"📋 Copy All"
                                                  style:UIAlertActionStyleDefault
                                                handler:^(UIAlertAction *action) {
            [UIPasteboard generalPasteboard].string = report;
        }]];
        
        // 5️⃣ إغلاق
        [alert addAction:[UIAlertAction actionWithTitle:@"👌 OK"
                                                  style:UIAlertActionStyleCancel
                                                handler:nil]];
        
        [topVC presentViewController:alert animated:YES completion:nil];
    });
}

#pragma mark - Top ViewController

- (UIViewController *)topViewController {
    UIViewController *topVC = nil;
    
    if (@available(iOS 13.0, *)) {
        for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
            if (![scene isKindOfClass:[UIWindowScene class]]) continue;
            if (scene.activationState != UISceneActivationStateForegroundActive) continue;
            UIWindowScene *ws = (UIWindowScene *)scene;
            for (UIWindow *w in ws.windows) {
                if (w.isKeyWindow && w.rootViewController) {
                    topVC = w.rootViewController;
                    break;
                }
            }
            if (topVC) break;
        }
    }
    
    if (!topVC) {
        for (UIWindow *w in [UIApplication sharedApplication].windows) {
            if (w.isKeyWindow && w.rootViewController) {
                topVC = w.rootViewController;
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
        topVC = [(UISplitViewController *)topVC viewControllers].lastObject;
        if ([topVC isKindOfClass:[UINavigationController class]]) {
            topVC = [(UINavigationController *)topVC visibleViewController];
        }
    }
    return topVC;
}

#pragma mark - View Description

// وصف مختصر لعنصر واحد
- (NSString *)describeView:(UIView *)view {
    if (!view) return @"(nil)";
    
    NSMutableString *s = [NSMutableString string];
    [s appendFormat:@"%@", NSStringFromClass([view class])];
    
    NSString *ident = view.accessibilityIdentifier;
    NSString *label = view.accessibilityLabel;
    NSString *value = nil;
    if ([view respondsToSelector:@selector(accessibilityValue)]) {
        id v = [view accessibilityValue];
        if ([v isKindOfClass:[NSString class]] && [v length] > 0) value = v;
    }
    
    if (ident.length)  [s appendFormat:@" | id=%@", ident];
    if (label.length)  [s appendFormat:@" | label=%@", label];
    if (value.length)  [s appendFormat:@" | value=%@", value];
    
    NSString *innerText = [self innerTextForView:view];
    if (innerText.length) [s appendFormat:@" | text=%@", innerText];
    
    return s;
}

// يبحث عن نص داخل العنصر أو أبنائه
- (NSString *)innerTextForView:(UIView *)view {
    if (!view) return nil;
    
    if ([view isKindOfClass:[UILabel class]]) {
        NSString *t = ((UILabel *)view).text;
        return t.length ? t : nil;
    }
    if ([view isKindOfClass:[UITextField class]]) {
        UITextField *tf = (UITextField *)view;
        if (tf.text.length) return tf.text;
        if (tf.placeholder.length) return tf.placeholder;
        return nil;
    }
    if ([view isKindOfClass:[UITextView class]]) {
        NSString *t = ((UITextView *)view).text;
        return t.length ? t : nil;
    }
    if ([view isKindOfClass:[UIButton class]]) {
        UIButton *b = (UIButton *)view;
        if (b.currentTitle.length) return b.currentTitle;
        if (b.titleLabel.text.length) return b.titleLabel.text;
    }
    
    if ([view respondsToSelector:NSSelectorFromString(@"text")]) {
        @try {
            id t = [view performSelector:NSSelectorFromString(@"text")];
            if ([t isKindOfClass:[NSString class]] && [(NSString *)t length]) return t;
        } @catch (__unused NSException *e) {}
    }
    
    for (UIView *sub in view.subviews) {
        NSString *t = [self innerTextForView:sub];
        if (t.length) return t;
    }
    return nil;
}

#pragma mark - Concise Report (Tap)

- (NSString *)conciseReportForView:(UIView *)view {
    NSMutableString *s = [NSMutableString string];
    [s appendFormat:@"\n=== TAP @ %@ ===\n", [NSDate date]];
    [s appendString:@"📍 Hit chain (from deepest to topmost):\n"];
    
    UIView *v = view;
    int depth = 0;
    while (v && depth < 20) {
        [s appendFormat:@"  [%d] %@ | frame=(%.0f,%.0f,%.0f,%.0f) | alpha=%.2f hidden=%@\n",
            depth,
            [self describeView:v],
            v.frame.origin.x, v.frame.origin.y,
            v.frame.size.width, v.frame.size.height,
            v.alpha,
            v.hidden ? @"YES" : @"NO"];
        v = v.superview;
        depth++;
    }
    
    NSString *bestID = [self bestIdentifierFromView:view];
    [s appendFormat:@"🎯 Best ID: %@\n", bestID.length ? bestID : @"(none)"];
    [s appendFormat:@"🏷 Best Class: %@\n", NSStringFromClass([view class])];
    
    return s;
}

#pragma mark - Best ID extraction

- (NSString *)bestIdentifierFromView:(UIView *)view {
    if (!view) return nil;
    
    if (view.accessibilityIdentifier.length) return view.accessibilityIdentifier;
    
    for (UIView *sub in view.subviews) {
        NSString *id_ = [self bestIdentifierFromView:sub];
        if (id_.length) return id_;
    }
    
    UIView *parent = view.superview;
    int depth = 0;
    while (parent && depth < 6) {
        if (parent.accessibilityIdentifier.length) return parent.accessibilityIdentifier;
        parent = parent.superview;
        depth++;
    }
    
    NSString *text = [self innerTextForView:view];
    if (text.length) return text;
    
    return nil;
}

#pragma mark - Full Report (Long Press)

- (NSString *)formattedReportForView:(UIView *)view {
    NSMutableString *s = [NSMutableString string];
    [s appendString:@"🎯 ===== HPlus Inspector =====\n\n"];
    
    // 1. العنصر المضغوط
    [s appendString:@"📍 Tapped view:\n"];
    [s appendFormat:@"  Class: %@\n", NSStringFromClass([view class])];
    [s appendFormat:@"  Frame: (%.0f, %.0f, %.0f, %.0f)\n",
        view.frame.origin.x, view.frame.origin.y,
        view.frame.size.width, view.frame.size.height];
    [s appendFormat:@"  Alpha: %.2f | Hidden: %@ | Opaque: %@\n",
        view.alpha, view.hidden ? @"YES" : @"NO", view.isOpaque ? @"YES" : @"NO"];
    
    // 2. Accessibility
    [s appendString:@"\n♿️ Accessibility:\n"];
    [s appendFormat:@"  Identifier: %@\n",
        view.accessibilityIdentifier.length ? view.accessibilityIdentifier : @"(none)"];
    [s appendFormat:@"  Label: %@\n",
        view.accessibilityLabel.length ? view.accessibilityLabel : @"(none)"];
    if ([view respondsToSelector:@selector(accessibilityValue)]) {
        id v = [view accessibilityValue];
        [s appendFormat:@"  Value: %@\n", v ?: @"(none)"];
    }
    if ([view respondsToSelector:@selector(accessibilityHint)]) {
        id h = [view accessibilityHint];
        [s appendFormat:@"  Hint: %@\n", h ?: @"(none)"];
    }
    [s appendFormat:@"  isAccessibilityElement: %@\n",
        view.isAccessibilityElement ? @"YES" : @"NO"];
    
    // 3. Text
    NSString *text = [self innerTextForView:view];
    if (text.length) {
        [s appendFormat:@"\n📝 Text: %@\n", text];
    }
    
    // 4. Image info
    if ([view isKindOfClass:[UIImageView class]]) {
        UIImage *img = ((UIImageView *)view).image;
        if (img) {
            [s appendFormat:@"\n🖼 Image: %.0fx%.0f\n", img.size.width, img.size.height];
        }
    }
    
    // 5. Hierarchy
    [s appendString:@"\n📊 Class hierarchy (deep → top):\n"];
    UIView *v = view;
    int depth = 0;
    while (v && depth < 15) {
        [s appendFormat:@"  %@%@\n",
            [@"" stringByPaddingToLength:depth * 2 withString:@" " startingAtIndex:0],
            [self describeView:v]];
        v = v.superview;
        depth++;
    }
    
    // 6. Runtime info
    [s appendString:@"\n⚙️ Runtime info:\n"];
    [s appendFormat:@"  Best ID: %@\n", [self bestIdentifierFromView:view] ?: @"(none)"];
    
    // 7. Subviews
    if (view.subviews.count > 0) {
        [s appendFormat:@"\n👶 Subviews (%lu):\n", (unsigned long)view.subviews.count];
        int i = 0;
        for (UIView *sub in view.subviews) {
            if (i >= 8) {
                [s appendFormat:@"  ... +%lu more\n",
                    (unsigned long)(view.subviews.count - i)];
                break;
            }
            [s appendFormat:@"  [%d] %@\n", i, [self describeView:sub]];
            i++;
        }
    }
    
    // 8. Responder chain
    [s appendString:@"\n🔗 Responder chain:\n"];
    UIResponder *r = view;
    int rc = 0;
    while (r && rc < 8) {
        [s appendFormat:@"  %@%@\n",
            [@"" stringByPaddingToLength:rc * 2 withString:@" " startingAtIndex:0],
            NSStringFromClass([r class])];
        r = r.nextResponder;
        rc++;
    }
    
    [s appendString:@"\n============================="];
    return s;
}

@end

#pragma mark - Constructor

%ctor {
    [HPlusInspector sharedInstance];
}}
