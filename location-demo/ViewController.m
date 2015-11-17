//
//  ViewController.m
//  location-demo
//
//  Created by Tony Meng on 8/25/14.
//  Copyright (c) 2014 Firebase. All rights reserved.
//

#import "ViewController.h"
#import "AppDelegate.h"

#import <Firebase/Firebase.h>
#import <FBSDKCoreKit/FBSDKCoreKit.h>
#import <FBSDKLoginKit/FBSDKLoginKit.h>

@interface ViewController ()
@property (weak, nonatomic) IBOutlet GMSMapView *mapView;
@property (weak, nonatomic) IBOutlet FBSDKLoginButton *loginButton;
@property (weak, nonatomic) IBOutlet UITextField *messageTextField;
- (IBAction)doneClicked:(id)sender;
@end

@implementation ViewController 

- (void)viewDidLoad
{
    [super viewDidLoad];
    // setup the view
    [self loadMapsView];
	// additional setup after loading the view, typically from a nib.
    [self loadFacebookView];
    [self listenForLocations];
}

// set google maps as the view
- (void)loadMapsView
{
    // initialize the map to san francisco
    GMSCameraPosition *camera = [GMSCameraPosition cameraWithLatitude:37.7833
                                                            longitude:-122.4167
                                                                 zoom:8];
//    self.mapView_ = [GMSMapView mapWithFrame:CGRectZero camera:camera];
    self.mapView.camera = camera;
    self.mapView.settings.myLocationButton = YES;
    self.mapView.settings.rotateGestures = NO;
    self.mapView.myLocationEnabled = YES;
//    self.view = self.mapView_;
}

// load the facebook login button
- (void)loadFacebookView
{
//    FBSDKLoginButton *loginButton = [[FBSDKLoginButton alloc] init];
//    loginButton.readPermissions = @[@"public_profile", @"email", @"user_friends"];
    // Optional: Place the button in the center of your view.
//    loginButton.center = self.view.center;
//    [self.view addSubview:loginButton];
}

// setup firebase listerners to handle other users' locations
- (void)listenForLocations
{
    // house all the markers in a map
    self.usersToMarkers_ = [NSMapTable mapTableWithKeyOptions:NSMapTableStrongMemory valueOptions:NSMapTableWeakMemory];
    Firebase *ref = [[Firebase alloc] initWithUrl:kFirebaseUrl];
    // listen for new users
    [ref observeEventType:FEventTypeChildAdded withBlock:^(FDataSnapshot *s2) {
        // listen for updates for each user
        [[ref childByAppendingPath:s2.key] observeEventType:FEventTypeValue withBlock:^(FDataSnapshot *snapshot) {
            // check to see if user was updated or removed
            if (snapshot.key) {
                // location updated, create/move the marker
                GMSMarker *marker = [self.usersToMarkers_ objectForKey:snapshot.key];
                if (!marker) {
                    marker = [[GMSMarker alloc] init];
                    marker.title = snapshot.key;
                    marker.map = self.mapView;
                    [self.usersToMarkers_ setObject:marker forKey:snapshot.key];
                }
                marker.snippet = snapshot.value[@"message"];
                marker.position = CLLocationCoordinate2DMake([snapshot.value[@"coords"][@"latitude"] doubleValue], [snapshot.value[@"coords"][@"longitude"] doubleValue]);
            } else {
                // user was removed, remove the marker
                GMSMarker *marker = [self.usersToMarkers_ objectForKey:snapshot.key];
                if (marker) {
                    marker.map = nil;
                    [self.usersToMarkers_ removeObjectForKey:snapshot.key];
                }
            }
        }];
    }];
}

// change where the camera is on the map
- (void)updateCameraWithLocation:(CLLocation*)location
{
    NSLog(@"Updating camera");
    GMSCameraPosition *oldPosition = [self.mapView camera];
    GMSCameraPosition *position = [GMSCameraPosition cameraWithTarget:location.coordinate zoom:oldPosition.zoom];
    [self.mapView setCamera:position];
}

// Logged-out user experience
- (void)loginViewShowingLoggedOutUser:(FBSDKLoginButton *)loginView
{
    NSLog(@"FB: logged out");
    AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
    [appDelegate deauthToFirebase];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (IBAction)doneClicked:(id)sender {
    NSLog(@"%@", self.messageTextField.text);
    Firebase *positionRef = [[[Firebase alloc] initWithUrl:kFirebaseUrl] childByAppendingPath:((AppDelegate*)[[UIApplication sharedApplication] delegate]).displayName_];
    [[positionRef childByAppendingPath:@"message"] setValue:self.messageTextField.text];
}
@end
