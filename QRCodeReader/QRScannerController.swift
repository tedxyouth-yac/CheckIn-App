//
//  QRScannerController.swift
//  QRCodeReader
//
//  Created by Nisala Kalupahana on 21/10/2016
//  Copyright © 2017 YAC & Nisala Kalupahana. All rights reserved.
//

import UIKit
import AVFoundation

class QRScannerController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {

    @IBOutlet var messageLabel:UILabel!
    
    var captureSession:AVCaptureSession?
    var videoPreviewLayer:AVCaptureVideoPreviewLayer?
    var qrCodeFrameView:UIView?
    let queryPassword = "REPLACE_WITH_YOUR_PASSWORD"
    var urlArray: [URL] = [];
    var lockMessageLabelText = false;
    
    let supportedCodeTypes = [AVMetadataObject.ObjectType.upce,
                        AVMetadataObject.ObjectType.code39,
                        AVMetadataObject.ObjectType.code39Mod43,
                        AVMetadataObject.ObjectType.code93,
                        AVMetadataObject.ObjectType.code128,
                        AVMetadataObject.ObjectType.ean8,
                        AVMetadataObject.ObjectType.ean13,
                        AVMetadataObject.ObjectType.aztec,
                        AVMetadataObject.ObjectType.pdf417,
                        AVMetadataObject.ObjectType.qr]
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Get an instance of the AVCaptureDevice class to initialize a device object and provide the video as the media type parameter.
        let captureDevice = AVCaptureDevice.default(for: AVMediaType.video)
        
        do {
            // Get an instance of the AVCaptureDeviceInput class using the previous device object.
            let input = try AVCaptureDeviceInput(device: captureDevice!)
            
            // Initialize the captureSession object.
            captureSession = AVCaptureSession()
            
            // Set the input device on the capture session.
            captureSession?.addInput(input)
            
            // Initialize a AVCaptureMetadataOutput object and set it as the output device to the capture session.
            let captureMetadataOutput = AVCaptureMetadataOutput()
            captureSession?.addOutput(captureMetadataOutput)
            
            // Set delegate and use the default dispatch queue to execute the call back
            captureMetadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
            captureMetadataOutput.metadataObjectTypes = supportedCodeTypes
            
            // Initialize the video preview layer and add it as a sublayer to the viewPreview view's layer.
            videoPreviewLayer = AVCaptureVideoPreviewLayer(session: captureSession!)
            videoPreviewLayer?.videoGravity = AVLayerVideoGravity.resizeAspectFill
            videoPreviewLayer?.frame = view.layer.bounds
            view.layer.addSublayer(videoPreviewLayer!)
            
            // Start video capture.
            captureSession?.startRunning()
            
            // Move the message label and top bar to the front
            view.bringSubview(toFront: messageLabel)
            
            // Initialize QR Code Frame to highlight the QR code
            qrCodeFrameView = UIView()
            
            if let qrCodeFrameView = qrCodeFrameView {
                qrCodeFrameView.layer.borderColor = UIColor.green.cgColor
                qrCodeFrameView.layer.borderWidth = 2
                view.addSubview(qrCodeFrameView)
                view.bringSubview(toFront: qrCodeFrameView)
            }
            
        } catch {
            // If any error occurs, simply print it out and don't continue any more.
            print(error)
            return
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    // MARK: - AVCaptureMetadataOutputObjectsDelegate Methods
    
    func metadataOutput(_ captureOutput: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        
        // Check if the metadataObjects array is not nil and it contains at least one object.
        if (metadataObjects == nil || metadataObjects.count == 0 || lockMessageLabelText) {
            qrCodeFrameView?.frame = CGRect.zero
            return
        }
        
        // Get the metadata object.
        let metadataObj = metadataObjects[0] as! AVMetadataMachineReadableCodeObject
        
        // If the metadata is there, execute the request.
        if supportedCodeTypes.contains(metadataObj.type) {
            let barCodeObject = videoPreviewLayer?.transformedMetadataObject(for: metadataObj)
            qrCodeFrameView?.frame = barCodeObject!.bounds
            
            if metadataObj.stringValue != nil {
                lockMessageLabelText = true;
                
                let url = URL(string: "https://us-central1-tedx-hillsboro.cloudfunctions.net/checkin?" + queryPassword + "%7C" + metadataObj.stringValue!)
                
                if (urlArray.contains(url!)) {
                    return;
                } else {
                    urlArray.append(url!);
                }
                
                messageLabel.text = "Processing..."
                
                let task = URLSession.shared.dataTask(with: url! as URL) { data, response, error in
                    guard let data = data, error == nil else { return }
                    let returnCode = NSString(data: data, encoding: String.Encoding.utf8.rawValue)
                    
                    if (returnCode!.contains("200")) {
                        DispatchQueue.main.async {
                            let username = returnCode!.substring(from: 3)
                            self.messageLabel.text = "Signed in \(username)!"
                            self.messageLabel.backgroundColor = UIColor.green
                        }
                    } else if (returnCode == "201") {
                        DispatchQueue.main.async {
                            self.messageLabel.text = "Already signed in!"
                            self.messageLabel.backgroundColor = UIColor.red
                        }
                    } else if (returnCode == "420") {
                        DispatchQueue.main.async {
                            self.messageLabel.text = "PROBLEM! GET EVENT ORG!"
                            self.messageLabel.backgroundColor = UIColor.red
                        }
                    } else if (returnCode == "215") {
                        DispatchQueue.main.async {
                            self.messageLabel.text = "CORRUPTION! REINSTALL APP!"
                            self.messageLabel.backgroundColor = UIColor.red
                        }
                    } else if (returnCode == "202") {
                        DispatchQueue.main.async {
                            self.messageLabel.text = "INVALID CODE! DENY ENTRY!"
                            self.messageLabel.backgroundColor = UIColor.red
                        }
                    } else {
                        DispatchQueue.main.async {
                            self.messageLabel.text = "Internal Error \(returnCode!)"
                            self.messageLabel.backgroundColor = UIColor.red
                        }
                    }
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(4), execute: {
                    self.messageLabel.text = "Scan a QR code to sign in"
                    self.urlArray = [];
                    self.messageLabel.backgroundColor = UIColor(red: 206, green: 206, blue: 206, alpha: 0.6)
                    self.lockMessageLabelText = false;
                })
                
                task.resume()
                
            }
        }
    }

}
