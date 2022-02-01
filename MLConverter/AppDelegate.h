//
//  AppDelegate.h
//  MLConverter
//
//  Created by Водолазкий В.В. on 01.02.2022.
//

#import <Cocoa/Cocoa.h>
#import <CoreData/CoreData.h>

@interface AppDelegate : NSObject <NSApplicationDelegate>

@property (readonly, strong) NSPersistentContainer *persistentContainer;


@end

