#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface HPlusDebugHelper : NSObject
+ (instancetype)sharedInstance;
- (void)handleLongPress:(UILongPressGestureRecognizer *)sender;
- (void)attachToView:(UIView *)view;
@end

%hook UIView

- (void)didMoveToWindow {
    %orig;
    [[HPlusDebugHelper sharedInstance] attachToView:self];
}

%end

%hook UIWindow

- (void)makeKeyAndVisible {
    %orig;
    [[HPlusDebugHelper sharedInstance] attachToView:self];
}

- (void)didAddSubview:(UIView *)subview {
    %orig;
    [[HPlusDebugHelper sharedInstance] attachToView:subview];
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

- (void)attachToView:(UIView *)view {
    if (!view) return;
    
    BOOL hasLongPress = NO;
    for (UIGestureRecognizer *recognizer in view.gestureRecognizers) {
        if ([recognizer isKindOfClass:[UILongPressGestureRecognizer class]]) {
            hasLongPress = YES;
            break;
        }
    }
    
    if (!hasLongPress) {
        UILongPressGestureRecognizer *longPress = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handleLongPress:)];
        longPress.minimumPressDuration = 0.4;
        [view addGestureRecognizer:longPress];
    }
}

- (void)handleLongPress:(UILongPressGestureRecognizer *)sender {
    if (sender.state == UIGestureRecognizerStateBegan) {
        UIView *containerView = sender.view;
        CGPoint point = [sender locationInView:containerView];
        
        UIView *targetView = [containerView hitTest:point withEvent:nil];
        if (!targetView) {
            targetView = containerView;
        }
        
        // تجميع الخصائص الشاملة
        NSMutableString *classChain = [NSMutableString string];
        UIView *tempView = targetView;
        int depth = 0;
        while (tempView != nil && depth < 4) {
            if (classChain.length >  0) {
                [classChain appendString:@" -> "];
            }
            [classChain appendString:NSStringFromClass([tempView class])];
            tempView = tempView.superview;
            depth++;
        }
        
        NSString *identifier = nil;
        NSString *accessibilityLabel = nil;
        NSString *extractedText = nil;
        NSString *imageInfo = nil;
        
        // البحث عن المعرف والـ Label الصاعد
        UIView *currentV = targetView;
        while (currentV != nil) {
            if (!identifier && currentV.accessibilityIdentifier.length > 0) {
                identifier = currentV.accessibilityIdentifier;
            }
            if (!accessibilityLabel && currentV.accessibilityLabel.length > 0) {
                accessibilityLabel = currentV.accessibilityLabel;
            }
            currentV = currentV.superview;
        }
        
        // استخراج النصوص (UILabel, UITextField, UITextView, الخ)
        if ([targetView respondsToSelector:@selector(text)] && [[(id)targetView text] isKindOfClass:[NSString class]]) {
            extractedText = [(id)targetView text];
        } else if ([targetView respondsToSelector:@selector(attributedText)] && [[(id)targetView attributedText] string]) {
            extractedText = [[(id)targetView attributedText] string];
        } else if ([targetView respondsToSelector:@selector(title)] && [[(id)targetView title] isKindOfClass:[NSString class]]) {
            extractedText = [(id)targetView title];
        }
        
        // فحص الصور أو الأيقونات (UIImageView)
        if ([targetView isKindOfClass:[UIImageView class]]) {
            UIImageView *imgView = (UIImageView *)targetView;
            if (imgView.image) {
                imageInfo = [NSString stringWithFormat:@"Size: %.0fx%.0f", imgView.image.size.width, imgView.image.size.height];
            }
        }
        
        // بناء رسالة التنبيه الشاملة
        NSMutableString *message = [NSMutableString string];
        [message appendFormat:@"Classes: %@\n\n", classChain];
        
        [message appendFormat:@"ID: %@\n", (identifier.length >  0) ? identifier : @"(None)"];
        [message appendFormat:@"Label: %@\n", (accessibilityLabel.length > 0) ? accessibilityLabel : @"(None)"];
        [message appendFormat:@"Text: %@\n", (extractedText.length > 0) ? extractedText : @"(None)"];
        
        if (imageInfo) {
            [message appendFormat:@"Image: %@\n", imageInfo];
        }
        
        // تحديد النص المناسب للنسخ التلقائي (الأولوية للمعرف ثم النص ثم الكلاس)
        NSString *bestToCopy = identifier.length > 0 ? identifier : (extractedText.length > 0 ? extractedText : (accessibilityLabel.length > 0 ? accessibilityLabel : NSStringFromClass([targetView class])));
        
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"HPlus Full Inspector" message:message preferredStyle:UIAlertControllerStyleAlert];
        
        [alert addAction:[UIAlertAction actionWithTitle:@"Copy Best Match" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            [UIPasteboard generalPasteboard].string = bestToCopy;
        }]];
        
        [alert addAction:[UIAlertAction actionWithTitle:@"Copy All Info" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            [UIPasteboard generalPasteboard].string = message;
        }]];
        
        [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:nil]];
        
        UIWindow *keyWindow = nil;
        for (UIWindow *window in [UIApplication sharedApplication].windows) {
            if (window.isKeyWindow) {
                keyWindow = window;
                break;
            }
        }
        [keyWindow.rootViewController presentViewController:alert animated:YES completion:nil];
    }
}

@end
