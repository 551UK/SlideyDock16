/*
 * Infinidock 16 Revival
 *
 * The original Infinidock implementation is:
 * Copyright (c) 2010-2014, Xuzz Productions, LLC
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 *
 * 1. Redistributions of source code must retain the above copyright notice,
 *    this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright notice,
 *    this list of conditions and the following disclaimer in the documentation
 *    and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
 * AND ANY EXPRESS OR IMPLIED WARRANTIES ARE DISCLAIMED.
 */

#import <UIKit/UIKit.h>
#import <math.h>
#import <objc/runtime.h>
#import "PrivateHeaders.h"

static const NSUInteger IF16MaximumDockIcons = 100;
static const NSUInteger IF16DefaultIconsPerPage = 4;
static NSString *const IF16PreferencesDomain = @"uk.551.slideydock16";
static NSString *const IF16EnableMarker =
    @"/var/mobile/Library/Preferences/uk.551.slideydock16.enable";
static NSString *const IF16DiagnosticsPath =
    @"/var/mobile/Library/Preferences/uk.551.slideydock16.diagnostics.plist";

static void *IF16ScrollViewKey = &IF16ScrollViewKey;
static void *IF16ContentViewKey = &IF16ContentViewKey;
static void *IF16AnchorYKey = &IF16AnchorYKey;
static void *IF16ReportedListKey = &IF16ReportedListKey;
static void *IF16LayoutPendingKey = &IF16LayoutPendingKey;
static void *IF16DeferredReportedKey = &IF16DeferredReportedKey;
static void *IF16OriginHookCountKey = &IF16OriginHookCountKey;
static void *IF16LastCoordinateKey = &IF16LastCoordinateKey;
static void *IF16LastOriginalOriginKey = &IF16LastOriginalOriginKey;
static void *IF16LastAdjustedOriginKey = &IF16LastAdjustedOriginKey;
static void *IF16OwnerListKey = &IF16OwnerListKey;
static void *IF16PositionCorrectionCountKey = &IF16PositionCorrectionCountKey;
static void *IF16LastCorrectedIconIndexKey = &IF16LastCorrectedIconIndexKey;
static void *IF16LastCorrectedIconFrameKey = &IF16LastCorrectedIconFrameKey;
static void *IF16ExtentReportPendingKey = &IF16ExtentReportPendingKey;

static UIScrollView *IF16ScrollView(SBDockIconListView *listView);
static NSArray<SBIconView *> *IF16SortedIconViews(SBDockIconListView *listView);
static UIView *IF16DockBackgroundView(SBDockIconListView *listView);

static id IF16PreferenceValue(NSString *key) {
    return CFBridgingRelease(
        CFPreferencesCopyAppValue(
            (__bridge CFStringRef)key,
            (__bridge CFStringRef)IF16PreferencesDomain
        )
    );
}

static BOOL IF16TweakEnabled(void) {
    id value = IF16PreferenceValue(@"Enabled");
    return value != nil ? [value boolValue] : YES;
}

// Fixed Dock mode keeps the complete icon model in place, but prevents
// horizontal scrolling; restoring scrolling reveals any off-screen apps.
static BOOL IF16ScrollingEnabled(void) {
    id value = IF16PreferenceValue(@"ScrollingEnabled");
    return value != nil ? [value boolValue] : YES;
}

static BOOL IF16PagingEnabled(void) {
    id value = IF16PreferenceValue(@"PagingEnabled");
    return value != nil ? [value boolValue] : YES;
}

static NSUInteger IF16IconsPerPage(void) {
    static NSUInteger visibleIcons = IF16DefaultIconsPerPage;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        id value = IF16PreferenceValue(@"VisibleIconsPerPage");
        NSInteger selected = [value respondsToSelector:@selector(integerValue)]
            ? [value integerValue] : 4;
        visibleIcons = (selected >= 4 && selected <= 6)
            ? (NSUInteger)selected : IF16DefaultIconsPerPage;
    });
    return visibleIcons;
}

