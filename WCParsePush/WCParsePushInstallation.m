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

@property (strong, nonatomic) WCParsePushData *eventuallySaveData;
@property (strong, nonatomic) WCParsePushData *saveData;
@property (strong, nonatomic) WCParsePushData *parseData;

@property (strong, nonatomic) NSURLSessionDataTask *saveDataTask;
@property (strong, nonatomic) NSURLSessionDataTask *loadDataTask;
@property (strong, nonatomic) KSReachableOperation *operation;

@end

@implementation WCParsePushInstallation

@synthesize deviceToken = _deviceToken;
@synthesize badge = _badge;

#pragma mark - Singleton Methods

+ (instancetype)currentInstallation {
    static WCParsePushInstallation *_currentInstallation = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _currentInstallation = [[WCParsePushInstallation alloc] init];
    });
    
    return _currentInstallation;
}

#pragma mark - Initialization Methods

- (instancetype)init
{
    self = [super init];
    if (self) {
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationWillResignActive:) name:UIApplicationWillResignActiveNotification object:nil];
    }
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - Getter/Setter Methods

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
    [self loadInstallationData];
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

- (BOOL)addChannel:(NSString *)channel
{
    if(![WCParsePushInstallation channelIsValid:channel]) {
        return NO;
    }
    else {
        NSMutableSet *channels = [NSMutableSet setWithSet:self.channels];
        [channels addObject:channel];
        self.channels = [NSSet setWithSet:channels];
        return YES;
    }
}

- (BOOL)removeChannel:(NSString *)channel
{
    if(![self.channels containsObject:channel]) {
        return NO;
    }
    else {
        NSMutableSet *channels = [NSMutableSet setWithSet:self.channels];
        [channels removeObject:channel];
        self.channels = [NSSet setWithSet:channels];
        return YES;
    }
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
    self.eventuallySaveData = [[WCParsePushData alloc] initWithParsePushData:self];

    WCParsePushInstallation __weak *weakself = self;
    self.operation = [KSReachableOperation operationWithHost:@"https://api.parse.com" allowWWAN:YES onReachabilityAchieved:^{
        [weakself performSaveWithBlock:^(BOOL succeeded, NSError *error) {
            if(block) block(succeeded, error);
        }];
    }];
}

#pragma mark - Notifications Methods

- (void)applicationWillResignActive:(NSNotification *)notification
{
    if(self.parseData) [self storeInstallationData];
    if(self.eventuallySaveData) [self storeTempData];
}

#pragma mark - Private Methods

