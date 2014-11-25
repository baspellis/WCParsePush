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
pod "WCParsePush", "~> 1.1"
```

## Getting started

Add the following to your Application Delegate implementation:

Objective-C:
```objective-c
- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    // Setup Push Notifications
    [WCParsePushInstallation setApplicationId:@"<YOUR-APP-ID>" restAPIKey:@"<YOUR-REST-API_KEY>"];

  	UIUserNotificationSettings *settings = [UIUserNotificationSettings settingsForTypes:UIUserNotificationTypeAlert | UIUserNotificationTypeBadge | UIUserNotificationTypeSound categories:nil];
  	[application registerUserNotificationSettings:settings];
    [application registerForRemoteNotifications];
    
    return YES;
}

- (void)application:(UIApplication *)application didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken
{
    [[WCParsePushInstallation currentInstallation] setDeviceTokenFromData:deviceToken];    
}
```
Swift:
```swift
func application(application: UIApplication, didFinishLaunchingWithOptions launchOptions: [NSObject: AnyObject]?) -> Bool {

    // Setup Push Notifications
    WCParsePushInstallation.setApplicationId("<YOUR-APP-ID>", restAPIKey: "<YOUR-REST-API_KEY>")

	let settings = UIUserNotificationSettings(forTypes: UIUserNotificationType.Alert | UIUserNotificationType.Badge | UIUserNotificationType.Sound, categories: nil)
    application.registerUserNotificationSettings(settings)
    application.registerForRemoteNotifications()
    
    return YES;
}

func application(application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: NSData) {

    let pushInstallation = WCParsePushInstallation.currentInstallation()
    pushInstallation.setDeviceTokenFromData(deviceToken)
}
```

Then to add a channel subscription

Objective-C:
```objective-c
[[WCParsePushInstallation currentInstallation] addChannel:@"Channel"];
[[WCParsePushInstallation currentInstallation] saveEventually];
```
Swift:
```swift
let pushInstallation = WCParsePushInstallation.currentInstallation()
pushInstallation.addChannel("Channel")
pushInstallation.saveEventually()
```

To reset the badge number

Objective-C:
```objective-c
[[WCParsePushInstallation currentInstallation] setBadge:0];
[[WCParsePushInstallation currentInstallation] saveEventually];
```
Swift:
```swift
let pushInstallation = WCParsePushInstallation.currentInstallation()
pushInstallation.badge = 0
pushInstallation.saveEventually()
```

## Contact

Bas Pellis

- https://github.com/baspellis
- https://twitter.com/baspellis

## License

WCParsePush is available under the MIT license. See the LICENSE file for more info.