static void IF16WriteDiagnostics(NSString *phase, SBDockIconListView *listView) {
    NSFileManager *fileManager = NSFileManager.defaultManager;
    NSMutableDictionary *report = [NSMutableDictionary dictionary];
    report[@"Build"] = @"1.4.2-1";
    report[@"Phase"] = phase ?: @"unknown";
    report[@"Timestamp"] = [NSDate date];
    report[@"SystemVersion"] = NSProcessInfo.processInfo.operatingSystemVersionString;
    report[@"EnableMarkerExists"] = @([fileManager fileExistsAtPath:IF16EnableMarker]);
    report[@"MasterEnabled"] = @(IF16TweakEnabled());
    report[@"PagingEnabled"] = @(IF16PagingEnabled());
    report[@"ScrollingEnabled"] = @(IF16ScrollingEnabled());
    report[@"VisibleIconsPerPage"] = @(IF16IconsPerPage());
    report[@"LegacyRootDockClass"] =
        NSStringFromClass(NSClassFromString(@"SBRootFolderDockIconListView")) ?: @"missing";
    report[@"DockClass"] =
        NSStringFromClass(NSClassFromString(@"SBDockIconListView")) ?: @"missing";
    report[@"RootFolderWithDockClass"] =
        NSStringFromClass(NSClassFromString(@"SBRootFolderWithDock")) ?: @"missing";
    report[@"ModelClass"] =
        NSStringFromClass(NSClassFromString(@"SBIconListModel")) ?: @"missing";
    report[@"ProviderClass"] =
        NSStringFromClass(NSClassFromString(@"SBHDefaultIconListLayoutProvider")) ?: @"missing";

    if (listView != nil) {
        report[@"ObservedListClass"] = NSStringFromClass(listView.class) ?: @"unknown";
        report[@"ObservedListFrame"] = NSStringFromCGRect(listView.frame);
        report[@"ObservedVisibleIconCount"] = @(listView.visibleIcons.count);
        report[@"ScrollerInstalled"] = @(IF16ScrollView(listView) != nil);
        report[@"ObservedIconViewCount"] = @(IF16SortedIconViews(listView).count);
        report[@"ObservedContentSize"] =
            NSStringFromCGSize(IF16ScrollView(listView).contentSize);
        report[@"OriginHookCallCount"] =
            objc_getAssociatedObject(listView, IF16OriginHookCountKey) ?: @0;
        report[@"LastIconCoordinate"] =
            objc_getAssociatedObject(listView, IF16LastCoordinateKey) ?: @"not-observed";
        report[@"LastOriginalOrigin"] =
            objc_getAssociatedObject(listView, IF16LastOriginalOriginKey) ?: @"not-observed";
        report[@"LastAdjustedOrigin"] =
            objc_getAssociatedObject(listView, IF16LastAdjustedOriginKey) ?: @"not-observed";
        report[@"PositionCorrectionCallCount"] =
            objc_getAssociatedObject(listView, IF16PositionCorrectionCountKey) ?: @0;
        report[@"LastCorrectedIconIndex"] =
            objc_getAssociatedObject(listView, IF16LastCorrectedIconIndexKey) ?: @"not-observed";
        report[@"LastCorrectedIconFrame"] =
            objc_getAssociatedObject(listView, IF16LastCorrectedIconFrameKey) ?: @"not-observed";
        UIView *dockBackgroundView = IF16DockBackgroundView(listView);
        report[@"ObservedBackgroundClass"] =
            dockBackgroundView != nil
                ? (NSStringFromClass(dockBackgroundView.class) ?: @"unknown")
                : @"missing";
        if (dockBackgroundView != nil) {
            report[@"ObservedBackgroundFrame"] =
                NSStringFromCGRect([listView convertRect:dockBackgroundView.bounds
                                                fromView:dockBackgroundView]);
        }
    }

    BOOL wrote = [report writeToFile:IF16DiagnosticsPath atomically:YES];
    NSLog(
        @"[SlideyDock16] Diagnostics phase=%@ wrote=%d path=%@",
        phase,
        wrote,
        IF16DiagnosticsPath
    );
}

static BOOL IF16IsIconView(id object) {
    Class iconViewClass = NSClassFromString(@"SBIconView");
    return iconViewClass != Nil && [object isKindOfClass:iconViewClass];
}

static UIScrollView *IF16ScrollView(SBDockIconListView *listView) {
    return objc_getAssociatedObject(listView, IF16ScrollViewKey);
}

