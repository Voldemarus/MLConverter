//
//  SourceFilesExtractor.m
//  MLConverter
//
//  Created by Водолазкий В.В. on 02.02.2022.
//

#import "SourceFilesExtractor.h"
#import "Preferences.h"

#import "FilePointer.h"


#define LEARN_THRESHOLD 0.7         // to be used for training


@interface SourceFilesExtractor ()
{
    Preferences *prefs;
}

@property (nonatomic, retain) NSMutableArray *learningArrray;
@property (nonatomic, retain) NSMutableArray *testingArray;

@property (nonatomic, readonly) NSArray *sets;
@property (nonatomic, readonly) NSArray *objectNames;

@end

@implementation SourceFilesExtractor


- (instancetype) init
{
    if (self = [super init]) {
        self.learningArrray = [NSMutableArray new];
        self.testingArray = [NSMutableArray new];
        self.list = [NSMutableArray new];
        prefs = [Preferences sharedPreferences];
    }
    return self;
}

- (void) processFiles
{
    NSFileManager *fm = [NSFileManager defaultManager];
    for (NSInteger i = 0; i < [self sets].count; i++) {
        NSString *fullDirPath = [PATH stringByAppendingPathComponent:self.sets[i]];
        BOOL isDir = NO;
        if ([fm fileExistsAtPath:fullDirPath isDirectory:&isDir]) {
            // Directory exists!
            NSLog(@"\n------------------");
            NSLog(@"Processing batch pack %@",self.sets[i]);
            NSLog(@"\n------------------");
            NSString *imageDir = [fullDirPath stringByAppendingPathComponent:@"images"];
            NSString *labelDir = [fullDirPath stringByAppendingPathComponent:@"labels"];
            // Get Directories content
            // Start from labels directory
            NSError *error = nil;
            NSArray *labelFiles = [fm contentsOfDirectoryAtPath:labelDir error:&error];
            if (error) {
                NSLog(@"Cannot get content for %@ --> %@",
                      labelDir, [error localizedDescription]);
                return;
            }
            NSMutableDictionary *imNames = [NSMutableDictionary new];
            NSArray *images = [fm contentsOfDirectoryAtPath:imageDir error:&error];
            if (error) {
                NSLog(@"Cannot get content for %@ --> %@",
                      imageDir, [error localizedDescription]);
                return;
            }
            NSInteger duplicateCounter = 0;
            for (NSInteger k = 0; k < images.count; k++) {
                NSString *imName = images[k];
                NSArray *comps = [imName componentsSeparatedByString:@"-"];
                NSString *fullImagePath = [imageDir stringByAppendingPathComponent:imName];
                NSString *prefix = comps[0];
                if (imNames[prefix]) {
                   NSLog(@">>>>>   image %@ just found! Old - %@ New -%@",
                        prefix, imNames[prefix], imName );
                  duplicateCounter++;
                } else {
                   imNames[prefix] = fullImagePath;
                }
            }
            if (duplicateCounter > 0) {
                NSLog(@"### Duplicates found - %ld", (long)duplicateCounter);
            }
            NSInteger labelReadError = 0;
            for (NSInteger k = 0; k < labelFiles.count; k++) {
                // parse label file name to extract image name
                Entry *newEntry = [[Entry alloc] init];
                NSArray *comps = [labelFiles[k] componentsSeparatedByString:@"-"];
                if (comps.count > 1) {
                    //Prefix is a start part
                    NSString *fNamePrefix = comps[0];
                    // Now we should check for presense of such image file
                    if (imNames[fNamePrefix]) {
                        // YES, we have such image!
                        NSString *labelFile = [labelDir stringByAppendingPathComponent:labelFiles[k]];
                        NSString *data = [[NSString alloc] initWithContentsOfFile:labelFile encoding:NSUTF8StringEncoding error:&error];
                        if (error) {
                            NSLog(@"#### Cannot read label file - %@ --> %@",labelFiles[k], [error localizedDescription]);
                            labelReadError++;
                        } else {
                            // Parse data. Extract rectangle parameters.
                            NSArray <NSString *> *comps = [data componentsSeparatedByString:@" "];
                            if (comps.count > 4) {
                                CGRect coords = CGRectMake(comps[1].doubleValue, comps[2].doubleValue,
                                                           comps[3].doubleValue, comps[4].doubleValue);
                                // this coords are presented in relative values
                                // But Create ML requires absolute coordinates, so we need to get
                                // actual image size and convert them
                                NSString *imageName = imNames[fNamePrefix];
                                NSImage *image = [[NSImage alloc] initWithContentsOfFile:imageName];
                                newEntry.fullPath = imageName;
                                newEntry.x = coords.origin.x;
                                newEntry.y = coords.origin.y;
                                newEntry.width = coords.size.width;
                                newEntry.height = coords.size.height;

                                if (image) {
                                    double width = image.size.width;
                                    double height = image.size.height;
                                    coords.origin.x *= width;
                                    coords.origin.y = height * (1.0 - coords.origin.y);
                                    coords.size.width *= width;
                                    coords.size.height *= height;

                                    newEntry.imageWidth = width;
                                    newEntry.imageHeight = height;
                                    //
                                    // Now we should create record for annotation file
                                    //
                                    /*
                                     Output record example
                                     Array of JSON entries

                                    {"annotations":[{
                                         "label":"Net",
                                         "coordinates":{"y":69,"x":287,"width":316,"height":37}
                                          }],
                                     "imagefilename":"NetDetector10.png"},
                                    */
                                    NSMutableArray *arr = [NSMutableArray new];
                                    NSMutableDictionary *dd = [NSMutableDictionary new];
                                    dd[@"label"] = self.objectNames[i];
                                    dd[@"coordinates"] = @{
                                        @"x":       @(coords.origin.x),
                                        @"y":       @(coords.origin.y),
                                        @"width":   @(coords.size.width),
                                        @"height":  @(coords.size.height),
                                    };
                                    [arr addObject:dd];
                                    NSString *fileName = [(NSString *)imNames[fNamePrefix] lastPathComponent];
                                    NSDictionary *d = @{
                                        @"annotations" : arr,
                                        @"imagefilename" : fileName,
                                    };
                                    // Now we should decide where image should be placed, and which
                                    // annotation file should be updated: train or test
                                    BOOL testZone = [self decideArea:(uint32_t)labelFiles.count];
                                    newEntry.testZone = testZone;
                                    if (prefs.generateOnStartup) {
                                        if (testZone) {
                                            // update test directory
                                            if ([self copyImage:imNames[fNamePrefix] to:@"train"
                                                     withTarget:self.objectNames[i]]) {
                                                [self.learningArrray addObject:d];
                                            }
                                        } else {
                                            // update train directory
                                            if ([self copyImage:imNames[fNamePrefix] to:@"test"
                                                     withTarget:self.objectNames[i]]) {
                                                [self.testingArray addObject:d];
                                            }
                                        }
                                    }
                                     // Add new entry to total list
                                    [self.list addObject:newEntry];
                               } else {
                                    NSLog(@"#### Image for prefix - %@ notFound. Skipping!", fNamePrefix);
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    // Final step - create annotations json file
    if (prefs.generateOnStartup) {
        [self writeAnnotations:self.learningArrray toDir:@"train"];
        [self writeAnnotations:self.testingArray toDir:@"test"];
    }
    NSBeep();
    NSBeep();

}


- (BOOL) copyImage:(NSString *)fileName to:(NSString *)destDir withTarget:(NSString *)targetDir
{
    NSFileManager *fm = [NSFileManager defaultManager];
    NSError *error = nil;
    NSString *targetPath = destDir; //[destDir stringByAppendingPathComponent:targetDir];
    targetPath = [DESTPATH stringByAppendingPathComponent:targetPath];
    if ([fm fileExistsAtPath:targetPath] == NO) {
        [fm createDirectoryAtPath:targetPath withIntermediateDirectories:YES attributes:nil error:&error];
        if (error) {
            NSLog(@"!!! Cannot create destination path - %@ ==> %@", destDir,[error localizedDescription]);
            return NO;
        }
    }
    NSString *destFileName = [targetPath stringByAppendingPathComponent:fileName.lastPathComponent];
    [fm copyItemAtPath:fileName toPath:destFileName error:&error];
    if (error) {
        NSLog(@"Cannot copy file %@ to %@ --> %@", fileName.lastPathComponent, targetDir,
               [error localizedDescription]);
        return NO;
    }
    return YES;
}


- (void) writeAnnotations:(NSArray *)array toDir:(NSString *)targetDir
{
    NSString *targetPath = [DESTPATH stringByAppendingPathComponent:targetDir];
    targetPath = [targetPath stringByAppendingPathComponent:@"annotations.json"];
    NSFileManager *fm = [NSFileManager defaultManager];
    NSError *error = nil;
    if ([fm fileExistsAtPath:targetPath]) {
        [fm removeItemAtPath:targetPath error:&error];
        if (error) {
            NSLog(@"### Cannot remove old annotations.json! - %@", [error localizedDescription]);
            return;
        }
    }
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:array
                                                       options:NSJSONWritingPrettyPrinted
                                                         error:&error];
    if (error) {
        NSLog(@"### Error during json preparing - %@", [error localizedDescription]);
        return;
    }
    NSString *jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];

    [jsonString writeToFile:targetPath atomically:NO encoding:NSUTF8StringEncoding error:&error];
    if (error) {
        NSLog(@"### Cannot write annotations.json file - %@", [error localizedDescription]);
    }

}

- (BOOL) decideArea:(uint32_t) amount
{
    double pip = (double)arc4random_uniform(amount) / (double)amount;
    return (pip < LEARN_THRESHOLD);
}

- (NSArray *) sets
{
    //return @[@"Ball_1", @"Ball_2", @"Ball_3"]; // @"Net_1"];
    return @[@"Net_1"];
}

- (NSArray *) objectNames
{
//    return @[@"Ball", @"Ball", @"Ball"]; // @"Net"];
    return @[@"Net"];
}

@end


@implementation Entry

- (NSString *) fileName
{
    return self.fullPath.lastPathComponent;
}

@end
