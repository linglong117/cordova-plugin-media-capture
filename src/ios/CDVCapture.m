/*
 Licensed to the Apache Software Foundation (ASF) under one
 or more contributor license agreements.  See the NOTICE file
 distributed with this work for additional information
 regarding copyright ownership.  The ASF licenses this file
 to you under the Apache License, Version 2.0 (the
 "License"); you may not use this file except in compliance
 with the License.  You may obtain a copy of the License at
 
 http://www.apache.org/licenses/LICENSE-2.0
 
 Unless required by applicable law or agreed to in writing,
 software distributed under the License is distributed on an
 "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
 KIND, either express or implied.  See the License for the
 specific language governing permissions and limitations
 under the License.
 */

#import "CDVCapture.h"
#import "CDVFile.h"
#import <Cordova/CDVJSON.h>
#import <Cordova/CDVAvailability.h>

#import <AssetsLibrary/AssetsLibrary.h>



#define kW3CMediaFormatHeight @"height"
#define kW3CMediaFormatWidth @"width"
#define kW3CMediaFormatCodecs @"codecs"
#define kW3CMediaFormatBitrate @"bitrate"
#define kW3CMediaFormatDuration @"duration"
#define kW3CMediaModeType @"type"

@implementation NSBundle (PluginExtensions)

+ (NSBundle*) pluginBundle:(CDVPlugin*)plugin {
    NSBundle* bundle = [NSBundle bundleWithPath: [[NSBundle mainBundle] pathForResource:NSStringFromClass([plugin class]) ofType: @"bundle"]];
    return bundle;
}
@end

#define PluginLocalizedString(plugin, key, comment) [[NSBundle pluginBundle:(plugin)] localizedStringForKey:(key) value:nil table:nil]

@implementation CDVImagePicker

@synthesize quality;
@synthesize callbackId;
@synthesize mimeType;

- (uint64_t)accessibilityTraits
{
    NSString* systemVersion = [[UIDevice currentDevice] systemVersion];
    
    if (([systemVersion compare:@"4.0" options:NSNumericSearch] != NSOrderedAscending)) { // this means system version is not less than 4.0
        return UIAccessibilityTraitStartsMediaSession;
    }
    
    return UIAccessibilityTraitNone;
}

- (BOOL)prefersStatusBarHidden {
    return YES;
}

- (UIViewController*)childViewControllerForStatusBarHidden {
    return nil;
}

- (void)viewWillAppear:(BOOL)animated {
    SEL sel = NSSelectorFromString(@"setNeedsStatusBarAppearanceUpdate");
    if ([self respondsToSelector:sel]) {
        [self performSelector:sel withObject:nil afterDelay:0];
    }
    
    [super viewWillAppear:animated];
}

@end

@implementation CDVCapture
@synthesize inUse;

- (id)initWithWebView:(UIWebView*)theWebView
{
    self = (CDVCapture*)[super initWithWebView:theWebView];
    if (self) {
        self.inUse = NO;
    }
    return self;
}

- (void)captureAudio:(CDVInvokedUrlCommand*)command
{
    NSString* callbackId = command.callbackId;
    NSDictionary* options = [command.arguments objectAtIndex:0];
    
    if ([options isKindOfClass:[NSNull class]]) {
        options = [NSDictionary dictionary];
    }
    
    NSNumber* duration = [options objectForKey:@"duration"];
    // the default value of duration is 0 so use nil (no duration) if default value
    if (duration) {
        duration = [duration doubleValue] == 0 ? nil : duration;
    }
    CDVPluginResult* result = nil;
    
    if (NSClassFromString(@"AVAudioRecorder") == nil) {
        result = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageToErrorObject:CAPTURE_NOT_SUPPORTED];
    } else if (self.inUse == YES) {
        result = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageToErrorObject:CAPTURE_APPLICATION_BUSY];
    } else {
        // all the work occurs here
        CDVAudioRecorderViewController* audioViewController = [[CDVAudioRecorderViewController alloc] initWithCommand:self duration:duration callbackId:callbackId];
        
        // Now create a nav controller and display the view...
        CDVAudioNavigationController* navController = [[CDVAudioNavigationController alloc] initWithRootViewController:audioViewController];
        
        self.inUse = YES;
        
        [self.viewController presentViewController:navController animated:YES completion:nil];
    }
    
    if (result) {
        [self.commandDelegate sendPluginResult:result callbackId:callbackId];
    }
}

- (void)captureImage:(CDVInvokedUrlCommand*)command
{
    NSString* callbackId = command.callbackId;
    NSDictionary* options = [command.arguments objectAtIndex:0];
    
    if ([options isKindOfClass:[NSNull class]]) {
        options = [NSDictionary dictionary];
    }
    
    // options could contain limit and mode neither of which are supported at this time
    // taking more than one picture (limit) is only supported if provide own controls via cameraOverlayView property
    // can support mode in OS
    
    if (![UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypeCamera]) {
        NSLog(@"Capture.imageCapture: camera not available.");
        CDVPluginResult* result = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageToErrorObject:CAPTURE_NOT_SUPPORTED];
        [self.commandDelegate sendPluginResult:result callbackId:callbackId];
    } else {
        
        
        if (pickerController == nil) {
            pickerController = [[CDVImagePicker alloc] init];
        }
        
        pickerController.delegate = self;
        pickerController.sourceType = UIImagePickerControllerSourceTypeCamera;
        pickerController.allowsEditing = NO;
        if ([pickerController respondsToSelector:@selector(mediaTypes)]) {
            // iOS 3.0
            pickerController.mediaTypes = [NSArray arrayWithObjects:(NSString*)kUTTypeImage, nil];
        }
        
        /*if ([pickerController respondsToSelector:@selector(cameraCaptureMode)]){
         // iOS 4.0
         pickerController.cameraCaptureMode = UIImagePickerControllerCameraCaptureModePhoto;
         pickerController.cameraDevice = UIImagePickerControllerCameraDeviceRear;
         pickerController.cameraFlashMode = UIImagePickerControllerCameraFlashModeAuto;
         }*/
        
//        BOOL cameraAvailableFlag = [UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypeCamera];
//        if (cameraAvailableFlag)
//            [self performSelector:@selector(showcamera) withObject:nil afterDelay:0.3];
        
        
        // CDVImagePicker specific property
        pickerController.callbackId = callbackId;
        
        
        // Snapshotting a view that has not been rendered results in an empty snapshot. Ensure your view has been rendered at least once before snapshotting or snapshot after screen updates.
//        if ([UIImagePickerController isSourceTypeAvailable: UIImagePickerControllerSourceTypeCamera]) {
//            if ([[[UIDevice currentDevice] systemVersion] floatValue] !=7){
//                [self initCamera];
//            }
//            
//            [self.viewController presentViewController:pickerController animated:YES completion:nil];
//
//            //[self presentViewController:pickerController animated:YES completion:nil];
//            
//        }else {
//            //[BlmFuncView showWarn:@"你没有摄像头" andTime:1.5];
//            NSLog(@"你没有摄像头");
 //       }
        
        double delayInSeconds = 0.5;
        dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, delayInSeconds * NSEC_PER_SEC);
        dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
            [self.viewController presentViewController:pickerController animated:YES completion:nil];
        });
        
        //[self.viewController presentViewController:pickerController animated:YES completion:nil];

    
    }
}

