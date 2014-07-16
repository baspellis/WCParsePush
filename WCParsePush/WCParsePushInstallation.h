//
//  WCParsePushInstallation.h
//  WCParsePush
//
//  Created by Bas Pellis on 17/06/14.
//  Copyright (c) 2014 Bas Pellis. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "WCParsePushData.h"

extern NSString * const WCParsePushErrorDomain;

typedef void (^WCParsePushBooleanResultBlock)(BOOL succeeded, NSError *error);

@protocol WCParsePushInstallationDelegate;

@interface WCParsePushInstallation : WCParsePushData

+ (instancetype)currentInstallation;

@property (weak, nonatomic) id<WCParsePushInstallationDelegate> delegate;

// Device Token Methods
- (void)setDeviceTokenFromData:(NSData *)deviceTokenData;

// Application Id and Client Key Methods
+ (void)setApplicationId:(NSString *)applicationId restAPIKey:(NSString *)restAPIKey;
+ (NSString *)getApplicationId;
+ (NSString *)getRestAPIKey;

// Channel Methods
- (BOOL)addChannel:(NSString *)channel;
- (BOOL)removeChannel:(NSString *)channel;

// Save Methods
- (BOOL)save;
- (BOOL)save:(NSError **)error;
- (void)saveInBackground;
- (void)saveInBackgroundWithBlock:(WCParsePushBooleanResultBlock)block;
- (void)saveEventually;
- (void)saveEventuallyWithBlock:(WCParsePushBooleanResultBlock)block;

@end

@protocol WCParsePushInstallationDelegate <NSObject>

@optional
- (void)parsePushInstallationDidSave:(WCParsePushInstallation *)installation;
- (void)parsePushInstallationDidLoad:(WCParsePushInstallation *)installation;
- (void)parsePushInstallation:(WCParsePushInstallation *)installation didFailWithError:(NSError *)error;

@end