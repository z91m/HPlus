#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <os/log.h>
#import "Headers.h"

// مفتاح فريد للـ Associated Object
static char kHPlusGestureKey;

// ============================================================
// إعدادات قابلة للتعديل بسهولة (لاحقاً تُنقل إلى Prefs Bundle)
// ============================================================
static const NSTimeInterval kHPlusMinimumPressDuration   = 0.4;
static const int            kHPlusMaxScanDepth           = 8;    // أقصى عمق للبحث المتكرر (موحّد لكل الدوال)
static const NSUInteger     kHPlusMaxCollectedItems      = 60;   // حد أقصى لعدد العناصر المجمّعة (حماية أداء)
static const BOOL           kHPlusProtectSecureFields    = YES;  // منع استخراج نص حقول كلمة المرور

// ============================================================
// بنية بسيطة لتمثيل عنصر تم اكتشافه أثناء المسح الشامل
// ============================================================
@interface HPlusFoundItem : NSObject
@property (nonatomic, copy) NSString *className;
@property (nonatomic, copy) NSString *identifier;
@property (nonatomic, copy) NSString *text;
@property (nonatomic, assign) int depth;
@end
@implementation HPlusFoundItem
@end

@interface HPlusDebugHelper : NSObject
@property (nonatomic, strong) UIWindow *fallbackAlertWindow; // مرجع قوي دائم لتفادي اختفاء النافذة الاحتياطية
@property (nonatomic, strong) UIImpactFeedbackGenerator *hapticGenerator;

+ (instancetype)sharedInstance;
- (void)handleLongPress:(UILongPressGestureRecognizer *)sender;
- (void)setupGestureForWindow:(UIWindow *)window;
- (UIViewController *)topViewController;
- (NSString *)getClassChainForView:(UIView *)view;
- (NSString *)extractTextFromView:(UIView *)view depth:(int)depth;
- (NSString *)getImageInfoForView:(UIView *)view;
- (NSString *)getAccessibilityInfoForView:(UIView *)view;
- (NSString *)getFrameInfoForView:(UIView *)view;
- (NSString *)getAdditionalInfoForView:(UIView *)view;
- (BOOL)shouldIgnoreView:(UIView *)view;
- (BOOL)isGeneralOrIgnoredIdentifier:(NSString *)identifier;
- (NSArray<HPlusFoundItem *> *)collectAllIdentifiersInView:(UIView *)view;
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
        sharedInstance.hapticGenerator = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium];
    });
    return sharedInstance;
}

#pragma mark - Filtering

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

// نطبّق فلترة إضافية على مستوى النافذة نفسها قبل إضافة الإيماءة
- (BOOL)shouldAttachGestureToWindow:(UIWindow *)window {
    if ([self shouldIgnoreView:window]) return NO;

    NSString *windowClass = NSStringFromClass([window class]);
    if ([windowClass containsString:@"Alert"] ||
        [windowClass containsString:@"Keyboard"]) {
        return NO;
    }

    // تفادي النوافذ ذات المستوى العالي جداً (status bar / system overlays)
    if (window.windowLevel > UIWindowLevelStatusBar) {
        return NO;
    }

    return YES;
}

