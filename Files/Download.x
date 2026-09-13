// Download.x — HPlus Download Module
// Merged: Direct + Server + SABR + FFmpeg + RangeDownloader
// Dependencies: Headers.h, SABRDownload.x

#import "Headers.h"
#import <AVFoundation/AVFoundation.h>
#import <Photos/Photos.h>
#import <math.h>
#import <objc/message.h>
#import <objc/runtime.h>
#import <dlfcn.h>
#import <stdarg.h>
#import <stdlib.h>

// =========================================================
// MARK: - Forward declarations (must be before use)
// =========================================================
static NSInteger HPlusResolutionFromQuality(NSString *quality);
static NSInteger HPlusFPSFromQuality(NSString *quality);
static NSInteger HPlusNormalizedFPS(NSInteger fps);
static NSInteger HPlusDisplayHeightForVideoHeight(NSInteger height);
static NSString *HPlusQualityLabel(NSInteger height, NSInteger fps, NSString *fallback);
static BOOL HPlusFFmpegKitAvailable(void);
static BOOL HPlusVideoFileCanSaveToPhotos(NSURL *fileURL);
static void HPlusShowTranslationDialog(NSString *text, UIViewController *presenter);
static void HPlusHandlePostDownloadImage(UIImage *image, UIViewController *presenter);
static void HPlusShareFile(NSURL *fileURL, UIViewController *presenter);
static void HPlusCopyDownloadDiagnostics(UIViewController *presenter);

// =========================================================
// MARK: - Global state
// =========================================================
static __weak YTPlayerViewController *HPlusCurrentPlayerViewController;
static NSString *HPlusLastDownloadDiagnostic;

// =========================================================
// MARK: - HPlusMenuItem
// =========================================================
@interface HPlusMenuItem : NSObject
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSString *subtitle;
@property (nonatomic, strong) UIImage *iconImage;
@property (nonatomic, copy) void (^handler)(void);
+ (instancetype)itemWithTitle:(NSString *)title subtitle:(NSString *)subtitle icon:(UIImage *)icon handler:(void (^)(void))handler;
@end

@implementation HPlusMenuItem
+ (instancetype)itemWithTitle:(NSString *)title subtitle:(NSString *)subtitle icon:(UIImage *)icon handler:(void (^)(void))handler {
    HPlusMenuItem *item = [HPlusMenuItem new];
    item.title = title;
    item.subtitle = subtitle;
    item.iconImage = icon;
    item.handler = handler;
    return item;
}
@end

// =========================================================
// MARK: - HPlusMediaFormat (extended with codec + audio info)
// =========================================================
@interface HPlusMediaFormat : NSObject
@property (nonatomic, strong) YTIFormatStream *source;
@property (nonatomic, copy) NSString *urlString;
@property (nonatomic, copy) NSString *qualityLabel;
@property (nonatomic, copy) NSString *mimeType;
@property (nonatomic, copy) NSString *idp;
@property (nonatomic, copy) NSString *codec;
@property (nonatomic, copy) NSString *languageCode;
@property (nonatomic, copy) NSString *languageName;
@property (nonatomic, copy) NSDictionary *httpHeaders;
@property (nonatomic, assign) NSInteger contentLength;
@property (nonatomic, assign) NSUInteger durationMs;
@property (nonatomic, assign) int fps;
@property (nonatomic, assign) int itag;
@property (nonatomic, assign) int resolution;
@property (nonatomic, assign) BOOL video;
@property (nonatomic, assign) BOOL drcAudio;
@end

@implementation HPlusMediaFormat
@end

// =========================================================
// MARK: - HPlusAudioOutputFormat (NEW: FFmpeg audio conversion)
// =========================================================
@interface HPlusAudioOutputFormat : NSObject
@property (nonatomic, copy) NSString *identifier;
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSString *subtitle;
@property (nonatomic, copy) NSString *fileExtension;
@property (nonatomic, copy) NSArray <NSString *> *ffmpegArguments;
@property (nonatomic, assign) BOOL passthroughWhenCompatible;
@property (nonatomic, assign) BOOL supported;
@end

@implementation HPlusAudioOutputFormat
@end

// =========================================================
// MARK: - Completion blocks
// =========================================================
typedef void (^HPlusFileDownloadCompletion)(NSURL *fileURL, NSError *error);
typedef void (^HPlusMergeCompletion)(BOOL success, NSError *error);
typedef void (^HPlusRangeDownloadProgress)(unsigned long long completedBytes);

// =========================================================
// MARK: - HPlusDownloadChunk
// =========================================================
@interface HPlusDownloadChunk : NSObject
@property (nonatomic, assign) unsigned long long offset;
@property (nonatomic, assign) unsigned long long length;
@property (nonatomic, assign) NSUInteger attempts;
@end

@implementation HPlusDownloadChunk
@end

// =========================================================
// MARK: - HPlusRangeDownloader (NEW: fast multi-chunk HTTP)
// =========================================================
@interface HPlusRangeDownloader : NSObject
@property (nonatomic, strong) NSURL *url;
@property (nonatomic, strong) NSURL *destinationURL;
@property (nonatomic, copy) NSDictionary *httpHeaders;
@property (nonatomic, assign) unsigned long long expectedBytes;
@property (nonatomic, copy) HPlusRangeDownloadProgress progress;
@property (nonatomic, copy) HPlusFileDownloadCompletion completion;
@property (nonatomic, strong) NSURLSession *session;
@property (nonatomic, strong) NSFileHandle *fileHandle;
@property (nonatomic, strong) NSMutableArray <HPlusDownloadChunk *> *pendingChunks;
@property (nonatomic, strong) NSMutableSet <NSURLSessionDataTask *> *tasks;
@property (nonatomic, strong) dispatch_queue_t stateQueue;
@property (nonatomic, strong) dispatch_queue_t fileQueue;
@property (nonatomic, assign) NSUInteger activeTaskCount;
@property (nonatomic, assign) NSUInteger totalChunkCount;
@property (nonatomic, assign) unsigned long long completedBytes;
@property (nonatomic, assign) BOOL cancelled;
@property (nonatomic, assign) BOOL finished;
- (instancetype)initWithURL:(NSURL *)url destinationURL:(NSURL *)destinationURL expectedBytes:(unsigned long long)expectedBytes headers:(NSDictionary *)headers progress:(HPlusRangeDownloadProgress)progress completion:(HPlusFileDownloadCompletion)completion;
- (void)start;
- (void)cancel;
@end

// =========================================================
// MARK: - HPlusDownloadCoordinator
// =========================================================
@interface HPlusDownloadCoordinator : NSObject <NSURLSessionDownloadDelegate>
@property (nonatomic, strong) NSURLSession *session;
@property (nonatomic, strong) NSURLSessionDownloadTask *task;
@property (nonatomic, strong) NSURLSessionDataTask *metadataTask;
@property (nonatomic, strong) HPlusRangeDownloader *rangeDownloader;
@property (nonatomic, strong) AVAssetExportSession *exporter;
@property (nonatomic, strong) YMDownloadProgressView *progressPill;
@property (nonatomic, weak) UIViewController *presenter;
@property (nonatomic, copy) HPlusFileDownloadCompletion fileCompletion;
@property (nonatomic, strong) NSURL *destinationURL;
@property (nonatomic, strong) NSURL *videoTempURL;
@property (nonatomic, strong) NSURL *audioTempURL;
@property (nonatomic, assign) unsigned long long completedBytes;
@property (nonatomic, assign) unsigned long long totalBytes;
@property (nonatomic, assign) unsigned long long currentBytes;
@property (nonatomic, assign) unsigned long long currentExpectedBytes;
@property (nonatomic, assign) BOOL currentResolvedSizeAddedToTotal;
@property (nonatomic, assign) BOOL active;
@property (nonatomic, assign) BOOL finishedCurrentFile;
@property (nonatomic, assign) BOOL cancelled;
@property (nonatomic, copy) NSString *baseProgressTitle;
@property (nonatomic, assign) NSTimeInterval downloadStartTime;
@property (nonatomic, copy) void (^downloadCompletionBlock)(NSURL *localURL, NSString *errorMsg);
+ (instancetype)sharedCoordinator;
- (void)startVideoDownloadWithVideoFormat:(HPlusMediaFormat *)videoFormat audioFormat:(HPlusMediaFormat *)audioFormat fileName:(NSString *)fileName presenter:(UIViewController *)presenter videoID:(NSString *)vidID;
- (void)startAudioDownloadWithAudioFormat:(HPlusMediaFormat *)audioFormat fileName:(NSString *)fileName presenter:(UIViewController *)presenter videoID:(NSString *)vidID;
- (void)startAudioDownloadWithAudioFormat:(HPlusMediaFormat *)audioFormat fileName:(NSString *)fileName presenter:(UIViewController *)presenter videoID:(NSString *)vidID outputFormat:(HPlusAudioOutputFormat *)outputFormat;
- (void)startDirectVideoDownloadWithVideoFormat:(HPlusMediaFormat *)videoFormat audioFormat:(HPlusMediaFormat *)audioFormat fileName:(NSString *)fileName presenter:(UIViewController *)presenter videoID:(NSString *)vidID;
- (void)startDirectAudioDownloadWithAudioFormat:(HPlusMediaFormat *)audioFormat fileName:(NSString *)fileName presenter:(UIViewController *)presenter videoID:(NSString *)vidID outputFormat:(HPlusAudioOutputFormat *)outputFormat;
- (void)trimAudioToHalfLengthAtURL:(NSURL *)inputURL toURL:(NSURL *)outputURL completion:(void (^)(NSError *error))completion;
- (void)mergeVideoURL:(NSURL *)videoURL audioURL:(NSURL *)audioURL fileName:(NSString *)fileName outputExtension:(NSString *)outputExtension durationMs:(unsigned long long)durationMs presenter:(UIViewController *)presenter;
- (void)mergeVideoWithAVFoundationVideoURL:(NSURL *)videoURL audioURL:(NSURL *)audioURL outputURL:(NSURL *)outputURL durationMs:(unsigned long long)durationMs presenter:(UIViewController *)presenter fallbackError:(NSError *)fallbackError;
@end

// =========================================================
// MARK: - Constants
// =========================================================
static const unsigned long long HPlusFastDownloadMinimumBytes = 256ULL * 1024ULL;
static const unsigned long long HPlusFastDownloadChunkBytes = 4ULL * 1024ULL * 1024ULL;
static const NSUInteger HPlusFastDownloadConcurrency = 8;
static const NSUInteger HPlusFastDownloadMaxAttempts = 3;

// =========================================================
// MARK: - HTTP header helpers
// =========================================================
static BOOL HPlusHTTPHeadersContainField(NSDictionary *headers, NSString *field) {
    for (id key in headers) {
        if ([key isKindOfClass:NSString.class] && [(NSString *)key caseInsensitiveCompare:field] == NSOrderedSame)
            return YES;
    }
    return NO;
}

static NSString *HPlusYouTubeCookiesString(void) {
    NSMutableArray *cookieStrings = [NSMutableArray array];
    for (NSHTTPCookie *cookie in [[NSHTTPCookieStorage sharedHTTPCookieStorage] cookies]) {
        if ([cookie.domain containsString:@"youtube.com"]) {
            [cookieStrings addObject:[NSString stringWithFormat:@"%@=%@", cookie.name, cookie.value]];
        }
    }
    return [cookieStrings componentsJoinedByString:@"; "];
}

static NSString *HPlusNativeUserAgent(void) {
    NSString *device = isPad() ? @"iPad" : @"iPhone";
    return [NSString stringWithFormat:@"com.google.ios.youtube/21.26.4 (%@; CPU OS 18_7 like Mac OS X)", device];
}

static void HPlusApplyDownloadHeaders(NSMutableURLRequest *request, NSDictionary *headers) {
    for (id key in headers) {
        id value = headers[key];
        if ([key isKindOfClass:NSString.class] && [value isKindOfClass:NSString.class])
            [request setValue:value forHTTPHeaderField:key];
    }
    if (!HPlusHTTPHeadersContainField(headers, @"User-Agent"))
        [request setValue:HPlusNativeUserAgent() forHTTPHeaderField:@"User-Agent"];
    if (!HPlusHTTPHeadersContainField(headers, @"Origin"))
        [request setValue:@"https://www.youtube.com" forHTTPHeaderField:@"Origin"];
    if (!HPlusHTTPHeadersContainField(headers, @"Referer"))
        [request setValue:@"https://www.youtube.com/" forHTTPHeaderField:@"Referer"];
    if (!HPlusHTTPHeadersContainField(headers, @"Cookie")) {
        NSString *cookies = HPlusYouTubeCookiesString();
        if (cookies.length > 0) [request setValue:cookies forHTTPHeaderField:@"Cookie"];
    }
    extern NSString *HPlusGlobalAuthHeader;
    if (HPlusGlobalAuthHeader && !HPlusHTTPHeadersContainField(headers, @"Authorization")) {
        [request setValue:HPlusGlobalAuthHeader forHTTPHeaderField:@"Authorization"];
    }
    [request setValue:@"identity" forHTTPHeaderField:@"Accept-Encoding"];
}

// =========================================================
// MARK: - HPlusRangeDownloader Implementation
// =========================================================
@implementation HPlusRangeDownloader

- (instancetype)initWithURL:(NSURL *)url destinationURL:(NSURL *)destinationURL expectedBytes:(unsigned long long)expectedBytes headers:(NSDictionary *)headers progress:(HPlusRangeDownloadProgress)progress completion:(HPlusFileDownloadCompletion)completion {
    self = [super init];
    if (self) {
        _url = url;
        _destinationURL = destinationURL;
        _httpHeaders = [headers copy];
        _expectedBytes = expectedBytes;
        _progress = [progress copy];
        _completion = [completion copy];
        _pendingChunks = [NSMutableArray array];
        _tasks = [NSMutableSet set];
        _stateQueue = dispatch_queue_create("com.youmod.download.range.state", DISPATCH_QUEUE_SERIAL);
        _fileQueue = dispatch_queue_create("com.youmod.download.range.file", DISPATCH_QUEUE_SERIAL);

        NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration defaultSessionConfiguration];
        configuration.HTTPMaximumConnectionsPerHost = HPlusFastDownloadConcurrency;
        configuration.requestCachePolicy = NSURLRequestReloadIgnoringLocalCacheData;
        configuration.timeoutIntervalForResource = 300;

        NSMutableDictionary *additionalHeaders = [NSMutableDictionary dictionary];
        for (id key in headers) {
            id value = headers[key];
            if ([key isKindOfClass:NSString.class] && [value isKindOfClass:NSString.class])
                additionalHeaders[key] = value;
        }
        if (!HPlusHTTPHeadersContainField(additionalHeaders, @"User-Agent"))
            additionalHeaders[@"User-Agent"] = HPlusNativeUserAgent();
        if (!HPlusHTTPHeadersContainField(additionalHeaders, @"Origin"))
            additionalHeaders[@"Origin"] = @"https://www.youtube.com";
        if (!HPlusHTTPHeadersContainField(additionalHeaders, @"Referer"))
            additionalHeaders[@"Referer"] = @"https://www.youtube.com/";
        if (!HPlusHTTPHeadersContainField(additionalHeaders, @"Cookie")) {
            NSString *cookies = HPlusYouTubeCookiesString();
            if (cookies.length > 0) additionalHeaders[@"Cookie"] = cookies;
        }
        extern NSString *HPlusGlobalAuthHeader;
        if (HPlusGlobalAuthHeader && !HPlusHTTPHeadersContainField(additionalHeaders, @"Authorization")) {
            additionalHeaders[@"Authorization"] = HPlusGlobalAuthHeader;
        }
        additionalHeaders[@"Accept-Encoding"] = @"identity";
        configuration.HTTPAdditionalHeaders = additionalHeaders;
        _session = [NSURLSession sessionWithConfiguration:configuration];
    }
    return self;
}

- (NSError *)errorWithCode:(NSInteger)code message:(NSString *)message {
    return [NSError errorWithDomain:@"HPlus" code:code userInfo:@{NSLocalizedDescriptionKey: message ?: @"Download failed"}];
}

- (BOOL)prepareDestinationWithError:(NSError **)error {
    [NSFileManager.defaultManager removeItemAtURL:self.destinationURL error:nil];
    if (![NSFileManager.defaultManager createFileAtPath:self.destinationURL.path contents:nil attributes:nil]) {
        if (error) *error = [self errorWithCode:20 message:@"Cannot create file"];
        return NO;
    }

    self.fileHandle = [NSFileHandle fileHandleForWritingAtPath:self.destinationURL.path];
    if (!self.fileHandle) {
        if (error) *error = [self errorWithCode:21 message:@"Cannot open file"];
        return NO;
    }

    @try {
        [self.fileHandle truncateFileAtOffset:self.expectedBytes];
    } @catch (NSException *exception) {
        if (error) *error = [self errorWithCode:22 message:exception.reason ?: @"Cannot allocate file"];
        return NO;
    }
    return YES;
}

- (void)start {
    dispatch_async(self.stateQueue, ^{
        if (self.expectedBytes == 0) {
            [self finishWithErrorLocked:[self errorWithCode:23 message:@"Unknown stream size"]];
            return;
        }

        NSError *error = nil;
        if (![self prepareDestinationWithError:&error]) {
            [self finishWithErrorLocked:error];
            return;
        }

        unsigned long long chunkSize = self.expectedBytes / 100ULL;
        if (chunkSize < 256ULL * 1024ULL) chunkSize = 256ULL * 1024ULL;
        if (chunkSize > HPlusFastDownloadChunkBytes) chunkSize = HPlusFastDownloadChunkBytes;

        for (unsigned long long offset = 0; offset < self.expectedBytes; offset += chunkSize) {
            HPlusDownloadChunk *chunk = [HPlusDownloadChunk new];
            chunk.offset = offset;
            unsigned long long remaining = self.expectedBytes - offset;
            chunk.length = remaining < chunkSize ? remaining : chunkSize;
            [self.pendingChunks addObject:chunk];
        }
        self.totalChunkCount = self.pendingChunks.count;
        [self scheduleChunksLocked];
    });
}

- (void)cancel {
    dispatch_async(self.stateQueue, ^{
        if (self.finished) return;
        self.cancelled = YES;
        self.finished = YES;
        for (NSURLSessionDataTask *task in self.tasks) [task cancel];
        [self.tasks removeAllObjects];
        [self.session invalidateAndCancel];
        dispatch_async(self.fileQueue, ^{
            @try { [self.fileHandle closeFile]; } @catch (__unused NSException *e) {}
            [NSFileManager.defaultManager removeItemAtURL:self.destinationURL error:nil];
        });
    });
}

- (void)scheduleChunksLocked {
    if (self.finished || self.cancelled) return;
    while (self.activeTaskCount < HPlusFastDownloadConcurrency && self.pendingChunks.count > 0) {
        HPlusDownloadChunk *chunk = self.pendingChunks.firstObject;
        [self.pendingChunks removeObjectAtIndex:0];
        [self startChunkLocked:chunk];
    }
    if (self.activeTaskCount == 0 && self.pendingChunks.count == 0) {
        [self finishSuccessfullyLocked];
    }
}

- (void)startChunkLocked:(HPlusDownloadChunk *)chunk {
    unsigned long long end = chunk.offset + chunk.length - 1;
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:self.url cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:60.0];
    HPlusApplyDownloadHeaders(request, self.httpHeaders);
    [request setValue:[NSString stringWithFormat:@"bytes=%llu-%llu", chunk.offset, end] forHTTPHeaderField:@"Range"];

    __weak typeof(self) weakSelf = self;
    __block NSURLSessionDataTask *task = nil;
    task = [self.session dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        [self completeChunk:chunk task:task data:data response:response error:error];
    }];
    [self.tasks addObject:task];
    self.activeTaskCount++;
    [task resume];
}

- (NSError *)validationErrorForChunk:(HPlusDownloadChunk *)chunk data:(NSData *)data response:(NSURLResponse *)response error:(NSError *)error {
    if (error) return error;
    NSHTTPURLResponse *httpResponse = [response isKindOfClass:NSHTTPURLResponse.class] ? (NSHTTPURLResponse *)response : nil;
    NSInteger statusCode = httpResponse.statusCode;
    BOOL statusOK = statusCode == 206 || (self.totalChunkCount == 1 && statusCode == 200);
    if (httpResponse && !statusOK)
        return [self errorWithCode:24 message:@"Range request rejected"];
    if (data.length != chunk.length)
        return [self errorWithCode:25 message:@"Incomplete chunk"];
    return nil;
}

