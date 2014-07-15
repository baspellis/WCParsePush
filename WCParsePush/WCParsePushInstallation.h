//
//  WCParsePushInstallation.h
//  WCParsePush
//
//  Created by Bas Pellis on 17/06/14.
//  Copyright (c) 2014 Bas Pellis. All rights reserved.
//

#import <Foundation/Foundation.h>

extern NSString * const WCParsePushErrorDomain;

typedef void (^WCParsePushBooleanResultBlock)(BOOL succeeded, NSError *error);

@interface WCParsePushInstallation : NSObject

+ (instancetype)currentInstallation;

@property (strong, nonatomic, readonly) NSString *deviceType;
@property (strong, nonatomic) NSString *deviceToken;
@property (strong, nonatomic) NSSet *channels;
@property (assign, nonatomic) NSInteger badge;

// Device Token Methods
- (void)setDeviceTokenFromData:(NSData *)deviceTokenData;

// Application Id and Client Key Methods
+ (void)setApplicationId:(NSString *)applicationId restAPIKey:(NSString *)restAPIKey;
+ (NSString *)getApplicationId;
+ (NSString *)getRestAPIKey;

// Channel Methods
- (void)addChannel:(NSString *)channel;
- (void)removeChannel:(NSString *)channel;

// Save Methods
- (BOOL)save;
- (BOOL)save:(NSError **)error;
- (void)saveInBackground;
- (void)saveInBackgroundWithBlock:(WCParsePushBooleanResultBlock)block;
- (void)saveEventually;
- (void)saveEventuallyWithBlock:(WCParsePushBooleanResultBlock)block;

@end
