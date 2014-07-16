WCParsePush
===========

Lightweight Push Notifications with [Parse.com](https://parse.com)

## Description

This small library provides simple interface to the Parse Push Notification Service without the need to include the full Parse iOS SDK. It inlcudes:

- Device installation registration
- Channel subscribe/unsubscribe
- Async and synchoronous save methods
- Save eventually also after app restart

## Installation with CocoaPods

Add the following to your podfile

```ruby
pod "WCParsePush", "~> 1.0"
```

## Getting started

Add the following to your Application Delegate implementation:

```objective-c
- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    // Setup Push Notifications
    [WCParsePushInstallation setApplicationId:@"<YOUR-APP-ID>" restAPIKey:@"<YOUR-REST-API_KEY>"];
    [[UIApplication sharedApplication] registerForRemoteNotificationTypes:(UIRemoteNotificationTypeAlert | UIRemoteNotificationTypeSound)];
    
    return YES;
}

- (void)application:(UIApplication *)application didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken
{
    [[WCParsePushInstallation currentInstallation] setDeviceTokenFromData:deviceToken];    
}
```

Then to add a channel subscription

```objective-c
[[WCParsePushInstallation currentInstallation] addChannel:@"Channel"];
[[WCParsePushInstallation currentInstallation] saveEventually];
```

## Contact

Bas Pellis

- https://github.com/baspellis
- https://twitter.com/baspellis

## License

WCParsePush is available under the MIT license. See the LICENSE file for more info.