//
//  ScanCodeView.swift
//  QRScan
//
//  Created by WZH on 2017/7/12.
//  Copyright © 2017年 Zhihua. All rights reserved.
//

import UIKit
import AVFoundation
import CoreGraphics
fileprivate let ScanCode_ScreenWidth = UIScreen.main.bounds.size.width
fileprivate let ScanCode_ScreenHeight = UIScreen.main.bounds.size.height

/// 对应枚举场景使用的标准参数
enum ScanCodeType {
    case fetch // 扫码 （条件：全屏尺寸）
    case customSize(CGFloat, CGFloat, String) //自定义size(width, height) 和 tips
    case customRect(CGFloat, CGFloat, CGFloat, CGFloat, String, UIColor) //自定义rect(x, y, width, height) 和 tips 自定义line颜色
    
    /// 固定配置 扫码范围以及提示
    func configure() -> (scanOrigin: CGPoint, scanSize: CGSize, tips: String, lineColor: UIColor) {
        switch self {
        case .fetch:
            return (scanOrigin: CGPoint(x: ScanCode_ScreenWidth * (1 - 4 / 5) / 2.0, y: 100), scanSize: CGSize(width: ScanCode_ScreenWidth / 5 * 4,height: ScanCode_ScreenWidth / 5 * 4), tips: "请对准二维码", lineColor: UIColor.yellow)
            
        case .customSize(let width, let height, let tips):
            return (scanOrigin: CGPoint(x: width * (1 - 4 / 5) / 2.0, y: 100), scanSize: CGSize(width: width,height: height), tips: tips, lineColor: UIColor.yellow)
            
        case .customRect(let x, let y, let width, let height, let tips, let lineColor):
            return (scanOrigin:CGPoint(x: x, y: y), scanSize: CGSize(width: width,height: height), tips: tips, lineColor: lineColor)
        }
    }
}

class ScanCodeView: UIView {
    /// ↓↓--------------! 手电筒配置 !--------------↓↓
    /// 手电筒
    fileprivate var torchBtn: UIButton! = {
        let btn = UIButton.init(type: .custom)
        btn.setImage(UIImage(named: "troch"), for: .normal)
        return btn
    }()
    
    /// 手电筒设备
    fileprivate var torchDevice: AVCaptureDevice!
    
    /// 记录手电筒开关
    fileprivate var torchOn: Bool = false {
        didSet {
            if torchDevice.hasTorch {
                try? torchDevice.lockForConfiguration()
                if torchOn {
                    torchDevice.torchMode = .on
                } else {
                    torchDevice.torchMode = .off
                }
                torchDevice.unlockForConfiguration()
            }
            
        }
    }
    
    /// 手电筒坐标
    var torchFrame: CGRect! {
        didSet {
            torchBtn.frame = torchFrame
        }
    }
    
    /// 设置是否显示手电筒
    var needTorch: Bool = false {
        didSet {
            torchBtn.isHidden = !needTorch
        }
    }
    /// ↑↑--------------! 手电筒配置 !--------------↑↑
    
    /// 照相图层
    fileprivate var prelayer: AVCaptureVideoPreviewLayer!
    
    /// 扫码有效范围
    fileprivate var scanShadow: ScanShadowView!
    
    /// 扫码提示文字lab
    fileprivate var tipsLabel: UILabel! = {
        let lab = UILabel()
        lab.font = UIFont.systemFont(ofSize: 20)
        lab.textAlignment = .center
        lab.textColor = UIColor.white
        return lab
    }()
    
    /// 系统RunningView图
    fileprivate var activityView: RunningView!
    
    /// 扫码处理
    fileprivate var scanManager: ScanCodeManager!
    
    /// 扫描线 图片
    fileprivate var scanLine: UIImageView! = {
        let img = UIImageView.init()
        //        img.image = UIImage(named: "QRCodeScanningLine")
        return img
    }()
    
    /// 扫描线 layer
    fileprivate var line: CAGradientLayer!
    
    /// 扫码结果回调
    var resultBlc:((String) -> Void)?
    
    /// 提示文字text
    var tipsText: String? {
        get {
            return tipsLabel.text
        }
        set {
            tipsLabel.text = newValue
        }
    }
    /// 记录type样式
    fileprivate(set) var type: ScanCodeType!
    
    /// 设置 默认扫描线
    var isDefault: Bool = true
    
    override init(frame: CGRect) {
        super.init(frame: frame)
    }
    
    convenience init(_ frame: CGRect, type: ScanCodeType) {
        let config = type.configure()
        self.init(frame, scanRect: CGRect(origin: config.scanOrigin, size: config.scanSize), lineColor: config.lineColor)
        tipsText = config.tips
        self.type = type
    }
    
    fileprivate convenience init(_ frame: CGRect, scanRect: CGRect, lineColor: UIColor = UIColor.yellow) {
        self.init(frame: frame)
        self.backgroundColor = .clear
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            return
        }
        
        let status = AVCaptureDevice.authorizationStatus(for: AVMediaType.video)
        guard status == .authorized || status == .notDetermined else {
            return
        }