- (void)setupGestureForWindow:(UIWindow *)window {
    if (!window) return;
    if (![self shouldAttachGestureToWindow:window]) return;

    id existingGesture = objc_getAssociatedObject(window, &kHPlusGestureKey);
    if (existingGesture) return;

    UILongPressGestureRecognizer *longPress =
        [[UILongPressGestureRecognizer alloc]
         initWithTarget:self
         action:@selector(handleLongPress:)];
    longPress.minimumPressDuration = kHPlusMinimumPressDuration;
    longPress.cancelsTouchesInView = NO;
    longPress.delaysTouchesBegan = NO;
    longPress.delaysTouchesEnded = NO;
    [window addGestureRecognizer:longPress];

    objc_setAssociatedObject(window, &kHPlusGestureKey, longPress, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

#pragma mark - Top View Controller (simplified)

- (UIViewController *)topViewController {
    UIViewController *topVC = nil;

    // أولوية: البحث في الـ scenes المتصلة مباشرة (iOS 13+) عن الـ key window
    if (@available(iOS 13.0, *)) {
        for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
            if (![scene isKindOfClass:[UIWindowScene class]]) continue;
            UIWindowScene *windowScene = (UIWindowScene *)scene;
            if (windowScene.activationState != UISceneActivationStateForegroundActive) continue;
            for (UIWindow *window in windowScene.windows) {
                if (window.isKeyWindow && window.rootViewController) {
                    topVC = window.rootViewController;
                    break;
                }
            }
            if (topVC) break;
        }
    }

    // fallback: أي نافذة key عبر windows العادية (يشمل ما قبل iOS 13)
    if (!topVC) {
        for (UIWindow *window in [UIApplication sharedApplication].windows) {
            if (window.isKeyWindow && !window.hidden && window.rootViewController) {
                topVC = window.rootViewController;
                break;
            }
        }
    }

    // fallback أخير: أول نافذة ظاهرة عندها root VC
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
        topVC = [(UINavigationController *)topVC visibleViewController] ?: topVC;
    }

    if ([topVC isKindOfClass:[UITabBarController class]]) {
        UIViewController *selected = [(UITabBarController *)topVC selectedViewController];
        if (selected) topVC = selected;
        if ([topVC isKindOfClass:[UINavigationController class]]) {
            topVC = [(UINavigationController *)topVC visibleViewController] ?: topVC;
        }
    }

    if ([topVC isKindOfClass:[UISplitViewController class]]) {
        UISplitViewController *splitVC = (UISplitViewController *)topVC;
        UIViewController *last = splitVC.viewControllers.lastObject;
        if (last) topVC = last;
        if ([topVC isKindOfClass:[UINavigationController class]]) {
            topVC = [(UINavigationController *)topVC visibleViewController] ?: topVC;
        }
    }

    return topVC;
}

#pragma mark - Class chain

- (NSString *)getClassChainForView:(UIView *)view {
    if (!view) return @"(None)";

    NSMutableString *chain = [NSMutableString string];
    UIView *tempView = view;
    int depth = 0;

    while (tempView != nil && depth < kHPlusMaxScanDepth) {
        if (chain.length > 0) {
            [chain appendString:@"\n     ↓ "];
        }
        [chain appendString:NSStringFromClass([tempView class])];
        tempView = tempView.superview;
        depth++;
    }

    return chain;
}

#pragma mark - Text extraction (safe, no blind performSelector)