- (void)completeChunk:(HPlusDownloadChunk *)chunk task:(NSURLSessionDataTask *)task data:(NSData *)data response:(NSURLResponse *)response error:(NSError *)error {
    dispatch_async(self.stateQueue, ^{
        if (self.activeTaskCount > 0) self.activeTaskCount--;
        if (task) [self.tasks removeObject:task];
        if (self.finished || self.cancelled) return;

        NSError *validationError = [self validationErrorForChunk:chunk data:data response:response error:error];
        if (validationError) {
            if (validationError.code == 24) { [self finishWithErrorLocked:validationError]; return; }
            if (chunk.attempts + 1 < HPlusFastDownloadMaxAttempts) {
                chunk.attempts++;
                [self.pendingChunks insertObject:chunk atIndex:0];
                [self scheduleChunksLocked];
            } else { [self finishWithErrorLocked:validationError]; }
            return;
        }

        NSData *chunkData = [data copy];
        dispatch_async(self.fileQueue, ^{
            NSError *writeError = nil;
            @try {
                [self.fileHandle seekToFileOffset:chunk.offset];
                [self.fileHandle writeData:chunkData];
            } @catch (NSException *exception) {
                writeError = [self errorWithCode:26 message:exception.reason ?: @"Write failed"];
            }
            dispatch_async(self.stateQueue, ^{
                if (self.finished || self.cancelled) return;
                if (writeError) { [self finishWithErrorLocked:writeError]; return; }
                self.completedBytes += chunkData.length;
                if (self.progress) {
                    unsigned long long completed = self.completedBytes;
                    dispatch_async(dispatch_get_main_queue(), ^{ self.progress(completed); });
                }
                [self scheduleChunksLocked];
            });
        });
    });
}

- (void)finishSuccessfullyLocked {
    if (self.finished) return;
    self.finished = YES;
    [self.session finishTasksAndInvalidate];
    dispatch_async(self.fileQueue, ^{
        @try { [self.fileHandle closeFile]; } @catch (__unused NSException *e) {}
        dispatch_async(dispatch_get_main_queue(), ^{
            if (self.completion) self.completion(self.destinationURL, nil);
        });
    });
}

- (void)finishWithErrorLocked:(NSError *)error {
    if (self.finished) return;
    self.finished = YES;
    for (NSURLSessionDataTask *task in self.tasks) [task cancel];
    [self.tasks removeAllObjects];
    [self.session invalidateAndCancel];
    dispatch_async(self.fileQueue, ^{
        @try { [self.fileHandle closeFile]; } @catch (__unused NSException *e) {}
        [NSFileManager.defaultManager removeItemAtURL:self.destinationURL error:nil];
        dispatch_async(dispatch_get_main_queue(), ^{
            if (self.completion) self.completion(nil, error ?: [self errorWithCode:27 message:@"Download failed"]);
        });
    });
}

@end

// =========================================================
// MARK: - Current player tracking
// =========================================================
void HPlusDownloadSetCurrentPlayer(YTPlayerViewController *player) {
    HPlusCurrentPlayerViewController = player;
}

YTPlayerViewController *HPlusDownloadGetCurrentPlayer(void) {
    return HPlusCurrentPlayerViewController;
}

// =========================================================
// MARK: - Safe KVC helpers
// =========================================================
static id HPlusObjectFromSelector(id object, SEL selector) {
    if (!object) return nil;
    if ([object respondsToSelector:selector]) {
        return ((id (*)(id, SEL))objc_msgSend)(object, selector);
    }
    @try {
        return [object valueForKey:NSStringFromSelector(selector)];
    } @catch (__unused NSException *exception) {
        return nil;
    }
}

static NSString *HPlusStringFromSelector(id object, SEL selector) {
    if (!object) return nil;
    id value = HPlusObjectFromSelector(object, selector);
    if ([value isKindOfClass:NSString.class]) return value;
    if ([value isKindOfClass:NSURL.class]) return [(NSURL *)value absoluteString];
    if ([value respondsToSelector:@selector(stringValue)]) return [value stringValue];
    return [value respondsToSelector:@selector(description)] ? [value description] : nil;
}

static unsigned long long HPlusUnsignedLongLongFromSelector(id object, SEL selector) {
    if (!object) return 0;
    if ([object respondsToSelector:selector]) {
        return ((unsigned long long (*)(id, SEL))objc_msgSend)(object, selector);
    }
    @try {
        id value = [object valueForKey:NSStringFromSelector(selector)];
        if ([value respondsToSelector:@selector(unsignedLongLongValue)])
            return [value unsignedLongLongValue];
    } @catch (__unused NSException *exception) {}
    return 0;
}

static BOOL HPlusBoolFromSelector(id object, SEL selector) {
    if (!object) return NO;
    if ([object respondsToSelector:selector]) {
        return ((BOOL (*)(id, SEL))objc_msgSend)(object, selector);
    }
    @try {
        id value = [object valueForKey:NSStringFromSelector(selector)];
        if ([value respondsToSelector:@selector(boolValue)])
            return [value boolValue];
    } @catch (__unused NSException *exception) {}
    return NO;
}

static NSInteger HPlusIntegerFromSelector(id object, SEL selector) {
    if (!object) return 0;
    if ([object respondsToSelector:selector]) {
        return ((NSInteger (*)(id, SEL))objc_msgSend)(object, selector);
    }
    @try {
        id value = [object valueForKey:NSStringFromSelector(selector)];
        if ([value respondsToSelector:@selector(integerValue)])
            return [value integerValue];
    } @catch (__unused NSException *exception) {}
    return 0;
}

// =========================================================
// MARK: - Notification helpers (uses SBSkipNotificationView)
// =========================================================
static void HPlusSendToast(NSString *message) {
    UIView *parent = sbGetNotificationParent();
    [SBSkipNotificationView showInView:parent message:message buttonTitle:nil action:nil duration:3.0];
}

static void HPlusSendSuccess(NSString *message) {
    UIView *parent = sbGetNotificationParent();
    [SBSkipNotificationView showSuccessInView:parent message:message duration:3.0];
}

static void HPlusSendError(NSString *message) {
    UIView *parent = sbGetNotificationParent();
    [SBSkipNotificationView showErrorInView:parent message:message duration:4.0];
}

// =========================================================
// MARK: - Byte count / URL helpers
// =========================================================
static NSString *HPlusByteCount(unsigned long long bytes) {
    if (bytes == 0) return nil;
    NSByteCountFormatter *formatter = [NSByteCountFormatter new];
    formatter.countStyle = NSByteCountFormatterCountStyleFile;
    return [formatter stringFromByteCount:(long long)bytes];
}

static NSString *HPlusGenerateCPN(void) {
    static NSString *const alphabet = @"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_";
    NSMutableString *nonce = [NSMutableString stringWithCapacity:16];
    for (NSUInteger i = 0; i < 16; i++)
        [nonce appendFormat:@"%C", [alphabet characterAtIndex:arc4random_uniform((uint32_t)alphabet.length)]];
    return nonce;
}

static NSString *HPlusURLStringBypassingThrottle(NSString *urlString) {
    if (urlString.length == 0) return urlString;
    NSURLComponents *components = [NSURLComponents componentsWithString:urlString];
    if (components) {
        NSMutableArray *queryItems = [components.queryItems mutableCopy] ?: [NSMutableArray array];
        NSMutableArray *filtered = [NSMutableArray array];
        for (NSURLQueryItem *item in queryItems) {
            if (![item.name isEqualToString:@"n"])
                [filtered addObject:item];
        }
        BOOL hasRateBypass = NO;
        for (NSURLQueryItem *item in filtered) {
            if ([item.name isEqualToString:@"ratebypass"]) { hasRateBypass = YES; break; }
        }
        if (!hasRateBypass)
            [filtered addObject:[NSURLQueryItem queryItemWithName:@"ratebypass" value:@"yes"]];
        components.queryItems = filtered;
        NSString *result = components.string;
        if (result.length > 0) return result;
    }
    return urlString;
}

static NSString *HPlusURLStringWithCPN(NSString *urlString) {
    if (urlString.length == 0) return urlString;
    urlString = HPlusURLStringBypassingThrottle(urlString);
    if ([urlString containsString:@"cpn="]) return urlString;
    Class ytDataUtils = NSClassFromString(@"YTDataUtils");
    NSString *cpn = nil;
    if (ytDataUtils && [ytDataUtils respondsToSelector:@selector(generateClientSideNonce)])
        cpn = ((id (*)(Class, SEL))objc_msgSend)(ytDataUtils, @selector(generateClientSideNonce));
    if (![cpn isKindOfClass:NSString.class] || cpn.length == 0)
        cpn = HPlusGenerateCPN();
    NSString *separator = [urlString containsString:@"?"] ? @"&" : @"?";
    return [NSString stringWithFormat:@"%@%@cpn=%@", urlString, separator, cpn];
}

// =========================================================
// MARK: - File path helpers
// =========================================================
static NSString *HPlusSanitizedFileName(NSString *name) {
    if (name.length == 0) return @"YouTube Video";
    NSMutableCharacterSet *invalid = [NSMutableCharacterSet characterSetWithCharactersInString:@"/\\?%*|\"<>:"];
    [invalid formUnionWithCharacterSet:NSCharacterSet.newlineCharacterSet];
    NSArray *parts = [name componentsSeparatedByCharactersInSet:invalid];
    NSString *clean = [[parts componentsJoinedByString:@" "] stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    while ([clean containsString:@"  "]) clean = [clean stringByReplacingOccurrencesOfString:@"  " withString:@" "];
    if (clean.length > 120) clean = [clean substringToIndex:120];
    return clean.length ? clean : @"YouTube Video";
}

static NSURL *HPlusDownloadsDirectoryURL(void) {
    NSURL *documentsURL = [NSFileManager.defaultManager URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask].firstObject;
    NSURL *downloadsURL = [documentsURL URLByAppendingPathComponent:@"HPlus_Downloads" isDirectory:YES];
    [NSFileManager.defaultManager createDirectoryAtURL:downloadsURL withIntermediateDirectories:YES attributes:nil error:nil];
    return downloadsURL;
}

static NSURL *HPlusUniqueFileURL(NSString *fileName, NSString *extension) {
    NSString *safeName = HPlusSanitizedFileName(fileName);
    NSURL *directoryURL = HPlusDownloadsDirectoryURL();
    NSURL *candidate = [directoryURL URLByAppendingPathComponent:[safeName stringByAppendingPathExtension:extension]];
    NSUInteger index = 2;
    while ([NSFileManager.defaultManager fileExistsAtPath:candidate.path]) {
        NSString *indexed = [NSString stringWithFormat:@"%@ %lu", safeName, (unsigned long)index++];
        candidate = [directoryURL URLByAppendingPathComponent:[indexed stringByAppendingPathExtension:extension]];
    }
    return candidate;
}

static NSURL *HPlusTemporaryFileURL(NSString *extension) {
    NSString *name = [[NSUUID UUID].UUIDString stringByAppendingPathExtension:extension];
    return [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:name]];
}

// =========================================================
// MARK: - Download diagnostics
// =========================================================
static NSURL *HPlusDiagnosticLogURL(void) {
    return [HPlusDownloadsDirectoryURL() URLByAppendingPathComponent:@"youmod-download-diagnostics.txt"];
}

static void HPlusRecordDownloadDiagnostic(NSString *context, NSString *details) {
    if (context.length == 0 && details.length == 0) return;

    NSDateFormatter *formatter = [NSDateFormatter new];
    formatter.locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
    formatter.dateFormat = @"yyyy-MM-dd HH:mm:ss ZZZZZ";
    NSString *timestamp = [formatter stringFromDate:NSDate.date];
    NSString *entry = [NSString stringWithFormat:@"[%@]\n%@\n%@\n\n", timestamp ?: @"", context ?: @"", details ?: @""];
    HPlusLastDownloadDiagnostic = entry;

    NSURL *logURL = HPlusDiagnosticLogURL();
    NSData *data = [entry dataUsingEncoding:NSUTF8StringEncoding];
    if (![NSFileManager.defaultManager fileExistsAtPath:logURL.path])
        [NSFileManager.defaultManager createFileAtPath:logURL.path contents:nil attributes:nil];

    NSFileHandle *handle = [NSFileHandle fileHandleForWritingAtPath:logURL.path];
    if (!handle) return;
    @try {
        [handle seekToEndOfFile];
        [handle writeData:data];
        [handle closeFile];
    } @catch (__unused NSException *exception) {}
}

static NSString *HPlusDownloadDiagnosticText(void) {
    if (HPlusLastDownloadDiagnostic.length) return HPlusLastDownloadDiagnostic;
    NSString *log = [NSString stringWithContentsOfURL:HPlusDiagnosticLogURL() encoding:NSUTF8StringEncoding error:nil];
    if (log.length == 0) return nil;
    NSUInteger maxLength = 12000;
    return log.length > maxLength ? [log substringFromIndex:log.length - maxLength] : log;
}

static void HPlusCopyDownloadDiagnostics(UIViewController *presenter) {
    NSString *diagnostic = HPlusDownloadDiagnosticText();
    if (diagnostic.length == 0) {
        HPlusSendToast(@"No download diagnostics yet.");
        return;
    }
    UIPasteboard.generalPasteboard.string = diagnostic;
    HPlusSendSuccess(@"Copied download diagnostics");
}

// =========================================================
// MARK: - AVFoundation duration helpers
// =========================================================
static unsigned long long HPlusDurationMsForURL(NSURL *url) {
    AVURLAsset *asset = [AVURLAsset URLAssetWithURL:url options:nil];
    if (!CMTIME_IS_NUMERIC(asset.duration) || !CMTIME_IS_VALID(asset.duration)) return 0;
    Float64 seconds = CMTimeGetSeconds(asset.duration);
    if (!isfinite(seconds) || seconds <= 0.0) return 0;
    return (unsigned long long)llround(seconds * 1000.0);
}

static BOOL HPlusCMTimeIsUsable(CMTime time) {
    if (!CMTIME_IS_VALID(time) || !CMTIME_IS_NUMERIC(time) || CMTIME_IS_INDEFINITE(time)) return NO;
    Float64 seconds = CMTimeGetSeconds(time);
    return isfinite(seconds) && seconds > 0.0;
}

static CMTime HPlusMinUsableDuration(CMTime first, CMTime second) {
    BOOL firstOK = HPlusCMTimeIsUsable(first);
    BOOL secondOK = HPlusCMTimeIsUsable(second);
    if (firstOK && secondOK) return CMTIME_COMPARE_INLINE(first, <, second) ? first : second;
    if (firstOK) return first;
    if (secondOK) return second;
    return kCMTimeInvalid;
}

static CMTime HPlusExportDuration(AVAsset *videoAsset, AVAsset *audioAsset, unsigned long long expectedDurationMs) {
    CMTime duration = kCMTimeInvalid;
    if (expectedDurationMs > 0)
        duration = CMTimeMakeWithSeconds((double)expectedDurationMs / 1000.0, 600);

    CMTime videoDuration = HPlusMinUsableDuration(videoAsset.duration, [[videoAsset tracksWithMediaType:AVMediaTypeVideo] firstObject].timeRange.duration);
    CMTime audioDuration = audioAsset ? HPlusMinUsableDuration(audioAsset.duration, [[audioAsset tracksWithMediaType:AVMediaTypeAudio] firstObject].timeRange.duration) : kCMTimeInvalid;
    CMTime mediaDuration = audioAsset ? HPlusMinUsableDuration(videoDuration, audioDuration) : videoDuration;

    if (!HPlusCMTimeIsUsable(duration)) return mediaDuration;
    if (HPlusCMTimeIsUsable(mediaDuration) && CMTIME_COMPARE_INLINE(duration, >, mediaDuration))
        return mediaDuration;
    return duration;
}

// =========================================================
// MARK: - FFmpegKit loader
// =========================================================
static NSMutableArray <NSString *> *HPlusFFmpegKitLoadEntries(void) {
    static NSMutableArray <NSString *> *entries = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ entries = [NSMutableArray array]; });
    return entries;
}

static void HPlusAppendFFmpegKitLoadEntry(NSString *format, ...) {
    if (format.length == 0) return;
    va_list arguments;
    va_start(arguments, format);
    NSString *entry = [[NSString alloc] initWithFormat:format arguments:arguments];
    va_end(arguments);
    if (entry.length == 0) return;
    NSMutableArray <NSString *> *entries = HPlusFFmpegKitLoadEntries();
    @synchronized(entries) {
        [entries addObject:entry];
        if (entries.count > 220)
            [entries removeObjectsInRange:NSMakeRange(0, entries.count - 220)];
    }
}

static NSArray <NSString *> *HPlusFFmpegKitSearchDirectories(void) {
    NSMutableOrderedSet <NSString *> *directories = [NSMutableOrderedSet orderedSet];
    NSString *bundlePath = [[NSBundle.mainBundle resourcePath] stringByAppendingPathComponent:@"HPlus.bundle"];
    NSString *frameworksInsideBundle = [bundlePath stringByAppendingPathComponent:@"Frameworks"];
    BOOL isDir = NO;
    if ([[NSFileManager defaultManager] fileExistsAtPath:frameworksInsideBundle isDirectory:&isDir] && isDir) {
        [directories addObject:frameworksInsideBundle];
    }
    return directories.array;
}

static void HPlusDlopenPath(NSString *path, BOOL requireExistingFile) {
    if (path.length == 0) return;
    if (requireExistingFile && ![NSFileManager.defaultManager fileExistsAtPath:path]) {
        HPlusAppendFFmpegKitLoadEntry(@"missing %@", path);
        return;
    }
    dlerror();
    void *handle = dlopen(path.fileSystemRepresentation, RTLD_NOW | RTLD_GLOBAL);
    const char *error = dlerror();
    if (handle) {
        HPlusAppendFFmpegKitLoadEntry(@"loaded %@", path);
    } else {
        HPlusAppendFFmpegKitLoadEntry(@"failed %@\n  dlerror=%@", path, error ? [NSString stringWithUTF8String:error] : @"unknown");
    }
}

static void HPlusLoadFrameworkBinary(NSString *directory, NSString *frameworkName, NSString *binaryName) {
    if (directory.length == 0 || frameworkName.length == 0 || binaryName.length == 0) return;
    HPlusDlopenPath([[directory stringByAppendingPathComponent:[frameworkName stringByAppendingString:@".framework"]] stringByAppendingPathComponent:binaryName], YES);
    HPlusDlopenPath([[directory stringByAppendingPathComponent:[frameworkName stringByAppendingString:@".framework"]] stringByAppendingPathComponent:frameworkName], YES);
}

static void HPlusLoadFFmpegKitIfNeeded(void) {
    static BOOL attempted = NO;
    if (NSClassFromString(@"FFmpegKit")) return;
    if (attempted) return;
    attempted = YES;

    HPlusAppendFFmpegKitLoadEntry(@"[HPlus] Starting bundled FFmpegKit load...");
    NSArray <NSArray <NSString *> *> *frameworks = @[
        @[@"libavutil", @"libavutil"],
        @[@"libswresample", @"libswresample"],
        @[@"libswscale", @"libswscale"],
        @[@"libavcodec", @"libavcodec"],
        @[@"libavformat", @"libavformat"],
        @[@"libavfilter", @"libavfilter"],
        @[@"libavdevice", @"libavdevice"],
        @[@"ffmpegkit", @"ffmpegkit"],
        @[@"FFmpegKit", @"FFmpegKit"],
    ];
    NSArray *searchDirs = HPlusFFmpegKitSearchDirectories();
    if (searchDirs.count == 0) {
        HPlusAppendFFmpegKitLoadEntry(@"[HPlus] Error: Bundled Frameworks directory not found.");
        return;
    }
    for (NSString *directory in searchDirs) {
        for (NSArray <NSString *> *framework in frameworks) {
            HPlusLoadFrameworkBinary(directory, framework.firstObject, framework.lastObject);
        }
        if (NSClassFromString(@"FFmpegKit")) {
            HPlusAppendFFmpegKitLoadEntry(@"[HPlus] Success: FFmpegKit loaded from bundle.");
            return;
        }
    }
    HPlusAppendFFmpegKitLoadEntry(@"[HPlus] Critical: FFmpegKit could not be found in HPlus.bundle.");
}

static Class HPlusFFmpegKitClass(void) {
    Class ffmpegKitClass = NSClassFromString(@"FFmpegKit");
    if (!ffmpegKitClass) {
        HPlusLoadFFmpegKitIfNeeded();
        ffmpegKitClass = NSClassFromString(@"FFmpegKit");
    }
    return ffmpegKitClass;
}

static BOOL HPlusFFmpegKitAvailable(void) {
    Class ffmpegKitClass = HPlusFFmpegKitClass();
    return ffmpegKitClass && [ffmpegKitClass respondsToSelector:@selector(executeWithArgumentsAsync:withCompleteCallback:withLogCallback:withStatisticsCallback:)];
}

