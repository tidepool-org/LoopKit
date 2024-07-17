//
//  CustomAlert.swift
//  LoopKit
//
//  Created by Cameron Ingham on 7/17/24.
//  Copyright © 2024 LoopKit Authors. All rights reserved.
//

import SwiftUI

public struct CustomAlertPresenter: UIViewControllerRepresentable {
    public struct CustomAlert {
        public struct AlertAction {
            let title: String?
            let style: UIAlertAction.Style
            let handler: ((UIAlertAction) -> Void)
            
            public init(title: String?, style: UIAlertAction.Style, handler: ((UIAlertAction) -> Void)? = nil) {
                self.title = title
                self.style = style
                self.handler = handler ?? { _ in }
            }
        }
        
        let image: UIImage?
        let imageBounds: (NSTextAttachment) -> CGRect
        let title: String?
        let message: String?
        let primaryAction: AlertAction?
        let secondaryAction: AlertAction?
        
        public init(
            image: UIImage?,
            imageBounds: @escaping (NSTextAttachment) -> CGRect = { titleImageAttachment in
                CGRect(x: titleImageAttachment.bounds.origin.x, y: -10, width: 40, height: 35)
            },
            title: String?,
            message: String?,
            primaryAction: AlertAction?,
            secondaryAction: AlertAction?
        ) {
            self.image = image
            self.imageBounds = imageBounds
            self.title = title
            self.message = message
            self.primaryAction = primaryAction
            self.secondaryAction = secondaryAction
        }
    }
    
    public class CustomAlertPresentingViewController: UIViewController {
        var alertController: UIAlertController?
        
        let alertBinding: Binding<CustomAlert?>
        
        public init(alertBinding: Binding<CustomAlert?>) {
            self.alertBinding = alertBinding
            super.init(nibName: nil, bundle: nil)
        }
        
        public required init?(coder: NSCoder) {
            fatalError()
        }
        
        var alert: CustomAlert? {
            didSet {
                if let alert {
                    alertController = UIAlertController(title: alert.title, message: alert.message, preferredStyle: .alert)
                    
                    if let title = alert.title {
                        let titleImageAttachment = NSTextAttachment()
                        titleImageAttachment.image = alert.image
                        titleImageAttachment.bounds = alert.imageBounds(titleImageAttachment)
                        let titleWithImage = NSMutableAttributedString(attachment: titleImageAttachment)
                        titleWithImage.append(NSMutableAttributedString(string: "\n\n", attributes: [.font: UIFont.systemFont(ofSize: 8)]))
                        titleWithImage.append(NSMutableAttributedString(string: title, attributes: [.font: UIFont.preferredFont(forTextStyle: .headline)]))
                        alertController?.setValue(titleWithImage, forKey: "attributedTitle")
                    }
                    
                    if let primaryAction = alert.primaryAction {
                        alertController?.addAction(UIAlertAction(title: primaryAction.title, style: primaryAction.style, handler: { [weak self] action in
                            self?.alertBinding.wrappedValue = nil
                            primaryAction.handler(action)
                        }))
                    }
                    
                    if let secondaryAction = alert.secondaryAction {
                        alertController?.addAction(UIAlertAction(title: secondaryAction.title, style: secondaryAction.style, handler: { [weak self] action in
                            self?.alertBinding.wrappedValue = nil
                            secondaryAction.handler(action)
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
    
    @Binding var alert: CustomAlert?
    
    public func makeUIViewController(context: Context) -> CustomAlertPresentingViewController {
        CustomAlertPresentingViewController(alertBinding: $alert)
    }
    
    public func updateUIViewController(_ uiViewController: CustomAlertPresentingViewController, context: Context) {
        uiViewController.alert = alert
    }
}

public extension View {
    @ViewBuilder
    func customAlert(item: Binding<CustomAlertPresenter.CustomAlert?>) -> some View {
        self.background(CustomAlertPresenter(alert: item))
    }
}

