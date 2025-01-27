#import "UVCCameraControl.h"


const uvc_controls_t uvc_controls = {
    .autoExposure = {
        .unit = UVC_INPUT_TERMINAL_ID,
        .selector = 0x02,
        .size = 1,
    },
    .exposure = {
        .unit = UVC_INPUT_TERMINAL_ID,
        .selector = 0x04,
        .size = 4,
    },
    .brightness = {
        .unit = UVC_PROCESSING_UNIT_ID,
        .selector = 0x02,
        .size = 4,
    },
    .contrast = {
        .unit = UVC_PROCESSING_UNIT_ID,
        .selector = 0x03,
        .size = 2,
    },
    .gain = {
        .unit = UVC_PROCESSING_UNIT_ID,
        .selector = 0x04,
        .size = 2,
    },
    .saturation = {
        .unit = UVC_PROCESSING_UNIT_ID,
        .selector = 0x07,
        .size = 2,
    },
    .sharpness = {
        .unit = UVC_PROCESSING_UNIT_ID,
        .selector = 0x08,
        .size = 2,
    },
    .whiteBalance = {
        .unit = UVC_PROCESSING_UNIT_ID,
        .selector = 0x0A,
        .size = 2,
    },
    .autoWhiteBalance = {
        .unit = UVC_PROCESSING_UNIT_ID,
        .selector = 0x0B,
        .size = 1,
    },
};


@implementation UVCCameraControl {
    IOUSBInterfaceInterface190 **m_interface;
    NSArray<NSNumber *> *m_discreteExposureValues;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        // Allegedly specific to the Microsoft LifeCam sensor
        m_discreteExposureValues = @[@1, @2, @5, @10, @20, @39, @78, @156, @312, @625, @1250, @2500, @5000, @10000];
    }
    return self;
}

- (instancetype)initWithLocationID:(UInt32)locationID {
    self = [self init];
    if (self) {
        m_interface = NULL;

        // Find All USB Devices, get their locationId and check if it matches the requested one
        CFMutableDictionaryRef matchingDict = IOServiceMatching(kIOUSBDeviceClassName);
        io_iterator_t serviceIterator;
        IOServiceGetMatchingServices(kIOMasterPortDefault, matchingDict, &serviceIterator);

        io_service_t camera;
        while ((camera = IOIteratorNext(serviceIterator))) {
            // Get DeviceInterface
            IOUSBDeviceInterface **deviceInterface = NULL;
            IOCFPlugInInterface **plugInInterface = NULL;
            SInt32 score;
            kern_return_t kr = IOCreatePlugInInterfaceForService(camera, kIOUSBDeviceUserClientTypeID, kIOCFPlugInInterfaceID, &plugInInterface, &score);
            if ((kIOReturnSuccess != kr) || !plugInInterface) {
                NSLog(@"CameraControl Error: IOCreatePlugInInterfaceForService returned 0x%08x.", kr);
                continue;
            }

            HRESULT res = (*plugInInterface)->QueryInterface(plugInInterface, CFUUIDGetUUIDBytes(kIOUSBDeviceInterfaceID), (LPVOID *)&deviceInterface);
            (*plugInInterface)->Release(plugInInterface);
            if (res || deviceInterface == NULL) {
                NSLog(@"CameraControl Error: QueryInterface returned %d.\n", (int)res);
                continue;
            }

            UInt32 currentLocationID = 0;
            (*deviceInterface)->GetLocationID(deviceInterface, &currentLocationID);

            if (currentLocationID == locationID) {
                // Yep, this is the USB Device that was requested!
                m_interface = [self getControlInterfaceWithDeviceInterface:deviceInterface];
                return self;
            }
        } // end while
    }
    return self;
}

- (instancetype)initWithVendorID:(int)vendorID productID:(int)productID {
    self = [self init];
    if (self) {
        m_interface = NULL;

        // Find USB Device
        CFMutableDictionaryRef matchingDict = IOServiceMatching(kIOUSBDeviceClassName);
        CFNumberRef numberRef;

        numberRef = CFNumberCreate(kCFAllocatorDefault, kCFNumberSInt32Type, &vendorID);
        CFDictionarySetValue(matchingDict, CFSTR(kUSBVendorID), numberRef);
        CFRelease(numberRef);

        numberRef = CFNumberCreate(kCFAllocatorDefault, kCFNumberSInt32Type, &productID);
        CFDictionarySetValue(matchingDict, CFSTR(kUSBProductID), numberRef);
        CFRelease(numberRef);
        io_service_t camera = IOServiceGetMatchingService(kIOMasterPortDefault, matchingDict);

        // Get DeviceInterface
        IOUSBDeviceInterface **deviceInterface = NULL;
        IOCFPlugInInterface **plugInInterface = NULL;
        SInt32 score;
        kern_return_t kr = IOCreatePlugInInterfaceForService(camera, kIOUSBDeviceUserClientTypeID, kIOCFPlugInInterfaceID, &plugInInterface, &score);
        if ((kIOReturnSuccess != kr) || !plugInInterface) {
            NSLog(@"CameraControl Error: IOCreatePlugInInterfaceForService returned 0x%08x.", kr);
            return self;
        }

        HRESULT res = (*plugInInterface)->QueryInterface(plugInInterface, CFUUIDGetUUIDBytes(kIOUSBDeviceInterfaceID), (LPVOID *)&deviceInterface);
        (*plugInInterface)->Release(plugInInterface);
        if (res || deviceInterface == NULL) {
            NSLog(@"CameraControl Error: QueryInterface returned %d.\n", (int)res);
            return self;
        }

        m_interface = [self getControlInterfaceWithDeviceInterface:deviceInterface];
    }
    return self;
}

