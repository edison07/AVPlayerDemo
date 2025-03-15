//
//  MediaService.swift
//  GlossikaPlayer
//
//  Created by Edison on 2025/3/12.
//
import Foundation
import Combine

// MARK: - MediaService Protocol
protocol MediaServiceProtocol {
    func fetchMedia() -> AnyPublisher<VideoPlayerModel.MediaJSON, Error>
}

// MARK: - MediaService Implementation
final class MediaService: MediaServiceProtocol {
    // MARK: - Public Methods
    func fetchMedia() -> AnyPublisher<VideoPlayerModel.MediaJSON, Error> {
        guard let url = Bundle.main.url(forResource: "media", withExtension: "json") else {
            return Fail(error: AppError.mediaNotFound).eraseToAnyPublisher()
        }
        
        return Future { promise in
            do {
                let data = try Data(contentsOf: url)
                let mediaJSON = try JSONDecoder().decode(VideoPlayerModel.MediaJSON.self, from: data)
                promise(.success(mediaJSON))
            } catch let error as DecodingError {
                promise(.failure(AppError.decodingError(error)))
            } catch {
                promise(.failure(error))
            }
        }
        .eraseToAnyPublisher()
    }
}

final class MockMediaService: MediaServiceProtocol {
    func fetchMedia() -> AnyPublisher<VideoPlayerModel.MediaJSON, Error> {
        let fakeMedia = VideoPlayerModel.MediaJSON(categories: [
            VideoPlayerModel.Category(
                name: "教育",
                videos: [
                    VideoPlayerModel.Video(
                        description: "介紹 Swift 基礎語法與使用方式",
                        sources: ["https://example.com/swift_basics.mp4"],
                        subtitle: "Swift 基礎教學字幕",
                        thumb: "https://example.com/swift_thumb.png",
                        title: "Swift 基礎"
                    ),
                    VideoPlayerModel.Video(
                        description: "學習如何使用 Combine 框架",
                        sources: ["https://example.com/combine_intro.mp4"],
                        subtitle: "Combine 教學字幕",
                        thumb: "https://example.com/combine_thumb.png",
                        title: "Combine 入門"
                    )
                ]
            ),
            VideoPlayerModel.Category(
                name: "娛樂",
                videos: [
                    VideoPlayerModel.Video(
                        description: "爆笑貓咪搞怪影片集",
                        sources: ["https://example.com/funny_cats.mp4"],
                        subtitle: "貓咪搞怪字幕",
                        thumb: "https://example.com/cats_thumb.png",
                        title: "爆笑貓咪"
                    )
                ]
            )
        ])
        return Just(fakeMedia)
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
}

final class FailingMediaService: MediaServiceProtocol {
    func fetchMedia() -> AnyPublisher<VideoPlayerModel.MediaJSON, Error> {
        return Fail(error: AppError.mediaNotFound)
            .eraseToAnyPublisher()
    }
}
