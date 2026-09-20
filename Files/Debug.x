// ============================================================
// HPlus Inspector
// UIKit-safe / Scene-aware / Cached / Privacy-aware / Budgeted
// Version: 3.0
// ============================================================

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <os/log.h>
#import <os/signpost.h>
#import <os/lock.h>
#import "Headers.h"

// ============================================================
// Logging
// ============================================================

static os_log_t HPlusLog(void) {
    static os_log_t log;
    static dispatch_once_t onceToken;

    dispatch_once(&onceToken, ^{
        log = os_log_create("com.hplus.inspector", "HPlusDebugHelper");
    });

    return log;
}

#define HPlusLogDebug(fmt, ...)   os_log_debug(HPlusLog(), fmt, ##__VA_ARGS__)
#define HPlusLogInfo(fmt, ...)    os_log_info(HPlusLog(), fmt, ##__VA_ARGS__)
#define HPlusLogWarning(fmt, ...) os_log_warning(HPlusLog(), fmt, ##__VA_ARGS__)
#define HPlusLogError(fmt, ...)   os_log_error(HPlusLog(), fmt, ##__VA_ARGS__)

// ============================================================
// Notifications
// ============================================================

static NSString * const kHPlusSettingsDidChangeNotification =
    @"HPlusSettingsDidChangeNotification";

// ============================================================
// Associated Object Keys
// ============================================================

static char kHPlusGestureKey;
static char kHPlusWindowConfiguredKey;

// ============================================================
// Constants
// ============================================================

static NSTimeInterval const kHPlusDefaultPressDuration       = 0.40;
static NSInteger      const kHPlusDefaultMaxScanDepth        = 15;
static NSUInteger     const kHPlusDefaultMaxCollectedItems   = 120;
static NSUInteger     const kHPlusDefaultMaxVisitedViews     = 2500;
static NSTimeInterval const kHPlusDefaultCacheTTL            = 1.0;
static NSTimeInterval const kHPlusDefaultScanTimeBudget      = 80.0;
static NSTimeInterval const kHPlusOverlayDuration            = 2.5;
static NSInteger      const kHPlusMaxViewPathDepth           = 50;
static NSInteger      const kHPlusMaxClassChainDepth         = 30;
static NSInteger      const kHPlusMaxViewControllerDepth     = 30;
static NSInteger      const kHPlusMaxHitTestDepth            = 100;
static NSTimeInterval const kHPlusMinScanInterval            = 0.5;
static NSUInteger     const kHPlusMaxFindMatches             = 50;

// ============================================================
// Match Reasons
// ============================================================

typedef NS_OPTIONS(NSUInteger, HPlusMatchReason) {
    HPlusMatchReasonNone            = 0,
    HPlusMatchReasonIdentifier      = 1 << 0,
    HPlusMatchReasonText            = 1 << 1,
    HPlusMatchReasonAccessibility   = 1 << 2,
    HPlusMatchReasonForced          = 1 << 3
};

// ============================================================
// Safe Helpers
// ============================================================

static BOOL HPlusIsFinite(CGFloat value) {
    return isfinite(value);
}

static CGRect HPlusSanitizeRect(CGRect rect) {
    if (!HPlusIsFinite(rect.origin.x) ||
        !HPlusIsFinite(rect.origin.y) ||
        !HPlusIsFinite(rect.size.width) ||
        !HPlusIsFinite(rect.size.height)) {
        return CGRectZero;
    }

    return rect;
}

static NSString *HPlusSafeString(NSString *value) {
    if (![value isKindOfClass:[NSString class]]) {
        return nil;
    }

    return value.length > 0 ? value : nil;
}

// ============================================================
// Class Name Helper
// ============================================================

static NSString *HPlusClassName(Class cls) {
    if (!cls) {
        return @"(None)";
    }

    NSString *name = NSStringFromClass(cls);

    if (!name.length) {
        return @"(None)";
    }

    return name;
}

// ============================================================
// Scene Helpers
// ============================================================

static UIWindowScene *HPlusWindowSceneForWindow(UIWindow *window) {
    if (!window) {
        return nil;
    }

    if (@available(iOS 13.0, *)) {
        return window.windowScene;
    }

    return nil;
}

static BOOL HPlusWindowHasActiveScene(UIWindow *window) {
    if (!window) {
        return NO;
    }

    if (@available(iOS 13.0, *)) {
        UIWindowScene *scene = window.windowScene;

        if (!scene) {
            return NO;
        }

        UISceneActivationState state = scene.activationState;

        return state == UISceneActivationStateForegroundActive ||
               state == UISceneActivationStateForegroundInactive;
    }

    return YES;
}

// ============================================================
// HPlus Settings
// ============================================================

@interface HPlusSettings : NSObject

+ (NSTimeInterval)minimumPressDuration;
+ (NSInteger)maxScanDepth;
+ (NSUInteger)maxCollectedItems;
+ (NSUInteger)maxVisitedViews;
+ (NSTimeInterval)cacheTTL;
+ (NSTimeInterval)scanTimeBudget;

+ (BOOL)protectSecureFields;
+ (BOOL)enabled;
+ (BOOL)showHighlightOverlay;
+ (BOOL)includeAccessibilityData;
+ (BOOL)includeAccessibilityValue;
+ (BOOL)includeHiddenViews;
+ (BOOL)includeEmptyViews;
+ (BOOL)includeImageURLs;
+ (BOOL)sanitizeClipboard;
+ (BOOL)prettyPrintJSON;

+ (NSArray<NSString *> *)ignoredIdentifierKeywords;

+ (void)reload;

@end

@implementation HPlusSettings

static NSDictionary *_cachedPrefs;
static os_unfair_lock _settingsLock = OS_UNFAIR_LOCK_INIT;

+ (void)initialize {
    if (self == [HPlusSettings class]) {
        [self reload];
    }
}

+ (NSString *)preferencesPath {
    return [NSHomeDirectory()
            stringByAppendingPathComponent:
                @"Library/Preferences/com.hplus.inspector.plist"];
}

+ (void)reload {
    NSDictionary *dict =
        [NSDictionary dictionaryWithContentsOfFile:[self preferencesPath]];

    if (![dict isKindOfClass:[NSDictionary class]]) {
        dict = @{};
    }

    NSDictionary *copy = [dict copy];

    os_unfair_lock_lock(&_settingsLock);
    _cachedPrefs = copy;
    os_unfair_lock_unlock(&_settingsLock);

    [[NSNotificationCenter defaultCenter]
        postNotificationName:kHPlusSettingsDidChangeNotification
                      object:nil];

    HPlusLogInfo("Settings reloaded");
}

+ (NSDictionary *)prefsDict {
    os_unfair_lock_lock(&_settingsLock);

    NSDictionary *dict = _cachedPrefs ?: @{};

    os_unfair_lock_unlock(&_settingsLock);

    return dict;
}

+ (NSTimeInterval)minimumPressDuration {
    NSNumber *value = [self prefsDict][@"MinimumPressDuration"];

    NSTimeInterval duration =
        value ? value.doubleValue : kHPlusDefaultPressDuration;

    if (duration < 0.15) {
        duration = 0.15;
    }

    if (duration > 3.0) {
        duration = 3.0;
    }

    return duration;
}

+ (NSInteger)maxScanDepth {
    NSNumber *value = [self prefsDict][@"MaxScanDepth"];

    NSInteger depth =
        value ? value.integerValue : kHPlusDefaultMaxScanDepth;

    if (depth < 1) {
        depth = 1;
    }

    if (depth > 100) {
        depth = 100;
    }

    return depth;
}

+ (NSUInteger)maxCollectedItems {
    NSNumber *value = [self prefsDict][@"MaxCollectedItems"];

    NSUInteger count =
        value ? value.unsignedIntegerValue : kHPlusDefaultMaxCollectedItems;

    if (count == 0) {
        count = 1;
    }

    if (count > 5000) {
        count = 5000;
    }

    return count;
}

+ (NSUInteger)maxVisitedViews {
    NSNumber *value = [self prefsDict][@"MaxVisitedViews"];

    NSUInteger count =
        value ? value.unsignedIntegerValue : kHPlusDefaultMaxVisitedViews;

    if (count < 100) {
        count = 100;
    }

    if (count > 50000) {
        count = 50000;
    }

    return count;
}

+ (NSTimeInterval)cacheTTL {
    NSNumber *value = [self prefsDict][@"CacheTTL"];

    NSTimeInterval ttl =
        value ? value.doubleValue : kHPlusDefaultCacheTTL;

    if (ttl < 0.0) {
        ttl = 0.0;
    }

    if (ttl > 30.0) {
        ttl = 30.0;
    }

    return ttl;
}

