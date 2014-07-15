//
//  WCParsePushInstallation.m
//  WCParsePush
//
//  Created by Bas Pellis on 17/06/14.
//  Copyright (c) 2014 Bas Pellis. All rights reserved.
//

#import "WCParsePushInstallation.h"

#import <KSReachability/KSReachability.h>

#define kParseHeaderApplicationId @"X-Parse-Application-Id"
#define kParseHeaderRestApiKey @"X-Parse-REST-API-Key"

#define kParseRestAPIUrl @"https://api.parse.com/1/installations"

NSString * const WCParsePushErrorDomain = @"WCParsePushErrorDomain";

@interface WCParsePushInstallation ()

@property (strong, nonatomic) NSString *applicationId;
@property (strong, nonatomic) NSString *restAPIKey;
@property (strong, nonatomic) NSURLSession *urlSession;
@property (strong, nonatomic) NSString *objectId;
@property (strong, nonatomic) NSDictionary *eventuallySaveData;

@property (strong, nonatomic) NSURLSessionDataTask *saveDataTask;
@property (strong, nonatomic) NSURLSessionDataTask *loadDataTask;
@property (strong, nonatomic) KSReachableOperation *operation;

@end

@implementation WCParsePushInstallation

@synthesize deviceType = _deviceType;

#pragma mark - Singleton Methods

+ (instancetype)currentInstallation {
    static WCParsePushInstallation *_currentInstallation = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _currentInstallation = [[WCParsePushInstallation alloc] init];
        
        if(TARGET_IPHONE_SIMULATOR) {
            _currentInstallation.deviceToken = @"simulator";
        }
    });
    
    return _currentInstallation;
}

#pragma mark - Getter/Setter Methods

- (NSString *)deviceType
{
    if(!_deviceType) _deviceType = @"ios";
    return _deviceType;
}

- (NSURLSession *)urlSession
{
    if(!_urlSession) {
        NSURLSessionConfiguration *sessionConfiguration = [NSURLSessionConfiguration defaultSessionConfiguration];
        
        NSMutableDictionary *headers = [NSMutableDictionary dictionaryWithCapacity:3];
        [headers setObject:@"application/json" forKey: @"Content-Type"];
        if(self.applicationId) [headers setObject:self.applicationId forKey:kParseHeaderApplicationId];
        if(self.restAPIKey) [headers setObject:self.restAPIKey forKey:kParseHeaderRestApiKey];
        
        [sessionConfiguration setHTTPAdditionalHeaders:headers];
        self.urlSession = [NSURLSession sessionWithConfiguration:sessionConfiguration];
    }
    return _urlSession;
}

- (NSString *)description
{
    NSString *description = [super description];
    description = [description stringByAppendingString:@"{\n"];
    description = [description stringByAppendingFormat:@"   deviceType: %@\n", self.deviceType];
    description = [description stringByAppendingFormat:@"   deviceToken: %@\n", self.deviceToken];
    if([self.channels count] > 0) description = [description stringByAppendingFormat:@"   channels: [%@]\n", [[self.channels allObjects] componentsJoinedByString:@","]];
    else description = [description stringByAppendingFormat:@"   channels: %@\n", self.channels];
    description = [description stringByAppendingFormat:@"   badge: %i\n", (int)self.badge];
    description = [description stringByAppendingString:@"}"];
    
    return description;
}

- (void)setDeviceToken:(NSString *)deviceToken
{
    _deviceToken = deviceToken;
    
    [self loadInstallation];
}

- (void)setBadge:(NSInteger)badge
{
    _badge = badge;

    [[UIApplication sharedApplication] setApplicationIconBadgeNumber: self.badge];
}

#pragma mark - Device Token Methods

- (void)setDeviceTokenFromData:(NSData *)deviceTokenData
{
    self.deviceToken = [self deviceTokenFromData:deviceTokenData];
}

#pragma mark - Channel Methods

- (void)addChannel:(NSString *)channel
{
    NSMutableSet *channels = [NSMutableSet setWithSet:self.channels];
    [channels addObject:channel];
    self.channels = [NSSet setWithSet:channels];
}

- (void)removeChannel:(NSString *)channel
{
    NSMutableSet *channels = [NSMutableSet setWithSet:self.channels];
    [channels removeObject:channel];
    self.channels = [NSSet setWithSet:channels];
}

#pragma mark - Application Id and Client Key methods