        scanManager = ScanCodeManager.init({[weak self] (code) in
            self?.stopScanLineAnimat()
            if let blc = self?.resultBlc {
                blc(code)
            }
        })
        // 设置有效扫码范围
        scanManager.setScanArea(scanRect, superSize: frame.size)
        
        // 扫码配置
        prelayer = AVCaptureVideoPreviewLayer.init(session: scanManager.session)
        prelayer.videoGravity = AVLayerVideoGravity.resizeAspectFill
        prelayer.frame = CGRect(x: 0, y: 0, width: frame.size.width, height: frame.size.height)
        self.layer.addSublayer(prelayer)
        
        // 绘制扫码区域
        scanShadow = ScanShadowView.init(self.bounds, interestFrame: scanRect, lineColor: lineColor)
        self.addSubview(scanShadow)
        if !isDefault {
            // 扫描线
            self.addSubview(self.scanLine)
            self.scanLine.frame = CGRect(x: scanRect.origin.x + 5, y: scanRect.origin.y, width: scanRect.size.width - 10, height: 3)
        } else {
            line = CAGradientLayer.init()
            line.frame = CGRect(x: scanRect.origin.x + 5, y: scanRect.origin.y, width: scanRect.size.width - 10, height: 3)
            //        line.startPoint = CGPoint(x: 0, y: 0)
            //        line.endPoint = CGPoint(x: 0, y: 1)
            //        let color = UIColor.init(red: 234 / 255.5, green: 222 / 255.0, blue: 69 / 255.0, alpha: 1.0)
            //        let color2 = UIColor.init(red: 251 / 255.5, green: 193 / 255.0, blue: 174 / 255.0, alpha: 1.0)
            //        line.colors = [color2.cgColor,color.cgColor,UIColor.yellow.cgColor,color.cgColor,color2.cgColor]
            //        line.locations = [0.0,0.45,0.50,0.55,1.0]
            line.backgroundColor = lineColor.cgColor
            self.layer.addSublayer(line)
        }
        // 扫码提示文字
        self.addSubview(self.tipsLabel)
        tipsLabel.frame = CGRect(x: 0, y: scanRect.origin.y + scanRect.size.height + 30, width: self.bounds.width, height: 30)
        
        // 手电筒配置
        torchBtn.frame = CGRect(x: 16, y: 16, width: 44, height: 44)
        torchBtn.isHidden = !needTorch
        self.addSubview(torchBtn)
        torchBtn.addTarget(self, action: #selector(torchBtnClick(btn:)), for: .touchUpInside)
        torchDevice = AVCaptureDevice.default(for: .video)
        
        /// activityView
        activityView = RunningView.init(CGPoint.zero)
        activityView.frame = CGRect(origin: CGPoint(x: scanRect.origin.x + (scanRect.size.width - activityView.frame.width) / 2.0,y: scanRect.origin.y + (scanRect.size.height - activityView.frame.height) / 2.0), size: activityView.frame.size)
        self.addSubview(activityView)
        stopActivity()
        
        scanLineAnimat(0, scanShadow.interestFrame.size.height - line.frame.size.height)
    }
    
    /// 开始扫描线动画
    fileprivate func scanLineAnimat(_ start: CGFloat, _ end: CGFloat) {
        let animation = CABasicAnimation()
        animation.keyPath = "transform.translation.y"
        animation.duration = 3
        animation.isRemovedOnCompletion = false
        animation.timingFunction = CAMediaTimingFunction.init(name: kCAMediaTimingFunctionLinear)
        animation.fillMode = kCAFillModeForwards
        animation.fromValue = start
        animation.toValue = end
        animation.repeatCount = MAXFLOAT
        if isDefault {
            line.add(animation, forKey: "lineAnimation")
        } else {
            scanLine.layer.add(animation, forKey: "lineAnimation")
        }
    }
    
    /// 结束扫描线动画
    fileprivate func stopScanLineAnimat() {
        if isDefault {
            line.removeAnimation(forKey: "lineAnimation")
        } else {
            self.scanLine.layer.removeAnimation(forKey: "lineAnimation")
        }
    }
    
    /// 手电筒按钮点击事件
    @objc fileprivate func torchBtnClick(btn: UIButton) {
        torchOn = !torchOn
    }
    
    /// 开始扫码
    func startRunning() {
        if !scanManager.session.isRunning {
            scanLineAnimat(0, scanShadow.interestFrame.size.height - line.frame.size.height)
            scanManager.session.startRunning()
        }
    }
    
    /// 开始activity
    func startActivity() {
        activityView.isHidden = false
        activityView.start()
    }
    
    /// 停止activity
    func stopActivity() {
        activityView.isHidden = true
        activityView.stop()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}


fileprivate class ScanShadowView: UIView {
    
    var interestFrame: CGRect!
    var timer: CADisplayLink!
    var scanningLine: CALayer = {
        let layer = CALayer.init()
        return layer
    }()
    
    var lineColor: UIColor!
    
    var change: CGFloat = 1
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        self.backgroundColor = .clear
    }
    
