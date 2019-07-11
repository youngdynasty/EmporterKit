//
//  EmporterKitTests.m
//  EmporterKitTests
//
//  Created by Mikey on 23/03/2019.
//  Copyright © 2019 Young Dynasty. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "Emporter-Private.h"
#import "ApplicationLauncher.h"

@interface EmporterKitTests : XCTestCase
@end

@interface EmporterKitTests(Helpers)
- (void)relaunchAppInBackground;
- (void)terminateRunningApps;
- (NSTask *)runTaskUntil:(NSDate *)date terminationHandler:(dispatch_block_t)terminationHandler;
@end

@implementation EmporterKitTests

- (void)setUp {
    self.continueAfterFailure = false;
    [self relaunchAppInBackground];
}

- (void)tearDown {
    [self terminateRunningApps];
}

#pragma mark -

- (void)testIsInstalled {
    NSURL *defaultBundleURL = [Emporter _bundleURL];
    [self addTeardownBlock:^{ [Emporter _forceBundleURL:defaultBundleURL]; }];
    
    [Emporter _forceBundleURL:[[NSBundle bundleForClass:[self class]] bundleURL]];
    XCTAssertFalse([Emporter isInstalled], @"Unexpected response for bad URL");

    [Emporter _forceBundleIds:@[@"net.youngdynasty.emporter-x"]];
    XCTAssertFalse([Emporter isInstalled], @"Unexpected response for bad bundle");

    [Emporter _forceBundleURL:nil];
    XCTAssertTrue([Emporter isInstalled]);
}

- (void)testBundleURL {
    Emporter *emporter = [[Emporter alloc] init];
    
    XCTAssertNotNil(emporter);
    XCTAssertNotNil(emporter.bundleURL);

    NSString *appPath = NSProcessInfo.processInfo.environment[@"EMPORTER_APP_PATH"];
    if (appPath != nil) {
        XCTAssertEqualObjects(emporter.bundleURL, [NSURL fileURLWithPath:appPath]);
    } else {
        XCTAssertTrue([emporter.bundleURL.path hasPrefix:@"/Applications"], @"%@ is not in /Applications directory", emporter.bundleURL.path);
    }
}

#pragma mark - Tunnels

- (void)testTunnelWithURL {
    Emporter *emporter = [[Emporter alloc] init];
    NSURL *localURL = [NSURL URLWithString:@"http://local.dev:2019"];
    EmporterTunnel *tunnel = [emporter createTunnelWithURL:localURL properties:@{@"name": @"neato"} error:NULL];
    
    XCTAssertNotNil(tunnel, @"Expected tunnel");
    XCTAssertEqual(tunnel.kind, EmporterTunnelKindProxy, @"Expected proxy tunnel");
    XCTAssertEqualObjects(tunnel.name, @"neato", @"Unexpected name");
    XCTAssertEqualObjects(tunnel.proxyPort, @(2019), @"Unexpected port");
    XCTAssertTrue(tunnel.shouldRewriteHostHeader, @"Expected host header to be rewritten");
    XCTAssertEqualObjects(tunnel.proxyHostHeader, @"local.dev", @"Unexpected host header");
    XCTAssertEqualObjects([emporter.tunnels valueForKey:@"id"], @[tunnel.id], @"Unexpected tunnels");
}