+ (NSTimeInterval)scanTimeBudget {
    NSNumber *value = [self prefsDict][@"ScanTimeBudget"];

    NSTimeInterval budget =
        value ? value.doubleValue : kHPlusDefaultScanTimeBudget;

    if (budget < 10.0) {
        budget = 10.0;
    }

    if (budget > 1000.0) {
        budget = 1000.0;
    }

    return budget;
}

+ (BOOL)protectSecureFields {
    NSNumber *value = [self prefsDict][@"ProtectSecureFields"];
    return value ? value.boolValue : YES;
}

+ (BOOL)enabled {
    NSNumber *value = [self prefsDict][@"Enabled"];
    return value ? value.boolValue : YES;
}

+ (BOOL)showHighlightOverlay {
    NSNumber *value = [self prefsDict][@"ShowHighlightOverlay"];
    return value ? value.boolValue : YES;
}

+ (BOOL)includeAccessibilityData {
    NSNumber *value = [self prefsDict][@"IncludeAccessibilityData"];
    return value ? value.boolValue : YES;
}

+ (BOOL)includeAccessibilityValue {
    NSNumber *value = [self prefsDict][@"IncludeAccessibilityValue"];
    return value ? value.boolValue : NO;
}

+ (BOOL)includeHiddenViews {
    NSNumber *value = [self prefsDict][@"IncludeHiddenViews"];
    return value ? value.boolValue : NO;
}

+ (BOOL)includeEmptyViews {
    NSNumber *value = [self prefsDict][@"IncludeEmptyViews"];
    return value ? value.boolValue : NO;
}

+ (BOOL)includeImageURLs {
    NSNumber *value = [self prefsDict][@"IncludeImageURLs"];
    return value ? value.boolValue : NO;
}

+ (BOOL)sanitizeClipboard {
    NSNumber *value = [self prefsDict][@"SanitizeClipboard"];
    return value ? value.boolValue : YES;
}

+ (BOOL)prettyPrintJSON {
    NSNumber *value = [self prefsDict][@"PrettyPrintJSON"];
    return value ? value.boolValue : YES;
}

+ (NSArray<NSString *> *)ignoredIdentifierKeywords {
    NSArray *custom = [self prefsDict][@"IgnoredIdentifierKeywords"];

    if ([custom isKindOfClass:[NSArray class]] && custom.count > 0) {
        NSMutableArray *result = [NSMutableArray array];

        for (id value in custom) {
            if ([value isKindOfClass:[NSString class]] &&
                [(NSString *)value length] > 0) {
                [result addObject:value];
            }
        }

        if (result.count > 0) {
            return result;
        }
    }

    return @[
        @"reel_overlay",
        @"elements.list_item",
        @"app.view",
        @"container",
        @"wrapper"
    ];
}

@end

// ============================================================
// HPlus Found Item
// ============================================================

@interface HPlusFoundItem : NSObject

@property (nonatomic, copy) NSString *className;
@property (nonatomic, copy) NSString *superclassName;
@property (nonatomic, copy) NSString *viewControllerClass;

@property (nonatomic, copy) NSString *identifier;
@property (nonatomic, copy) NSString *accessibilityLabel;
@property (nonatomic, copy) NSString *accessibilityValue;
@property (nonatomic, copy) NSString *text;

@property (nonatomic, copy) NSString *viewPath;

@property (nonatomic, assign) NSInteger depth;
@property (nonatomic, assign) NSInteger indexInSuperview;
@property (nonatomic, assign) NSUInteger subviewCount;

@property (nonatomic, assign) CGRect frame;
@property (nonatomic, assign) CGRect bounds;

@property (nonatomic, assign) BOOL hidden;
@property (nonatomic, assign) BOOL userInteractionEnabled;
@property (nonatomic, assign) BOOL clipsToBounds;
@property (nonatomic, assign) BOOL accessibilityElement;

@property (nonatomic, assign) CGFloat alpha;

@property (nonatomic, assign) UIAccessibilityTraits accessibilityTraits;

@property (nonatomic, assign) BOOL secureContent;

@property (nonatomic, assign) HPlusMatchReason matchReason;

- (NSDictionary *)toDictionary;

@end

@implementation HPlusFoundItem

- (NSDictionary *)toDictionary {

    NSMutableDictionary *dict = [NSMutableDictionary dictionary];

    dict[@"class"] =
        self.className ?: @"";

    if (self.superclassName.length) {
        dict[@"superclass"] = self.superclassName;
    }

    if (self.viewControllerClass.length) {
        dict[@"viewController"] = self.viewControllerClass;
    }

    if (self.identifier.length) {
        dict[@"identifier"] = self.identifier;
    }

    if (self.accessibilityLabel.length) {
        dict[@"accessibilityLabel"] = self.accessibilityLabel;
    }

    if (self.accessibilityValue.length &&
        HPlusSettings.includeAccessibilityValue) {
        dict[@"accessibilityValue"] = self.accessibilityValue;
    }

    if (self.text.length) {
        dict[@"text"] = self.text;
    }

    if (self.viewPath.length) {
        dict[@"path"] = self.viewPath;
    }

    dict[@"depth"] = @(self.depth);
    dict[@"indexInSuperview"] = @(self.indexInSuperview);
    dict[@"subviewCount"] = @(self.subviewCount);

    CGRect frame = HPlusSanitizeRect(self.frame);
    CGRect bounds = HPlusSanitizeRect(self.bounds);

    dict[@"frame"] = @{
        @"x": @(frame.origin.x),
        @"y": @(frame.origin.y),
        @"width": @(frame.size.width),
        @"height": @(frame.size.height)
    };

    dict[@"bounds"] = @{
        @"x": @(bounds.origin.x),
        @"y": @(bounds.origin.y),
        @"width": @(bounds.size.width),
        @"height": @(bounds.size.height)
    };

    dict[@"hidden"] =
        @(self.hidden);

    dict[@"alpha"] =
        @(self.alpha);

    dict[@"userInteractionEnabled"] =
        @(self.userInteractionEnabled);

    dict[@"clipsToBounds"] =
        @(self.clipsToBounds);

    dict[@"accessibilityElement"] =
        @(self.accessibilityElement);

    dict[@"accessibilityTraits"] =
        @((unsigned long long)self.accessibilityTraits);

    dict[@"secureContent"] =
        @(self.secureContent);

    dict[@"matchReason"] =
        @((NSUInteger)self.matchReason);

    return dict;
}

@end

// ============================================================
// HPlus Debug Helper
// ============================================================

@interface HPlusDebugHelper : NSObject
<UIGestureRecognizerDelegate>

@property (nonatomic, strong) UIWindow *fallbackAlertWindow;
@property (nonatomic, weak) UIWindow *previousKeyWindow;
@property (nonatomic, weak) UIWindowScene *fallbackWindowScene;

@property (nonatomic, strong) UIImpactFeedbackGenerator *hapticGenerator;

@property (nonatomic, strong) UIView *highlightOverlayView;
@property (nonatomic, weak) UIWindow *highlightOverlayWindow;

@property (nonatomic, weak) UIView *lastScannedRoot;
@property (nonatomic, weak) UIWindow *lastScannedWindow;

@property (nonatomic, copy) NSArray<HPlusFoundItem *> *lastScanResults;
@property (nonatomic, strong) NSDate *lastScanDate;

@property (nonatomic, assign) NSUInteger hierarchyGeneration;
@property (nonatomic, assign) NSUInteger lastScanGeneration;

@property (nonatomic, strong) NSDate *lastGestureDate;
@property (nonatomic, assign) BOOL scanInProgress;

+ (instancetype)sharedInstance;

- (void)setupGestureForWindow:(UIWindow *)window;
- (void)removeGestureFromWindow:(UIWindow *)window;
- (void)removeGesturesFromAllWindows;

- (void)handleLongPress:(UILongPressGestureRecognizer *)sender;

- (void)invalidateScanCache;

@end

// ============================================================
// UIWindow Hook
// ============================================================

%hook UIWindow

- (void)makeKeyAndVisible {

    %orig;

    __weak UIWindow *weakWindow = self;

    dispatch_async(dispatch_get_main_queue(), ^{
        UIWindow *window = weakWindow;

        if (window) {
            [[HPlusDebugHelper sharedInstance]
                setupGestureForWindow:window];
        }
    });
}

- (void)becomeKeyWindow {

    %orig;

    __weak UIWindow *weakWindow = self;

    dispatch_async(dispatch_get_main_queue(), ^{
        UIWindow *window = weakWindow;

        if (window) {
            [[HPlusDebugHelper sharedInstance]
                setupGestureForWindow:window];
        }
    });
}

%end

// ============================================================
// Implementation
// ============================================================

@implementation HPlusDebugHelper

// ============================================================
// Singleton
// ============================================================

+ (instancetype)sharedInstance {

    static HPlusDebugHelper *instance;
    static dispatch_once_t onceToken;

    dispatch_once(&onceToken, ^{

        instance = [[HPlusDebugHelper alloc] init];

        if (@available(iOS 10.0, *)) {
            instance.hapticGenerator =
                [[UIImpactFeedbackGenerator alloc]
                    initWithStyle:UIImpactFeedbackStyleMedium];
        }
    });

    return instance;
}

