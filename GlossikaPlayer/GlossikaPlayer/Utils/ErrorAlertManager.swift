//
//  ErrorAlertManager.swift
//  GlossikaPlayer
//
//  Created by Edison on 2025/3/12.
//
import UIKit

protocol AlertManagerProtocol {
    static func showErrorAlert(on viewController: UIViewController, message: String)
    static func showAlert(on viewController: UIViewController, title: String, message: String, actions: [UIAlertAction])
}

struct ErrorAlertManager: AlertManagerProtocol {
    static func showErrorAlert(on viewController: UIViewController, message: String) {
        showAlert(
            on: viewController,
            title: "錯誤",
            message: message,
            actions: [UIAlertAction(title: "確定", style: .default)]
        )
    }
    
    static func showAlert(on viewController: UIViewController, title: String, message: String, actions: [UIAlertAction]) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        actions.forEach { alert.addAction($0) }
        viewController.present(alert, animated: true)
    }
}
