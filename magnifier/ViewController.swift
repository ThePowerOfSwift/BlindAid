//
//  ViewController.swift
//  magnifier
//
//  Created by mulligans on 08/03/2015.
//  Copyright (c) 2015 mulligans. All rights reserved.
//

import Cocoa
import AVFoundation
import AppKit
import Foundation

@objc protocol CameraSessionControllerDelegate {
    optional func cameraSessionDidOutputSampleBuffer(sampleBuffer: CMSampleBuffer!)
}

class ViewController: NSViewController, AVCaptureVideoDataOutputSampleBufferDelegate{
    
    var ocrInputTextFileName : NSString = "ocr-input.txt"
    var synth = NSSpeechSynthesizer.init()
    
    var statusBar = NSStatusBar.systemStatusBar()
    var statusItem : NSStatusItem = NSStatusItem()
    var menuItem : NSMenuItem = NSMenuItem()
    var mainMenu = NSMenu()
    
    let captureSession = AVCaptureSession()
    var previewLayer : AVCaptureVideoPreviewLayer?
    
    // If we find a device we'll store it here for later use
    var captureDevice : AVCaptureDevice?
    var sessionDelegate: CameraSessionControllerDelegate?
    var myCounter = 0;
    var filterOn : Bool  = false
    var scrollViewMag:CGFloat = 1.0;
    @IBOutlet var scrollView: NSScrollView!
    var previewView: NSImageView = NSImageView()
    var clickCount = 0
    var videoDeviceArray = [AVCaptureDevice?]()
    var videoCaptureDeviceInputArray = [AVCaptureDeviceInput]()
    var requestService = AsyncHTTPSRequest()
    
    
    var err : NSError? = nil
    

    @IBAction func myPressGuesture(sender: NSPressGestureRecognizer) {
        if (sender.state == NSGestureRecognizerState.Ended){
            filterOn = !filterOn
        }
    }
    
    
    @IBAction func focusClick(sender: NSClickGestureRecognizer) {
        var lockErr : NSErrorPointer = nil
        /* if (sender.state == NSGestureRecognizerState.Ended){
        println("single click has been recieved")
        if (!videoCaptureDeviceInputArray[clickCount].device.focusPointOfInterestSupported)
        {
        println("focusPointOfInterestSupported")
        videoCaptureDeviceInputArray[clickCount].device.lockForConfiguration(lockErr)
        videoCaptureDeviceInputArray[clickCount].device.lockForConfiguration(lockErr)
        videoCaptureDeviceInputArray[clickCount].device.focusMode = AVCaptureFocusMode.Locked
        //videoCaptureDeviceInputArray[clickCount].device.focusPointOfInterest = sender.locationInView(previewView)
        println(sender.locationInView(previewView))
        videoCaptureDeviceInputArray[clickCount].device.unlockForConfiguration()
        }
        } */
    }
    
    @IBAction func clickRecogniser(sender: NSClickGestureRecognizer) {
        if (sender.state == NSGestureRecognizerState.Ended){
            println("double click has been recieved")
            //captureSession.stopRunning()
            captureSession.removeInput(videoCaptureDeviceInputArray[clickCount%videoCaptureDeviceInputArray.count])
            captureSession.sessionPreset = AVCaptureSessionPresetHigh
            
            if err != nil {
                println("error: \(err?.localizedDescription)")
            }
            println("mouse down press recieved")
            clickCount++
            // println("the click count is \(clickCount % videoDeviceArray.count)")
            //captureDevice = videoDeviceArray[clickCount % videoDeviceArray.count]
            //println("device count is \(videoDeviceArray.count)")
            println("new devices is \(captureDevice?.description)")
            captureSession.commitConfiguration()
            beginSession()
            requestService.getRequest("www.google.com")
        }
    }
    
    
    /**
      *  Generate an image of what is visible in the
      *  scrollView window, and nothing else
      *  Kevin Moroney 22/4/2015
      **/
    func  imageWithSubviews() -> NSImage
    {
        // Create size for final image
        var mySize = scrollView.bounds.size;
        var imgSize:NSSize = NSMakeSize(mySize.width, mySize.height );
    
        // Get a bitmap representation of the scrollview contents
        var bir:NSBitmapImageRep = scrollView.bitmapImageRepForCachingDisplayInRect(scrollView.bounds)!
        scrollView.cacheDisplayInRect(scrollView.bounds, toBitmapImageRep: bir)
        
        // Create the image
        var image:NSImage = NSImage(size: imgSize)
        
        image.addRepresentation(bir)
        return image;
    }
    