// ============================================================
// Init / Dealloc
// ============================================================

- (instancetype)init {

    self = [super init];

    if (self) {

        _hierarchyGeneration = 1;

        [[NSNotificationCenter defaultCenter]
            addObserver:self
               selector:@selector(settingsDidChange:)
                   name:kHPlusSettingsDidChangeNotification
                 object:nil];
    }

    return self;
}

- (void)dealloc {

    [[NSNotificationCenter defaultCenter]
        removeObserver:self];
}

// ============================================================
// Settings Change
// ============================================================

- (void)settingsDidChange:(NSNotification *)notification {

    dispatch_async(dispatch_get_main_queue(), ^{

        [self invalidateScanCache];

        if (!HPlusSettings.enabled) {

            [self removeGesturesFromAllWindows];

        } else {

            if (@available(iOS 13.0, *)) {

                for (UIScene *scene in
                     [UIApplication sharedApplication].connectedScenes) {

                    if (![scene isKindOfClass:[UIWindowScene class]]) {
                        continue;
                    }

                    UIWindowScene *windowScene =
                        (UIWindowScene *)scene;

                    for (UIWindow *window in windowScene.windows) {

                        [self removeGestureFromWindow:window];
                        [self setupGestureForWindow:window];
                    }
                }

            } else {

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"

                for (UIWindow *window in
                     [UIApplication sharedApplication].windows) {

                    [self removeGestureFromWindow:window];
                    [self setupGestureForWindow:window];
                }

#pragma clang diagnostic pop
            }
        }
    });
}

// ============================================================
// Main Thread
// ============================================================

- (void)performOnMainThread:(dispatch_block_t)block {

    if (!block) {
        return;
    }

    if ([NSThread isMainThread]) {
        block();
    } else {
        dispatch_async(dispatch_get_main_queue(), block);
    }
}

// ============================================================
// Window Filtering
// ============================================================

- (BOOL)shouldIgnoreView:(UIView *)view {

    if (!view) {
        return YES;
    }

    if (view == self.highlightOverlayView) {
        return YES;
    }

    NSString *className =
        HPlusClassName([view class]);

    static NSArray<NSString *> *ignoredClasses;
    static dispatch_once_t onceToken;

    dispatch_once(&onceToken, ^{

        ignoredClasses = @[
            @"_UIAlertControllerView",
            @"_UIKeyboardLayout",
            @"_UIRemoteKeyboardPlaceholderView",
            @"UIAlertController",
            @"UIKeyboard",
            @"UIRemoteKeyboard",
            @"UITextEffectsWindow",
            @"_UIScrollViewScrollIndicator",
            @"UIScrollIndicatorView",
            @"HPlusHighlightOverlay"
        ];
    });

    for (NSString *ignoredClass in ignoredClasses) {

        if ([className rangeOfString:ignoredClass
                              options:NSCaseInsensitiveSearch]
            .location != NSNotFound) {

            return YES;
        }
    }

    return NO;
}

- (BOOL)isIgnoredClassName:(NSString *)className {

    if (!className.length) {
        return NO;
    }

    static NSArray<NSString *> *ignoredSubstrings;
    static dispatch_once_t onceToken;

    dispatch_once(&onceToken, ^{
        ignoredSubstrings = @[
            @"keyboard",
            @"textEffects",
            @"statusbar"
        ];
    });

    for (NSString *sub in ignoredSubstrings) {

        if ([className rangeOfString:sub
                              options:NSCaseInsensitiveSearch]
            .location != NSNotFound) {

            return YES;
        }
    }

    return NO;
}

- (BOOL)shouldAttachGestureToWindow:(UIWindow *)window {

    if (!window) {
        return NO;
    }

    if (!HPlusSettings.enabled) {
        return NO;
    }

    if (window.hidden) {
        return NO;
    }

    if (!window.rootViewController) {
        return NO;
    }

    if ([self shouldIgnoreView:window]) {
        return NO;
    }

    if (!HPlusWindowHasActiveScene(window)) {
        return NO;
    }

    NSString *windowClass =
        HPlusClassName([window class]);

    if ([self isIgnoredClassName:windowClass]) {
        return NO;
    }

    if (window.windowLevel > UIWindowLevelStatusBar) {
        return NO;
    }

    return YES;
}

// ============================================================
// Gesture Setup
// ============================================================

- (void)setupGestureForWindow:(UIWindow *)window {

    if (![NSThread isMainThread]) {

        __weak typeof(self) weakSelf = self;
        __weak UIWindow *weakWindow = window;

        dispatch_async(dispatch_get_main_queue(), ^{

            __strong typeof(weakSelf) strongSelf = weakSelf;
            UIWindow *strongWindow = weakWindow;

            if (strongSelf && strongWindow) {
                [strongSelf setupGestureForWindow:strongWindow];
            }
        });

        return;
    }

    if (![self shouldAttachGestureToWindow:window]) {
        return;
    }

    UILongPressGestureRecognizer *existing =
        objc_getAssociatedObject(window, &kHPlusGestureKey);

    if (existing) {

        existing.minimumPressDuration =
            HPlusSettings.minimumPressDuration;

        return;
    }

    UILongPressGestureRecognizer *longPress =
        [[UILongPressGestureRecognizer alloc]
            initWithTarget:self
                    action:@selector(handleLongPress:)];

    longPress.minimumPressDuration =
        HPlusSettings.minimumPressDuration;

    longPress.cancelsTouchesInView = NO;
    longPress.delaysTouchesBegan = NO;
    longPress.delaysTouchesEnded = NO;
    longPress.delegate = self;

    [window addGestureRecognizer:longPress];

    objc_setAssociatedObject(
        window,
        &kHPlusGestureKey,
        longPress,
        OBJC_ASSOCIATION_RETAIN_NONATOMIC
    );

    objc_setAssociatedObject(
        window,
        &kHPlusWindowConfiguredKey,
        @YES,
        OBJC_ASSOCIATION_RETAIN_NONATOMIC
    );

    HPlusLogInfo(
        "Attached gesture to window: %{private}@",
        HPlusClassName([window class])
    );
}

// ============================================================
// Gesture Removal
// ============================================================

- (void)removeGestureFromWindow:(UIWindow *)window {

    if (!window) {
        return;
    }

    UILongPressGestureRecognizer *gesture =
        objc_getAssociatedObject(window, &kHPlusGestureKey);

    if (gesture) {

        [window removeGestureRecognizer:gesture];

        objc_setAssociatedObject(
            window,
            &kHPlusGestureKey,
            nil,
            OBJC_ASSOCIATION_RETAIN_NONATOMIC
        );
    }

    objc_setAssociatedObject(
        window,
        &kHPlusWindowConfiguredKey,
        nil,
        OBJC_ASSOCIATION_RETAIN_NONATOMIC
    );
}

- (void)removeGesturesFromAllWindows {

    if (![NSThread isMainThread]) {

        __weak typeof(self) weakSelf = self;

        dispatch_async(dispatch_get_main_queue(), ^{
            [weakSelf removeGesturesFromAllWindows];
        });

        return;
    }

    if (@available(iOS 13.0, *)) {

        for (UIScene *scene in
             [UIApplication sharedApplication].connectedScenes) {

            if (![scene isKindOfClass:[UIWindowScene class]]) {
                continue;
            }

            UIWindowScene *windowScene =
                (UIWindowScene *)scene;

            for (UIWindow *window in windowScene.windows) {
                [self removeGestureFromWindow:window];
            }
        }

    } else {

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"

        for (UIWindow *window in
             [UIApplication sharedApplication].windows) {

            [self removeGestureFromWindow:window];
        }

#pragma clang diagnostic pop
    }
}

// ============================================================
// Gesture Delegate
// ============================================================

- (BOOL)gestureRecognizer:
    (UIGestureRecognizer *)gestureRecognizer
    shouldRecognizeSimultaneouslyWithGestureRecognizer:
    (UIGestureRecognizer *)otherGestureRecognizer {

    return YES;
}

- (BOOL)gestureRecognizer:
    (UIGestureRecognizer *)gestureRecognizer
    shouldReceiveTouch:(UITouch *)touch {

    if ([self shouldIgnoreView:touch.view]) {
        return NO;
    }

    return YES;
}

// ============================================================
// Active Key Window
// ============================================================

