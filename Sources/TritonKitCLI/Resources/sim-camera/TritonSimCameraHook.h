#import <Foundation/Foundation.h>

static const uint32_t TritonSimCameraMagic = 0x434D4953;
static const uint32_t TritonSimCameraProtocolVersion = 2;
static const uint32_t TritonSimCameraPixelFormatBGRA = 0x41524742;

typedef struct __attribute__((packed)) {
    uint32_t magic;
    uint32_t version;
    uint32_t width;
    uint32_t height;
    uint32_t bytesPerRow;
    uint32_t pixelFormat;
    uint64_t hostTimeNs;
    uint32_t payloadLen;
    uint32_t qrPayloadLen;
    uint32_t cameraSlot;
    uint32_t reserved0;
} TritonSimCameraFrameHeader;