+ (void)setApplicationId:(NSString *)applicationId restAPIKey:(NSString *)restAPIKey
{
    if([applicationId length] == 0) {
        [NSException raise:NSInvalidArgumentException format:@"Parse application id cannot be empty."];
    }
    if([restAPIKey length] == 0) {
        [NSException raise:NSInvalidArgumentException format:@"Parse REST API key cannot be empty."];
    }
    
    WCParsePushInstallation *currentInstallation = [WCParsePushInstallation currentInstallation];
    [currentInstallation setApplicationId:applicationId];
    [currentInstallation setRestAPIKey:restAPIKey];
    
    // Invalidate the URL session
    [currentInstallation setUrlSession:nil];
}

+ (NSString *)getApplicationId
{
    return [[WCParsePushInstallation currentInstallation] applicationId];
}

+ (NSString *)getRestAPIKey
{
    return [[WCParsePushInstallation currentInstallation] restAPIKey];
}

#pragma mark - Public Save Methods

- (BOOL)save
{
    return [self save:NULL];
}

- (BOOL)save:(NSError **)error
{
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    
    BOOL __block saveSuccess;
    NSError __block *saveError = nil;
    [self performSaveWithBlock:^(BOOL succeeded, NSError *error) {
        saveSuccess = succeeded;
        saveError = error;

        dispatch_semaphore_signal(semaphore);
    }];
    
    dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
    
    *error = saveError;
    return saveSuccess;
}

- (void)saveInBackground
{
    [self saveInBackgroundWithBlock:NULL];
}

- (void)saveInBackgroundWithBlock:(WCParsePushBooleanResultBlock)block
{
    [self performSaveWithBlock:block];
}

- (void)saveEventually
{
    [self saveEventuallyWithBlock:NULL];
}

- (void)saveEventuallyWithBlock:(WCParsePushBooleanResultBlock)block
{
    self.eventuallySaveData = [self dictionary];
    
    [self storeInstallation];

    WCParsePushInstallation __weak *weakself = self;
    self.operation = [KSReachableOperation operationWithHost:@"https://api.parse.com" allowWWAN:YES onReachabilityAchieved:^{
        [weakself performSaveWithBlock:^(BOOL succeeded, NSError *error) {
            if(succeeded && !error) {
                weakself.eventuallySaveData = nil;
            }
            if(block) block(succeeded, error);
        }];
    }];
}

#pragma mark - Private Methods

- (void)performSaveWithBlock:(WCParsePushBooleanResultBlock)block
{
    if(self.eventuallySaveData) {
        NSMutableDictionary *saveData = [NSMutableDictionary dictionaryWithDictionary:[self dictionary]];
        [saveData setObject:@(YES) forKey:@"saveEventually"];
        self.eventuallySaveData = [NSDictionary dictionaryWithDictionary:saveData];
        
        [self storeInstallation];
    }
    
    if(TARGET_IPHONE_SIMULATOR) {
        [self storeInstallation];
        if(block) block(YES, nil);
        return;
    }
    
    NSURLRequest *request = [self saveRequest];

    if(!request) return;

    if(self.saveDataTask) [self.saveDataTask cancel];

    WCParsePushInstallation __weak *weakself = self;
    self.saveDataTask = [self.urlSession dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        
        NSDictionary *responseObject = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error: &error];
        
        NSInteger statusCode = [(NSHTTPURLResponse *)response statusCode];
        BOOL succeeded = (statusCode == 200 || statusCode == 201) && (error == nil);
        
        if(succeeded) {
            if(!weakself.objectId) weakself.objectId = [responseObject objectForKey:@"objectId"];
            [weakself storeInstallation];
        }
        
        if(block) {
            if(!succeeded && !error) error = [weakself errorFromResponseObject:responseObject];
            
            block(succeeded, error);
        }
        
        weakself.saveDataTask = nil;

        if(weakself.loadDataTask) {
            [weakself.loadDataTask resume];
        }
    }];
    if(self.loadDataTask && self.loadDataTask.state == NSURLSessionTaskStateRunning) {
        return;
    }
    
    [self.saveDataTask resume];
}

- (NSURLRequest *)saveRequest
{
    if([self.deviceToken length] == 0) return nil;
    
    NSURL *url;
    NSString *method;
    
    if(self.objectId) {
        url = [NSURL URLWithString:[kParseRestAPIUrl stringByAppendingPathComponent:self.objectId]];
        method = @"PUT";
    }
    else {
        url = [NSURL URLWithString:kParseRestAPIUrl];
        method = @"POST";
    }
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    [request setHTTPMethod:method];
    
    NSMutableDictionary *body = [NSMutableDictionary dictionaryWithCapacity:3];
    [body setObject:self.deviceType forKey:@"deviceType"];
    [body setObject:self.deviceToken forKey:@"deviceToken"];
    [body setObject:@(self.badge) forKey:@"badge"];
    if(self.channels) [body setObject:[self.channels allObjects] forKey:@"channels"];
    
    NSError *error = nil;
    NSData *data = [NSJSONSerialization dataWithJSONObject:body options:0 error:&error];
    
    NSAssert(!error, @"Parse request body failed: %@ - %@", error.localizedDescription, error.userInfo);
    
    [request setHTTPBody:data];
    return request;
}