- (UIWindow *)activeKeyWindow {

    if (![NSThread isMainThread]) {
        return nil;
    }

    if (@available(iOS 13.0, *)) {

        UIWindow *fallback = nil;

        for (UIScene *scene in
             [UIApplication sharedApplication].connectedScenes) {

            if (![scene isKindOfClass:[UIWindowScene class]]) {
                continue;
            }

            UIWindowScene *windowScene =
                (UIWindowScene *)scene;

            if (windowScene.activationState !=
                UISceneActivationStateForegroundActive) {
                continue;
            }

            for (UIWindow *window in windowScene.windows) {

                if (window.isKeyWindow &&
                    !window.hidden &&
                    window.rootViewController) {

                    return window;
                }

                if (!fallback &&
                    !window.hidden &&
                    window.rootViewController &&
                    window.windowLevel == UIWindowLevelNormal) {

                    fallback = window;
                }
            }
        }

        return fallback;
    }

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"

    for (UIWindow *window in
         [UIApplication sharedApplication].windows) {

        if (window.isKeyWindow &&
            !window.hidden &&
            window.rootViewController) {

            return window;
        }
    }

#pragma clang diagnostic pop

    return nil;
}

// ============================================================
// View Controller Resolution
// ============================================================

- (UIViewController *)resolveTopViewController:
    (UIViewController *)viewController {

    if (!viewController) {
        return nil;
    }

    NSHashTable *visited =
        [NSHashTable weakObjectsHashTable];

    UIViewController *current = viewController;

    for (NSInteger depth = 0;
         current && depth < kHPlusMaxViewControllerDepth;
         depth++) {

        if ([visited containsObject:current]) {
            break;
        }

        [visited addObject:current];

        UIViewController *presented =
            current.presentedViewController;

        if (presented &&
            !presented.isBeingDismissed) {

            current = presented;
            continue;
        }

        if ([current isKindOfClass:
                [UINavigationController class]]) {

            UIViewController *visible =
                [(UINavigationController *)current
                    visibleViewController];

            if (visible && visible != current) {
                current = visible;
                continue;
            }
        }

        if ([current isKindOfClass:
                [UITabBarController class]]) {

            UIViewController *selected =
                [(UITabBarController *)current
                    selectedViewController];

            if (selected && selected != current) {
                current = selected;
                continue;
            }
        }

        if ([current isKindOfClass:
                [UISplitViewController class]]) {

            NSArray *controllers =
                [(UISplitViewController *)current
                    viewControllers];

            UIViewController *candidate = nil;

            for (UIViewController *vc in
                 [controllers reverseObjectEnumerator]) {

                if (vc.viewIfLoaded.window) {
                    candidate = vc;
                    break;
                }
            }

            if (candidate && candidate != current) {
                current = candidate;
                continue;
            }
        }

        if ([current isKindOfClass:
                [UIPageViewController class]]) {

            UIViewController *candidate =
                [(UIPageViewController *)current
                    viewControllers].firstObject;

            if (candidate && candidate != current) {
                current = candidate;
                continue;
            }
        }

        UIViewController *visibleChild = nil;

        for (UIViewController *child in
             [current.children reverseObjectEnumerator]) {

            if (child.viewIfLoaded.window &&
                !child.viewIfLoaded.hidden) {

                visibleChild = child;
                break;
            }
        }

        if (visibleChild && visibleChild != current) {
            current = visibleChild;
            continue;
        }

        break;
    }

    return current;
}

- (UIViewController *)topViewController {

    if (![NSThread isMainThread]) {
        return nil;
    }

    UIWindow *window = [self activeKeyWindow];

    if (!window.rootViewController) {
        return nil;
    }

    return [self resolveTopViewController:
                window.rootViewController];
}

// ============================================================
// View Controller From View
// ============================================================

- (UIViewController *)viewControllerForView:(UIView *)view {

    if (!view) {
        return nil;
    }

    UIResponder *responder = view;

    NSInteger depth = 0;

    while (responder &&
           depth < kHPlusMaxViewControllerDepth) {

        if ([responder isKindOfClass:
                [UIViewController class]]) {

            return (UIViewController *)responder;
        }

        responder = responder.nextResponder;
        depth++;
    }

    return nil;
}

// ============================================================
// Overlay
// ============================================================

- (void)showHighlightOverlayForView:
    (UIView *)view
    inWindow:(UIWindow *)window {

    if (!HPlusSettings.showHighlightOverlay) {
        return;
    }

    if (!view || !window) {
        return;
    }

    if (![NSThread isMainThread]) {

        __weak typeof(self) weakSelf = self;
        __weak UIView *weakView = view;
        __weak UIWindow *weakWindow = window;

        dispatch_async(dispatch_get_main_queue(), ^{

            __strong typeof(weakSelf) strongSelf = weakSelf;

            if (strongSelf &&
                weakView &&
                weakWindow) {

                [strongSelf
                    showHighlightOverlayForView:weakView
                    inWindow:weakWindow];
            }
        });

        return;
    }

    [self removeHighlightOverlay];

    CGRect frameInWindow =
        HPlusSanitizeRect(
            [view convertRect:view.bounds
                      toView:window]
        );

    if (CGRectIsNull(frameInWindow) ||
        CGRectIsEmpty(frameInWindow)) {

        return;
    }

    UIView *overlay =
        [[UIView alloc] initWithFrame:frameInWindow];

    overlay.accessibilityIdentifier =
        @"HPlusHighlightOverlay";

    overlay.layer.borderColor =
        [UIColor systemRedColor].CGColor;

    overlay.layer.borderWidth = 2.0;
    overlay.layer.cornerRadius = 4.0;

    overlay.backgroundColor =
        [[UIColor systemRedColor]
            colorWithAlphaComponent:0.12];

    overlay.userInteractionEnabled = NO;
    overlay.clipsToBounds = YES;
    overlay.alpha = 0.0;

    [window addSubview:overlay];

    self.highlightOverlayView = overlay;
    self.highlightOverlayWindow = window;

    [UIView animateWithDuration:0.15
                     animations:^{
        overlay.alpha = 1.0;
    }];
}

- (void)removeHighlightOverlay {

    if (![NSThread isMainThread]) {

        __weak typeof(self) weakSelf = self;

        dispatch_async(dispatch_get_main_queue(), ^{
            [weakSelf removeHighlightOverlay];
        });

        return;
    }

    UIView *overlay =
        self.highlightOverlayView;

    self.highlightOverlayView = nil;
    self.highlightOverlayWindow = nil;

    if (!overlay) {
        return;
    }

    [UIView animateWithDuration:0.18
                     animations:^{
        overlay.alpha = 0.0;
    }
                     completion:^(BOOL finished) {
        [overlay removeFromSuperview];
    }];
}

// ============================================================
// Fallback Window
// ============================================================

- (void)cleanupFallbackWindow {

    if (![NSThread isMainThread]) {

        __weak typeof(self) weakSelf = self;

        dispatch_async(dispatch_get_main_queue(), ^{
            [weakSelf cleanupFallbackWindow];
        });

        return;
    }

    UIWindow *fallback =
        self.fallbackAlertWindow;

    self.fallbackAlertWindow = nil;

    if (!fallback) {
        return;
    }

    fallback.hidden = YES;
    fallback.rootViewController = nil;

    UIWindow *previous =
        self.previousKeyWindow;

    self.previousKeyWindow = nil;
    self.fallbackWindowScene = nil;

    if (previous &&
        !previous.hidden &&
        previous.windowScene.activationState !=
            UISceneActivationStateUnattached) {

        [previous makeKeyWindow];
    }
}

// ============================================================
// Alert Presentation
// ============================================================

- (void)presentAlert:
    (UIAlertController *)alert
    fromWindow:(UIWindow *)window {

    if (!alert) {
        return;
    }

    UIViewController *topVC =
        [self topViewController];

    if (topVC) {

        UIViewController *current = topVC;

        while (current.presentedViewController &&
               !current.presentedViewController.isBeingDismissed) {

            current =
                current.presentedViewController;
        }

        if (current.viewIfLoaded.window) {

            [current
                presentViewController:alert
                animated:YES
                completion:nil];

            return;
        }
    }

    if (!window) {
        window = [self activeKeyWindow];
    }

    if (!window) {

        HPlusLogError(
            "Unable to find presentation window"
        );

        return;
    }

    self.previousKeyWindow =
        [self activeKeyWindow];

    if (@available(iOS 13.0, *)) {

        UIWindowScene *scene =
            window.windowScene;

        if (!scene) {
            HPlusLogError(
                "Window has no UIWindowScene"
            );
            return;
        }

        UIWindow *fallback =
            [[UIWindow alloc]
                initWithWindowScene:scene];

        fallback.frame = scene.coordinateSpace.bounds;
        fallback.windowLevel =
            UIWindowLevelAlert + 1.0;

        fallback.backgroundColor =
            UIColor.clearColor;

        UIViewController *root =
            [[UIViewController alloc] init];

        root.view.backgroundColor =
            UIColor.clearColor;

        fallback.rootViewController = root;

        self.fallbackAlertWindow = fallback;
        self.fallbackWindowScene = scene;

        [fallback makeKeyAndVisible];

        [root
            presentViewController:alert
            animated:YES
            completion:nil];

    } else {

        UIWindow *fallback =
            [[UIWindow alloc]
                initWithFrame:window.bounds];

        fallback.windowLevel =
            UIWindowLevelAlert + 1.0;

        fallback.backgroundColor =
            UIColor.clearColor;

        UIViewController *root =
            [[UIViewController alloc] init];

        root.view.backgroundColor =
            UIColor.clearColor;

        fallback.rootViewController = root;

        self.fallbackAlertWindow = fallback;

        [fallback makeKeyAndVisible];

        [root
            presentViewController:alert
            animated:YES
            completion:nil];
    }
}

