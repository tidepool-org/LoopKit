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
    
    open override func viewDidLoad() {
        super.viewDidLoad()
        tableView.register(SectionHeaderView.self, forHeaderFooterViewReuseIdentifier: SectionHeaderView.reuseIdentifier)
        tableView.sectionFooterHeight = UITableView.automaticDimension
        tableView.estimatedSectionFooterHeight = 10
        tableView.sectionHeaderHeight = UITableView.automaticDimension
        tableView.estimatedSectionHeaderHeight = 70
    }
    
    override open func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        guard section == 0 else {
            return nil
        }
        return tableViewTitle
    }
    
    override open func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        guard let headerTitle = self.tableView(tableView, titleForHeaderInSection: section) else {
            return nil
        }

        guard let view = tableView.dequeueReusableHeaderFooterView(withIdentifier: SectionHeaderView.reuseIdentifier) as? SectionHeaderView else {
            return nil
        }

        view.title.text = headerTitle
        switch section {
        case 0:
            view.title.font = .preferredFont(forTextStyle: .title2)
        default:
            view.title.font = .preferredFont(forTextStyle: .headline)
        }

        return view
    }
    
    override open func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        guard self.tableView(tableView, titleForHeaderInSection: section) != nil else {
            // when there is no title for the header, remove the spacing
            return .leastNormalMagnitude
        }
        return UITableView.automaticDimension
    }
    
    override open func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        guard self.tableView(tableView, titleForFooterInSection: section) != nil else {
            // collaspe the footer when there is no title to display
            return 10
        }
        return UITableView.automaticDimension
    }
}

class SectionHeaderView: UITableViewHeaderFooterView, IdentifiableClass {
    static let reuseIdentifier: String = SectionHeaderView.className

    var title = TableViewTitleLabel()

    override init(reuseIdentifier: String?) {
        super.init(reuseIdentifier: reuseIdentifier)

        contentView.addSubview(title)
        
        title.translatesAutoresizingMaskIntoConstraints = false
        title.leadingAnchor.constraint(equalTo: contentView.leadingAnchor).isActive = true
        title.trailingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.trailingAnchor).isActive = true
        title.topAnchor.constraint(equalTo: contentView.layoutMarginsGuide.topAnchor).isActive = true
        title.bottomAnchor.constraint(equalToSystemSpacingBelow: contentView.layoutMarginsGuide.bottomAnchor, multiplier: -1).isActive = true
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
}
