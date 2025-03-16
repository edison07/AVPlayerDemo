//
//  Extensions.swift
//  GlossikaPlayer
//
//  Created by Edison on 2025/3/14.
//

import UIKit
import AVFoundation

// MARK: - UIView Extensions
extension UIView {
    func addRoundedCorners(radius: CGFloat) {
        layer.cornerRadius = radius
        layer.masksToBounds = true
    }
    
    func fadeIn(duration: TimeInterval = AnimationConstants.defaultDuration, targetAlpha: CGFloat = 1, completion: ((Bool) -> Void)? = nil) {
        self.alpha = 0
        isHidden = false
        UIView.animate(withDuration: duration, animations: {
            self.alpha = targetAlpha
        }, completion: completion)
    }
    
    func fadeOut(duration: TimeInterval = AnimationConstants.defaultDuration, completion: ((Bool) -> Void)? = nil) {
        UIView.animate(withDuration: duration, animations: {
            self.alpha = 0
        }, completion: { finished in
            self.isHidden = true
            completion?(finished)
        })
    }
}

extension UILabel {
    var isTextExceedOneLine: Bool {
        guard let text = self.text, let font = self.font else { return false }
            
        let maxSize = CGSize(width: self.frame.width, height: .greatestFiniteMagnitude)
        let textHeight = text.boundingRect(
            with: maxSize,
            options: .usesLineFragmentOrigin,
            attributes: [.font: font],
            context: nil
        ).height
            
        return textHeight > font.lineHeight
    }
}

// MARK: - Collection
extension Collection {
    /// 安全地存取集合中的元素，如果索引超出範圍則返回 nil
    subscript(safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

// MARK: - UIInterfaceOrientationMask Extension
extension UIInterfaceOrientationMask {
    // 判斷方向是否為橫向
    var isLandscape: Bool {
        return self == .landscapeRight || self == .landscapeLeft || self == .landscape
    }
}