    convenience init(_ frame: CGRect, interestFrame: CGRect, lineColor: UIColor = UIColor.yellow) {
        self.init(frame: frame)
        self.interestFrame = interestFrame
        self.lineColor = lineColor
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func draw(_ rect: CGRect) {
        super.draw(rect)
        if  let ctx = UIGraphicsGetCurrentContext() {
            ctx.setFillColor(red: 0.15, green: 0.15, blue: 0.15, alpha: 0.6)
            ctx.fill(rect)
            ctx.clear(interestFrame)
            
            ctx.addRect(interestFrame)
            ctx.setLineWidth(0.5)
            ctx.setStrokeColor(red: 1, green: 1, blue: 1, alpha: 1)
            ctx.strokePath()
            addAllLine(ctx, rect: interestFrame)
        }
    }
    
    func addAllLine(_ ctx: CGContext, rect: CGRect) {
        let lineOfWidth: CGFloat = 4 // 线宽
        let lineWidth: CGFloat = 25 // 水平线长度
        let lineHeight: CGFloat = 25 // 垂直线长度
        
        ctx.setStrokeColor(lineColor.cgColor)
        
        ctx.setLineWidth(lineOfWidth)
        
        let correctDistance: CGFloat = lineOfWidth / 2.0
        
        // rect 4角 坐标
        let leftTop = rect.origin
        let rightTop = CGPoint(x: rect.origin.x + rect.size.width, y: rect.origin.y)
        let leftBottom = CGPoint(x: rect.origin.x, y: rect.origin.y + rect.size.height)
        let rightBottom = CGPoint(x: rect.origin.x + rect.size.width, y: rect.origin.y + rect.size.height)
        
        
        // 左上角
        let leftTop1 = CGPoint(x: leftTop.x + correctDistance, y: leftTop.y + correctDistance)
        let leftTop0 = CGPoint(x: leftTop1.x, y: leftTop1.y + lineHeight)
        let leftTop2 = CGPoint(x: leftTop1.x + lineWidth, y: leftTop1.y)
        ctx.move(to:leftTop0)
        ctx.addLine(to: leftTop1)
        ctx.addLine(to: leftTop2)
        
        // 右上角
        let rightTop1 = CGPoint(x: rightTop.x - correctDistance, y: rightTop.y + correctDistance)
        let rightTop0 = CGPoint(x: rightTop.x - lineWidth, y: rightTop1.y)
        let rightTop2 = CGPoint(x: rightTop1.x, y: rightTop.y + lineHeight)
        ctx.move(to:rightTop0)
        ctx.addLine(to: rightTop1)
        ctx.addLine(to: rightTop2)
        
        // 左下角
        let leftBottom1 = CGPoint(x: leftBottom.x + correctDistance, y: leftBottom.y - correctDistance)
        let leftBottom0 = CGPoint(x: leftBottom1.x, y: leftBottom.y - lineHeight)
        let leftBottom2 = CGPoint(x: leftBottom.x + lineWidth, y: leftBottom1.y)
        ctx.move(to:leftBottom0)
        ctx.addLine(to: leftBottom1)
        ctx.addLine(to: leftBottom2)
        
        // 右下角
        let rightBottom1 = CGPoint(x: rightBottom.x - correctDistance, y: rightBottom.y - correctDistance)
        let rightBottom0 = CGPoint(x: rightBottom.x - lineWidth,y: rightBottom1.y)
        let rightBottom2 = CGPoint(x: rightBottom1.x, y: rightBottom.y - lineHeight)
        ctx.move(to:rightBottom0)
        ctx.addLine(to: rightBottom1)
        ctx.addLine(to: rightBottom2)
        
        ctx.strokePath()
    }
    
}

fileprivate class RunningView: UIView {
    var activity: UIActivityIndicatorView!
    var messageLab: UILabel!
    
    override init(frame: CGRect) {
        super.init(frame: frame)
    }
    
    convenience init(_ origin: CGPoint) {
        self.init(frame: CGRect(origin: origin, size: CGSize(width: 100, height: 80)))
        let activityWidth: CGFloat = 44
        activity = UIActivityIndicatorView.init(frame: CGRect(x: (frame.size.width - activityWidth) / 2.0, y: 2, width: activityWidth, height: activityWidth))
        activity.activityIndicatorViewStyle = .whiteLarge
        self.addSubview(activity)
        messageLab = UILabel()
        messageLab.frame = CGRect(x: 0, y: activity.frame.maxY, width: frame.size.width, height: 24)
        messageLab.text = "正在处理..."
        messageLab.textAlignment = .center
        messageLab.textColor = UIColor.white
        messageLab.font = UIFont.systemFont(ofSize: 15)
        self.addSubview(messageLab)
        activity.stopAnimating()
    }
    
    /// 开始
    func start() {
        activity.startAnimating()
    }
    
    /// 停止
    func stop() {
        activity.stopAnimating()
        
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    
    
}