-(void)initCamera
{
    //if (pickerController==nil) {
        pickerController = [[CDVImagePicker alloc] init];
        pickerController.delegate = self;
        pickerController.allowsEditing = YES;
        pickerController.sourceType = UIImagePickerControllerSourceTypeCamera;
    //}
}

/* Process a still image from the camera.
 * IN:
 *  UIImage* image - the UIImage data returned from the camera
 *  NSString* callbackId
 */
- (CDVPluginResult*)processImage:(UIImage*)image type:(NSString*)mimeType forCallbackId:(NSString*)callbackId
{
    CDVPluginResult* result = nil;
    
    /*
     *  不保存到 photosAlbum  2015-01-08 11:06:54   by xyl======
     **/
    // save the image to photo album
    //UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil);
    
    NSData* data = nil;
    if (mimeType && [mimeType isEqualToString:@"image/png"]) {
        data = UIImagePNGRepresentation(image);
    } else {
        data = UIImageJPEGRepresentation(image, 0.5);
    }
    
    // write to temp directory and return URI
    NSString* docsPath = [NSTemporaryDirectory()stringByStandardizingPath];   // use file system temporary directory
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];
    NSString *documentPath = [documentsDirectory stringByAppendingPathComponent:@"MediaCapture"];
    BOOL isDir = FALSE;
    BOOL isDirExist = [fileManager fileExistsAtPath:documentPath   isDirectory:&isDir];
    if(!(isDirExist && isDir))
    {
        BOOL bCreateDir = [fileManager createDirectoryAtPath:documentPath
                                 withIntermediateDirectories:YES
                                                  attributes:nil
                                                       error:nil];
        if(!bCreateDir){
            NSLog(@"Create Audio Directory Failed.");
        }
        NSLog(@"%@",documentPath);
    }
    
    
    NSError* err = nil;
    NSFileManager* fileMgr = [[NSFileManager alloc] init];
    
    // generate unique file name
    NSString* filePath;
    NSString *fileName = [self getCurrentDateString];
    int i = 1;
    do {
        //filePath = [NSString stringWithFormat:@"%@/photo_%03d.jpg", documentPath, i++];
        filePath = [NSString stringWithFormat:@"%@/%@.jpg", documentPath, fileName];
        
    } while ([fileMgr fileExistsAtPath:filePath]);
    
    if (![data writeToFile:filePath options:NSAtomicWrite error:&err]) {
        result = [CDVPluginResult resultWithStatus:CDVCommandStatus_IO_EXCEPTION messageToErrorObject:CAPTURE_INTERNAL_ERR];
        if (err) {
            NSLog(@"Error saving image: %@", [err localizedDescription]);
        }
    } else {
        // create MediaFile object
        
        NSDictionary* fileDict = [self getMediaDictionaryFromPath:filePath ofType:mimeType];
        NSArray* fileArray = [NSArray arrayWithObject:fileDict];
        
        result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsArray:fileArray];
    }
    
    return result;
}

- (void)captureVideo:(CDVInvokedUrlCommand*)command
{
    NSString* callbackId = command.callbackId;
    NSDictionary* options = [command.arguments objectAtIndex:0];
    
    if ([options isKindOfClass:[NSNull class]]) {
        options = [NSDictionary dictionary];
    }
    
    // options could contain limit, duration and mode
    // taking more than one video (limit) is only supported if provide own controls via cameraOverlayView property
    NSNumber* duration = [options objectForKey:@"duration"];
    NSString* mediaType = nil;
    
    if ([UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypeCamera]) {
        // there is a camera, it is available, make sure it can do movies
        pickerController = [[CDVImagePicker alloc] init];
        
        NSArray* types = nil;
        if ([UIImagePickerController respondsToSelector:@selector(availableMediaTypesForSourceType:)]) {
            types = [UIImagePickerController availableMediaTypesForSourceType:UIImagePickerControllerSourceTypeCamera];
            // NSLog(@"MediaTypes: %@", [types description]);
            
            if ([types containsObject:(NSString*)kUTTypeMovie]) {
                mediaType = (NSString*)kUTTypeMovie;
            } else if ([types containsObject:(NSString*)kUTTypeVideo]) {
                mediaType = (NSString*)kUTTypeVideo;
            }
        }
    }
    if (!mediaType) {
        // don't have video camera return error
        NSLog(@"Capture.captureVideo: video mode not available.");
        CDVPluginResult* result = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageToErrorObject:CAPTURE_NOT_SUPPORTED];
        [self.commandDelegate sendPluginResult:result callbackId:callbackId];
        pickerController = nil;
    } else {
        pickerController.delegate = self;
        pickerController.sourceType = UIImagePickerControllerSourceTypeCamera;
        pickerController.allowsEditing = NO;
        // iOS 3.0
        pickerController.mediaTypes = [NSArray arrayWithObjects:mediaType, nil];
        
        if ([mediaType isEqualToString:(NSString*)kUTTypeMovie]){
            if (duration) {
                pickerController.videoMaximumDuration = [duration doubleValue];
            }
            //NSLog(@"pickerController.videoMaximumDuration = %f", pickerController.videoMaximumDuration);
        }
        
        // iOS 4.0
        if ([pickerController respondsToSelector:@selector(cameraCaptureMode)]) {
            pickerController.cameraCaptureMode = UIImagePickerControllerCameraCaptureModeVideo;
            pickerController.videoQuality = UIImagePickerControllerQualityTypeHigh;
            pickerController.cameraDevice = UIImagePickerControllerCameraDeviceRear;
            pickerController.cameraFlashMode = UIImagePickerControllerCameraFlashModeAuto;
        }
        // CDVImagePicker specific property
        pickerController.callbackId = callbackId;
        
        [self.viewController presentViewController:pickerController animated:YES completion:nil];
    }
}

- (CDVPluginResult*)processVideo:(NSString*)moviePath forCallbackId:(NSString*)callbackId
{
    // save the movie to photo album (only avail as of iOS 3.1)
    
    /* don't need, it should automatically get saved
     NSLog(@"can save %@: %d ?", moviePath, UIVideoAtPathIsCompatibleWithSavedPhotosAlbum(moviePath));
     if (&UIVideoAtPathIsCompatibleWithSavedPhotosAlbum != NULL && UIVideoAtPathIsCompatibleWithSavedPhotosAlbum(moviePath) == YES) {
     NSLog(@"try to save movie");
     UISaveVideoAtPathToSavedPhotosAlbum(moviePath, nil, nil, nil);
     NSLog(@"finished saving movie");
     }*/
    // create MediaFile object
    NSDictionary* fileDict = [self getMediaDictionaryFromPath:moviePath ofType:nil];
    NSArray* fileArray = [NSArray arrayWithObject:fileDict];
    
    return [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsArray:fileArray];
}

