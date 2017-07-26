//
//  ViewController.swift
//  QRScan
//
//  Created by WZH on 2017/7/10.
//  Copyright © 2017年 Zhihua. All rights reserved.
//

import UIKit

class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        self.view.backgroundColor = .white
        let btn = UIButton.init(type: .system)
        btn.backgroundColor = .darkGray
        btn.tintColor = .white
        btn.setTitle("二维码or条形码扫描", for: .normal)
        self.view.addSubview(btn)
        btn.addTarget(self, action: #selector(btnClick(_:)), for: .touchUpInside)
        btn.frame = CGRect(x: 100, y: 300, width: 200, height: 80)
    }
    
    func btnClick(_ btn: UIButton) {
        self.navigationController?.pushViewController(ScanViewController(), animated: true)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }


}