- (void)testTunnelResolveURL {
    Emporter *emporter = [[Emporter alloc] init];
    NSURL *localURL = [NSURL URLWithString:@"http://local.dev:2019"];
    EmporterTunnel *tunnel = [emporter createTunnelWithURL:localURL properties:nil error:NULL];
    
    NSURL *localURL2 = [NSURL URLWithString:@"http://localhost:2019"];
    EmporterTunnel *tunnel2 = [emporter createTunnelWithURL:localURL2 properties:nil error:NULL];
    EmporterTunnel *resolvedTunnel = nil;
    
    resolvedTunnel = [emporter tunnelForURL:localURL error:NULL];
    XCTAssertNotNil(resolvedTunnel, "expected resolved tunnel %@", tunnel.proxyHostHeader);
    XCTAssertEqualObjects(tunnel.id, resolvedTunnel.id, "expected resolved tunnel to match original");
    
    resolvedTunnel = [emporter tunnelForURL:localURL2 error:NULL];
    XCTAssertNotNil(resolvedTunnel, "expected resolved tunnel '%@'", tunnel2.proxyHostHeader);
    XCTAssertEqualObjects(tunnel2.id, resolvedTunnel.id, "expected resolved tunnel to match original");

    resolvedTunnel = [emporter tunnelForURL:[NSURL URLWithString:@"http://127.0.0.1:2019"] error:NULL];
    XCTAssertNotNil(resolvedTunnel, "expected resolved tunnel");
    XCTAssertEqualObjects(tunnel2.id, resolvedTunnel.id, "expected resolved tunnel to match original");

    resolvedTunnel = [emporter tunnelForURL:[NSURL URLWithString:@"http://virtual-host-not-found:2019"] error:NULL];
    XCTAssertNil(resolvedTunnel, "unexpected resolved tunnel");
    
}

- (void)testTunnelResolveRemoteURL {
    Emporter *emporter = [[Emporter alloc] init];
    NSURL *localURL = [NSURL URLWithString:@"http://local.dev:2019"];
    EmporterTunnel *tunnel = [emporter createTunnelWithURL:localURL properties:nil error:NULL];
    
    XCTestExpectation *connectExpectation = [self expectationWithDescription:@"connect"];
    
    id tunnelStatusObserver = [[NSNotificationCenter defaultCenter] addObserverForName:EmporterTunnelStateDidChangeNotification object:emporter queue:nil usingBlock:^(NSNotification *note) {
        XCTAssertEqualObjects(tunnel.id, note.userInfo[EmporterTunnelIdentifierUserInfoKey], @"Unexpected tunnel");
        
        if (tunnel.state == EmporterTunnelStateConnected) {
            [connectExpectation fulfill];
        }
    }];
    
    [self addTeardownBlock:^{
        [[NSNotificationCenter defaultCenter] removeObserver:tunnelStatusObserver];
    }];
    
    [emporter resumeService:NULL];
    
    [self waitForExpectationsWithTimeout:5 handler:nil];
    
    NSURL *remoteURL = [NSURL URLWithString:tunnel.remoteUrl];
    XCTAssertNotNil(remoteURL);
    
    for (NSString *urlString in @[
                                  [NSString stringWithFormat:@"http://%@", remoteURL.host],
                                  [NSString stringWithFormat:@"https://%@", remoteURL.host],
                                  [NSString stringWithFormat:@"https://%@/some/path", remoteURL.host]
                                  ]) {
        XCTAssertNotNil([emporter tunnelForURL:([NSURL URLWithString:urlString]) error:NULL], @"%@", urlString);
    }
}

- (void)testTunnelWithFileURL {
    Emporter *emporter = [[Emporter alloc] init];
    NSURL *directoryURL = [[NSBundle bundleForClass:[self class]] bundleURL];
    EmporterTunnel *tunnel = [emporter createTunnelWithURL:directoryURL properties:@{@"name": @"neato"} error:NULL];
    
    XCTAssertNotNil(tunnel, @"Expected tunnel");
    XCTAssertEqualObjects(tunnel.name, @"neato", @"Unexpected name");
    XCTAssertEqual(tunnel.kind, EmporterTunnelKindDirectory, @"Expected directory tunnel");
    XCTAssertEqualObjects(tunnel.directory, directoryURL, @"Unexpected directory");
    XCTAssertTrue(tunnel.isBrowsingEnabled, @"Expected browsing to be enabled");
    XCTAssertEqualObjects([emporter.tunnels valueForKey:@"id"], @[tunnel.id], @"Unexpected tunnels");
}

