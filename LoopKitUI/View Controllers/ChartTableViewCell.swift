//
//  ChartTableViewCell.swift
//  Naterade
//
//  Created by Nathan Racklyeft on 2/19/16.
//  Copyright © 2016 Nathan Racklyeft. All rights reserved.
//

import UIKit


public final class ChartTableViewCell: UITableViewCell {

    @IBOutlet weak var chartContentView: ChartContainerView!

    @IBOutlet weak var titleLabel: UILabel?

    @IBOutlet weak var subtitleLabel: UILabel?

    public override func prepareForReuse() {
        super.prepareForReuse()

        chartContentView.chartGenerator = nil
    }

    public func reloadChart() {
        chartContentView.reloadChart()
    }
}
