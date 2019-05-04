/*
 * Emporter.h
 */

#import <AppKit/AppKit.h>
#import <ScriptingBridge/ScriptingBridge.h>


@class EmporterApplication, EmporterItem, EmporterTunnel;

enum EmporterServiceState {
	EmporterServiceStateSuspended = 'spnD' /* Suspended */,
	EmporterServiceStateConnecting = 'cnTi' /* Connecting */,
	EmporterServiceStateConnected = 'cnTd' /* Connected */,
	EmporterServiceStateConflicted = 'cofL' /* Conflicted (check conflict reason / next reconnect) */
};
typedef enum EmporterServiceState EmporterServiceState;

enum EmporterTunnelKind {
	EmporterTunnelKindProxy = 'prxY' /* Proxy tunnels forward traffic to an existing local web server. */,
	EmporterTunnelKindDirectory = 'diR ' /* Directory tunnels serve directories directly from your Mac. */
};
typedef enum EmporterTunnelKind EmporterTunnelKind;

enum EmporterTunnelState {
	EmporterTunnelStateInitializing = 'iNIt' /* Initializing */,
	EmporterTunnelStateDisconnecting = 'dscG' /* Disconnecting */,
	EmporterTunnelStateDisconnected = 'dscD' /* Disconnected */,
	EmporterTunnelStateConnecting = 'cnnG' /* Connecting */,
	EmporterTunnelStateConnected = 'cnnD' /* Connected */,
	EmporterTunnelStateConflicted = 'cnfD' /* Conflicted (check conflict reason) */
};
typedef enum EmporterTunnelState EmporterTunnelState;

@protocol EmporterGenericMethods

- (void) delete;  // Delete an object.

@end



/*
 * Standard Suite
 */

// The application's top-level scripting object.
@interface EmporterApplication : SBApplication

@property (copy, readonly) NSString *name;  // The name of the application.
@property (readonly) BOOL frontmost;  // Is this the active application?
@property (copy, readonly) NSString *version;  // The version number of the application.

- (void) quit;  // Quit the application.
- (EmporterTunnel *) configureTunnelWithSource:(id)x;  // Configure an existing (or new) tunnel.
- (void) resumeService;  // Resume serving tunnels.
- (void) suspendService;  // Suspend serving tunnels.

@end

// A scriptable object.
@interface EmporterItem : SBObject <EmporterGenericMethods>

@property (copy) NSDictionary *properties;  // All of the object's properties.


@end



/*
 * Emporter
 */

// Emporter's top level scripting object.
@interface EmporterApplication (Emporter)

- (SBElementArray<EmporterTunnel *> *) tunnels;

@property (copy, readonly) NSString *apiVersion;  // The version of the scripting API.
@property (readonly) EmporterServiceState serviceState;  // The state of the connection to the service.
@property (copy, readonly) NSString *conflictReason;  // The reason the service is in a conflicted state.
@property (copy, readonly) NSDate *nextReconnect;  // If the service is in a conflicted state (i.e. the service is unreachable), a reconnect attempt will be made by this date.

@end

// A tunnel
@interface EmporterTunnel : EmporterItem

- (NSString *) id;  // The unique identifier of the tunnel.
@property (readonly) EmporterTunnelKind kind;  // The kind of the tunnel.
@property (copy) NSString *name;  // The name of the tunnel.
@property (readonly) BOOL isTemporary;  // Is the tunnel temporary?
@property BOOL isEnabled;  // Is the tunnel enabled?
@property (readonly) BOOL isAuthEnabled;  // Is the tunnel password protected?
@property (copy, readonly) NSString *remoteUrl;  // The URL of the tunnel.
@property (readonly) EmporterTunnelState state;  // The state of the tunnel.
@property (copy, readonly) NSString *conflictReason;  // The reason the tunnel is in a conflicted state.
@property (copy) NSNumber *proxyPort;  // The port of the existing local web server. (proxy kind)
@property BOOL shouldRewriteHostHeader;  // Should the Host header be modified when proxying? (proxy kind)
@property (copy) NSString *proxyHostHeader;  // When proxying, sometimest he header needs to be rewritten to look like it's coming from your Mac. (proxy kind)
@property (copy) NSURL *directory;  // The directory to serve using the built-in web server. (directory kind).
@property (copy) NSString *directoryIndexFile;  // When serving a directory, this is the default file served. (directory kind)
@property BOOL isBrowsingEnabled;  // Can the directory contents be read when an index file is not found? (directory kind)
@property BOOL isLiveReloadEnabled;  // If enabled, anyone visiting your URL will receive live updates when images, markup or stylesheets change. (directory kind)

- (void) edit;  // Edit a tunnel's settings
- (BOOL) passwordProtectWithUsername:(NSString *)username password:(NSString *)password;  // Password protect a tunnel, unless it's already protected

@end

