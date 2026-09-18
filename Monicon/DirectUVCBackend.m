#import "DirectUVCBackend.h"
#include <libuvc/libuvc.h>

@interface MNDirectUVCBackend () {
    uvc_context_t *_context;
    uvc_device_t *_device;
    uvc_device_handle_t *_handle;
    uvc_stream_ctrl_t _streamControl;
    dispatch_queue_t _queue;
    BOOL _running;
}
@end

static void MNUVCFrameCallback(uvc_frame_t *frame, void *userPointer);

@implementation MNDirectUVCBackend

- (instancetype)init {
    self = [super init];
    if (self) {
        _queue = dispatch_queue_create("com.monicon.direct-uvc", DISPATCH_QUEUE_SERIAL);
    }
    return self;
}

- (void)startWithWidth:(NSUInteger)width height:(NSUInteger)height fps:(NSUInteger)fps {
    dispatch_async(_queue, ^{
        uvc_error_t result = uvc_init(&self->_context, NULL);
        if (result < 0) {
            [self fail:[NSString stringWithFormat:@"uvc_init failed: %s (%d)", uvc_strerror(result), result]];
            return;
        }

        result = uvc_find_device(self->_context, &self->_device, 0, 0, NULL);
        if (result < 0) {
            [self fail:[NSString stringWithFormat:@"uvc_find_device failed: %s (%d)", uvc_strerror(result), result]];
            return;
        }

        result = uvc_open(self->_device, &self->_handle);
        if (result < 0) {
            [self fail:[NSString stringWithFormat:@"uvc_open failed: %s (%d)", uvc_strerror(result), result]];
            return;
        }

        int requestedWidth = (int)width;
        int requestedHeight = (int)height;
        int requestedFPS = (int)fps;
        if (requestedWidth == 0 || requestedHeight == 0) {
            const uvc_format_desc_t *format = uvc_get_format_descs(self->_handle);
            while (format && !format->frame_descs) { format = format->next; }
            if (format && format->frame_descs) {
                requestedWidth = (int)format->frame_descs->wWidth;
                requestedHeight = (int)format->frame_descs->wHeight;
            }
        }
        if (requestedFPS == 0) { requestedFPS = 60; }
        result = uvc_get_stream_ctrl_format_size(self->_handle, &self->_streamControl,
                                                  UVC_FRAME_FORMAT_YUYV,
                                                  requestedWidth, requestedHeight, requestedFPS);
        if (result < 0) {
            result = uvc_get_stream_ctrl_format_size(self->_handle, &self->_streamControl,
                                                      UVC_FRAME_FORMAT_MJPEG,
                                                      requestedWidth, requestedHeight, requestedFPS);
        }
        if (result < 0) {
            [self fail:[NSString stringWithFormat:@"no matching UVC mode: %s (%d)", uvc_strerror(result), result]];
            return;
        }

        result = uvc_start_streaming(self->_handle, &self->_streamControl, MNUVCFrameCallback, (__bridge void *)self, 0);
        if (result < 0) {
            [self fail:[NSString stringWithFormat:@"uvc_start_streaming failed: %s (%d)", uvc_strerror(result), result]];
            return;
        }

        self->_running = YES;
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.delegate uvcBackendDidStartWithWidth:(NSUInteger)requestedWidth height:(NSUInteger)requestedHeight fps:(NSUInteger)requestedFPS];
        });
    });
}

- (void)stop {
    dispatch_async(_queue, ^{
        if (self->_handle && self->_running) {
            uvc_stop_streaming(self->_handle);
        }
        self->_running = NO;
        if (self->_handle) {
            uvc_close(self->_handle);
            self->_handle = NULL;
        }
        if (self->_device) {
            uvc_unref_device(self->_device);
            self->_device = NULL;
        }
        if (self->_context) {
            uvc_exit(self->_context);
            self->_context = NULL;
        }
    });
}

- (void)fail:(NSString *)message {
    [self stop];
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.delegate uvcBackendDidFail:message];
    });
}

static void MNUVCFrameCallback(uvc_frame_t *frame, void *userPointer) {
    MNDirectUVCBackend *backend = (__bridge MNDirectUVCBackend *)userPointer;
    if (!backend->_running || !frame) return;

    uvc_frame_t *rgb = uvc_allocate_frame(frame->width * frame->height * 3);
    if (!rgb) return;

    uvc_error_t result = uvc_any2rgb(frame, rgb);
    if (result == UVC_SUCCESS) {
        const NSUInteger outputWidth = frame->width;
        const NSUInteger outputHeight = frame->height;
        const NSUInteger outputBytes = rgb->data_bytes;
        NSData *data = [NSData dataWithBytes:rgb->data length:outputBytes];
        dispatch_async(dispatch_get_main_queue(), ^{
            [backend.delegate uvcBackendDidReceiveRGB:data width:outputWidth height:outputHeight];
        });
    }
    uvc_free_frame(rgb);
}

@end
