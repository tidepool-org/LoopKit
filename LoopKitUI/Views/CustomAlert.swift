//
//  CustomAlert.swift
//  LoopKit
//
//  Created by Cameron Ingham on 7/17/24.
//  Copyright © 2024 LoopKit Authors. All rights reserved.
//

import SwiftUI

public struct CustomAlert {
    public enum ImageOption {
        case warning
        case custom(
            UIImage?,
            bounds: (NSTextAttachment) -> CGRect
        )
    }
    
    let image: ImageOption?
    let title: String?
    let message: String?
    let primaryAction: UIAlertAction?
    let secondaryAction: UIAlertAction?
    
    public init(
        image: ImageOption?,
        title: String?,
        message: String?,
        primaryAction: UIAlertAction?,
        secondaryAction: UIAlertAction?
    ) {
        self.image = image
        self.title = title
        self.message = message
        self.primaryAction = primaryAction
        self.secondaryAction = secondaryAction
    }
}

public struct CustomAlertPresenter: UIViewControllerRepresentable {
    
    @Environment(\.guidanceColors) private var guidanceColors
    
    public class CustomAlertPresentingViewController: UIViewController {
        private var alertController: UIAlertController?
        
        private let alertBinding: Binding<CustomAlert?>
        private let guidanceColors: GuidanceColors
        
        fileprivate init(alertBinding: Binding<CustomAlert?>, guidanceColors: GuidanceColors) {
            self.alertBinding = alertBinding
            self.guidanceColors = guidanceColors
            super.init(nibName: nil, bundle: nil)
        }
        
        public required init?(coder: NSCoder) {
            fatalError()
        }
        
        fileprivate var alert: CustomAlert? {
            didSet {
                if let alert {
                    alertController = UIAlertController(title: alert.title, message: alert.message, preferredStyle: .alert)
                    
                    if let title = alert.title, let image = alert.image {
                        let titleImageAttachment = NSTextAttachment()
                        switch image {
                        case .warning:
                            titleImageAttachment.image = UIImage(systemName: "exclamationmark.triangle.fill")?.withTintColor(UIColor(guidanceColors.critical))
                            titleImageAttachment.bounds = CGRect(x: titleImageAttachment.bounds.origin.x, y: -10, width: 40, height: 35)
                        case let .custom(uIImage, bounds):
                            titleImageAttachment.image = uIImage
                            titleImageAttachment.bounds = bounds(titleImageAttachment)
                        }
                        
                        let titleWithImage = NSMutableAttributedString(attachment: titleImageAttachment)
                        titleWithImage.append(NSMutableAttributedString(string: "\n\n", attributes: [.font: UIFont.systemFont(ofSize: 8)]))
                        titleWithImage.append(NSMutableAttributedString(string: title, attributes: [.font: UIFont.preferredFont(forTextStyle: .headline)]))
                        alertController?.setValue(titleWithImage, forKey: "attributedTitle")
                    }
                    
                    typealias AlertHandler = @convention(block) (UIAlertAction) -> Void
                    
                    if let primaryAction = alert.primaryAction {
                        alertController?.addAction(UIAlertAction(title: primaryAction.title, style: primaryAction.style, handler: { [weak self] action in
                            self?.alertBinding.wrappedValue = nil
                            let block = primaryAction.value(forKey: "handler")
                            let handler = unsafeBitCast(block as AnyObject, to: AlertHandler.self)
                            handler(action)
                        }))
                    }
                    
                    if let secondaryAction = alert.secondaryAction {
                        alertController?.addAction(UIAlertAction(title: secondaryAction.title, style: secondaryAction.style, handler: { [weak self] action in
                            self?.alertBinding.wrappedValue = nil
                            let block = secondaryAction.value(forKey: "handler")
                            let handler = unsafeBitCast(block as AnyObject, to: AlertHandler.self)
                            handler(action)
                        }))
                    }
                    
                    if let alertController {
                        present(alertController, animated: true)
                    }
                } else {
                    alertController?.dismiss(animated: true, completion: { [weak self] in self?.alertController = nil })
                }
            }
        }
    }
    
    @Binding fileprivate var alert: CustomAlert?
    
    public func makeUIViewController(context: Context) -> CustomAlertPresentingViewController {
        CustomAlertPresentingViewController(alertBinding: $alert, guidanceColors: guidanceColors)
    }
    
    public func updateUIViewController(_ uiViewController: CustomAlertPresentingViewController, context: Context) {
        uiViewController.alert = alert
    }
}

public extension View {
    @ViewBuilder
    func customAlert(item: Binding<CustomAlert?>) -> some View {
        self.background(CustomAlertPresenter(alert: item))
    }
}

