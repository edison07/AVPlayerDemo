//
//  VideoPlayerViewModel.swift
//  GlossikaPlayer
//
//  Created by Edison on 2025/3/10.
//

import AVKit
import Combine

final class VideoPlayerViewModel {
    // MARK: - Published Properties
    @Published private(set) var isPlaying: Bool = false
    @Published private(set) var isLoading: Bool = false
    @Published private(set) var progress: Double = 0.0
    @Published private(set) var currentTimeText: String = "\(TimeConstants.defaultTimeText) / \(TimeConstants.defaultTimeText)"
    @Published private(set) var errorMessage: String?
    @Published private(set) var media: VideoPlayerModel.MediaJSON?
    @Published private(set) var controlsEnabled: Bool = true
    @Published var seekTimeText: String = TimeConstants.defaultTimeText
    
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
    
    func updateVideo(with url: URL) {
        pause()
        let asset = AVURLAsset(url: url)
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
                    if finished {
                        self?.player.play()
                        self?.isPlaying = true
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
        Task {
            guard let playerItem = player.currentItem, playerItem.duration.seconds > 0 else { return }
            let durationSeconds = playerItem.duration.seconds
            let newTimeSeconds = progress * durationSeconds
            let targetTime = CMTime(seconds: newTimeSeconds, preferredTimescale: TimeConstants.timeScale)
            
            _ = await player.seek(to: targetTime, toleranceBefore: .zero, toleranceAfter: .zero)
            isSeeking = false
        }
    }
    
    func skipForward(by seconds: Double = TimeConstants.defaultSkipInterval) {
        guard let durationSeconds = player.currentItem?.duration.seconds else { return }
        let currentTime = player.currentTime().seconds
        let newTime = min(currentTime + seconds, durationSeconds)
        player.seek(to: CMTime(seconds: newTime, preferredTimescale: TimeConstants.timeScale))
    }
    
    func skipBackward(by seconds: Double = TimeConstants.defaultSkipInterval) {
        let currentTime = player.currentTime().seconds
        let newTime = max(currentTime - seconds, 0)
        player.seek(to: CMTime(seconds: newTime, preferredTimescale: TimeConstants.timeScale))
    }
    
    func formattedTime(for progress: Double) -> String {
        guard let duration = player.currentItem?.duration.seconds, duration > 0 else {
            return TimeConstants.defaultTimeText
        }
        let newTime = progress * duration
        return formatTime(newTime)
    }
}

// MARK: - Private Methods
private extension VideoPlayerViewModel {
    func setupTimeObserver() {
        let interval = CMTime(seconds: TimeConstants.seekUpdateInterval, preferredTimescale: TimeConstants.timeScale)
        timeObserverToken = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let self = self else { return }
            let currentTime = time.seconds
            let duration = self.player.currentItem?.duration.seconds ?? 0
            self.currentTimeText = "\(self.formatTime(currentTime)) / \(self.formatTime(duration))"
            guard !self.isSeeking else { return }
            if duration > 0 {
                self.progress = currentTime / duration
            }
        }
    }
    
    func observePlayerItem(_ playerItem: AVPlayerItem) {
        // 監聽播放項目狀態變化
        playerItem.publisher(for: \.status)
            .sink { [weak self] status in
                guard let self = self else { return }
                switch status {
                case .readyToPlay:
                    self.isLoading = false
                    self.errorMessage = nil
                    self.controlsEnabled = true
                case .failed:
                    self.isLoading = false
                    self.controlsEnabled = false
                    if let error = playerItem.error {
                        self.errorMessage = error.localizedDescription
                    } else {
                        self.errorMessage = "影片載入失敗"
                    }
                default:
                    self.isLoading = true
                }
            }
            .store(in: &cancellables)
        
        // 監聽播放項目是否需要緩衝
        playerItem.publisher(for: \.isPlaybackLikelyToKeepUp)
            .sink { [weak self] isLikelyToKeepUp in
                self?.isLoading = !isLikelyToKeepUp
            }
            .store(in: &cancellables)
        
        // 監聽播放結束通知
        NotificationCenter.default.publisher(for: .AVPlayerItemDidPlayToEndTime, object: playerItem)
            .sink { [weak self] _ in
                self?.isPlaying = false
            }
            .store(in: &cancellables)
    }
    
    // 格式化時間為分:秒格式
    func formatTime(_ seconds: Double) -> String {
        guard !seconds.isNaN else { return TimeConstants.defaultTimeText }
        let minutes = Int(seconds) / 60
        let seconds = Int(seconds) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    func fetchMediaData() {
        isLoading = true
        mediaService.fetchMedia()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    guard let self = self else { return }
                    self.isLoading = false
                    if case .failure(let error) = completion {
                        if let appError = error as? AppError {
                            self.errorMessage = appError.localizedDescription
                        } else {
                            self.errorMessage = error.localizedDescription
                        }
                    }
                },
                receiveValue: { [weak self] mediaData in
                    guard let self = self else { return }
                    self.media = mediaData
                    if let firstCategory = mediaData.categories.first,
                       let firstVideo = firstCategory.videos.first,
                       let urlString = firstVideo.sources.first,
                       let videoURL = URL(string: urlString) {
                        self.updateVideo(with: videoURL)
                    }
                    self.errorMessage = nil
                }
            )
            .store(in: &cancellables)
    }
    
    func resetObservers(for playerItem: AVPlayerItem) {
        if let token = timeObserverToken {
            player.removeTimeObserver(token)
            timeObserverToken = nil
        }
        observePlayerItem(playerItem)
        setupTimeObserver()
    }
}