- (void)testTunnelResolveFileURL {
    Emporter *emporter = [[Emporter alloc] init];
    NSURL *directoryURL = [[NSBundle bundleForClass:[self class]] bundleURL];
    EmporterTunnel *tunnel = [emporter createTunnelWithURL:directoryURL properties:nil error:NULL];
    EmporterTunnel *resolvedTunnel = [emporter tunnelForURL:directoryURL error:NULL];
    
    XCTAssertNotNil(resolvedTunnel, "expected resolved tunnel");
    XCTAssertEqualObjects(tunnel.id, resolvedTunnel.id, "expected resolved tunnel to match original");
}

- (void)testTunnelWithBadURL {
    Emporter *emporter = [[Emporter alloc] init];
    NSError *error = nil;
    EmporterTunnel *tunnel = [emporter createTunnelWithURL:[NSURL URLWithString:@"wowsick:8080"] properties:nil error:&error];
    
    XCTAssertNotNil(error, "Expected non-nil error");
    XCTAssertNil(tunnel, "Expected nil tunnel");
}

- (void)testTunnelWithBadProperties {
    Emporter *emporter = [[Emporter alloc] init];
    NSError *error = nil;
    EmporterTunnel *tunnel = [emporter createTunnelWithURL:[NSURL URLWithString:@"http://wowsick:8080"] properties:@{@"directoryPath":@(1234)} error:&error];
    
    XCTAssertNotNil(error, "Expected non-nil error");
    XCTAssertNil(tunnel, "Expected nil tunnel");
}

- (void)testTunnelProtect {
    Emporter *emporter = [[Emporter alloc] init];
    NSError *error = nil;
    EmporterTunnel *tunnel = [emporter createTunnelWithURL:[NSURL URLWithString:@"http://127.0.0.1:8376"] properties:@{@"isTemporary": @(YES)} error:&error];
    XCTAssertNotNil(tunnel, "%@", error);
    
    XCTAssertFalse(tunnel.isAuthEnabled, "%@", tunnel.lastError);
    XCTAssertTrue([emporter protectTunnel:tunnel withUsername:@"test" password:@"1234" error:&error], "%@", error);
    XCTAssertFalse([emporter protectTunnel:tunnel withUsername:@"test" password:@"1234" error:&error], "%@", error);
    XCTAssertTrue(tunnel.isAuthEnabled, "%@", tunnel.lastError);
}

- (void)testTunnelConfigurationObserver {
    XCTestExpectation *tunnelStatusNotification = [self expectationWithDescription:@"notifications"];
    tunnelStatusNotification.expectedFulfillmentCount = 4;
    
    Emporter *emporter = [[Emporter alloc] init];
    EmporterTunnel *tunnel = [emporter createTunnelWithURL:[NSURL URLWithString:@"http://127.0.0.1:1234"] properties:nil error:NULL];
    [emporter suspendService:NULL];
    
    id configObserver = [[NSNotificationCenter defaultCenter] addObserverForName:EmporterTunnelConfigurationDidChangeNotification object:emporter queue:nil usingBlock:^(NSNotification *note) {
        XCTAssertEqualObjects(tunnel.id, note.userInfo[EmporterTunnelIdentifierUserInfoKey], @"Unexpected tunnel");
        [tunnelStatusNotification fulfill];
    }];
    
    [self addTeardownBlock:^{
        [[NSNotificationCenter defaultCenter] removeObserver:configObserver];
    }];
    
    tunnel.name = @"OK";
    tunnel.proxyPort = @(4321);
    tunnel.proxyHostHeader = @"blah";
    tunnel.shouldRewriteHostHeader = true;
    
    [self waitForExpectationsWithTimeout:2 handler:nil];
}