- (void)getMediaModes:(CDVInvokedUrlCommand*)command
{
    // NSString* callbackId = [arguments objectAtIndex:0];
    // NSMutableDictionary* imageModes = nil;
    NSArray* imageArray = nil;
    NSArray* movieArray = nil;
    NSArray* audioArray = nil;
    
    if ([UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypeCamera]) {
        // there is a camera, find the modes
        // can get image/jpeg or image/png from camera
        
        /* can't find a way to get the default height and width and other info
         * for images/movies taken with UIImagePickerController
         */
        NSDictionary* jpg = [NSDictionary dictionaryWithObjectsAndKeys:
                             [NSNumber numberWithInt:0], kW3CMediaFormatHeight,
                             [NSNumber numberWithInt:0], kW3CMediaFormatWidth,
                             @"image/jpeg", kW3CMediaModeType,
                             nil];
        NSDictionary* png = [NSDictionary dictionaryWithObjectsAndKeys:
                             [NSNumber numberWithInt:0], kW3CMediaFormatHeight,
                             [NSNumber numberWithInt:0], kW3CMediaFormatWidth,
                             @"image/png", kW3CMediaModeType,
                             nil];
        imageArray = [NSArray arrayWithObjects:jpg, png, nil];
        
        if ([UIImagePickerController respondsToSelector:@selector(availableMediaTypesForSourceType:)]) {
            NSArray* types = [UIImagePickerController availableMediaTypesForSourceType:UIImagePickerControllerSourceTypeCamera];
            
            if ([types containsObject:(NSString*)kUTTypeMovie]) {
                NSDictionary* mov = [NSDictionary dictionaryWithObjectsAndKeys:
                                     [NSNumber numberWithInt:0], kW3CMediaFormatHeight,
                                     [NSNumber numberWithInt:0], kW3CMediaFormatWidth,
                                     @"video/quicktime", kW3CMediaModeType,
                                     nil];
                movieArray = [NSArray arrayWithObject:mov];
            }
        }
    }
    NSDictionary* modes = [NSDictionary dictionaryWithObjectsAndKeys:
                           imageArray ? (NSObject*)                          imageArray:[NSNull null], @"image",
                           movieArray ? (NSObject*)                          movieArray:[NSNull null], @"video",
                           audioArray ? (NSObject*)                          audioArray:[NSNull null], @"audio",
                           nil];
    NSString* jsString = [NSString stringWithFormat:@"navigator.device.capture.setSupportedModes(%@);", [modes JSONString]];
    [self.commandDelegate evalJs:jsString];
}

- (void)getFormatData:(CDVInvokedUrlCommand*)command
{
    NSString* callbackId = command.callbackId;
    // existence of fullPath checked on JS side
    NSString* fullPath = [command.arguments objectAtIndex:0];
    // mimeType could be null
    NSString* mimeType = nil;
    
    if ([command.arguments count] > 1) {
        mimeType = [command.arguments objectAtIndex:1];
    }
    BOOL bError = NO;
    CDVCaptureError errorCode = CAPTURE_INTERNAL_ERR;
    CDVPluginResult* result = nil;
    
    if (!mimeType || [mimeType isKindOfClass:[NSNull class]]) {
        // try to determine mime type if not provided
        id command = [self.commandDelegate getCommandInstance:@"File"];
        bError = !([command isKindOfClass:[CDVFile class]]);
        if (!bError) {
            CDVFile* cdvFile = (CDVFile*)command;
            mimeType = [cdvFile getMimeTypeFromPath:fullPath];
            if (!mimeType) {
                // can't do much without mimeType, return error
                bError = YES;
                errorCode = CAPTURE_INVALID_ARGUMENT;
            }
        }
    }
    if (!bError) {
        // create and initialize return dictionary
        NSMutableDictionary* formatData = [NSMutableDictionary dictionaryWithCapacity:5];
        [formatData setObject:[NSNull null] forKey:kW3CMediaFormatCodecs];
        [formatData setObject:[NSNumber numberWithInt:0] forKey:kW3CMediaFormatBitrate];
        [formatData setObject:[NSNumber numberWithInt:0] forKey:kW3CMediaFormatHeight];
        [formatData setObject:[NSNumber numberWithInt:0] forKey:kW3CMediaFormatWidth];
        [formatData setObject:[NSNumber numberWithInt:0] forKey:kW3CMediaFormatDuration];
        
        if ([mimeType rangeOfString:@"image/"].location != NSNotFound) {
            UIImage* image = [UIImage imageWithContentsOfFile:fullPath];
            if (image) {
                CGSize imgSize = [image size];
                [formatData setObject:[NSNumber numberWithInteger:imgSize.width] forKey:kW3CMediaFormatWidth];
                [formatData setObject:[NSNumber numberWithInteger:imgSize.height] forKey:kW3CMediaFormatHeight];
            }
        } else if (([mimeType rangeOfString:@"video/"].location != NSNotFound) && (NSClassFromString(@"AVURLAsset") != nil)) {
            NSURL* movieURL = [NSURL fileURLWithPath:fullPath];
            AVURLAsset* movieAsset = [[AVURLAsset alloc] initWithURL:movieURL options:nil];
            CMTime duration = [movieAsset duration];
            [formatData setObject:[NSNumber numberWithFloat:CMTimeGetSeconds(duration)]  forKey:kW3CMediaFormatDuration];
            
            NSArray* allVideoTracks = [movieAsset tracksWithMediaType:AVMediaTypeVideo];
            if ([allVideoTracks count] > 0) {
                AVAssetTrack* track = [[movieAsset tracksWithMediaType:AVMediaTypeVideo] objectAtIndex:0];
                CGSize size = [track naturalSize];
                
                [formatData setObject:[NSNumber numberWithFloat:size.height] forKey:kW3CMediaFormatHeight];
                [formatData setObject:[NSNumber numberWithFloat:size.width] forKey:kW3CMediaFormatWidth];
                // not sure how to get codecs or bitrate???
                // AVMetadataItem
                // AudioFile
            } else {
                NSLog(@"No video tracks found for %@", fullPath);
            }
        } else if ([mimeType rangeOfString:@"audio/"].location != NSNotFound) {
            if (NSClassFromString(@"AVAudioPlayer") != nil) {
                NSURL* fileURL = [NSURL fileURLWithPath:fullPath];
                NSError* err = nil;
                
                AVAudioPlayer* avPlayer = [[AVAudioPlayer alloc] initWithContentsOfURL:fileURL error:&err];
                if (!err) {
                    // get the data
                    [formatData setObject:[NSNumber numberWithDouble:[avPlayer duration]] forKey:kW3CMediaFormatDuration];
                    if ([avPlayer respondsToSelector:@selector(settings)]) {
                        NSDictionary* info = [avPlayer settings];
                        NSNumber* bitRate = [info objectForKey:AVEncoderBitRateKey];
                        if (bitRate) {
                            [formatData setObject:bitRate forKey:kW3CMediaFormatBitrate];
                        }
                    }
                } // else leave data init'ed to 0
            }
        }
        result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:formatData];
        // NSLog(@"getFormatData: %@", [formatData description]);
    }
    if (bError) {
        result = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageToErrorObject:(int)errorCode];
    }
    if (result) {
        [self.commandDelegate sendPluginResult:result callbackId:callbackId];
    }
}