- (IOUSBInterfaceInterface190 **)getControlInterfaceWithDeviceInterface:(IOUSBDeviceInterface **)deviceInterface {
    IOUSBInterfaceInterface190 **controlInterface;

    io_iterator_t interfaceIterator;
    IOUSBFindInterfaceRequest interfaceRequest;
    interfaceRequest.bInterfaceClass = UVC_CONTROL_INTERFACE_CLASS;
    interfaceRequest.bInterfaceSubClass = UVC_CONTROL_INTERFACE_SUBCLASS;
    interfaceRequest.bInterfaceProtocol = kIOUSBFindInterfaceDontCare;
    interfaceRequest.bAlternateSetting = kIOUSBFindInterfaceDontCare;

    IOReturn success = (*deviceInterface)->CreateInterfaceIterator(deviceInterface, &interfaceRequest, &interfaceIterator);
    if (success != kIOReturnSuccess) {
        return NULL;
    }

    io_service_t usbInterface;
    HRESULT result;

    if ((usbInterface = IOIteratorNext(interfaceIterator))) {
        IOCFPlugInInterface **plugInInterface = NULL;

        // Create an intermediate plug-in
        SInt32 score;
        IOCreatePlugInInterfaceForService(usbInterface, kIOUSBInterfaceUserClientTypeID, kIOCFPlugInInterfaceID, &plugInInterface, &score);

        // Release the usbInterface object after getting the plug-in
        kern_return_t kr = IOObjectRelease(usbInterface);
        if ((kr != kIOReturnSuccess) || !plugInInterface) {
            NSLog(@"CameraControl Error: Unable to create a plug-in (%08x)\n", kr);
            return NULL;
        }

        // Now create the device interface for the interface
        result = (*plugInInterface)->QueryInterface(plugInInterface, CFUUIDGetUUIDBytes(kIOUSBInterfaceInterfaceID), (LPVOID *)&controlInterface);

        // No longer need the intermediate plug-in
        (*plugInInterface)->Release(plugInInterface);

        if (result || !controlInterface) {
            NSLog(@"CameraControl Error: Couldn’t create a device interface for the interface (%08x)", (int)result);
            return NULL;
        }

        return controlInterface;
    }

    return NULL;
}

- (void)dealloc {
    if (m_interface) {
        (*m_interface)->USBInterfaceClose(m_interface);
        (*m_interface)->Release(m_interface);
    }
}

- (BOOL)sendControlRequest:(IOUSBDevRequest)controlRequest {
    if( !m_interface ){
        NSLog( @"CameraControl Error: No interface to send request" );
        return NO;
    }
    
    kern_return_t kr = (*m_interface)->ControlRequest( m_interface, 0, &controlRequest );
    if( kr != kIOReturnSuccess ) {
        NSLog( @"CameraControl Error: Control request failed: %08x", kr );
        return NO;
    }
    
    return YES;
}

- (BOOL)setData:(long)value withLength:(int)length forSelector:(int)selector at:(int)unitId {
    IOUSBDevRequest controlRequest;
    controlRequest.bmRequestType = USBmakebmRequestType( kUSBOut, kUSBClass, kUSBInterface );
    controlRequest.bRequest = UVC_SET_CUR;
    controlRequest.wValue = (selector << 8) | 0x00;
    controlRequest.wIndex = (unitId << 8) | 0x00;
    controlRequest.wLength = length;
    controlRequest.wLenDone = 0;
    controlRequest.pData = &value;
    return [self sendControlRequest:controlRequest];
}

- (long)getDataFor:(int)type withLength:(int)length fromSelector:(int)selector at:(int)unitId {
    long value = 0;
    IOUSBDevRequest controlRequest;
    controlRequest.bmRequestType = USBmakebmRequestType( kUSBIn, kUSBClass, kUSBInterface );
    controlRequest.bRequest = type;
    controlRequest.wValue = (selector << 8) | 0x00;
    controlRequest.wIndex = (unitId << 8) | 0x00;
    controlRequest.wLength = length;
    controlRequest.wLenDone = 0;
    controlRequest.pData = &value;
    BOOL success = [self sendControlRequest:controlRequest];
    return ( success ? value : 0 );
}

