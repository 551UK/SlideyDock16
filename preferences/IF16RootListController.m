#import "IF16RootListController.h"

#import <Preferences/PSSpecifier.h>
#import <Preferences/PSTableCell.h>
#import <QuartzCore/QuartzCore.h>
#import <spawn.h>
#import <unistd.h>

extern char **environ;

@interface IF16RootListController ()
@property (nonatomic, strong) UIView *dockHero;
@property (nonatomic, strong) CAGradientLayer *dockGradient;
@end

@implementation IF16RootListController

- (UITableViewStyle)tableViewStyle {
    return UITableViewStyleInsetGrouped;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.navigationItem.title = @"SlideyDock16";

    UITableView *table = self.table;
    if (!table) return;
    table.backgroundColor = UIColor.systemGroupedBackgroundColor;

    UIView *header = [[UIView alloc] initWithFrame:
        CGRectMake(0, 0, CGRectGetWidth(table.bounds), 142)];
    header.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    UIView *hero = [[UIView alloc] initWithFrame:
        CGRectMake(16, 16, MAX(0, CGRectGetWidth(header.bounds) - 32), 110)];
    hero.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    hero.layer.cornerRadius = 19;
    hero.layer.masksToBounds = YES;
    [header addSubview:hero];
    self.dockHero = hero;

    CAGradientLayer *gradient = [CAGradientLayer layer];
    gradient.colors = @[
        (__bridge id)[UIColor colorWithRed:0.10 green:0.16 blue:0.27 alpha:1].CGColor,
        (__bridge id)[UIColor colorWithRed:0.13 green:0.32 blue:0.44 alpha:1].CGColor
    ];
    gradient.startPoint = CGPointMake(0, 0);
    gradient.endPoint = CGPointMake(1, 1);
    gradient.frame = hero.bounds;
    [hero.layer insertSublayer:gradient atIndex:0];
    self.dockGradient = gradient;

    UIView *emblem = [UIView new];
    emblem.translatesAutoresizingMaskIntoConstraints = NO;
    emblem.backgroundColor = [UIColor colorWithRed:0.12 green:0.69 blue:0.92 alpha:1];
    emblem.layer.cornerRadius = 15;
    [hero addSubview:emblem];

    UIImage *symbol = [UIImage systemImageNamed:@"square.grid.3x1.fill"];
    if (!symbol) symbol = [UIImage systemImageNamed:@"square.grid.2x2.fill"];
    UIImageView *icon = [[UIImageView alloc] initWithImage:symbol];
    icon.translatesAutoresizingMaskIntoConstraints = NO;
    icon.tintColor = UIColor.whiteColor;
    icon.contentMode = UIViewContentModeScaleAspectFit;
    [emblem addSubview:icon];

    UILabel *title = [UILabel new];
    title.translatesAutoresizingMaskIntoConstraints = NO;
    title.text = @"SlideyDock16";
    title.font = [UIFont systemFontOfSize:22 weight:UIFontWeightBold];
    title.textColor = UIColor.whiteColor;
    title.adjustsFontSizeToFitWidth = YES;
    title.minimumScaleFactor = 0.8;
    [hero addSubview:title];

    UILabel *subtitle = [UILabel new];
    subtitle.translatesAutoresizingMaskIntoConstraints = NO;
    subtitle.text = @"Your Dock, your layout.";
    subtitle.font = [UIFont systemFontOfSize:13 weight:UIFontWeightMedium];
    subtitle.textColor = [UIColor colorWithWhite:1 alpha:0.74];
    [hero addSubview:subtitle];

    [NSLayoutConstraint activateConstraints:@[
        [emblem.leadingAnchor constraintEqualToAnchor:hero.leadingAnchor constant:18],
        [emblem.centerYAnchor constraintEqualToAnchor:hero.centerYAnchor],
        [emblem.widthAnchor constraintEqualToConstant:54],
        [emblem.heightAnchor constraintEqualToConstant:54],
        [icon.centerXAnchor constraintEqualToAnchor:emblem.centerXAnchor],
        [icon.centerYAnchor constraintEqualToAnchor:emblem.centerYAnchor],
        [icon.widthAnchor constraintEqualToConstant:28],
        [icon.heightAnchor constraintEqualToConstant:28],
        [title.leadingAnchor constraintEqualToAnchor:emblem.trailingAnchor constant:15],
        [title.trailingAnchor constraintLessThanOrEqualToAnchor:hero.trailingAnchor constant:-12],
        [title.bottomAnchor constraintEqualToAnchor:hero.centerYAnchor constant:-2],
        [subtitle.leadingAnchor constraintEqualToAnchor:title.leadingAnchor],
        [subtitle.topAnchor constraintEqualToAnchor:hero.centerYAnchor constant:6],
        [subtitle.trailingAnchor constraintLessThanOrEqualToAnchor:hero.trailingAnchor constant:-12]
    ]];
    table.tableHeaderView = header;
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    self.dockGradient.frame = self.dockHero.bounds;
}

