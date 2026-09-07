#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface HPlusDebugHelper : NSObject
+ (instancetype)sharedInstance;
- (void)handleLongPress:(UILongPressGestureRecognizer *)sender;
@end

%hook UIView

- (void)setAccessibilityIdentifier:(NSString *)accessibilityIdentifier {
    %orig;
    if (accessibilityIdentifier && accessibilityIdentifier.length > 0) {
        // طباعة الكلاس والمعرف في السجلات
        NSLog(@"HPlus_Class: %@ -> ID: %@", NSStringFromClass([self class]), accessibilityIdentifier);
        
        // التحقق من عدم وجود إيماءة مطولة مضافة مسبقاً لتجنب التكرار
        BOOL hasLongPress = NO;
        for (UIGestureRecognizer *recognizer in self.gestureRecognizers) {
            if ([recognizer isKindOfClass:[UILongPressGestureRecognizer class]]) {
                hasLongPress = YES;
                break;
            }
        }
        
        // إضافة ميزة النقر المطول لإظهار المعرف على الشاشة
        if (!hasLongPress) {
            UILongPressGestureRecognizer *longPress = [[UILongPressGestureRecognizer alloc] initWithTarget:[HPlusDebugHelper sharedInstance] action:@selector(handleLongPress:)];
            [self addGestureRecognizer:longPress];
        }
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
        NSString *identifier = view.accessibilityIdentifier;
        NSString *className = NSStringFromClass([view class]);
        
        if (identifier && identifier.length > 0) {
            NSString *message = [NSString stringWithFormat:@"Class: %@\nID: %@", className, identifier];
            
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"HPlus Debug ID" message:message preferredStyle:UIAlertControllerStyleAlert];
            [alert addAction:[UIAlertAction actionWithTitle:@"Copy ID" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                [UIPasteboard generalPasteboard].string = identifier;
            }]];
            [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:nil]];
            
            // العثور على الـ Root ViewController الحالي لإظهار التنبيه
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
}

@end
