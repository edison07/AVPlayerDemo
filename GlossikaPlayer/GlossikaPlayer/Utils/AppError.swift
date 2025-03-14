//
//  AppError.swift
//  GlossikaPlayer
//
//  Created by Edison on 2025/3/14.
//

import Foundation

enum AppError: Error {
    case mediaNotFound
    case decodingError(DecodingError)
}

extension AppError: Equatable {
    static func == (lhs: AppError, rhs: AppError) -> Bool {
        switch (lhs, rhs) {
        case (.mediaNotFound, .mediaNotFound):
            return true
        case (.decodingError, .decodingError):
            return true
        default:
            return false
        }
    }
} 
