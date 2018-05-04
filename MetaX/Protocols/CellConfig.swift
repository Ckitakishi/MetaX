//
//  CellConfig.swift
//  MetaX
//
//  Created by Ckitakishi on 2018/3/19.
//  Copyright © 2018年 Yuhan Chen. All rights reserved.
//

protocol CellConfig: class {
    associatedtype DataSource
    var cellDataSource: DataSource? { get set }
}