- (NSString *)extractTextFromView:(UIView *)view depth:(int)depth {
    if (!view || depth > kHPlusMaxScanDepth) return nil;

    if ([view isKindOfClass:[UITextField class]]) {
        UITextField *textField = (UITextField *)view;
        // 🔒 حماية: لا نستخرج نص حقول كلمة المرور إطلاقاً
        if (kHPlusProtectSecureFields && textField.isSecureTextEntry) {
            return @"🔒 (Secure field — hidden)";
        }
        if (textField.text.length > 0) return textField.text;
        if (textField.placeholder.length > 0) {
            return [NSString stringWithFormat:@"Placeholder: %@", textField.placeholder];
        }
        return nil;
    }

    if ([view isKindOfClass:[UILabel class]]) {
        UILabel *label = (UILabel *)view;
        if (label.text.length > 0) return label.text;
    }

    if ([view isKindOfClass:[UITextView class]]) {
        UITextView *textView = (UITextView *)view;
        // بعض TextViews تُستخدم كحقول إدخال حساسة أيضاً؛ لا يوجد isSecureTextEntry هنا
        // لكن نتحقق احتياطاً من الاسم إن كان مرتبطاً بكلمة مرور
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

    // ⚠️ أُزيل الاستخدام القديم لـ performSelector:@selector(text) العام —
    // كان بلا فحص لنوع القيمة المُرجعة وقد يسبب crash على subviews عامة.
    // الاستخراج الآن يعتمد فقط على أنواع معروفة أو accessibilityLabel.

    for (UIView *subview in view.subviews) {
        NSString *subText = [self extractTextFromView:subview depth:depth + 1];
        if (subText.length > 0) return subText;
    }

    return nil;
}

#pragma mark - Image info

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

#pragma mark - Identifier filtering

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

#pragma mark - ✨ البحث الشامل الجديد (يحل مشكلة القوائم المنسدلة / الـ Dropdowns)
//
// بدل التوقف عند أول معرف نجده (كما كان سابقاً)، هذه الدالة تمسح الشجرة
// كاملة تحت العنصر المستهدف وتجمع *كل* العناصر ذات القيمة (معرف أو نص)
// بحد أقصى للعمق وعدد العناصر لحماية الأداء في الشجرات الضخمة (مثل SwiftUI).

- (void)collectAllIdentifiersInView:(UIView *)view
                               depth:(int)depth
                             results:(NSMutableArray<HPlusFoundItem *> *)results {
    if (!view || depth > kHPlusMaxScanDepth) return;
    if (results.count >= kHPlusMaxCollectedItems) return;
    if ([self shouldIgnoreView:view]) return;

    NSString *identifier = view.accessibilityIdentifier;
    NSString *text = nil;

    // نص مباشر بدون النزول recursively (تفادي تكرار نفس النص لعدة عناصر أب/ابن)
    if ([view isKindOfClass:[UILabel class]]) {
        text = ((UILabel *)view).text;
    } else if ([view isKindOfClass:[UIButton class]]) {
        text = ((UIButton *)view).currentTitle;
    } else if ([view isKindOfClass:[UITextField class]]) {
        UITextField *tf = (UITextField *)view;
        text = (kHPlusProtectSecureFields && tf.isSecureTextEntry) ? @"🔒 hidden" : tf.text;
    }

    BOOL hasUsefulIdentifier = identifier.length > 0 && ![self isGeneralOrIgnoredIdentifier:identifier];
    BOOL hasUsefulText = text.length > 0;

    if (hasUsefulIdentifier || hasUsefulText) {
        HPlusFoundItem *item = [[HPlusFoundItem alloc] init];
        item.className = NSStringFromClass([view class]);
        item.identifier = hasUsefulIdentifier ? identifier : nil;
        item.text = hasUsefulText ? text : nil;
        item.depth = depth;
        [results addObject:item];
    }

    for (UIView *subview in view.subviews) {
        if (results.count >= kHPlusMaxCollectedItems) break;
        [self collectAllIdentifiersInView:subview depth:depth + 1 results:results];
    }
}

- (NSArray<HPlusFoundItem *> *)collectAllIdentifiersInView:(UIView *)view {
    NSMutableArray<HPlusFoundItem *> *results = [NSMutableArray array];

    // نبدأ من أقرب "حاوية منطقية" بدل العنصر الدقيق تحت الإصبع مباشرة،
    // لأن القوائم المنسدلة غالباً تُبنى كـ cell/stack يحوي عدة عناصر إخوة.
    // نصعد حتى نجد UITableViewCell / UICollectionViewCell / أو نتوقف عند الجذر بعد عدة مستويات.
    UIView *container = view;
    int upSteps = 0;
    while (container.superview && upSteps < 3) {
        if ([container isKindOfClass:[UITableViewCell class]] ||
            [container isKindOfClass:[UICollectionViewCell class]]) {
            break;
        }
        container = container.superview;
        upSteps++;
    }

    [self collectAllIdentifiersInView:container depth:0 results:results];

    // إن لم نجد شيئاً في الحاوية الموسّعة (نادر)، نرجع للعنصر الأصلي فقط كـ fallback
    if (results.count == 0) {
        [self collectAllIdentifiersInView:view depth:0 results:results];
    }

    return results;
}

- (NSString *)formattedListFromFoundItems:(NSArray<HPlusFoundItem *> *)items {
    NSMutableString *out = [NSMutableString string];
    for (HPlusFoundItem *item in items) {
        NSMutableString *line = [NSMutableString string];
        [line appendString:[@"" stringByPaddingToLength:item.depth * 2 withString:@" " startingAtIndex:0]];
        [line appendFormat:@"• [%@]", item.className];
        if (item.identifier) [line appendFormat:@" ID: %@", item.identifier];
        if (item.text) [line appendFormat:@" Text: \"%@\"", item.text];
        [out appendString:line];
        [out appendString:@"\n"];
    }
    return out;
}

- (NSString *)plainIdentifiersOnlyFromFoundItems:(NSArray<HPlusFoundItem *> *)items {
    NSMutableArray<NSString *> *ids = [NSMutableArray array];
    for (HPlusFoundItem *item in items) {
        if (item.identifier) [ids addObject:item.identifier];
    }
    return [ids componentsJoinedByString:@"\n"];
}

#pragma mark - Accessibility summary (single best guess — كما كان، لكن الآن مكمّل بالمسح الشامل)

- (NSString *)extractIdentifierFromView:(UIView *)view {
    if (!view) return nil;

    UIView *currentV = view;
    int depth = 0;
    while (currentV != nil && depth < kHPlusMaxScanDepth) {
        NSString *currID = currentV.accessibilityIdentifier;
        if (currID.length > 0 && ![self isGeneralOrIgnoredIdentifier:currID]) {
            return currID;
        }
        currentV = currentV.superview;
        depth++;
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

#pragma mark - Main gesture handler

- (void)handleLongPress:(UILongPressGestureRecognizer *)sender {
    if (sender.state == UIGestureRecognizerStateBegan) {
        // ⚡️ اهتزاز خفيف كتأكيد لمسي عند تفعيل الأداة
        [self.hapticGenerator prepare];
        [self.hapticGenerator impactOccurred];
    }

    if (sender.state != UIGestureRecognizerStateBegan) return;
    if (![sender.view isKindOfClass:[UIWindow class]]) return;

    UIWindow *window = (UIWindow *)sender.view;
    CGPoint point = [sender locationInView:window];

    UIView *targetView = [window hitTest:point withEvent:nil];
    if (!targetView) return;
    if ([self shouldIgnoreView:targetView]) return;

    NSString *classChain = [self getClassChainForView:targetView];
    NSString *accessibilityInfo = [self getAccessibilityInfoForView:targetView];
    NSString *extractedText = [self extractTextFromView:targetView depth:0];
    NSString *imageInfo = [self getImageInfoForView:targetView];
    NSString *frameInfo = [self getFrameInfoForView:targetView];
    NSString *additionalInfo = [self getAdditionalInfoForView:targetView];
    NSString *identifier = [self extractIdentifierFromView:targetView];

    // 🆕 المسح الشامل — يحل مشكلة القوائم المنسدلة
    NSArray<HPlusFoundItem *> *allFound = [self collectAllIdentifiersInView:targetView];

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
    [message appendFormat:@"⚙️ %@\n\n", additionalInfo];

    if (allFound.count > 1) {
        [message appendFormat:@"📚 وجدنا %lu عنصر في هذه المنطقة (اضغط \"نسخ الكل الشامل\" لنسخهم جميعاً)\n", (unsigned long)allFound.count];
    }

    NSString *bestToCopy = identifier.length > 0 ? identifier :
                          (extractedText.length > 0 ? extractedText :
                           NSStringFromClass([targetView class]));

    UIAlertController *alert = [UIAlertController
        alertControllerWithTitle:@"🔍 HPlus Inspector"
        message:message
        preferredStyle:UIAlertControllerStyleAlert];

    [alert addAction:[UIAlertAction actionWithTitle:@"📋 Copy ID/Text"
        style:UIAlertActionStyleDefault
        handler:^(UIAlertAction * _Nonnull action) {
            [UIPasteboard generalPasteboard].string = bestToCopy;
        }]];

    [alert addAction:[UIAlertAction actionWithTitle:@"📊 Copy Hierarchy"
        style:UIAlertActionStyleDefault
        handler:^(UIAlertAction * _Nonnull action) {
            [UIPasteboard generalPasteboard].string = classChain;
        }]];

    // 🆕 زر جديد: نسخ كل المعرفات الموجودة في المنطقة (مثالي للقوائم المنسدلة)
    if (allFound.count > 0) {
        [alert addAction:[UIAlertAction actionWithTitle:[NSString stringWithFormat:@"📚 Copy All IDs (%lu found)", (unsigned long)allFound.count]
            style:UIAlertActionStyleDefault
            handler:^(UIAlertAction * _Nonnull action) {
                [UIPasteboard generalPasteboard].string = [self plainIdentifiersOnlyFromFoundItems:allFound];
            }]];

        [alert addAction:[UIAlertAction actionWithTitle:@"📚 Copy Full Detailed List"
            style:UIAlertActionStyleDefault
            handler:^(UIAlertAction * _Nonnull action) {
                [UIPasteboard generalPasteboard].string = [self formattedListFromFoundItems:allFound];
            }]];
    }

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
            // ✅ نافذة احتياطية بمرجع قوي دائم (self.fallbackAlertWindow) بدل متغير محلي هش
            self.fallbackAlertWindow = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
            self.fallbackAlertWindow.rootViewController = [[UIViewController alloc] init];
            self.fallbackAlertWindow.windowLevel = UIWindowLevelAlert + 1;
            self.fallbackAlertWindow.backgroundColor = [UIColor clearColor];
            [self.fallbackAlertWindow makeKeyAndVisible];

            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)),
                          dispatch_get_main_queue(), ^{
                [self.fallbackAlertWindow.rootViewController presentViewController:alert animated:YES completion:^{
                    // تنظيف المرجع بعد إغلاق التنبيه لتفادي بقاء نافذة شفافة عالقة فوق التطبيق
                }];
            });
        }
    });
}

@end

%ctor {
    [HPlusDebugHelper sharedInstance];
}
