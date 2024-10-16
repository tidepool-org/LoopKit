//
//  StatusChartHighlightLayer.swift
//  Naterade
//
//  Created by Nathan Racklyeft on 2/28/16.
//  Copyright © 2016 Nathan Racklyeft. All rights reserved.
//

import Foundation
import SwiftCharts
import UIKit

final class ChartPointsTouchHighlightLayerViewCache {
    static let defaultPointSize: CGFloat = 16
    
    private lazy var containerView = UIView(frame: .zero)

    private lazy var xAxisOverlayView = UIView()

    private lazy var point = ChartPointEllipseView(center: .zero, diameter: ChartPointsTouchHighlightLayerViewCache.defaultPointSize)

    private lazy var labelY: UILabel = {
        let label = UILabel()
        label.font = UIFont.monospacedDigitSystemFont(ofSize: 15, weight: UIFont.Weight.bold)

        return label
    }()

    private lazy var labelX: UILabel = {
        let label = UILabel()
        label.font = self.axisLabelSettings.font
        label.textColor = self.axisLabelSettings.fontColor

        return label
    }()

    private let axisLabelSettings: ChartLabelSettings

    private(set) var highlightLayer: ChartPointsTouchHighlightLayer<ChartPoint, UIView>!

    init(xAxisLayer: ChartAxisLayer, yAxisLayer: ChartAxisLayer, axisLabelSettings: ChartLabelSettings, chartPoints: [ChartPoint], tintColor: UIColor, allowOverridingTintColor: Bool = false, allowOverridingHighlightPointSize: Bool = false, highlightPointOffsetY: CGFloat = 0, gestureRecognizer: UIGestureRecognizer? = nil, onCompleteHighlight: (() -> Void)? = nil) {

        self.axisLabelSettings = axisLabelSettings

        highlightLayer = ChartPointsTouchHighlightLayer(
            xAxis: xAxisLayer.axis,
            yAxis: yAxisLayer.axis,
            chartPoints: chartPoints,
            gestureRecognizer: gestureRecognizer,
            onCompleteHighlight: onCompleteHighlight,
            modelFilter: { (screenLoc, chartPointModels) -> ChartPointLayerModel<ChartPoint>? in
                if let index = chartPointModels.map({ $0.screenLoc.x }).findClosestElementIndex(matching: screenLoc.x) {
                    return chartPointModels[index]
                } else {
                    return nil
                }
            },
            viewGenerator: { [weak self] (chartPointModel, layer, chart) -> UIView? in
                guard let strongSelf = self else {
                    return nil
                }

                let containerView = strongSelf.containerView
                containerView.frame = chart.contentView.bounds
                containerView.alpha = 1  // This is animated to 0 when touch last ended

                let xAxisOverlayView = strongSelf.xAxisOverlayView
                if xAxisOverlayView.superview == nil {
                    xAxisOverlayView.frame = CGRect(
                        origin: CGPoint(x: containerView.bounds.minX,
                                        y: containerView.bounds.maxY + 1), // Don't clip X line
                        size: xAxisLayer.frame.size
                    )
                    xAxisOverlayView.backgroundColor = .systemBackground
                    xAxisOverlayView.isOpaque = true
                    containerView.addSubview(xAxisOverlayView)
                }
                
                // For charts with overridden tint colors or highlight point sizes, calculate new values
                // If old values don't match new values, refresh the view
                let newColor = chartPointModel.chartPoint.overrideColor ?? tintColor
                let newPointSize = chartPointModel.chartPoint.overrideHighlightPointSize ?? ChartPointsTouchHighlightLayerViewCache.defaultPointSize
                
                let point = strongSelf.point
                point.center = CGPoint(x: chartPointModel.screenLoc.x, y: chartPointModel.screenLoc.y + highlightPointOffsetY)
                if point.superview == nil || (allowOverridingTintColor && point.fillColor != newColor) {
                    // Color the point when view is initialized and every time overridden tint color does not match previous value
                    point.fillColor = newColor
                    point.setNeedsDisplay()
                }
                if allowOverridingHighlightPointSize && point.frame.width != newPointSize {
                    // Change the points's frame each time the overridden point size changes and correct it's location
                    point.frame.size = CGSize(width: newPointSize, height: newPointSize)
                    point.center = CGPoint(x: chartPointModel.screenLoc.x, y: chartPointModel.screenLoc.y + highlightPointOffsetY)
                }
                if point.superview == nil {
                    point.alpha = 0.5
                    containerView.addSubview(point)
                }

                if let text = chartPointModel.chartPoint.y.labels.first?.text {
                    let label = strongSelf.labelY

                    label.text = text
                    label.sizeToFit()
                    label.center.y = containerView.frame.minY - 21
                    label.center.x = chartPointModel.screenLoc.x
                    label.frame.origin.x = min(max(label.frame.origin.x, containerView.bounds.minX), containerView.bounds.maxX - label.frame.size.width)
                    label.frame.origin.makeIntegralInPlaceWithDisplayScale(chart.view.traitCollection.displayScale)

                    if label.superview == nil || (allowOverridingTintColor && label.textColor != newColor) {
                        // Color the label when view is initialized and every time overridden tint color does not match previous value
                        label.textColor = newColor
                    }
                    if label.superview == nil {
                        containerView.addSubview(label)
                    }
                }

                if let text = chartPointModel.chartPoint.x.labels.first?.text {
                    let label = strongSelf.labelX
                    label.text = text
                    label.sizeToFit()
                    label.center = CGPoint(x: chartPointModel.screenLoc.x, y: xAxisOverlayView.center.y)
                    label.frame.origin.makeIntegralInPlaceWithDisplayScale(chart.view.traitCollection.displayScale)

                    if label.superview == nil {
                        containerView.addSubview(label)
                    }
                }
                
                return containerView
            }
        )
    }
}
