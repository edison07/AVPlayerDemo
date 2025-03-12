//
//  VideoPlayerModel.swift
//  GlossikaPlayer
//
//  Created by Edison on 2025/3/10.
//
import Foundation

struct VideoPlayerModel {
    struct MediaJSON: Codable {
        let categories: [Category]
    }

    struct Category: Codable {
        let name: String
        let videos: [Video]
    }

    struct Video: Codable {
        let description: String
        let sources: [String]
        let subtitle: String
        let thumb: String
        let title: String
    }
}