static NSString *HPlusFFmpegKitDiagnosticText(HPlusAudioOutputFormat *outputFormat, HPlusMediaFormat *sourceFormat, NSString *videoID) {
    HPlusLoadFFmpegKitIfNeeded();
    Class ffmpegKitClass = NSClassFromString(@"FFmpegKit");
    SEL executeSelector = @selector(executeWithArgumentsAsync:withCompleteCallback:withLogCallback:withStatisticsCallback:);
    NSMutableArray <NSString *> *lines = [NSMutableArray array];
    NSBundle *mainBundle = NSBundle.mainBundle;
    NSString *resourcePath = mainBundle.resourcePath ?: @"";
    NSString *bundlePath = [resourcePath stringByAppendingPathComponent:@"HPlus.bundle"];
    NSString *packageFrameworkPath = [resourcePath stringByAppendingPathComponent:@"HPlus.bundle/Frameworks"];

    [lines addObject:@"FFmpegKit lookup"];
    [lines addObject:[NSString stringWithFormat:@"videoID=%@", videoID ?: @""]];
    [lines addObject:[NSString stringWithFormat:@"requestedFormat=%@ (%@)", outputFormat.title ?: @"", outputFormat.identifier ?: @""]];
    [lines addObject:[NSString stringWithFormat:@"sourceMime=%@", sourceFormat.mimeType ?: @""]];
    [lines addObject:[NSString stringWithFormat:@"sourceQuality=%@", sourceFormat.qualityLabel ?: @""]];
    [lines addObject:[NSString stringWithFormat:@"sourceBytes=%lld", (long long)sourceFormat.contentLength]];
    [lines addObject:[NSString stringWithFormat:@"HPlus.bundle exists=%@", [NSFileManager.defaultManager fileExistsAtPath:bundlePath] ? @"YES" : @"NO"]];
    [lines addObject:[NSString stringWithFormat:@"HPlus.bundle/Frameworks exists=%@", [NSFileManager.defaultManager fileExistsAtPath:packageFrameworkPath] ? @"YES" : @"NO"]];
    [lines addObject:[NSString stringWithFormat:@"FFmpegKit class=%@", ffmpegKitClass ? @"YES" : @"NO"]];
    [lines addObject:[NSString stringWithFormat:@"FFmpegKit execute selector=%@", [ffmpegKitClass respondsToSelector:executeSelector] ? @"YES" : @"NO"]];
    [lines addObject:[NSString stringWithFormat:@"ReturnCode class=%@", NSClassFromString(@"ReturnCode") ? @"YES" : @"NO"]];
    [lines addObject:@"searchDirectories:"];
    for (NSString *directory in HPlusFFmpegKitSearchDirectories()) {
        BOOL isDirectory = NO;
        BOOL exists = [NSFileManager.defaultManager fileExistsAtPath:directory isDirectory:&isDirectory];
        [lines addObject:[NSString stringWithFormat:@"  %@ exists=%@ directory=%@", directory, exists ? @"YES" : @"NO", isDirectory ? @"YES" : @"NO"]];
    }
    NSMutableArray <NSString *> *entries = HPlusFFmpegKitLoadEntries();
    [lines addObject:@"dlopenAttempts:"];
    @synchronized(entries) { [lines addObjectsFromArray:entries]; }
    return [lines componentsJoinedByString:@"\n"];
}

static void HPlusCancelFFmpegKit(void) {
    Class ffmpegKitClass = HPlusFFmpegKitClass();
    if ([ffmpegKitClass respondsToSelector:@selector(cancel)])
        ((void (*)(Class, SEL))objc_msgSend)(ffmpegKitClass, @selector(cancel));
}

static NSError *HPlusFFmpegErrorFromSession(id session) {
    NSString *failure = HPlusStringFromSelector(session, @selector(getFailStackTrace));
    NSString *message = failure.length ? failure : @"FFmpeg failed";
    return [NSError errorWithDomain:@"HPlus" code:7 userInfo:@{NSLocalizedDescriptionKey: message}];
}

static BOOL HPlusPathExtensionIsPhotosVideo(NSString *extension) {
    NSString *lower = extension.lowercaseString ?: @"";
    return [@[@"mp4", @"m4v", @"mov"] containsObject:lower];
}

// =========================================================
// MARK: - FFmpegKit Merge + Audio Convert
// =========================================================
static BOOL HPlusStartFFmpegKitMerge(NSURL *videoURL, NSURL *audioURL, NSURL *outputURL, unsigned long long durationMs, void (^progress)(float progress), HPlusMergeCompletion completion) {
    Class ffmpegKitClass = HPlusFFmpegKitClass();
    SEL executeSelector = @selector(executeWithArgumentsAsync:withCompleteCallback:withLogCallback:withStatisticsCallback:);
    if (![ffmpegKitClass respondsToSelector:executeSelector]) return NO;

    NSMutableArray *arguments = [@[
        @"-y", @"-i", videoURL.path, @"-i", audioURL.path,
        @"-map", @"0:v:0", @"-map", @"1:a:0",
    ] mutableCopy];
    if (durationMs > 0)
        [arguments addObjectsFromArray:@[@"-t", [NSString stringWithFormat:@"%.3f", (double)durationMs / 1000.0]]];
    [arguments addObjectsFromArray:@[@"-c", @"copy", @"-shortest", @"-avoid_negative_ts", @"make_zero"]];
    if (HPlusPathExtensionIsPhotosVideo(outputURL.pathExtension))
        [arguments addObjectsFromArray:@[@"-movflags", @"+faststart"]];
    [arguments addObject:outputURL.path];

    id completeBlock = [^(id session) {
        Class returnCodeClass = NSClassFromString(@"ReturnCode");
        id returnCode = HPlusObjectFromSelector(session, @selector(getReturnCode));
        BOOL success = NO;
        if ([returnCodeClass respondsToSelector:@selector(isSuccess:)])
            success = ((BOOL (*)(Class, SEL, id))objc_msgSend)(returnCodeClass, @selector(isSuccess:), returnCode);
        NSError *error = success ? nil : HPlusFFmpegErrorFromSession(session);
        dispatch_async(dispatch_get_main_queue(), ^{
            if (success && [NSFileManager.defaultManager fileExistsAtPath:outputURL.path]) {
                completion(YES, nil);
            } else {
                completion(NO, error ?: [NSError errorWithDomain:@"HPlus" code:7 userInfo:@{NSLocalizedDescriptionKey: @"Merge failed"}]);
            }
        });
    } copy];

    id statisticsBlock = durationMs ? [^(id statistics) {
        if (!progress || ![statistics respondsToSelector:@selector(getTime)]) return;
        double timeMs = ((double (*)(id, SEL))objc_msgSend)(statistics, @selector(getTime));
        if (!isfinite(timeMs) || timeMs <= 0.0) return;
        float p = 0.985f + (0.01f * fminf((float)(timeMs / (double)durationMs), 1.0f));
        dispatch_async(dispatch_get_main_queue(), ^{ progress(p); });
    } copy] : nil;

    ((id (*)(Class, SEL, NSArray *, id, id, id))objc_msgSend)(ffmpegKitClass, executeSelector, arguments, completeBlock, nil, statisticsBlock);
    return YES;
}

static BOOL HPlusStartFFmpegKitAudioConvert(NSURL *inputURL, NSURL *outputURL, HPlusAudioOutputFormat *outputFormat, unsigned long long durationMs, void (^progress)(float progress), HPlusMergeCompletion completion) {
    Class ffmpegKitClass = HPlusFFmpegKitClass();
    SEL executeSelector = @selector(executeWithArgumentsAsync:withCompleteCallback:withLogCallback:withStatisticsCallback:);
    if (![ffmpegKitClass respondsToSelector:executeSelector] || outputFormat.ffmpegArguments.count == 0) return NO;

    NSMutableArray *arguments = [@[@"-y", @"-i", inputURL.path] mutableCopy];
    [arguments addObjectsFromArray:outputFormat.ffmpegArguments];
    [arguments addObject:outputURL.path];

    id completeBlock = [^(id session) {
        Class returnCodeClass = NSClassFromString(@"ReturnCode");
        id returnCode = HPlusObjectFromSelector(session, @selector(getReturnCode));
        BOOL success = NO;
        if ([returnCodeClass respondsToSelector:@selector(isSuccess:)])
            success = ((BOOL (*)(Class, SEL, id))objc_msgSend)(returnCodeClass, @selector(isSuccess:), returnCode);
        NSError *error = success ? nil : HPlusFFmpegErrorFromSession(session);
        dispatch_async(dispatch_get_main_queue(), ^{
            if (success && [NSFileManager.defaultManager fileExistsAtPath:outputURL.path]) {
                completion(YES, nil);
            } else {
                completion(NO, error ?: [NSError errorWithDomain:@"HPlus" code:13 userInfo:@{NSLocalizedDescriptionKey: @"Conversion failed"}]);
            }
        });
    } copy];

    id statisticsBlock = durationMs ? [^(id statistics) {
        if (!progress || ![statistics respondsToSelector:@selector(getTime)]) return;
        double timeMs = ((double (*)(id, SEL))objc_msgSend)(statistics, @selector(getTime));
        if (!isfinite(timeMs) || timeMs <= 0.0) return;
        float p = 0.985f + (0.01f * fminf((float)(timeMs / (double)durationMs), 1.0f));
        dispatch_async(dispatch_get_main_queue(), ^{ progress(p); });
    } copy] : nil;

    ((id (*)(Class, SEL, NSArray *, id, id, id))objc_msgSend)(ffmpegKitClass, executeSelector, arguments, completeBlock, nil, statisticsBlock);
    return YES;
}

// =========================================================
// MARK: - Codec detection
// =========================================================
static NSString *HPlusCodecFromItag(NSInteger itag) {
    if (itag >= 394 && itag <= 401) return @"av01";
    if ((itag >= 242 && itag <= 248) || (itag >= 270 && itag <= 278) ||
        (itag >= 302 && itag <= 303) || (itag >= 308 && itag <= 315) ||
        itag == 330) return @"vp9";
    if (itag >= 43 && itag <= 46) return @"vp8";
    if (itag == 331 || itag == 332 || itag == 333 || itag == 334) return @"hevc";
    return @"avc1";
}

static NSString *HPlusCodecFromMime(NSString *mimeType) {
    NSString *lower = mimeType.lowercaseString ?: @"";
    if ([lower containsString:@"av01"]) return @"av01";
    if ([lower containsString:@"avc1"] || [lower containsString:@"h264"]) return @"avc1";
    if ([lower containsString:@"vp9"]) return @"vp9";
    if ([lower containsString:@"vp8"]) return @"vp8";
    if ([lower containsString:@"hevc"] || [lower containsString:@"h265"]) return @"hevc";
    return nil;
}

static NSString *HPlusMimeDetail(NSString *mimeType) {
    NSString *lower = mimeType.lowercaseString ?: @"";
    NSMutableString *result = [NSMutableString string];
    if ([lower containsString:@"mp4"]) [result appendString:@"mp4"];
    else if ([lower containsString:@"webm"]) [result appendString:@"webm"];
    else if ([lower containsString:@"3gpp"]) [result appendString:@"3gp"];
    else if ([lower containsString:@"mp3"]) [result appendString:@"mp3"];
    else if ([lower containsString:@"aac"]) [result appendString:@"aac"];
    else [result appendString:@"stream"];
    NSString *codec = HPlusCodecFromMime(mimeType);
    if (codec.length) {
        [result appendString:@" · "];
        [result appendString:codec];
    }
    return result.copy;
}

static NSString *HPlusFileExtensionForFormat(HPlusMediaFormat *format, NSString *fallbackExtension) {
    NSString *lower = format.mimeType.lowercaseString ?: @"";
    if ([lower containsString:@"webm"]) return @"webm";
    if ([lower containsString:@"matroska"]) return @"mkv";
    if ([lower containsString:@"quicktime"]) return @"mov";
    if ([lower containsString:@"m4a"]) return @"m4a";
    if ([lower containsString:@"mp4"]) return @"mp4";
    return fallbackExtension ?: @"mp4";
}

static BOOL HPlusFormatLooksMP4Family(HPlusMediaFormat *format) {
    NSString *mime = format.mimeType.lowercaseString ?: @"";
    NSString *extension = HPlusFileExtensionForFormat(format, @"").lowercaseString ?: @"";
    return [mime containsString:@"mp4"] || [mime containsString:@"m4a"] || [mime containsString:@"quicktime"] || [@[@"mp4", @"m4a", @"m4v", @"mov"] containsObject:extension];
}

static BOOL HPlusFormatLooksWebM(HPlusMediaFormat *format) {
    NSString *mime = format.mimeType.lowercaseString ?: @"";
    NSString *extension = HPlusFileExtensionForFormat(format, @"").lowercaseString ?: @"";
    return [mime containsString:@"webm"] || [extension isEqualToString:@"webm"];
}

static NSString *HPlusMergedVideoOutputExtension(HPlusMediaFormat *videoFormat, HPlusMediaFormat *audioFormat) {
    if (HPlusFormatLooksMP4Family(videoFormat) && HPlusFormatLooksMP4Family(audioFormat)) return @"mp4";
    if (HPlusFormatLooksWebM(videoFormat) && HPlusFormatLooksWebM(audioFormat)) return @"webm";
    return @"mkv";
}

static BOOL HPlusVideoFileCanSaveToPhotos(NSURL *fileURL) {
    return HPlusPathExtensionIsPhotosVideo(fileURL.pathExtension);
}

// =========================================================
// MARK: - Audio output formats (FFmpeg conversion targets)
// =========================================================
static HPlusAudioOutputFormat *HPlusAudioOutputFormatMake(NSString *identifier, NSString *title, NSString *subtitle, NSString *fileExtension, NSArray <NSString *> *ffmpegArguments, BOOL passthroughWhenCompatible, BOOL supported) {
    HPlusAudioOutputFormat *format = [HPlusAudioOutputFormat new];
    format.identifier = identifier;
    format.title = title;
    format.subtitle = subtitle;
    format.fileExtension = fileExtension;
    format.ffmpegArguments = ffmpegArguments;
    format.passthroughWhenCompatible = passthroughWhenCompatible;
    format.supported = supported;
    return format;
}

static NSArray <HPlusAudioOutputFormat *> *HPlusAudioOutputFormats(void) {
    static NSArray <HPlusAudioOutputFormat *> *formats = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        formats = @[
            HPlusAudioOutputFormatMake(@"m4a", @"M4A", @"AAC container, passthrough when possible", @"m4a", @[@"-map", @"0:a:0", @"-vn", @"-c:a", @"aac", @"-b:a", @"192k", @"-movflags", @"+faststart"], YES, YES),
            HPlusAudioOutputFormatMake(@"aac", @"AAC", @"Lossy (192k)", @"aac", @[@"-map", @"0:a:0", @"-vn", @"-c:a", @"aac", @"-b:a", @"192k", @"-f", @"adts"], YES, YES),
            HPlusAudioOutputFormatMake(@"mp3", @"MP3", @"Lossy, widely compatible", @"mp3", @[@"-map", @"0:a:0", @"-vn", @"-c:a", @"libmp3lame", @"-q:a", @"2"], NO, YES),
            HPlusAudioOutputFormatMake(@"opus", @"Opus", @"Lossy, small file size", @"opus", @[@"-map", @"0:a:0", @"-vn", @"-c:a", @"libopus", @"-b:a", @"160k", @"-vbr", @"on"], NO, YES),
            HPlusAudioOutputFormatMake(@"ogg", @"OGG", @"Vorbis lossy", @"ogg", @[@"-map", @"0:a:0", @"-vn", @"-c:a", @"libvorbis", @"-q:a", @"6"], NO, YES),
            HPlusAudioOutputFormatMake(@"flac", @"FLAC", @"Lossless compressed", @"flac", @[@"-map", @"0:a:0", @"-vn", @"-c:a", @"flac", @"-compression_level", @"8"], NO, YES),
            HPlusAudioOutputFormatMake(@"alac", @"ALAC", @"Apple lossless (M4A)", @"m4a", @[@"-map", @"0:a:0", @"-vn", @"-c:a", @"alac", @"-movflags", @"+faststart"], NO, YES),
            HPlusAudioOutputFormatMake(@"wav", @"WAV", @"Uncompressed PCM", @"wav", @[@"-map", @"0:a:0", @"-vn", @"-c:a", @"pcm_s24le"], NO, YES),
            HPlusAudioOutputFormatMake(@"aiff", @"AIFF", @"Apple PCM", @"aiff", @[@"-map", @"0:a:0", @"-vn", @"-c:a", @"pcm_s24be"], NO, YES),
        ];
    });
    return formats;
}

static HPlusAudioOutputFormat *HPlusDefaultAudioOutputFormat(void) {
    return [HPlusAudioOutputFormats() firstObject];
}

static BOOL HPlusAudioOutputFormatCanPassthrough(HPlusAudioOutputFormat *outputFormat, HPlusMediaFormat *sourceFormat) {
    if (!outputFormat.passthroughWhenCompatible) return NO;
    NSString *identifier = outputFormat.identifier.lowercaseString ?: @"";
    NSString *mime = sourceFormat.mimeType.lowercaseString ?: @"";
    NSString *extension = HPlusFileExtensionForFormat(sourceFormat, @"").lowercaseString ?: @"";
    if ([identifier isEqualToString:@"m4a"] || [identifier isEqualToString:@"aac"])
        return [extension isEqualToString:@"m4a"] || [mime containsString:@"mp4"] || [mime containsString:@"m4a"];
    return NO;
}

static NSString *HPlusAudioOutputFileExtension(HPlusAudioOutputFormat *outputFormat, HPlusMediaFormat *sourceFormat, BOOL passthrough) {
    NSString *identifier = outputFormat.identifier.lowercaseString ?: @"";
    NSString *mime = sourceFormat.mimeType.lowercaseString ?: @"";
    if (passthrough && ([identifier isEqualToString:@"m4a"] || [identifier isEqualToString:@"aac"]) && ([mime containsString:@"mp4"] || [mime containsString:@"m4a"]))
        return @"m4a";
    return outputFormat.fileExtension ?: HPlusFileExtensionForFormat(sourceFormat, @"m4a");
}

static NSString *HPlusAudioOutputSubtitle(HPlusAudioOutputFormat *outputFormat) {
    return outputFormat.subtitle ?: @"";
}

// =========================================================
// MARK: - Subtitle / Attributed title helpers
// =========================================================
static NSString *HPlusFormatSubtitle(HPlusMediaFormat *format) {
    NSMutableArray *parts = [NSMutableArray array];
    NSString *language = format.languageName.length ? format.languageName : format.languageCode;
    if (language.length) [parts addObject:language];
    if (format.drcAudio) [parts addObject:@"DRC"];
    NSString *detail = HPlusMimeDetail(format.mimeType);
    if (detail.length) [parts addObject:detail];
    NSString *size = HPlusByteCount(format.contentLength);
    if (size.length) [parts addObject:size];
    return [parts componentsJoinedByString:@" · "];
}

static NSAttributedString *HPlusAttributedTitle(NSString *title, NSString *subtitle) {
    if (!subtitle.length) return [[NSAttributedString alloc] initWithString:title ?: @""];
    NSMutableAttributedString *attr = [[NSMutableAttributedString alloc] init];
    [attr appendAttributedString:[[NSAttributedString alloc]
        initWithString:title ?: @""
        attributes:@{
            NSFontAttributeName: [UIFont systemFontOfSize:17 weight:UIFontWeightRegular],
            NSForegroundColorAttributeName: [UIColor labelColor],
        }]];
    [attr appendAttributedString:[[NSAttributedString alloc]
        initWithString:[NSString stringWithFormat:@"  %@", subtitle]
        attributes:@{
            NSFontAttributeName: [UIFont systemFontOfSize:13 weight:UIFontWeightRegular],
            NSForegroundColorAttributeName: [UIColor secondaryLabelColor],
        }]];
    return attr.copy;
}

// =========================================================
// MARK: - Player data extraction
// =========================================================
static NSArray *HPlusPlayerResponsesForPlayer(YTPlayerViewController *player) {
    NSMutableArray *responses = [NSMutableArray array];
    id response = HPlusObjectFromSelector(player, @selector(contentPlayerResponse));
    if (response) [responses addObject:response];

    id activeVideo = HPlusObjectFromSelector(player, @selector(activeVideo));
    response = HPlusObjectFromSelector(activeVideo, @selector(contentPlayerResponse));
    if (response && ![responses containsObject:response]) [responses addObject:response];
    return responses.copy;
}

static id HPlusPlayerDataForPlayer(YTPlayerViewController *player) {
    id response = HPlusPlayerResponsesForPlayer(player).firstObject;
    id playerData = HPlusObjectFromSelector(response, @selector(playerData));
    return playerData ?: response;
}

static NSString *HPlusVideoIDForPlayer(YTPlayerViewController *player) {
    NSString *videoID = [player contentVideoID];
    if (videoID.length == 0) videoID = [player currentVideoID];
    if (videoID.length == 0) videoID = HPlusStringFromSelector(player, @selector(videoID));
    return videoID;
}

