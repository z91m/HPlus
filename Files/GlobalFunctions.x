#import "Headers.h"

// HPlus's bundle (For localizations)
NSBundle *HPlusBundle() {
    static NSBundle *bundle = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        // جرب تحميل الحزمة عن طريق المعرف الجديد
        bundle = [NSBundle bundleWithIdentifier:@"dev.hamad.hplus"];
        
        // لو ما لقاها، جرب المسار الجديد (احتياطي)
        if (!bundle) {
            bundle = [NSBundle bundleWithPath:@"/Library/Application Support/HPlus.bundle"];
        }
        
        // لو للحين ما لقاها (تأكيد إضافي)، جرب الـ MainBundle
        if (!bundle) {
            bundle = [NSBundle mainBundle];
        }
    });
    return bundle;
}

// YouTube icon image (YTIIcon)
UIImage *HPlusYTIconImage(NSInteger iconType, BOOL useCustomColor, UIColor *customColor) {
    YTIIcon *icon = [%c(YTIIcon) new];
    icon.iconType = iconType;
    UIColor *targetColor = (useCustomColor && customColor) ? customColor : [UIColor labelColor];
    return [icon iconImageWithColor:targetColor];
}

// Language list
NSArray *getAllSystemLanguageTitles() {
    NSMutableArray *titles = [NSMutableArray array];
    NSArray *allLocales = [%c(YTLanguages) languageList];
    NSMutableSet *seenLanguages = [NSMutableSet set];
    NSLocale *currentLocale = [NSLocale currentLocale];
    
    for (NSString *localeId in allLocales) {
        NSDictionary *components = [NSLocale componentsFromLocaleIdentifier:localeId];
        NSString *langCode = components[NSLocaleLanguageCode];
        
        if (langCode && ![seenLanguages containsObject:langCode]) {
            [seenLanguages addObject:langCode];
            NSString *displayName = [currentLocale localizedStringForLocaleIdentifier:langCode];
            if (displayName) [titles addObject:displayName];
        }
    }
    return [titles sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
}

NSArray *getAllSystemLanguageValues() {
    NSArray *sortedTitles = getAllSystemLanguageTitles();
    NSMutableArray *sortedCodes = [NSMutableArray array];
    NSArray *allLocales = [%c(YTLanguages) languageList];
    NSLocale *currentLocale = [NSLocale currentLocale];
    
    NSMutableDictionary *titleToCodeMap = [NSMutableDictionary dictionary];
    for (NSString *localeId in allLocales) {
        NSDictionary *components = [NSLocale componentsFromLocaleIdentifier:localeId];
        NSString *langCode = components[NSLocaleLanguageCode];
        if (langCode) {
            NSString *displayName = [currentLocale localizedStringForLocaleIdentifier:langCode];
            if (displayName) titleToCodeMap[displayName] = langCode;
        }
    }
    
    for (NSString *title in sortedTitles) {
        [sortedCodes addObject:titleToCodeMap[title] ? titleToCodeMap[title] : @"en"];
    }
    return [sortedCodes copy];
}

// Get TopViewController
UIViewController *HPlusTopViewController(UIViewController *root) {
    if (!root) {
        UIWindow *keyWindow = nil;
        for (UIWindow *window in UIApplication.sharedApplication.windows) {
            if (window.isKeyWindow) {
                keyWindow = window;
                break;
            }
        }
        root = keyWindow.rootViewController;
    }
    while (root.presentedViewController) root = root.presentedViewController;
    if ([root isKindOfClass:UINavigationController.class])
        return HPlusTopViewController(((UINavigationController *)root).topViewController);
    if ([root isKindOfClass:UITabBarController.class])
        return HPlusTopViewController(((UITabBarController *)root).selectedViewController);
    return root;
}

// OLEDKeyboard (https://github.com/dayanch96/OledKeyboard)
BOOL isDarkMode(UIView *view) {
    if ([view respondsToSelector:@selector(_mapkit_isDarkModeEnabled)]) {
        return view._mapkit_isDarkModeEnabled;
    }
    return view.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark;
}

BOOL isPad() {
    return UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPad;
}