//
//  VideoPlayerViewModel.swift
//  GlossikaPlayer
//
//  Created by Edison on 2025/3/10.
//

import AVKit
import Combine

final class VideoPlayerViewModel {
    typealias VideoDetail = (title: String, subtitle: String, description: String)
    typealias VideoTime = (current: String, duration: String)
    // MARK: - Published Properties
    @Published private(set) var isPlaying: Bool = false
    @Published private(set) var isReadyToPlay: Bool = false
    @Published private(set) var progress: Double = 0.0
    @Published private(set) var videoTimeText: VideoTime = (TimeConstants.defaultTimeText, TimeConstants.defaultTimeText)
    @Published private(set) var errorMessage: String?
    @Published private(set) var media: VideoPlayerModel.MediaJSON?
    @Published private(set) var videoDetail: VideoDetail?
    @Published private(set) var seekTimeText: String = TimeConstants.defaultTimeText
    @Published private(set) var currentVideoIndex = 0
    // MARK: - Private Properties
    private let player: AVPlayer
    private var playerLayer: AVPlayerLayer?
    private var cancellables = Set<AnyCancellable>()
    private var timeObserverToken: Any?
    private let mediaService: MediaServiceProtocol
    
    // MARK: - Public Properties
    var isSeeking: Bool = false
    
    // MARK: - Initialization
    init(mediaService: MediaServiceProtocol = MediaService()) {
        self.player = AVPlayer()
        self.mediaService = mediaService
        fetchMediaData()
    }
    
    deinit {
        if let token = timeObserverToken {
            player.removeTimeObserver(token)
        }
    }
    
    // MARK: - Public Methods
    func setupPlayer() {
        player.play()
        isPlaying = true
    }
    
    func attachPlayerLayer(to view: UIView) {
        playerLayer?.removeFromSuperlayer()
        let layer = AVPlayerLayer(player: player)
        layer.frame = view.bounds
        layer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(layer)
        playerLayer = layer
    }
    
    func updatePlayerLayerFrame(to frame: CGRect) {
        playerLayer?.frame = frame
    }
    
    func updateVideo(at index: Int) {
        currentVideoIndex = index
        guard let video = media?.categories.first?.videos[index],
              let urlString = video.sources.first,
              let videoURL = URL(string: urlString) else {
            self.errorMessage = "影片載入失敗"
            return
        }
        pause()
        let asset = AVURLAsset(url: videoURL)
        let newItem = AVPlayerItem(asset: asset)
        player.replaceCurrentItem(with: newItem)
        
        resetObservers(for: newItem)
        setupPlayer()
    }
    
    func togglePlayPause() {
        guard let currentItem = player.currentItem else { return }
        if isPlaying {
            player.pause()
            isPlaying = false
        } else {
            let currentTime = currentItem.currentTime().seconds
            let duration = currentItem.duration.seconds
            
            if currentTime == duration {
                player.seek(to: .zero) { [weak self] finished in
                    guard let self else { return }
                    
                    if finished {
                        self.player.play()
                        self.isPlaying = true
                    }
                }
            } else {
                player.play()
                isPlaying = true
            }
        }
    }
    
    func pause() {
        player.pause()
        isPlaying = false
    }
    
    func seek(to progress: Double) {
        guard let playerItem = player.currentItem, playerItem.duration.seconds > 0 else { return }

        Task { [weak self] in
            guard let self else { return }
            defer { self.isSeeking = false }
            let durationSeconds = playerItem.duration.seconds
            let newTimeSeconds = progress * durationSeconds
            let targetTime = CMTime(seconds: newTimeSeconds, preferredTimescale: TimeConstants.timeScale)
            
            _ = await player.seek(to: targetTime, toleranceBefore: .zero, toleranceAfter: .zero)
        }
    }
    
    func nextVideo() {
        guard let count = media?.categories.first?.videos.count, count > 0 else { return }
        
        let index = (currentVideoIndex + 1) % count
        updateVideo(at: index)
    }
    
    func prevVideo() {
        guard let count = media?.categories.first?.videos.count, count > 0 else { return }
        
        let index = (currentVideoIndex - 1 + count) % count
        updateVideo(at: index)
    }
    
