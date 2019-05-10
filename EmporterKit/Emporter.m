//
//  EmporterBridge.m
//  EmporterKit
//
//  Created by Mikey on 23/03/2019.
//  Copyright © 2019 Young Dynasty. All rights reserved.
//

#import <Carbon/Carbon.h>

#import "Emporter.h"
#import "Emporter-Private.h"
#import "ApplicationLauncher.h"

NSNotificationName EmporterDidLaunchNotification = @"EmporterDidLaunchNotification";
NSNotificationName EmporterDidTerminateNotification = @"EmporterDidTerminateNotification";

NSNotificationName EmporterDidAddTunnelNotification = @"EmporterDidAddTunnelNotification";
NSNotificationName EmporterDidRemoveTunnelNotification = @"EmporterDidRemoveTunnelNotification";

NSNotificationName EmporterServiceStateDidChangeNotification = @"EmporterServiceStateDidChangeNotification";
NSNotificationName EmporterTunnelStateDidChangeNotification = @"EmporterTunnelStateDidChangeNotification";
NSNotificationName EmporterTunnelConfigurationDidChangeNotification = @"EmporterTunnelConfigurationDidChangeNotification";

NSString *const EmporterTunnelIdentifierUserInfoKey = @"EmporterTunnelIdentifierUserInfoKey";

@interface EmporterErrorLogger : NSObject<SBApplicationDelegate>
@property(nonatomic,weak) Emporter *emporter;
@end

@implementation Emporter {
    EmporterErrorLogger *_logger;
}
@synthesize _application = _application;
@synthesize bundleURL = _bundleURL;

#if DEBUG
+ (void)initialize {
    // Use custom app path if supplied (for testing new features)
    NSString *appPath = NSProcessInfo.processInfo.environment[@"EMPORTER_APP_PATH"];
    if (appPath != nil) {
        [self _forceBundleURL:[NSURL fileURLWithPath:appPath]];
    }
}
#endif

+ (BOOL)isInstalled {
    return [self _bundleIdentifier] != nil;
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
    
    // Find all bundle URLs
    NSMutableArray *bundleURLs = [NSMutableArray array];
    
    for (NSString *bundleId in [self _bundleIds]) {
        NSArray *urls = CFBridgingRelease(LSCopyApplicationURLsForBundleIdentifier((__bridge CFStringRef)bundleId, NULL));
        if (urls != nil) {
            [bundleURLs addObjectsFromArray:urls];
        }
    }
    
    // Find newest version
    static NSString* (^appVersion)(NSURL *) = ^NSString*(NSURL *appURL) {
        NSBundle *bundle = [NSBundle bundleWithURL:appURL];
        if (bundle == nil) {
            return nil;
        } else {
            return [bundle objectForInfoDictionaryKey:(__bridge NSString *)kCFBundleVersionKey];
        }
    };
    
    return [[bundleURLs sortedArrayUsingComparator:^NSComparisonResult(NSURL *url1, NSURL *url2) {
        NSString *version1 = appVersion(url1);
        NSString *version2 = appVersion(url2);
        
        if (version1 == nil) {
            return (version2 == nil) ? NSOrderedSame : NSOrderedAscending;
        } else if (version2 == nil) {
            return NSOrderedDescending;
        }
        
        NSComparisonResult order = [version2 compare:version1];
        
        // If versions match, sort by path
        if (order == NSOrderedSame) {
            order = [url1.path compare:url2.path];
        }
        
        return order;
    }] firstObject];
}

