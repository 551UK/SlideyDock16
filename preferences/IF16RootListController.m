#import "IF16RootListController.h"

#import <spawn.h>
#import <unistd.h>

extern char **environ;

@implementation IF16RootListController

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