- (void)testTunnelLifeObserver {
    Emporter *emporter = [[Emporter alloc] init];
    
    XCTestExpectation *notificationExpectation = [self expectationWithDescription:@"notifications"];
    notificationExpectation.expectedFulfillmentCount = 2;
    
    __block NSString *noteTunnelId = nil;
    id addObserver = [[NSNotificationCenter defaultCenter] addObserverForName:EmporterDidAddTunnelNotification object:emporter queue:nil usingBlock:^(NSNotification *note) {
        XCTAssertNotNil(noteTunnelId = note.userInfo[EmporterTunnelIdentifierUserInfoKey], @"Expected tunnel id");
        [notificationExpectation fulfill];
    }];

    id removeObserver = [[NSNotificationCenter defaultCenter] addObserverForName:EmporterDidRemoveTunnelNotification object:emporter queue:nil usingBlock:^(NSNotification *note) {
        XCTAssertEqualObjects(noteTunnelId, note.userInfo[EmporterTunnelIdentifierUserInfoKey], @"Unexpected tunnel");
        [notificationExpectation fulfill];
    }];

    [self addTeardownBlock:^{
        [[NSNotificationCenter defaultCenter] removeObserver:addObserver];
        [[NSNotificationCenter defaultCenter] removeObserver:removeObserver];
    }];
    
    EmporterTunnel *tunnel = [emporter createTunnelWithURL:[NSURL URLWithString:@"http://127.0.0.1:8376"] properties:nil error:NULL];
    NSString *tunnelId = tunnel.id;
    XCTAssertNotNil(tunnelId, @"Expected tunnel id");
    
    [tunnel delete];
    
    [self waitForExpectationsWithTimeout:2 handler:nil];
    
    XCTAssertEqualObjects(tunnelId, noteTunnelId, @"Unexpected tunnel ids");
}

- (void)testTunnelPidBind {
    Emporter *emporter = [[Emporter alloc] init];
    NSError *error = nil;
    EmporterTunnel *tunnel = [emporter createTunnelWithURL:[NSURL URLWithString:@"http://127.0.0.1:8376"] properties:@{@"isTemporary": @(YES)} error:&error];
    XCTAssertNotNil(tunnel, "%@", error);
    
    NSString *tunnelId = tunnel.id;
    XCTAssertNotNil(tunnelId, "%@", error);
    
    XCTestExpectation *terminate1 = [self expectationWithDescription:@"task 1 terminated"];
    NSTask *t1 = [self runTaskUntil:[NSDate dateWithTimeIntervalSinceNow:5] terminationHandler:^{ [terminate1 fulfill]; }];
    
    XCTestExpectation *terminate2 = [self expectationWithDescription:@"task 2 terminated"];
    NSTask *t2 = [self runTaskUntil:[NSDate dateWithTimeIntervalSinceNow:5] terminationHandler:^{ [terminate2 fulfill]; }];
    
    XCTAssertTrue([emporter bindTunnel:tunnel toPid:t1.processIdentifier error:&error], "%@", error);
    XCTAssertTrue([emporter bindTunnel:tunnel toPid:t2.processIdentifier error:&error], "%@", error);
    XCTAssertTrue([emporter unbindTunnel:tunnel fromPid:t2.processIdentifier error:&error], "%@", error);
    XCTAssertTrue([emporter unbindTunnel:tunnel fromPid:t2.processIdentifier error:&error], "%@", error);
    
    [t2 terminate];
    [self waitForExpectations:@[terminate2] timeout:2];
    
    XCTAssertEqualObjects([emporter.tunnels valueForKeyPath:@"id"], @[tunnel.id], @"Tunnel was removed");
    
    [t1 terminate];
    [self waitForExpectations:@[terminate1] timeout:2];
    
    XCTAssertEqualObjects([emporter.tunnels valueForKeyPath:@"id"], @[], @"Tunnel was not removed");
}


#pragma mark - Observers