- (NSDictionary*)getMediaDictionaryFromPath:(NSString*)fullPath ofType:(NSString*)type
{
    NSFileManager* fileMgr = [[NSFileManager alloc] init];
    NSMutableDictionary* fileDict = [NSMutableDictionary dictionaryWithCapacity:5];
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];
    
    CDVFile *fs = [self.commandDelegate getCommandInstance:@"File"];
    
    // Get canonical version of localPath
    NSURL *fileURL = [NSURL URLWithString:[NSString stringWithFormat:@"file://%@", fullPath]];
    NSURL *resolvedFileURL = [fileURL URLByResolvingSymlinksInPath];
    NSString *path = [resolvedFileURL path];
    
    CDVFilesystemURL *url = [fs fileSystemURLforLocalPath:path];
    
    [fileDict setObject:[fullPath lastPathComponent] forKey:@"name"];
    [fileDict setObject:fullPath forKey:@"fullPath"];
    if (url) {
        [fileDict setObject:[url absoluteURL] forKey:@"localURL"];
    }
    
    [fileDict setObject:@"" forKey:@"fileThumbnailPath"];

    // determine type
    if (!type) {
        id command = [self.commandDelegate getCommandInstance:@"File"];
        if ([command isKindOfClass:[CDVFile class]]) {
            CDVFile* cdvFile = (CDVFile*)command;
            NSString* mimeType = [cdvFile getMimeTypeFromPath:fullPath];
            [fileDict setObject:(mimeType != nil ? (NSObject*)mimeType : [NSNull null]) forKey:@"type"];
            
            //获取视频第一帧
            if ([mimeType isEqualToString:@"video/quicktime"]) {
                
                UIImage *img =  [self imageWithMediaURL:resolvedFileURL];
                //NSLog(@"dddd  %@",img);
                NSString *thumb_path = [self doSaveThumb:img];
                //if (thumb_path && [thumb_path length]>0) {
                [fileDict setObject:thumb_path forKey:@"fileThumbnailPath"];
                //}
                
                //                UIImageView *imageView = [[UIImageView alloc] initWithImage:img];
                //                imageView.frame = CGRectMake(50, 50, 300, 300);
                //[self.viewController.view addSubview:imageView];
            }
            
            //获取图片缩略图
            
            if([mimeType rangeOfString:@"image"].location !=NSNotFound)//_roaldSearchText
            {
                UIImage *img = [self thumbnailWithImage:nil size:CGSizeMake(300, 300) path:path];
                //UIImage *img = [self thumbnailWithImageWithoutScale:nil size:CGSizeMake(300, 300) path:path];

                    //NSLog(@"dddd  %@",img);
                    NSString *thumb_path = [self doSaveThumb:img];
                    //if (thumb_path && [thumb_path length]>0) {
                    [fileDict setObject:thumb_path forKey:@"fileThumbnailPath"];
                    //}
//                
//                UIImageView *imageView = [[UIImageView alloc] initWithImage:img];
//                imageView.frame = CGRectMake(10, 100, 300, 300);
//                [self.viewController.view addSubview:imageView];
            }
        }
    }
    NSDictionary* fileAttrs = [fileMgr attributesOfItemAtPath:fullPath error:nil];
    [fileDict setObject:[NSNumber numberWithUnsignedLongLong:[fileAttrs fileSize]] forKey:@"size"];
    NSDate* modDate = [fileAttrs fileModificationDate];
    NSNumber* msDate = [NSNumber numberWithDouble:[modDate timeIntervalSince1970] * 1000];
    [fileDict setObject:msDate forKey:@"lastModifiedDate"];
    
    
    AVURLAsset *audioAsset =[AVURLAsset URLAssetWithURL:fileURL options:nil];
    CMTime audioDuration = audioAsset.duration;
    int audioDurationSeconds =CMTimeGetSeconds(audioDuration);
    
    NSString  *timelong = [NSString stringWithFormat:@"%d",audioDurationSeconds] ;
    NSLog(@"时长>>>>  %d",audioDurationSeconds);
    [fileDict setObject:timelong forKey:@"fileDuration"];

    return fileDict;
}


/**
 * 
 */
//1.自动缩放到指定大小
- (UIImage *)thumbnailWithImage:(UIImage *)image size:(CGSize)asize path:(NSString*) path
{
    image = [UIImage imageWithContentsOfFile:path];
    
    UIImage *newimage;
    
    if (nil == image) {
        newimage = nil;
    }else{
        UIGraphicsBeginImageContext(asize);
        [image drawInRect:CGRectMake(0, 0, asize.width, asize.height)];
        newimage = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
    }
    return newimage;
}

//2.保持原来的长宽比，生成一个缩略图
- (UIImage *)thumbnailWithImageWithoutScale:(UIImage *)image size:(CGSize)asize path:(NSString*) path
{
    image = [UIImage imageWithContentsOfFile:path];

    UIImage *newimage;
    if (nil == image) {
        newimage = nil;
    }else{
        CGSize oldsize = image.size;
        CGRect rect;
        if (asize.width/asize.height > oldsize.width/oldsize.height) {
            rect.size.width = asize.height*oldsize.width/oldsize.height;
            rect.size.height = asize.height;
            rect.origin.x = (asize.width - rect.size.width)/2;
            rect.origin.y = 0;
        }else{
            rect.size.width = asize.width;
            rect.size.height = asize.width*oldsize.height/oldsize.width;
            rect.origin.x = 0;
            rect.origin.y = (asize.height - rect.size.height)/2;
        }
        UIGraphicsBeginImageContext(asize);
        CGContextRef context = UIGraphicsGetCurrentContext();
        CGContextSetFillColorWithColor(context, [[UIColor clearColor] CGColor]);
        UIRectFill(CGRectMake(0, 0, asize.width, asize.height));//clear background
        [image drawInRect:rect];
        newimage = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
    }
    return newimage;
}



/**
 *  通过音乐地址，读取音乐数据，获得图片
 *
 *  @param url 音乐地址
 *
 *  @return音乐图片
 */
- (UIImage *)musicImageWithMusicURL:(NSURL *)url {
    NSData *data = nil;
    // 初始化媒体文件
    AVURLAsset *mp3Asset = [AVURLAsset URLAssetWithURL:url options:nil];
    // 读取文件中的数据
    for (NSString *format in [mp3Asset availableMetadataFormats]) {
        for (AVMetadataItem *metadataItem in [mp3Asset metadataForFormat:format]) {
            //artwork这个key对应的value里面存的就是封面缩略图，其它key可以取出其它摘要信息，例如title - 标题
            if ([metadataItem.commonKey isEqualToString:@"artwork"]) {
                data = [(NSDictionary*)metadataItem.value objectForKey:@"data"];
                break;
            }
        }
    }
    if (!data) {
        // 如果音乐没有图片，就返回默认图片
        return [UIImage imageNamed:@"default"];
    }
    return [UIImage imageWithData:data];
}

/**
 *  通过视频的URL，获得视频缩略图
 *
 *  @param url 视频URL
 *
 *  @return首帧缩略图
 */