- (void)performLoadWithBlock:(WCParsePushBooleanResultBlock)block
{
    NSURLRequest *request = [self saveRequest];
    
    if(!request) return;
    
    if(self.loadDataTask) [self.loadDataTask cancel];
    
    WCParsePushInstallation __weak *weakself = self;
    self.loadDataTask = [self.urlSession dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        
        NSDictionary *responseObject = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error: &error];
        NSInteger statusCode = [(NSHTTPURLResponse *)response statusCode];
        BOOL succeeded = (statusCode == 200 || statusCode == 201) && (error == nil);
        
        if(succeeded) {
            if(!weakself.objectId) weakself.objectId = [responseObject objectForKey:@"objectId"];
            weakself.channels = [NSSet setWithArray:[responseObject objectForKey:@"channels"]];
            weakself.badge = [[responseObject objectForKey:@"badge"] integerValue];
            [self storeInstallation];
        }
        
        if(block) {
            if(!succeeded && !error) error = [weakself errorFromResponseObject:responseObject];
            block(succeeded, error);
        }
        
        weakself.loadDataTask = nil;
        
        if(weakself.saveDataTask) {
            [weakself.saveDataTask resume];
        }
    }];
    
    if(self.saveDataTask && self.saveDataTask.state == NSURLSessionTaskStateRunning) {
        return;
    }

    [self.loadDataTask resume];
}

- (NSURLRequest *)loadRequest
{
    if([self.deviceToken length] == 0) return nil;
    
    NSString *query = [NSString stringWithFormat:@"where={\"deviceType\":\"%@\",\"deviceToken\":\"%@\"}", self.deviceType, self.deviceToken];
    NSString *urlString = [NSString stringWithFormat:@"%@?%@", kParseRestAPIUrl, [query stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];

    return [NSURLRequest requestWithURL:[NSURL URLWithString:urlString]];
}

- (NSError *)errorFromResponseObject:(NSDictionary *)object
{
    NSString *description = [object objectForKey:@"error"];
    if(!description) description = @"Unknown error";
    
    NSInteger code = [[object objectForKey:@"code"] integerValue];
    
    NSDictionary *userInfo = @{ NSLocalizedDescriptionKey: NSLocalizedString(description, nil)};

    return [NSError errorWithDomain:WCParsePushErrorDomain code:code userInfo:userInfo];
}

- (NSString *)deviceTokenFromData:(NSData *)data
{
    const unsigned *tokenBytes = [data bytes];
    NSString *hexToken = [NSString stringWithFormat:@"%08x%08x%08x%08x%08x%08x%08x%08x",
                          ntohl(tokenBytes[0]), ntohl(tokenBytes[1]), ntohl(tokenBytes[2]),
                          ntohl(tokenBytes[3]), ntohl(tokenBytes[4]), ntohl(tokenBytes[5]),
                          ntohl(tokenBytes[6]), ntohl(tokenBytes[7])];
    
    return hexToken;
}

- (void)loadInstallation
{
    NSDictionary *dict = [NSDictionary dictionaryWithContentsOfFile:[self pathForInstallationDictionary]];
    if(dict) {
        self.objectId = [dict objectForKey:@"objectId"];
        self.channels = [NSSet setWithArray:[dict objectForKey:@"channels"]];
        self.badge = [[dict objectForKey:@"badge"] integerValue];
        if([dict objectForKey:@"saveEventually"]) {
            [self saveEventually];
        }
    }
    else {
        [self performLoadWithBlock:NULL];
    }
}

- (void)storeInstallation
{
    NSMutableDictionary *saveData;
    
    if(self.eventuallySaveData) {
        saveData = [NSMutableDictionary dictionaryWithDictionary:self.eventuallySaveData];
        [saveData setObject:@(YES) forKey:@"saveEventually"];
    }
    else {
        saveData = [NSMutableDictionary dictionaryWithDictionary:[self dictionary]];
    }
    [saveData writeToFile:[self pathForInstallationDictionary] atomically:YES];
}

- (NSString *)pathForInstallationDictionary
{
    NSString *filename = [NSString stringWithFormat:@"PasePushInstallation-%@.plist",self.deviceToken];
    return [[WCParsePushInstallation applicationDocumentsDirectory] stringByAppendingPathComponent:filename];
}

+ (NSString *) applicationDocumentsDirectory
{
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *basePath = ([paths count] > 0) ? [paths objectAtIndex:0] : nil;
    return basePath;
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
