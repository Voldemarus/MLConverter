//
//  SourceFilesExtractor.h
//  MLConverter
//
//  Created by Водолазкий В.В. on 02.02.2022.
//

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface Entry : NSObject

@property   (nonatomic, readonly) NSString *fileName;
@property (nonatomic, retain) NSString *fullPath;
// parameters from original labels (relative)
@property (nonatomic) double x;
@property (nonatomic) double y;
@property (nonatomic) double width;
@property (nonatomic) double height;
// image dimensions
@property (nonatomic) double imageWidth;
@property (nonatomic) double imageHeight;
// YES if entry allocated to test area
@property (nonatomic) BOOL testZone;

@end


@interface SourceFilesExtractor : NSObject

@property (nonatomic, retain) NSMutableArray <Entry *> *list;

- (void) processFiles;

@end

NS_ASSUME_NONNULL_END