// ============================================================
// Class Chain
// ============================================================

- (NSString *)classChainForView:(UIView *)view {

    if (!view) {
        return @"(None)";
    }

    NSMutableArray<NSString *> *parts =
        [NSMutableArray array];

    UIView *current = view;

    NSInteger depth = 0;

    while (current &&
           depth < kHPlusMaxClassChainDepth) {

        [parts addObject:
            HPlusClassName([current class])];

        current = current.superview;
        depth++;
    }

    NSArray *reversed =
        [[parts reverseObjectEnumerator] allObjects];

    return [reversed componentsJoinedByString:@"\n     ↓ "];
}

// ============================================================
// View Path
// ============================================================

- (NSString *)viewPathForView:(UIView *)view {

    if (!view) {
        return @"(None)";
    }

    NSMutableArray<NSString *> *parts =
        [NSMutableArray array];

    UIView *current = view;

    NSInteger depth = 0;

    while (current &&
           depth < kHPlusMaxViewPathDepth) {

        [parts addObject:
            HPlusClassName([current class])];

        current = current.superview;
        depth++;
    }

    NSArray *reversed =
        [[parts reverseObjectEnumerator] allObjects];

    return [NSString stringWithFormat:
        @"[%@]",
        [reversed componentsJoinedByString:@" > "]];
}

// ============================================================
// Secure Text / Text Extraction
// ============================================================

- (NSString *)safeTextForView:
    (UIView *)view
    secure:(BOOL *)secure {

    if (secure) {
        *secure = NO;
    }

    if (!view) {
        return nil;
    }

    BOOL protect =
        HPlusSettings.protectSecureFields;

    if ([view isKindOfClass:
            [UITextField class]]) {

        UITextField *textField =
            (UITextField *)view;

        if (textField.isSecureTextEntry) {

            if (secure) {
                *secure = YES;
            }

            return protect
                ? @"🔒 (Secure field)"
                : textField.text;
        }

        if (textField.text.length) {
            return textField.text;
        }

        if (textField.attributedPlaceholder.string.length) {

            return [NSString stringWithFormat:
                @"Placeholder: %@",
                textField.attributedPlaceholder.string];
        }

        if (textField.placeholder.length) {

            return [NSString stringWithFormat:
                @"Placeholder: %@",
                textField.placeholder];
        }
    }

    if ([view isKindOfClass:
            [UITextView class]]) {

        UITextView *textView =
            (UITextView *)view;

        if (textView.secureTextEntry) {

            if (secure) {
                *secure = YES;
            }

            return protect
                ? @"🔒 (Secure field)"
                : textView.text;
        }

        if (textView.text.length) {
            return textView.text;
        }
    }

    if ([view isKindOfClass:
            [UILabel class]]) {

        UILabel *label =
            (UILabel *)view;

        if (label.text.length) {
            return label.text;
        }
    }

    if ([view isKindOfClass:
            [UIButton class]]) {

        UIButton *button =
            (UIButton *)view;

        NSString *title =
            [button titleForState:UIControlStateNormal];

        if (title.length) {
            return title;
        }

        NSAttributedString *attributed =
            [button attributedTitleForState:
                UIControlStateNormal];

        if (attributed.string.length) {
            return attributed.string;
        }

        if (button.currentTitle.length) {
            return button.currentTitle;
        }

        if (button.currentAttributedTitle.string.length) {
            return button.currentAttributedTitle.string;
        }
    }

    if ([view isKindOfClass:
            [UISegmentedControl class]]) {

        UISegmentedControl *segmented =
            (UISegmentedControl *)view;

        if (segmented.selectedSegmentIndex >= 0) {

            NSString *title =
                [segmented titleForSegmentAtIndex:
                    segmented.selectedSegmentIndex];

            if (title.length) {
                return title;
            }
        }
    }

    if ([view isKindOfClass:
            [UISwitch class]]) {

        return ((UISwitch *)view).isOn
            ? @"ON"
            : @"OFF";
    }

    if ([view isKindOfClass:
            [UISlider class]]) {

        return [NSString stringWithFormat:
            @"%.3f",
            ((UISlider *)view).value];
    }

    if (HPlusSettings.includeAccessibilityData &&
        view.accessibilityLabel.length) {

        return view.accessibilityLabel;
    }

    return nil;
}

// ============================================================
// Image Info
// ============================================================

- (NSString *)sanitizeImageURL:(NSURL *)url {

    if (!url) {
        return nil;
    }

    if (!HPlusSettings.includeImageURLs) {
        return nil;
    }

    NSURLComponents *components =
        [NSURLComponents componentsWithURL:url
                   resolvingAgainstBaseURL:NO];

    if (!components) {
        return nil;
    }

    // Do not expose query parameters or fragments.
    components.query = nil;
    components.fragment = nil;

    return components.URL.absoluteString;
}

- (NSString *)getImageInfoForView:(UIView *)view {

    if (![view isKindOfClass:
            [UIImageView class]]) {

        return nil;
    }

    UIImageView *imageView =
        (UIImageView *)view;

    UIImage *image =
        imageView.image;

    if (!image) {
        return nil;
    }

    NSMutableString *info =
        [NSMutableString stringWithFormat:
            @"Size: %.0fx%.0f @%.1fx",
            image.size.width,
            image.size.height,
            image.scale];

    if (HPlusSettings.includeImageURLs) {

        SEL selector =
            NSSelectorFromString(@"sd_imageURL");

        if ([imageView respondsToSelector:selector]) {

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"

            id value =
                [imageView performSelector:selector];

#pragma clang diagnostic pop

            if ([value isKindOfClass:
                    [NSURL class]]) {

                NSString *url =
                    [self sanitizeImageURL:
                        (NSURL *)value];

                if (url.length) {

                    [info appendFormat:
                        @" | URL: %@",
                        url];
                }
            }
        }
    }

    return info;
}

// ============================================================
// Identifier Filtering
// ============================================================

- (BOOL)isGeneralOrIgnoredIdentifier:
    (NSString *)identifier {

    if (!identifier.length) {
        return YES;
    }

    for (NSString *keyword in
         HPlusSettings.ignoredIdentifierKeywords) {

        if ([identifier rangeOfString:keyword
                              options:NSCaseInsensitiveSearch]
            .location != NSNotFound) {

            return YES;
        }
    }

    return NO;
}

// ============================================================
// Index In Superview
// ============================================================

- (NSInteger)indexOfViewInSuperview:(UIView *)view {

    if (!view.superview) {
        return -1;
    }

    NSUInteger index =
        [view.superview.subviews
            indexOfObjectIdenticalTo:view];

    if (index == NSNotFound) {
        return -1;
    }

    return (NSInteger)index;
}

// ============================================================
// Scanner
// ============================================================