static NSString *HPlusTitleForPlayer(YTPlayerViewController *player) {
    id playerData = HPlusPlayerDataForPlayer(player);
    id details = HPlusObjectFromSelector(playerData, @selector(videoDetails));
    NSString *title = HPlusStringFromSelector(details, @selector(title));
    if (title.length) return title;
    NSString *videoID = HPlusVideoIDForPlayer(player);
    return videoID.length ? [NSString stringWithFormat:@"YouTube %@", videoID] : @"YouTube Video";
}

static NSString *HPlusAuthorForPlayer(YTPlayerViewController *player) {
    id playerData = HPlusPlayerDataForPlayer(player);
    id details = HPlusObjectFromSelector(playerData, @selector(videoDetails));
    return HPlusStringFromSelector(details, @selector(author));
}

static NSString *HPlusDescriptionForPlayer(YTPlayerViewController *player) {
    id playerData = HPlusPlayerDataForPlayer(player);
    id details = HPlusObjectFromSelector(playerData, @selector(videoDetails));
    return HPlusStringFromSelector(details, @selector(shortDescription));
}

static NSArray *HPlusCaptionTracksForPlayer(YTPlayerViewController *player) {
    for (id response in HPlusPlayerResponsesForPlayer(player)) {
        id playerData = HPlusObjectFromSelector(response, @selector(playerData)) ?: response;
        id captions = HPlusObjectFromSelector(playerData, @selector(captions));
        id tracklistRenderer = HPlusObjectFromSelector(captions, @selector(playerCaptionsTracklistRenderer));
        NSArray *tracks = HPlusObjectFromSelector(tracklistRenderer, @selector(captionTracksArray));
        if (tracks.count > 0) return tracks;
    }
    return nil;
}

static NSArray *HPlusAdaptiveFormatObjectsForPlayer(YTPlayerViewController *player) {
    NSMutableArray *formats = [NSMutableArray array];
    NSMutableSet *seenPointers = [NSMutableSet set];

    void (^appendFormats)(NSArray *) = ^(NSArray *candidateFormats) {
        if (![candidateFormats isKindOfClass:NSArray.class]) return;
        for (id format in candidateFormats) {
            NSString *key = [NSString stringWithFormat:@"%p", format];
            if ([seenPointers containsObject:key]) continue;
            [seenPointers addObject:key];
            [formats addObject:format];
        }
    };

    id activeVideo = HPlusObjectFromSelector(player, @selector(activeVideo));
    id streamingData = HPlusObjectFromSelector(activeVideo, @selector(streamingData));
    appendFormats(HPlusObjectFromSelector(streamingData, @selector(adaptiveStreams)));
    appendFormats(HPlusObjectFromSelector(activeVideo, @selector(selectableVideoFormats)));

    for (id response in HPlusPlayerResponsesForPlayer(player)) {
        id playerData = HPlusObjectFromSelector(response, @selector(playerData)) ?: response;
        id responseStreamingData = HPlusObjectFromSelector(playerData, @selector(streamingData));
        appendFormats(HPlusObjectFromSelector(responseStreamingData, @selector(adaptiveFormatsArray)));
    }
    return formats.copy;
}

// =========================================================
// MARK: - Media format from stream
// =========================================================
static HPlusMediaFormat *HPlusMediaFormatFromStream(id stream, BOOL video) {
    id formatStream = HPlusObjectFromSelector(stream, @selector(formatStream));
    NSString *url = HPlusStringFromSelector(stream, @selector(URL));
    if (url.length == 0) url = HPlusStringFromSelector(formatStream, @selector(URL));
    if (url.length == 0) url = HPlusStringFromSelector(stream, @selector(url));
    if (url.length == 0) url = HPlusStringFromSelector(formatStream, @selector(url));

    NSString *mimeType = HPlusStringFromSelector(stream, @selector(mimeType));
    if (mimeType.length == 0) mimeType = HPlusStringFromSelector(formatStream, @selector(mimeType));
    NSString *lowerMime = mimeType.lowercaseString ?: @"";
    BOOL streamSaysVideo = HPlusBoolFromSelector(stream, @selector(isVideo)) || HPlusBoolFromSelector(formatStream, @selector(isVideo));
    BOOL streamSaysAudio = HPlusBoolFromSelector(stream, @selector(isAudio)) || HPlusBoolFromSelector(formatStream, @selector(isAudio));
    NSInteger itag = HPlusIntegerFromSelector(stream, @selector(itag));
    if (itag == 0) itag = HPlusIntegerFromSelector(formatStream, @selector(itag));

    // Type check
    BOOL typeMatches = video
        ? ([lowerMime containsString:@"video/"] || streamSaysVideo)
        : ([lowerMime containsString:@"audio/"] || streamSaysAudio);

    if (!typeMatches && mimeType.length == 0) {
        NSSet *knownVideoItags = [NSSet setWithObjects:
            @18, @22, @37, @38, @43, @44, @45, @46, @59, @78,
            @133, @134, @135, @136, @137, @160,
            @212, @242, @243, @244, @247, @248, @264, @266, @271, @272, @278,
            @298, @299, @302, @303, @308, @313, @315, @330,
            @394, @395, @396, @397, @398, @399, @400, @401, nil];
        NSSet *knownAudioItags = [NSSet setWithObjects:
            @139, @140, @141, @171, @172, @249, @250, @251, @256, @258, @325, @328, nil];
        if (video && [knownVideoItags containsObject:@(itag)]) typeMatches = YES;
        if (!video && [knownAudioItags containsObject:@(itag)]) typeMatches = YES;
    }
    if (!typeMatches) return nil;

    HPlusMediaFormat *format = [HPlusMediaFormat new];
    format.source = stream;
    format.video = video;
    format.itag = (int)itag;
    format.codec = HPlusCodecFromItag(itag);
    if (!format.codec) format.codec = HPlusCodecFromMime(mimeType);
    format.urlString = url.length ? HPlusURLStringWithCPN(url) : nil;
    format.mimeType = mimeType.length ? mimeType : (video ? @"video/mp4" : @"audio/mp4");

    NSInteger height = HPlusIntegerFromSelector(stream, @selector(height));
    if (height == 0) height = HPlusIntegerFromSelector(formatStream, @selector(height));
    NSInteger fps = HPlusIntegerFromSelector(stream, @selector(fps));
    if (fps == 0) fps = HPlusIntegerFromSelector(formatStream, @selector(fps));
    if (fps == 0) fps = HPlusIntegerFromSelector(stream, @selector(framesPerSecond));
    if (fps == 0) fps = HPlusIntegerFromSelector(formatStream, @selector(framesPerSecond));
    if (fps == 0) fps = HPlusIntegerFromSelector(stream, @selector(frameRate));
    if (fps == 0) fps = HPlusIntegerFromSelector(formatStream, @selector(frameRate));
    fps = HPlusNormalizedFPS(fps);
    format.fps = (int)fps;
    format.resolution = (int)height;

    format.qualityLabel = HPlusStringFromSelector(stream, @selector(qualityLabel));
    if (format.qualityLabel.length == 0) format.qualityLabel = HPlusStringFromSelector(formatStream, @selector(qualityLabel));

    if (video) {
        NSInteger labelHeight = HPlusResolutionFromQuality(format.qualityLabel);
        NSInteger labelFPS = HPlusFPSFromQuality(format.qualityLabel);
        if (labelHeight == 960) format.qualityLabel = HPlusQualityLabel(labelHeight, fps ?: labelFPS, nil);
        else if (labelFPS == 0 && fps > 0) format.qualityLabel = HPlusQualityLabel(height, fps, format.qualityLabel);
        if (format.qualityLabel.length == 0) format.qualityLabel = HPlusQualityLabel(height, fps, nil);
    }
    if (format.qualityLabel.length == 0 && !video) format.qualityLabel = @"Audio";

    if (!video) {
        NSString *languageCode = HPlusStringFromSelector(stream, @selector(languageCode));
        if (languageCode.length == 0) languageCode = HPlusStringFromSelector(formatStream, @selector(languageCode));
        if (languageCode.length == 0) languageCode = HPlusStringFromSelector(stream, @selector(language));
        if (languageCode.length == 0) languageCode = HPlusStringFromSelector(formatStream, @selector(language));
        format.languageCode = languageCode;

        NSString *languageName = HPlusStringFromSelector(stream, @selector(languageName));
        if (languageName.length == 0) languageName = HPlusStringFromSelector(formatStream, @selector(languageName));
        if (languageName.length == 0) languageName = HPlusStringFromSelector(stream, @selector(displayName));
        if (languageName.length == 0) languageName = HPlusStringFromSelector(formatStream, @selector(displayName));
        format.languageName = languageName.length ? languageName : languageCode;

        NSMutableArray *audioTraits = [NSMutableArray array];
        for (NSString *value in @[
            mimeType ?: @"",
            format.qualityLabel ?: @"",
            HPlusStringFromSelector(stream, @selector(audioTrack)) ?: @"",
            HPlusStringFromSelector(formatStream, @selector(audioTrack)) ?: @"",
            HPlusStringFromSelector(stream, @selector(audioTrackType)) ?: @"",
            HPlusStringFromSelector(formatStream, @selector(audioTrackType)) ?: @"",
        ]) {
            if (value.length) [audioTraits addObject:value];
        }
        format.drcAudio = [[audioTraits componentsJoinedByString:@" "] localizedCaseInsensitiveContainsString:@"drc"];
    }

    if (HPlusBoolFromSelector(stream, @selector(hasContentLength)) || [stream respondsToSelector:@selector(contentLength)])
        format.contentLength = (NSInteger)HPlusUnsignedLongLongFromSelector(stream, @selector(contentLength));
    if (format.contentLength == 0 && (HPlusBoolFromSelector(formatStream, @selector(hasContentLength)) || [formatStream respondsToSelector:@selector(contentLength)]))
        format.contentLength = (NSInteger)HPlusUnsignedLongLongFromSelector(formatStream, @selector(contentLength));
    format.durationMs = (NSUInteger)HPlusUnsignedLongLongFromSelector(stream, @selector(approxDurationMs));
    if (format.durationMs == 0) format.durationMs = (NSUInteger)HPlusUnsignedLongLongFromSelector(formatStream, @selector(approxDurationMs));

    NSMutableDictionary *headers = [NSMutableDictionary dictionary];
    NSDictionary *streamHeaders = HPlusObjectFromSelector(stream, @selector(httpHeaders));
    if (![streamHeaders isKindOfClass:NSDictionary.class]) streamHeaders = HPlusObjectFromSelector(formatStream, @selector(httpHeaders));
    if ([streamHeaders isKindOfClass:NSDictionary.class]) {
        for (id key in streamHeaders) {
            id value = streamHeaders[key];
            if ([key isKindOfClass:NSString.class] && [value isKindOfClass:NSString.class])
                headers[key] = value;
        }
    }
    if (!HPlusHTTPHeadersContainField(headers, @"Origin"))
        headers[@"Origin"] = @"https://www.youtube.com";
    if (!HPlusHTTPHeadersContainField(headers, @"Referer"))
        headers[@"Referer"] = @"https://www.youtube.com/";
    format.httpHeaders = headers;
    return format;
}

// =========================================================
// MARK: - Quality label helpers
// =========================================================
static NSInteger HPlusResolutionFromQuality(NSString *quality) {
    NSScanner *scanner = [NSScanner scannerWithString:quality ?: @""];
    NSInteger value = 0;
    [scanner scanInteger:&value];
    return value;
}

static NSInteger HPlusFPSFromQuality(NSString *quality) {
    NSString *lower = quality.lowercaseString ?: @"";
    NSRange pRange = [lower rangeOfString:@"p"];
    if (pRange.location != NSNotFound && pRange.location + 1 < lower.length) {
        NSString *afterP = [lower substringFromIndex:pRange.location + 1];
        NSScanner *scanner = [NSScanner scannerWithString:afterP];
        NSInteger fps = 0;
        if ([scanner scanInteger:&fps] && fps > 0) return fps;
    }
    if ([lower containsString:@"60fps"] || [lower containsString:@"60 fps"]) return 60;
    if ([lower containsString:@"30fps"] || [lower containsString:@"30 fps"]) return 30;
    return 0;
}

static NSInteger HPlusNormalizedFPS(NSInteger fps) {
    if (fps >= 50 && fps <= 61) return 60;
    if (fps >= 24 && fps <= 31) return 30;
    return fps;
}

static NSInteger HPlusDisplayHeightForVideoHeight(NSInteger height) {
    if (height >= 900 && height < 1080) return 1080;
    return height;
}

static NSString *HPlusQualityLabel(NSInteger height, NSInteger fps, NSString *fallback) {
    height = HPlusDisplayHeightForVideoHeight(height);
    fps = HPlusNormalizedFPS(fps);
    if (height > 0 && fps > 0) return [NSString stringWithFormat:@"%ldp%ld", (long)height, (long)fps];
    if (height > 0) return [NSString stringWithFormat:@"%ldp", (long)height];
    if (fallback.length && fps > 0 && ![fallback.lowercaseString containsString:@"fps"])
        return [NSString stringWithFormat:@"%@ %ldfps", fallback, (long)fps];
    return fallback;
}

// =========================================================
// MARK: - Format list for player
// =========================================================
static NSArray <HPlusMediaFormat *> *HPlusFormatsForPlayer(YTPlayerViewController *player, BOOL video) {
    NSMutableArray *formats = [NSMutableArray array];
    for (id stream in HPlusAdaptiveFormatObjectsForPlayer(player)) {
        HPlusMediaFormat *format = HPlusMediaFormatFromStream(stream, video);
        if (format) [formats addObject:format];
    }

    [formats sortUsingComparator:^NSComparisonResult(HPlusMediaFormat *left, HPlusMediaFormat *right) {
        if (video) {
            NSInteger leftRes = left.resolution;
            NSInteger rightRes = right.resolution;
            if (leftRes != rightRes) return leftRes > rightRes ? NSOrderedAscending : NSOrderedDescending;
            NSInteger leftFPS = left.fps;
            NSInteger rightFPS = right.fps;
            if (leftFPS != rightFPS) return leftFPS > rightFPS ? NSOrderedAscending : NSOrderedDescending;
        }
        BOOL leftMP4 = HPlusFormatLooksMP4Family(left);
        BOOL rightMP4 = HPlusFormatLooksMP4Family(right);
        if (leftMP4 != rightMP4) return leftMP4 ? NSOrderedAscending : NSOrderedDescending;
        if (!video && IS_ENABLED(DownloadPreferDRCAudio) && left.drcAudio != right.drcAudio)
            return left.drcAudio ? NSOrderedAscending : NSOrderedDescending;
        if (left.contentLength != right.contentLength)
            return left.contentLength > right.contentLength ? NSOrderedAscending : NSOrderedDescending;
        return NSOrderedSame;
    }];

    NSMutableArray *unique = [NSMutableArray array];
    NSMutableSet *seen = [NSMutableSet set];
    for (HPlusMediaFormat *format in formats) {
        NSInteger fps = format.fps ?: HPlusFPSFromQuality(format.qualityLabel);
        NSString *key = video
            ? [NSString stringWithFormat:@"%@-%ld-%@-%d", format.qualityLabel ?: @"", (long)fps, format.codec ?: @"", format.itag]
            : [NSString stringWithFormat:@"%@-%@-%@-%@-%d", format.qualityLabel ?: @"", format.languageCode ?: @"", format.drcAudio ? @"drc" : @"std", format.codec ?: @"", format.itag];
        if ([seen containsObject:key]) continue;
        [seen addObject:key];
        [unique addObject:format];
    }
    return unique.copy;
}

static HPlusMediaFormat *HPlusBestAudioFormatForPlayer(YTPlayerViewController *player) {
    return [HPlusFormatsForPlayer(player, NO) firstObject];
}

// =========================================================
// MARK: - Presenter / Player lookup
// =========================================================
static UIViewController *HPlusPresenterForSender(UIView *sender, YTPlayerViewController *player) {
    UIViewController *presenter = nil;
    if ([sender respondsToSelector:@selector(_viewControllerForAncestor)])
        presenter = [sender _viewControllerForAncestor];
    if (!presenter) presenter = player;
    return HPlusTopViewController(presenter);
}

static YTPlayerViewController *HPlusPlayerFromViewController(UIViewController *vc) {
    Class playerClass = NSClassFromString(@"YTPlayerViewController");
    UIViewController *cursor = vc;
    while (cursor) {
        if (playerClass && [cursor isKindOfClass:playerClass]) return (YTPlayerViewController *)cursor;
        id player = HPlusObjectFromSelector(cursor, @selector(playerViewController));
        if (playerClass && [player isKindOfClass:playerClass]) return (YTPlayerViewController *)player;
        cursor = cursor.parentViewController;
    }
    return HPlusCurrentPlayerViewController;
}

static NSURL *HPlusThumbnailURL(YTPlayerViewController *player) {
    if (!player) return nil;
    id playerData = HPlusPlayerDataForPlayer(player);
    id details = HPlusObjectFromSelector(playerData, @selector(videoDetails));
    id thumbmain = HPlusObjectFromSelector(details, @selector(thumbnail));
    NSArray *thumbs = HPlusObjectFromSelector(thumbmain, @selector(thumbnailsArray));
    id best = nil; NSUInteger maxPixels = 0;
    for (id thumb in thumbs) {
        NSInteger w = HPlusIntegerFromSelector(thumb, @selector(width));
        NSInteger h = HPlusIntegerFromSelector(thumb, @selector(height));
        NSUInteger px = (NSUInteger)(w * h);
        if (px > maxPixels) { maxPixels = px; best = thumb; }
    }
    if (!best) {
        NSString *videoID = HPlusVideoIDForPlayer(player);
        if (videoID.length == 0) return nil;
        return [NSURL URLWithString:[NSString stringWithFormat:@"https://i.ytimg.com/vi/%@/maxresdefault.jpg", videoID]];
    }
    NSString *urlString = HPlusStringFromSelector(best, @selector(URL));
    return urlString.length ? [NSURL URLWithString:urlString] : nil;
}

// =========================================================
// MARK: - Photos
// =========================================================
static void HPlusRequestPhotoAccess(void (^completion)(BOOL granted)) {
    if (@available(iOS 14.0, *)) {
        [PHPhotoLibrary requestAuthorizationForAccessLevel:PHAccessLevelAddOnly handler:^(PHAuthorizationStatus status) {
            completion(status == PHAuthorizationStatusAuthorized || status == PHAuthorizationStatusLimited);
        }];
    } else {
        [PHPhotoLibrary requestAuthorization:^(PHAuthorizationStatus status) {
            completion(status == PHAuthorizationStatusAuthorized);
        }];
    }
}

static void HPlusSaveVideoToPhotos(NSURL *fileURL, UIViewController *presenter, void (^completion)(BOOL success, NSError *error)) {
    HPlusRequestPhotoAccess(^(BOOL granted) {
        if (!granted) {
            NSError *error = [NSError errorWithDomain:@"HPlus" code:1 userInfo:@{NSLocalizedDescriptionKey: @"Photos access denied"}];
            completion(NO, error);
            return;
        }
        [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
            [PHAssetCreationRequest creationRequestForAssetFromVideoAtFileURL:fileURL];
        } completionHandler:^(BOOL success, NSError *error) {
            dispatch_async(dispatch_get_main_queue(), ^{ completion(success, error); });
        }];
    });
}

// =========================================================
// MARK: - Share
// =========================================================
static void HPlusShareItem(id item, UIViewController *presenter) {
    if (!item || !presenter) return;
    UIActivityViewController *activity = [[UIActivityViewController alloc] initWithActivityItems:@[item] applicationActivities:nil];
    if (isPad()) {
        activity.popoverPresentationController.sourceView = presenter.view;
        activity.popoverPresentationController.sourceRect = CGRectMake(presenter.view.bounds.size.width / 2, presenter.view.bounds.size.height, 0, 0);
        activity.popoverPresentationController.permittedArrowDirections = 0;
    } else {
        activity.popoverPresentationController.sourceView = presenter.view;
    }
    [presenter presentViewController:activity animated:YES completion:nil];
}

static void HPlusShareFile(NSURL *fileURL, UIViewController *presenter) {
    HPlusShareItem(fileURL, presenter);
}

// =========================================================
// MARK: - Post-download action handling
// =========================================================
static NSInteger HPlusGetPostDownloadAction(void) {
    return INTFORVAL(PostDownloadAction);
}

