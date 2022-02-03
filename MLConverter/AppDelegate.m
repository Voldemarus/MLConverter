//
//  AppDelegate.m
//  MLConverter
//
//  Created by Водолазкий В.В. on 01.02.2022.
//

#import "AppDelegate.h"
#import "SourceFilesExtractor.h"
#import "Preferences.h"

@interface AppDelegate () <NSTableViewDelegate, NSTableViewDataSource>
{
    Preferences *prefs;
}

@property (nonatomic, retain) SourceFilesExtractor *processor;

@property (strong) IBOutlet NSWindow *window;
- (IBAction)saveAction:(id)sender;
@property (weak) IBOutlet NSTableView *tableView;
@property (weak) IBOutlet NSImageView *imageView;
- (IBAction)QuitbuttonClicked:(id)sender;
- (IBAction)modeClicked:(id)sender;
@property (weak) IBOutlet NSSegmentedControl *modeControl;
@property (weak) IBOutlet NSSwitch *generateSwitch;
- (IBAction)generateSwitchClicked:(id)sender;

@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    self.processor = [[SourceFilesExtractor alloc] init];

    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    prefs = [Preferences sharedPreferences];
    self.generateSwitch.state = (prefs.generateOnStartup ? NSControlStateValueOn : NSControlStateValueOff);
    self.modeControl.selectedSegment = prefs.offsetMode;

    [self.processor processFiles];

    [self.tableView reloadData];
}


- (void)applicationWillTerminate:(NSNotification *)aNotification {
    // Insert code here to tear down your application
}


#pragma mark - Core Data stack

@synthesize persistentContainer = _persistentContainer;

- (NSPersistentContainer *)persistentContainer {
    // The persistent container for the application. This implementation creates and returns a container, having loaded the store for the application to it.
    @synchronized (self) {
        if (_persistentContainer == nil) {
            _persistentContainer = [[NSPersistentContainer alloc] initWithName:@"MLConverter"];
            [_persistentContainer loadPersistentStoresWithCompletionHandler:^(NSPersistentStoreDescription *storeDescription, NSError *error) {
                if (error != nil) {
                    // Replace this implementation with code to handle the error appropriately.
                    // abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
                    
                    /*
                     Typical reasons for an error here include:
                     * The parent directory does not exist, cannot be created, or disallows writing.
                     * The persistent store is not accessible, due to permissions or data protection when the device is locked.
                     * The device is out of space.
                     * The store could not be migrated to the current model version.
                     Check the error message to determine what the actual problem was.
                    */
                    NSLog(@"Unresolved error %@, %@", error, error.userInfo);
                    abort();
                }
            }];
        }
    }
    
    return _persistentContainer;
}

#pragma mark - Core Data Saving and Undo support

- (IBAction)saveAction:(id)sender {
    // Performs the save action for the application, which is to send the save: message to the application's managed object context. Any encountered errors are presented to the user.
    NSManagedObjectContext *context = self.persistentContainer.viewContext;

    if (![context commitEditing]) {
        NSLog(@"%@:%@ unable to commit editing before saving", [self class], NSStringFromSelector(_cmd));
    }
    
    NSError *error = nil;
    if (context.hasChanges && ![context save:&error]) {
        // Customize this code block to include application-specific recovery steps.              
        [[NSApplication sharedApplication] presentError:error];
    }
}

- (NSUndoManager *)windowWillReturnUndoManager:(NSWindow *)window {
    // Returns the NSUndoManager for the application. In this case, the manager returned is that of the managed object context for the application.
    return self.persistentContainer.viewContext.undoManager;
}

- (NSApplicationTerminateReply)applicationShouldTerminate:(NSApplication *)sender {
    // Save changes in the application's managed object context before the application terminates.
    NSManagedObjectContext *context = self.persistentContainer.viewContext;

    if (![context commitEditing]) {
        NSLog(@"%@:%@ unable to commit editing to terminate", [self class], NSStringFromSelector(_cmd));
        return NSTerminateCancel;
    }
    
    if (!context.hasChanges) {
        return NSTerminateNow;
    }
    
    NSError *error = nil;
    if (![context save:&error]) {

        // Customize this code block to include application-specific recovery steps.
        BOOL result = [sender presentError:error];
        if (result) {
            return NSTerminateCancel;
        }

        NSString *question = NSLocalizedString(@"Could not save changes while quitting. Quit anyway?", @"Quit without saves error question message");
        NSString *info = NSLocalizedString(@"Quitting now will lose any changes you have made since the last successful save", @"Quit without saves error question info");
        NSString *quitButton = NSLocalizedString(@"Quit anyway", @"Quit anyway button title");
        NSString *cancelButton = NSLocalizedString(@"Cancel", @"Cancel button title");
        NSAlert *alert = [[NSAlert alloc] init];
        [alert setMessageText:question];
        [alert setInformativeText:info];
        [alert addButtonWithTitle:quitButton];
        [alert addButtonWithTitle:cancelButton];

        NSInteger answer = [alert runModal];
        
        if (answer == NSAlertSecondButtonReturn) {
            return NSTerminateCancel;
        }
    }

    return NSTerminateNow;
}