- (UIImage *)imageWithMediaURL:(NSURL *)url {
    NSDictionary *opts = [NSDictionary dictionaryWithObject:[NSNumber numberWithBool:NO]
                                                     forKey:AVURLAssetPreferPreciseDurationAndTimingKey];
    // 初始化媒体文件
    AVURLAsset *urlAsset = [AVURLAsset URLAssetWithURL:url options:opts];
    // 根据asset构造一张图
    AVAssetImageGenerator *generator = [AVAssetImageGenerator assetImageGeneratorWithAsset:urlAsset];
    // 设定缩略图的方向
    // 如果不设定，可能会在视频旋转90/180/270°时，获取到的缩略图是被旋转过的，而不是正向的（自己的理解）
    generator.appliesPreferredTrackTransform = YES;
    // 设置图片的最大size(分辨率)
    generator.maximumSize = CGSizeMake(300, 300);
    // 初始化error
    NSError *error = nil;
    // 根据时间，获得第N帧的图片
    // CMTimeMake(a, b)可以理解为获得第a/b秒的frame
    CGImageRef img = [generator copyCGImageAtTime:CMTimeMake(0, 10000) actualTime:NULL error:&error];
    // 构造图片
    UIImage *image = [UIImage imageWithCGImage: img];
    return image;
}

-(UIImage *)getImage:(NSString *)videoURL
{
    AVURLAsset *asset = [[AVURLAsset alloc] initWithURL:[NSURL fileURLWithPath:videoURL] options:nil];
    
    AVAssetImageGenerator *gen = [[AVAssetImageGenerator alloc] initWithAsset:asset];
    
    gen.appliesPreferredTrackTransform = YES;
    
    CMTime time = CMTimeMakeWithSeconds(0.0, 600);
    
    NSError *error = nil;
    
    CMTime actualTime;
    
    CGImageRef image = [gen copyCGImageAtTime:time actualTime:&actualTime error:&error];
    
    UIImage *thumb = [[UIImage alloc] initWithCGImage:image];
    
    CGImageRelease(image);
    
    return thumb;
}


/*
 *
*/
- (NSString *)doSaveThumb:(UIImage*)image
{
    
    /*
     *  不保存到 photosAlbum  2015-01-08 11:06:54   by xyl======
     **/
    // save the image to photo album
    //UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil);
    
    NSData* data = nil;
    data = UIImageJPEGRepresentation(image, 0.5);
    // write to temp directory and return URI
    //NSString* docsPath = [NSTemporaryDirectory()stringByStandardizingPath];   // use file system temporary directory
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];
    NSString *documentPath = [documentsDirectory stringByAppendingPathComponent:@"MediaCapture"];
    BOOL isDir = FALSE;
    BOOL isDirExist = [fileManager fileExistsAtPath:documentPath   isDirectory:&isDir];
    if(!(isDirExist && isDir))
    {
        BOOL bCreateDir = [fileManager createDirectoryAtPath:documentPath
                                 withIntermediateDirectories:YES
                                                  attributes:nil
                                                       error:nil];
        if(!bCreateDir){
            NSLog(@"Create Audio Directory Failed.");
        }
        NSLog(@"%@",documentPath);
    }
    
    NSError* err = nil;
    NSFileManager* fileMgr = [[NSFileManager alloc] init];
    
    // generate unique file name
    NSString* filePath;
    NSString *fileName = [self getCurrentDateString];
    do {
        //filePath = [NSString stringWithFormat:@"%@/photo_%03d.jpg", documentPath, i++];
        filePath = [NSString stringWithFormat:@"%@/%@_thumb.jpg", documentPath, fileName];
        
    } while ([fileMgr fileExistsAtPath:filePath]);
    
    if (![data writeToFile:filePath options:NSAtomicWrite error:&err]) {
        //result = [CDVPluginResult resultWithStatus:CDVCommandStatus_IO_EXCEPTION messageToErrorObject:CAPTURE_INTERNAL_ERR];
        if (err) {
            NSLog(@"Error saving image: %@", [err localizedDescription]);
        }
    } else {
        // create MediaFile object
        // 
        // NSDictionary* fileDict = [self getMediaDictionaryFromPath:filePath ofType:mimeType];
        // NSArray* fileArray = [NSArray arrayWithObject:fileDict];
        //result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsArray:fileArray];
        return filePath;
    }
    return  @"";
    
}

 

//+(UIImage *)fFirstVideoFrame:(NSString *)path
//{
//    MPMoviePlayerController *mp = [[MPMoviePlayerController alloc] initWithContentURL:[NSURL fileURLWithPath:path]];
//    UIImage *img = [mp thumbnailImageAtTime:0.0 timeOption:MPMovieTimeOptionNearest[object Object]KeyFrame];
//    return img;
//}



- (void)imagePickerController:(UIImagePickerController*)picker didFinishPickingImage:(UIImage*)image editingInfo:(NSDictionary*)editingInfo
{
    // older api calls new one
    [self imagePickerController:picker didFinishPickingMediaWithInfo:editingInfo];
}

/* Called when image/movie is finished recording.
 * Calls success or error code as appropriate
 * if successful, result  contains an array (with just one entry since can only get one image unless build own camera UI) of MediaFile object representing the image
 *      name
 *      fullPath
 *      type
 *      lastModifiedDate
 *      size
 */
- (void)imagePickerController:(UIImagePickerController*)picker didFinishPickingMediaWithInfo:(NSDictionary*)info
{
    CDVImagePicker* cameraPicker = (CDVImagePicker*)picker;
    NSString* callbackId = cameraPicker.callbackId;
    
    [[picker presentingViewController] dismissViewControllerAnimated:YES completion:nil];
    
    CDVPluginResult* result = nil;
    
    UIImage* image = nil;
    NSString* mediaType = [info objectForKey:UIImagePickerControllerMediaType];
    
    if (!mediaType || [mediaType isEqualToString:(NSString*)kUTTypeImage]) {
        // mediaType is nil then only option is UIImagePickerControllerOriginalImage
        if ([UIImagePickerController respondsToSelector:@selector(allowsEditing)] &&
            (cameraPicker.allowsEditing && [info objectForKey:UIImagePickerControllerEditedImage])) {
            image = [info objectForKey:UIImagePickerControllerEditedImage];
        } else {
            image = [info objectForKey:UIImagePickerControllerOriginalImage];
        }
    }
    if (image != nil) {
        // mediaType was image
        result = [self processImage:image type:cameraPicker.mimeType forCallbackId:callbackId];
    } else if ([mediaType isEqualToString:(NSString*)kUTTypeMovie]) {
        // process video
        //NSString* moviePath = [[info objectForKey:UIImagePickerControllerMediaURL] path];
        NSString* moviePath = [[info objectForKey:UIImagePickerControllerMediaURL] absoluteString];
        NSURL *videoURL = [info objectForKey:UIImagePickerControllerMediaURL];
        //        NSData *webData = [NSData dataWithContentsOfURL:videoURL];
        //        //NSData *video = [[NSString alloc] initWithContentsOfURL:videoURL];
        //        //[webData writeToFile:[self findUniqueMoviePath] atomically:YES];
        //        CFShow((__bridge CFTypeRef)([[NSFileManager defaultManager] directoryContentsAtPath:[NSHomeDirectory() stringByAppendingString:@"/Documents"]]));
        //        //CFShow([[NSFileManager defaultManager] directoryContentsAtPath:[NSHomeDirectory() stringByAppendingString:@"/Documents"]]);
        moviePath = [self videoPath:videoURL];
        if (moviePath && [moviePath length]>0) {
            result = [self processVideo:moviePath forCallbackId:callbackId];
        }
    }
    if (!result) {
        result = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageToErrorObject:CAPTURE_INTERNAL_ERR];
    }
    [self.commandDelegate sendPluginResult:result callbackId:callbackId];
    pickerController = nil;
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController*)picker
{
    CDVImagePicker* cameraPicker = (CDVImagePicker*)picker;
    NSString* callbackId = cameraPicker.callbackId;
    
    [[picker presentingViewController] dismissViewControllerAnimated:YES completion:nil];
    
    CDVPluginResult* result = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageToErrorObject:CAPTURE_NO_MEDIA_FILES];
    [self.commandDelegate sendPluginResult:result callbackId:callbackId];
    pickerController = nil;
}


