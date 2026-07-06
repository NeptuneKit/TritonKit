#import "TritonSimCameraHook.h"
#import <AVFoundation/AVFoundation.h>
#import <CoreMedia/CoreMedia.h>
#import <CoreVideo/CoreVideo.h>
#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
#import <QuartzCore/QuartzCore.h>
#import <objc/runtime.h>
#import <sys/socket.h>
#import <sys/un.h>
#import <unistd.h>

static NSString * const TritonSimCameraBackUID = @"TRITON-SIM-CAMERA-BACK";
static NSString * const TritonSimCameraFrontUID = @"TRITON-SIM-CAMERA-FRONT";
static const char *TritonFakeDeviceKey = "triton.fake.device";
static const char *TritonDiscoveryDevicesKey = "triton.discovery.devices";
static const char *TritonSessionInputsKey = "triton.session.inputs";
static const char *TritonSessionOutputsKey = "triton.session.outputs";
static const char *TritonSessionRunningKey = "triton.session.running";
static const char *TritonOutputSessionKey = "triton.output.session";
static const char *TritonPreviewSessionKey = "triton.preview.session";
static const char *TritonPreviewOverlayKey = "triton.preview.overlay";

@interface TritonSimCameraDevice : AVCaptureDevice
@end

@implementation TritonSimCameraDevice {
    NSString *_uid;
    NSString *_name;
    AVCaptureDevicePosition _position;
}

+ (instancetype)backCamera {
    TritonSimCameraDevice *device = class_createInstance(self, 0);
    device->_uid = TritonSimCameraBackUID;
    device->_name = @"Triton Simulator Back Camera";
    device->_position = AVCaptureDevicePositionBack;
    return device;
}

+ (instancetype)frontCamera {
    TritonSimCameraDevice *device = class_createInstance(self, 0);
    device->_uid = TritonSimCameraFrontUID;
    device->_name = @"Triton Simulator Front Camera";
    device->_position = AVCaptureDevicePositionFront;
    return device;
}

- (NSString *)uniqueID { return _uid; }
- (NSString *)localizedName { return _name; }
- (NSString *)modelID { return @"TritonSimCamera"; }
- (NSString *)manufacturer { return @"TritonKit"; }
- (AVCaptureDevicePosition)position { return _position; }
- (BOOL)isConnected { return YES; }
- (BOOL)hasMediaType:(AVMediaType)mediaType { return [mediaType isEqualToString:AVMediaTypeVideo]; }
- (BOOL)supportsAVCaptureSessionPreset:(AVCaptureSessionPreset)preset { return YES; }
- (BOOL)lockForConfiguration:(NSError **)outError { return YES; }
- (void)unlockForConfiguration {}
- (NSArray<AVCaptureDeviceFormat *> *)formats { return @[]; }
@end

@interface TritonSampleDelegateEntry : NSObject
@property(nonatomic, weak) id<AVCaptureVideoDataOutputSampleBufferDelegate> delegate;
@property(nonatomic, strong) dispatch_queue_t queue;
@property(nonatomic, weak) AVCaptureVideoDataOutput *output;
@end

@implementation TritonSampleDelegateEntry
@end

static NSMutableArray<TritonSampleDelegateEntry *> *gSampleDelegates;
static NSHashTable<AVCaptureVideoPreviewLayer *> *gPreviewLayers;
static AVCaptureDevice *gBackCamera;
static AVCaptureDevice *gFrontCamera;

static AVCaptureDevice *TritonBackCamera(void) {
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        gBackCamera = [TritonSimCameraDevice backCamera];
    });
    return gBackCamera;
}

static AVCaptureDevice *TritonFrontCamera(void) {
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        gFrontCamera = [TritonSimCameraDevice frontCamera];
    });
    return gFrontCamera;
}

