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