static UIView *IF16ContentView(SBDockIconListView *listView) {
    return objc_getAssociatedObject(listView, IF16ContentViewKey);
}

static UIView *IF16DockBackgroundView(SBDockIconListView *listView) {
    for (UIView *ancestor = listView.superview;
         ancestor != nil;
         ancestor = ancestor.superview) {
        NSString *className = NSStringFromClass(ancestor.class) ?: @"";
        if (![className containsString:@"DockView"] ||
            ![ancestor respondsToSelector:@selector(backgroundView)]) {
            continue;
        }

        UIView *backgroundView = [(SBDockView *)ancestor backgroundView];
        if ([backgroundView isKindOfClass:UIView.class] &&
            !backgroundView.hidden &&
            CGRectGetWidth(backgroundView.bounds) > 0.0 &&
            CGRectGetHeight(backgroundView.bounds) > 0.0) {
            return backgroundView;
        }
    }
    return nil;
}

static NSArray<SBIconView *> *IF16SortedIconViews(SBDockIconListView *listView) {
    UIView *contentView = IF16ContentView(listView);
    if (contentView == nil) {
        return @[];
    }

    NSMutableArray<SBIconView *> *iconViews = [NSMutableArray array];
    for (UIView *view in contentView.subviews) {
        if (IF16IsIconView(view)) {
            [iconViews addObject:(SBIconView *)view];
        }
    }

    NSArray *visibleIcons = nil;
    if ([listView respondsToSelector:@selector(visibleIcons)]) {
        visibleIcons = listView.visibleIcons;
    }

    [iconViews sortUsingComparator:^NSComparisonResult(SBIconView *left, SBIconView *right) {
        if (visibleIcons != nil &&
            [left respondsToSelector:@selector(icon)] &&
            [right respondsToSelector:@selector(icon)]) {
            NSUInteger leftIndex = [visibleIcons indexOfObjectIdenticalTo:left.icon];
            NSUInteger rightIndex = [visibleIcons indexOfObjectIdenticalTo:right.icon];
            if (leftIndex != NSNotFound && rightIndex != NSNotFound && leftIndex != rightIndex) {
                return leftIndex < rightIndex ? NSOrderedAscending : NSOrderedDescending;
            }
        }

        if (CGRectGetMinX(left.frame) == CGRectGetMinX(right.frame)) {
            return NSOrderedSame;
        }
        return CGRectGetMinX(left.frame) < CGRectGetMinX(right.frame)
            ? NSOrderedAscending
            : NSOrderedDescending;
    }];

    return iconViews;
}

static void IF16CaptureAnchorY(SBDockIconListView *listView, UIView *iconView) {
    if (objc_getAssociatedObject(listView, IF16AnchorYKey) != nil) {
        return;
    }

    CGFloat centerY = CGRectGetMidY(iconView.frame);
    if (isfinite(centerY) && centerY > 0.0) {
        objc_setAssociatedObject(
            listView,
            IF16AnchorYKey,
            @(centerY),
            OBJC_ASSOCIATION_RETAIN_NONATOMIC
        );
    }
}

static void IF16MoveExistingIconsIntoScrollView(SBDockIconListView *listView) {
    UIView *contentView = IF16ContentView(listView);
    if (contentView == nil) {
        return;
    }

    for (UIView *view in [listView.subviews copy]) {
        if (!IF16IsIconView(view)) {
            continue;
        }
        IF16CaptureAnchorY(listView, view);
        [contentView addSubview:view];
    }
}