    /**
      *  Perform an OCR operation and read the
      *  processed text back to the User
      *  Kevin Moroney 22/4/2015
      **/
    @IBAction func performOCR(sender: NSRotationGestureRecognizer) {
        println("performOCR rotation gesture has been recieved")
        // Check that the gesture has ended so as not
        // to perform the same operation multiple times
        if (sender.state == NSGestureRecognizerState.Ended){
            // User has finished gesture, perform OCR
            // First verify that a camera is present
            if captureDevice != nil {
                
                // Caputre an image from the device and save it to the disk
                // this should be moved to internal code for any prod version
                var image : NSImage
                image = imageWithSubviews()
                
                // define our path and image file name
                var ocrFilePath : NSString = ""
                var fileName:NSString = "ocr.png"
                
                var pngFileName = ocrFilePath.stringByAppendingPathComponent(fileName as String)
                
                // Get a TIFF representation of the image
                let myImageData = image.TIFFRepresentation!
                
                // Save the file to the disk
                let fileManager = NSFileManager.defaultManager()
                fileManager.createFileAtPath(pngFileName, contents: myImageData, attributes: nil)
                
                // Run the tesseract OCR on the generated image
                shell("/opt/local/bin/tesseract", arguments: ["ocr.png", "output"])
                
                // Read the text from the output file using syntesized speech
                readOCRText()
                
            } else {
                // No camera is present - Danger Will Robinson - Abort!
                println("No capture device present!!!")
            }
        }
    }
    
    /**
      *  Read the text from a file using a
      *  speech synthesizer
      *  Kevin Moroney 22/4/2015
      **/
    func readOCRText(){
        println("Starting Speaking...")
        
        // Read in the text to read from the file
        let file = "output.txt"
        let text = String(contentsOfFile: file, encoding: NSUTF8StringEncoding, error: nil)
        
        // Print the text read to the console
        print(text)
        
        // Stop any speech that may be in progress
        synth.stopSpeaking()
        // Read the text back to the user
        synth.startSpeakingString(text)
    
    }
    
    /**
      *  Run a shell script from a swift program
      *  Kevin Moroney 22/4/2015
      **/
    func shell(launchPath: String, arguments: [AnyObject]) -> String
    {
        // Define a task with path and args
        let task = NSTask()
        task.launchPath = launchPath
        task.arguments = arguments
        
        // launch the task and pipe the output
        let pipe = NSPipe()
        task.standardOutput = pipe
        task.launch()
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output: String = NSString(data: data, encoding: NSUTF8StringEncoding)! as String
        
        return output
    }
    
    
    //var pressGesture: NSPressGestureRecognizer = NSPressGestureRecognizer()
    
    override func viewDidAppear() {
        super.viewDidAppear()
        captureSession.sessionPreset = AVCaptureSessionPresetHigh// AVCaptureSessionPresetMedium  //
        self.scrollView.allowsMagnification = true
        self.scrollView.minMagnification = 1
        self.scrollView.maxMagnification = 16
        
        //pressGesture.target = self
        let devices = AVCaptureDevice.devices()
        
        // Loop through all the capture devices on this phone
        for device in devices {
            // Make sure this particular device supports video
            if (device.hasMediaType(AVMediaTypeVideo)) {
                // Finally check the position and confirm we've got the back camera
                if(device.description.lowercaseString.rangeOfString("face") != nil) {
                    //captureDevice = device as? AVCaptureDevice
                    videoDeviceArray.append(device as? AVCaptureDevice)
                    videoCaptureDeviceInputArray.append(AVCaptureDeviceInput(device: device as? AVCaptureDevice, error: &err))
                }
            }
        }
        captureDevice = videoDeviceArray.first!
        if captureDevice != nil {
            println("Capture device found")
            beginSession()
        }
    }
    
    override func viewWillLayout() {
        // When we change the size of the window we want the image captured to resize with it.
        self.scrollView.frame = self.view.bounds
        previewView.frame = self.view.bounds
    }
    
    override var representedObject: AnyObject? {
        didSet {
            // Update the view, if already loaded.
        }
    }
    
