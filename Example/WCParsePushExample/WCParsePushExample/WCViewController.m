//
//  WCViewController.m
//  WCParsePushExample
//
//  Created by Bas Pellis on 15/07/14.
//  Copyright (c) 2014 Bas Pellis. All rights reserved.
//

#import "WCViewController.h"
#import "WCParsePushInstallation.h"

@interface WCViewController () <WCParsePushInstallationDelegate, UIAlertViewDelegate>

@property (strong, nonatomic) NSArray *channels;

@end

@implementation WCViewController

- (id)initWithStyle:(UITableViewStyle)style
{
    self = [super initWithStyle:style];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    [[WCParsePushInstallation currentInstallation] setDelegate:self];
    
    NSArray *channels = [[[WCParsePushInstallation currentInstallation] channels] allObjects];
    self.channels = [channels sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return [self.channels count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"Cell" forIndexPath:indexPath];
    
    // Configure the cell...
    NSString *channel = [self.channels objectAtIndex:indexPath.row];
    cell.textLabel.text = channel;
    
    return cell;
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
    return YES;
}


- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        UITableViewCell *cell = [tableView cellForRowAtIndexPath:indexPath];
        NSString *channel = cell.textLabel.text;
        
        NSMutableArray *channels = [NSMutableArray arrayWithArray:self.channels];
        [channels removeObjectAtIndex:indexPath.row];
        self.channels = [NSArray arrayWithArray:channels];

        [self.tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
        
        WCParsePushInstallation *parsePushInstallation = [WCParsePushInstallation currentInstallation];
        if([parsePushInstallation removeChannel:channel]) {
            [parsePushInstallation saveEventuallyWithBlock:^(BOOL succeeded, NSError *error) {
                if(succeeded) {
                    NSLog(@"Saved removed channel: %@", channel);
                }
            }];
        }
    } else if (editingStyle == UITableViewCellEditingStyleInsert) {
        // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
    }   
}

#pragma mark - WCParsePushInstallation Delegate Methods

- (void)parsePushInstallationDidLoad:(WCParsePushInstallation *)installation
{
    NSLog(@"Parse push installation did load");
    [self updateChannels];
}

- (void)parsePushInstallationDidSave:(WCParsePushInstallation *)installation
{
    NSLog(@"Parse push installation did save");    
    [self updateChannels];
}

- (void)parsePushInstallation:(WCParsePushInstallation *)installation didFailWithError:(NSError *)error
{
    NSLog(@"ERROR: Parse push installation did fail with error: %@", error.localizedDescription);
}

#pragma mark - UIAlertView Delegate methods

- (void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex
{
    if(buttonIndex == alertView.cancelButtonIndex) return;
    
    NSString *channel = [alertView textFieldAtIndex:0].text;
    
    if(channel.length == 0) {
        UIAlertView *newAlertView = [[UIAlertView alloc] initWithTitle:@"Channel name empty" message:@"Channel name cannot be empty" delegate:nil cancelButtonTitle:@"Ok" otherButtonTitles:nil];
        [newAlertView show];
    }
    else {
        if([self.channels containsObject:channel]) return;
        
        WCParsePushInstallation *parsePushInstallation = [WCParsePushInstallation currentInstallation];
        if([parsePushInstallation addChannel:channel]) {
            NSMutableSet *channels = [NSMutableSet setWithArray:self.channels];
            [channels addObject:channel];
            self.channels = [[channels allObjects] sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)];

            NSInteger index = [self.channels indexOfObject:channel];
            
            [self.tableView insertRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:index inSection:0]] withRowAnimation:UITableViewRowAnimationAutomatic];
            
            [parsePushInstallation saveEventuallyWithBlock:^(BOOL succeeded, NSError *error) {
                if(succeeded) {
                    NSLog(@"Saved added channel: %@", channel);
                }
            }];
        }
        else {
            UIAlertView *newAlertView = [[UIAlertView alloc] initWithTitle:@"Invalid Channel" message:@"Channel name is not valid" delegate:nil cancelButtonTitle:@"Ok" otherButtonTitles:nil];
            [newAlertView show];
        }
    }
}

#pragma mark - Private Methods

- (void)updateChannels
{
    NSArray *channels = [[[WCParsePushInstallation currentInstallation] channels] allObjects];
    self.channels = [channels sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)];
    
    [self.tableView reloadData];
}

- (IBAction)addChannel:(id)sender
{
    UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"Add channel"
                                                          message:@"Enter the name of the channel"
                                                         delegate:self
                                                cancelButtonTitle:@"Cancel"
                                                otherButtonTitles:@"OK", nil];
    [alertView setAlertViewStyle:UIAlertViewStylePlainTextInput];
    [alertView setDelegate:self];
    [alertView show];
}

@end