static void IF16InstallScrollViewIfNeeded(SBDockIconListView *listView) {
    if (IF16ScrollView(listView) != nil || listView.bounds.size.width <= 0.0) {
        return;
    }

    UIScrollView *scrollView = [[UIScrollView alloc] initWithFrame:listView.bounds];
    scrollView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    scrollView.backgroundColor = UIColor.clearColor;
    scrollView.clipsToBounds = YES;
    scrollView.scrollEnabled = IF16ScrollingEnabled();
    scrollView.pagingEnabled = IF16ScrollingEnabled() && IF16PagingEnabled();
    scrollView.decelerationRate =
        scrollView.pagingEnabled
            ? UIScrollViewDecelerationRateFast
            : UIScrollViewDecelerationRateNormal;
    scrollView.bounces = IF16ScrollingEnabled();
    scrollView.alwaysBounceHorizontal = IF16ScrollingEnabled();
    scrollView.alwaysBounceVertical = NO;
    scrollView.showsHorizontalScrollIndicator = NO;
    scrollView.showsVerticalScrollIndicator = NO;
    scrollView.directionalLockEnabled = YES;

    UIView *contentView = [[UIView alloc] initWithFrame:scrollView.bounds];
    contentView.backgroundColor = UIColor.clearColor;
    objc_setAssociatedObject(
        contentView,
        IF16OwnerListKey,
        listView,
        OBJC_ASSOCIATION_ASSIGN
    );
    [scrollView addSubview:contentView];

    objc_setAssociatedObject(
        listView,
        IF16ScrollViewKey,
        scrollView,
        OBJC_ASSOCIATION_RETAIN_NONATOMIC
    );
    objc_setAssociatedObject(
        listView,
        IF16ContentViewKey,
        contentView,
        OBJC_ASSOCIATION_RETAIN_NONATOMIC
    );

    [listView insertSubview:scrollView atIndex:0];
    IF16MoveExistingIconsIntoScrollView(listView);
    NSLog(@"[SlideyDock16] Installed scroller on %@", listView);
}

static SBDockIconListView *IF16OwningListView(SBIconView *iconView) {
    UIView *superview = iconView.superview;
    id owner = superview != nil
        ? objc_getAssociatedObject(superview, IF16OwnerListKey)
        : nil;
    Class dockClass = NSClassFromString(@"SBDockIconListView");
    if (owner != nil && dockClass != Nil && [owner isKindOfClass:dockClass]) {
        return (SBDockIconListView *)owner;
    }
    return nil;
}

static NSUInteger IF16IndexForIconView(
    SBDockIconListView *listView,
    SBIconView *iconView
) {
    NSArray *visibleIcons = listView.visibleIcons;
    if (visibleIcons != nil && [iconView respondsToSelector:@selector(icon)]) {
        NSUInteger modelIndex =
            [visibleIcons indexOfObjectIdenticalTo:iconView.icon];
        if (modelIndex != NSNotFound) {
            return modelIndex;
        }
    }

    UIView *contentView = IF16ContentView(listView);
    NSUInteger fallbackIndex = 0;
    for (UIView *view in contentView.subviews) {
        if (!IF16IsIconView(view)) {
            continue;
        }
        if (view == iconView) {
            return fallbackIndex;
        }
        fallbackIndex++;
    }
    return NSNotFound;
}

static void IF16UpdateScrollExtent(
    SBDockIconListView *listView,
    NSUInteger minimumIconCount
) {
    UIScrollView *scrollView = IF16ScrollView(listView);
    UIView *contentView = IF16ContentView(listView);
    if (scrollView == nil || contentView == nil) {
        return;
    }

    CGFloat pageWidth = CGRectGetWidth(scrollView.bounds);
    CGFloat pageHeight = CGRectGetHeight(scrollView.bounds);
    if (!isfinite(pageWidth) ||
        !isfinite(pageHeight) ||
        pageWidth <= 0.0 ||
        pageHeight <= 0.0) {
        return;
    }

    NSUInteger iconCount = MAX(listView.visibleIcons.count, minimumIconCount);
    NSUInteger pageCount = MAX(
        (NSUInteger)1,
        (iconCount + IF16IconsPerPage() - 1) / IF16IconsPerPage()
    );
    CGSize contentSize = CGSizeMake(pageWidth * pageCount, pageHeight);
    if (CGSizeEqualToSize(scrollView.contentSize, contentSize) &&
        CGSizeEqualToSize(contentView.frame.size, contentSize)) {
        return;
    }

    scrollView.contentSize = contentSize;
    contentView.frame = (CGRect){ CGPointZero, contentSize };

    if (pageCount > 1 &&
        objc_getAssociatedObject(listView, IF16ExtentReportPendingKey) == nil) {
        objc_setAssociatedObject(
            listView,
            IF16ExtentReportPendingKey,
            @YES,
            OBJC_ASSOCIATION_RETAIN_NONATOMIC
        );
        __weak SBDockIconListView *weakListView = listView;
        dispatch_async(dispatch_get_main_queue(), ^{
            SBDockIconListView *strongListView = weakListView;
            if (strongListView == nil) {
                return;
            }
            objc_setAssociatedObject(
                strongListView,
                IF16ExtentReportPendingKey,
                nil,
                OBJC_ASSOCIATION_RETAIN_NONATOMIC
            );
            IF16WriteDiagnostics(@"scroll-extent-updated", strongListView);
        });
    }
}