// A single centered, styled GitHub link, matching CallBar's project action.
- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [super tableView:tableView cellForRowAtIndexPath:indexPath];
    NSString *identifier = [[self specifierAtIndexPath:indexPath] propertyForKey:@"id"];
    if (![identifier isEqualToString:@"githubLink"]) return cell;

    cell.textLabel.hidden = YES;
    if ([cell isKindOfClass:PSTableCell.class]) {
        ((PSTableCell *)cell).titleLabel.hidden = YES;
    }
    UIStackView *link = (UIStackView *)[cell.contentView viewWithTag:55116];
    if (!link) {
        link = [UIStackView new];
        link.tag = 55116;
        link.axis = UILayoutConstraintAxisHorizontal;
        link.alignment = UIStackViewAlignmentCenter;
        link.spacing = 9;
        link.userInteractionEnabled = NO;
        link.translatesAutoresizingMaskIntoConstraints = NO;

        UIImageView *glyph = [[UIImageView alloc] initWithImage:
            [UIImage systemImageNamed:@"chevron.left.forwardslash.chevron.right"]];
        glyph.tintColor = UIColor.systemTealColor;
        glyph.contentMode = UIViewContentModeScaleAspectFit;
        [glyph.widthAnchor constraintEqualToConstant:21].active = YES;
        [glyph.heightAnchor constraintEqualToConstant:20].active = YES;

        UILabel *label = [UILabel new];
        label.text = @"View on GitHub";
        label.font = [UIFont systemFontOfSize:16 weight:UIFontWeightSemibold];
        label.textColor = UIColor.systemTealColor;
        [link addArrangedSubview:glyph];
        [link addArrangedSubview:label];
        [cell.contentView addSubview:link];

        [NSLayoutConstraint activateConstraints:@[
            [link.centerXAnchor constraintEqualToAnchor:cell.contentView.centerXAnchor],
            [link.centerYAnchor constraintEqualToAnchor:cell.contentView.centerYAnchor],
            [link.leadingAnchor constraintGreaterThanOrEqualToAnchor:cell.contentView.leadingAnchor constant:16],
            [link.trailingAnchor constraintLessThanOrEqualToAnchor:cell.contentView.trailingAnchor constant:-16]
        ]];
    }
    cell.accessibilityLabel = @"View SlideyDock16 on GitHub";
    return cell;
}

- (void)tableView:(UITableView *)tableView
  didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    NSString *identifier = [[self specifierAtIndexPath:indexPath] propertyForKey:@"id"];
    if ([identifier isEqualToString:@"githubLink"]) {
        [tableView deselectRowAtIndexPath:indexPath animated:YES];
        [self openProjectSource:nil];
        return;
    }
    [super tableView:tableView didSelectRowAtIndexPath:indexPath];
}


- (NSArray *)specifiers {
    if (_specifiers == nil) {
        _specifiers = [self loadSpecifiersFromPlistName:@"Root" target:self];
    }
    return _specifiers;
}

- (void)respring:(id)sender {
    (void)sender;

    const char *sbreloadPaths[] = {
        "/var/jb/usr/bin/sbreload",
        "/usr/bin/sbreload",
        NULL
    };
    for (NSUInteger index = 0; sbreloadPaths[index] != NULL; index++) {
        const char *path = sbreloadPaths[index];
        if (access(path, X_OK) != 0) {
            continue;
        }

        pid_t pid = 0;
        char *const arguments[] = {
            (char *)"sbreload",
            NULL
        };
        posix_spawn(&pid, path, NULL, NULL, arguments, environ);
        return;
    }

    const char *killallPaths[] = {
        "/var/jb/usr/bin/killall",
        "/usr/bin/killall",
        NULL
    };
    for (NSUInteger index = 0; killallPaths[index] != NULL; index++) {
        const char *path = killallPaths[index];
        if (access(path, X_OK) != 0) {
            continue;
        }

        pid_t pid = 0;
        char *const arguments[] = {
            (char *)"killall",
            (char *)"SpringBoard",
            NULL
        };
        posix_spawn(&pid, path, NULL, NULL, arguments, environ);
        return;
    }
}

- (void)openProjectSource:(id)sender {
    (void)sender;
    NSURL *url = [NSURL URLWithString:
        @"https://github.com/551UK/SlideyDock16"];
    [UIApplication.sharedApplication
        openURL:url
        options:@{}
        completionHandler:nil];
}

@end