/*
 *
 */
-(Boolean)createMediaCaptureDir{
    
    //BOOL success;
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSString *documentsDirectory=[NSHomeDirectory() stringByAppendingPathComponent:@"Documents"];
    NSString *documentPath = [documentsDirectory stringByAppendingPathComponent:@"MediaCapture"];
    BOOL isDir = FALSE;
    BOOL isDirExist = [fileManager fileExistsAtPath:documentPath   isDirectory:&isDir];
    if(!(isDirExist && isDir))
    {
        BOOL bCreateDir = [fileManager createDirectoryAtPath:documentPath
                                 withIntermediateDirectories:YES
                                                  attributes:nil
                                                       error:nil];
        if(!bCreateDir){
            NSLog(@"Create Audio Directory Failed.");
        }
        NSLog(@"%@",documentPath);
        return bCreateDir;
    }
    return true;
}

- (NSString*)videoPath:(NSURL*)mediaURL
{
    BOOL success;
    //NSFileManager *fileManager = [NSFileManager defaultManager];
    //获取视频文件的url
    
    //NSURL* mediaURL = [info objectForKey:UIImagePickerControllerMediaURL];
    
    Boolean isExistMediaCaptureDir = [self createMediaCaptureDir];
    if (isExistMediaCaptureDir) {
        
        NSFileManager *fileManager = [NSFileManager defaultManager];
        NSString *documentsDirectory=[NSHomeDirectory() stringByAppendingPathComponent:@"Documents"];
        NSString *documentPath = [documentsDirectory stringByAppendingPathComponent:@"MediaCapture"];
        
        NSData* videoData=[NSData dataWithContentsOfURL:mediaURL];
        
        NSString* filePath;
        NSString *fileName = [self getCurrentDateString];
        NSError *err;
        int i = 1;
        do {
            //filePath = [NSString stringWithFormat:@"%@/capturedvideo_%03d.MOV", documentPath, i++];
            filePath = [NSString stringWithFormat:@"%@/%@.MOV", documentPath, fileName];
        } while ([fileManager fileExistsAtPath:filePath]);
        //
        //NSString * videoFile=[documentsDirectory stringByAppendingString:@"temp.mov"];
        
        success=[fileManager fileExistsAtPath:filePath];
        NSError *error;
        if(success) {
            success = [fileManager removeItemAtPath:filePath error:&error];
        }
        [videoData writeToFile:filePath atomically:YES];
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
        NSString *DocumentsDirectory = [paths objectAtIndex:0];
        
        //创建ALAssetsLibrary对象并将视频保存到媒体库
        ALAssetsLibrary* assetsLibrary = [[ALAssetsLibrary alloc] init];
        
        //textField1.text=[mediaURL absoluteString].lastPathComponent;
        //videoToEmbedFullPath=[mediaURL absoluteString];
        
        /*
         *  不保存到 photosAlbum  2015-01-08 11:06:54   by xyl======
         **/
//        [assetsLibrary writeVideoAtPathToSavedPhotosAlbum:mediaURL completionBlock:^(NSURL *assetURL, NSError *error) {
//            if (!error) {
//                NSLog(@"captured video saved with no error.");
//            }else
//            {
//                NSLog(@"error occured while saving the video:%@", error);
//            }
//        }];
        
        return filePath;
    }
    return @"";
}


/**
 * @brief
 @Expose
 */
- (NSString*)getCurrentDateString
{
    NSDate *date = [NSDate date];
    NSTimeZone *zone = [NSTimeZone systemTimeZone];
    NSInteger interval = [zone secondsFromGMTForDate: date];
    NSDate *localeDate = [date  dateByAddingTimeInterval: interval];
    NSLog(@"%@", localeDate);
    
    //实例化一个NSDateFormatter对象
    
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    //设定时间格式,这里可以设置成自己需要的格式
    [dateFormatter setDateFormat:@"yyyyMMddHHmmss"];
    //用[NSDate date]可以获取系统当前时间
    NSString *currentDateStr = [dateFormatter stringFromDate:date];
    return currentDateStr;
}


@end

@implementation CDVAudioNavigationController

#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 60000
- (NSUInteger)supportedInterfaceOrientations
{
    // delegate to CVDAudioRecorderViewController
    return [self.topViewController supportedInterfaceOrientations];
}
#endif

@end

@interface CDVAudioRecorderViewController () {
    UIStatusBarStyle _previousStatusBarStyle;
}
@end

@implementation CDVAudioRecorderViewController
@synthesize errorCode, callbackId, duration, captureCommand, doneButton, recordingView, recordButton, recordImage, stopRecordImage, timerLabel, avRecorder, avSession, pluginResult, timer, isTimed;

- (NSString*)resolveImageResource:(NSString*)resource
{
    NSString* systemVersion = [[UIDevice currentDevice] systemVersion];
    BOOL isLessThaniOS4 = ([systemVersion compare:@"4.0" options:NSNumericSearch] == NSOrderedAscending);
    
    // the iPad image (nor retina) differentiation code was not in 3.x, and we have to explicitly set the path
    // if user wants iPhone only app to run on iPad they must remove *~ipad.* images from CDVCapture.bundle
    if (isLessThaniOS4) {
        NSString* iPadResource = [NSString stringWithFormat:@"%@~ipad.png", resource];
        if (CDV_IsIPad() && [UIImage imageNamed:iPadResource]) {
            return iPadResource;
        } else {
            return [NSString stringWithFormat:@"%@.png", resource];
        }
    }
    
    return resource;
}

- (id)initWithCommand:(CDVCapture*)theCommand duration:(NSNumber*)theDuration callbackId:(NSString*)theCallbackId
{
    if ((self = [super init])) {
        self.captureCommand = theCommand;
        self.duration = theDuration;
        self.callbackId = theCallbackId;
        self.errorCode = CAPTURE_NO_MEDIA_FILES;
        self.isTimed = self.duration != nil;
        _previousStatusBarStyle = [UIApplication sharedApplication].statusBarStyle;
        
        return self;
    }
    
    return nil;
}

