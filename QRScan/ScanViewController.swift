//
//  ScanViewController.swift
//  QRScan
//
//  Created by WZH on 2017/7/10.
//  Copyright © 2017年 Zhihua. All rights reserved.
//

import UIKit
import AVFoundation

class ScanViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    var scanView: ScanCodeView!
    
    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
        self.navigationItem.setHidesBackButton(false, animated: true)
    }
    
    convenience init() {
        self.init(nibName: nil, bundle: nil)
    }
    
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        self.title = "扫一扫"
        guard ScanCodeManager.authorization({ (success) in
            if !success {
                // 鉴权失败
                self.navigationController?.popViewController(animated: true)
            }
        }) else {
            return
        }

        
        scanView = ScanCodeView.init(CGRect(x: 0, y: 64 ,width: self.view.bounds.width, height: self.view.bounds.height-64), type: .fetch)
        scanView.needTorch = true
        self.view.addSubview(scanView)
        scanView.resultBlc = { code in
            print("扫码结果：" + code)
            let alert = UIAlertController.init(title: "扫描结果", message: "\"" + code + "\"", preferredStyle: .alert)
            let ac = UIAlertAction.init(title: "退出", style: .destructive, handler: { (ac) in
                self.navigationController?.popViewController(animated: true)
            })
            
            let ac1 = UIAlertAction.init(title: "重新扫描", style: .default, handler: { (ac) in
                self.scanView.startRunning()
            })
            alert.addAction(ac)
            alert.addAction(ac1)
            self.present(alert, animated: true, completion: nil)
            
        }
        
        scanView.startRunning()
    }
    
    

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */

}
