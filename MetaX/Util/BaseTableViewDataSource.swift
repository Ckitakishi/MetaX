//
//  BaseTableViewController.swift
//  MetaX
//
//  Created by Ckitakishi on 2018/3/19.
//  Copyright © 2018年 Yuhan Chen. All rights reserved.
//

import UIKit

// Model --> cell's model
// Cell --> cell
class BaseTableViewDataSource<Model, Cell: UITableViewCell>: NSObject, UITableViewDataSource where Cell: Reusable, Cell: CellConfig, Model == Cell.DataSource {
    
    var dataSource: [[Model]] = [] {
        didSet { tableView.reloadData() }
    }
    
    fileprivate unowned var tableView: UITableView
    
    init(tableView: UITableView) {
        self.tableView = tableView
        tableView.registerReusableCell(Cell.self)
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.dataSource.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell: Cell = tableView.dequeueReusableCell(indexPath: indexPath)
        cell.cellDataSource = dataSource[indexPath.row][0]
        return cell
    }
}
