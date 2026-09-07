#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

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
- (BOOL)shouldIgnoreView:(UIView *)view;
@end

%hook UIWindow

- (void)makeKeyAndVisible {
    %orig;
    [[HPlusDebugHelper sharedInstance] setupGestureForWindow:self];
}

- (void)becomeKeyWindow {
    %orig;
    // تأخير قصير جداً مع فحص
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
    
    // تجاهل نوافذ النظام الحساسة فقط
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
    
    // تجاهل نوافذ النظام
    if ([self shouldIgnoreView:window]) return;
    
    NSString *windowClass = NSStringFromClass([window class]);
    if ([windowClass containsString:@"Alert"] || 
        [windowClass containsString:@"Keyboard"]) {
        return;
    }
    
    // فحص باستخدام Associated Object (أكثر أماناً وموثوقية)
    id existingGesture = objc_getAssociatedObject(window, &kHPlusGestureKey);
    if (existingGesture) return; // النافذة لديها الـ Gesture بالفعل
    
    // إنشاء Long Press Gesture
    UILongPressGestureRecognizer *longPress = 
        [[UILongPressGestureRecognizer alloc] 
         initWithTarget:self 
         action:@selector(handleLongPress:)];
    longPress.minimumPressDuration = 0.4; // مدة الضغط المطلوبة
    longPress.cancelsTouchesInView = NO; // لا يمنع التفاعل الطبيعي
    longPress.delaysTouchesBegan = NO;
    longPress.delaysTouchesEnded = NO;
    [window addGestureRecognizer:longPress];
    
    // حفظ المرجع لمنع التكرار
    objc_setAssociatedObject(window, &kHPlusGestureKey, longPress, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (UIViewController *)topViewController {
    UIViewController *topVC = nil;
    
    // البحث في جميع النوافذ عن النافذة الرئيسية
    for (UIWindow *window in [UIApplication sharedApplication].windows) {
        if (window.isKeyWindow && !window.hidden && window.rootViewController) {
            topVC = window.rootViewController;
            break;
        }
    }
    
    // إذا لم نجد، استخدم keyWindow
    if (!topVC) {
        UIWindow *keyWindow = [UIApplication sharedApplication].keyWindow;
        if (keyWindow && keyWindow.rootViewController) {
            topVC = keyWindow.rootViewController;
        }
    }
    
    if (!topVC) return nil;
    
    // الصعود لأعلى View Controller
    while (topVC.presentedViewController) {
        topVC = topVC.presentedViewController;
    }
    
    // إذا كان Navigation Controller
    if ([topVC isKindOfClass:[UINavigationController class]]) {
        topVC = [(UINavigationController *)topVC visibleViewController];
    }
    
    // إذا كان Tab Bar Controller
    if ([topVC isKindOfClass:[UITabBarController class]]) {
        topVC = [(UITabBarController *)topVC selectedViewController];
        if ([topVC isKindOfClass:[UINavigationController class]]) {
            topVC = [(UINavigationController *)topVC visibleViewController];
        }
    }
    
    // إذا كان Split View Controller
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
    
    // بناء سلسلة الوراثة حتى 6 مستويات
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
    
    // 1. UILabel - النصوص العادية
    if ([view isKindOfClass:[UILabel class]]) {
        UILabel *label = (UILabel *)view;
        if (label.text.length > 0) {
            return label.text;
        }
    }
    
    // 2. UITextField - حقول الإدخال
    if ([view isKindOfClass:[UITextField class]]) {
        UITextField *textField = (UITextField *)view;
        if (textField.text.length > 0) {
            return textField.text;
        }
        if (textField.placeholder.length > 0) {
            return [NSString stringWithFormat:@"Placeholder: %@", textField.placeholder];
        }
    }
    
    // 3. UITextView - النصوص الطويلة
    if ([view isKindOfClass:[UITextView class]]) {
        UITextView *textView = (UITextView *)view;
        if (textView.text.length > 0) {
            return textView.text;
        }
    }
    
    // 4. UIButton - الأزرار
    if ([view isKindOfClass:[UIButton class]]) {
        UIButton *button = (UIButton *)view;
        
        NSString *currentTitle = [button currentTitle];
        if (currentTitle.length > 0) {
            return currentTitle;
        }
        
        NSAttributedString *attributedTitle = [button currentAttributedTitle];
        if (attributedTitle.string.length > 0) {
            return attributedTitle.string;
        }
        
        if (button.titleLabel.text.length > 0) {
            return button.titleLabel.text;
        }
        
        NSString *normalTitle = [button titleForState:UIControlStateNormal];
        if (normalTitle.length > 0) {
            return normalTitle;
        }
        
        NSString *selectedTitle = [button titleForState:UIControlStateSelected];
        if (selectedTitle.length > 0) {
            return selectedTitle;
        }
    }
    
    // 5. UISegmentedControl - المؤشرات
    if ([view isKindOfClass:[UISegmentedControl class]]) {
        UISegmentedControl *segmented = (UISegmentedControl *)view;
        NSInteger selectedIndex = segmented.selectedSegmentIndex;
        if (selectedIndex >= 0 && selectedIndex < segmented.numberOfSegments) {
            NSString *title = [segmented titleForSegmentAtIndex:selectedIndex];
            if (title.length > 0) {
                return [NSString stringWithFormat:@"Segment [%ld]: %@", (long)selectedIndex, title];
            }
        }
    }
    
    // 6. UISwitch - المفاتيح
    if ([view isKindOfClass:[UISwitch class]]) {
        UISwitch *switchControl = (UISwitch *)view;
        return [NSString stringWithFormat:@"Switch: %@", switchControl.isOn ? @"ON" : @"OFF"];
    }
    
    // 7. UISlider - المنزلقات
    if ([view isKindOfClass:[UISlider class]]) {
        UISlider *slider = (UISlider *)view;
        return [NSString stringWithFormat:@"Slider: %.2f", slider.value];
    }
    
    // 8. UIProgressView - أشرطة التقدم
    if ([view isKindOfClass:[UIProgressView class]]) {
        UIProgressView *progress = (UIProgressView *)view;
        return [NSString stringWithFormat:@"Progress: %.2f", progress.progress];
    }
    
    // 9. UIStepper - عدادات
    if ([view isKindOfClass:[UIStepper class]]) {
        UIStepper *stepper = (UIStepper *)view;
        return [NSString stringWithFormat:@"Stepper: %.2f", stepper.value];
    }
    
    // 10. UITableViewCell - خلايا الجداول
    if ([view isKindOfClass:[UITableViewCell class]]) {
        UITableViewCell *cell = (UITableViewCell *)view;
        
        NSString *mainText = cell.textLabel.text;
        NSString *detailText = cell.detailTextLabel.text;
        
        if (mainText.length > 0 && detailText.length > 0) {
            return [NSString stringWithFormat:@"%@ - %@", mainText, detailText];
        } else if (mainText.length > 0) {
            return mainText;
        } else if (detailText.length > 0) {
            return detailText;
        }
    }
    
    // 11. UICollectionViewCell - خلايا المجموعات
    if ([view isKindOfClass:[UICollectionViewCell class]]) {
        UICollectionViewCell *cell = (UICollectionViewCell *)view;
        
        // البحث في contentView أولاً
        for (UIView *subview in cell.contentView.subviews) {
            NSString *subviewText = [self extractTextFromView:subview];
            if (subviewText.length > 0) {
                return subviewText;
            }
        }
        
        // ثم البحث في الخلية نفسها
        for (UIView *subview in cell.subviews) {
            if (subview != cell.contentView) {
                NSString *subviewText = [self extractTextFromView:subview];
                if (subviewText.length > 0) {
                    return subviewText;
                }
            }
        }
    }
    
    // 12. فحص عام لأي View يستجيب للـ text
    if ([view respondsToSelector:@selector(text)]) {
        id textValue = [view performSelector:@selector(text)];
        if ([textValue isKindOfClass:[NSString class]] && [(NSString *)textValue length] > 0) {
            return textValue;
        }
    }
    
    // 13. فحص attributedText
    if ([view respondsToSelector:@selector(attributedText)]) {
        id attributedText = [view performSelector:@selector(attributedText)];
        if ([attributedText respondsToSelector:@selector(string)]) {
            NSString *string = [attributedText performSelector:@selector(string)];
            if (string.length > 0) {
                return string;
            }
        }
    }
    
    // 14. فحص title
    if ([view respondsToSelector:@selector(title)]) {
        id titleValue = [view performSelector:@selector(title)];
        if ([titleValue isKindOfClass:[NSString class]] && [(NSString *)titleValue length] > 0) {
            return titleValue;
        }
    }
    
    // 15. فحص currentTitle
    if ([view respondsToSelector:@selector(currentTitle)]) {
        id currentTitle = [view performSelector:@selector(currentTitle)];
        if ([currentTitle isKindOfClass:[NSString class]] && [(NSString *)currentTitle length] > 0) {
            return currentTitle;
        }
    }
    
    return nil;
}

- (NSString *)getImageInfoForView:(UIView *)view {
    if (!view) return nil;
    
    // UIImageView - الصور
    if ([view isKindOfClass:[UIImageView class]]) {
        UIImageView *imgView = (UIImageView *)view;
        if (imgView.image) {
            NSMutableString *info = [NSMutableString string];
            [info appendFormat:@"Size: %.0fx%.0f", 
             imgView.image.size.width, 
             imgView.image.size.height];
            
            if (imgView.image.scale > 1) {
                [info appendFormat:@" @%.1fx", imgView.image.scale];
            }
            
            if (imgView.image.images.count > 1) {
                [info appendFormat:@" | Frames: %lu", 
                 (unsigned long)imgView.image.images.count];
            }
            
            return info;
        }
    }
    
    // UIButton مع صورة
    if ([view isKindOfClass:[UIButton class]]) {
        UIButton *button = (UIButton *)view;
        if (button.currentImage) {
            return [NSString stringWithFormat:@"Image: %.0fx%.0f", 
                    button.currentImage.size.width, 
                    button.currentImage.size.height];
        }
        if (button.currentBackgroundImage) {
            return [NSString stringWithFormat:@"Background: %.0fx%.0f", 
                    button.currentBackgroundImage.size.width, 
                    button.currentBackgroundImage.size.height];
        }
    }
    
    return nil;
}

- (NSString *)extractIdentifierFromView:(UIView *)view {
    if (!view) return nil;
    
    // البحث الصاعد عن accessibilityIdentifier
    UIView *currentV = view;
    while (currentV != nil) {
        if (currentV.accessibilityIdentifier.length > 0) {
            return currentV.accessibilityIdentifier;
        }
        currentV = currentV.superview;
    }
    return nil;
}

- (NSString *)getAccessibilityInfoForView:(UIView *)view {
    if (!view) return nil;
    
    NSMutableString *info = [NSMutableString string];
    
    // البحث الصاعد عن معلومات الوصول
    UIView *currentV = view;
    NSString *identifier = nil;
    NSString *label = nil;
    NSString *value = nil;
    NSString *hint = nil;
    
    while (currentV != nil) {
        if (!identifier && currentV.accessibilityIdentifier.length > 0) {
            identifier = currentV.accessibilityIdentifier;
        }
        if (!label && currentV.accessibilityLabel.length > 0) {
            label = currentV.accessibilityLabel;
        }
        if (!value && currentV.accessibilityValue.length > 0) {
            value = currentV.accessibilityValue;
        }
        if (!hint && currentV.accessibilityHint.length > 0) {
            hint = currentV.accessibilityHint;
        }
        currentV = currentV.superview;
    }
    
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
    
    // معلومات الإطار والحدود
    return [NSString stringWithFormat:@"Frame: (%.0f, %.0f, %.0f, %.0f) | Bounds: (%.0f, %.0f, %.0f, %.0f)",
            view.frame.origin.x,
            view.frame.origin.y,
            view.frame.size.width,
            view.frame.size.height,
            view.bounds.origin.x,
            view.bounds.origin.y,
            view.bounds.size.width,
            view.bounds.size.height];
}

- (NSString *)getAdditionalInfoForView:(UIView *)view {
    if (!view) return nil;
    
    NSMutableString *info = [NSMutableString string];
    
    // معلومات أساسية
    [info appendFormat:@"Alpha: %.2f | Hidden: %@ | UserInteraction: %@",
     view.alpha,
     view.hidden ? @"Yes" : @"No",
     view.userInteractionEnabled ? @"Yes" : @"No"];
    
    // Tag إذا وجد
    if (view.tag != 0) {
        [info appendFormat:@" | Tag: %ld", (long)view.tag];
    }
    
    // لون الخلفية (بطريقة آمنة)
    if (view.backgroundColor && 
        ![view.backgroundColor isEqual:[UIColor clearColor]]) {
        UIColor *color = view.backgroundColor;
        CGFloat red = 0, green = 0, blue = 0, alpha = 0;
        if ([color getRed:&red green:&green blue:&blue alpha:&alpha]) {
            [info appendFormat:@" | BG: RGB(%.0f, %.0f, %.0f)", 
             red * 255, green * 255, blue * 255];
        }
    }
    
    // Corner Radius إذا وجد
    if (view.layer.cornerRadius > 0) {
        [info appendFormat:@" | Corner: %.1f", view.layer.cornerRadius];
    }
    
    return info;
}

- (void)handleLongPress:(UILongPressGestureRecognizer *)sender {
    // التأكد من أن الضغطة في البداية فقط
    if (sender.state != UIGestureRecognizerStateBegan) return;
    
    // التأكد من أن الـ View هو UIWindow
    if (![sender.view isKindOfClass:[UIWindow class]]) return;
    
    UIWindow *window = (UIWindow *)sender.view;
    CGPoint point = [sender locationInView:window];
    
    // تحديد العنصر المضغوط عليه
    UIView *targetView = [window hitTest:point withEvent:nil];
    if (!targetView) return;
    
    // تجاهل عناصر النظام
    if ([self shouldIgnoreView:targetView]) return;
    
    // جمع كل المعلومات
    NSString *classChain = [self getClassChainForView:targetView];
    NSString *accessibilityInfo = [self getAccessibilityInfoForView:targetView];
    NSString *extractedText = [self extractTextFromView:targetView];
    NSString *imageInfo = [self getImageInfoForView:targetView];
    NSString *frameInfo = [self getFrameInfoForView:targetView];
    NSString *additionalInfo = [self getAdditionalInfoForView:targetView];
    NSString *identifier = [self extractIdentifierFromView:targetView];
    
    // بناء الرسالة
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
    
    // تحديد أفضل نص للنسخ
    NSString *bestToCopy = identifier.length > 0 ? identifier : 
                          (extractedText.length > 0 ? extractedText : 
                           NSStringFromClass([targetView class]));
    
    // إنشاء الـ Alert
    UIAlertController *alert = [UIAlertController 
        alertControllerWithTitle:@"🔍 HPlus Inspector" 
        message:message 
        preferredStyle:UIAlertControllerStyleAlert];
    
    // زر نسخ المعلومات الأساسية
    [alert addAction:[UIAlertAction actionWithTitle:@"📋 Copy Info" 
        style:UIAlertActionStyleDefault 
        handler:^(UIAlertAction * _Nonnull action) {
            [UIPasteboard generalPasteboard].string = bestToCopy;
        }]];
    
    // زر نسخ كل المعلومات
    [alert addAction:[UIAlertAction actionWithTitle:@"📄 Copy All" 
        style:UIAlertActionStyleDefault 
        handler:^(UIAlertAction * _Nonnull action) {
            [UIPasteboard generalPasteboard].string = message;
        }]];
    
    // زر الإغلاق
    [alert addAction:[UIAlertAction actionWithTitle:@"👌 OK" 
        style:UIAlertActionStyleCancel 
        handler:nil]];
    
    // عرض التنبيه بأمان
    dispatch_async(dispatch_get_main_queue(), ^{
        UIViewController *topVC = [self topViewController];
        
        if (topVC) {
            [topVC presentViewController:alert animated:YES completion:nil];
        } else {
            // Fallback: إنشاء نافذة جديدة
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