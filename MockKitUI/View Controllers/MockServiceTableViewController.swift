//
//  MockServiceSettingsViewController.swift
//  MockKitUI
//
//  Created by Darin Krauss on 5/17/19.
//  Copyright © 2019 LoopKit Authors. All rights reserved.
//

import UIKit
import LoopKit
import LoopKitUI
import MockKit


final class MockServiceTableViewController: ServiceTableViewController {

    private let mockService: MockService

    init(mockService: MockService, for operation: Operation) {
        self.mockService = mockService

        super.init(service: mockService, for: operation)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        tableView.register(SettingsTableViewCell.self, forCellReuseIdentifier: SettingsTableViewCell.className)
        tableView.register(SwitchTableViewCell.nib(), forCellReuseIdentifier: SwitchTableViewCell.className)
        tableView.register(TextButtonTableViewCell.self, forCellReuseIdentifier: TextButtonTableViewCell.className)
    }

    // MARK: - Data Source

    private enum Section: Int, CaseIterable {
        case source
        case history
        case deleteService
    }

    private enum Source: Int, CaseIterable {
        case remoteData
        case logging
        case analytics
    }

    private enum History: Int, CaseIterable {
        case viewHistory
        case clearHistory
    }

    // MARK: - UITableViewDataSource

    override func numberOfSections(in tableView: UITableView) -> Int {
        switch operation {
        case .create:
            return Section.allCases.count - 2   // No history or deleteService
        case .update:
            return Section.allCases.count
        }
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch Section(rawValue: section)! {
        case .source:
            return Source.allCases.count
        case .history:
            return History.allCases.count
        case .deleteService:
            return 1
        }
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch Section(rawValue: section)! {
        case .source:
            return "Source"
        case .history:
            return "History"
        case .deleteService:
            return " " // Use an empty string for more dramatic spacing
        }
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch Section(rawValue: indexPath.section)! {
        case .source:
            let cell = tableView.dequeueReusableCell(withIdentifier: SwitchTableViewCell.className, for: indexPath) as! SwitchTableViewCell
            switch Source(rawValue: indexPath.row)! {
            case .remoteData:
                cell.titleLabel?.text = "Remote Data"
                cell.switch?.isOn = mockService.remoteData
                cell.switch?.addTarget(self, action: #selector(remoteDataChanged(_:)), for: .valueChanged)
            case .logging:
                cell.titleLabel?.text = "Logging"
                cell.switch?.isOn = mockService.logging
                cell.switch?.addTarget(self, action: #selector(loggingChanged(_:)), for: .valueChanged)
            case .analytics:
                cell.titleLabel?.text = "Analytics"
                cell.switch?.isOn = mockService.analytics
                cell.switch?.addTarget(self, action: #selector(analyticsChanged(_:)), for: .valueChanged)
            }
            return cell
        case .history:
            switch History(rawValue: indexPath.row)! {
            case .viewHistory:
                let cell = tableView.dequeueReusableCell(withIdentifier: SettingsTableViewCell.className, for: indexPath) as! SettingsTableViewCell
                cell.textLabel?.text = "View History"
                cell.accessoryType = .disclosureIndicator
                return cell
            case .clearHistory:
                let cell = tableView.dequeueReusableCell(withIdentifier: TextButtonTableViewCell.className, for: indexPath) as! TextButtonTableViewCell
                cell.textLabel?.text = "Clear History"
                cell.tintColor = .delete
                return cell
            }
        case .deleteService:
            let cell = tableView.dequeueReusableCell(withIdentifier: TextButtonTableViewCell.className, for: indexPath) as! TextButtonTableViewCell
            cell.textLabel?.text = "Delete Service"
            cell.textLabel?.textAlignment = .center
            cell.tintColor = .delete
            return cell
        }
    }

    @objc private func remoteDataChanged(_ sender: UISwitch) {
        mockService.remoteData = sender.isOn
    }

    @objc private func loggingChanged(_ sender: UISwitch) {
        mockService.logging = sender.isOn
    }

    @objc private func analyticsChanged(_ sender: UISwitch) {
        mockService.analytics = sender.isOn
    }

    // MARK: - UITableViewDelegate

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        switch Section(rawValue: indexPath.section)! {
        case .source:
            break
        case .history:
            switch History(rawValue: indexPath.row)! {
            case .viewHistory:
                show(MockServiceHistoryViewController.init(mockService: mockService), sender: tableView.cellForRow(at: indexPath))
            case .clearHistory:
                let alert = UIAlertController(clearHistoryHandler: {
                    self.mockService.history = []
                })
                present(alert, animated: true) {
                    tableView.deselectRow(at: indexPath, animated: true)
                }
            }
        case .deleteService:
            confirmDeletion {
                tableView.deselectRow(at: indexPath, animated: true)
            }
        }
    }

}


fileprivate class MockServiceHistoryViewController: UIViewController {

    private let mockService: MockService

    private lazy var textView = UITextView()

    init(mockService: MockService) {
        self.mockService = mockService

        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = textView
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        title = "History"

        textView.contentInsetAdjustmentBehavior = .always
        textView.isEditable = false
        if let font = UIFont(name: "Menlo-Regular", size: 12) {
            textView.font = UIFontMetrics(forTextStyle: .body).scaledFont(for: font)
        }

        textView.text = mockService.history.joined(separator: "\n")

        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .action, target: self, action: #selector(share))
    }

    @objc func share() {
        let timestamp = ISO8601DateFormatter.string(from: Date(), timeZone: .current, formatOptions: [.withInternetDateTime])
        let title = "\(mockService.localizedTitle)_History_\(timestamp).txt"

        let item = SharedResponse(text: textView.text, title: title)

        do {
            try item.write()
        } catch let error {
            present(UIAlertController(with: error), animated: true)
            return
        }

        present(UIActivityViewController(activityItems: [item], applicationActivities: nil), animated: true)
    }

}


fileprivate class SharedResponse: NSObject, UIActivityItemSource {

    private let text: String

    private let title: String
    
    private let url: URL

    init(text: String, title: String) {
        var url = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        url.appendPathComponent(title, isDirectory: false)

        self.text = text
        self.title = title
        self.url = url

        super.init()
    }

    func write() throws {
        try text.write(to: url, atomically: true, encoding: .utf8)
    }

    // MARK: - UIActivityItemSource

    func activityViewControllerPlaceholderItem(_ activityViewController: UIActivityViewController) -> Any {
        return url
    }

    func activityViewController(_ activityViewController: UIActivityViewController, itemForActivityType activityType: UIActivity.ActivityType?) -> Any? {
        return url
    }

    func activityViewController(_ activityViewController: UIActivityViewController, subjectForActivityType activityType: UIActivity.ActivityType?) -> String {
        return title
    }

    func activityViewController(_ activityViewController: UIActivityViewController, dataTypeIdentifierForActivityType activityType: UIActivity.ActivityType?) -> String {
        return "public.utf8-plain-text"
    }

}


fileprivate extension UIAlertController {

    convenience init(clearHistoryHandler handler: @escaping () -> Void) {
        self.init(title: nil, message: "Are you sure you want to clear the history?", preferredStyle: .actionSheet)
        addAction(UIAlertAction(title: "Clear History", style: .destructive, handler: { _ in handler() }))
        addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
    }

}
