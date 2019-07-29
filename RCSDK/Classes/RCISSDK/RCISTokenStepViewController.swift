//
//  RCISTokenStepViewController.swift
//  iChange
//
//  Created by James Kizer on 6/25/18.
//  Copyright © 2018 James Kizer. All rights reserved.
//

import UIKit
import ResearchSuiteExtensions
import QRCodeReader
import AVFoundation
import SnapKit
import ResearchKit

open class RCISResponseResult: ORKResult {
    
    public var response: RCISClient.TokenResponse?
    
    override open func copy(with zone: NSZone? = nil) -> Any {
        let copy: RCISResponseResult = super.copy(with: zone) as! RCISResponseResult
        copy.response = response
        return copy
    }
    
}

open class RCISTokenStepViewController: RSQuestionViewController, QRCodeReaderViewControllerDelegate {
    
    
    lazy var readerVC: QRCodeReaderViewController = {
        let builder = QRCodeReaderViewControllerBuilder {
            $0.reader = QRCodeReader(metadataObjectTypes: [.qr], captureDevicePosition: .back)
            $0.showCancelButton = false
            $0.showSwitchCameraButton = false
        }
        
        return QRCodeReaderViewController(builder: builder)
    }()

    var rcisClient: RCISClient!
    var rcManager: RCManager!
    var response: RCISClient.TokenResponse? = nil
    
    open override func viewDidLoad() {
        
        do {
            let supported = try QRCodeReader.supportsMetadataObjectTypes()
            if supported == false {
                //potentially show error message here
                let alertController = UIAlertController(title: "Not Supported", message: "QR Code reading is not supported", preferredStyle: UIAlertController.Style.alert)
                
                let okAction = UIAlertAction(title: "OK", style: UIAlertAction.Style.default) {
                    (result : UIAlertAction) -> Void in
                    
                }
                
                alertController.addAction(okAction)
                self.present(alertController, animated: true)
                
                return
            }
        }
        catch {
            //potentially show error message here
            let alertController = UIAlertController(title: "Not Supported", message: "QR Code reading is not supported", preferredStyle: UIAlertController.Style.alert)
            
            let okAction = UIAlertAction(title: "OK", style: UIAlertAction.Style.default) {
                (result : UIAlertAction) -> Void in
                
            }
            
            alertController.addAction(okAction)
            self.present(alertController, animated: true)
            return
        }
        
        self.titleLabel.text = self.step?.title
        self.textLabel.text = self.step?.text
        
        self.readerVC.delegate = self
        self.addChild(self.readerVC)
        self.contentView.addSubview(self.readerVC.view)
        self.readerVC.view.snp.makeConstraints { (make) in
            
            make.center.equalTo(self.contentView)
            make.size.equalTo(self.contentView)
            
        }
        
        self.skipButton.isHidden = true
        self.continueButton.isHidden = true
        
        if let step = self.step as? RCISTokenScanStep {
            self.rcisClient = step.rcisClient
            self.rcManager = step.rcManager
        }
        
        
    }
    
    public func reader(_ reader: QRCodeReaderViewController, didScanResult result: QRCodeReaderResult) {
        
        reader.stopScanning()
        
        //pop up spinner
        let token = result.value
        self.rcisClient.redeemToken(
            token: token
        ) { (response, error) in
            
            
            if let response = response {
                self.response = response
                
                let credentials = RCManager.Credentials(
                    apiToken: response.APIToken,
                    recordID: response.recordID,
                    rcisJWT: response.rcisJWT
                )
                
                self.rcManager.postJoinedMessage(credentials: credentials, completion: { (error) in
                    
                    
                    
                    //could not post instrument instance
                    if let error = error {
                        
                        let message: String = {
                            switch error {
                            case RCClientError.invalidAPIToken:
                                return "The API token is invalid. Please alert the research team."
                            default:
                                return "Could not reach the server. Please try again later."
                            }
                        }()
                        
                        DispatchQueue.main.async {
                            let alertController = UIAlertController(title: "Server Error", message: message, preferredStyle: UIAlertController.Style.alert)
                            
                            let okAction = UIAlertAction(title: "OK", style: UIAlertAction.Style.default) {
                                (result : UIAlertAction) -> Void in
                                reader.startScanning()
                            }
                            
                            alertController.addAction(okAction)
                            self.present(alertController, animated: true)
                        }
                        
                    }
                    else {
                        self.rcisClient.markTokenRedeemed(token: token, completion: { (error) in
                            if error != nil {
                                
                                self.rcManager.signOut(completion: { (error) in
                                    
                                    //potentially show error message here
                                    
                                    let alertController = UIAlertController(title: "Server Error", message: "Could not mark the token as redeemed. Please try again later.", preferredStyle: UIAlertController.Style.alert)
                                    
                                    let okAction = UIAlertAction(title: "OK", style: UIAlertAction.Style.default) {
                                        (result : UIAlertAction) -> Void in
                                        reader.startScanning()
                                    }
                                    
                                    alertController.addAction(okAction)
                                    self.present(alertController, animated: true)
                                    
                                })
                                
                                
                            }
                            else {
                                
                                self.goForward()
                                
                            }
                        })
                    }
                    
                })
                
            }
            else {
                //token could not be redeemed
                let alertController = UIAlertController(title: "Token Error", message: "An error occurred when redeeming the token. Please try again later.", preferredStyle: UIAlertController.Style.alert)
                
                let okAction = UIAlertAction(title: "OK", style: UIAlertAction.Style.default) {
                    (result : UIAlertAction) -> Void in
                    reader.startScanning()
                }
                
                alertController.addAction(okAction)
                self.present(alertController, animated: true)
            }
            
            
            
        }
        
        
    }
    
    override open var result: ORKStepResult? {
        guard let parentResult = super.result else {
            return nil
        }
        
        if let response = self.response {
            let rcisResult = RCISResponseResult(identifier: step!.identifier)
            rcisResult.response = response
            
            parentResult.results = [rcisResult]
        }
        
        return parentResult
    }
    
    //This is an optional delegate method, that allows you to be notified when the user switches the cameraName
    //By pressing on the switch camera button
    public func reader(_ reader: QRCodeReaderViewController, didSwitchCamera newCaptureDevice: AVCaptureDeviceInput) {
        
        let cameraName = newCaptureDevice.device.localizedName
    }
    
    public func readerDidCancel(_ reader: QRCodeReaderViewController) {
        reader.stopScanning()
        assertionFailure()
        
//        dismiss(animated: true, completion: nil)
    }

}
