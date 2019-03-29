//
//  EmporterBridge.m
//  EmporterKit
//
//  Created by Mikey on 23/03/2019.
//  Copyright © 2019 Young Dynasty. All rights reserved.
//

#import "Emporter.h"
#import "Emporter-Private.h"
#import "ApplicationLauncher.h"

NSNotificationName EmporterServiceStateDidChangeNotification = @"EmporterServiceStateDidChangeNotification";
NSNotificationName EmporterTunnelStateDidChangeNotification = @"EmporterTunnelStateDidChangeNotification";
NSNotificationName EmporterTunnelConfigurationDidChangeNotification = @"EmporterTunnelConfigurationDidChangeNotification";

NSString *const EmporterTunnelIdentifierUserInfoKey = @"EmporterTunnelIdentifierUserInfoKey";

@implementation Emporter
@synthesize _application = _application;
@synthesize bundleURL = _bundleURL;

+ (BOOL)isInstalled {
    NSURL *bundleURL = [self _bundleURL];
    if (bundleURL == nil) {
        return NO;
    }
    
    NSBundle *bundle = [NSBundle bundleWithURL:bundleURL];
    if (bundle == nil || bundle.bundleIdentifier == nil) {
        return NO;
    }
    
    return [[self _bundleIds] containsObject:bundle.bundleIdentifier];
}

+ (NSURL *)appStoreURL {
    if (@available(macOS 10.14, *)) {
        return [NSURL URLWithString:@"macappstore://itunes.apple.com/app/id1406832001"];
    } else {
        return [NSURL URLWithString:@"https://itunes.apple.com/app/id1406832001"];
    }
}

static NSArray <NSString *> *_fixedBundleIds = nil;

+ (void)_forceBundleIds:(NSArray<NSString *> *)bundleIds {
    _fixedBundleIds = bundleIds;
    _fixedBundleURL = nil;
}

static NSURL *_fixedBundleURL = nil;

+ (void)_forceBundleURL:(NSURL *)url {
    _fixedBundleURL = url;
    _fixedBundleIds = nil;
}

+ (NSArray *)_bundleIds {
    return _fixedBundleIds? : @[@"net.youngdynasty.emporter.mas", @"net.youngdynasty.emporter"];
}

+ (NSURL *)_bundleURL {
    NSURL *fixedURL = _fixedBundleURL;
    if (fixedURL != nil) {
        return fixedURL;
    }
    
    for (NSString *bundleId in [self _bundleIds]) {
        NSArray *urls = CFBridgingRelease(LSCopyApplicationURLsForBundleIdentifier((__bridge CFStringRef)bundleId, NULL));
        if (urls != nil && urls.count > 0) {
            return [urls firstObject];
        }
    }
    
    return nil;
}

+ (NSArray <NSRunningApplication *> *)_runningApplications {
    NSMutableArray *apps = [NSMutableArray array];
    
    for (NSString *bundleId in [Emporter _bundleIds]) {
        [apps addObjectsFromArray:[NSRunningApplication runningApplicationsWithBundleIdentifier:bundleId]];
    }
    
    return [apps copy];
}

#pragma mark -

- (instancetype)init {
    NSURL *bundleURL = [Emporter _bundleURL];
    if (bundleURL == nil)
        return nil;
    
    EmporterApplication *application = [SBApplication applicationWithURL:bundleURL];
    if (application == nil)
        return nil;
    
    self = [super init];
    if (self == nil)
        return nil;
    
    _application = application;
    _bundleURL = bundleURL;
    
    for (NSNotificationName name in @[EmporterServiceStateDidChangeNotification, EmporterTunnelStateDidChangeNotification, EmporterTunnelConfigurationDidChangeNotification]) {
        [[NSDistributedNotificationCenter defaultCenter] addObserver:self selector:@selector(_dispatchNotification:) name:name object:nil];
    }
    
    return self;
}

- (void)dealloc {
    [[NSDistributedNotificationCenter defaultCenter] removeObserver:self];
}