- (void)performSaveWithBlock:(WCParsePushBooleanResultBlock)block
{
    self.saveData = [[WCParsePushData alloc] initWithParsePushData:self];
    
    NSURLRequest *request = [self saveRequest];

    if(!request) return;

    if(self.saveDataTask) [self.saveDataTask cancel];

    WCParsePushInstallation __weak *weakself = self;
    self.saveDataTask = [self.urlSession dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        
        NSDictionary *responseObject = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error: &error];
        
        NSInteger statusCode = [(NSHTTPURLResponse *)response statusCode];
        BOOL succeeded = (statusCode == 200 || statusCode == 201) && (error == nil);

        if(!error) {
            [weakself removeTempData];
        }
        
        if(!succeeded && !error) error = [weakself errorFromResponseObject:responseObject];
        
        if(succeeded) {
            if(!weakself.objectId) {
                weakself.objectId = [responseObject objectForKey:@"objectId"];                
            }
            
            if(!weakself.saveData.objectId) {
                weakself.saveData.objectId = weakself.objectId;
            }

            weakself.parseData = weakself.saveData;
            weakself.saveData = nil;
            weakself.eventuallySaveData = nil;
            
            dispatch_async(dispatch_get_main_queue(), ^{
                if([weakself.delegate respondsToSelector:@selector(parsePushInstallationDidSave:)]) {
                    [weakself.delegate parsePushInstallationDidSave:weakself];
                }
            });
        }
        else {
            dispatch_async(dispatch_get_main_queue(), ^{
                if([weakself.delegate respondsToSelector:@selector(parsePushInstallation:didFailWithError:)]) {
                    [weakself.delegate parsePushInstallation:weakself didFailWithError:error];
                }
            });
        }
        if(block) {
            
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
    
    if(self.saveData) {
        NSError *error = nil;
        NSData *data = [NSJSONSerialization dataWithJSONObject:[self.saveData dictionary] options:0 error:&error];
        
        NSAssert(!error, @"Parse request body failed: %@ - %@", error.localizedDescription, error.userInfo);
        
        [request setHTTPBody:data];
    }
    
    return request;
}

- (void)performLoadWithBlock:(WCParsePushBooleanResultBlock)block
{
    self.saveData = [[WCParsePushData alloc] initWithParsePushData:self];
    NSURLRequest *request = [self saveRequest];
    
    if(!request) return;
    
    if(self.loadDataTask) [self.loadDataTask cancel];
    
    WCParsePushInstallation __weak *weakself = self;
    self.loadDataTask = [self.urlSession dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        
        NSDictionary *responseObject = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error: &error];
        NSInteger statusCode = [(NSHTTPURLResponse *)response statusCode];
        BOOL succeeded = (statusCode == 200 || statusCode == 201) && (error == nil);

        if(!succeeded && !error) error = [weakself errorFromResponseObject:responseObject];
        
        if(succeeded) {
            if(!weakself.objectId) weakself.objectId = [responseObject objectForKey:@"objectId"];
            weakself.channels = [NSSet setWithArray:[responseObject objectForKey:@"channels"]];
            weakself.badge = [[responseObject objectForKey:@"badge"] integerValue];

            
            weakself.parseData = weakself.saveData;
            weakself.saveData = nil;

            dispatch_async(dispatch_get_main_queue(), ^{
                if([weakself.delegate respondsToSelector:@selector(parsePushInstallationDidLoad:)]) {
                    [weakself.delegate parsePushInstallationDidLoad:weakself];
                }
            });
        }
        else {
            dispatch_async(dispatch_get_main_queue(), ^{
                if([weakself.delegate respondsToSelector:@selector(parsePushInstallation:didFailWithError:)]) {
                    [weakself.delegate parsePushInstallation:weakself didFailWithError:error];
                }
            });
        }
        
        if(block) {
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

- (void)loadInstallationData
{
    BOOL loadedFromFile = NO;
    
    NSDictionary *dict = [NSDictionary dictionaryWithContentsOfFile:[self pathForTempDictionary]];
    if(dict) {
        self.objectId = [dict objectForKey:@"objectId"];
        self.channels = [NSSet setWithArray:[dict objectForKey:@"channels"]];
        self.badge = [[dict objectForKey:@"badge"] integerValue];
        
        self.eventuallySaveData = [[WCParsePushData alloc] initWithParsePushData:self];
        
        [self saveEventually];
        loadedFromFile = YES;
    }
    else {
        NSDictionary *dict = [NSDictionary dictionaryWithContentsOfFile:[self pathForInstallationDictionary]];
        if(dict) {
            self.objectId = [dict objectForKey:@"objectId"];
            self.channels = [NSSet setWithArray:[dict objectForKey:@"channels"]];
            self.badge = [[dict objectForKey:@"badge"] integerValue];
            
            loadedFromFile = YES;
        }
    }
    
    if(loadedFromFile) {
        if([self.delegate respondsToSelector:@selector(parsePushInstallationDidLoad:)]) {
            [self.delegate parsePushInstallationDidLoad:self];
        }
    }
    else {
        [self performLoadWithBlock:NULL];
    }
}

- (void)storeInstallationData
{
    [[self.parseData dictionary] writeToFile:[self pathForInstallationDictionary] atomically:YES];
}

- (void)storeTempData
{
    [[self.eventuallySaveData dictionary] writeToFile:[self pathForTempDictionary] atomically:YES];
}

- (void)removeTempData
{
    [[NSFileManager defaultManager] removeItemAtPath:[self pathForTempDictionary] error:nil];
}

- (NSString *)pathForInstallationDictionary
{
    return [self pathForDictionaryWithBasename:@"PasePushInstallation"];
}

- (NSString *)pathForTempDictionary
{
    return [self pathForDictionaryWithBasename:@"TempInstallation"];
}

- (NSString *)pathForDictionaryWithBasename:(NSString *)basename
{
    NSString *deviceToken = self.deviceToken;
    if(TARGET_IPHONE_SIMULATOR) {
        deviceToken = @"simulator";
    }

    NSString *filename = [NSString stringWithFormat:@"%@-%@.plist", basename, deviceToken];
    return [[WCParsePushInstallation applicationDocumentsDirectory] stringByAppendingPathComponent:filename];
}

+ (NSString *) applicationDocumentsDirectory
{
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *basePath = ([paths count] > 0) ? [paths objectAtIndex:0] : nil;
    return basePath;
}

+ (BOOL)channelIsValid:(NSString *)channel
{
    NSRange range = [channel rangeOfString:@"^[A-Z][A-Z0-9-_]+$" options:NSRegularExpressionSearch|NSCaseInsensitiveSearch];
    return range.location != NSNotFound;
}

@end
