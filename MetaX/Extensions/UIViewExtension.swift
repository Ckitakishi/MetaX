//
//  CALayerExtension.swift
//  MetaX
//
//  Created by Ckitakishi on 2018/4/14.
//  Copyright © 2018年 Yuhan Chen. All rights reserved.
//

import UIKit

extension UIView {
    
    func addBorder(_ edge: UIRectEdge, color: UIColor, thickness: CGFloat) {
        
        let edgeBit = UInt8(edge.rawValue)
        
        let topBit = UInt8(UIRectEdge.top.rawValue)
        if topBit & edgeBit == topBit {
            layer.addSublayer(borderLayerMake(CGRect.init(x: 0, y: 0, width: frame.width, height: thickness), color: color))
        }
        
        let bottomBit = UInt8(UIRectEdge.bottom.rawValue)
        if bottomBit & edgeBit == bottomBit {
            layer.addSublayer(borderLayerMake(CGRect.init(x: 0, y: frame.height - thickness, width: frame.width, height: thickness), color: color))
        }
        
        let leftBit = UInt8(UIRectEdge.left.rawValue)
        if leftBit & edgeBit == leftBit {
            layer.addSublayer(borderLayerMake(CGRect.init(x: 0, y: 0, width: thickness, height: frame.height), color: color))
        }
        
        let rightBit = UInt8(UIRectEdge.right.rawValue)
        if rightBit & edgeBit == rightBit {
            layer.addSublayer(borderLayerMake(CGRect.init(x: frame.width - thickness, y: 0, width: thickness, height: frame.height), color: color))
        }
    }
    
    fileprivate func borderLayerMake(_ rect: CGRect, color: UIColor) -> CALayer {
        let layer = CALayer()
        layer.backgroundColor = color.cgColor
        layer.frame = rect
        return layer
    }
}
