#import "CameraControlAppDelegate.h"


@implementation CameraControlAppDelegate {
	AVCaptureSession *m_captureSession;
	AVCaptureDeviceDiscoverySession *m_discoverySession;
	UVCCameraControl *m_cameraControl;
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
	NSArray<AVCaptureDeviceType> *deviceTypes = @[AVCaptureDeviceTypeBuiltInWideAngleCamera, AVCaptureDeviceTypeExternalUnknown];
	m_discoverySession = [AVCaptureDeviceDiscoverySession discoverySessionWithDeviceTypes:deviceTypes
																					  mediaType:AVMediaTypeVideo
																					   position:AVCaptureDevicePositionUnspecified];

	NSArray<AVCaptureDevice *> *devices = [m_discoverySession devices];
	for (AVCaptureDevice *device in devices)
		[cameraSelectButton addItemWithTitle:[device localizedName]];

	m_captureSession = [[AVCaptureSession alloc] init];
	
	CALayer *captureViewLayer = [captureView layer];
	[captureViewLayer setBackgroundColor:CGColorGetConstantColor(kCGColorBlack)];
	AVCaptureVideoPreviewLayer *newPreviewLayer = [[AVCaptureVideoPreviewLayer alloc] initWithSession:m_captureSession];
	[newPreviewLayer setFrame:[captureViewLayer bounds]];
	[newPreviewLayer setAutoresizingMask:kCALayerWidthSizable | kCALayerHeightSizable];
	[captureViewLayer addSublayer:newPreviewLayer];

	[self setCaptureSessionToUseDevice:[devices firstObject]];

	m_cameraControl = [[UVCCameraControl alloc] initWithVendorID:0x045e productID:0x0772];
	[m_cameraControl setAutoExposure:YES];
	[m_cameraControl setAutoWhiteBalance:YES];

	[exposureSlider setNumberOfTickMarks:[m_cameraControl numExposureValues]];
	[exposureSlider setAllowsTickMarkValuesOnly:YES];
}


- (void)setCaptureSessionToUseDevice:(AVCaptureDevice *)device {
	if ([m_captureSession isRunning])
		[m_captureSession stopRunning];

	NSArray<AVCaptureDeviceInput *> *inputs = [m_captureSession inputs];
	NSUInteger inputCount = [inputs count];
	if (inputCount > 0) {

		if (inputCount > 1)
			NSLog(@"Multiple input devices for current capture session!");

		[m_captureSession removeInput:[inputs firstObject]];
	}

	[m_captureSession addInput:[AVCaptureDeviceInput deviceInputWithDevice:device error:nil]];
	[m_captureSession startRunning];
}


- (IBAction)sliderMoved:(id)sender {
	
	// Exposure Time
	if( [sender isEqualTo:exposureSlider] ) {		
		[m_cameraControl setExposure:[exposureSlider closestTickMarkValueToValue:exposureSlider.floatValue]];
	}
	
	// White Balance Temperature
	else if( [sender isEqualTo:whiteBalanceSlider] ) {
		[m_cameraControl setWhiteBalance:whiteBalanceSlider.floatValue];
	}
	
	// Gain Value
	else if( [sender isEqualTo:gainSlider] ) {
		[m_cameraControl setBrightness:gainSlider.floatValue];
	}
}


- (IBAction)selectedCameraChanged:(id)sender {
	NSString *selectedCameraName = [cameraSelectButton titleOfSelectedItem];

	NSArray<AVCaptureDevice *> *devices = [m_discoverySession devices];
	[devices enumerateObjectsUsingBlock:^(AVCaptureDevice * _Nonnull device, NSUInteger idx, BOOL * _Nonnull stop) {
		if ([[device localizedName] isEqualToString:selectedCameraName]) {
			[self setCaptureSessionToUseDevice:device];
			*stop = YES;
		}
	}];
}

- (IBAction)checkBoxChanged:(id)sender {
	
	// Auto Exposure
	if( [sender isEqualTo:autoExposureCheckBox] ) {
		if( autoExposureCheckBox.state == NSControlStateValueOn ) {
			[m_cameraControl setAutoExposure:YES];
			[exposureSlider setEnabled:NO];
		} 
		else {
			[m_cameraControl setAutoExposure:NO];
			[exposureSlider setEnabled:YES];
			[m_cameraControl setExposure:exposureSlider.floatValue];
		}
	}
	
	// Auto White Balance
	else if( [sender isEqualTo:autoWhiteBalanceCheckBox] ) {
		if( autoWhiteBalanceCheckBox.state == NSControlStateValueOn ) {
			[m_cameraControl setAutoWhiteBalance:YES];
			[whiteBalanceSlider setEnabled:NO];
		} 
		else {
			[m_cameraControl setAutoWhiteBalance:NO];
			[whiteBalanceSlider setEnabled:YES];
			[m_cameraControl setWhiteBalance:whiteBalanceSlider.floatValue];
		}
	}
}



@end