#pragma mark - TableView delegate/datasource -

- (NSInteger) numberOfRowsInTableView:(NSTableView *)tableView
{
    return self.processor.list.count;
}

- (nullable id)tableView:(NSTableView *)tableView objectValueForTableColumn:(nullable NSTableColumn *)tableColumn row:(NSInteger)row
{
    Entry *entry = self.processor.list[row];
    NSString *identifier = tableColumn.identifier;
    if ([identifier isEqualToString:@"FileName"]) {
        return entry.fileName;
    } else if ([identifier isEqualToString:@"Origin"]) {
        // Calculate updated position
        double newX = entry.x * entry.imageWidth;
        double newY = entry.y * entry.imageHeight;
        switch(prefs.offsetMode) {
            case offsetModeTL: {
                // This is native coordinate system in NSImage/UIImage
                break;
            }
            case offsetModeBL:{
                newY = entry.imageHeight - newY;
                break;
            }
            case offsetModeBR:{
                newY = entry.imageHeight - newY;
                newX = entry.imageWidth - newX;
                break;
            }
            case offsetModeTR:{
                newX = entry.imageWidth - newX;
                break;
            }
         }
        int newXi = newX;
        int newYi = newY;
        return [NSString stringWithFormat:@"%4d*%4d", newXi,newYi];
    } else if ([identifier isEqualToString:@"Size"]) {
        int ww = entry.width * entry.imageWidth;
        int wh = entry.height * entry.imageHeight;
        return [NSString stringWithFormat:@"%2d*%2d", ww,wh];
    }
    return identifier;
}

- (void) tableViewSelectionDidChange:(NSNotification *)notification
{
    NSInteger selRow = self.tableView.selectedRow;
    Entry *entry = self.processor.list[selRow];

    NSImage *image = [[NSImage alloc] initWithContentsOfFile:entry.fullPath];
    self.imageView.image = image;
    [self updateImageOverlay];
}


#pragma mark - Image processing -

- (void) updateImageOverlay
{
    NSInteger selected = self.tableView.selectedRow;
    if (selected != NSNotFound) {
        // We have selected row, so we can process it
        Entry *entry = self.processor.list[selected];
        // Calculate object' position
        // Calculate updated position
        double newX = entry.x * entry.imageWidth;
        double newY = entry.y * entry.imageHeight;
        switch(prefs.offsetMode) {
            case offsetModeTL: {
                // This is native coordinate system in NSImage/UIImage
                break;
            }
            case offsetModeBL:{
                newY = entry.imageHeight - newY;
                break;
            }
            case offsetModeBR:{
                newY = entry.imageHeight - newY;
                newX = entry.imageWidth - newX;
                break;
            }
            case offsetModeTR:{
                newX = entry.imageWidth - newX;
                break;
            }
        }
        double ww = entry.width * entry.imageWidth;
        double wh = entry.height * entry.imageHeight;
        // Now we should raw/redraw box on the image
        [self drawCrosshair:self.imageView.image];
        CGRect bBox = CGRectMake(newX, newY, ww, wh);
        [self drawBoundingBox:bBox];

    }
}

- (void) drawBoundingBox:(CGRect) rect
{
    NSImage *image = self.imageView.image;
    [image lockFocus];

    NSBezierPath *path = [NSBezierPath bezierPathWithRect:rect];
    path.lineWidth = 8;
    [[NSColor redColor] set];
    [path stroke];
    [image unlockFocus];
    self.imageView.image = image;
}


- (void)drawCrosshair:(NSImage*)img
{
    [img lockFocus];

    NSBezierPath* path = [NSBezierPath bezierPath];

    [path moveToPoint:CGPointMake(90,100)];
    [path lineToPoint:CGPointMake(110,100)];

    [path moveToPoint:CGPointMake(100,90)];
    [path lineToPoint:CGPointMake(100,110)];

    [[NSColor blackColor] set];
    [path stroke];
    [img unlockFocus];
}

#pragma mark - Controls actions -


- (IBAction)modeClicked:(id)sender
{
    NSInteger newMode = self.modeControl.selectedSegment;
    prefs.offsetMode = newMode;
    [self.tableView reloadData];
    [self updateImageOverlay];
}

- (IBAction)QuitbuttonClicked:(id)sender {
    [[NSApplication sharedApplication] terminate:nil];
}


- (IBAction)generateSwitchClicked:(id)sender
{
    prefs.generateOnStartup = (self.generateSwitch.state == NSControlStateValueOn);
}

@end
