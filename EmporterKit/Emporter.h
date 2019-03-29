//
//  EmporterBridge.h
//  EmporterKit
//
//  Created by Mikey on 23/03/2019.
//  Copyright © 2019 Young Dynasty. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "Emporter-Bridge.h"

NS_ASSUME_NONNULL_BEGIN

@interface Emporter : NSObject

/*!
 Determine if Emporter is installed.
 
 If Emporter is not installed, the designated initializer (init) will return nil.
 
 \returns True if Emporter is installed
 */
+ (BOOL)isInstalled;

/*!
 A URL which can be used to view/download Emporter on the Mac App Store.
 
 If Emporter is not installed, users should be directed to this URL.
 
 \returns The Mac App Store URL for Emporter.
 */
+ (NSURL *)appStoreURL;

#pragma mark - Lifecycle

/*!
 Determine whether or not Emporter is open.
 
 If Emporter is not open, it will open automatically when using APIs which read/write data
 to/from Emporter, which may result in host applications losing focus (and Emporter windows
 becoming visible). To work around this, see launchInBackgroundWithCompletionHandler.

 \returns True if an instance of Emporter is running.
 */
@property (readonly) BOOL isRunning;

/*!
 The bundle URL of Emporter.
 
 \returns True if an instance of Emporter is running.
 */
@property (readonly) NSURL *bundleURL;

/*!
 Activate the current running instance of Emporter.
 */
- (void)activate;

/*!
 Launch Emporter in the without activation or its windows appearing.
 
 \param completionHandler The completion handler is invoked once Emporter has finished launching.
 */
- (void)launchInBackgroundWithCompletionHandler:(void (^__nullable)(NSError *__nullable))completionHandler;

/*!
 Terminate the current running instance of Emporter.
 */
- (void)quit;

#pragma mark - Tunnels

/*!
 EmporterTunnelStateDidChangeNotification is posted when a tunnel's state changes.
 
 The userInfo will include EmporterTunnelIdentifierUserInfoKey for the tunnel whose state changed.
 */
extern NSNotificationName EmporterTunnelStateDidChangeNotification;

/*!
 EmporterTunnelConfigurationDidChangeNotification is posted when a tunnel's configuration changes.
 
 The userInfo will include EmporterTunnelIdentifierUserInfoKey for the tunnel whose configuration changed.
 */
extern NSNotificationName EmporterTunnelConfigurationDidChangeNotification;

/*!
 EmporterTunnelIdentifierUserInfoKey defines a key present in tunnel notifications which can be
 used to resolve the tunnel related to a notification.
 */
extern NSString *const EmporterTunnelIdentifierUserInfoKey;

/*!
 Tunnels expose the tunnels managed by Emporter.
 
 For best performance, SBElementArray should be filtered using NSPredicates.
 */
@property (readonly) SBElementArray<EmporterTunnel *> *tunnels;

/*!
 Find a tunnel to a directory or local HTTP URL.
 
 \param url A file or local HTTP URL.
 
 \returns The tunnel whose source matches the given URL. May be nil.
 */

- (EmporterTunnel *__nullable)tunnelForURL:(NSURL *)url;

/*!
 Find a tunnel by id.
 
 \returns The tunnel with the given id. May be nil.
 */

- (EmporterTunnel *__nullable)tunnelWithIdentifier:(NSString *)identifer;

/*!
 Create a tunnel to a directory or local HTTP server.
 
 \param url The directory or HTTP URL used to provide contents for the tunnel.
 \param properties Options for configuring tunnels (i.e. name). See \c EmporterTunnel for a list of available properties.
 \param outError An optional error pointer explaining why the tunnel could not be created.
 
 \returns A new tunnel (prepended to \c tunnels) or nil if the tunnel could not be created.
 */
- (EmporterTunnel *__nullable)createTunnelWithURL:(NSURL *)url properties:(NSDictionary *__nullable)properties error:(NSError **__nullable)outError;

/*! Configure a tunnel to a directory or local HTTP server by either showing its existing configuration or prompting the user to configure a new tunnel.
 
 \param url The source directory or HTTP URL used to provide contents for the tunnel.
 
 \returns An existing tunnel or nil.
 */
- (EmporterTunnel *__nullable)configureTunnelWithURL:(NSURL *)url;

#pragma mark - Service

/*!
 EmporterServiceStateDidChangeNotification is posted when the connection to the Emporter service changes.
 */
extern NSNotificationName EmporterServiceStateDidChangeNotification;


/*!
 The state of the connection to the Emporter service.
 */
@property (readonly) EmporterServiceState serviceState;


/*!
 The reason the service is in a conflicted state.
 */
@property (readonly) NSString *__nullable serviceConflictReason;

/*!
 If the service is a conflicted state temporarily (i.e. network timeout), a reconnect will be attempted by this date.
 */
@property (readonly) NSDate *__nullable nextReconnectDate;

/*!
 Resume the connection to the service.
 
 The service may not be resumed if there are no tunnels configured. Tunnels will become accessible after the service connects.
 */
- (void)resumeService;

/*!
 Suspend the connection to the service.
 
 All tunnels will be taken offline immediately.
 */
- (void)suspendService;

@end

NS_ASSUME_NONNULL_END
