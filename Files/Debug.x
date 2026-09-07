#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface HPlusDebugHelper : NSObject
+ (instancetype)sharedInstance;
- (void)handleLongPress:(UILongPressGestureRecognizer *)sender;
@end

%hook UIView

- (void)didMoveToWindow {
    %orig;
    BOOL hasLongPress = NO;
    for (UIGestureRecognizer *recognizer in self.gestureRecognizers) {
        if ([recognizer isKindOfClass:[UILongPressGestureRecognizer class]]) {
            hasLongPress = YES;
            break;
        }
    }
    
    if (!hasLongPress) {
        UILongPressGestureRecognizer *longPress = [[UILongPressGestureRecognizer alloc] initWithTarget:[HPlusDebugHelper sharedInstance] action:@selector(handleLongPress:)];
        [self addGestureRecognizer:longPress];
    }
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

- (void)handleLongPress:(UILongPressGestureRecognizer *)sender {
    if (sender.state == UIGestureRecognizerStateBegan) {
        UIView *containerView = sender.view;
        CGPoint point = [sender locationInView:containerView];
        
        // استخدام Hit-Testing للعثور على أصغر وأدق عنصر تحته الإصبع مباشرة
        UIView *targetView = [containerView hitTest:point withEvent:nil];
        if (!targetView) {
            targetView = containerView;
        }
        
        NSString *className = NSStringFromClass([targetView class]);
        NSString *identifier = targetView.accessibilityIdentifier;
        NSString *extractedText = nil;
        
        // استخراج النص إذا كان العنصر يحتوي على نص (مثل UILabel أو زر نصي)
        if ([targetView respondsToSelector:@selector(text)] && [[(id)targetView text] isKindOfClass:[NSString class]]) {
            extractedText = [(id)targetView text];
        } else if ([targetView respondsToSelector:@selector(attributedText)] && [[(id)targetView attributedText] string]) {
            extractedText = [[(id)targetView attributedText] string];
        }
        
        // تجهيز بيانات العرض في التنبيه
        NSMutableString *message = [NSMutableString stringWithFormat:@"Class: %@\n", className];
        if (identifier && identifier.length > 0) {
            [message appendFormat:@"ID: %@\n", identifier];
        } else {
            [message appendString:@"ID: (None/Dynamic)\n"];
        }
        
        if (extractedText && extractedText.length > 0) {
            if (extractedText.length > 100) {
                extractedText = [extractedText substringToIndex:100];
            }
            [message appendFormat:@"Text: %@", extractedText];
        }
        
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"HPlus Inspector" message:message preferredStyle:UIAlertControllerStyleAlert];
        
        [alert addAction:[UIAlertAction actionWithTitle:@"Copy Info" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            [UIPasteboard generalPasteboard].string = identifier.length > 0 ? identifier : (extractedText.length > 0 ? extractedText : className);
        }]];
        
        [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:nil]];
        
        // إظهار التنبيه على الشاشة
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