// Get Range (min, max)
- (uvc_range_t)getRangeForControl:(const uvc_control_info_t *)control {
    uvc_range_t range = { 0, 0 };
    range.min = [self getDataFor:UVC_GET_MIN withLength:control->size fromSelector:control->selector at:control->unit];
    range.max = [self getDataFor:UVC_GET_MAX withLength:control->size fromSelector:control->selector at:control->unit];
    return range;
}

// Used to de-/normalize values
- (float)mapValue:(float)value fromMin:(float)fromMin max:(float)fromMax toMin:(float)toMin max:(float)toMax {
    return toMin + (toMax - toMin) * ((value - fromMin) / (fromMax - fromMin));
}

// Get a normalized value
- (float)getValueForControl:(const uvc_control_info_t *)control {
    // TODO: Cache the range somewhere?
    uvc_range_t range = [self getRangeForControl:control];

    long intval = [self getDataFor:UVC_GET_CUR withLength:control->size fromSelector:control->selector at:control->unit];
    return [self mapValue:intval fromMin:range.min max:range.max toMin:0 max:1];
}

// Set a normalized value
- (BOOL)setValue:(float)value forControl:(const uvc_control_info_t *)control {
    // TODO: Cache the range somewhere?
    uvc_range_t range = [self getRangeForControl:control];

    int intval = [self mapValue:value fromMin:0 max:1 toMin:range.min max:range.max];
    return [self setData:intval withLength:control->size forSelector:control->selector at:control->unit];
}


// ================================================================

// Set/Get the actual values for the camera
- (NSUInteger)numExposureValues {
    return [m_discreteExposureValues count];
}

- (BOOL)setAutoExposure:(BOOL)enabled {
    int intval = (enabled ? 0x08 : 0x01); // "auto exposure modes" ar NOT boolean (on|off) as it seems
    return [self setData:intval
              withLength:uvc_controls.autoExposure.size
             forSelector:uvc_controls.autoExposure.selector
                      at:uvc_controls.autoExposure.unit];
}

- (BOOL)getAutoExposure {
    long intval = [self getDataFor:UVC_GET_CUR
                       withLength:uvc_controls.autoExposure.size
                     fromSelector:uvc_controls.autoExposure.selector
                               at:uvc_controls.autoExposure.unit];
    
    return ( intval == 0x08 ? YES : NO );
}

- (BOOL)setExposure:(float)value {
    NSUInteger exposureIndex = value * ([m_discreteExposureValues count] + 1);
    return [self setData:[m_discreteExposureValues[exposureIndex] intValue]
              withLength:uvc_controls.exposure.size
             forSelector:uvc_controls.exposure.selector
                      at:uvc_controls.exposure.unit];
}

- (float)getExposure {
    float value = [self getValueForControl:&uvc_controls.exposure];
    return 1 - value;
}

- (BOOL)setGain:(float)value {
    return [self setValue:value forControl:&uvc_controls.gain];
}

- (float)getGain {
    return [self getValueForControl:&uvc_controls.gain];
}

- (BOOL)setBrightness:(float)value {
    return [self setValue:value forControl:&uvc_controls.brightness];
}

- (float)getBrightness {
    return [self getValueForControl:&uvc_controls.brightness];
}

- (BOOL)setContrast:(float)value {
    return [self setValue:value forControl:&uvc_controls.contrast];
}

- (float)getContrast {
    return [self getValueForControl:&uvc_controls.contrast];
}

- (BOOL)setSaturation:(float)value {
    return [self setValue:value forControl:&uvc_controls.saturation];
}

- (float)getSaturation {
    return [self getValueForControl:&uvc_controls.saturation];
}

- (BOOL)setSharpness:(float)value {
    return [self setValue:value forControl:&uvc_controls.sharpness];
}

- (float)getSharpness {
    return [self getValueForControl:&uvc_controls.sharpness];
}

- (BOOL)setAutoWhiteBalance:(BOOL)enabled {
    int intval = (enabled ? 0x01 : 0x00);
    return [self setData:intval
              withLength:uvc_controls.autoWhiteBalance.size
             forSelector:uvc_controls.autoWhiteBalance.selector
                      at:uvc_controls.autoWhiteBalance.unit];
}

- (BOOL)getAutoWhiteBalance {
    long intval = [self getDataFor:UVC_GET_CUR
                       withLength:uvc_controls.autoWhiteBalance.size
                     fromSelector:uvc_controls.autoWhiteBalance.selector
                               at:uvc_controls.autoWhiteBalance.unit];
    
    return ( intval ? YES : NO );
}

- (BOOL)setWhiteBalance:(float)value {
    return [self setValue:value forControl:&uvc_controls.whiteBalance];
}

- (float)getWhiteBalance {
    return [self getValueForControl:&uvc_controls.whiteBalance];
}

@end
