//
//  TestModule.h
//  DCTestUniPlugin
//
//  Created by XHY on 2020/4/22.
//  Copyright © 2020 DCloud. All rights reserved.
//

#import <Foundation/Foundation.h>
#include <UIKit/UIKit.h>

@interface TomatoOCR : NSObject

+ (void)init:(NSString*)dirPath;

+ (void)initYolo:(NSString*)key modelPath:(NSString*)modelPath labelPath:(NSString*)labelPath;

+ (void)setMode:(NSString*)mode;

+ (void)setHttpIntervalTime:(NSNumber*)second;

+ (NSString*)setLicense:(NSString*)license_data;
+ (NSString*)setLicense:(NSString*)license_data remark:(NSString*)remark;

+ (void)setRecType:(NSString*)rec_type;

+ (void)setDetBoxType:(NSString*)det_box_type;

+ (void)setDetUnclipRatio:(NSNumber*)det_unclip_ratio;

+ (void)setRecScoreThreshold:(NSNumber*)rec_score_threshold;

+ (void)setReturnType:(NSString*)return_type;

+ (void)setBinaryThresh:(NSNumber*)binary_thresh;

+ (void)setRunMode:(NSString*)run_mode;

+ (void)setFilterColor:(NSString*)filter_color background_color:(NSString*)background_color;

+ (void)setBackgroundColor:(NSString*)background_color;


+ (NSString*)ocrUIImage:(UIImage*)image type:(NSNumber*)type;
+ (NSString*)ocrFile:(NSString*)filePath type:(NSNumber*)type;

+ (NSString*)findTapPoint:(NSString*)data;
+ (NSString*)findTapPoints:(NSString*)data;

+ (NSString*)yoloFile:(NSString*)key filePath:(NSString*)filePath targetSize:(NSNumber *)targetSize scoreThreshold:(NSNumber *)scoreThreshold nmsThreshold:(NSNumber *)nmsThreshold;
+ (NSString*)yoloUIImage:(NSString*)key image:(UIImage*)image  targetSize:(NSNumber *)targetSize scoreThreshold:(NSNumber *)scoreThreshold nmsThreshold:(NSNumber *)nmsThreshold;

+ (void)releaeYolo:(NSString*)key;

@end
