//
//  AppDelegate.m
//  location-demo
//
//  Created by Tony Meng on 8/25/14.
//  Copyright (c) 2014 Firebase. All rights reserved.
//

#import "AppDelegate.h"
#import "ViewController.h"

#import <GoogleMaps/GoogleMaps.h>
#import <Firebase/Firebase.h>
#import <FBSDKCoreKit/FBSDKCoreKit.h>

NSString* const kFirebaseUrl = @"http://convoyer.firebaseio.com";
static NSString* const kGmsMapApiKey = @"AIzaSyA9KuN67O4D4fWxEgdBiQGxyJdzEhfcZr0";

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application
            openURL:(NSURL *)url
  sourceApplication:(NSString *)sourceApplication
         annotation:(id)annotation
{
    // Call FBAppCall's handleOpenURL:sourceApplication to handle Facebook app responses
    BOOL wasHandled = [[FBSDKApplicationDelegate sharedInstance] application:application
                                                                     openURL:url
                                                           sourceApplication:sourceApplication
                                                                  annotation:annotation
                       ];
    if (wasHandled) {
        [self authToFirebase];
    }
    // You can add your app-specific url handling code here if needed
    return wasHandled;
}

// notify firebase that user has logged in
- (void)authToFirebase
{
    NSString *fbAccessToken = [[FBSDKAccessToken currentAccessToken] tokenString]; //[[[FBSession activeSession] accessTokenData] accessToken];
    // if we have an access token, authenticate to firebase
    if (fbAccessToken) {
        Firebase *ref = [[Firebase alloc] initWithUrl:kFirebaseUrl];
        [ref authWithOAuthProvider:@"facebook" token:fbAccessToken withCompletionBlock:^(NSError *error, FAuthData *authData) {
            if (error) {
                NSLog(@"Error on login %@", error);
            } else if (authData) {
                self.displayName_ = authData.providerData[@"displayName"];
                NSLog(@"Logged In: %@", self.displayName_);
                [self startLocationUpdates];
            } else {
                NSLog(@"Logged out");
            }
        }];
    } else {
        NSLog(@"No access token provided.");
    }
}

// notify firebase that user has logged out
- (void)deauthToFirebase
{
    if (self.displayName_) {
        Firebase *positionRef = [[[Firebase alloc] initWithUrl:kFirebaseUrl] childByAppendingPath:self.displayName_];
        [positionRef removeValueWithCompletionBlock:^(NSError *error, Firebase *ref) {
            self.displayName_ = nil;
            [positionRef unauth];
        }];
    }
    [self stopLocationUpdates];
}

// start updating location
- (void)startLocationUpdates
{
    // Create the location manager if this object does not
    // already have one.
    if (!self.locationManager_) {
        self.locationManager_ = [[CLLocationManager alloc] init];
    }
    
    self.locationManager_.delegate = self;
    self.locationManager_.desiredAccuracy = kCLLocationAccuracyBest;
    
    // Set a movement threshold for new events.
    self.locationManager_.distanceFilter = 5; // meters
    
    self.hasOrientated_ = false;
    
    [self.locationManager_ requestWhenInUseAuthorization];
    [self.locationManager_ startUpdatingLocation];
}

- (void)locationManager:(CLLocationManager *)manager didChangeAuthorizationStatus:(CLAuthorizationStatus)status {
    if (status == kCLAuthorizationStatusAuthorizedWhenInUse) {
        [self.locationManager_ startUpdatingLocation];
    } else if (status == kCLAuthorizationStatusAuthorizedAlways) {
        // iOS 7 will redundantly call this line.
        [self.locationManager_ startUpdatingLocation];
    } else if (status > kCLAuthorizationStatusNotDetermined) {
        NSLog(@"Could not fetch correct authorization status.");
    }
}

// stop updating location
- (void)stopLocationUpdates
{
    if (self.locationManager_) {
        [self.locationManager_ stopUpdatingLocation];
        self.locationManager_ = nil;
    }
}

// this function executes once per location update
- (void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray *)locations {
    CLLocation *loc = locations[0];
    if (!self.hasOrientated_) {
        // set map to the user's location on initial login
        ViewController* controller = (ViewController*) self.window.rootViewController;
        [controller updateCameraWithLocation:loc];
        self.hasOrientated_ = true;
    }
    if (self.displayName_) {
        // if the user has logged in, update firebase with the new location
        Firebase *positionRef = [[[Firebase alloc] initWithUrl:kFirebaseUrl] childByAppendingPath:self.displayName_];
        
        NSDictionary *value = @{
            @"coords": @{
                @"accuracy" : [NSNumber numberWithDouble:loc.horizontalAccuracy],
                @"latitude" : [NSNumber numberWithDouble:loc.coordinate.latitude],
                @"longitude" : [NSNumber numberWithDouble:loc.coordinate.longitude]
            },
            @"timestamp" : [NSNumber numberWithInt:[[NSNumber numberWithDouble:loc.timestamp.timeIntervalSince1970 * 1000] intValue]]
        };
        
        [positionRef updateChildValues:value];
        // if the user disconnects, remove his data from firebase
//        [positionRef onDisconnectRemoveValue];
    }
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    // Override point for customization after application launch.
    [GMSServices provideAPIKey:kGmsMapApiKey];
    [[FBSDKApplicationDelegate sharedInstance] application:application
                             didFinishLaunchingWithOptions:launchOptions];
    [self authToFirebase];
    return YES;
}
							
- (void)applicationWillResignActive:(UIApplication *)application
{
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later. 
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
    // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    [FBSDKAppEvents activateApp];
}

- (void)applicationWillTerminate:(UIApplication *)application
{
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
}

@end