- (void)collectViewsFromView:
    (UIView *)view
    rootWindow:(UIWindow *)rootWindow
    results:(NSMutableArray<HPlusFoundItem *> *)results
    visited:(NSMutableSet<UIView *> *)visited
    visitedCount:(NSUInteger *)visitedCount
    scanStartTime:(CFTimeInterval)scanStartTime
    timedOut:(BOOL *)timedOut {

    if (!view || !rootWindow) {
        return;
    }

    NSInteger maxDepth =
        HPlusSettings.maxScanDepth;

    NSUInteger maxCollected =
        HPlusSettings.maxCollectedItems;

    NSUInteger maxVisited =
        HPlusSettings.maxVisitedViews;

    BOOL includeHidden =
        HPlusSettings.includeHiddenViews;

    BOOL includeEmpty =
        HPlusSettings.includeEmptyViews;

    BOOL includeAccessibility =
        HPlusSettings.includeAccessibilityData;

    CFTimeInterval budgetSeconds =
        HPlusSettings.scanTimeBudget / 1000.0;

    NSMutableArray<NSArray *> *stack =
        [NSMutableArray array];

    [stack addObject:@[
        view,
        @0
    ]];

    while (stack.count > 0) {

        if ((CFAbsoluteTimeGetCurrent() -
             scanStartTime) >= budgetSeconds) {

            if (timedOut) {
                *timedOut = YES;
            }

            break;
        }

        NSArray *entry =
            stack.lastObject;

        [stack removeLastObject];

        UIView *v = entry[0];

        NSInteger depth =
            [entry[1] integerValue];

        if (!v) {
            continue;
        }

        if (depth > maxDepth) {
            continue;
        }

        if (results.count >= maxCollected) {
            break;
        }

        if (*visitedCount >= maxVisited) {
            break;
        }

        if ([visited containsObject:v]) {
            continue;
        }

        [visited addObject:v];
        (*visitedCount)++;

        if ([self shouldIgnoreView:v]) {
            continue;
        }

        if (!includeHidden &&
            (v.hidden || v.alpha <= 0.001)) {

            continue;
        }

        NSString *identifier =
            v.accessibilityIdentifier;

        BOOL secure = NO;

        NSString *text =
            [self safeTextForView:v
                           secure:&secure];

        NSString *accessibilityLabel =
            includeAccessibility
                ? v.accessibilityLabel
                : nil;

        NSString *accessibilityValue =
            (includeAccessibility &&
             HPlusSettings.includeAccessibilityValue)
                ? v.accessibilityValue
                : nil;

        BOOL hasUsefulID =
            identifier.length > 0 &&
            ![self isGeneralOrIgnoredIdentifier:
                identifier];

        BOOL hasUsefulText =
            text.length > 0;

        BOOL hasAccessibility =
            accessibilityLabel.length > 0 ||
            accessibilityValue.length > 0;

        HPlusMatchReason reason =
            HPlusMatchReasonNone;

        if (hasUsefulID) {
            reason |= HPlusMatchReasonIdentifier;
        }

        if (hasUsefulText) {
            reason |= HPlusMatchReasonText;
        }

        if (hasAccessibility) {
            reason |= HPlusMatchReasonAccessibility;
        }

        BOOL shouldCollect =
            hasUsefulID ||
            hasUsefulText ||
            hasAccessibility ||
            includeEmpty;

        if (includeEmpty &&
            reason == HPlusMatchReasonNone) {

            reason |= HPlusMatchReasonForced;
        }

        if (shouldCollect) {

            HPlusFoundItem *item =
                [[HPlusFoundItem alloc] init];

            item.className =
                HPlusClassName([v class]);

            Class superclass =
                class_getSuperclass([v class]);

            if (superclass) {
                item.superclassName =
                    HPlusClassName(superclass);
            }

            UIViewController *viewController =
                [self viewControllerForView:v];

            if (viewController) {
                item.viewControllerClass =
                    HPlusClassName([viewController class]);
            }

            item.identifier =
                hasUsefulID ? identifier : nil;

            item.accessibilityLabel =
                accessibilityLabel;

            item.accessibilityValue =
                accessibilityValue;

            item.text =
                text;

            item.depth =
                depth;

            item.indexInSuperview =
                [self indexOfViewInSuperview:v];

            item.subviewCount =
                v.subviews.count;

            item.hidden =
                v.hidden;

            item.alpha =
                v.alpha;

            item.userInteractionEnabled =
                v.userInteractionEnabled;

            item.clipsToBounds =
                v.clipsToBounds;

            item.accessibilityElement =
                v.isAccessibilityElement;

            item.accessibilityTraits =
                v.accessibilityTraits;

            item.secureContent =
                secure;

            item.matchReason =
                reason;

            item.frame =
                HPlusSanitizeRect(
                    [v convertRect:v.bounds
                            toView:rootWindow]
                );

            item.bounds =
                HPlusSanitizeRect(v.bounds);

            item.viewPath =
                [self viewPathForView:v];

            [results addObject:item];
        }

        NSArray<UIView *> *subviews =
            v.subviews;

        for (NSInteger i =
             (NSInteger)subviews.count - 1;
             i >= 0;
             i--) {

            if (results.count >= maxCollected) {
                break;
            }

            if (*visitedCount >= maxVisited) {
                break;
            }

            [stack addObject:@[
                subviews[(NSUInteger)i],
                @(depth + 1)
            ]];
        }
    }
}

// ============================================================
// Root Selection
// ============================================================

- (UIView *)scanRootForView:(UIView *)view {

    if (!view) {
        return nil;
    }

    UIView *container = view;

    NSInteger upSteps = 0;

    while (container.superview &&
           upSteps < 3) {

        if ([container isKindOfClass:
                [UITableViewCell class]] ||
            [container isKindOfClass:
                [UICollectionViewCell class]]) {

            break;
        }

        container =
            container.superview;

        upSteps++;
    }

    return container;
}

// ============================================================
// Cache
// ============================================================

- (void)invalidateScanCache {

    if (![NSThread isMainThread]) {

        __weak typeof(self) weakSelf = self;

        dispatch_async(dispatch_get_main_queue(), ^{
            [weakSelf invalidateScanCache];
        });

        return;
    }

    self.hierarchyGeneration++;

    self.lastScannedRoot = nil;
    self.lastScannedWindow = nil;
    self.lastScanResults = nil;
    self.lastScanDate = nil;
    self.lastScanGeneration = 0;
}

- (BOOL)isScanCacheValidForRoot:(UIView *)root
                         window:(UIWindow *)window {

    if (!root || !window) {
        return NO;
    }

    if (!self.lastScannedRoot ||
        self.lastScannedRoot != root) {

        return NO;
    }

    if (!self.lastScannedWindow ||
        self.lastScannedWindow != window) {

        return NO;
    }

    if (self.lastScanGeneration !=
        self.hierarchyGeneration) {

        return NO;
    }

    if (!self.lastScanResults.count) {
        return NO;
    }

    if (!self.lastScanDate) {
        return NO;
    }

    NSTimeInterval age =
        -[self.lastScanDate timeIntervalSinceNow];

    return age <= HPlusSettings.cacheTTL;
}

// ============================================================
// Scan
// ============================================================

- (NSArray<HPlusFoundItem *> *)
    collectAllIdentifiersInView:(UIView *)view {

    if (![NSThread isMainThread]) {

        HPlusLogError(
            "Attempted UIKit scan off main thread"
        );

        return @[];
    }

    UIView *root =
        [self scanRootForView:view];

    if (!root) {
        return @[];
    }

    UIWindow *window =
        root.window;

    if (!window) {
        return @[];
    }

    if ([self isScanCacheValidForRoot:root
                               window:window]) {

        return self.lastScanResults;
    }

    os_signpost_id_t spid =
        os_signpost_id_generate(HPlusLog());

    os_signpost_interval_begin(
        HPlusLog(),
        spid,
        "Scan"
    );

    CFTimeInterval start =
        CFAbsoluteTimeGetCurrent();

    NSMutableArray<HPlusFoundItem *> *results =
        [NSMutableArray array];

    NSMutableSet<UIView *> *visited =
        [NSMutableSet set];

    NSUInteger visitedCount = 0;

    BOOL timedOut = NO;

    [self collectViewsFromView:root
                    rootWindow:window
                       results:results
                       visited:visited
                  visitedCount:&visitedCount
                scanStartTime:start
                      timedOut:&timedOut];

    os_signpost_interval_end(
        HPlusLog(),
        spid,
        "Scan"
    );

    self.lastScannedRoot = root;
    self.lastScannedWindow = window;
    self.lastScanResults = [results copy];
    self.lastScanDate = [NSDate date];
    self.lastScanGeneration =
        self.hierarchyGeneration;

    NSTimeInterval duration =
        (CFAbsoluteTimeGetCurrent() - start) * 1000.0;

    if (timedOut) {

        HPlusLogWarning(
            "Scan timed out after %.2f ms: %lu items / %lu views",
            duration,
            (unsigned long)results.count,
            (unsigned long)visitedCount
        );

    } else {

        HPlusLogInfo(
            "Scan completed in %.2f ms: %lu items / %lu views",
            duration,
            (unsigned long)results.count,
            (unsigned long)visitedCount
        );
    }

    return self.lastScanResults ?: @[];
}

// ============================================================
// Formatting
// ============================================================

- (NSString *)
    formattedListFromFoundItems:
    (NSArray<HPlusFoundItem *> *)items {

    if (!items.count) {
        return @"(No items)";
    }

    NSMutableString *output =
        [NSMutableString string];

    for (HPlusFoundItem *item in items) {

        NSUInteger spaces =
            MIN((NSUInteger)100,
                (NSUInteger)MAX(0,
                    item.depth * 2));

        [output appendString:
            [@"" stringByPaddingToLength:spaces
                              withString:@" "
                         startingAtIndex:0]];

        [output appendFormat:
            @"• [%@]",
            item.className ?: @"UIView"];

        if (item.identifier.length) {

            [output appendFormat:
                @" ID: %@",
                item.identifier];
        }

        if (item.text.length) {

            [output appendFormat:
                @" Text: \"%@\"",
                item.text];
        }

        [output appendString:@"\n"];
    }

    return output;
}

// ============================================================
// JSON
// ============================================================

