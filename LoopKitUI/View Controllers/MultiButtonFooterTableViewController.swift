//
//  MultiButtonFooterTableViewController.swift
//  LoopKitUI
//
//  Created by Nathaniel Hamming on 2020-01-27.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import UIKit

open class MultiButtonFooterTableViewController: TitleTableViewController {

    public var footerView: MultiButtonTableFooterView!
    
    public var padFooterToBottom: Bool = true
    
    private var lastContentHeight: CGFloat = 0
        
    override open func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        // Reposition footer view if necessary
        if tableView.contentSize.height != lastContentHeight {
            lastContentHeight = tableView.contentSize.height
            tableView.tableFooterView = nil

            var footerSize = footerView.systemLayoutSizeFitting(CGSize(width: tableView.frame.size.width,
                                                                       height: UIView.layoutFittingCompressedSize.height))
            let visibleHeight = tableView.bounds.size.height - (tableView.adjustedContentInset.top + tableView.adjustedContentInset.bottom)
            let footerHeight = padFooterToBottom ? max(footerSize.height, visibleHeight - tableView.contentSize.height) : footerSize.height

            footerSize.height = footerHeight
            footerView.frame.size = footerSize
            tableView.tableFooterView = footerView
        }
    }
    
}
