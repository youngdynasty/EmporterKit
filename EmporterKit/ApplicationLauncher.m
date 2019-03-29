//
//  ApplicationLauncher.m
//  EmporterKit
//
//  Created by Mikey on 26/03/2019.
//  Copyright © 2019 Young Dynasty. All rights reserved.
//

#import "ApplicationLauncher.h"

@implementation ApplicationLauncher {
    NSRunningApplication *_app;
    ApplicationLaunchHandler _handler;
}

+ (void)launchApplicationAtURL:(NSURL *)url withArguments:(NSArray<NSString *> *)arguments timeout:(NSTimeInterval)timeout completionHandler:(ApplicationLaunchHandler)completionHandler {
    NSDictionary *configuration = nil;
    if (arguments != nil) {
        configuration = @{NSWorkspaceLaunchConfigurationArguments: arguments};
    }
    
    NSError *error = nil;
    NSRunningApplication *app = [[NSWorkspace sharedWorkspace] launchApplicationAtURL:url
                                                                              options:NSWorkspaceLaunchDefault
                                                                        configuration:configuration
                                                                                error:&error];
    
    if (app == nil) {
        if (completionHandler != nil) {
            dispatch_async(dispatch_get_main_queue(), ^{ completionHandler(error); });
        }
        
        return;
    }
    
    ApplicationLauncher *job = [[self alloc] initWithApplication:app handler:completionHandler];
    
    // Add timeout with a strong reference to job so that it doesn't dealloc before the handler is invoked
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(timeout * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [job _invokeHandlerOnceWithError:[NSError errorWithDomain:NSCocoaErrorDomain code:NSExecutableLoadError userInfo:nil]];
    });
}

- (instancetype)initWithApplication:(NSRunningApplication *)app handler:(ApplicationLaunchHandler)handler {
    self = [super init];
    if (self == nil)
        return nil;
    
    _app = app;
    _handler = handler;
    
    [app addObserver:self forKeyPath:@"isFinishedLaunching" options:NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew context:nil];
    
    return self;
}

- (void)dealloc {
    [_app removeObserver:self forKeyPath:@"isFinishedLaunching"];
}

- (void)_invokeHandlerOnceWithError:(NSError *)error {
    if (_handler != nil) {
        _handler(error);
        _handler = nil;
    }
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context {
    if ([_app isFinishedLaunching]) {
        // We may be still initializing. Defer handler invocation so that the handler is invoked while the
        // caller's code block continues to execute.
        dispatch_async(dispatch_get_main_queue(), ^{
            [self _invokeHandlerOnceWithError:nil];
        });
    }
}

@end
