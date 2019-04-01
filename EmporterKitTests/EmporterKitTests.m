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

@implementation EmporterKitTests

- (void)setUp {
    self.continueAfterFailure = false;
    [self terminateRunningApps];
    
    // Use custom app path if supplied (for testing new features)
    NSString *appPath = NSProcessInfo.processInfo.environment[@"EMPORTER_APP_PATH"];
    if (appPath != nil) {
        [Emporter _forceBundleURL:[NSURL fileURLWithPath:appPath]];
    }
    
    // Launch in background without data persistence
    XCTestExpectation *launchExpectation = [self expectationWithDescription:@"launch"];
    NSArray *launchArgs = @[@"--background", @"--transient", @"--termsVersion", @"1"];
    
    [ApplicationLauncher launchApplicationAtURL:[Emporter _bundleURL] withArguments:launchArgs timeout:10 completionHandler:^(NSError *error) {
        XCTAssertNil(error, @"Unexpected error launching app");
        [launchExpectation fulfill];
    }];
    
    [self waitForExpectations:@[launchExpectation] timeout:10];
}

- (void)tearDown {
    [self terminateRunningApps];
}

- (void)terminateRunningApps {
    [[Emporter _runningApplications] makeObjectsPerformSelector:@selector(terminate)];
    
    XCTestExpectation *terminateExpectation = [self expectationWithDescription:@"terminate"];
    BOOL isWaiting = YES;
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
        while (isWaiting && [[Emporter _runningApplications] count]) { usleep(15 * 1000); }
        [terminateExpectation fulfill];
    });
    
    [self waitForExpectations:@[terminateExpectation] timeout:1];
    isWaiting = NO;
}

#pragma mark -

- (void)testIsInstalled {
    [Emporter _forceBundleURL:[[NSBundle bundleForClass:[self class]] bundleURL]];
    XCTAssertFalse([Emporter isInstalled], @"Unexpected response for bad URL");

    [Emporter _forceBundleIds:@[@"net.youngdynasty.emporter-x"]];
    XCTAssertFalse([Emporter isInstalled], @"Unexpected response for bad bundle");

    [Emporter _forceBundleURL:nil];
    XCTAssertTrue([Emporter isInstalled]);
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
    
    resolvedTunnel = [emporter tunnelForURL:localURL];
    XCTAssertNotNil(resolvedTunnel, "expected resolved tunnel %@", tunnel.proxyHostHeader);
    XCTAssertEqualObjects(tunnel.id, resolvedTunnel.id, "expected resolved tunnel to match original");
    
    resolvedTunnel = [emporter tunnelForURL:localURL2];
    XCTAssertNotNil(resolvedTunnel, "expected resolved tunnel '%@'", tunnel2.proxyHostHeader);
    XCTAssertEqualObjects(tunnel2.id, resolvedTunnel.id, "expected resolved tunnel to match original");

    resolvedTunnel = [emporter tunnelForURL:[NSURL URLWithString:@"http://127.0.0.1:2019"]];
    XCTAssertNotNil(resolvedTunnel, "expected resolved tunnel");
    XCTAssertEqualObjects(tunnel2.id, resolvedTunnel.id, "expected resolved tunnel to match original");

    resolvedTunnel = [emporter tunnelForURL:[NSURL URLWithString:@"http://virtual-host-not-found:2019"]];
    XCTAssertNil(resolvedTunnel, "unexpected resolved tunnel");
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
    EmporterTunnel *resolvedTunnel = [emporter tunnelForURL:directoryURL];
    
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

- (void)testTunnelConfigurationObserver {
    XCTestExpectation *tunnelStatusNotification = [self expectationWithDescription:@"notifications"];
    tunnelStatusNotification.expectedFulfillmentCount = 4;
    
    Emporter *emporter = [[Emporter alloc] init];
    EmporterTunnel *tunnel = [emporter createTunnelWithURL:[NSURL URLWithString:@"http://127.0.0.1:1234"] properties:nil error:NULL];
    [emporter suspendService];
    
    id configObserver = [[NSNotificationCenter defaultCenter] addObserverForName:EmporterTunnelConfigurationDidChangeNotification object:nil queue:nil usingBlock:^(NSNotification *note) {
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
    
    XCTestExpectation *tunnelStatusNotification = [self expectationWithDescription:@"tunnel status"];
    tunnelStatusNotification.assertForOverFulfill = false;
    
    NSURL *directoryURL = [[NSBundle bundleForClass:[self class]] bundleURL];
    EmporterTunnel *tunnel = [emporter createTunnelWithURL:directoryURL properties:nil error:NULL];
    EmporterTunnelState originalTunnelState = tunnel.state;
    
    id tunnelStatusObserver = [[NSNotificationCenter defaultCenter] addObserverForName:EmporterTunnelStateDidChangeNotification object:nil queue:nil usingBlock:^(NSNotification *note) {
        XCTAssertEqualObjects(tunnel.id, note.userInfo[EmporterTunnelIdentifierUserInfoKey], @"Unexpected tunnel");
        XCTAssertNotEqual(originalTunnelState, tunnel.state, @"Unexpected tunnel state");
        
        [tunnelStatusNotification fulfill];
    }];
    
    [self addTeardownBlock:^{
        [[NSNotificationCenter defaultCenter] removeObserver:serviceObserver];
        [[NSNotificationCenter defaultCenter] removeObserver:tunnelStatusObserver];
    }];
    
    [emporter resumeService];
    
    [self waitForExpectationsWithTimeout:2 handler:nil];
}

@end