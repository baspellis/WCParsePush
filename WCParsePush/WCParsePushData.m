//
//  WCParsePushData.m
//  WCParsePushExample
//
//  Created by Bas Pellis on 16/07/14.
//  Copyright (c) 2014 Bas Pellis. All rights reserved.
//

#import "WCParsePushData.h"

@implementation WCParsePushData

@synthesize deviceType = _deviceType;

- (id)initWithParsePushData:(WCParsePushData *)data
{
    self = [super init];
    if(self ) {
        _deviceType = data.deviceType;
        _deviceToken = data.deviceToken;
        _channels = data.channels;
        _badge = data.badge;
        _objectId = data.objectId;
    }
    return self;
}

- (NSString *)deviceType
{
    if(!_deviceType) _deviceType = @"ios";
    return _deviceType;
}

- (NSDictionary *)dictionary
{
    NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithCapacity:4];
    if(self.objectId) [dict setObject:self.objectId forKey:@"objectId"];
    if(self.deviceToken) [dict setObject:self.deviceToken forKey:@"deviceToken"];
    if(self.deviceType) [dict setObject:self.deviceType forKey:@"deviceType"];
    if(self.channels) [dict setObject:[self.channels allObjects] forKey:@"channels"];
    [dict setObject:@(self.badge) forKey:@"badge"];
    
    return [NSDictionary dictionaryWithDictionary:dict];
}

@end