    func beginSession() {
        
        captureSession.addInput(videoCaptureDeviceInputArray[clickCount%videoCaptureDeviceInputArray.count])
        if err != nil {
            println("error: \(err?.localizedDescription)")
        }
        //println(CIFilter.filterNamesInCategories(nil))
        
        var myVideoOutput = AVCaptureVideoDataOutput()
        println(myVideoOutput.debugDescription)
        myVideoOutput.alwaysDiscardsLateVideoFrames = true
        var videoDataOutputQueue = dispatch_queue_create("Video_Data_Output_Queue", DISPATCH_QUEUE_SERIAL)
        myVideoOutput.setSampleBufferDelegate(self, queue: videoDataOutputQueue)
        
        captureSession.addOutput(myVideoOutput)
        
        myVideoOutput.connectionWithMediaType(AVMediaTypeVideo)
        
        scrollView.frame = self.view.frame
        //previewLayer?.frame = self.view.bounds
        //previewLayer?.videoGravity = AVLayerVideoGravityResizeAspectFill;
        //previewView.frame = previewLayer!.frame
        
        scrollView.hasHorizontalScroller = true
        scrollView.hasVerticalScroller = true
        
        //previewView.wantsLayer = true
        //previewView.layer?.addSublayer(previewLayer)
        //previewView.layer?.needsDisplayOnBoundsChange = true
        
        scrollView.documentView = previewView
        scrollView.display()
        captureSession.startRunning()
    }
    
    
    func captureOutput(captureOutput: AVCaptureOutput!, didOutputSampleBuffer sampleBuffer: CMSampleBuffer!, fromConnection connection: AVCaptureConnection!) {
        
        /*if (connection.supportsVideoOrientation){
        //connection.videoOrientation = AVCaptureVideoOrientation.PortraitUpsideDown
        connection.videoOrientation = AVCaptureVideoOrientation.Portrait
        }
        if (connection.supportsVideoMirroring) {
        //connection.videoMirrored = true
        connection.videoMirrored = false
        } */
        
        var myOutputCIImage : CIImage
        var myOutputRect : CGRect
        
        sessionDelegate?.cameraSessionDidOutputSampleBuffer?(sampleBuffer)
        var ref : CVImageBufferRef = CMSampleBufferGetImageBuffer(sampleBuffer)
        //ref. takeUnretainedValue()
        var myCIImage = CIImage(CVImageBuffer: ref)
        
        var mySubView  = scrollView.convertRect(scrollView.bounds, toView: previewView)
        
        myCIImage.imageByCroppingToRect(mySubView)
        
        //scrollView.convertRect(self.scrollView.bounds, fromView: self.scrollView.documentView as NSView)
        
        // println("The scroll view height is \(self.scrollView.frame.height) while the image height is \(mySubView.height)")
        
        //myCIImage = myCIImage.imageByCroppingToRect(NSRectToCGRect(self.scrollView.frame))
        //myCIImage.imageByCroppingToRect(CGRect()) // ACTION: Look to crop the image being displayed to the visible area to improve performance. May need to position this also to ensure that previewView frame size remains the same for scrolling functionality to be maintained.
        
        var myCIContext = CIContext()
        
        
        //myCIImage.layer(previewLayer!, shouldInheritContentsScale: 1, fromWindow: self.view.window!)
        var myFilter = CIFilter(name: "CIColorInvert")
        
        //var myFilter = CIFilter(name: "CIEdges")
        myFilter.setValue(myCIImage, forKey: kCIInputImageKey)
        // myFilter.setValue(3, forKey: kCIInputRadiusKey)
        // myFilter.setValue(3.0, forKey: kCIInputIntensityKey)
        var mySecondFilter = CIFilter(name:"CIPhotoEffectMono")
        mySecondFilter.setValue(myFilter.outputImage, forKey: kCIInputImageKey)
        
        if (filterOn) {
            myOutputCIImage = mySecondFilter.outputImage;
        } else {
            myOutputCIImage = myCIImage;
        }
        myOutputRect  = myOutputCIImage.extent()
        
        var myCGImage : CGImage  = myCIContext.createCGImage(myOutputCIImage, fromRect: myOutputRect)
        
        var myNSImage = NSImage(CGImage: myCGImage, size: previewView.frame.size)
        dispatch_sync(dispatch_get_main_queue()){
            self.previewView.image = myNSImage
        }
    }
}