- (void)loadView
{
    if ([self respondsToSelector:@selector(edgesForExtendedLayout)]) {
        self.edgesForExtendedLayout = UIRectEdgeNone;
    }
    
    // create view and display
    CGRect viewRect = [[UIScreen mainScreen] applicationFrame];
    UIView* tmp = [[UIView alloc] initWithFrame:viewRect];
    
    // make backgrounds
    NSString* microphoneResource = @"CDVCapture.bundle/microphone";
    
    if (CDV_IsIPhone5()) {
        microphoneResource = @"CDVCapture.bundle/microphone-568h";
    }
    
    UIImage* microphone = [UIImage imageNamed:[self resolveImageResource:microphoneResource]];
    UIView* microphoneView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, viewRect.size.width, microphone.size.height)];
    [microphoneView setBackgroundColor:[UIColor colorWithPatternImage:microphone]];
    [microphoneView setUserInteractionEnabled:NO];
    [microphoneView setIsAccessibilityElement:NO];
    [tmp addSubview:microphoneView];
    
    // add bottom bar view
    UIImage* grayBkg = [UIImage imageNamed:[self resolveImageResource:@"CDVCapture.bundle/controls_bg"]];
    UIView* controls = [[UIView alloc] initWithFrame:CGRectMake(0, microphone.size.height, viewRect.size.width, grayBkg.size.height)];
    [controls setBackgroundColor:[UIColor colorWithPatternImage:grayBkg]];
    [controls setUserInteractionEnabled:NO];
    [controls setIsAccessibilityElement:NO];
    [tmp addSubview:controls];
    
    // make red recording background view
    UIImage* recordingBkg = [UIImage imageNamed:[self resolveImageResource:@"CDVCapture.bundle/recording_bg"]];
    UIColor* background = [UIColor colorWithPatternImage:recordingBkg];
    self.recordingView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, viewRect.size.width, recordingBkg.size.height)];
    [self.recordingView setBackgroundColor:background];
    [self.recordingView setHidden:YES];
    [self.recordingView setUserInteractionEnabled:NO];
    [self.recordingView setIsAccessibilityElement:NO];
    [tmp addSubview:self.recordingView];
    
    // add label
    self.timerLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, viewRect.size.width, recordingBkg.size.height)];
    // timerLabel.autoresizingMask = reSizeMask;
    [self.timerLabel setBackgroundColor:[UIColor clearColor]];
    [self.timerLabel setTextColor:[UIColor whiteColor]];
#ifdef __IPHONE_6_0
    [self.timerLabel setTextAlignment:NSTextAlignmentCenter];
#else
    // for iOS SDK < 6.0
    [self.timerLabel setTextAlignment:UITextAlignmentCenter];
#endif
    [self.timerLabel setText:@"0:00"];
    [self.timerLabel setAccessibilityHint:PluginLocalizedString(captureCommand, @"recorded time in minutes and seconds", nil)];
    self.timerLabel.accessibilityTraits |= UIAccessibilityTraitUpdatesFrequently;
    self.timerLabel.accessibilityTraits &= ~UIAccessibilityTraitStaticText;
    [tmp addSubview:self.timerLabel];
    
    // Add record button
    
    self.recordImage = [UIImage imageNamed:[self resolveImageResource:@"CDVCapture.bundle/record_button"]];
    self.stopRecordImage = [UIImage imageNamed:[self resolveImageResource:@"CDVCapture.bundle/stop_button"]];
    self.recordButton.accessibilityTraits |= [self accessibilityTraits];
    self.recordButton = [[UIButton alloc] initWithFrame:CGRectMake((viewRect.size.width - recordImage.size.width) / 2, (microphone.size.height + (grayBkg.size.height - recordImage.size.height) / 2), recordImage.size.width, recordImage.size.height)];
    [self.recordButton setAccessibilityLabel:PluginLocalizedString(captureCommand, @"toggle audio recording", nil)];
    [self.recordButton setImage:recordImage forState:UIControlStateNormal];
    [self.recordButton addTarget:self action:@selector(processButton:) forControlEvents:UIControlEventTouchUpInside];
    [tmp addSubview:recordButton];
    
    // make and add done button to navigation bar
    self.doneButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(dismissAudioView:)];
    [self.doneButton setStyle:UIBarButtonItemStyleDone];
    self.navigationItem.rightBarButtonItem = self.doneButton;
    
    [self setView:tmp];
}


/**
 * @brief
 @Expose
 */
- (NSString*)getCurrentDateString
{
    NSDate *date = [NSDate date];
    NSTimeZone *zone = [NSTimeZone systemTimeZone];
    NSInteger interval = [zone secondsFromGMTForDate: date];
    NSDate *localeDate = [date  dateByAddingTimeInterval: interval];
    NSLog(@"%@", localeDate);
    //实例化一个NSDateFormatter对象
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    //设定时间格式,这里可以设置成自己需要的格式
    [dateFormatter setDateFormat:@"yyyyMMddHHmmss"];
    //用[NSDate date]可以获取系统当前时间
    NSString *currentDateStr = [dateFormatter stringFromDate:date];
    return currentDateStr;
}


- (void)viewDidLoad
{
    [super viewDidLoad];
    UIAccessibilityPostNotification(UIAccessibilityScreenChangedNotification, nil);
    NSError* error = nil;
    
    if (self.avSession == nil) {
        // create audio session
        self.avSession = [AVAudioSession sharedInstance];
        if (error) {
            // return error if can't create recording audio session
            NSLog(@"error creating audio session: %@", [[error userInfo] description]);
            self.errorCode = CAPTURE_INTERNAL_ERR;
            [self dismissAudioView:nil];
        }
    }
    
    // create file to record to in temporary dir
    
    NSString* docsPath = [NSTemporaryDirectory()stringByStandardizingPath];   // use file system temporary directory
    NSError* err = nil;
    NSFileManager* fileMgr = [[NSFileManager alloc] init];
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];
    NSString *documentPath = [documentsDirectory stringByAppendingPathComponent:@"MediaCapture"];
    BOOL isDir = FALSE;
    BOOL isDirExist = [fileManager fileExistsAtPath:documentPath   isDirectory:&isDir];
    if(!(isDirExist && isDir))
    {
        BOOL bCreateDir = [fileManager createDirectoryAtPath:documentPath
                                 withIntermediateDirectories:YES
                                                  attributes:nil
                                                       error:nil];
        if(!bCreateDir){
            NSLog(@"Create Audio Directory Failed.");
        }
        NSLog(@"%@",documentPath);
    }
    
    // generate unique file name
    NSString* filePath;
    NSString *fileName = [self getCurrentDateString];
    //int i = 1;
    do {
        //filePath = [NSString stringWithFormat:@"%@/audio_%03d.wav", documentPath, i++];
        filePath = [NSString stringWithFormat:@"%@/%@.wav", documentPath, fileName];
        
    } while ([fileMgr fileExistsAtPath:filePath]);
    
    NSURL* fileURL = [NSURL fileURLWithPath:filePath isDirectory:NO];
    
    // create AVAudioPlayer
    self.avRecorder = [[AVAudioRecorder alloc] initWithURL:fileURL settings:nil error:&err];
    if (err) {
        NSLog(@"Failed to initialize AVAudioRecorder: %@\n", [err localizedDescription]);
        self.avRecorder = nil;
        // return error
        self.errorCode = CAPTURE_INTERNAL_ERR;
        [self dismissAudioView:nil];
    } else {
        self.avRecorder.delegate = self;
        [self.avRecorder prepareToRecord];
        self.recordButton.enabled = YES;
        self.doneButton.enabled = YES;
    }
}