+ (NSString *)_bundleIdentifier {
    NSURL *bundleURL = [self _bundleURL];
    if (bundleURL == nil) {
        return nil;
    }
    
    NSBundle *bundle = [NSBundle bundleWithURL:bundleURL];
    if (bundle == nil || bundle.bundleIdentifier == nil) {
        return nil;
    }
    
    return [[self _bundleIds] containsObject:bundle.bundleIdentifier] ? bundle.bundleIdentifier : nil;
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
    NSString *bundleIdentifier = [Emporter _bundleIdentifier];
    if (bundleURL == nil || bundleIdentifier == nil)
        return nil;
    
    EmporterApplication *application = [SBApplication applicationWithURL:bundleURL];
    if (application == nil)
        return nil;
    
    self = [super init];
    if (self == nil)
        return nil;
    
    _application = application;
    
    _logger = [[EmporterErrorLogger alloc] init];
    _logger.emporter = self;
    _application.delegate = _logger; // delegate is strong (!)
    
    _bundleURL = bundleURL;
    _bundleIdentifier = bundleIdentifier;
    
    for (NSNotificationName name in @[EmporterServiceStateDidChangeNotification, EmporterTunnelStateDidChangeNotification, EmporterTunnelConfigurationDidChangeNotification, EmporterDidAddTunnelNotification, EmporterDidRemoveTunnelNotification]) {
        [[NSDistributedNotificationCenter defaultCenter] addObserver:self selector:@selector(_dispatchNotification:) name:name object:nil];
    }
    
    [[[NSWorkspace sharedWorkspace] notificationCenter] addObserver:self selector:@selector(_dispatchNotification:) name:NSWorkspaceDidLaunchApplicationNotification object:nil];
    [[[NSWorkspace sharedWorkspace] notificationCenter] addObserver:self selector:@selector(_dispatchNotification:) name:NSWorkspaceDidTerminateApplicationNotification object:nil];
    
    return self;
}

- (void)dealloc {
    [[[NSWorkspace sharedWorkspace] notificationCenter] removeObserver:self];
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

- (void)determineUserConsentWithPrompt:(BOOL)allowPrompt completionHandler:(void (^)(EmporterUserConsentType))completionHandler {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        EmporterUserConsentType userConsentType = [self _determineUserConsentTypeWithPrompt:YES];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            completionHandler(userConsentType);
        });
    });
}

- (EmporterUserConsentType)determineUserConsentTypeWithPrompt:(BOOL)prompt {
    // Schedule run loop source so we can process events while we wait
    CFRunLoopRef runLoop = CFRunLoopGetCurrent();
    CFRunLoopSourceContext runLoopCtx = { .perform = &_NOOP };
    CFRunLoopSourceRef runLoopSource = CFRunLoopSourceCreate(NULL, 0, &runLoopCtx);
    
    CFRunLoopAddSource(runLoop, runLoopSource, kCFRunLoopCommonModes);
    CFRunLoopWakeUp(runLoop);
    
    __block EmporterUserConsentType consentType = EmporterUserConsentTypeUnknown;
    __block BOOL isBusy = YES;

    [self determineUserConsentWithPrompt:prompt completionHandler:^(EmporterUserConsentType v) {
        consentType = v;
        isBusy = NO;
        
        CFRunLoopSourceSignal(runLoopSource);
        CFRunLoopWakeUp(runLoop);
    }];
    
    // Time out after ~2 seconds
    while (isBusy && CFRunLoopRunInMode(kCFRunLoopDefaultMode, 2, true) != kCFRunLoopRunTimedOut);
    
    CFRunLoopRemoveSource(runLoop, runLoopSource, kCFRunLoopCommonModes);
    
    return consentType;
}

