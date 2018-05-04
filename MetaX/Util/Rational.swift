//
//  Rational.swift
//  MetaX
//
//  Created by Ckitakishi on 2018/04/04.
//  Copyright © 2018年 Yuhan Chen. All rights reserved.
//

struct Rational {
    
    var num: Int
    var den: Int
    
    // Reference: https://stackoverflow.com/questions/35895154/decimal-to-fraction-conversion-in-swift
    init(approximationOf doubleNum: Double, withPrecision eps: Double = 1.0E-6) {
        var dNum = doubleNum
        var dNumRoundedDown = dNum.rounded(.down)
        var (h1, k1, h, k) = (1, 0, Int(dNumRoundedDown), 1)
        
        while dNum - dNumRoundedDown > eps * Double(k) * Double(k) {
            dNum = 1.0/(dNum - dNumRoundedDown)
            dNumRoundedDown = dNum.rounded(.down)
            (h1, k1, h, k) = (h, k, h1 + Int(dNumRoundedDown) * h, k1 + Int(dNumRoundedDown) * k)
        }
        num = h
        den = k
    }
}
