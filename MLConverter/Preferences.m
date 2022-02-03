//
//  Preferences.m
//  MultiPeerTest
//

#import "Preferences.h"


@interface Preferences ()
{
    NSUserDefaults *prefs;
}

@end

NSString * const VVVgenerate                =   @"VVV001";
NSString * const VVVmode                     =  @"VVV002";

@implementation Preferences

+ (Preferences *) sharedPreferences
{
    static Preferences *_Preferences;
    if (_Preferences == nil) {
        _Preferences = [[Preferences alloc] init];
    }
    return _Preferences;
}

- (instancetype) init
{
    if (self = [super init]) {
        prefs = NSUserDefaults.standardUserDefaults;

        NSMutableDictionary  *defaultValues = [NSMutableDictionary new];
		// Initial values for prefeences should be set below

		[[NSUserDefaults standardUserDefaults] registerDefaults: defaultValues];
    }
    return self;
}

+ (void) initialize
{
    NSMutableDictionary  *defaultValues = [NSMutableDictionary dictionary];
    [defaultValues setValue:@(NO) forKey:VVVgenerate];
    [defaultValues setValue:@(offsetModeTL) forKey:VVVmode];
    [[NSUserDefaults standardUserDefaults] registerDefaults: defaultValues];
}

- (void) flush
{
    [prefs synchronize];
}

#pragma mark -

- (BOOL) generateOnStartup
{
    return [prefs boolForKey:VVVgenerate];
}

- (void) setGenerateOnStartup:(BOOL)generateOnStartup
{
    [prefs setBool:generateOnStartup forKey:VVVgenerate];
}

- (OffsetMode) offsetMode
{
    return (OffsetMode)[prefs integerForKey:VVVmode];
}

- (void) setOffsetMode:(OffsetMode)offstMode
{
    [prefs setInteger:offstMode forKey:VVVmode];
}


@end
