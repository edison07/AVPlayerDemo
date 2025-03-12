//
//  Untitled.swift
//  GlossikaPlayer
//
//  Created by Edison on 2025/3/12.
//
import UIKit

struct ErrorAlertManager {
    static func showErrorAlert(on viewController: UIViewController, message: String) {
        let alert = UIAlertController(title: "錯誤", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "確定", style: .default))
        viewController.present(alert, animated: true)
    }
}
