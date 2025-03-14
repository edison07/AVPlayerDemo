//
//  AppError.swift
//  GlossikaPlayer
//
//  Created by Edison on 2025/3/14.
//

import Foundation

enum AppError: Error {
    case mediaNotFound
    case decodingError(Error)
    
    var localizedDescription: String {
        switch self {
        case .mediaNotFound:
            return "找不到媒體檔案"
        case .decodingError(let error):
            return "媒體檔案解析失敗: \(error.localizedDescription)"
        }
    }
} 