- (EmporterUserConsentType)_determineUserConsentTypeWithPrompt:(BOOL)prompt {
    if (@available(macOS 10.14, *)) {
        if (![self isRunning]) {
            return EmporterUserConsentTypeUnknown;
        }
        
        NSAppleEventDescriptor *emporterAppDescriptor = [NSAppleEventDescriptor descriptorWithBundleIdentifier:_bundleIdentifier];
        OSStatus status = AEDeterminePermissionToAutomateTarget(emporterAppDescriptor.aeDesc, typeWildCard, typeWildCard, prompt);
        
        switch (status) {
            case errAEEventNotPermitted:
                return EmporterUserConsentTypeDenied;
            case -1744 /*errAEEventWouldRequireUserConsent*/:
                return EmporterUserConsentTypeRequired;
            case noErr:
                return EmporterUserConsentTypeGranted;
            default: {
                return EmporterUserConsentTypeUnknown;
            }
        }
    } else {
        return EmporterUserConsentTypeGranted;
    }
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

static void _NOOP(void *info) {}

- (BOOL)launchInBackground:(NSError **)outError {
    __block NSError *error = nil;
    __block BOOL isLaunching = YES;
    
    // Schedule run loop source so we can wait for the app to launch but still process events
    CFRunLoopRef runLoop = CFRunLoopGetCurrent();
    CFRunLoopSourceContext runLoopCtx = { .perform = &_NOOP };
    CFRunLoopSourceRef runLoopSource = CFRunLoopSourceCreate(NULL, 1, &runLoopCtx);
    
    CFRunLoopAddSource(runLoop, runLoopSource, kCFRunLoopCommonModes);
    CFRunLoopWakeUp(runLoop);
    
    [self launchInBackgroundWithCompletionHandler:^(NSError *err) {
        error = err;
        isLaunching = NO;
        
        CFRunLoopSourceSignal(runLoopSource);
        CFRunLoopWakeUp(runLoop);
    }];
    
    // Wait for launch (launcher handles timeouts for us)
    while (isLaunching) {
        CFRunLoopRunInMode(kCFRunLoopDefaultMode, 5, true);
    }
    
    // Clean up
    CFRunLoopRemoveSource(runLoop, runLoopSource, kCFRunLoopCommonModes);
    
    if (outError != NULL) {
        (*outError) = error;
    }
    
    return (error == nil);
}

#pragma mark - Service

- (EmporterServiceState)serviceState {
    return [_application serviceState];
}

- (NSString *)serviceConflictReason {
    return [_application conflictReason];
}

- (BOOL)resumeService:(NSError **)outError {
    [_application resumeService];
    
    if (outError != NULL) {
        (*outError) = _application.lastError;
    }
    
    return _application.lastError == nil;
}

- (BOOL)suspendService:(NSError **)outError  {
    [_application suspendService];

    if (outError != NULL) {
        (*outError) = _application.lastError;
    }
    
    return _application.lastError == nil;
}

#pragma mark - Tunnels

- (EmporterTunnel *)tunnelForURL:(NSURL *)url error:(NSError **)outError {
    // Use predicate for best performance
    NSPredicate *filter = [Emporter tunnelPredicateForSourceURL:url];
    EmporterTunnel *tunnel = [[[_application tunnels] filteredArrayUsingPredicate:filter] firstObject];
    
    if (outError != NULL) {
        (*outError) = _application.lastError;
    }
    
    return (_application.lastError == nil) ? tunnel : nil;
}

- (EmporterTunnel *)tunnelWithIdentifier:(NSString *)identifer error:(NSError **)outError {
    EmporterTunnel *tunnel = [[_application tunnels] objectWithID:identifer];
    
    if (outError != NULL) {
        (*outError) = _application.lastError;
    }

    return (_application.lastError == nil) ? tunnel : nil;
}

- (EmporterTunnel *)configureTunnelWithURL:(NSURL *)url error:(NSError **)outError {
    EmporterTunnel *tunnel = [_application configureTunnelWithSource:url];
    
    if (outError != NULL) {
        (*outError) = _application.lastError;
    }
    
    return (_application.lastError == nil) ? tunnel : nil;
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
    
    if ([@[NSWorkspaceDidLaunchApplicationNotification, NSWorkspaceDidTerminateApplicationNotification] containsObject:notification.name]) {
        NSRunningApplication *application = notification.userInfo[NSWorkspaceApplicationKey];
        if ([application.bundleIdentifier isEqualToString:_bundleIdentifier]) {
            NSNotificationName name = self.isRunning ? EmporterDidLaunchNotification : EmporterDidTerminateNotification;
            [[NSNotificationCenter defaultCenter] postNotificationName:name object:self userInfo:nil];
        }
        
        return;
    }
    
    NSDictionary *userInfo = nil;
    
    if ([notification.object isKindOfClass:[NSString class]] && [[NSUUID alloc] initWithUUIDString:notification.object] != nil) {
        userInfo = @{EmporterTunnelIdentifierUserInfoKey: notification.object};
    }
    
    [[NSNotificationCenter defaultCenter] postNotificationName:notification.name object:self userInfo:userInfo];
}

@end


@implementation EmporterErrorLogger

- (nullable id)eventDidFail:(nonnull const AppleEvent *)event withError:(nonnull NSError *)error {
    NSLog(@"Warning: Emporter event failed with error: %@", error);
    return nil;
}

@end


@implementation Emporter(Version)

+ (BOOL)getVersion:(EmporterVersion *)version {
    NSURL *bundleURL = [self _bundleURL];
    if (bundleURL == nil) {
        return NO;
    }
    
    NSBundle *bundle = [NSBundle bundleWithURL:bundleURL];
    if (bundle == nil) {
        return NO;
    }
    
    
    NSString *versionString = [bundle objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
    NSArray<NSString*> *versionComponents = [(versionString ?: @"0.0.0") componentsSeparatedByString:@"."];

    if (versionComponents.count >= 2) {
        version->major = MAX(0, [versionComponents[0] integerValue]);
        version->minor = MAX(0, [versionComponents[1] integerValue]);
        
        if (versionComponents.count >= 3) {
            version->patch = MAX(0, [[[versionComponents[2] componentsSeparatedByString:@"-"] firstObject] integerValue]);
        }
    }
    
    NSString *apiString = [bundle objectForInfoDictionaryKey:@"EMAPIVersionString"];
    NSArray *apiComponents = [(apiString ?: @"0.1.0") componentsSeparatedByString:@"."];
    
    if (apiComponents.count >= 2) {
        version->api.major = MAX(0, [apiComponents[0] integerValue]);
        version->api.minor = MAX(0, [apiComponents[1] integerValue]);
        
        if (apiComponents.count >= 3) {
            version->api.patch = MAX(0, [[[apiComponents[2] componentsSeparatedByString:@"-"] firstObject] integerValue]);
        }
    }
    
    NSString *buildNumberString = [bundle objectForInfoDictionaryKey:(__bridge NSString *)kCFBundleVersionKey];
    version->buildNumber = MAX(0, [(buildNumberString ?: @"1") integerValue]);
    
    return YES;
}

@end

BOOL IsEmporterAPIAvailable(EmporterVersion version, int major, int minor) {
    return version.api.major > major || (version.api.major == major && version.api.minor >= minor);
}

@implementation Emporter(Predicates)

+ (NSPredicate *)tunnelPredicateForPort:(NSNumber *)port {
    return [NSPredicate predicateWithFormat:@"proxyPort == %@", port];
}

+ (NSPredicate *)tunnelPredicateForSourceURL:(NSURL *)url {
    if ([url isFileURL]) {
        return [NSPredicate predicateWithFormat:@"directory == %@", url.URLByStandardizingPath];
    } else {
        NSPredicate *portFilter = [self tunnelPredicateForPort:url.port];
        NSPredicate *hostFilter = nil;
        
        if ([@[@"127.0.0.1", @"localhost"] containsObject:url.host]) {
            // We should be able to use "proxyHostHeader IN %@" but our tests suggest otherwise
            hostFilter = [NSPredicate predicateWithFormat:@"proxyHostHeader == '127.0.0.1' OR proxyHostHeader == 'localhost' OR proxyHostHeader == ''"];
        } else {
            hostFilter = [NSPredicate predicateWithFormat:@"proxyHostHeader == %@", url.host];
        }
        
        return [NSCompoundPredicate andPredicateWithSubpredicates:@[hostFilter, portFilter]];
    }
}

@end
