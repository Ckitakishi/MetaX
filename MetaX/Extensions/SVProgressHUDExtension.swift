//
//  SVProgressHUDExtension.swift
//  MetaX
//
//  Created by Ckitakishi on 2018/04/19.
//  Copyright © 2018 Yuhan Chen. All rights reserved.
//

import SVProgressHUD

extension SVProgressHUD {
    
    class func customInit() {
        SVProgressHUD.setBackgroundColor(UIColor.black)
        SVProgressHUD.setForegroundColor(UIColor.white)
        SVProgressHUD.setDefaultStyle(.dark)
    }
    
    class func showProcessingHUD(with message: String) {
        SVProgressHUD.customInit()
        SVProgressHUD.setDefaultMaskType(.clear)
        SVProgressHUD.show(withStatus: message)
    }
    
    class func showCustomErrorHUD(with message: String) {
        SVProgressHUD.customInit()
        SVProgressHUD.setMaximumDismissTimeInterval(2.0)
        SVProgressHUD.showError(withStatus: message)
    }
    
    class func showCustomInfoHUD(with message: String) {
        SVProgressHUD.customInit()
        SVProgressHUD.setMaximumDismissTimeInterval(2.0)
        SVProgressHUD.showInfo(withStatus: message)
    }
    
    class func showCustomProgress(_ progress: Float, status: String) {
        SVProgressHUD.customInit()
        SVProgressHUD.showProgress(progress, status: status)
    }
}
