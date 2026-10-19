//
//  ChartContainerView.swift
//  LoopKitUI
//
//  Created by Nate Racklyeft on 9/14/16.
//  Copyright © 2016 Nathan Racklyeft. All rights reserved.
//

import UIKit

public class ChartContainerView: UIView {

    /// Heights at or below this are skipped, since they may be requested mid-animation.
    /// Lower it for compact charts that legitimately render in a short container.
    public var minimumChartHeight: CGFloat = 50

    override public func layoutSubviews() {
        super.layoutSubviews()

        if chartView == nil || chartView!.frame != bounds {
            if bounds.height > minimumChartHeight {
                chartView = chartGenerator?(bounds)
            }
        } else if chartView!.superview == nil {
            addSubview(chartView!)
        }
    }

    public func reloadChart() {
        chartView = nil
        setNeedsLayout()
    }

    public var chartGenerator: ((CGRect) -> UIView?)? {
        didSet {
            chartView = nil
            setNeedsLayout()
        }
    }

    private var chartView: UIView? {
        didSet {
            if let view = oldValue {
                view.removeFromSuperview()
            }

            if let view = chartView {
                self.addSubview(view)
            }
        }
    }

}