- (NSString *)
    jsonStringFromFoundItems:
    (NSArray<HPlusFoundItem *> *)items {

    NSMutableArray *array =
        [NSMutableArray arrayWithCapacity:
            items.count];

    for (HPlusFoundItem *item in items) {

        [array addObject:
            [item toDictionary]];
    }

    NSMutableDictionary *root =
        [NSMutableDictionary dictionary];

    root[@"schemaVersion"] = @2;
    root[@"generatedAt"] =
        [[NSDate date]
            descriptionWithLocale:
                [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"]];

    root[@"itemCount"] =
        @(array.count);

    root[@"items"] =
        array;

    NSError *error = nil;

    NSJSONWritingOptions options =
        HPlusSettings.prettyPrintJSON
            ? NSJSONWritingPrettyPrinted
            : 0;

    NSData *data =
        [NSJSONSerialization
            dataWithJSONObject:root
            options:options
            error:&error];

    if (!data) {

        HPlusLogError(
            "JSON serialization failed: %{private}@",
            error.localizedDescription
        );

        return @"{}";
    }

    return [[NSString alloc]
        initWithData:data
        encoding:NSUTF8StringEncoding];
}

// ============================================================
// Find By Identifier - Iterative
// ============================================================

- (void)findViewsWithIdentifier:
    (NSString *)identifier
    inView:(UIView *)root
    results:(NSMutableArray<UIView *> *)results {

    if (!root ||
        !identifier.length ||
        !results) {

        return;
    }

    if (results.count >= kHPlusMaxFindMatches) {
        return;
    }

    NSMutableArray<UIView *> *stack =
        [NSMutableArray arrayWithObject:root];

    NSMutableSet<UIView *> *visited =
        [NSMutableSet set];

    while (stack.count > 0 &&
           results.count < kHPlusMaxFindMatches) {

        UIView *current =
            stack.lastObject;

        [stack removeLastObject];

        if (!current ||
            [visited containsObject:current]) {

            continue;
        }

        [visited addObject:current];

        if ([current.accessibilityIdentifier
             isEqualToString:identifier]) {

            [results addObject:current];
        }

        NSArray<UIView *> *subviews =
            current.subviews;

        for (NSInteger i =
             (NSInteger)subviews.count - 1;
             i >= 0;
             i--) {

            if (results.count >=
                kHPlusMaxFindMatches) {
                break;
            }

            [stack addObject:
                subviews[(NSUInteger)i]];
        }
    }
}

// ============================================================
// Scroll To View
// ============================================================

- (void)scrollViewToMakeViewVisible:(UIView *)view {

    if (!view) {
        return;
    }

    UIScrollView *scrollView = nil;

    UIView *current =
        view.superview;

    while (current) {

        if ([current isKindOfClass:
                [UIScrollView class]]) {

            scrollView =
                (UIScrollView *)current;

            break;
        }

        current =
            current.superview;
    }

    if (!scrollView) {
        return;
    }

    CGRect rect =
        [view convertRect:view.bounds
                  toView:scrollView];

    [scrollView
        scrollRectToVisible:rect
                   animated:YES];
}

// ============================================================
// Find Prompt
// ============================================================

- (void)presentFindByIDPrompt {

    UIViewController *topVC =
        [self topViewController];

    if (!topVC) {
        return;
    }

    UIAlertController *prompt =
        [UIAlertController
            alertControllerWithTitle:@"🔎 Find by ID"
                             message:@"أدخل الـ accessibilityIdentifier"
                      preferredStyle:UIAlertControllerStyleAlert];

    [prompt
        addTextFieldWithConfigurationHandler:
        ^(UITextField *textField) {

        textField.placeholder =
            @"مثال: login_button";

        textField.autocapitalizationType =
            UITextAutocapitalizationTypeNone;

        textField.autocorrectionType =
            UITextAutocorrectionTypeNo;

        textField.clearButtonMode =
            UITextFieldViewModeWhileEditing;
    }];

    __weak typeof(self) weakSelf = self;
    __weak UIAlertController *weakPrompt = prompt;

    [prompt
        addAction:
        [UIAlertAction
            actionWithTitle:@"بحث"
                      style:UIAlertActionStyleDefault
                    handler:^(UIAlertAction *action) {

        __strong typeof(weakSelf) strongSelf =
            weakSelf;

        UIAlertController *strongPrompt =
            weakPrompt;

        if (!strongSelf ||
            !strongPrompt) {

            return;
        }

        NSString *targetID =
            [strongPrompt.textFields.firstObject.text
                stringByTrimmingCharactersInSet:
                    [NSCharacterSet
                        whitespaceAndNewlineCharacterSet]];

        if (!targetID.length) {
            return;
        }

        UIWindow *window =
            [strongSelf activeKeyWindow];

        if (!window) {
            return;
        }

        NSMutableArray<UIView *> *matches =
            [NSMutableArray array];

        [strongSelf
            findViewsWithIdentifier:targetID
            inView:window
            results:matches];

        UIView *found =
            matches.firstObject;

        if (found) {

            [strongSelf
                showHighlightOverlayForView:found
                inWindow:window];

            [strongSelf
                scrollViewToMakeViewVisible:found];

            dispatch_after(
                dispatch_time(
                    DISPATCH_TIME_NOW,
                    (int64_t)
                        (kHPlusOverlayDuration *
                         NSEC_PER_SEC)
                ),
                dispatch_get_main_queue(),
                ^{
                    [strongSelf
                        removeHighlightOverlay];
                }
            );
        }

        NSString *message;

        if (matches.count == 0) {

            message =
                @"لم يتم العثور على عنصر.";

        } else {

            NSMutableString *result =
                [NSMutableString string];

            [result appendFormat:
                @"تم العثور على %lu عنصر.\n\n",
                (unsigned long)matches.count];

            if (found) {

                [result appendString:
                    [strongSelf
                        viewPathForView:found]];
            }

            message = result;
        }

        UIAlertController *resultAlert =
            [UIAlertController
                alertControllerWithTitle:
                    (matches.count
                        ? @"✅ موجود"
                        : @"❌ غير موجود")
                message:message
                preferredStyle:
                    UIAlertControllerStyleAlert];

        [resultAlert
            addAction:
            [UIAlertAction
                actionWithTitle:@"OK"
                          style:UIAlertActionStyleCancel
                        handler:nil]];

        UIViewController *currentVC =
            [strongSelf topViewController];

        if (currentVC) {

            [currentVC
                presentViewController:resultAlert
                animated:YES
                completion:nil];
        }
    }]];

    [prompt
        addAction:
        [UIAlertAction
            actionWithTitle:@"إلغاء"
                      style:UIAlertActionStyleCancel
                    handler:nil]];

    [topVC
        presentViewController:prompt
        animated:YES
        completion:nil];
}

// ============================================================
// Deepest View At Point
// ============================================================

- (UIView *)deepestViewAtPoint:
    (CGPoint)point
    inView:(UIView *)view {

    if (!view) {
        return nil;
    }

    UIView *current = view;
    CGPoint currentPoint = point;

    NSInteger depth = 0;

    while (current &&
           depth < kHPlusMaxHitTestDepth) {

        UIView *next = nil;

        for (UIView *sub in
             current.subviews.reverseObjectEnumerator) {

            if (!sub.userInteractionEnabled ||
                sub.hidden ||
                sub.alpha < 0.01) {

                continue;
            }

            CGPoint subPoint =
                [current convertPoint:currentPoint
                               toView:sub];

            if ([sub pointInside:subPoint
                       withEvent:nil]) {

                next = sub;
                currentPoint = subPoint;
                break;
            }
        }

        if (!next) {
            break;
        }

        current = next;
        depth++;
    }

    return current;
}

// ============================================================
// Clipboard
// ============================================================

- (void)copyStringToPasteboard:(NSString *)string {

    if (!string.length) {
        return;
    }

    NSString *value = string;

    if (HPlusSettings.sanitizeClipboard) {

        value =
            [value stringByTrimmingCharactersInSet:
                [NSCharacterSet
                    whitespaceAndNewlineCharacterSet]];
    }

    if (!value.length) {
        return;
    }

    [UIPasteboard generalPasteboard].string =
        value;
}

// ============================================================
// Long Press
// ============================================================

- (void)handleLongPress:
    (UILongPressGestureRecognizer *)sender {

    if (![NSThread isMainThread]) {

        __weak typeof(self) weakSelf = self;
        __weak UILongPressGestureRecognizer *weakSender =
            sender;

        dispatch_async(dispatch_get_main_queue(), ^{
            [weakSelf handleLongPress:weakSender];
        });

        return;
    }

    if (!HPlusSettings.enabled) {
        return;
    }

    if (sender.state !=
        UIGestureRecognizerStateBegan) {

        return;
    }

    if (![sender.view isKindOfClass:
            [UIWindow class]]) {

        return;
    }

    NSDate *now =
        [NSDate date];

    if (self.lastGestureDate &&
        [now timeIntervalSinceDate:
            self.lastGestureDate] <
            kHPlusMinScanInterval) {

        return;
    }

    self.lastGestureDate = now;

    if (self.scanInProgress) {
        return;
    }

    if (@available(iOS 10.0, *)) {

        [self.hapticGenerator prepare];
        [self.hapticGenerator impactOccurred];
    }

    UIWindow *window =
        (UIWindow *)sender.view;

    CGPoint point =
        [sender locationInView:window];

    UIView *targetView =
        [window hitTest:point
              withEvent:nil];

    if (!targetView) {

        targetView =
            [self deepestViewAtPoint:point
                              inView:window];
    }

    if (!targetView) {
        return;
    }

    if ([self shouldIgnoreView:targetView]) {
        return;
    }

    // ========================================================
    // Target Metadata
    // ========================================================

    NSString *className =
        HPlusClassName([targetView class]);

    NSString *classChain =
        [self classChainForView:targetView];

    NSString *viewPath =
        [self viewPathForView:targetView];

    NSString *identifier =
        targetView.accessibilityIdentifier;

    BOOL secure = NO;

    NSString *extractedText =
        [self safeTextForView:targetView
                       secure:&secure];

    CGRect frameInWindow =
        HPlusSanitizeRect(
            [targetView
                convertRect:targetView.bounds
                     toView:window]
        );

    NSString *frameInfo =
        [NSString stringWithFormat:
            @"Frame: (%.0f, %.0f, %.0f, %.0f)",
            frameInWindow.origin.x,
            frameInWindow.origin.y,
            frameInWindow.size.width,
            frameInWindow.size.height];

    NSString *imageInfo =
        [self getImageInfoForView:targetView];

    UIViewController *viewController =
        [self viewControllerForView:targetView];

    NSString *controllerName =
        viewController
            ? HPlusClassName([viewController class])
            : nil;

    // ========================================================
    // Highlight
    // ========================================================

    [self
        showHighlightOverlayForView:targetView
        inWindow:window];

    // ========================================================
    // Initial Alert
    // ========================================================

    NSMutableString *message =
        [NSMutableString string];

    [message appendFormat:
        @"🎯 Target: %@\n\n",
        className];

    if (controllerName.length) {

        [message appendFormat:
            @"🎬 Controller: %@\n\n",
            controllerName];
    }

    [message appendFormat:
        @"📊 Hierarchy:\n%@\n\n",
        classChain];

    [message appendFormat:
        @"🧭 Path:\n%@\n\n",
        viewPath];

    if (identifier.length) {

        [message appendFormat:
            @"🔑 ID: %@\n\n",
            identifier];
    }

    [message appendFormat:
        @"📝 Text: %@\n\n",
        extractedText.length
            ? extractedText
            : @"(None)"];

    if (imageInfo.length) {

        [message appendFormat:
            @"🖼 %@\n\n",
            imageInfo];
    }

    [message appendFormat:
        @"📍 %@\n\n",
        frameInfo];

    [message appendFormat:
        @"👆 Interaction: %@\n\n",
        targetView.userInteractionEnabled
            ? @"Enabled"
            : @"Disabled"];

    [message appendString:
        @"⏳ Scanning subviews..."];

    __block NSArray<HPlusFoundItem *> *allFound =
        @[];

    __weak typeof(self) weakSelf = self;

    UIAlertController *alert =
        [UIAlertController
            alertControllerWithTitle:
                @"🔍 HPlus Inspector"
            message:message
            preferredStyle:
                UIAlertControllerStyleAlert];

    // ========================================================
    // Copy ID
    // ========================================================

    if (identifier.length) {

        [alert
            addAction:
            [UIAlertAction
                actionWithTitle:@"📋 Copy ID"
                          style:UIAlertActionStyleDefault
                        handler:^(UIAlertAction *action) {

            __strong typeof(weakSelf) strongSelf =
                weakSelf;

            if (!strongSelf) {
                return;
            }

            [strongSelf
                copyStringToPasteboard:identifier];
        }]];
    }

    // ========================================================
    // Copy Text
    // ========================================================

    if (extractedText.length &&
        !(secure &&
          HPlusSettings.protectSecureFields)) {

        [alert
            addAction:
            [UIAlertAction
                actionWithTitle:@"📝 Copy Text"
                          style:UIAlertActionStyleDefault
                        handler:^(UIAlertAction *action) {

            __strong typeof(weakSelf) strongSelf =
                weakSelf;

            if (!strongSelf) {
                return;
            }

            [strongSelf
                copyStringToPasteboard:extractedText];
        }]];
    }

    // ========================================================
    // Copy Hierarchy
    // ========================================================

    [alert
        addAction:
        [UIAlertAction
            actionWithTitle:@"📊 Copy Hierarchy"
                      style:UIAlertActionStyleDefault
                    handler:^(UIAlertAction *action) {

        __strong typeof(weakSelf) strongSelf =
            weakSelf;

        if (!strongSelf) {
            return;
        }

        [strongSelf
            copyStringToPasteboard:classChain];
    }]];

    // ========================================================
    // Copy JSON
    // ========================================================

    [alert
        addAction:
        [UIAlertAction
            actionWithTitle:@"🧩 Copy as JSON"
                      style:UIAlertActionStyleDefault
                    handler:^(UIAlertAction *action) {

        __strong typeof(weakSelf) strongSelf =
            weakSelf;

        if (!strongSelf ||
            allFound.count == 0) {

            return;
        }

        NSString *json =
            [strongSelf
                jsonStringFromFoundItems:allFound];

        [strongSelf
            copyStringToPasteboard:json];
    }]];

    // ========================================================
    // Share JSON
    // ========================================================

    [alert
        addAction:
        [UIAlertAction
            actionWithTitle:@"📤 Share JSON"
                      style:UIAlertActionStyleDefault
                    handler:^(UIAlertAction *action) {

        __strong typeof(weakSelf) strongSelf =
            weakSelf;

        if (!strongSelf ||
            allFound.count == 0) {

            return;
        }

        NSString *json =
            [strongSelf
                jsonStringFromFoundItems:allFound];

        UIActivityViewController *activity =
            [[UIActivityViewController alloc]
                initWithActivityItems:@[json]
                applicationActivities:nil];

        UIViewController *vc =
            [strongSelf topViewController];

        if (!vc) {
            return;
        }

        if (activity.popoverPresentationController) {

            activity.popoverPresentationController.sourceView =
                vc.view;

            activity.popoverPresentationController.sourceRect =
                CGRectMake(
                    vc.view.bounds.size.width / 2.0,
                    vc.view.bounds.size.height / 2.0,
                    1,
                    1
                );
        }

        [vc
            presentViewController:activity
            animated:YES
            completion:nil];
    }]];

    // ========================================================
    // Find By ID
    // ========================================================

    [alert
        addAction:
        [UIAlertAction
            actionWithTitle:@"🔎 Find by ID"
                      style:UIAlertActionStyleDefault
                    handler:^(UIAlertAction *action) {

        __strong typeof(weakSelf) strongSelf =
            weakSelf;

        if (!strongSelf) {
            return;
        }

        dispatch_async(dispatch_get_main_queue(), ^{
            [strongSelf presentFindByIDPrompt];
        });
    }]];

    // ========================================================
    // Close
    // ========================================================

    [alert
        addAction:
        [UIAlertAction
            actionWithTitle:@"👌 OK"
                      style:UIAlertActionStyleCancel
                    handler:^(UIAlertAction *action) {

        __strong typeof(weakSelf) strongSelf =
            weakSelf;

        if (strongSelf) {

            [strongSelf
                removeHighlightOverlay];

            [strongSelf
                cleanupFallbackWindow];
        }
    }]];

    // ========================================================
    // Present
    // ========================================================

    [self presentAlert:alert
            fromWindow:window];

    // ========================================================
    // Scan
    // ========================================================

    self.scanInProgress = YES;

    dispatch_async(dispatch_get_main_queue(), ^{

        __strong typeof(weakSelf) strongSelf =
            weakSelf;

        if (!strongSelf) {
            return;
        }

        NSArray<HPlusFoundItem *> *found =
            [strongSelf
                collectAllIdentifiersInView:targetView];

        allFound =
            found ?: @[];

        strongSelf.scanInProgress = NO;

        alert.title =
            [NSString stringWithFormat:
                @"🔍 HPlus (%lu عنصر)",
                (unsigned long)allFound.count];

        if (allFound.count == 0) {

            alert.message =
                [NSString stringWithFormat:
                    @"%@\n\n⚠️ لم يتم العثور على عناصر قابلة للعرض.",
                    message];

        } else {

            alert.message =
                [NSString stringWithFormat:
                    @"%@\n\n✅ تم العثور على %lu عنصر.",
                    message,
                    (unsigned long)allFound.count];
        }
    });
}

@end