    func skipForward(by seconds: Double = TimeConstants.defaultSkipInterval) {
        guard let durationSeconds = player.currentItem?.duration.seconds, durationSeconds.isFinite else { return }
        let currentTime = player.currentTime().seconds
        let newTime = min(currentTime + seconds, durationSeconds)
        player.seek(to: CMTime(seconds: newTime, preferredTimescale: TimeConstants.timeScale))
    }
    
    func skipBackward(by seconds: Double = TimeConstants.defaultSkipInterval) {
        let currentTime = player.currentTime().seconds
        let newTime = max(currentTime - seconds, 0)
        player.seek(to: CMTime(seconds: newTime, preferredTimescale: TimeConstants.timeScale))
    }
    
    func setPlaybackRate(_ rate: Float) {
        player.rate = rate
    }
    
    func updateProgress(to progress: Double) {
        guard let duration = player.currentItem?.duration.seconds, duration > 0, duration.isFinite else {
            seekTimeText = TimeConstants.defaultTimeText
            return
        }
        let newTime = progress * duration
        seekTimeText = formatTime(newTime)
    }
}

// MARK: - Private Methods
private extension VideoPlayerViewModel {
    func setupPlayerSettings() {
        player.automaticallyWaitsToMinimizeStalling = true
        try? AVAudioSession.sharedInstance().setCategory(.playback)
    }
    
    func setupTimeObserver() {
        removeTimeObserver()
        
        let interval = CMTime(seconds: TimeConstants.seekUpdateInterval, preferredTimescale: TimeConstants.timeScale)
        timeObserverToken = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let self else { return }
            let currentTime = time.seconds
            let duration = self.player.currentItem?.duration.seconds ?? 0
            
            // 避免處理無效的時間
            if currentTime.isFinite && duration.isFinite && duration > 0 {
                self.videoTimeText = (self.formatTime(currentTime), self.formatTime(duration))
                guard !self.isSeeking else { return }
                self.progress = min(currentTime / duration, 1.0)
            }
        }
    }
    
    func removeTimeObserver() {
        if let token = timeObserverToken {
            player.removeTimeObserver(token)
            timeObserverToken = nil
        }
    }
    
    func observePlayerItem(_ playerItem: AVPlayerItem) {
        // 監聽播放項目狀態變化
        playerItem.publisher(for: \.status)
            .sink { [weak self] status in
                guard let self else { return }
                switch status {
                case .readyToPlay:
                    self.isReadyToPlay = true
                    self.errorMessage = nil
                    guard let videoDetail = media?.categories.first?.videos[safe: currentVideoIndex] else { return }
                    self.videoDetail = (title: videoDetail.title, subtitle: videoDetail.subtitle, videoDetail.description)
                case .failed:
                    self.isReadyToPlay = false
                    if let error = playerItem.error {
                        self.errorMessage = error.localizedDescription
                    } else {
                        self.errorMessage = "影片載入失敗"
                    }
                default:
                    self.isReadyToPlay = false
                }
            }
            .store(in: &cancellables)
        
        // 監聽播放結束通知
        NotificationCenter.default.publisher(for: .AVPlayerItemDidPlayToEndTime, object: playerItem)
            .sink { [weak self] _ in
                guard let self else { return }
                self.nextVideo()
            }
            .store(in: &cancellables)
    }
    
    // 格式化時間為分:秒格式
    func formatTime(_ seconds: Double) -> String {
        guard !seconds.isNaN && seconds.isFinite else { return TimeConstants.defaultTimeText }
        let minutes = Int(seconds) / 60
        let seconds = Int(seconds) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    func fetchMediaData() {
        mediaService.fetchMedia()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    guard let self else { return }
                    if case .failure(let error) = completion {
                        if let appError = error as? AppError {
                            self.errorMessage = appError.localizedDescription
                        } else {
                            self.errorMessage = error.localizedDescription
                        }
                    }
                },
                receiveValue: { [weak self] mediaData in
                    guard let self else { return }
                    self.media = mediaData
                    if let videos = mediaData.categories.first?.videos, !videos.isEmpty {
                        self.updateVideo(at: 0)
                    } else {
                        self.errorMessage = "沒有可用的影片"
                    }
                }
            )
            .store(in: &cancellables)
    }
    
    func resetObservers(for playerItem: AVPlayerItem) {
        removeTimeObserver()
        observePlayerItem(playerItem)
        setupTimeObserver()
    }
}
