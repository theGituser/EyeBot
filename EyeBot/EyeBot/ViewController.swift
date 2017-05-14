//
//  ViewController.swift
//  EyeBot
//
//  Created by Luis Padron on 5/12/17.
//  Copyright © 2017 com.eyebot. All rights reserved.
//

import UIKit
import AVFoundation

class ViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate {
    
    var takenPhoto:UIImage?
    
    let captureButton = UIButton(type: .custom)
    let settingsButton = UIButton(type: .custom)
    let flashButton = UIButton(type: .custom)
    
    let captureSession = AVCaptureSession()
    var previewLayer: CALayer!
    
    var captureDevice:AVCaptureDevice!
    
    var takePhoto = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        prepareCamera()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    func prepareCamera() {
        captureSession.sessionPreset = AVCaptureSessionPresetHigh
        
        if let availableDevices = AVCaptureDeviceDiscoverySession(deviceTypes: [.builtInWideAngleCamera],
                                                                  mediaType: AVMediaTypeVideo,
                                                                  position: .back).devices {
            captureDevice = availableDevices.first
            beginSession()
        }
    }
    
    func beginSession() {
        do {
            let captureDeviceInput = try AVCaptureDeviceInput(device: captureDevice)
            
            captureSession.addInput(captureDeviceInput)
        } catch {
            print(error.localizedDescription)
        }
        
        if let previewLayer = AVCaptureVideoPreviewLayer(session: captureSession) {
            self.previewLayer = previewLayer
            self.view.layer.addSublayer(self.previewLayer)
            let button = UIButton(type: .system)
            button.center = self.view.center
            self.previewLayer.frame = self.view.layer.frame
            captureSession.startRunning()
            
            let touchRecognizer = UITapGestureRecognizer(target: self,
                                                         action: #selector(actionButtonsPressed(touch:)))
            
            touchRecognizer.numberOfTapsRequired = 1
            self.view.addGestureRecognizer(touchRecognizer)

            addSettingsButton()
            addFlashButton()
            addCaptureButton()
            
            let dataOutput = AVCaptureVideoDataOutput()
            dataOutput.videoSettings = [(kCVPixelBufferPixelFormatTypeKey as NSString):NSNumber(value: kCVPixelFormatType_32BGRA)]
            
            dataOutput.alwaysDiscardsLateVideoFrames = true
            
            if captureSession.canAddOutput(dataOutput) {
                captureSession.addOutput(dataOutput)
            }
            
            captureSession.commitConfiguration()
            
            let queue = DispatchQueue(label: "com.EyeBot.EyeBot")
            dataOutput.setSampleBufferDelegate(self, queue: queue)
        }
    }
    
    func actionButtonsPressed(touch: UITapGestureRecognizer) {
        let touchPoint = touch.location(in: self.view)
        let myCaptureButtonArea = CGRect(x: captureButton.frame.origin.x,
                                         y: captureButton.frame.origin.y,
                                         width: captureButton.frame.width,
                                         height: captureButton.frame.height)
        
        let myFlashButtonArea = CGRect(x: flashButton.frame.origin.x,
                                       y: flashButton.frame.origin.y,
                                       width: flashButton.frame.width,
                                       height: flashButton.frame.height)
        
        let mySettingsButtonArea = CGRect(x: settingsButton.frame.origin.x,
                                          y: settingsButton.frame.origin.y,
                                          width: settingsButton.frame.width,
                                          height: settingsButton.frame.height)
        
        if myCaptureButtonArea.contains(touchPoint) {
            takePhoto = true
        } else if myFlashButtonArea.contains(touchPoint) {
            if let device = captureDevice {
                do {
                    try device.lockForConfiguration()
                    if device.isTorchActive {
                        device.torchMode = AVCaptureTorchMode.off
                    } else {
                        device.torchMode = AVCaptureTorchMode.on
                    }
                }
                catch {
                    print(error.localizedDescription)
                }
            } 
        }
        else if mySettingsButtonArea.contains(touchPoint) {
            showResultPopover(sender: self.view)
        }
    }
    
    func captureOutput(_ captureOutput: AVCaptureOutput!, didOutputSampleBuffer sampleBuffer: CMSampleBuffer!, from connection: AVCaptureConnection!) {
        if takePhoto {
            takePhoto = false
            
            if let image = self.getImageFromSampleBuffer(buffer: sampleBuffer) {
                takenPhoto = image
                EinsteinManager.shared.predictImage(image,
                                                    withModelId: EinsteinManager.generalImageId,
                                                    completion:
                { (prediction, error) in
                    if error == nil {
                        print(prediction?.mostProbable.label ?? "No label predicted")
                    } else {
                        print(error!.message)
                    }
                })
            }
        }
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        
        let myCaptureButtonArea = CGRect(x: captureButton.frame.origin.x,
                                         y: captureButton.frame.origin.y,
                                         width: captureButton.frame.width,
                                         height: captureButton.frame.height)
        
        let screenSize = UIScreen.main.bounds.size
        
        if let touchPoint = touches.first {
            
            let x = touchPoint.location(in: self.view).y / screenSize.height
            let y = touchPoint.location(in: self.view).x / screenSize.width
            
            let focusPoint = CGPoint(x: x,
                                     y: y)
            
            if !myCaptureButtonArea.contains((touches.first?.location(in: self.view))!) {
                if let device = captureDevice {
                    
                    do {
                        try device.lockForConfiguration()
                        device.focusPointOfInterest = focusPoint
                        device.focusMode = .autoFocus
                        device.exposurePointOfInterest = focusPoint
                        device.exposureMode = AVCaptureExposureMode.continuousAutoExposure
                        device.unlockForConfiguration()
                    } catch {
                        print(error.localizedDescription)
                    }
                }
            }
        }
    }

    func getImageFromSampleBuffer(buffer: CMSampleBuffer) -> UIImage? {
        
        if let pixelBuffer = CMSampleBufferGetImageBuffer(buffer) {
            
            let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
            let context = CIContext()
            
            let imageRect = CGRect(x: 0,
                                   y: 0,
                                   width: CVPixelBufferGetWidth(pixelBuffer),
                                   height: CVPixelBufferGetHeight(pixelBuffer))
            
            if let image = context.createCGImage(ciImage, from: imageRect) {
                
                return UIImage(cgImage: image,
                               scale: UIScreen.main.scale,
                               orientation: .right)
            }
        }
        return nil
    }
    
    func stopCaptureSession() {
        self.captureSession.stopRunning()
        
        if let inputs = captureSession.inputs as? [AVCaptureDeviceInput] {
            for input in inputs {
                self.captureSession.removeInput(input)
            }
        }
    }
    
    func addSettingsButton() {
        settingsButton.frame = CGRect(x: 10, y: 20, width: 30, height: 30)
        settingsButton.clipsToBounds = true
        settingsButton.setImage(#imageLiteral(resourceName: "settingsButton"), for: .normal)
        previewLayer?.addSublayer(self.settingsButton.layer)
    }
    
    func addFlashButton() {
        let widthScreen = UIScreen.main.bounds.width
        // 10 + *30 = 40 as settings button width = *30
        // add a minimum of 30 space between buttons, more depending on screen
        flashButton.frame = CGRect(x: 40 + max(30, 0.075 * widthScreen), y: 25, width: 30, height: 30)
        flashButton.clipsToBounds = true
        flashButton.setImage(#imageLiteral(resourceName: "flashButton"), for: .normal)
        previewLayer?.addSublayer(self.flashButton.layer)
    }
    
    func addCaptureButton() {
        let widthScreen = UIScreen.main.bounds.width
        let heightScreen = UIScreen.main.bounds.height
        captureButton.frame = CGRect(x: widthScreen/2, y: heightScreen-50, width: 75, height: 75)
        captureButton.center = CGPoint(x: widthScreen/2, y: heightScreen-50)
        captureButton.clipsToBounds = true
        captureButton.setImage(#imageLiteral(resourceName: "captureButton"), for: .normal)
        previewLayer?.addSublayer(self.captureButton.layer)
    }
    
    func showResultPopover(sender: UIView) {
        let dynamicView = UIView(frame: CGRect(x: 100, y: 200, width: 100, height: 100))
        dynamicView.backgroundColor = UIColor.green
        dynamicView.layer.cornerRadius = 25
        dynamicView.layer.borderWidth = 2
        sender.addSubview(dynamicView)
    }
}