- (void)activate {
    [_application activate];
}

- (void)quit {
    [_application quit];
}

- (BOOL)isRunning {
    return [_application isRunning];
}

- (void)launchInBackgroundWithCompletionHandler:(void (^)(NSError *))completionHandler {
    // Check if the application is running before we launch it as we may unintentionally activate it
    for (NSRunningApplication *app in [Emporter _runningApplications]) {
        if ([app.bundleURL isEqual:_bundleURL]) {
            if (completionHandler != nil) {
                dispatch_async(dispatch_get_main_queue(), ^{ completionHandler(nil); });
            }
            return;
        }
    }
    
    [ApplicationLauncher launchApplicationAtURL:_bundleURL withArguments:@[@"--background"] timeout:10 completionHandler:completionHandler];
}

#pragma mark - Service

- (EmporterServiceState)serviceState {
    return [_application serviceState];
}

- (void)resumeService {
    [_application resumeService];
}

- (void)suspendService {
    [_application suspendService];
}

#pragma mark - Tunnels

- (EmporterTunnel *)tunnelForURL:(NSURL *)url {
    // Use predicate for best performance
    NSPredicate *filter = nil;
    
    if ([url isFileURL]) {
        filter = [NSPredicate predicateWithFormat:@"directoryPath == %@", url.URLByStandardizingPath.path];
    } else {
        NSPredicate *portFilter = [NSPredicate predicateWithFormat:@"proxyPort == %@", url.port];
        NSPredicate *hostFilter = nil;
        
        if ([@[@"127.0.0.1", @"localhost"] containsObject:url.host]) {
            // We should be able to use "proxyHostHeader IN %@" but our tests suggest otherwise
            hostFilter = [NSPredicate predicateWithFormat:@"proxyHostHeader == '127.0.0.1' OR proxyHostHeader == 'localhost' OR proxyHostHeader == ''"];
        } else {
            hostFilter = [NSPredicate predicateWithFormat:@"proxyHostHeader == %@", url.host];
        }
        
        filter = [NSCompoundPredicate andPredicateWithSubpredicates:@[hostFilter, portFilter]];
    }
    
    return [[[_application tunnels] filteredArrayUsingPredicate:filter] firstObject];
}

- (EmporterTunnel *)tunnelWithIdentifier:(NSString *)identifer {
    return [[_application tunnels] objectWithID:identifer];
}

- (EmporterTunnel *)configureTunnelWithURL:(NSURL *)url {
    return [_application configureTunnelWithSource:url];
}

- (EmporterTunnel *)createTunnelWithURL:(NSURL *)url properties:(NSDictionary *)properties error:(NSError **)outError {
    id data = url.isFileURL ? url : url.absoluteString;
    EmporterTunnel *tunnel = [[[_application classForScriptingClass:@"tunnel"] alloc] initWithElementCode:'Tnnl' properties:properties data:data];
    
    [[_application tunnels] insertObject:tunnel atIndex:0];
    
    if (outError != NULL) {
        (*outError) = tunnel.lastError;
    }

    return tunnel.lastError == nil ? tunnel : nil;
}

- (SBElementArray<EmporterTunnel *> *)tunnels {
    return [_application tunnels];
}

#pragma mark -

- (EmporterApplication *)_application {
    return _application;
}

- (void)_dispatchNotification:(NSNotification *)notification {
    if (![NSThread isMainThread]) {
        return dispatch_async(dispatch_get_main_queue(), ^{
            [self _dispatchNotification:notification];
        });
    }
    
    NSDictionary *userInfo = nil;
    
    if ([@[EmporterTunnelStateDidChangeNotification, EmporterTunnelConfigurationDidChangeNotification] containsObject:notification.name]) {
        if ([notification.object isKindOfClass:[NSString class]]) {
            userInfo = @{EmporterTunnelIdentifierUserInfoKey: notification.object};
        }
    }
    
    [[NSNotificationCenter defaultCenter] postNotificationName:notification.name object:self userInfo:userInfo];
}

@end
