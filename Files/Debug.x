#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface HPlusDebugHelper : NSObject
+ (instancetype)sharedInstance;
- (void)handleLongPress:(UILongPressGestureRecognizer *)sender;
@end

%hook UIView

- (void)didMoveToWindow {
    %orig;
    // التحقق من عدم وجود إيماءة مطولة مضافة مسبقاً لتجنب التكرار
    BOOL hasLongPress = NO;
    for (UIGestureRecognizer *recognizer in self.gestureRecognizers) {
        if ([recognizer isKindOfClass:[UILongPressGestureRecognizer class]]) {
            hasLongPress = YES;
            break;
        }
    }
    
    // إضافة النقر المطول لكل الـ Views في التطبيق لضمان شمولية الفحص
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
        UIView *view = sender.view;
        NSString *className = NSStringFromClass([view class]);
        NSString *identifier = view.accessibilityIdentifier;
        
        // استخراج النص تلقائياً إذا كان العنصر يحتوي على نص (مثل UILabel أو ما شابه)
        NSString *extractedText = nil;
        if ([view respondsToSelector:@selector(text)] && [[(id)view text] isKindOfClass:[NSString class]]) {
            extractedText = [(id)view text];
        } else if ([view respondsToSelector:@selector(attributedText)] && [[(id)view attributedText] string]) {
            extractedText = [[(id)view attributedText] string];
        }
        
        // تجهيز الرسالة لتظهر في التنبيه
        NSMutableString *message = [NSMutableString stringWithFormat:@"Class: %@\n", className];
        if (identifier && identifier.length > 0) {
            [message appendFormat:@"ID: %@\n", identifier];
        } else {
            [message appendString:@"ID: (None/Dynamic)\n"];
        }
        
        if (extractedText && extractedText.length > 0) {
            // تقليص النص لو كان طويلاً جداً
            if (extractedText.length > 100) {
                extractedText = [extractedText substringToIndex:100];
            }
            [message appendFormat:@"Text: %@", extractedText];
        }
        
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"HPlus Inspector" message:message preferredStyle:UIAlertControllerStyleAlert];
        
        [alert addAction:[UIAlertAction actionWithTitle:@"Copy ID/Info" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
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