static BOOL IF16CorrectedCenterForIconView(
    SBIconView *iconView,
    CGPoint *correctedCenter,
    NSUInteger *correctedIndex
) {
    SBDockIconListView *listView = IF16OwningListView(iconView);
    UIScrollView *scrollView =
        listView != nil ? IF16ScrollView(listView) : nil;
    if (listView == nil || scrollView == nil) {
        return NO;
    }

    NSUInteger iconIndex = IF16IndexForIconView(listView, iconView);
    CGFloat pageWidth = CGRectGetWidth(scrollView.bounds);
    CGFloat pageHeight = CGRectGetHeight(scrollView.bounds);
    if (iconIndex == NSNotFound ||
        !isfinite(pageWidth) ||
        !isfinite(pageHeight) ||
        pageWidth <= 0.0 ||
        pageHeight <= 0.0) {
        return NO;
    }

    IF16UpdateScrollExtent(listView, iconIndex + 1);

    CGFloat slotWidth = pageWidth / IF16IconsPerPage();
    *correctedCenter = CGPointMake(
        slotWidth * ((CGFloat)iconIndex + 0.5),
        pageHeight / 2.0
    );
    if (correctedIndex != NULL) {
        *correctedIndex = iconIndex;
    }
    return YES;
}

static void IF16RecordPositionCorrection(
    SBDockIconListView *listView,
    NSUInteger iconIndex,
    CGRect correctedFrame
) {
    NSNumber *previousCount =
        objc_getAssociatedObject(listView, IF16PositionCorrectionCountKey);
    objc_setAssociatedObject(
        listView,
        IF16PositionCorrectionCountKey,
        @((previousCount != nil ? previousCount.unsignedIntegerValue : 0) + 1),
        OBJC_ASSOCIATION_RETAIN_NONATOMIC
    );
    objc_setAssociatedObject(
        listView,
        IF16LastCorrectedIconIndexKey,
        @(iconIndex),
        OBJC_ASSOCIATION_RETAIN_NONATOMIC
    );
    objc_setAssociatedObject(
        listView,
        IF16LastCorrectedIconFrameKey,
        NSStringFromCGRect(correctedFrame),
        OBJC_ASSOCIATION_RETAIN_NONATOMIC
    );
}

static void IF16LayoutDock(SBDockIconListView *listView) {
    UIScrollView *scrollView = IF16ScrollView(listView);
    UIView *contentView = IF16ContentView(listView);
    if (scrollView == nil || contentView == nil) {
        return;
    }

    UIView *dockBackgroundView = IF16DockBackgroundView(listView);
    CGRect scrollFrame = listView.bounds;
    if (dockBackgroundView != nil) {
        CGRect convertedBackgroundFrame =
            [listView convertRect:dockBackgroundView.bounds fromView:dockBackgroundView];
        if (isfinite(CGRectGetMinX(convertedBackgroundFrame)) &&
            isfinite(CGRectGetMinY(convertedBackgroundFrame)) &&
            CGRectGetWidth(convertedBackgroundFrame) > 0.0 &&
            CGRectGetHeight(convertedBackgroundFrame) > 0.0) {
            scrollFrame = convertedBackgroundFrame;
        }
    }
    scrollView.frame = scrollFrame;
    // Fixed mode deliberately leaves the icon model intact while making the
    // Dock non-scrollable. Only the selected visible slots are on screen.
    if (!IF16ScrollingEnabled()) {
        scrollView.scrollEnabled = NO;
        scrollView.pagingEnabled = NO;
        scrollView.bounces = NO;
        scrollView.alwaysBounceHorizontal = NO;
        if (!CGPointEqualToPoint(scrollView.contentOffset, CGPointZero)) {
            scrollView.contentOffset = CGPointZero;
        }
    }
    listView.clipsToBounds = NO;
    scrollView.clipsToBounds = YES;
    CGFloat backgroundCornerRadius =
        dockBackgroundView != nil ? dockBackgroundView.layer.cornerRadius : 0.0;
    scrollView.layer.cornerRadius =
        backgroundCornerRadius > 0.0
            ? backgroundCornerRadius
            : MIN(CGRectGetHeight(scrollView.bounds) / 2.0, 32.0);
    scrollView.layer.masksToBounds = YES;

    NSArray<SBIconView *> *iconViews = IF16SortedIconViews(listView);
    CGFloat pageWidth = CGRectGetWidth(scrollView.bounds);
    CGFloat pageHeight = CGRectGetHeight(scrollView.bounds);
    if (pageWidth <= 0.0 || pageHeight <= 0.0) {
        return;
    }

    CGFloat slotWidth = pageWidth / IF16IconsPerPage();
    NSUInteger iconCount = MAX(iconViews.count, listView.visibleIcons.count);
    IF16UpdateScrollExtent(listView, iconCount);

    CGFloat anchorY = pageHeight / 2.0;

    [iconViews enumerateObjectsUsingBlock:^(SBIconView *iconView, NSUInteger index, BOOL *stop) {
        (void)stop;
        IF16CaptureAnchorY(listView, iconView);
        CGFloat centerX = slotWidth * ((CGFloat)index + 0.5);
        iconView.center = CGPointMake(centerX, anchorY);
    }];
}

