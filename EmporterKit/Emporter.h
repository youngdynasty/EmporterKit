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
 The bundle identifier of Emporter.
 
 \returns The bundle identifier of Emporter.
 */
@property (readonly) NSString *bundleIdentifier;

/*!
 Activate the current running instance of Emporter.
 */
- (void)activate;

/*!
 Launch Emporter in the without activation or its windows appearing.
 
 \param completionHandler Invoked once on the main queue once Emporter has finished launching.
 */
- (void)launchInBackgroundWithCompletionHandler:(void (^__nullable)(NSError *__nullable))completionHandler;

/*!
 Launch Emporter, synchronously, without activation or its windows appearing.
 
 This method will block until Emporter has launched. To launch asynchronously, use \c launchInBackgroundWithCompletionHandler:.
 
 \param outError A pointer to an NSError explaining why Emporter could not be launched. Can be NULL.
 
 \returns True if Emporter was launched successfully.
 */
- (BOOL)launchInBackground:(NSError **__nullable)outError;

/*!
 Terminate the current running instance of Emporter.
 */
- (void)quit;

#pragma mark - Permissions

/*!
 User consent may be required to before Emporter data can be accessed.
 */
typedef NS_OPTIONS(NSUInteger, EmporterUserConsentType) {
    /*! Consent state is not known (is Emporter running?) */
    EmporterUserConsentTypeUnknown,
    
    /*! Consent is required before Emporter data can be accessed. */
    EmporterUserConsentTypeRequired,
    
    /*! Consent has been granted. */
    EmporterUserConsentTypeGranted,
    
    /*! Consent has been denied. */
    EmporterUserConsentTypeDenied
};

/*!
 Determine the user's consent to access Emporter data with an optional prompt.
 
 Emporter must be running in order to prompt and/or determine the user's consent. This method will always return
 \c EmporterUserConsentTypeGranted when running macOS versions older than 10.14.
 
 \param allowPrompt If true, the user will be prompted (at most once) for consent as needed.
 \param completionHandler Invoked on the main queue once the user has approved or denied access to control Emporter.
 
 */
- (void)determineUserConsentWithPrompt:(BOOL)allowPrompt completionHandler:(void(^)(EmporterUserConsentType))completionHandler __attribute__((deprecated));

/*!
 User consent is used to determine whether or not the current application has access to Emporter data. A prompt asking for permission
 will be shown automatically for the first invocation, but if denied, will always fail (even after the app restarts).
 
 This is the synchronous version of \c determineUserConsentWithPrompt:completionHandler: but doesn't rely on Apple's event APIs
 which are known to occasionally cause deadlocks.
 
 \returns The current user consent for accessing Emporter data.
 */
@property(nonatomic, readonly) EmporterUserConsentType userConsentType;

#pragma mark - Tunnels

/*!
 Tunnels expose the tunnels managed by Emporter.
 
 For best performance, SBElementArray should be filtered using NSPredicates.
 */
@property (readonly) SBElementArray<EmporterTunnel *> *tunnels;

/*!
 Find a tunnel to a directory or local HTTP URL.
 
 \param url A file or local HTTP URL.
 \param outError An optional error pointer if there was a problem interfacing with Emporter.
 
 \returns The tunnel whose source matches the given URL. May be nil.
 */

- (EmporterTunnel *__nullable)tunnelForURL:(NSURL *)url error:(NSError **__nullable)outError;

/*!
 Find a tunnel by id.
 
 \param outError An optional error pointer if there was a problem interfacing with Emporter.
 
 \returns The tunnel with the given id. May be nil.
 */

- (EmporterTunnel *__nullable)tunnelWithIdentifier:(NSString *)identifer error:(NSError **__nullable)outError;

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
 \param outError An optional error pointer if there was a problem interfacing with Emporter.
 
 \returns An existing tunnel or nil.
 */
- (EmporterTunnel *__nullable)configureTunnelWithURL:(NSURL *)url error:(NSError **__nullable)outError;

#pragma mark - Service

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

 \param outError An optional error pointer if there was a problem interfacing with Emporter.

 \returns True if the service was successfully resumed.
 */
- (BOOL)resumeService:(NSError **__nullable)outError;

/*!
 Suspend the connection to the service.
 
 All tunnels will be taken offline immediately.

 \returns True if the service was successfully suspended.
 */
- (BOOL)suspendService:(NSError **__nullable)outError;

@end

#pragma mark - Notifications

/*!
 EmporterDidLaunchNotification is posted when Emporter launches.
 */
extern NSNotificationName EmporterDidLaunchNotification;

/*!
 EmporterDidTerminateNotification is posted when Emporter terminates.
 */
extern NSNotificationName EmporterDidTerminateNotification;

/*!
 EmporterDidAddTunnelNotification is posted when a tunnel is added.
 
 The userInfo will include EmporterTunnelIdentifierUserInfoKey for the tunnel that was added.
 */
extern NSNotificationName EmporterDidAddTunnelNotification;

/*!
 EmporterDidRemoveTunnelNotification is posted when a tunnel is removed.
 
 The userInfo will include EmporterTunnelIdentifierUserInfoKey for the tunnel that was removed.
 */
extern NSNotificationName EmporterDidRemoveTunnelNotification;

/*!
 EmporterTunnelStateDidChangeNotification is posted when a tunnel's state changes.
 
 The userInfo will include EmporterTunnelIdentifierUserInfoKey for the tunnel whose state changed.
 */
extern NSNotificationName EmporterTunnelStateDidChangeNotification;

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
 EmporterServiceStateDidChangeNotification is posted when the connection to the Emporter service changes.
 */
extern NSNotificationName EmporterServiceStateDidChangeNotification;

#pragma mark -

@interface Emporter(Predicates)

/*!
 A predicate to filter tunnels by their port.
 
 Predicates provide the most efficient way to query tunnels from Emporter (as they are evaluated only one time between processes).
 
 \returns A predicate to filter tunnels by port.
 */
+ (NSPredicate *)tunnelPredicateForPort:(NSNumber *)port;

/*!
 A predicate to filter tunnels by their source URL. The source URL can be a directory or local web address, in which case
 the URL's host and port will be used for matching.
 
 Predicates provide the most efficient way to query tunnels from Emporter (as they are evaluated only one time between processes).
 
 \returns A predicate to filter tunnels by source URL.
 */
+ (NSPredicate *)tunnelPredicateForSourceURL:(NSURL *)sourceURL;

@end

/*!
 Contextual info describing the current Emporter version.
*/
typedef struct _EmporterVersion {
    struct {
        NSUInteger major;
        NSUInteger minor;
        NSUInteger patch;
    } api;

    NSUInteger major;
    NSUInteger minor;
    NSUInteger patch;
    
    NSUInteger buildNumber;
} EmporterVersion;

@interface Emporter(Version)

/*!
 Get the current version of Emporter (without requiring it to be open).
 
 \returns True if Emporter is installed and the version was extracted.
 */
+ (BOOL)getVersion:(EmporterVersion *)version;

@end

BOOL IsEmporterAPIAvailable(EmporterVersion version, int major, int minor);

NS_ASSUME_NONNULL_END