static void HPlusHandlePostDownloadFile(NSURL *fileURL, BOOL isVideo, UIViewController *presenter) {
    if (!fileURL) return;
    NSInteger action = HPlusGetPostDownloadAction();

    if (action == PostDownloadActionSaveToPhotos) {
        if (isVideo && HPlusVideoFileCanSaveToPhotos(fileURL)) {
            HPlusSaveVideoToPhotos(fileURL, presenter, ^(BOOL success, NSError *error) {
                if (success) {
                    HPlusSendSuccess(LOC(@"SAVED_TO_PHOTOS"));
                } else {
                    HPlusSendError(error.localizedDescription ?: LOC(@"CANNOT_SAVE_TO_PHOTOS"));
                    HPlusShareFile(fileURL, presenter);
                }
            });
        } else {
            HPlusSendSuccess(LOC(@"DOWNLOAD_COMPLETED"));
            HPlusShareFile(fileURL, presenter);
        }
    } else if (action == PostDownloadActionShare) {
        HPlusSendSuccess(LOC(@"DOWNLOAD_COMPLETED"));
        HPlusShareFile(fileURL, presenter);
    } else if (action == PostDownloadActionAsk) {
        UIView *parent = sbGetNotificationParent();
        [SBSkipNotificationView showDownloadCompleteDialogInView:parent
                                                        message:LOC(@"DOWNLOAD_COMPLETED")
                                                    saveHandler:^{
            if (isVideo && HPlusVideoFileCanSaveToPhotos(fileURL)) {
                HPlusSaveVideoToPhotos(fileURL, presenter, ^(BOOL success, NSError *error) {
                    if (success) {
                        HPlusSendSuccess(LOC(@"SAVED_TO_PHOTOS"));
                    } else {
                        HPlusSendError(error.localizedDescription ?: LOC(@"CANNOT_SAVE_TO_PHOTOS"));
                        HPlusShareFile(fileURL, presenter);
                    }
                });
            } else {
                HPlusSendSuccess(LOC(@"DOWNLOAD_COMPLETED"));
                HPlusShareFile(fileURL, presenter);
            }
        } shareHandler:^{
            HPlusShareFile(fileURL, presenter);
        } duration:8.0];
    }
}

static void HPlusHandlePostDownloadImage(UIImage *image, UIViewController *presenter) {
    if (!image) return;
    NSInteger action = HPlusGetPostDownloadAction();

    if (action == PostDownloadActionSaveToPhotos) {
        HPlusRequestPhotoAccess(^(BOOL granted) {
            if (!granted) { HPlusSendError(LOC(@"PHOTO_ACCESS_DENINED")); return; }
            [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
                [PHAssetChangeRequest creationRequestForAssetFromImage:image];
            } completionHandler:^(BOOL success, NSError *saveError) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (success) HPlusSendSuccess(LOC(@"SAVED_TO_PHOTOS"));
                    else {
                        HPlusSendError(saveError.localizedDescription ?: LOC(@"SAVE_FAILED"));
                        HPlusShareItem(image, presenter);
                    }
                });
            }];
        });
    } else if (action == PostDownloadActionShare) {
        HPlusSendSuccess(LOC(@"DOWNLOAD_COMPLETED"));
        HPlusShareItem(image, presenter);
    } else if (action == PostDownloadActionAsk) {
        UIView *parent = sbGetNotificationParent();
        [SBSkipNotificationView showDownloadCompleteDialogInView:parent
                                                        message:LOC(@"DOWNLOAD_COMPLETED")
                                                    saveHandler:^{
            HPlusRequestPhotoAccess(^(BOOL granted) {
                if (!granted) { HPlusSendError(LOC(@"PHOTO_ACCESS_DENINED")); return; }
                [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
                    [PHAssetChangeRequest creationRequestForAssetFromImage:image];
                } completionHandler:^(BOOL success, NSError *saveError) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        if (success) HPlusSendSuccess(LOC(@"SAVED_TO_PHOTOS"));
                        else HPlusSendError(saveError.localizedDescription ?: LOC(@"SAVE_FAILED"));
                    });
                }];
            });
        } shareHandler:^{
            HPlusShareItem(image, presenter);
        } duration:8.0];
    }
}

// =========================================================
// MARK: - Menu presentation (single-line attributed titles)
// =========================================================
static void HPlusPresentMenu(YTPlayerViewController *player, NSArray <HPlusMenuItem *> *items, UIViewController *presenter, UIView *sender) {
    presenter = HPlusTopViewController(presenter);
    Class sheetClass = NSClassFromString(@"YTDefaultSheetController");
    if (sheetClass && [sheetClass respondsToSelector:@selector(sheetControllerWithParentResponder:)]) {
        YTDefaultSheetController *sheet = [sheetClass sheetControllerWithParentResponder:presenter];
        Class actionClass = NSClassFromString(@"YTActionSheetAction");

        for (HPlusMenuItem *item in items) {
            id action = nil;
            NSAttributedString *attrTitle = HPlusAttributedTitle(item.title, item.subtitle);

            if ([actionClass respondsToSelector:@selector(actionWithAttributedTitle:iconImage:style:handler:)]) {
                action = ((id (*)(Class, SEL, NSAttributedString *, UIImage *, NSInteger, id))objc_msgSend)(
                    actionClass, @selector(actionWithAttributedTitle:iconImage:style:handler:),
                    attrTitle, item.iconImage, 0,
                    ^(__unused id a) { if (item.handler) item.handler(); });
            } else if ([actionClass respondsToSelector:@selector(actionWithAttributedTitle:iconImage:handler:)]) {
                action = ((id (*)(Class, SEL, NSAttributedString *, UIImage *, id))objc_msgSend)(
                    actionClass, @selector(actionWithAttributedTitle:iconImage:handler:),
                    attrTitle, item.iconImage,
                    ^(__unused id a) { if (item.handler) item.handler(); });
            } else if ([actionClass respondsToSelector:@selector(actionWithAttributedTitle:style:handler:)]) {
                action = ((id (*)(Class, SEL, NSAttributedString *, NSInteger, id))objc_msgSend)(
                    actionClass, @selector(actionWithAttributedTitle:style:handler:),
                    attrTitle, 0,
                    ^(__unused id a) { if (item.handler) item.handler(); });
            } else {
                NSString *combined = item.subtitle.length
                    ? [NSString stringWithFormat:@"%@  %@", item.title, item.subtitle]
                    : item.title;
                if ([actionClass respondsToSelector:@selector(actionWithTitle:iconImage:style:handler:)]) {
                    action = ((id (*)(Class, SEL, NSString *, UIImage *, NSInteger, id))objc_msgSend)(
                        actionClass, @selector(actionWithTitle:iconImage:style:handler:),
                        combined, item.iconImage, 0,
                        ^(__unused id a) { if (item.handler) item.handler(); });
                } else if ([actionClass respondsToSelector:@selector(actionWithTitle:style:handler:)]) {
                    action = ((id (*)(Class, SEL, NSString *, NSInteger, id))objc_msgSend)(
                        actionClass, @selector(actionWithTitle:style:handler:),
                        combined, 0,
                        ^(__unused id a) { if (item.handler) item.handler(); });
                } else if ([actionClass respondsToSelector:@selector(actionWithTitle:subtitle:iconImage:handler:)]) {
                    action = ((id (*)(Class, SEL, NSString *, NSString *, UIImage *, id))objc_msgSend)(
                        actionClass, @selector(actionWithTitle:subtitle:iconImage:handler:),
                        item.title, item.subtitle, item.iconImage,
                        ^(__unused id a) { if (item.handler) item.handler(); });
                }
            }
            if (action) [sheet addAction:action];
        }

        if (player && [sheet respondsToSelector:@selector(addHeaderWithTitle:subtitle:)]) {
            NSString *author = HPlusAuthorForPlayer(player);
            NSString *title = HPlusTitleForPlayer(player);
            if (author.length || title.length) [sheet addHeaderWithTitle:author subtitle:title];
        }

        if (sender && [sheet respondsToSelector:@selector(presentFromView:animated:completion:)])
            [sheet presentFromView:sender animated:YES completion:nil];
        else
            [sheet presentFromViewController:presenter animated:YES completion:nil];
        return;
    }

    // Fallback
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:nil message:nil preferredStyle:UIAlertControllerStyleActionSheet];
    for (HPlusMenuItem *item in items) {
        NSString *rowTitle = item.subtitle.length
            ? [NSString stringWithFormat:@"%@  %@", item.title, item.subtitle]
            : item.title;
        [alert addAction:[UIAlertAction actionWithTitle:rowTitle style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
            if (item.handler) item.handler();
        }]];
    }
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    alert.popoverPresentationController.sourceView = sender ?: presenter.view;
    [presenter presentViewController:alert animated:YES completion:nil];
}

// =========================================================
// MARK: - HPlusDownloadCoordinator Implementation
// =========================================================
@implementation HPlusDownloadCoordinator

+ (instancetype)sharedCoordinator {
    static HPlusDownloadCoordinator *coordinator;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ coordinator = [HPlusDownloadCoordinator new]; });
    return coordinator;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration defaultSessionConfiguration];
        configuration.HTTPAdditionalHeaders = @{
            @"User-Agent": @"Mozilla/5.0",
            @"Origin": @"https://www.youtube.com",
            @"Referer": @"https://www.youtube.com/",
        };
        configuration.HTTPMaximumConnectionsPerHost = HPlusFastDownloadConcurrency;
        configuration.requestCachePolicy = NSURLRequestReloadIgnoringLocalCacheData;
        configuration.timeoutIntervalForResource = 300;
        _session = [NSURLSession sessionWithConfiguration:configuration delegate:self delegateQueue:[NSOperationQueue mainQueue]];
    }
    return self;
}

- (void)showProgressWithTitle:(NSString *)title presenter:(UIViewController *)presenter {
    self.presenter = presenter;
    self.baseProgressTitle = title;
    self.downloadStartTime = [NSDate timeIntervalSinceReferenceDate];
    UIView *pillParent = sbGetNotificationParent();
    __weak typeof(self) weakSelf = self;
    self.progressPill = [YMDownloadProgressView showInView:pillParent
        message:[NSString stringWithFormat:@"%@ - 0%%", title]
        cancelAction:^{
            [weakSelf cancelWithMessage:LOC(@"DOWNLOAD_CANCELLED")];
        }];
}

- (void)updateProgressTitle:(NSString *)title progress:(float)progress {
    NSString *displayTitle = [NSString stringWithFormat:@"%@ - %ld%%", title, (long)lrintf(progress * 100.0f)];
    [self.progressPill updateProgress:progress title:displayTitle subtitle:nil];
}

- (void)updateSABRProgressTitle:(NSString *)title progress:(float)progress bytesDownloaded:(unsigned long long)bytesDownloaded {
    NSTimeInterval elapsed = [NSDate timeIntervalSinceReferenceDate] - self.downloadStartTime;
    double downloadedMB = (double)bytesDownloaded / 1048576.0;
    double speedMBps = elapsed > 0 ? (downloadedMB / elapsed) : 0;

    NSString *subtitle;
    if (self.totalBytes > 0) {
        progress = fminf(fmaxf((float)bytesDownloaded / (float)self.totalBytes, 0.0f), 1.0f);
        double totalMB = (double)self.totalBytes / 1048576.0;
        subtitle = [NSString stringWithFormat:@"%.1f MB/s · %.1f / %.1f MB", speedMBps, downloadedMB, totalMB];
    } else {
        subtitle = [NSString stringWithFormat:@"%.1f MB/s · %.1f MB", speedMBps, downloadedMB];
    }

    NSString *displayTitle = [NSString stringWithFormat:@"%@ - %ld%%", title, (long)lrintf(progress * 100.0f)];
    [self.progressPill updateProgress:progress title:displayTitle subtitle:subtitle];
}

- (void)cancelWithMessage:(NSString *)message {
    if (![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{ [self cancelWithMessage:message]; });
        return;
    }
    [self.task cancel];
    [self.metadataTask cancel];
    [self.rangeDownloader cancel];
    [self.exporter cancelExport];
    [YMSABR cancelCurrent];
    HPlusCancelFFmpegKit();

    self.task = nil;
    self.metadataTask = nil;
    self.rangeDownloader = nil;
    self.exporter = nil;
    self.fileCompletion = nil;
    self.downloadCompletionBlock = nil;
    self.active = NO;
    self.cancelled = YES;
    if (self.progressPill) { [self.progressPill dismiss]; self.progressPill = nil; }
    [self cleanupTemporaryFiles];
    if (message.length) HPlusSendError(message);
}

- (void)cleanupTemporaryFiles {
    if (self.videoTempURL) [NSFileManager.defaultManager removeItemAtURL:self.videoTempURL error:nil];
    if (self.audioTempURL) [NSFileManager.defaultManager removeItemAtURL:self.audioTempURL error:nil];
    if (self.destinationURL) [NSFileManager.defaultManager removeItemAtURL:self.destinationURL error:nil];
    self.videoTempURL = nil;
    self.audioTempURL = nil;
    self.destinationURL = nil;
}

- (void)downloadURL:(NSURL *)url toURL:(NSURL *)destinationURL expectedBytes:(unsigned long long)expectedBytes headers:(NSDictionary *)headers completion:(HPlusFileDownloadCompletion)completion {
    self.currentResolvedSizeAddedToTotal = NO;
    self.currentExpectedBytes = expectedBytes;
    self.currentBytes = 0;
    if (expectedBytes == 0) {
        __weak typeof(self) weakSelf = self;
        [self resolveExpectedBytesForURL:url headers:headers completion:^(unsigned long long bytes) {
            __strong typeof(weakSelf) self = weakSelf;
            if (!self || self.cancelled) return;
            if (bytes > 0) [self adjustCurrentExpectedBytesIfNeeded:bytes];
            [self beginDownloadURL:url toURL:destinationURL expectedBytes:bytes headers:headers allowFast:YES completion:completion];
        }];
        return;
    }
    [self beginDownloadURL:url toURL:destinationURL expectedBytes:expectedBytes headers:headers allowFast:YES completion:completion];
}

- (void)beginDownloadURL:(NSURL *)url toURL:(NSURL *)destinationURL expectedBytes:(unsigned long long)expectedBytes headers:(NSDictionary *)headers allowFast:(BOOL)allowFast completion:(HPlusFileDownloadCompletion)completion {
    self.destinationURL = destinationURL;
    self.currentExpectedBytes = expectedBytes;
    self.currentBytes = 0;
    self.finishedCurrentFile = NO;
    self.fileCompletion = completion;
    [NSFileManager.defaultManager removeItemAtURL:destinationURL error:nil];

    if (self.cancelled) {
        if (completion) completion(nil, [NSError errorWithDomain:NSCocoaErrorDomain code:NSUserCancelledError userInfo:@{NSLocalizedDescriptionKey: LOC(@"DOWNLOAD_CANCELLED")}]);
        return;
    }

    if (allowFast && expectedBytes == 0) allowFast = NO;

    if (allowFast && expectedBytes >= HPlusFastDownloadMinimumBytes) {
        __weak typeof(self) weakSelf = self;
        self.rangeDownloader = [[HPlusRangeDownloader alloc] initWithURL:url destinationURL:destinationURL expectedBytes:expectedBytes headers:headers progress:^(unsigned long long completedBytes) {
            __strong typeof(weakSelf) self = weakSelf;
            if (!self || self.cancelled) return;
            self.currentBytes = completedBytes;
            [self updateDownloadProgressWithCurrentBytes:completedBytes expectedBytes:expectedBytes];
        } completion:^(NSURL *fileURL, NSError *error) {
            __strong typeof(weakSelf) self = weakSelf;
            if (!self || self.cancelled) return;
            self.rangeDownloader = nil;
            if (error) {
                [self beginDownloadURL:url toURL:destinationURL expectedBytes:expectedBytes headers:headers allowFast:NO completion:completion];
                return;
            }
            if (completion) completion(fileURL, nil);
        }];
        [self.rangeDownloader start];
        return;
    }

    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:60.0];
    HPlusApplyDownloadHeaders(request, headers);
    self.task = [self.session downloadTaskWithRequest:request];
    [self.task resume];
}

- (void)resolveExpectedBytesForURL:(NSURL *)url headers:(NSDictionary *)headers completion:(void (^)(unsigned long long bytes))completion {
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:15.0];
    request.HTTPMethod = @"HEAD";
    HPlusApplyDownloadHeaders(request, headers);

    __weak typeof(self) weakSelf = self;
    self.metadataTask = [NSURLSession.sharedSession dataTaskWithRequest:request completionHandler:^(__unused NSData *data, NSURLResponse *response, __unused NSError *error) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        unsigned long long bytes = 0;
        if (response.expectedContentLength > 0) {
            bytes = (unsigned long long)response.expectedContentLength;
        } else if ([response isKindOfClass:NSHTTPURLResponse.class]) {
            id header = ((NSHTTPURLResponse *)response).allHeaderFields[@"Content-Length"];
            if ([header respondsToSelector:@selector(unsignedLongLongValue)])
                bytes = [header unsignedLongLongValue];
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            self.metadataTask = nil;
            completion(bytes);
        });
    }];
    [self.metadataTask resume];
}

- (void)updateDownloadProgressWithCurrentBytes:(unsigned long long)currentBytes expectedBytes:(unsigned long long)expectedBytes {
    unsigned long long total = self.totalBytes ?: expectedBytes;
    float progress = total ? (float)(self.completedBytes + currentBytes) / (float)total : 0.0f;
    progress = fminf(fmaxf(progress, 0.0f), 1.0f);

    NSTimeInterval elapsed = [NSDate timeIntervalSinceReferenceDate] - self.downloadStartTime;
    double speedMBps = elapsed > 0 ? ((double)(self.completedBytes + currentBytes) / 1048576.0) / elapsed : 0;
    double totalMB = (double)total / 1048576.0;

    NSString *title = [NSString stringWithFormat:@"%@ - %ld%%", self.baseProgressTitle ?: @"Downloading", (long)lrintf(progress * 100.0f)];
    NSString *subtitle;
    if (total > 0) subtitle = [NSString stringWithFormat:@"%.1f MB/s · %.1f MB", speedMBps, totalMB];
    else subtitle = [NSString stringWithFormat:@"%.1f MB/s", speedMBps];
    [self.progressPill updateProgress:progress title:title subtitle:subtitle];
}

- (void)adjustCurrentExpectedBytesIfNeeded:(unsigned long long)newExpectedBytes {
    unsigned long long oldExpectedBytes = self.currentExpectedBytes;
    if (newExpectedBytes <= oldExpectedBytes) return;
    self.currentExpectedBytes = newExpectedBytes;
    if (oldExpectedBytes > 0) {
        self.totalBytes += newExpectedBytes - oldExpectedBytes;
    } else if (!self.currentResolvedSizeAddedToTotal) {
        self.totalBytes += newExpectedBytes;
        self.currentResolvedSizeAddedToTotal = YES;
    }
}

// =========================================================
// Video download entry points
// =========================================================
- (void)startVideoDownloadWithVideoFormat:(HPlusMediaFormat *)videoFormat audioFormat:(HPlusMediaFormat *)audioFormat fileName:(NSString *)fileName presenter:(UIViewController *)presenter videoID:(NSString *)vidID {
    if (self.active) { HPlusSendToast(LOC(@"ALREADY_DOWNLOADING")); return; }
    [self startDirectVideoDownloadWithVideoFormat:videoFormat audioFormat:audioFormat fileName:fileName presenter:presenter videoID:vidID];
}

- (void)startDirectVideoDownloadWithVideoFormat:(HPlusMediaFormat *)videoFormat audioFormat:(HPlusMediaFormat *)audioFormat fileName:(NSString *)fileName presenter:(UIViewController *)presenter videoID:(NSString *)vidID {
    [self cleanupTemporaryFiles];

    // On-device SABR path (routed through SABRDownload.x)
    if (INTFORVAL(DownloadMethod) == DownloadMethodOnDevice) {
        [self startSABRVideoDownloadWithVideoFormat:videoFormat audioFormat:audioFormat fileName:fileName presenter:presenter];
        return;
    }

    NSURL *videoURL = [NSURL URLWithString:videoFormat.urlString];
    NSURL *audioURL = [NSURL URLWithString:audioFormat.urlString];

    // Server path (external)
    if (INTFORVAL(DownloadMethod) == DownloadMethodServer) {
        NSString *resolutionStr = [NSString stringWithFormat:@"%d", videoFormat.itag];
        [self triggerSilentDownloadWithQuality:resolutionStr isAudio:NO videoID:vidID presenter:presenter];
        return;
    }

    if (!videoURL || !audioURL) {
        HPlusSendError(LOC(@"NO_STREAM_URL"));
        return;
    }

    self.active = YES;
    self.cancelled = NO;
    self.completedBytes = 0;
    self.totalBytes = videoFormat.contentLength + audioFormat.contentLength;
    self.videoTempURL = HPlusTemporaryFileURL(HPlusFileExtensionForFormat(videoFormat, @"mp4"));
    self.audioTempURL = HPlusTemporaryFileURL(HPlusFileExtensionForFormat(audioFormat, @"m4a"));
    NSString *outputExtension = HPlusMergedVideoOutputExtension(videoFormat, audioFormat);
    [self showProgressWithTitle:LOC(@"DOWNLOADING_VIDEO") presenter:presenter];

    __weak typeof(self) weakSelf = self;
    [self downloadURL:videoURL toURL:self.videoTempURL expectedBytes:videoFormat.contentLength headers:videoFormat.httpHeaders completion:^(NSURL *videoFileURL, NSError *videoError) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self || self.cancelled) return;
        if (videoError) {
            [self failWithError:videoError ?: [NSError errorWithDomain:@"HPlus" code:2 userInfo:@{NSLocalizedDescriptionKey: @"Video download failed"}]];
            return;
        }
        self.completedBytes += MAX((unsigned long long)videoFormat.contentLength, self.currentBytes);
        [self updateProgressTitle:LOC(@"DOWNLOADING_AUDIO") progress:(self.totalBytes ? (float)self.completedBytes / (float)self.totalBytes : 0.5f)];
        [self downloadURL:audioURL toURL:self.audioTempURL expectedBytes:audioFormat.contentLength headers:audioFormat.httpHeaders completion:^(NSURL *audioFileURL, NSError *audioError) {
            __strong typeof(weakSelf) self = weakSelf;
            if (!self || self.cancelled) return;
            if (audioError) {
                [self failWithError:audioError ?: [NSError errorWithDomain:@"HPlus" code:3 userInfo:@{NSLocalizedDescriptionKey: @"Audio download failed"}]];
                return;
            }
            unsigned long long durationMs = videoFormat.durationMs ?: audioFormat.durationMs;
            [self mergeVideoURL:videoFileURL audioURL:audioFileURL fileName:fileName outputExtension:outputExtension durationMs:durationMs presenter:presenter];
        }];
    }];
}