static void IF16ScheduleDeferredLayout(SBDockIconListView *listView) {
    if (objc_getAssociatedObject(listView, IF16LayoutPendingKey) != nil) {
        return;
    }

    objc_setAssociatedObject(
        listView,
        IF16LayoutPendingKey,
        @YES,
        OBJC_ASSOCIATION_RETAIN_NONATOMIC
    );

    __weak SBDockIconListView *weakListView = listView;
    dispatch_async(dispatch_get_main_queue(), ^{
        SBDockIconListView *strongListView = weakListView;
        if (strongListView == nil) {
            return;
        }

        objc_setAssociatedObject(
            strongListView,
            IF16LayoutPendingKey,
            nil,
            OBJC_ASSOCIATION_RETAIN_NONATOMIC
        );
        IF16MoveExistingIconsIntoScrollView(strongListView);
        IF16LayoutDock(strongListView);

        if (objc_getAssociatedObject(strongListView, IF16DeferredReportedKey) == nil) {
            objc_setAssociatedObject(
                strongListView,
                IF16DeferredReportedKey,
                @YES,
                OBJC_ASSOCIATION_RETAIN_NONATOMIC
            );
            IF16WriteDiagnostics(@"deferred-layout-applied", strongListView);
        }
    });
}

%group SlideyDock16Base

%hook SBDockIconListView

+ (unsigned long long)maxIcons {
    return IF16MaximumDockIcons;
}