static NSArray<AVCaptureDevice *> *TritonCamerasForPosition(AVCaptureDevicePosition position) {
    switch (position) {
        case AVCaptureDevicePositionFront:
            return @[TritonFrontCamera()];
        case AVCaptureDevicePositionBack:
            return @[TritonBackCamera()];
        default:
            return @[TritonBackCamera(), TritonFrontCamera()];
    }
}

static BOOL TritonIsFakeDevice(AVCaptureDevice *device) {
    return [device isKindOfClass:[TritonSimCameraDevice class]];
}

static BOOL TritonInputUsesFakeDevice(AVCaptureInput *input) {
    AVCaptureDevice *device = objc_getAssociatedObject(input, TritonFakeDeviceKey);
    return device != nil;
}

static NSMutableArray *TritonAssociatedArray(id object, const void *key) {
    NSMutableArray *array = objc_getAssociatedObject(object, key);
    if (array == nil) {
        array = [NSMutableArray array];
        objc_setAssociatedObject(object, key, array, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return array;
}

static IMP TritonSwizzleClassMethod(Class cls, SEL selector, id block) {
    Method method = class_getClassMethod(cls, selector);
    if (method == NULL) {
        return NULL;
    }
    Class meta = object_getClass(cls);
    IMP original = method_getImplementation(method);
    IMP replacement = imp_implementationWithBlock(block);
    const char *types = method_getTypeEncoding(method);
    class_replaceMethod(meta, selector, replacement, types);
    return original;
}

static IMP TritonSwizzleInstanceMethod(Class cls, SEL selector, id block) {
    Method method = class_getInstanceMethod(cls, selector);
    if (method == NULL) {
        return NULL;
    }
    IMP original = method_getImplementation(method);
    IMP replacement = imp_implementationWithBlock(block);
    const char *types = method_getTypeEncoding(method);
    class_replaceMethod(cls, selector, replacement, types);
    return original;
}

static BOOL TritonReadFully(int fd, void *buffer, size_t byteCount) {
    uint8_t *cursor = (uint8_t *)buffer;
    size_t remaining = byteCount;
    while (remaining > 0) {
        ssize_t readCount = read(fd, cursor, remaining);
        if (readCount <= 0) {
            return NO;
        }
        cursor += readCount;
        remaining -= (size_t)readCount;
    }
    return YES;
}

static int TritonConnectSocket(NSString *socketPath) {
    int fd = socket(AF_UNIX, SOCK_STREAM, 0);
    if (fd < 0) {
        return -1;
    }
    struct sockaddr_un addr;
    memset(&addr, 0, sizeof(addr));
    addr.sun_family = AF_UNIX;
    NSData *pathData = [socketPath dataUsingEncoding:NSUTF8StringEncoding];
    if (pathData.length >= sizeof(addr.sun_path)) {
        close(fd);
        return -1;
    }
    memcpy(addr.sun_path, pathData.bytes, pathData.length);
    if (connect(fd, (struct sockaddr *)&addr, sizeof(addr)) != 0) {
        close(fd);
        return -1;
    }
    return fd;
}

static void TritonPixelBufferRelease(void *releaseRefCon, const void *baseAddress) {
    if (releaseRefCon != NULL) {
        CFRelease(releaseRefCon);
    }
}

static CGImageRef TritonMakeCGImage(TritonSimCameraFrameHeader header, NSData *payload) {
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGDataProviderRef provider = CGDataProviderCreateWithCFData((__bridge CFDataRef)payload);
    if (colorSpace == NULL || provider == NULL) {
        if (colorSpace) {
            CGColorSpaceRelease(colorSpace);
        }
        if (provider) {
            CGDataProviderRelease(provider);
        }
        return NULL;
    }
    CGImageRef image = CGImageCreate(
        header.width,
        header.height,
        8,
        32,
        header.bytesPerRow,
        colorSpace,
        kCGBitmapByteOrder32Little | kCGImageAlphaPremultipliedFirst,
        provider,
        NULL,
        false,
        kCGRenderingIntentDefault
    );
    CGDataProviderRelease(provider);
    CGColorSpaceRelease(colorSpace);
    return image;
}

static CMSampleBufferRef TritonMakeSampleBuffer(TritonSimCameraFrameHeader header, NSData *payload) {
    CVPixelBufferRef pixelBuffer = NULL;
    NSDictionary *attrs = @{ (NSString *)kCVPixelBufferIOSurfacePropertiesKey: @{} };
    OSStatus pixelStatus = CVPixelBufferCreateWithBytes(
        kCFAllocatorDefault,
        header.width,
        header.height,
        kCVPixelFormatType_32BGRA,
        (void *)payload.bytes,
        header.bytesPerRow,
        TritonPixelBufferRelease,
        (void *)CFBridgingRetain(payload),
        (__bridge CFDictionaryRef)attrs,
        &pixelBuffer
    );
    if (pixelStatus != noErr || pixelBuffer == NULL) {
        return NULL;
    }

    CMVideoFormatDescriptionRef format = NULL;
    OSStatus formatStatus = CMVideoFormatDescriptionCreateForImageBuffer(kCFAllocatorDefault, pixelBuffer, &format);
    if (formatStatus != noErr || format == NULL) {
        CVPixelBufferRelease(pixelBuffer);
        return NULL;
    }

    CMTime pts = CMTimeMake((int64_t)header.hostTimeNs, 1000000000);
    CMSampleTimingInfo timing = { kCMTimeInvalid, pts, kCMTimeInvalid };
    CMSampleBufferRef sampleBuffer = NULL;
    OSStatus sampleStatus = CMSampleBufferCreateForImageBuffer(
        kCFAllocatorDefault,
        pixelBuffer,
        true,
        NULL,
        NULL,
        format,
        &timing,
        &sampleBuffer
    );
    CFRelease(format);
    CVPixelBufferRelease(pixelBuffer);
    if (sampleStatus != noErr) {
        return NULL;
    }
    return sampleBuffer;
}

static void TritonFanoutSampleBuffer(CMSampleBufferRef sampleBuffer) {
    NSArray<TritonSampleDelegateEntry *> *snapshot;
    @synchronized(gSampleDelegates) {
        NSPredicate *alive = [NSPredicate predicateWithBlock:^BOOL(TritonSampleDelegateEntry *entry, NSDictionary *bindings) {
            return entry.delegate != nil && entry.output != nil;
        }];
        [gSampleDelegates filterUsingPredicate:alive];
        snapshot = [gSampleDelegates copy];
    }
    for (TritonSampleDelegateEntry *entry in snapshot) {
        id<AVCaptureVideoDataOutputSampleBufferDelegate> delegate = entry.delegate;
        AVCaptureVideoDataOutput *output = entry.output;
        if (delegate == nil || output == nil) {
            continue;
        }
        if (![delegate respondsToSelector:@selector(captureOutput:didOutputSampleBuffer:fromConnection:)]) {
            continue;
        }
        CFRetain(sampleBuffer);
        dispatch_async(entry.queue ?: dispatch_get_main_queue(), ^{
            [delegate captureOutput:output didOutputSampleBuffer:sampleBuffer fromConnection:nil];
            CFRelease(sampleBuffer);
        });
    }
}

static CALayer *TritonPreviewOverlay(AVCaptureVideoPreviewLayer *previewLayer) {
    CALayer *overlay = objc_getAssociatedObject(previewLayer, TritonPreviewOverlayKey);
    if (overlay == nil) {
        overlay = [CALayer layer];
        overlay.frame = previewLayer.bounds;
        overlay.contentsGravity = kCAGravityResizeAspectFill;
        overlay.masksToBounds = YES;
        [previewLayer addSublayer:overlay];
        objc_setAssociatedObject(previewLayer, TritonPreviewOverlayKey, overlay, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return overlay;
}

static void TritonFanoutPreviewImage(CGImageRef image) {
    if (image == NULL) {
        return;
    }
    NSArray<AVCaptureVideoPreviewLayer *> *snapshot;
    @synchronized(gPreviewLayers) {
        snapshot = gPreviewLayers.allObjects;
    }
    if (snapshot.count == 0) {
        return;
    }
    CGImageRetain(image);
    dispatch_async(dispatch_get_main_queue(), ^{
        for (AVCaptureVideoPreviewLayer *layer in snapshot) {
            CALayer *overlay = TritonPreviewOverlay(layer);
            overlay.frame = layer.bounds;
            overlay.contents = (__bridge id)image;
        }
        CGImageRelease(image);
    });
}

static void TritonFrameLoop(NSString *socketPath) {
    while (YES) {
        @autoreleasepool {
            int fd = TritonConnectSocket(socketPath);
            if (fd < 0) {
                [NSThread sleepForTimeInterval:1.0];
                continue;
            }
            while (YES) {
                TritonSimCameraFrameHeader header;
                if (!TritonReadFully(fd, &header, sizeof(header))) {
                    break;
                }
                if (header.magic != TritonSimCameraMagic ||
                    header.version != TritonSimCameraProtocolVersion ||
                    header.pixelFormat != TritonSimCameraPixelFormatBGRA ||
                    header.payloadLen == 0) {
                    break;
                }
                NSMutableData *payload = [NSMutableData dataWithLength:header.payloadLen];
                if (!TritonReadFully(fd, payload.mutableBytes, header.payloadLen)) {
                    break;
                }
                CMSampleBufferRef sampleBuffer = TritonMakeSampleBuffer(header, payload);
                if (sampleBuffer != NULL) {
                    TritonFanoutSampleBuffer(sampleBuffer);
                    CFRelease(sampleBuffer);
                }
                CGImageRef image = TritonMakeCGImage(header, payload);
                if (image != NULL) {
                    TritonFanoutPreviewImage(image);
                    CGImageRelease(image);
                }
            }
            close(fd);
        }
    }
}

static void TritonInstallAVFoundationHooks(void) {
    gSampleDelegates = [NSMutableArray array];
    gPreviewLayers = [NSHashTable weakObjectsHashTable];

    SEL devicesSel = @selector(devicesWithMediaType:);
    static NSArray *(*origDevices)(id, SEL, AVMediaType) = NULL;
    origDevices = (void *)TritonSwizzleClassMethod([AVCaptureDevice class], devicesSel, ^NSArray *(id self, AVMediaType mediaType) {
        if (![mediaType isEqualToString:AVMediaTypeVideo]) {
            return origDevices ? origDevices(self, devicesSel, mediaType) : @[];
        }
        return TritonCamerasForPosition(AVCaptureDevicePositionUnspecified);
    });

    SEL defaultDeviceSel = @selector(defaultDeviceWithMediaType:);
    static AVCaptureDevice *(*origDefaultDevice)(id, SEL, AVMediaType) = NULL;
    origDefaultDevice = (void *)TritonSwizzleClassMethod([AVCaptureDevice class], defaultDeviceSel, ^AVCaptureDevice *(id self, AVMediaType mediaType) {
        if (![mediaType isEqualToString:AVMediaTypeVideo]) {
            return origDefaultDevice ? origDefaultDevice(self, defaultDeviceSel, mediaType) : nil;
        }
        return TritonBackCamera();
    });

    SEL deviceWithUIDSel = @selector(deviceWithUniqueID:);
    static AVCaptureDevice *(*origDeviceWithUID)(id, SEL, NSString *) = NULL;
    origDeviceWithUID = (void *)TritonSwizzleClassMethod([AVCaptureDevice class], deviceWithUIDSel, ^AVCaptureDevice *(id self, NSString *uid) {
        if ([uid isEqualToString:TritonSimCameraBackUID]) {
            return TritonBackCamera();
        }
        if ([uid isEqualToString:TritonSimCameraFrontUID]) {
            return TritonFrontCamera();
        }
        return origDeviceWithUID ? origDeviceWithUID(self, deviceWithUIDSel, uid) : nil;
    });

    SEL typedDefaultSel = @selector(defaultDeviceWithDeviceType:mediaType:position:);
    static AVCaptureDevice *(*origTypedDefault)(id, SEL, AVCaptureDeviceType, AVMediaType, AVCaptureDevicePosition) = NULL;
    origTypedDefault = (void *)TritonSwizzleClassMethod([AVCaptureDevice class], typedDefaultSel, ^AVCaptureDevice *(id self, AVCaptureDeviceType type, AVMediaType mediaType, AVCaptureDevicePosition position) {
        if (![mediaType isEqualToString:AVMediaTypeVideo]) {
            return origTypedDefault ? origTypedDefault(self, typedDefaultSel, type, mediaType, position) : nil;
        }
        return position == AVCaptureDevicePositionFront ? TritonFrontCamera() : TritonBackCamera();
    });

    SEL authorizationSel = @selector(authorizationStatusForMediaType:);
    static AVAuthorizationStatus (*origAuthorization)(id, SEL, AVMediaType) = NULL;
    origAuthorization = (void *)TritonSwizzleClassMethod([AVCaptureDevice class], authorizationSel, ^AVAuthorizationStatus(id self, AVMediaType mediaType) {
        if ([mediaType isEqualToString:AVMediaTypeVideo]) {
            return AVAuthorizationStatusAuthorized;
        }
        return origAuthorization ? origAuthorization(self, authorizationSel, mediaType) : AVAuthorizationStatusNotDetermined;
    });

    SEL requestAccessSel = @selector(requestAccessForMediaType:completionHandler:);
    static void (*origRequestAccess)(id, SEL, AVMediaType, void (^)(BOOL)) = NULL;
    origRequestAccess = (void *)TritonSwizzleClassMethod([AVCaptureDevice class], requestAccessSel, ^(id self, AVMediaType mediaType, void (^handler)(BOOL)) {
        if ([mediaType isEqualToString:AVMediaTypeVideo]) {
            if (handler) {
                dispatch_async(dispatch_get_main_queue(), ^{ handler(YES); });
            }
            return;
        }
        if (origRequestAccess) {
            origRequestAccess(self, requestAccessSel, mediaType, handler);
        } else if (handler) {
            handler(NO);
        }
    });

    SEL discoverySel = @selector(discoverySessionWithDeviceTypes:mediaType:position:);
    static AVCaptureDeviceDiscoverySession *(*origDiscovery)(id, SEL, NSArray *, AVMediaType, AVCaptureDevicePosition) = NULL;
    origDiscovery = (void *)TritonSwizzleClassMethod([AVCaptureDeviceDiscoverySession class], discoverySel, ^AVCaptureDeviceDiscoverySession *(id self, NSArray *types, AVMediaType mediaType, AVCaptureDevicePosition position) {
        if (![mediaType isEqualToString:AVMediaTypeVideo]) {
            return origDiscovery ? origDiscovery(self, discoverySel, types, mediaType, position) : nil;
        }
        AVCaptureDeviceDiscoverySession *session = class_createInstance([AVCaptureDeviceDiscoverySession class], 0);
        objc_setAssociatedObject(session, TritonDiscoveryDevicesKey, TritonCamerasForPosition(position), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        return session;
    });

    SEL discoveryDevicesSel = @selector(devices);
    static NSArray *(*origDiscoveryDevices)(id, SEL) = NULL;
    origDiscoveryDevices = (void *)TritonSwizzleInstanceMethod([AVCaptureDeviceDiscoverySession class], discoveryDevicesSel, ^NSArray *(AVCaptureDeviceDiscoverySession *self) {
        NSArray *devices = objc_getAssociatedObject(self, TritonDiscoveryDevicesKey);
        return devices ?: (origDiscoveryDevices ? origDiscoveryDevices(self, discoveryDevicesSel) : @[]);
    });

    SEL initInputSel = @selector(initWithDevice:error:);
    static id (*origInitInput)(id, SEL, AVCaptureDevice *, NSError **) = NULL;
    origInitInput = (void *)TritonSwizzleInstanceMethod([AVCaptureDeviceInput class], initInputSel, ^id(AVCaptureDeviceInput *self, AVCaptureDevice *device, NSError **error) {
        if (!TritonIsFakeDevice(device)) {
            return origInitInput ? origInitInput(self, initInputSel, device, error) : self;
        }
        objc_setAssociatedObject(self, TritonFakeDeviceKey, device, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        return self;
    });

    SEL classInputSel = @selector(deviceInputWithDevice:error:);
    static AVCaptureDeviceInput *(*origClassInput)(id, SEL, AVCaptureDevice *, NSError **) = NULL;
    origClassInput = (void *)TritonSwizzleClassMethod([AVCaptureDeviceInput class], classInputSel, ^AVCaptureDeviceInput *(id self, AVCaptureDevice *device, NSError **error) {
        if (!TritonIsFakeDevice(device)) {
            return origClassInput ? origClassInput(self, classInputSel, device, error) : nil;
        }
        return [[AVCaptureDeviceInput alloc] initWithDevice:device error:error];
    });

    SEL inputDeviceSel = @selector(device);
    static AVCaptureDevice *(*origInputDevice)(id, SEL) = NULL;
    origInputDevice = (void *)TritonSwizzleInstanceMethod([AVCaptureDeviceInput class], inputDeviceSel, ^AVCaptureDevice *(AVCaptureDeviceInput *self) {
        AVCaptureDevice *device = objc_getAssociatedObject(self, TritonFakeDeviceKey);
        return device ?: (origInputDevice ? origInputDevice(self, inputDeviceSel) : nil);
    });

    SEL canAddInputSel = @selector(canAddInput:);
    static BOOL (*origCanAddInput)(id, SEL, AVCaptureInput *) = NULL;
    origCanAddInput = (void *)TritonSwizzleInstanceMethod([AVCaptureSession class], canAddInputSel, ^BOOL(AVCaptureSession *self, AVCaptureInput *input) {
        if (TritonInputUsesFakeDevice(input)) {
            return YES;
        }
        return origCanAddInput ? origCanAddInput(self, canAddInputSel, input) : YES;
    });

    SEL addInputSel = @selector(addInput:);
    static void (*origAddInput)(id, SEL, AVCaptureInput *) = NULL;
    origAddInput = (void *)TritonSwizzleInstanceMethod([AVCaptureSession class], addInputSel, ^(AVCaptureSession *self, AVCaptureInput *input) {
        if (TritonInputUsesFakeDevice(input)) {
            [TritonAssociatedArray(self, TritonSessionInputsKey) addObject:input];
            return;
        }
        if (origAddInput) {
            origAddInput(self, addInputSel, input);
        }
    });

    SEL canAddOutputSel = @selector(canAddOutput:);
    static BOOL (*origCanAddOutput)(id, SEL, AVCaptureOutput *) = NULL;
    origCanAddOutput = (void *)TritonSwizzleInstanceMethod([AVCaptureSession class], canAddOutputSel, ^BOOL(AVCaptureSession *self, AVCaptureOutput *output) {
        NSArray *inputs = objc_getAssociatedObject(self, TritonSessionInputsKey);
        if (inputs.count > 0) {
            return YES;
        }
        return origCanAddOutput ? origCanAddOutput(self, canAddOutputSel, output) : YES;
    });

    SEL addOutputSel = @selector(addOutput:);
    static void (*origAddOutput)(id, SEL, AVCaptureOutput *) = NULL;
    origAddOutput = (void *)TritonSwizzleInstanceMethod([AVCaptureSession class], addOutputSel, ^(AVCaptureSession *self, AVCaptureOutput *output) {
        NSArray *inputs = objc_getAssociatedObject(self, TritonSessionInputsKey);
        if (inputs.count > 0) {
            [TritonAssociatedArray(self, TritonSessionOutputsKey) addObject:output];
            objc_setAssociatedObject(output, TritonOutputSessionKey, self, OBJC_ASSOCIATION_ASSIGN);
            return;
        }
        if (origAddOutput) {
            origAddOutput(self, addOutputSel, output);
        }
    });

    SEL inputsSel = @selector(inputs);
    static NSArray *(*origInputs)(id, SEL) = NULL;
    origInputs = (void *)TritonSwizzleInstanceMethod([AVCaptureSession class], inputsSel, ^NSArray *(AVCaptureSession *self) {
        NSArray *inputs = objc_getAssociatedObject(self, TritonSessionInputsKey);
        return inputs ?: (origInputs ? origInputs(self, inputsSel) : @[]);
    });

    SEL outputsSel = @selector(outputs);
    static NSArray *(*origOutputs)(id, SEL) = NULL;
    origOutputs = (void *)TritonSwizzleInstanceMethod([AVCaptureSession class], outputsSel, ^NSArray *(AVCaptureSession *self) {
        NSArray *outputs = objc_getAssociatedObject(self, TritonSessionOutputsKey);
        return outputs ?: (origOutputs ? origOutputs(self, outputsSel) : @[]);
    });

    SEL setDelegateSel = @selector(setSampleBufferDelegate:queue:);
    static void (*origSetDelegate)(id, SEL, id, dispatch_queue_t) = NULL;
    origSetDelegate = (void *)TritonSwizzleInstanceMethod([AVCaptureVideoDataOutput class], setDelegateSel, ^(AVCaptureVideoDataOutput *self, id<AVCaptureVideoDataOutputSampleBufferDelegate> delegate, dispatch_queue_t queue) {
        if (origSetDelegate) {
            origSetDelegate(self, setDelegateSel, delegate, queue);
        }
        @synchronized(gSampleDelegates) {
            [gSampleDelegates filterUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(TritonSampleDelegateEntry *entry, NSDictionary *bindings) {
                return entry.output != self && entry.delegate != nil;
            }]];
            if (delegate != nil) {
                TritonSampleDelegateEntry *entry = [TritonSampleDelegateEntry new];
                entry.delegate = delegate;
                entry.queue = queue ?: dispatch_get_main_queue();
                entry.output = self;
                [gSampleDelegates addObject:entry];
            }
        }
    });

    SEL previewInitSel = @selector(initWithSession:);
    static id (*origPreviewInit)(id, SEL, AVCaptureSession *) = NULL;
    origPreviewInit = (void *)TritonSwizzleInstanceMethod([AVCaptureVideoPreviewLayer class], previewInitSel, ^id(AVCaptureVideoPreviewLayer *self, AVCaptureSession *session) {
        NSArray *inputs = objc_getAssociatedObject(session, TritonSessionInputsKey);
        if (inputs.count == 0) {
            return origPreviewInit ? origPreviewInit(self, previewInitSel, session) : [self init];
        }
        AVCaptureVideoPreviewLayer *initialized = [self init];
        AVCaptureVideoPreviewLayer *layer = initialized ?: self;
        objc_setAssociatedObject(layer, TritonPreviewSessionKey, session, OBJC_ASSOCIATION_ASSIGN);
        @synchronized(gPreviewLayers) {
            [gPreviewLayers addObject:layer];
        }
        (void)TritonPreviewOverlay(layer);
        return layer;
    });

    SEL previewLayerSel = @selector(layerWithSession:);
    static AVCaptureVideoPreviewLayer *(*origPreviewLayer)(id, SEL, AVCaptureSession *) = NULL;
    origPreviewLayer = (void *)TritonSwizzleClassMethod([AVCaptureVideoPreviewLayer class], previewLayerSel, ^AVCaptureVideoPreviewLayer *(id self, AVCaptureSession *session) {
        NSArray *inputs = objc_getAssociatedObject(session, TritonSessionInputsKey);
        if (inputs.count == 0 && origPreviewLayer) {
            return origPreviewLayer(self, previewLayerSel, session);
        }
        return [[AVCaptureVideoPreviewLayer alloc] initWithSession:session];
    });

    SEL previewSetFrameSel = @selector(setFrame:);
    static void (*origPreviewSetFrame)(id, SEL, CGRect) = NULL;
    origPreviewSetFrame = (void *)TritonSwizzleInstanceMethod([AVCaptureVideoPreviewLayer class], previewSetFrameSel, ^(AVCaptureVideoPreviewLayer *self, CGRect frame) {
        if (origPreviewSetFrame) {
            origPreviewSetFrame(self, previewSetFrameSel, frame);
        }
        CALayer *overlay = objc_getAssociatedObject(self, TritonPreviewOverlayKey);
        if (overlay != nil) {
            overlay.frame = self.bounds;
        }
    });

    SEL previewSetBoundsSel = @selector(setBounds:);
    static void (*origPreviewSetBounds)(id, SEL, CGRect) = NULL;
    origPreviewSetBounds = (void *)TritonSwizzleInstanceMethod([AVCaptureVideoPreviewLayer class], previewSetBoundsSel, ^(AVCaptureVideoPreviewLayer *self, CGRect bounds) {
        if (origPreviewSetBounds) {
            origPreviewSetBounds(self, previewSetBoundsSel, bounds);
        }
        CALayer *overlay = objc_getAssociatedObject(self, TritonPreviewOverlayKey);
        if (overlay != nil) {
            overlay.frame = self.bounds;
        }
    });

    SEL startRunningSel = @selector(startRunning);
    static void (*origStartRunning)(id, SEL) = NULL;
    origStartRunning = (void *)TritonSwizzleInstanceMethod([AVCaptureSession class], startRunningSel, ^(AVCaptureSession *self) {
        NSArray *inputs = objc_getAssociatedObject(self, TritonSessionInputsKey);
        if (inputs.count > 0) {
            objc_setAssociatedObject(self, TritonSessionRunningKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            return;
        }
        if (origStartRunning) {
            origStartRunning(self, startRunningSel);
        }
    });

    SEL stopRunningSel = @selector(stopRunning);
    static void (*origStopRunning)(id, SEL) = NULL;
    origStopRunning = (void *)TritonSwizzleInstanceMethod([AVCaptureSession class], stopRunningSel, ^(AVCaptureSession *self) {
        NSArray *inputs = objc_getAssociatedObject(self, TritonSessionInputsKey);
        if (inputs.count > 0) {
            objc_setAssociatedObject(self, TritonSessionRunningKey, @NO, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            return;
        }
        if (origStopRunning) {
            origStopRunning(self, stopRunningSel);
        }
    });

    SEL isRunningSel = @selector(isRunning);
    static BOOL (*origIsRunning)(id, SEL) = NULL;
    origIsRunning = (void *)TritonSwizzleInstanceMethod([AVCaptureSession class], isRunningSel, ^BOOL(AVCaptureSession *self) {
        NSNumber *running = objc_getAssociatedObject(self, TritonSessionRunningKey);
        return running != nil ? running.boolValue : (origIsRunning ? origIsRunning(self, isRunningSel) : NO);
    });
}

__attribute__((constructor))
static void TritonSimCameraHookStart(void) {
    TritonInstallAVFoundationHooks();
    const char *socketPath = getenv("TRITON_SIM_CAMERA_SOCKET");
    if (socketPath == NULL || strlen(socketPath) == 0) {
        return;
    }
    NSString *path = [NSString stringWithUTF8String:socketPath];
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
        TritonFrameLoop(path);
    });
}
