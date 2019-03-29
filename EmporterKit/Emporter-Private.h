//
//  Emporter-Tests.h
//  EmporterKit
//
//  Created by Mikey on 23/03/2019.
//  Copyright © 2019 Young Dynasty. All rights reserved.
//

#import "Emporter.h"

NS_ASSUME_NONNULL_BEGIN

@interface Emporter()

@property (nonatomic,readonly) EmporterApplication *_application;

+ (NSURL *)_bundleURL;
+ (NSArray <NSRunningApplication *> *)_runningApplications;

+ (void)_forceBundleURL:(NSURL *__nullable)url;
+ (void)_forceBundleIds:(NSArray<NSString *> *__nullable)bundleIds;

@end

NS_ASSUME_NONNULL_END