- (void)startSABRVideoDownloadWithVideoFormat:(HPlusMediaFormat *)videoFormat audioFormat:(HPlusMediaFormat *)audioFormat fileName:(NSString *)fileName presenter:(UIViewController *)presenter {
    self.active = YES;
    self.cancelled = NO;
    self.completedBytes = 0;
    self.totalBytes = videoFormat.contentLength + audioFormat.contentLength;
    [self showProgressWithTitle:LOC(@"DOWNLOADING_VIDEO") presenter:presenter];

    unsigned long long durationMs = videoFormat.durationMs ?: audioFormat.durationMs;
    __weak typeof(self) weakSelf = self;
    [YMSABR downloadVideoItag:videoFormat.itag audioItag:audioFormat.itag
        progress:^(float fraction, unsigned long long bytesDownloaded, BOOL isAudio) {
            __strong typeof(weakSelf) self = weakSelf;
            if (!self || self.cancelled) return;
            NSString *title = isAudio ? LOC(@"DOWNLOADING_AUDIO") : LOC(@"DOWNLOADING_VIDEO");
            [self updateSABRProgressTitle:title progress:fraction bytesDownloaded:bytesDownloaded];
        }
        completion:^(NSURL *videoURL, NSURL *audioURL, NSString *err) {
            __strong typeof(weakSelf) self = weakSelf;
            if (!self || self.cancelled) return;
            if (err || !videoURL || !audioURL) {
                [self failWithError:[NSError errorWithDomain:@"HPlus" code:20 userInfo:@{NSLocalizedDescriptionKey: err ?: LOC(@"DOWNLOAD_FAILED")}]];
                return;
            }
            self.videoTempURL = videoURL;
            self.audioTempURL = audioURL;
            [self mergeVideoURL:videoURL audioURL:audioURL fileName:fileName outputExtension:@"mp4" durationMs:durationMs presenter:presenter];
        }];
}

- (void)startDirectSingleVideoDownloadWithFormat:(HPlusMediaFormat *)format fileName:(NSString *)fileName presenter:(UIViewController *)presenter videoID:(NSString *)vidID {
    NSURL *videoURL = [NSURL URLWithString:format.urlString];
    if (!videoURL) { HPlusSendError(LOC(@"NO_STREAM_URL")); return; }

    self.active = YES;
    self.cancelled = NO;
    self.completedBytes = 0;
    self.totalBytes = format.contentLength;
    NSString *extension = HPlusFileExtensionForFormat(format, @"mp4");
    BOOL canFinalizeWithAVFoundation = format.durationMs > 0 && HPlusPathExtensionIsPhotosVideo(extension);
    NSURL *finalURL = HPlusUniqueFileURL(fileName, extension);
    NSURL *downloadURL = canFinalizeWithAVFoundation ? HPlusTemporaryFileURL(extension) : finalURL;
    self.videoTempURL = canFinalizeWithAVFoundation ? downloadURL : nil;
    [self showProgressWithTitle:LOC(@"DOWNLOADING_VIDEO") presenter:presenter];

    __weak typeof(self) weakSelf = self;
    [self downloadURL:videoURL toURL:downloadURL expectedBytes:format.contentLength headers:format.httpHeaders completion:^(NSURL *fileURL, NSError *error) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self || self.cancelled) return;
        if (error) {
            [self failWithError:error ?: [NSError errorWithDomain:@"HPlus" code:8 userInfo:@{NSLocalizedDescriptionKey: @"Video download failed"}]];
            return;
        }
        if (canFinalizeWithAVFoundation) {
            [self trimSingleVideoURL:fileURL outputURL:finalURL durationMs:format.durationMs presenter:presenter];
            return;
        }
        [self completeWithFileURL:fileURL isVideo:YES presenter:presenter];
    }];
}

// =========================================================
// Audio download entry points
// =========================================================
- (void)startAudioDownloadWithAudioFormat:(HPlusMediaFormat *)audioFormat fileName:(NSString *)fileName presenter:(UIViewController *)presenter videoID:(NSString *)vidID {
    [self startAudioDownloadWithAudioFormat:audioFormat fileName:fileName presenter:presenter videoID:vidID outputFormat:nil];
}

- (void)startAudioDownloadWithAudioFormat:(HPlusMediaFormat *)audioFormat fileName:(NSString *)fileName presenter:(UIViewController *)presenter videoID:(NSString *)vidID outputFormat:(HPlusAudioOutputFormat *)outputFormat {
    if (self.active) { HPlusSendToast(LOC(@"ALREADY_DOWNLOADING")); return; }
    [self startDirectAudioDownloadWithAudioFormat:audioFormat fileName:fileName presenter:presenter videoID:vidID outputFormat:outputFormat];
}

- (void)startDirectAudioDownloadWithAudioFormat:(HPlusMediaFormat *)audioFormat fileName:(NSString *)fileName presenter:(UIViewController *)presenter videoID:(NSString *)vidID outputFormat:(HPlusAudioOutputFormat *)outputFormat {
    [self cleanupTemporaryFiles];

    if (INTFORVAL(DownloadMethod) == DownloadMethodOnDevice) {
        [self startSABRAudioDownloadWithAudioFormat:audioFormat fileName:fileName presenter:presenter];
        return;
    }

    NSURL *audioURL = [NSURL URLWithString:audioFormat.urlString];

    if (INTFORVAL(DownloadMethod) == DownloadMethodServer) {
        [self triggerSilentDownloadWithQuality:nil isAudio:YES videoID:vidID presenter:presenter];
        return;
    }

    if (!audioURL) { HPlusSendError(LOC(@"NO_AUDIO_URL")); return; }

    outputFormat = outputFormat ?: HPlusDefaultAudioOutputFormat();
    if (!outputFormat.supported) {
        HPlusSendError([NSString stringWithFormat:@"%@ not supported", outputFormat.title ?: @"Format"]);
        return;
    }

    self.active = YES;
    self.cancelled = NO;
    self.completedBytes = 0;
    self.totalBytes = audioFormat.contentLength;
    BOOL passthrough = HPlusAudioOutputFormatCanPassthrough(outputFormat, audioFormat);

    if (!passthrough && !HPlusFFmpegKitAvailable()) {
        self.active = NO;
        NSString *details = HPlusFFmpegKitDiagnosticText(outputFormat, audioFormat, vidID);
        HPlusRecordDownloadDiagnostic(@"FFmpegKit unavailable for audio conversion", details);
        NSString *diagnostic = HPlusDownloadDiagnosticText();
        if (diagnostic.length) {
            UIPasteboard.generalPasteboard.string = diagnostic;
            HPlusSendToast(@"FFmpegKit not loaded, diagnostics copied");
        } else {
            HPlusSendError([NSString stringWithFormat:@"FFmpegKit required for %@", outputFormat.title ?: @"this format"]);
        }
        return;
    }

    NSURL *finalURL = HPlusUniqueFileURL(fileName, HPlusAudioOutputFileExtension(outputFormat, audioFormat, passthrough));
    NSURL *downloadURL = passthrough ? finalURL : HPlusTemporaryFileURL(HPlusFileExtensionForFormat(audioFormat, @"m4a"));
    self.audioTempURL = passthrough ? nil : downloadURL;
    [self showProgressWithTitle:LOC(@"DOWNLOADING_AUDIO") presenter:presenter];

    __weak typeof(self) weakSelf = self;
    [self downloadURL:audioURL toURL:downloadURL expectedBytes:audioFormat.contentLength headers:audioFormat.httpHeaders completion:^(NSURL *fileURL, NSError *error) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self || self.cancelled) return;
        if (error) {
            [self failWithError:error ?: [NSError errorWithDomain:@"HPlus" code:4 userInfo:@{NSLocalizedDescriptionKey: @"Audio download failed"}]];
            return;
        }
        if (!passthrough) {
            unsigned long long durationMs = audioFormat.durationMs ?: HPlusDurationMsForURL(fileURL);
            [self convertAudioURL:fileURL outputURL:finalURL outputFormat:outputFormat durationMs:durationMs presenter:presenter];
            return;
        }
        [self completeWithFileURL:fileURL isVideo:NO presenter:presenter];
    }];
}

- (void)startSABRAudioDownloadWithAudioFormat:(HPlusMediaFormat *)audioFormat fileName:(NSString *)fileName presenter:(UIViewController *)presenter {
    self.active = YES;
    self.cancelled = NO;
    self.completedBytes = 0;
    self.totalBytes = audioFormat.contentLength;
    [self showProgressWithTitle:LOC(@"DOWNLOADING_AUDIO") presenter:presenter];

    NSURL *finalURL = HPlusUniqueFileURL(fileName, @"m4a");
    __weak typeof(self) weakSelf = self;
    [YMSABR downloadAudioItag:audioFormat.itag
        progress:^(float fraction, unsigned long long bytesDownloaded) {
            __strong typeof(weakSelf) self = weakSelf;
            if (!self || self.cancelled) return;
            [self updateSABRProgressTitle:LOC(@"DOWNLOADING_AUDIO") progress:fraction bytesDownloaded:bytesDownloaded];
        }
        completion:^(NSURL *audioURL, NSString *err) {
            __strong typeof(weakSelf) self = weakSelf;
            if (!self || self.cancelled) return;
            if (err || !audioURL) {
                [self failWithError:[NSError errorWithDomain:@"HPlus" code:21 userInfo:@{NSLocalizedDescriptionKey: err ?: LOC(@"DOWNLOAD_FAILED")}]];
                return;
            }
            self.audioTempURL = audioURL;
            [self exportSABRAudioURL:audioURL toURL:finalURL presenter:presenter];
        }];
}

- (void)exportSABRAudioURL:(NSURL *)audioURL toURL:(NSURL *)outputURL presenter:(UIViewController *)presenter {
    [self updateProgressTitle:LOC(@"FINA_VIDEO") progress:0.985f];
    AVURLAsset *asset = [AVURLAsset URLAssetWithURL:audioURL options:nil];
    AVAssetExportSession *exportSession = [AVAssetExportSession exportSessionWithAsset:asset presetName:AVAssetExportPresetAppleM4A];
    if (!exportSession) {
        [self failWithError:[NSError errorWithDomain:@"HPlus" code:22 userInfo:@{NSLocalizedDescriptionKey: LOC(@"DOWNLOAD_FAILED")}]];
        return;
    }
    exportSession.outputURL = outputURL;
    exportSession.outputFileType = AVFileTypeAppleM4A;
    self.exporter = exportSession;

    __weak typeof(self) weakSelf = self;
    [exportSession exportAsynchronouslyWithCompletionHandler:^{
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) self = weakSelf;
            if (!self) return;
            self.exporter = nil;
            if (self.cancelled || exportSession.status == AVAssetExportSessionStatusCancelled) return;
            if (exportSession.status == AVAssetExportSessionStatusCompleted) {
                [self completeWithFileURL:outputURL isVideo:NO presenter:presenter];
            } else {
                [self failWithError:exportSession.error ?: [NSError errorWithDomain:@"HPlus" code:23 userInfo:@{NSLocalizedDescriptionKey: LOC(@"DOWNLOAD_FAILED")}]];
            }
        });
    }];
}

- (void)trimAudioToHalfLengthAtURL:(NSURL *)inputURL toURL:(NSURL *)outputURL completion:(void (^)(NSError *error))completion {
    [self updateProgressTitle:LOC(@"TRIMMING_AUDIO") progress:0.985f];
    AVURLAsset *asset = [AVURLAsset URLAssetWithURL:inputURL options:nil];

    [asset loadValuesAsynchronouslyForKeys:@[@"duration"] completionHandler:^{
        NSError *error = nil;
        AVKeyValueStatus status = [asset statusOfValueForKey:@"duration" error:&error];
        if (status != AVKeyValueStatusLoaded) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(error ?: [NSError errorWithDomain:@"HPlus" code:5 userInfo:@{NSLocalizedDescriptionKey: @"Failed to load audio duration"}]);
            });
            return;
        }
        CMTime totalDuration = asset.duration;
        CMTime halfDuration = CMTimeMultiplyByFloat64(totalDuration, 0.5);
        CMTimeRange exportTimeRange = CMTimeRangeMake(kCMTimeZero, halfDuration);

        AVAssetExportSession *exportSession = [AVAssetExportSession exportSessionWithAsset:asset presetName:AVAssetExportPresetAppleM4A];
        if (!exportSession) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion([NSError errorWithDomain:@"HPlus" code:6 userInfo:@{NSLocalizedDescriptionKey: @"Failed to create export session"}]);
            });
            return;
        }
        exportSession.outputURL = outputURL;
        exportSession.outputFileType = AVFileTypeAppleM4A;
        exportSession.timeRange = exportTimeRange;

        [exportSession exportAsynchronouslyWithCompletionHandler:^{
            dispatch_async(dispatch_get_main_queue(), ^{
                if (exportSession.status == AVAssetExportSessionStatusCompleted) {
                    completion(nil);
                } else {
                    completion(exportSession.error ?: [NSError errorWithDomain:@"HPlus" code:7 userInfo:@{NSLocalizedDescriptionKey: @"Audio trim export failed"}]);
                }
            });
        }];
    }];
}

// =========================================================
// Merge + Convert + Finalize
// =========================================================
- (void)mergeVideoURL:(NSURL *)videoURL audioURL:(NSURL *)audioURL fileName:(NSString *)fileName outputExtension:(NSString *)outputExtension durationMs:(unsigned long long)durationMs presenter:(UIViewController *)presenter {
    [self updateProgressTitle:LOC(@"MERGING_VID") progress:0.985f];
    NSURL *outputURL = HPlusUniqueFileURL(fileName, outputExtension.length ? outputExtension : @"mp4");
    if (durationMs == 0) durationMs = HPlusDurationMsForURL(videoURL);

    if (HPlusFFmpegKitAvailable()) {
        __weak typeof(self) weakSelf = self;
        BOOL started = HPlusStartFFmpegKitMerge(videoURL, audioURL, outputURL, durationMs, ^(float progress) {
            __strong typeof(weakSelf) self = weakSelf;
            if (!self || self.cancelled) return;
            [self updateProgressTitle:LOC(@"MERGING_VID") progress:progress];
        }, ^(BOOL success, NSError *error) {
            __strong typeof(weakSelf) self = weakSelf;
            if (!self || self.cancelled) return;
            if (success) {
                [self completeWithFileURL:outputURL isVideo:YES presenter:presenter];
                return;
            }
            [NSFileManager.defaultManager removeItemAtURL:outputURL error:nil];
            if (HPlusVideoFileCanSaveToPhotos(outputURL)) {
                [self mergeVideoWithAVFoundationVideoURL:videoURL audioURL:audioURL outputURL:outputURL durationMs:durationMs presenter:presenter fallbackError:error];
            } else {
                [self failWithError:error ?: [NSError errorWithDomain:@"HPlus" code:16 userInfo:@{NSLocalizedDescriptionKey: @"FFmpegKit required for this stream"}]];
            }
        });
        if (started) return;
    }

    if (HPlusVideoFileCanSaveToPhotos(outputURL)) {
        [self mergeVideoWithAVFoundationVideoURL:videoURL audioURL:audioURL outputURL:outputURL durationMs:durationMs presenter:presenter fallbackError:nil];
    } else {
        [self failWithError:[NSError errorWithDomain:@"HPlus" code:16 userInfo:@{NSLocalizedDescriptionKey: @"FFmpegKit required for this stream"}]];
    }
}

- (void)convertAudioURL:(NSURL *)inputURL outputURL:(NSURL *)outputURL outputFormat:(HPlusAudioOutputFormat *)outputFormat durationMs:(unsigned long long)durationMs presenter:(UIViewController *)presenter {
    [self updateProgressTitle:[NSString stringWithFormat:@"Converting to %@", outputFormat.title ?: @"audio"] progress:0.985f];
    [NSFileManager.defaultManager removeItemAtURL:outputURL error:nil];

    __weak typeof(self) weakSelf = self;
    BOOL started = HPlusStartFFmpegKitAudioConvert(inputURL, outputURL, outputFormat, durationMs, ^(float progress) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self || self.cancelled) return;
        [self updateProgressTitle:[NSString stringWithFormat:@"Converting to %@", outputFormat.title ?: @"audio"] progress:progress];
    }, ^(BOOL success, NSError *error) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self || self.cancelled) return;
        if (success) {
            [self completeWithFileURL:outputURL isVideo:NO presenter:presenter];
            return;
        }
        [self failWithError:error ?: [NSError errorWithDomain:@"HPlus" code:14 userInfo:@{NSLocalizedDescriptionKey: @"Conversion failed"}]];
    });

    if (!started) {
        [self failWithError:[NSError errorWithDomain:@"HPlus" code:15 userInfo:@{NSLocalizedDescriptionKey: @"Format unavailable"}]];
    }
}

- (void)mergeVideoWithAVFoundationVideoURL:(NSURL *)videoURL audioURL:(NSURL *)audioURL outputURL:(NSURL *)outputURL durationMs:(unsigned long long)durationMs presenter:(UIViewController *)presenter fallbackError:(NSError *)fallbackError {
    [self updateProgressTitle:fallbackError ? LOC(@"MERGING_VID_FALLBACK") : LOC(@"MERGING_VID") progress:0.985f];
    AVURLAsset *videoAsset = [AVURLAsset URLAssetWithURL:videoURL options:nil];
    AVURLAsset *audioAsset = [AVURLAsset URLAssetWithURL:audioURL options:nil];
    AVMutableComposition *composition = [AVMutableComposition composition];

    AVAssetTrack *videoTrack = [[videoAsset tracksWithMediaType:AVMediaTypeVideo] firstObject];
    AVAssetTrack *audioTrack = [[audioAsset tracksWithMediaType:AVMediaTypeAudio] firstObject];
    if (!videoTrack || !audioTrack) {
        [self failWithError:fallbackError ?: [NSError errorWithDomain:@"HPlus" code:5 userInfo:@{NSLocalizedDescriptionKey: @"Merge failed"}]];
        return;
    }

    CMTime duration = HPlusExportDuration(videoAsset, audioAsset, durationMs);
    if (!HPlusCMTimeIsUsable(duration)) {
        [self failWithError:fallbackError ?: [NSError errorWithDomain:@"HPlus" code:9 userInfo:@{NSLocalizedDescriptionKey: @"Cannot determine duration"}]];
        return;
    }
    NSError *insertError = nil;
    AVMutableCompositionTrack *compositionVideo = [composition addMutableTrackWithMediaType:AVMediaTypeVideo preferredTrackID:kCMPersistentTrackID_Invalid];
    [compositionVideo insertTimeRange:CMTimeRangeMake(kCMTimeZero, duration) ofTrack:videoTrack atTime:kCMTimeZero error:&insertError];
    compositionVideo.preferredTransform = videoTrack.preferredTransform;
    if (insertError) { [self failWithError:insertError]; return; }

    AVMutableCompositionTrack *compositionAudio = [composition addMutableTrackWithMediaType:AVMediaTypeAudio preferredTrackID:kCMPersistentTrackID_Invalid];
    CMTime audioDuration = HPlusMinUsableDuration(duration, audioTrack.timeRange.duration);
    [compositionAudio insertTimeRange:CMTimeRangeMake(kCMTimeZero, audioDuration) ofTrack:audioTrack atTime:kCMTimeZero error:&insertError];
    if (insertError) { [self failWithError:insertError]; return; }

    AVAssetExportSession *exporter = [[AVAssetExportSession alloc] initWithAsset:composition presetName:AVAssetExportPresetPassthrough];
    exporter.outputURL = outputURL;
    exporter.outputFileType = AVFileTypeMPEG4;
    exporter.shouldOptimizeForNetworkUse = YES;
    self.exporter = exporter;

    __weak typeof(self) weakSelf = self;
    [exporter exportAsynchronouslyWithCompletionHandler:^{
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) self = weakSelf;
            if (!self) return;
            self.exporter = nil;
            if (self.cancelled || exporter.status == AVAssetExportSessionStatusCancelled) return;
            if (exporter.status == AVAssetExportSessionStatusCompleted) {
                [self completeWithFileURL:outputURL isVideo:YES presenter:presenter];
            } else {
                [self failWithError:exporter.error ?: [NSError errorWithDomain:@"HPlus" code:6 userInfo:@{NSLocalizedDescriptionKey: @"Merge failed"}]];
            }
        });
    }];
}

