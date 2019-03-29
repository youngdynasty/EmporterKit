//
//  ApplicationLauncher.h
//  EmporterKit
//
//  Created by Mikey on 26/03/2019.
//  Copyright © 2019 Young Dynasty. All rights reserved.
//

#import <AppKit/AppKit.h>

@interface ApplicationLauncher : NSObject

typedef void (^ApplicationLaunchHandler)(NSError *__nullable);

+ (void)launchApplicationAtURL:(NSURL *__nonnull)url
                 withArguments:(NSArray<NSString *> *__nullable)arguments
                       timeout:(NSTimeInterval)timeout
             completionHandler:(ApplicationLaunchHandler __nullable)completionHandler;

@end
