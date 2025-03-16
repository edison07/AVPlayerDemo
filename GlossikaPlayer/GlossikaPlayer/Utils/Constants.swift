//
//  Constants.swift
//  GlossikaPlayer
//
//  Created by Edison on 2025/3/12.
//
import Foundation

// MARK: - UI Constants
enum IconConstants {
    static let portraitIcon = "arrow.up.left.and.arrow.down.right"
    static let landscapeIcon = "arrow.down.right.and.arrow.up.left"
    static let playIcon = "play.fill"
    static let pauseIcon = "pause.fill"
    static let skipForwardIcon = "goforward.10"
    static let skipBackwardIcon = "gobackward.10"
}

// MARK: - Time Constants
enum TimeConstants {
    static let timeScale: Int32 = 600
    static let defaultSkipInterval: Double = 10.0
    static let seekUpdateInterval: Double = 0.5
    static let defaultTimeText = "00:00"
    static let controlsFadeOutTime: UInt64 = 2_000_000_000 
}

// MARK: - Animation Constants
enum AnimationConstants {
    static let defaultDuration: TimeInterval = 0.3
    static let fastDuration: Double = 0.15
    static let slowDuration: Double = 0.5
}

// MARK: - UIConstants
enum UIConstants {
    static let showMoreText = "顯示更多.."
    static let showLessText = "顯示更少.."
}
