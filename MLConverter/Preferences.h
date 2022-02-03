//
//  Preferences.h
//  MultiPeerTest
//


#import <Foundation/Foundation.h>
#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN


typedef NS_ENUM(NSInteger, OffsetMode) {
    offsetModeBL = 0,
    offsetModeBR,
    offsetModeTL,
    offsetModeTR,
};

@interface Preferences : NSObject

+ (Preferences *) sharedPreferences;
- (void) flush;

@property (nonatomic) OffsetMode offsetMode;

@property (nonatomic) BOOL generateOnStartup;

@end

NS_ASSUME_NONNULL_END