- (CGPoint)originForIconAtCoordinate:(IF16IconCoordinate)coordinate
                       numberOfIcons:(unsigned long long)numberOfIcons {
    CGPoint originalOrigin = %orig;

    NSNumber *previousCount =
        objc_getAssociatedObject(self, IF16OriginHookCountKey);
    objc_setAssociatedObject(
        self,
        IF16OriginHookCountKey,
        @((previousCount != nil ? previousCount.unsignedIntegerValue : 0) + 1),
        OBJC_ASSOCIATION_RETAIN_NONATOMIC
    );
    objc_setAssociatedObject(
        self,
        IF16LastCoordinateKey,
        [NSString stringWithFormat:
            @"row=%lld col=%lld numberOfIcons=%llu",
            coordinate.row,
            coordinate.col,
            numberOfIcons],
        OBJC_ASSOCIATION_RETAIN_NONATOMIC
    );
    objc_setAssociatedObject(
        self,
        IF16LastOriginalOriginKey,
        NSStringFromCGPoint(originalOrigin),
        OBJC_ASSOCIATION_RETAIN_NONATOMIC
    );

    /*
     * SpringBoard coordinates are one-based. The provider still exposes a
     * large single row so the model accepts more than four icons, but the
     * final origin is calculated as four, five, or six fixed-width slots per scroll page.
     * Hooking this final calculation prevents a later SpringBoard layout pass
     * from compressing every icon into the first page.
     */
    if (coordinate.col < 1) {
        return originalOrigin;
    }

    UIView *dockBackgroundView = IF16DockBackgroundView(self);
    CGFloat pageWidth = CGRectGetWidth(self.bounds);
    if (dockBackgroundView != nil) {
        CGRect convertedBackgroundFrame =
            [self convertRect:dockBackgroundView.bounds fromView:dockBackgroundView];
        if (CGRectGetWidth(convertedBackgroundFrame) > 0.0) {
            pageWidth = CGRectGetWidth(convertedBackgroundFrame);
        }
    }
    if (!isfinite(pageWidth) || pageWidth <= 0.0) {
        return originalOrigin;
    }

    NSUInteger zeroBasedIndex = (NSUInteger)(coordinate.col - 1);
    NSUInteger page = zeroBasedIndex / IF16IconsPerPage();
    NSUInteger slot = zeroBasedIndex % IF16IconsPerPage();
    CGFloat slotWidth = pageWidth / IF16IconsPerPage();

    CGFloat iconWidth = 60.0;
    NSArray<SBIconView *> *iconViews = IF16SortedIconViews(self);
    if (iconViews.count > 0 && CGRectGetWidth(iconViews.firstObject.bounds) > 0.0) {
        iconWidth = CGRectGetWidth(iconViews.firstObject.bounds);
    } else if ([self respondsToSelector:@selector(defaultIconSize)]) {
        CGSize defaultIconSize = [self defaultIconSize];
        if (isfinite(defaultIconSize.width) && defaultIconSize.width > 0.0) {
            iconWidth = defaultIconSize.width;
        }
    }

    CGPoint adjustedOrigin = originalOrigin;
    adjustedOrigin.x =
        pageWidth * page +
        slotWidth * ((CGFloat)slot + 0.5) -
        iconWidth / 2.0;
    objc_setAssociatedObject(
        self,
        IF16LastAdjustedOriginKey,
        NSStringFromCGPoint(adjustedOrigin),
        OBJC_ASSOCIATION_RETAIN_NONATOMIC
    );
    return adjustedOrigin;
}

- (void)didMoveToWindow {
    %orig;
    IF16InstallScrollViewIfNeeded(self);
    IF16MoveExistingIconsIntoScrollView(self);
    IF16LayoutDock(self);
    IF16ScheduleDeferredLayout(self);
    if (objc_getAssociatedObject(self, IF16ReportedListKey) == nil) {
        objc_setAssociatedObject(
            self,
            IF16ReportedListKey,
            @YES,
            OBJC_ASSOCIATION_RETAIN_NONATOMIC
        );
        IF16WriteDiagnostics(@"dock-did-move-to-window", self);
    }
}

- (void)addSubview:(UIView *)view {
    UIView *contentView = IF16ContentView(self);
    if (contentView != nil && IF16IsIconView(view)) {
        IF16CaptureAnchorY(self, view);
        [contentView addSubview:view];
        return;
    }
    %orig;
}

- (void)layoutSubviews {
    IF16InstallScrollViewIfNeeded(self);
    %orig;
    IF16MoveExistingIconsIntoScrollView(self);
    IF16LayoutDock(self);
    IF16ScheduleDeferredLayout(self);
}

%end

%hook SBIconView

- (void)setCenter:(CGPoint)center {
    CGPoint correctedCenter = center;
    NSUInteger iconIndex = NSNotFound;
    SBDockIconListView *listView = IF16OwningListView(self);
    if (IF16CorrectedCenterForIconView(self, &correctedCenter, &iconIndex)) {
        CGRect correctedFrame = self.frame;
        correctedFrame.origin.x =
            correctedCenter.x - CGRectGetWidth(correctedFrame) / 2.0;
        correctedFrame.origin.y =
            correctedCenter.y - CGRectGetHeight(correctedFrame) / 2.0;
        IF16RecordPositionCorrection(listView, iconIndex, correctedFrame);
    }
    %orig(correctedCenter);
}

