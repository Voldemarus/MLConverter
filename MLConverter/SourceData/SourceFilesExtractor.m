//
//  SourceFilesExtractor.m
//  MLConverter
//
//  Created by Водолазкий В.В. on 02.02.2022.
//

#import "SourceFilesExtractor.h"

#import "FilePointer.h"


#define LEARN_THRESHOLD 0.7         // to be used for training


@interface SourceFilesExtractor ()

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
                NSString *imName = images[i];
                NSArray *comps = [imName componentsSeparatedByString:@"-"];
                if (comps.count > 1) {
                    NSString *prefix = comps[0];
                    if (imNames[prefix]) {
                        NSLog(@">>>>>   image %@ just found! Old - %@ New -%@",
                              prefix, imNames[prefix], imName );
                        duplicateCounter++;
                    } else {
                        imNames[prefix] = imName;
                    }
                }
            }
            NSLog(@"### Duplicates found - %ld", (long)duplicateCounter);
            NSInteger labelReadError = 0;
            for (NSInteger k = 0; k < labelFiles.count; k++) {
                // parse label file name to extract image name
                NSArray *comps = [labelFiles[k] componentsSeparatedByString:@"-"];
                if (comps.count > 1) {
                    //Prefix is a start part
                    NSString *fNamePrefix = comps[0];
                    // Now we should check for presense of such image file
                    if (imNames[fNamePrefix]) {
                        // YES, we have such image!
                        NSString *data = [[NSString alloc] initWithContentsOfFile:labelFiles[k] encoding:NSUTF8StringEncoding error:&error];
                        if (error) {
                            NSLog(@"#### Cannot read label file - %@",labelFiles[k]);
                            labelReadError++;
                        } else {
                            // Parse data. Extract rectangle parameters.
                            NSScanner *scanner = [NSScanner scannerWithString:data];
                            NSCharacterSet *numbers = [NSCharacterSet characterSetWithCharactersInString:@".0123456789"];

                            // Throw away characters before the first number.
                            [scanner scanUpToCharactersFromSet:numbers intoString:NULL];

                            // Collect numbers.
                            float nums[20];
                            BOOL found = [scanner scanFloat:nums];
                            if (found) {
                                // this coords are presented in relative values
                                CGRect coords = CGRectMake(nums[1], nums[2], nums[3], nums[4]);
                                // But Create ML requires absolute coordinates, so we need to get
                                // actual image size and convert them
                                NSImage *image = [[NSImage alloc] initWithContentsOfFile:imNames[fNamePrefix]];
                                if (image) {
                                    double width = image.size.width;
                                    double height = image.size.height;
                                    coords.origin.x *= width;
                                    coords.origin.y *= height;
                                    coords.size.width *= width;
                                    coords.size.height *= height;

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
                                    if (testZone) {
                                        // update test directory
                                        [self.learningArrray addObject:d];
                                        [self copyImage:imNames[fNamePrefix] to:@"train"
                                             withTarget:self.objectNames[i]];
                                    } else {
                                        // update train directory
                                        [self.testingArray addObject:d];
                                        [self copyImage:imNames[fNamePrefix] to:@"test"
                                             withTarget:self.objectNames[i]];
                                    }

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
}


- (void) copyImage:(NSString *)fileName to:(NSString *)destDir withTarget:(NSString *)targetDir
{
    NSFileManager *fm = [NSFileManager defaultManager];
    NSError *error = nil;
    NSString *targetPath = [destDir stringByAppendingPathComponent:targetDir];
    if ([fm fileExistsAtPath:targetPath] == NO) {
        [fm createDirectoryAtPath:targetPath withIntermediateDirectories:YES attributes:nil error:&error];
        if (error) {
            NSLog(@"!!! Cannot create destination path - %@ ==> %@", destDir,[error localizedDescription]);
            return;
        }
        [fm copyItemAtPath:fileName toPath:targetPath error:&error];
        if (error) {
            NSLog(@"Cannot copy file %@ to %@", fileName.lastPathComponent, targetDir);
        }
    }

}


- (BOOL) decideArea:(uint32_t) amount
{
    double pip = arc4random_uniform(amount) * amount;
    return (pip > LEARN_THRESHOLD);
}

- (NSArray *) sets
{
    return @[@"Ball_1", @"Ball_2", @"Ball_3", @"Net_1"];
}

- (NSArray *) objectNames
{
    return @[@"Ball", @"Ball", @"Ball", @"Net"];
}

@end