#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 60000
- (NSUInteger)supportedInterfaceOrientations
{
    NSUInteger orientation = UIInterfaceOrientationMaskPortrait; // must support portrait
    NSUInteger supported = [captureCommand.viewController supportedInterfaceOrientations];
    
    orientation = orientation | (supported & UIInterfaceOrientationMaskPortraitUpsideDown);
    return orientation;
}
#endif

- (void)viewDidUnload
{
    [self setView:nil];
    [self.captureCommand setInUse:NO];
}

- (void)processButton:(id)sender
{
    if (self.avRecorder.recording) {
        // stop recording
        [self.avRecorder stop];
        self.isTimed = NO;  // recording was stopped via button so reset isTimed
        // view cleanup will occur in audioRecordingDidFinishRecording
    } else {
        // begin recording
        [self.recordButton setImage:stopRecordImage forState:UIControlStateNormal];
        self.recordButton.accessibilityTraits &= ~[self accessibilityTraits];
        [self.recordingView setHidden:NO];
        __block NSError* error = nil;
        
        void (^startRecording)(void) = ^{
            [self.avSession setCategory:AVAudioSessionCategoryRecord error:&error];
            [self.avSession setActive:YES error:&error];
            if (error) {
                // can't continue without active audio session
                self.errorCode = CAPTURE_INTERNAL_ERR;
                [self dismissAudioView:nil];
            } else {
                if (self.duration) {
                    self.isTimed = true;
                    [self.avRecorder recordForDuration:[duration doubleValue]];
                } else {
                    [self.avRecorder record];
                }
                [self.timerLabel setText:@"0.00"];
                self.timer = [NSTimer scheduledTimerWithTimeInterval:0.5f target:self selector:@selector(updateTime) userInfo:nil repeats:YES];
                self.doneButton.enabled = NO;
            }
            UIAccessibilityPostNotification(UIAccessibilityLayoutChangedNotification, nil);
        };
        
        SEL rrpSel = NSSelectorFromString(@"requestRecordPermission:");
        if ([self.avSession respondsToSelector:rrpSel])
        {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
            [self.avSession performSelector:rrpSel withObject:^(BOOL granted){
                if (granted) {
                    startRecording();
                } else {
                    NSLog(@"Error creating audio session, microphone permission denied.");
                    self.errorCode = CAPTURE_INTERNAL_ERR;
                    [self dismissAudioView:nil];
                }
            }];
#pragma clang diagnostic pop
        } else {
            startRecording();
        }
    }
}

/*
 * helper method to clean up when stop recording
 */
- (void)stopRecordingCleanup
{
    if (self.avRecorder.recording) {
        [self.avRecorder stop];
    }
    [self.recordButton setImage:recordImage forState:UIControlStateNormal];
    self.recordButton.accessibilityTraits |= [self accessibilityTraits];
    [self.recordingView setHidden:YES];
    self.doneButton.enabled = YES;
    if (self.avSession) {
        // deactivate session so sounds can come through
        [self.avSession setCategory:AVAudioSessionCategoryPlayAndRecord error:nil];
        [self.avSession setActive:NO error:nil];
    }
    if (self.duration && self.isTimed) {
        // VoiceOver announcement so user knows timed recording has finished
        BOOL isUIAccessibilityAnnouncementNotification = (&UIAccessibilityAnnouncementNotification != NULL);
        if (isUIAccessibilityAnnouncementNotification) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 500ull * NSEC_PER_MSEC), dispatch_get_main_queue(), ^{
                UIAccessibilityPostNotification(UIAccessibilityAnnouncementNotification, PluginLocalizedString(captureCommand, @"timed recording complete", nil));
            });
        }
    } else {
        // issue a layout notification change so that VO will reannounce the button label when recording completes
        UIAccessibilityPostNotification(UIAccessibilityLayoutChangedNotification, nil);
    }
}

- (void)dismissAudioView:(id)sender
{
    // called when done button pressed or when error condition to do cleanup and remove view
    [[self.captureCommand.viewController.presentedViewController presentingViewController] dismissViewControllerAnimated:YES completion:nil];
    
    if (!self.pluginResult) {
        // return error
        self.pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageToErrorObject:(int)self.errorCode];
    }
    
    self.avRecorder = nil;
    [self.avSession setCategory:AVAudioSessionCategoryPlayAndRecord error:nil];
    [self.avSession setActive:NO error:nil];
    [self.captureCommand setInUse:NO];
    UIAccessibilityPostNotification(UIAccessibilityScreenChangedNotification, nil);
    // return result
    [self.captureCommand.commandDelegate sendPluginResult:pluginResult callbackId:callbackId];
    
    if (IsAtLeastiOSVersion(@"7.0")) {
        [[UIApplication sharedApplication] setStatusBarStyle:_previousStatusBarStyle];
    }
}

- (void)updateTime
{
    // update the label with the elapsed time
    [self.timerLabel setText:[self formatTime:self.avRecorder.currentTime]];
}

- (NSString*)formatTime:(int)interval
{
    // is this format universal?
    int secs = interval % 60;
    int min = interval / 60;
    
    if (interval < 60) {
        return [NSString stringWithFormat:@"0:%02d", interval];
    } else {
        return [NSString stringWithFormat:@"%d:%02d", min, secs];
    }
}

- (void)audioRecorderDidFinishRecording:(AVAudioRecorder*)recorder successfully:(BOOL)flag
{
    // may be called when timed audio finishes - need to stop time and reset buttons
    [self.timer invalidate];
    [self stopRecordingCleanup];
    
    // generate success result
    if (flag) {
        NSString* filePath = [avRecorder.url path];
        // NSLog(@"filePath: %@", filePath);
        //NSDictionary* fileDict = [captureCommand getMediaDictionaryFromPath:filePath ofType:@"audio/wav"];
        NSDictionary* fileDict = [captureCommand getMediaDictionaryFromPath:filePath ofType:nil];
        NSArray* fileArray = [NSArray arrayWithObject:fileDict];
        
        self.pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsArray:fileArray];
    } else {
        self.pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_IO_EXCEPTION messageToErrorObject:CAPTURE_INTERNAL_ERR];
    }
}

- (void)audioRecorderEncodeErrorDidOccur:(AVAudioRecorder*)recorder error:(NSError*)error
{
    [self.timer invalidate];
    [self stopRecordingCleanup];
    
    NSLog(@"error recording audio");
    self.pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_IO_EXCEPTION messageToErrorObject:CAPTURE_INTERNAL_ERR];
    [self dismissAudioView:nil];
}

- (UIStatusBarStyle)preferredStatusBarStyle
{
    return UIStatusBarStyleDefault;
}

- (void)viewWillAppear:(BOOL)animated
{
    if (IsAtLeastiOSVersion(@"7.0")) {
        [[UIApplication sharedApplication] setStatusBarStyle:[self preferredStatusBarStyle]];
    }
    
    [super viewWillAppear:animated];
}

@end