- (void)setFrame:(CGRect)frame {
    CGPoint correctedCenter = CGPointMake(
        CGRectGetMidX(frame),
        CGRectGetMidY(frame)
    );
    NSUInteger iconIndex = NSNotFound;
    SBDockIconListView *listView = IF16OwningListView(self);
    if (IF16CorrectedCenterForIconView(self, &correctedCenter, &iconIndex)) {
        frame.origin.x =
            correctedCenter.x - CGRectGetWidth(frame) / 2.0;
        frame.origin.y =
            correctedCenter.y - CGRectGetHeight(frame) / 2.0;
        IF16RecordPositionCorrection(listView, iconIndex, frame);
    }
    %orig(frame);
}

%end

%hook SBIconListModel

- (instancetype)initWithFolder:(id)folder maxIconCount:(unsigned long long)maxIconCount {
    Class dockFolderClass = NSClassFromString(@"SBRootFolderWithDock");
    NSString *folderClassName = NSStringFromClass([folder class]) ?: @"";
    BOOL explicitDockFolder =
        dockFolderClass != Nil && [folder isKindOfClass:dockFolderClass];
    BOOL likelyStockDockModel =
        maxIconCount == 4 && [folderClassName containsString:@"RootFolder"];
    BOOL exactFourIconModel = maxIconCount == 4;
    if ((explicitDockFolder || likelyStockDockModel || exactFourIconModel) &&
        maxIconCount < IF16MaximumDockIcons) {
        NSLog(
            @"[SlideyDock16] Raising dock model capacity from %llu to %lu",
            maxIconCount,
            (unsigned long)IF16MaximumDockIcons
        );
        return %orig(folder, IF16MaximumDockIcons);
    }
    return %orig;
}

%end

%end

%group SlideyDock16Provider

%hook SBHDefaultIconListLayoutProvider

- (id)layoutForIconLocation:(id)iconLocation {
    id layout = %orig;
    if (![iconLocation isKindOfClass:NSString.class] ||
        ![(NSString *)iconLocation isEqualToString:@"SBIconLocationDock"]) {
        return layout;
    }

    if ([layout respondsToSelector:@selector(layoutConfiguration)]) {
        SBIconListGridLayoutConfiguration *configuration =
            [(SBIconListGridLayout *)layout layoutConfiguration];
        if ([configuration respondsToSelector:@selector(setNumberOfPortraitRows:)]) {
            configuration.numberOfPortraitRows = 1;
            configuration.numberOfLandscapeRows = 1;
            configuration.numberOfPortraitColumns = IF16MaximumDockIcons;
            configuration.numberOfLandscapeColumns = IF16MaximumDockIcons;
        }
    }
    return layout;
}

%end

%end

%ctor {
    @autoreleasepool {
        NSOperatingSystemVersion version = NSProcessInfo.processInfo.operatingSystemVersion;
        Class dockClass = NSClassFromString(@"SBDockIconListView");
        Class modelClass = NSClassFromString(@"SBIconListModel");
        Class providerClass = NSClassFromString(@"SBHDefaultIconListLayoutProvider");

        NSLog(
            @"[SlideyDock16] Probe: iOS %ld.%ld.%ld dock=%@ model=%@ provider=%@",
            (long)version.majorVersion,
            (long)version.minorVersion,
            (long)version.patchVersion,
            dockClass,
            modelClass,
            providerClass
        );
        IF16WriteDiagnostics(@"constructor-probe", nil);

        if (!IF16TweakEnabled()) {
            NSLog(
                @"[SlideyDock16] Disabled in Settings; hooks were not installed."
            );
            IF16WriteDiagnostics(@"disabled-in-settings", nil);
            return;
        }

        if (version.majorVersion >= 15 &&
            version.majorVersion <= 16 &&
            dockClass != Nil &&
            modelClass != Nil) {
            %init(SlideyDock16Base);
            if (providerClass != Nil) {
                %init(SlideyDock16Provider);
            }
            IF16WriteDiagnostics(
                providerClass != Nil
                    ? @"base-and-provider-hooks-enabled"
                    : @"base-hooks-enabled-provider-missing",
                nil
            );
            NSLog(@"[SlideyDock16] Base hooks enabled");
        } else {
            IF16WriteDiagnostics(@"unsupported-or-required-class-missing", nil);
            NSLog(@"[SlideyDock16] Unsupported runtime; hooks not installed");
        }
    }
}