- (void)trimSingleVideoURL:(NSURL *)inputURL outputURL:(NSURL *)outputURL durationMs:(unsigned long long)durationMs presenter:(UIViewController *)presenter {
    [self updateProgressTitle:LOC(@"FINA_VIDEO") progress:0.99f];
    [NSFileManager.defaultManager removeItemAtURL:outputURL error:nil];

    AVURLAsset *asset = [AVURLAsset URLAssetWithURL:inputURL options:nil];
    AVAssetTrack *videoTrack = [[asset tracksWithMediaType:AVMediaTypeVideo] firstObject];
    if (!videoTrack) {
        [self failWithError:[NSError errorWithDomain:@"HPlus" code:10 userInfo:@{NSLocalizedDescriptionKey: @"Cannot finalize video"}]];
        return;
    }

    CMTime duration = HPlusExportDuration(asset, nil, durationMs);
    if (!HPlusCMTimeIsUsable(duration)) {
        [self failWithError:[NSError errorWithDomain:@"HPlus" code:11 userInfo:@{NSLocalizedDescriptionKey: @"Cannot determine duration"}]];
        return;
    }

    AVMutableComposition *composition = [AVMutableComposition composition];
    NSError *insertError = nil;
    AVMutableCompositionTrack *compositionVideo = [composition addMutableTrackWithMediaType:AVMediaTypeVideo preferredTrackID:kCMPersistentTrackID_Invalid];
    [compositionVideo insertTimeRange:CMTimeRangeMake(kCMTimeZero, duration) ofTrack:videoTrack atTime:kCMTimeZero error:&insertError];
    compositionVideo.preferredTransform = videoTrack.preferredTransform;
    if (insertError) { [self failWithError:insertError]; return; }

    AVAssetTrack *audioTrack = [[asset tracksWithMediaType:AVMediaTypeAudio] firstObject];
    if (audioTrack) {
        CMTime audioDuration = HPlusMinUsableDuration(duration, audioTrack.timeRange.duration);
        AVMutableCompositionTrack *compositionAudio = [composition addMutableTrackWithMediaType:AVMediaTypeAudio preferredTrackID:kCMPersistentTrackID_Invalid];
        [compositionAudio insertTimeRange:CMTimeRangeMake(kCMTimeZero, audioDuration) ofTrack:audioTrack atTime:kCMTimeZero error:&insertError];
        if (insertError) { [self failWithError:insertError]; return; }
    }

    AVAssetExportSession *exporter = [[AVAssetExportSession alloc] initWithAsset:composition presetName:AVAssetExportPresetPassthrough];
    exporter.outputURL = outputURL;
    exporter.outputFileType = AVFileTypeMPEG4;
    exporter.shouldOptimizeForNetworkUse = YES;
    self.exporter = exporter;

    __weak typeof(self) weakSelf = self;
    [exporter exportAsynchronouslyWithCompletionHandler:^{
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) self = weakSelf;
            if (!self) return;
            self.exporter = nil;
            if (self.cancelled || exporter.status == AVAssetExportSessionStatusCancelled) return;
            if (exporter.status == AVAssetExportSessionStatusCompleted) {
                [self completeWithFileURL:outputURL isVideo:YES presenter:presenter];
            } else {
                [self failWithError:exporter.error ?: [NSError errorWithDomain:@"HPlus" code:12 userInfo:@{NSLocalizedDescriptionKey: @"Finalize failed"}]];
            }
        });
    }];
}

- (void)completeWithFileURL:(NSURL *)fileURL isVideo:(BOOL)isVideo presenter:(UIViewController *)presenter {
    if (self.cancelled) return;
    self.active = NO;
    [self updateProgressTitle:LOC(@"DOWNLOAD_COMPLETED") progress:1.0f];
    if (self.progressPill) { [self.progressPill dismiss]; self.progressPill = nil; }
    HPlusHandlePostDownloadFile(fileURL, isVideo, presenter);
}

- (void)failWithError:(NSError *)error {
    if (self.cancelled) return;
    self.active = NO;
    if (self.progressPill) { [self.progressPill dismiss]; self.progressPill = nil; }
    [self cleanupTemporaryFiles];
    HPlusSendError(error.localizedDescription ?: LOC(@"DOWNLOAD_FAILED"));
}

// =========================================================
// Server path (silent download)
// =========================================================
- (NSString *)serverEndpoint {
    if (INTFORVAL(DownloadServerIndex) == 0) return @"https://appropriatenet2928.tail6a9ca7.ts.net/";
    if (INTFORVAL(DownloadServerIndex) == 1) return @"https://waterserver.freeddns.org/";
    return @"";
}

- (void)triggerSilentDownloadWithQuality:(NSString *)quality isAudio:(BOOL)isAudio videoID:(NSString *)vidID presenter:(UIViewController *)presenter {
    __weak typeof(self) weakSelf = self;
    [self requestDownloadForVideoId:vidID isAudio:isAudio quality:quality presenter:presenter completion:^(NSURL *localURL, NSString *errorMsg) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf || strongSelf.cancelled) return;
        dispatch_async(dispatch_get_main_queue(), ^{
            if (!strongSelf || strongSelf.cancelled) return;
            if (!localURL) { [strongSelf cancelWithMessage:errorMsg]; return; }
            [strongSelf completeWithFileURL:localURL isVideo:!isAudio presenter:presenter];
        });
    }];
}

- (void)requestDownloadForVideoId:(NSString *)vId isAudio:(BOOL)isAudio quality:(NSString *)quality presenter:(UIViewController *)presenter completion:(void (^)(NSURL *localURL, NSString *errorMsg))completionBlock {
    [self showProgressWithTitle:LOC(@"CONNECTING_TO_SERVER") presenter:presenter];
    NSString *watchURL = [NSString stringWithFormat:@"https://www.youtube.com/watch?v=%@", vId];
    [self startYTDMDownloadWithWatchURL:watchURL format:isAudio ? @"audio" : @"video" formatId:quality presenter:presenter completion:completionBlock];
}

- (void)startYTDMDownloadWithWatchURL:(NSString *)watchURL format:(NSString *)format formatId:(NSString *)formatId presenter:(UIViewController *)presenter completion:(void (^)(NSURL *localURL, NSString *errorMsg))completionBlock {
    if (!self || self.cancelled) return;
    NSString *urlStr = [[self serverEndpoint] stringByAppendingString:@"/api/download"];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:urlStr]];
    [request setHTTPMethod:@"POST"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];

    NSMutableDictionary *payload = [@{@"url": watchURL, @"format": format} mutableCopy];
    if (formatId) payload[@"format_id"] = formatId;
    request.HTTPBody = [NSJSONSerialization dataWithJSONObject:payload options:0 error:nil];

    [[[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (!self || self.cancelled) return;
        if (error || !data) { completionBlock(nil, @"Server unreachable."); return; }
        NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
        if (json[@"job_id"]) {
            BOOL isAudioDl = [format isEqualToString:@"audio"];
            [self pollJobStatus:json[@"job_id"] isAudio:isAudioDl presenter:presenter completion:completionBlock];
        } else {
            completionBlock(nil, json[@"error"] ?: @"Job init failed.");
        }
    }] resume];
}

- (void)pollJobStatus:(NSString *)jobId isAudio:(BOOL)isAudio presenter:(UIViewController *)presenter completion:(void (^)(NSURL *localURL, NSString *errorMsg))completionBlock {
    if (!self || self.cancelled) return;
    NSString *urlStr = [NSString stringWithFormat:@"%@/api/status/%@", [self serverEndpoint], jobId];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:urlStr]];

    [[[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (!self || self.cancelled) return;
        if (error || !data) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [self pollJobStatus:jobId isAudio:isAudio presenter:presenter completion:completionBlock];
            });
            return;
        }
        NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
        NSString *status = json[@"status"];

        if ([status isEqualToString:@"done"]) {
            NSString *singleFileName = json[@"filename"];
            if (!singleFileName || singleFileName.length == 0)
                singleFileName = isAudio ? @"downloaded_file.mp3" : @"downloaded_file.mp4";
            [self downloadSingleFile:singleFileName isAudio:isAudio forJobId:jobId presenter:presenter completion:completionBlock];
        } else if ([status isEqualToString:@"error"]) {
            completionBlock(nil, json[@"error"] ?: @"Error.");
        } else {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self updateProgressTitle:LOC(@"DOWNLOADING_TO_SERVER") progress:0.0f];
            });
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [self pollJobStatus:jobId isAudio:isAudio presenter:presenter completion:completionBlock];
            });
        }
    }] resume];
}

- (void)downloadSingleFile:(NSString *)filename isAudio:(BOOL)isAudio forJobId:(NSString *)jobId presenter:(UIViewController *)presenter completion:(void (^)(NSURL *localURL, NSString *errorMsg))completionBlock {
    if (!self || self.cancelled) return;
    self.downloadCompletionBlock = completionBlock;
    NSString *tempPath = [NSTemporaryDirectory() stringByAppendingPathComponent:filename];
    self.destinationURL = [NSURL fileURLWithPath:tempPath];
    self.finishedCurrentFile = NO;
    self.currentBytes = 0;
    self.currentExpectedBytes = 0;
    self.baseProgressTitle = isAudio ? LOC(@"DOWNLOADING_AUDIO") : LOC(@"DOWNLOADING_VIDEO");
    dispatch_async(dispatch_get_main_queue(), ^{
        [self updateProgressTitle:self.baseProgressTitle progress:0.0f];
    });
    NSString *urlString = [NSString stringWithFormat:@"%@/api/file/%@", [self serverEndpoint], jobId];
    self.task = [self.session downloadTaskWithURL:[NSURL URLWithString:urlString]];
    self.task.taskDescription = filename;
    [self.task resume];
}

// =========================================================
// NSURLSession delegate
// =========================================================
- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask didWriteData:(int64_t)bytesWritten totalBytesWritten:(int64_t)totalBytesWritten totalBytesExpectedToWrite:(int64_t)totalBytesExpectedToWrite {
    self.currentBytes = (unsigned long long)MAX(totalBytesWritten, 0);
    if (totalBytesExpectedToWrite > 0)
        [self adjustCurrentExpectedBytesIfNeeded:(unsigned long long)totalBytesExpectedToWrite];
    if (self.currentBytes > self.currentExpectedBytes)
        [self adjustCurrentExpectedBytesIfNeeded:self.currentBytes];
    [self updateDownloadProgressWithCurrentBytes:self.currentBytes expectedBytes:self.currentExpectedBytes];
}

- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask didFinishDownloadingToURL:(NSURL *)location {
    if (self.cancelled) return;
    self.finishedCurrentFile = YES;
    NSURL *destURL = self.destinationURL;
    NSError *error = nil;
    [[NSFileManager defaultManager] removeItemAtURL:destURL error:nil];
    [[NSFileManager defaultManager] moveItemAtURL:location toURL:destURL error:&error];

    if (self.downloadCompletionBlock) {
        self.downloadCompletionBlock(error ? nil : destURL, error ? error.localizedDescription : nil);
        self.downloadCompletionBlock = nil;
    } else if (self.fileCompletion) {
        self.fileCompletion(error ? nil : destURL, error);
        self.fileCompletion = nil;
    }
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error {
    if (error && !self.finishedCurrentFile) {
        if (self.downloadCompletionBlock) {
            self.downloadCompletionBlock(nil, error.localizedDescription);
            self.downloadCompletionBlock = nil;
        } else if (self.fileCompletion) {
            self.fileCompletion(nil, error);
            self.fileCompletion = nil;
        }
    }
}

@end

// =========================================================
// MARK: - Thumbnail / Photo helpers
// =========================================================
static void HPlusDownloadThumbnail(YTPlayerViewController *player, UIViewController *presenter) {
    NSURL *thumbnailURL = HPlusThumbnailURL(player);
    if (!thumbnailURL) {
        HPlusSendError(LOC(@"NO_THUMBNAIL_FOUND"));
        return;
    }
    HPlusSendToast(LOC(@"DOWNLOADING_THUMBNAIL"));
    [[NSURLSession.sharedSession dataTaskWithURL:thumbnailURL completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        UIImage *image = data ? [UIImage imageWithData:data] : nil;
        dispatch_async(dispatch_get_main_queue(), ^{
            if (!image || error) {
                HPlusSendError(error.localizedDescription ?: LOC(@"THUMBNAIL_FAILED"));
                return;
            }
            HPlusHandlePostDownloadImage(image, presenter);
        });
    }] resume];
}

static void HPlusCopyThumbnail(YTPlayerViewController *player, UIViewController *presenter) {
    NSURL *thumbnailURL = HPlusThumbnailURL(player);
    if (!thumbnailURL) {
        HPlusSendError(LOC(@"NO_THUMBNAIL_FOUND"));
        return;
    }
    HPlusSendToast(LOC(@"DOWNLOADING_THUMBNAIL"));
    [[NSURLSession.sharedSession dataTaskWithURL:thumbnailURL completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        UIImage *image = data ? [UIImage imageWithData:data] : nil;
        dispatch_async(dispatch_get_main_queue(), ^{
            if (!image || error) {
                HPlusSendError(error.localizedDescription ?: LOC(@"THUMBNAIL_FAILED"));
                return;
            }
            [[UIPasteboard generalPasteboard] setImage:image];
            HPlusSendSuccess(LOC(@"COPIED_TO_CLIPBOARD"));
        });
    }] resume];
}

static void HPlusShowThumbnailViewer(YTPlayerViewController *player, UIViewController *presenter) {
    NSURL *thumbnailURL = HPlusThumbnailURL(player);
    if (!thumbnailURL) {
        HPlusSendError(LOC(@"NO_THUMBNAIL_FOUND"));
        return;
    }
    [[NSURLSession.sharedSession dataTaskWithURL:thumbnailURL completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        UIImage *image = data ? [UIImage imageWithData:data] : nil;
        dispatch_async(dispatch_get_main_queue(), ^{
            if (!image || error) {
                HPlusSendError(error.localizedDescription ?: LOC(@"THUMBNAIL_FAILED"));
                return;
            }
            HPlusThumbnailViewController *viewerVC = [[HPlusThumbnailViewController alloc] init];
            viewerVC.thumbnailImage = image;
            viewerVC.modalPresentationStyle = UIModalPresentationFormSheet;
            [presenter presentViewController:viewerVC animated:YES completion:nil];
        });
    }] resume];
}

// =========================================================
// MARK: - Copy helpers
// =========================================================
static void HPlusCopyTextToPasteboard(NSString *text, NSString *successKey) {
    UIPasteboard.generalPasteboard.string = text;
    HPlusSendSuccess(LOC(successKey));
}

static void HPlusCopyImageToPasteboard(UIImage *image, NSString *successKey) {
    UIPasteboard.generalPasteboard.image = image;
    HPlusSendSuccess(LOC(successKey));
}

// =========================================================
// MARK: - Menu builders (video / audio / captions / thumbnail / info)
// =========================================================
static void HPlusShowVideoQualitySheet(YTPlayerViewController *player, UIViewController *presenter, UIView *sender) {
    NSArray <HPlusMediaFormat *> *videoFormats = HPlusFormatsForPlayer(player, YES);
    HPlusMediaFormat *audioFormat = HPlusBestAudioFormatForPlayer(player);
    NSString *title = HPlusTitleForPlayer(player);
    NSString *videoID = HPlusVideoIDForPlayer(player);

    if (videoFormats.count == 0 || !audioFormat) {
        HPlusSendError(LOC(@"NO_VID_AUDIO_STREAM_FOUND"));
        return;
    }

    NSMutableArray *items = [NSMutableArray array];
    for (HPlusMediaFormat *format in videoFormats) {
        NSString *rowTitle = format.qualityLabel.length ? format.qualityLabel : @"Video";
        NSString *subtitle = HPlusFormatSubtitle(format);
        [items addObject:[HPlusMenuItem itemWithTitle:rowTitle subtitle:subtitle icon:HPlusYTIconImage(658, NO, nil) handler:^{
            [[HPlusDownloadCoordinator sharedCoordinator] startVideoDownloadWithVideoFormat:format audioFormat:audioFormat fileName:title presenter:presenter videoID:videoID];
        }]];
    }
    HPlusPresentMenu(player, items, presenter, sender);
}

static void HPlusShowAudioSourceSheet(YTPlayerViewController *player, HPlusAudioOutputFormat *outputFormat, UIViewController *presenter, UIView *sender) {
    NSArray <HPlusMediaFormat *> *audioFormats = HPlusFormatsForPlayer(player, NO);
    NSString *title = HPlusTitleForPlayer(player);
    NSString *videoID = HPlusVideoIDForPlayer(player);
    NSMutableArray *items = [NSMutableArray array];

    if (audioFormats.count == 0) {
        HPlusSendError(LOC(@"NO_AUDIO_STREAM_FOUND"));
        return;
    }

    NSUInteger index = 1;
    for (HPlusMediaFormat *format in audioFormats) {
        NSString *rowTitle = audioFormats.count == 1 ? @"Audio" : [NSString stringWithFormat:@"Audio %lu", (unsigned long)index++];
        NSString *subtitle = HPlusFormatSubtitle(format);
        [items addObject:[HPlusMenuItem itemWithTitle:rowTitle subtitle:subtitle icon:HPlusYTIconImage(21, NO, nil) handler:^{
            [[HPlusDownloadCoordinator sharedCoordinator] startAudioDownloadWithAudioFormat:format fileName:title presenter:presenter videoID:videoID outputFormat:outputFormat];
        }]];
    }
    HPlusPresentMenu(player, items, presenter, sender);
}

static void HPlusShowAudioSheet(YTPlayerViewController *player, UIViewController *presenter, UIView *sender) {
    NSMutableArray *items = [NSMutableArray array];
    for (HPlusAudioOutputFormat *format in HPlusAudioOutputFormats()) {
        [items addObject:[HPlusMenuItem itemWithTitle:format.title subtitle:HPlusAudioOutputSubtitle(format) icon:HPlusYTIconImage(21, NO, nil) handler:^{
            if (!format.supported) {
                HPlusSendError(@"DSD export is not supported by bundled FFmpeg.");
                return;
            }
            HPlusShowAudioSourceSheet(player, format, presenter, sender);
        }]];
    }
    HPlusPresentMenu(player, items, presenter, sender);
}

static void HPlusStartDownloadAudio(YTPlayerViewController *player, UIViewController *presenter, UIView *sender) {
    HPlusShowAudioSheet(player, presenter, sender);
}

static void HPlusShowCaptionsSheet(YTPlayerViewController *player, UIViewController *presenter, UIView *sender) {
    NSArray *tracks = HPlusCaptionTracksForPlayer(player);
    if (tracks.count == 0) {
        HPlusSendError(LOC(@"NO_CAPTIONS"));
        return;
    }

    NSMutableArray *items = [NSMutableArray array];
    for (id track in tracks) {
        NSString *baseURL = HPlusStringFromSelector(track, @selector(baseURL));
        if (baseURL.length == 0) continue;

        NSString *languageCode = HPlusStringFromSelector(track, @selector(languageCode));
        NSString *vssId = HPlusStringFromSelector(track, @selector(vssId));
        NSString *nameStr = nil;
        id nameObj = HPlusObjectFromSelector(track, @selector(name));
        nameStr = HPlusStringFromSelector(nameObj, @selector(simpleText));
        if (!nameStr.length) {
            NSArray *runs = HPlusObjectFromSelector(nameObj, @selector(runsArray));
            if (runs.count > 0) nameStr = HPlusStringFromSelector(runs.firstObject, @selector(text));
        }
        if (!nameStr.length) nameStr = languageCode;
        if (!nameStr.length) nameStr = vssId;

        [items addObject:[HPlusMenuItem itemWithTitle:nameStr subtitle:languageCode icon:HPlusYTIconImage(50, NO, nil) handler:^{
            NSString *vttURL = [baseURL stringByAppendingString:@"&fmt=vtt"];
            NSURL *url = [NSURL URLWithString:vttURL];
            if (!url) {
                HPlusSendError(LOC(@"NO_CAPTIONS_URL"));
                return;
            }
            HPlusSendToast(LOC(@"DOWNLOADING_CAPTIONS"));
            [[NSURLSession.sharedSession dataTaskWithURL:url completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (error || data.length == 0) {
                        HPlusSendError(LOC(@"CAPTIONS_FAILED"));
                        return;
                    }
                    NSString *title = HPlusTitleForPlayer(player);
                    NSString *filename = [NSString stringWithFormat:@"%@.%@", title, languageCode ?: @"captions"];
                    NSURL *tempURL = HPlusUniqueFileURL(filename, @"vtt");
                    NSError *writeError = nil;
                    BOOL writeSuccess = [data writeToURL:tempURL options:NSDataWritingAtomic error:&writeError];
                    if (writeSuccess) {
                        HPlusSendSuccess(LOC(@"DOWNLOAD_COMPLETED"));
                        HPlusShareFile(tempURL, presenter);
                    } else {
                        HPlusSendError(writeError.localizedDescription ?: LOC(@"CAPTIONS_FAILED"));
                    }
                });
            }] resume];
        }]];
    }

    if (items.count == 0) {
        HPlusSendError(LOC(@"NO_CAPTIONS_URL"));
        return;
    }
    HPlusPresentMenu(player, items, presenter, sender);
}

