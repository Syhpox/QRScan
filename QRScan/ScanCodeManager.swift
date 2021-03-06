//
//  ScanCodeManager.swift
//  QRScan
//
//  Created by WZH on 2017/7/12.
//  Copyright © 2017年 Zhihua. All rights reserved.
//  扫码处理工具

import UIKit
import AVFoundation

class ScanCodeManager: NSObject, AVCaptureMetadataOutputObjectsDelegate {
    // session   处理回调
    
    fileprivate var device: AVCaptureDevice!
    fileprivate var input: AVCaptureDeviceInput!
    fileprivate var output: AVCaptureMetadataOutput!
    var session: AVCaptureSession!
    // 默认 扫码所有类型
    var scanTypes: [AVMetadataObject.ObjectType] = [] {
        didSet {
            if output != nil {
                output.metadataObjectTypes = scanTypes
            }
        }
    }
    
    var resultBlc:((String) -> Void)?
    
    fileprivate override init() {
        super.init()
        self.device = AVCaptureDevice.default(for: AVMediaType.video)
        self.input = try? AVCaptureDeviceInput.init(device: device)
        self.output = AVCaptureMetadataOutput.init()
        output.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
        
        session = AVCaptureSession.init()
        session.canSetSessionPreset(AVCaptureSession.Preset.high)
        session.addInput(input)
        session.addOutput(output)
        
        // 设置扫码支持的编码格式
        output.metadataObjectTypes = [AVMetadataObject.ObjectType.qr,
                                      AVMetadataObject.ObjectType.code39,
                                      AVMetadataObject.ObjectType.code39Mod43,
                                      AVMetadataObject.ObjectType.ean13,
                                      AVMetadataObject.ObjectType.ean8,
                                      AVMetadataObject.ObjectType.code93,
                                      AVMetadataObject.ObjectType.code128,
                                      AVMetadataObject.ObjectType.pdf417,
                                      AVMetadataObject.ObjectType.upce,
                                      AVMetadataObject.ObjectType.interleaved2of5,
                                      AVMetadataObject.ObjectType.dataMatrix
        ]
    }
    
    convenience init(_ resultBlc: ((String) -> Void)?) {
        self.init()
        self.resultBlc = resultBlc
    }
    
    /// 设置有效扫码区域
    func setScanArea(_ rect: CGRect, superSize: CGSize) {
        let superWidth = superSize.width
        let superHeight = superSize.height
        let interestRect = CGRect(x: rect.origin.y / superHeight, y: 1 - rect.origin.x / superWidth - rect.size.width / superWidth, width: rect.size.height / superHeight, height: rect.size.width / superWidth)
        output.rectOfInterest = interestRect
    }
    
    //MARK: - AVCaptureMetadataOutputObjectsDelegate
    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        if metadataObjects.count > 0 {
            session.stopRunning()
            let obj = metadataObjects[0] as! AVMetadataMachineReadableCodeObject
            if let block = resultBlc {
                block(obj.stringValue!)
            }
        }
    }
    
    /// 摄像机鉴权
    class func authorization(_ complete:((_ success: Bool) -> Void)? = nil) -> Bool {
        // 有无摄像头
        if !(UIImagePickerController.isSourceTypeAvailable(UIImagePickerControllerSourceType.camera) &&
            UIImagePickerController.isCameraDeviceAvailable(UIImagePickerControllerCameraDevice.rear)) {
            let alert = UIAlertController.init(title: "提示", message: "没有摄像头或摄像头不可用", preferredStyle: .alert)
            let action = UIAlertAction.init(title: "确定", style: .default, handler: { (alert) in
                if let blc = complete {
                    blc(false)
                }
            })
            alert.addAction(action)
            UIApplication.shared.keyWindow?.rootViewController?.present(alert, animated: true, completion: nil)
            return false

        }
        let status = AVCaptureDevice.authorizationStatus(for: AVMediaType.video)
        if status == .restricted || status == .denied {
            let alert = UIAlertController.init(title: "提示", message: "没有摄像头权限，请到设置打开摄像头", preferredStyle: .alert)
            let action = UIAlertAction.init(title: "确定", style: .default, handler: { (alert) in
                if let blc = complete {
                    blc(false)
                }
            })
            alert.addAction(action)
            UIApplication.shared.keyWindow?.rootViewController?.present(alert, animated: true, completion: nil)
            return false
        }
        if let blc = complete {
            blc(true)
        }
        return true
    }
    
}
