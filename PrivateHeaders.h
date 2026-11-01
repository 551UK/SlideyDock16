#import <UIKit/UIKit.h>

typedef struct {
    long long row;
    long long col;
} IF16IconCoordinate;

@interface SBIconView : UIView
@property (nonatomic, readonly) id icon;
@end

@interface SBIconListModel : NSObject
- (instancetype)initWithFolder:(id)folder maxIconCount:(unsigned long long)maxIconCount;
@end

@interface SBIconListGridLayoutConfiguration : NSObject
@property (nonatomic) unsigned long long numberOfPortraitRows;
@property (nonatomic) unsigned long long numberOfPortraitColumns;
@property (nonatomic) unsigned long long numberOfLandscapeRows;
@property (nonatomic) unsigned long long numberOfLandscapeColumns;
@end

@interface SBIconListGridLayout : NSObject
@property (nonatomic, readonly, copy) SBIconListGridLayoutConfiguration *layoutConfiguration;
@end

@interface SBHDefaultIconListLayoutProvider : NSObject
- (id)layoutForIconLocation:(id)iconLocation;
@end

@interface SBIconListView : UIView
@property (nonatomic, readonly, copy) NSArray *visibleIcons;
@property (nonatomic, copy) NSString *iconLocation;
- (CGSize)defaultIconSize;
@end

@interface SBDockIconListView : SBIconListView
- (CGPoint)originForIconAtCoordinate:(IF16IconCoordinate)coordinate
                       numberOfIcons:(unsigned long long)numberOfIcons;
@end

@interface SBDockView : UIView
@property (nonatomic, retain) UIView *backgroundView;
@end

@interface SBDockIconListView (SlideyDock16)
+ (unsigned long long)maxIcons;
@end
