//
//  TitleTableViewController.swift
//  LoopKitUI
//
//  Created by Nathaniel Hamming on 2020-01-27.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import UIKit

open class TitleTableViewController: UITableViewController {

    public var tableViewTitle: String?
    
    override open func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return tableViewTitle
    }
    
    override open func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        guard let headerTitle = self.tableView(tableView, titleForHeaderInSection: section) else {
            return nil
        }
        let headerLabel = TableViewTitleLabel()
        headerLabel.text = headerTitle
        return headerLabel
    }
    
    override open func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return .loopSectionWithTitleHeaderHeight
    }

}
