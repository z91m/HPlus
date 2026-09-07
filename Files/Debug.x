%hook UIView
- (void)setAccessibilityIdentifier:(NSString *)accessibilityIdentifier {
    %orig;
    if (accessibilityIdentifier && accessibilityIdentifier.length > 0) {
        NSLog(@"HPlus_AllIDs -> %@", accessibilityIdentifier);
    }
}
%end