static void HPlusShowThumbnailSheet(YTPlayerViewController *player, UIViewController *presenter, UIView *sender) {
    NSMutableArray *items = [NSMutableArray array];
    [items addObject:[HPlusMenuItem itemWithTitle:LOC(@"SAVE_THUMBNAIL") subtitle:nil icon:HPlusYTIconImage(57, NO, nil) handler:^{
        HPlusDownloadThumbnail(player, presenter);
    }]];
    [items addObject:[HPlusMenuItem itemWithTitle:LOC(@"SHOW_THUMBNAIL") subtitle:nil icon:HPlusYTIconImage(208, NO, nil) handler:^{
        HPlusShowThumbnailViewer(player, presenter);
    }]];
    [items addObject:[HPlusMenuItem itemWithTitle:LOC(@"COPY_THUMBNAIL") subtitle:nil icon:HPlusYTIconImage(250, NO, nil) handler:^{
        HPlusCopyThumbnail(player, presenter);
    }]];
    HPlusPresentMenu(player, items, presenter, sender);
}

static void HPlusShowCopyVideoInfoSheet(YTPlayerViewController *player, UIViewController *presenter, UIView *sender) {
    NSString *author = HPlusAuthorForPlayer(player);
    NSString *title = HPlusTitleForPlayer(player);
    NSString *description = HPlusDescriptionForPlayer(player);
    NSString *all = [NSString stringWithFormat:@"%@ - %@\n%@", author, title, description];

    NSMutableArray *items = [NSMutableArray array];
    [items addObject:[HPlusMenuItem itemWithTitle:LOC(@"COPY_ALL_VID_INFO") subtitle:nil icon:HPlusYTIconImage(250, NO, nil) handler:^{
        HPlusCopyTextToPasteboard(all, @"COPIED_VID_INFO");
    }]];
    [items addObject:[HPlusMenuItem itemWithTitle:LOC(@"COPY_AUTHOR") subtitle:nil icon:HPlusYTIconImage(250, NO, nil) handler:^{
        HPlusCopyTextToPasteboard(author, @"COPIED_AUTHOR");
    }]];
    [items addObject:[HPlusMenuItem itemWithTitle:LOC(@"COPY_TITLE") subtitle:nil icon:HPlusYTIconImage(250, NO, nil) handler:^{
        HPlusCopyTextToPasteboard(title, @"COPIED_TITLE");
    }]];
    [items addObject:[HPlusMenuItem itemWithTitle:LOC(@"COPY_DESCRIPTION") subtitle:nil icon:HPlusYTIconImage(250, NO, nil) handler:^{
        HPlusCopyTextToPasteboard(description, @"COPIED_DESCRIPTION");
    }]];
    HPlusPresentMenu(player, items, presenter, sender);
}

// =========================================================
// MARK: - Download manager (main entry)
// =========================================================
static void HPlusShowDownloadManager(YTPlayerViewController *player, UIViewController *presenter, UIView *sender, BOOL isShorts) {
    if (!player) {
        HPlusSendError(LOC(@"OPEN_VID_BEFORE"));
        return;
    }

    NSMutableArray *items = [NSMutableArray array];
    YTSingleVideoController *sgvidcon = player.activeVideo;
    YTSingleVideo *sgvid = sgvidcon.singleVideo;
    BOOL isLive = NO;
    if (sgvid && [sgvid respondsToSelector:@selector(isLivePlayback)])
        isLive = [sgvid isLivePlayback];

    if (!isLive) {
        if (isShorts) {
            [items addObject:[HPlusMenuItem itemWithTitle:LOC(@"DOWNLOAD_SHORTS") subtitle:nil icon:HPlusYTIconImage(769, NO, nil) handler:^{
                HPlusShowVideoQualitySheet(player, presenter, sender);
            }]];
        } else {
            [items addObject:[HPlusMenuItem itemWithTitle:LOC(@"DOWNLOAD_VIDEO") subtitle:nil icon:HPlusYTIconImage(658, NO, nil) handler:^{
                HPlusShowVideoQualitySheet(player, presenter, sender);
            }]];
        }
        [items addObject:[HPlusMenuItem itemWithTitle:LOC(@"DOWNLOAD_AUDIO") subtitle:nil icon:HPlusYTIconImage(21, NO, nil) handler:^{
            HPlusStartDownloadAudio(player, presenter, sender);
        }]];
        [items addObject:[HPlusMenuItem itemWithTitle:LOC(@"DOWNLOAD_CAPTIONS") subtitle:nil icon:HPlusYTIconImage(50, NO, nil) handler:^{
            HPlusShowCaptionsSheet(player, presenter, sender);
        }]];
    }
    [items addObject:[HPlusMenuItem itemWithTitle:LOC(@"THUMBNAIL_OPTIONS") subtitle:nil icon:HPlusYTIconImage(367, NO, nil) handler:^{
        HPlusShowThumbnailSheet(player, presenter, sender);
    }]];
    [items addObject:[HPlusMenuItem itemWithTitle:LOC(@"COPY_VID_INFO") subtitle:nil icon:HPlusYTIconImage(250, NO, nil) handler:^{
        HPlusShowCopyVideoInfoSheet(player, presenter, sender);
    }]];
    [items addObject:[HPlusMenuItem itemWithTitle:@"Copy diagnostics" subtitle:@"Copy last error log" icon:HPlusYTIconImage(870, NO, nil) handler:^{
        HPlusCopyDownloadDiagnostics(presenter);
    }]];
    HPlusPresentMenu(player, items, presenter, sender);
}

// =========================================================
// MARK: - Download button hook
// =========================================================
void HPlusConfigureDownloadButton(_ASDisplayView *view) {
    if (!IS_ENABLED(DownloadManager)) return;
    if (![view.accessibilityIdentifier isEqualToString:@"id.ui.add_to.offline.button"]) return;
    if (objc_getAssociatedObject(view, @selector(HPlusDownloadButtonTapped:))) return;

    view.userInteractionEnabled = YES;
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:view action:@selector(HPlusDownloadButtonTapped:)];
    tap.cancelsTouchesInView = YES;
    tap.delaysTouchesBegan = YES;
    tap.delaysTouchesEnded = YES;
    [view addGestureRecognizer:tap];
    objc_setAssociatedObject(view, @selector(HPlusDownloadButtonTapped:), @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
// =========================================================
// MARK: - Translation dialog (defined locally)
// =========================================================
static void HPlusShowTranslationDialog(NSString *text, UIViewController *presenter) {
    if (!text || text.length == 0 || !presenter) return;

    HPlusTranslationViewController *vc = [[HPlusTranslationViewController alloc] init];
    vc.originalText = text;

    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:vc];

    if (@available(iOS 15.0, *)) {
        UISheetPresentationController *sheet = nav.sheetPresentationController;
        if (sheet) {
            sheet.detents = @[
                [UISheetPresentationControllerDetent mediumDetent],
                [UISheetPresentationControllerDetent largeDetent]
            ];
            sheet.prefersGrabberVisible = YES;
            sheet.preferredCornerRadius = 24.0;
        }
    } else {
        nav.modalPresentationStyle = UIModalPresentationFormSheet;
    }
    [presenter presentViewController:nav animated:YES completion:nil];
}

// =========================================================
// MARK: - Comment / Post long-press helpers
// =========================================================
static NSString *HPlusExtractCommentText(UIView *cellView) {
    if (!cellView) return @"";

    NSString *resultText = @"";
    NSMutableArray<UIView *> *queue = [NSMutableArray arrayWithObject:cellView];
    Class asDisplayClass = NSClassFromString(@"_ASDisplayView");
    Class elmTextExClass = NSClassFromString(@"ELMExpandableTextNode");
    Class elmTextClass = NSClassFromString(@"ELMTextNode");

    while (queue.count > 0) {
        UIView *current = queue.firstObject;
        [queue removeObjectAtIndex:0];

        if (asDisplayClass && [current isKindOfClass:asDisplayClass]) {
            ASDisplayNode *node = [current performSelector:@selector(keepalive_node)];
            BOOL isExpandableText = node && elmTextExClass && [node isKindOfClass:elmTextExClass];
            BOOL isText = node && elmTextClass && [node isKindOfClass:elmTextClass];
            BOOL isCommentLabel = [current.accessibilityIdentifier isEqualToString:@"id.comment.content.label"];

            if (isText || isExpandableText || isCommentLabel) {
                resultText = current.accessibilityLabel ?: @"";
                break;
            }
            for (id obj in node.yogaChildren) {
                if ([obj isKindOfClass:elmTextClass] && [[obj description] containsString:@"id.comment.content.label"]) {
                    NSAttributedString *text = [obj valueForKey:@"_attributedText"];
                    resultText = text.string;
                    break;
                }
            }
        }
        [queue addObjectsFromArray:current.subviews];
    }
    return resultText;
}

static UIImage *HPlusRenderViewToImage(_ASDisplayView *view) {
    if (!view || view.bounds.size.width <= 0 || view.bounds.size.height <= 0) return nil;
    UIColor *realBgColor = isDarkMode(view) ? [YTColor black3] : [YTColor white1];
    UIGraphicsBeginImageContextWithOptions(view.bounds.size, NO, [UIScreen mainScreen].scale);
    CGContextRef context = UIGraphicsGetCurrentContext();
    [realBgColor setFill];
    CGContextFillRect(context, view.bounds);
    [view drawViewHierarchyInRect:view.bounds afterScreenUpdates:YES];
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return image;
}

// =========================================================
// MARK: - %hook _ASDisplayView
// =========================================================
%hook _ASDisplayView

- (void)didMoveToWindow {
    %orig;
    if ([self.accessibilityIdentifier isEqualToString:@"id.ui.comment_cell"] && IS_ENABLED(DownloadComment)) {
        BOOL hasGesture = NO;
        for (UIGestureRecognizer *g in self.gestureRecognizers) {
            if ([g.name isEqualToString:@"HPlusCommentLongPress"]) { hasGesture = YES; break; }
        }
        if (!hasGesture) {
            UILongPressGestureRecognizer *longPress = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(HPlusHandleCommentLongPress:)];
            longPress.name = @"HPlusCommentLongPress";
            longPress.minimumPressDuration = 0.3;
            [self addGestureRecognizer:longPress];
        }
    } else if ([self.accessibilityIdentifier isEqualToString:@"id.ui.backstage.original_post"] && IS_ENABLED(DownloadPost)) {
        BOOL hasGesture = NO;
        for (UIGestureRecognizer *g in self.gestureRecognizers) {
            if ([g.name isEqualToString:@"HPlusPostLongPress"]) { hasGesture = YES; break; }
        }
        if (!hasGesture) {
            UILongPressGestureRecognizer *longPress = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(HPlusHandlePostLongPress:)];
            longPress.name = @"HPlusPostLongPress";
            longPress.minimumPressDuration = 0.3;
            [self addGestureRecognizer:longPress];
        }
    }
}

%new
- (void)HPlusDownloadButtonTapped:(UITapGestureRecognizer *)sender {
    if (sender.state != UIGestureRecognizerStateEnded) return;
    UIViewController *presenter = HPlusPresenterForSender(self, HPlusCurrentPlayerViewController);
    YTPlayerViewController *player = HPlusPlayerFromViewController(presenter);
    HPlusShowDownloadManager(player, presenter, self, NO);
}

%new
- (void)HPlusHandleCommentLongPress:(UILongPressGestureRecognizer *)sender {
    if (sender.state != UIGestureRecognizerStateBegan) return;
    NSMutableArray *items = [NSMutableArray array];
    NSString *commentText = HPlusExtractCommentText(self);

    if (commentText.length > 0) {
        [items addObject:[HPlusMenuItem itemWithTitle:LOC(@"TRANSLATE_COMMENT") subtitle:nil icon:HPlusYTIconImage(897, NO, nil) handler:^{
            UIViewController *presenter = HPlusPresenterForSender(self, nil);
            HPlusShowTranslationDialog(commentText, presenter);
        }]];
        [items addObject:[HPlusMenuItem itemWithTitle:LOC(@"COPY_COMMENT_TEXT") subtitle:nil icon:HPlusYTIconImage(243, NO, nil) handler:^{
            HPlusCopyTextToPasteboard(commentText, @"COPIED_TO_CLIPBOARD");
        }]];
    }
    [items addObject:[HPlusMenuItem itemWithTitle:LOC(@"SAVE_COMMENT_IMAGE") subtitle:nil icon:HPlusYTIconImage(367, NO, nil) handler:^{
        UIImage *image = HPlusRenderViewToImage(self);
        if (image) {
            UIViewController *p = HPlusPresenterForSender(self, nil);
            HPlusHandlePostDownloadImage(image, p);
        }
    }]];
    [items addObject:[HPlusMenuItem itemWithTitle:LOC(@"COPY_COMMENT_IMAGE") subtitle:nil icon:HPlusYTIconImage(208, NO, nil) handler:^{
        UIImage *image = HPlusRenderViewToImage(self);
        if (image) HPlusCopyImageToPasteboard(image, @"COPIED_TO_CLIPBOARD");
    }]];

    UIViewController *presenter = HPlusPresenterForSender(self, nil);
    if (!presenter) return;
    HPlusPresentMenu(nil, items, presenter, self);
}

%new
- (void)HPlusHandlePostLongPress:(UILongPressGestureRecognizer *)sender {
    if (sender.state != UIGestureRecognizerStateBegan) return;
    NSMutableArray *items = [NSMutableArray array];
    NSString *text = HPlusExtractCommentText(self);

    if (text.length > 0) {
        [items addObject:[HPlusMenuItem itemWithTitle:LOC(@"TRANSLATE_POST") subtitle:nil icon:HPlusYTIconImage(897, NO, nil) handler:^{
            UIViewController *presenter = HPlusPresenterForSender(self, nil);
            HPlusShowTranslationDialog(text, presenter);
        }]];
        [items addObject:[HPlusMenuItem itemWithTitle:LOC(@"COPY_POST_TEXT") subtitle:nil icon:HPlusYTIconImage(243, NO, nil) handler:^{
            HPlusCopyTextToPasteboard(text, @"COPIED_TO_CLIPBOARD");
        }]];
    }
    [items addObject:[HPlusMenuItem itemWithTitle:LOC(@"SAVE_POST_IMAGE") subtitle:nil icon:HPlusYTIconImage(367, NO, nil) handler:^{
        UIImage *image = HPlusRenderViewToImage(self);
        if (image) {
            UIViewController *p = HPlusPresenterForSender(self, nil);
            HPlusHandlePostDownloadImage(image, p);
        }
    }]];
    [items addObject:[HPlusMenuItem itemWithTitle:LOC(@"COPY_POST_IMAGE") subtitle:nil icon:HPlusYTIconImage(208, NO, nil) handler:^{
        UIImage *image = HPlusRenderViewToImage(self);
        if (image) HPlusCopyImageToPasteboard(image, @"COPIED_TO_CLIPBOARD");
    }]];

    UIViewController *presenter = HPlusPresenterForSender(self, nil);
    if (!presenter) return;
    HPlusPresentMenu(nil, items, presenter, self);
}

%end

// =========================================================
// MARK: - %hook YTPlayerViewController
// =========================================================
%hook YTPlayerViewController

- (void)viewDidAppear:(BOOL)animated {
    %orig;
    HPlusCurrentPlayerViewController = self;
}

- (void)viewWillDisappear:(BOOL)animated {
    %orig;
    if (HPlusCurrentPlayerViewController == self)
        HPlusCurrentPlayerViewController = nil;
}

%end

// =========================================================
// MARK: - Auth header (for download requests)
// =========================================================
NSString *HPlusGlobalAuthHeader = nil;

%hook SSOAuthorization
- (id)accessToken {
    id token = %orig;
    if ([token isKindOfClass:[NSString class]] && [(NSString *)token length] > 0) {
        HPlusGlobalAuthHeader = [NSString stringWithFormat:@"Bearer %@", token];
    }
    return token;
}
%end

%hook SSOAuthorizationImpl
- (id)accessToken {
    id token = %orig;
    if ([token isKindOfClass:[NSString class]] && [(NSString *)token length] > 0) {
        HPlusGlobalAuthHeader = [NSString stringWithFormat:@"Bearer %@", token];
    }
    return token;
}
%end

%hook GNPSSOAuthorizationService
- (id)authToken {
    id token = %orig;
    if ([token isKindOfClass:[NSString class]] && [(NSString *)token length] > 0) {
        HPlusGlobalAuthHeader = [NSString stringWithFormat:@"Bearer %@", token];
    }
    return token;
}
%end

// =========================================================
// MARK: - %hook YTReelWatchPlaybackOverlayView (Shorts download button)
// =========================================================
%hook YTReelWatchPlaybackOverlayView

- (void)layoutSubviews {
    %orig;
    if (!IS_ENABLED(AddDownloadToShorts)) return;
    YTQTMButton *downloadBtn = (YTQTMButton *)[self viewWithTag:1501];
    if (!downloadBtn) {
        UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:20 weight:UIImageSymbolWeightMedium];
        UIImage *icon = [[UIImage systemImageNamed:@"arrow.down.circle" withConfiguration:config] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
        downloadBtn = [YTQTMButton iconButton];
        [downloadBtn setImage:icon forState:UIControlStateNormal];
        downloadBtn.tintColor = [UIColor whiteColor];
        downloadBtn.exclusiveTouch = YES;
        downloadBtn.tag = 1501;
        [downloadBtn addTarget:self action:@selector(didTapHPlusShortsDownload:) forControlEvents:UIControlEventTouchUpInside];
        [downloadBtn enableNewTouchFeedback];
        [self addSubview:downloadBtn];
    }
    CGFloat btnWidth = 64.0;
    CGFloat btnHeight = 60.0;
    YTReelElementAsyncComponentView *pov = nil;
    @try { pov = [self valueForKey:@"_playerOverlayView"]; } @catch (...) {}
    YTReelElementAsyncComponentView *actionBar = [self valueForKey:@"_actionBarComponentView"];
    CGFloat X = [UIScreen mainScreen].bounds.size.width - actionBar.frame.origin.x - btnWidth;
    CGFloat Y = 0.0;
    if (pov == nil) {
        Y = actionBar.frame.origin.y - 76.0;
        btnHeight = btnHeight + 16.0;
    } else {
        Y = pov.frame.origin.y - 60.0;
    }
    downloadBtn.frame = CGRectMake(X, Y, btnWidth, btnHeight);
    [self bringSubviewToFront:downloadBtn];
}

%new
- (void)didTapHPlusShortsDownload:(YTQTMButton *)button {
    YTShortsPlayerViewController *shortsPlayerView = (YTShortsPlayerViewController *)self._viewControllerForAncestor;
    YTPlayerViewController *player = (YTPlayerViewController *)shortsPlayerView.childViewControllers[0];
    UIViewController *presenter = HPlusPresenterForSender(button, player);
    HPlusShowDownloadManager(player, presenter, button, YES);
}

%end

// =========================================================
// MARK: - Overlay button registration (%ctor)
// =========================================================
%ctor {
    %init;
    YMOverlayButtonSpec *download = [[YMOverlayButtonSpec alloc] init];
    download.identifier = @"download.video";
    download.symbolName = @"arrow.down.circle";
    download.settingsSymbolName = @"arrow.down.circle";
    download.displayName = LOC(@"DOWNLOAD_BUTTON");
    download.tintColor = [UIColor whiteColor];
    download.sortOrder = 200;
    download.isVisible = ^BOOL(YTPlayerViewController *player) {
        return YMIsOverlayButtonEnabled(@"download.video");
    };
    download.onTap = ^(YTPlayerViewController *player, UIButton *button) {
        UIViewController *presenter = HPlusPresenterForSender(button, player ?: HPlusCurrentPlayerViewController);
        YTPlayerViewController *resolved = HPlusPlayerFromViewController(presenter) ?: player ?: HPlusCurrentPlayerViewController;
        HPlusShowDownloadManager(resolved, presenter, button, NO);
    };
    YMRegisterOverlayButton(download);
}
