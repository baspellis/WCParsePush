//
//  WCParsePushData.h
//  WCParsePushExample
//
//  Created by Bas Pellis on 16/07/14.
//  Copyright (c) 2014 Bas Pellis. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface WCParsePushData : NSObject

@property (copy, nonatomic, readonly) NSString *deviceType;
@property (copy, nonatomic) NSString *deviceToken;
@property (copy, nonatomic) NSSet *channels;
@property (assign, nonatomic) NSInteger badge;
@property (copy, nonatomic) NSString *objectId;

- (id)initWithParsePushData:(WCParsePushData *)data;
- (NSDictionary *)dictionary;

@end
