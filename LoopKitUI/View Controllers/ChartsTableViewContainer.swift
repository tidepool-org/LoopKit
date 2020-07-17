//
//  ChartsTableViewController2.swift
//  LoopKitUI
//
//  Copyright © 2017 LoopKit Authors. All rights reserved.
//

import UIKit
import HealthKit
import os.log

public protocol ChartsTableViewControllerDelegate: class {
    var preferredUnit: HKUnit { get }
    var healthStore: HKHealthStore { get }
}

/// Abstract class providing boilerplate setup for chart-based table view controllers
open class ChartsTableViewContainer: UITableViewController, UIGestureRecognizerDelegate {
    
    public weak var delegate: ChartsTableViewControllerDelegate? {
        didSet {
            NotificationCenter.default.addObserver(self, selector: #selector(unitPreferencesDidChange(_:)), name: .HKUserPreferencesDidChange, object: delegate?.healthStore)
        }
    }

    private let log = OSLog(category: "ChartsTableViewContainer")

    open override func viewDidLoad() {
        super.viewDidLoad()
        
        if let unit = delegate?.preferredUnit {
            self.charts.setGlucoseUnit(unit)
        }

        let notificationCenter = NotificationCenter.default

        notificationObservers += [
            notificationCenter.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: .main) { [weak self] _ in
                self?.active = false
            },
            notificationCenter.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
                self?.active = true
            }
        ]

        let gestureRecognizer = UILongPressGestureRecognizer()
        gestureRecognizer.delegate = self
        gestureRecognizer.minimumPressDuration = 0.1
        gestureRecognizer.addTarget(self, action: #selector(handlePan(_:)))
        charts.gestureRecognizer = gestureRecognizer
    }

    open override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()

        if !visible {
            charts.didReceiveMemoryWarning()
        }
    }

    open override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        visible = true
    }

    open override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        visible = false
    }

    open override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)

        log.debug("[reloadData] for view transition to size: %@", String(describing: size))
        reloadData(animated: false)
    }

    open override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)

        charts.traitCollection = traitCollection
    }

    deinit {
        for observer in notificationObservers {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    // MARK: - State
    
    @objc private func unitPreferencesDidChange(_ note: Notification) {
        DispatchQueue.main.async {
            if let unit = self.delegate?.preferredUnit {
                self.charts.setGlucoseUnit(unit)

                self.glucoseUnitDidChange()
            }
            self.log.debug("[reloadData] for HealthKit unit preference change")
            self.reloadData()
        }
    }
    
    

    open func glucoseUnitDidChange() {
        // To override.
    }

    open func createChartsManager() -> ChartsManager {
        fatalError("Subclasses must implement \(#function)")
    }

    lazy public private(set) var charts = createChartsManager()

    // References to registered notification center observers
    public var notificationObservers: [Any] = []

    open var active: Bool = true {
        didSet {
            log.debug("[reloadData] for app change to active: %d, applicationState: %d", active)
            reloadData()
        }
    }

    public var visible = false {
        didSet {
            log.debug("[reloadData] for view change to visible: %d", visible)
            reloadData()
        }
    }

    // MARK: - Data loading

    /// Refetches all data and updates the views. Must be called on the main queue.
    ///
    /// - Parameters:
    ///   - animated: Whether the updating should be animated if possible
    open func reloadData(animated: Bool = false) {

    }

    // MARK: - UIGestureRecognizer

    public func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        /// Only start the long-press recognition when it starts in a chart cell
        let point = gestureRecognizer.location(in: tableView)
        if let indexPath = tableView.indexPathForRow(at: point) {
            if let cell = tableView.cellForRow(at: indexPath), cell is ChartTableViewCell {
                return true
            }
        }

        return false
    }

    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }

    @objc func handlePan(_ gestureRecognizer: UIGestureRecognizer) {
        switch gestureRecognizer.state {
        case .possible, .changed:
            // Follow your dreams!
            break
        case .began, .cancelled, .ended, .failed:
            for case let row as ChartTableViewCell in self.tableView.visibleCells {
                let forwards = gestureRecognizer.state == .began
                UIView.animate(withDuration: forwards ? 0.2 : 0.5, delay: forwards ? 0 : 1, animations: {
                    let alpha: CGFloat = forwards ? 0 : 1
                    row.titleLabel?.alpha = alpha
                    row.subtitleLabel?.alpha = alpha
                })
            }
        @unknown default:
            break
        }
    }
}

fileprivate extension ChartsManager {
    func setGlucoseUnit(_ unit: HKUnit) {
        for case let chart as GlucoseChart in charts {
            chart.glucoseUnit = unit
        }
    }
}