//
//  MediaService.swift
//  GlossikaPlayer
//
//  Created by Edison on 2025/3/12.
//
import Foundation

class MediaService {
    func fetchMedia() async throws -> VideoPlayerModel.MediaJSON {
        guard let url = Bundle.main.url(forResource: "media", withExtension: "json") else {
            throw NSError(domain: "MediaService", code: 404, userInfo: [NSLocalizedDescriptionKey: "Media JSON not found"])
        }
        let data = try Data(contentsOf: url)
        let media = try JSONDecoder().decode(VideoPlayerModel.MediaJSON.self, from: data)
        return media
    }
}