- (void)testServiceObservers {
    Emporter *emporter = [[Emporter alloc] init];
    EmporterServiceState originalServiceState = emporter.serviceState;
    
    XCTestExpectation *serviceNotification = [self expectationWithDescription:@"notification"];
    serviceNotification.assertForOverFulfill = false;
    
    id serviceObserver = [[NSNotificationCenter defaultCenter] addObserverForName:EmporterServiceStateDidChangeNotification object:emporter queue:nil usingBlock:^(NSNotification * _Nonnull note) {
        XCTAssertNotEqual(originalServiceState, emporter.serviceState, @"Unexpected service state");
        [serviceNotification fulfill];
    }];
    [self addTeardownBlock:^{ [[NSNotificationCenter defaultCenter] removeObserver:serviceObserver]; }];
    
    XCTestExpectation *tunnelStatusNotification = [self expectationWithDescription:@"tunnel status"];
    tunnelStatusNotification.expectedFulfillmentCount = 3;
    tunnelStatusNotification.assertForOverFulfill = NO; // We may or may not get the "initializing" status
    
    NSURL *directoryURL = [[NSBundle bundleForClass:[self class]] bundleURL];
    EmporterTunnel *tunnel = [emporter createTunnelWithURL:directoryURL properties:nil error:NULL];
    
    NSString *tunnelId = tunnel.id;
    XCTAssertNotNil(tunnelId, @"Expected tunnel id");
    
    id tunnelStatusObserver = [[NSNotificationCenter defaultCenter] addObserverForName:EmporterTunnelStateDidChangeNotification object:emporter queue:nil usingBlock:^(NSNotification *note) {
        if ([tunnelId isEqualToString:note.userInfo[EmporterTunnelIdentifierUserInfoKey]]) {
            // We should check the status in theory, but it may have already changed
            [tunnelStatusNotification fulfill];
        }
    }];
    [self addTeardownBlock:^{ [[NSNotificationCenter defaultCenter] removeObserver:tunnelStatusObserver]; }];

    [emporter resumeService:NULL];
    
    [self waitForExpectationsWithTimeout:5 handler:nil];
}

@end

@implementation EmporterKitTests(Helpers)

- (void)_launchAppInBackground:(XCTestExpectation *)launchExpectation {
    // Launch in background without data persistence
    NSArray *launchArgs = @[@"--background", @"--transient", @"--termsVersion", @"1"];
    
    [ApplicationLauncher launchApplicationAtURL:[Emporter _bundleURL] withArguments:launchArgs timeout:10 completionHandler:^(NSError *error) {
        if (error != nil) {
            NSError *underlyngError = error.userInfo[NSUnderlyingErrorKey];
            if (underlyngError != nil && [underlyngError.domain isEqualToString:NSOSStatusErrorDomain] && underlyngError.code == procNotFound) {
                return [self _launchAppInBackground:launchExpectation];
            }
            
            XCTFail(@"Unexpected error launching app: %@", error);
        }
        
        [launchExpectation fulfill];
    }];
}

- (void)relaunchAppInBackground {
    [self terminateRunningApps];
    
    XCTestExpectation *launchExpectation = [self expectationWithDescription:@"launch"];
    [self _launchAppInBackground:launchExpectation];
    [self waitForExpectations:@[launchExpectation] timeout:10];
}

- (void)terminateRunningApps {
    NSArray *runningApps = [Emporter _runningApplications];
    
    NSMutableSet *sources = [NSMutableSet set];
    dispatch_group_t terminateGroup = dispatch_group_create();
    
    for (NSRunningApplication *app in runningApps) {
        dispatch_group_enter(terminateGroup);
        
        dispatch_source_t src = dispatch_source_create(DISPATCH_SOURCE_TYPE_PROC, app.processIdentifier, DISPATCH_PROC_EXIT, NULL);
        dispatch_source_set_registration_handler(src, ^{
            if (kill(app.processIdentifier, 0) != noErr) {
                dispatch_group_leave(terminateGroup);
            }
        });
        dispatch_source_set_event_handler(src, ^{ dispatch_group_leave(terminateGroup); });
        dispatch_resume(src);
        
        [sources addObject:src];
    }
    
    [runningApps makeObjectsPerformSelector:@selector(terminate)];
    
    dispatch_group_wait(terminateGroup, 5 * NSEC_PER_SEC);
}

- (NSTask *)runTaskUntil:(NSDate *)date terminationHandler:(dispatch_block_t)terminationHandler {
    NSTimeInterval interval = [date timeIntervalSinceDate:[NSDate date]];
    
    return [NSTask launchedTaskWithExecutableURL:[NSURL fileURLWithPath:@"/bin/sleep"] arguments:@[[NSString stringWithFormat:@"%@", @(interval)]] error:nil terminationHandler:^(NSTask *t) {
        if (terminationHandler) {
            terminationHandler();
        }
    }];
}

@end
