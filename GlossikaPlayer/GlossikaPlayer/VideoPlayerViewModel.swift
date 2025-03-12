//
//  VideoPlayerViewModel.swift
//  GlossikaPlayer
//
//  Created by Edison on 2025/3/10.
//

import AVKit
import Combine

final class VideoPlayerViewModel {
    @Published var isPlaying: Bool = false
    @Published var isLoading: Bool = false
    @Published var progress: Double = 0.0
    @Published var currentTimeText: String = "00:00 / 00:00"
    @Published var seekTimeText: String = "00:00"
    @Published var errorMessage: String?
    
    private var player: AVPlayer?
    private var playerLayer: AVPlayerLayer?
    private var cancellables = Set<AnyCancellable>()
    private var timeObserverToken: Any?
    var isSeeking: Bool = false
    
    init() {
        guard let videoURL = URL(string: AppConstants.videoURL) else { return }
        let asset = AVURLAsset(url: videoURL)
        let playerItem = AVPlayerItem(asset: asset)
        self.player = AVPlayer(playerItem: playerItem)
        observePlayerItem(playerItem)
        setupTimeObserver()
    }
    
    deinit {
        if let token = timeObserverToken {
            player?.removeTimeObserver(token)
        }
    }
    
    func setupPlayer() {
        player?.play()
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
    
    func togglePlayPause() {
        guard let player = player else { return }
        if isPlaying {
            player.pause()
        } else {
            player.play()
        }
        isPlaying.toggle()
    }
    
    func pause() {
        player?.pause()
        isPlaying = false
    }
    
    func seek(to progress: Double) {
        Task {
            guard
                let player = player ,
                let playerItem = player.currentItem, playerItem.duration.seconds > 0 else { return }
            let durationSeconds = playerItem.duration.seconds
            let newTimeSeconds = progress * durationSeconds
            let targetTime = CMTime(seconds: newTimeSeconds, preferredTimescale: 600)
            
            _ = await player.seek(to: targetTime, toleranceBefore: .zero, toleranceAfter: .zero)
            isSeeking = false
        }
    }
    
    func skipForward(by seconds: Double = 10.0) {
        guard let player = player, let durationSeconds = player.currentItem?.duration.seconds else { return }
        let currentTime = player.currentTime().seconds
        let newTime = min(currentTime + seconds, durationSeconds)
        player.seek(to: CMTime(seconds: newTime, preferredTimescale: 600))
    }
    
    func skipBackward(by seconds: Double = 10.0) {
        guard let player = player else { return }
        let currentTime = player.currentTime().seconds
        let newTime = max(currentTime - seconds, 0)
        player.seek(to: CMTime(seconds: newTime, preferredTimescale: 600))
    }
    
    func formattedTime(for progress: Double) -> String {
        guard let duration = player?.currentItem?.duration.seconds, duration > 0 else {
            return "00:00"
        }
        let newTime = progress * duration
        return formatTime(newTime)
    }
}

// MARK: - Private Methods
private extension VideoPlayerViewModel {
    func setupTimeObserver() {
        guard let player = player else { return }
        let interval = CMTime(seconds: 1, preferredTimescale: 600)
        timeObserverToken = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let self = self else { return }
            let currentTime = time.seconds
            let duration = player.currentItem?.duration.seconds ?? 0
            self.currentTimeText = "\(self.formatTime(currentTime)) / \(self.formatTime(duration))"
            guard !self.isSeeking else { return }
            if duration > 0 {
                self.progress = currentTime / duration
            }
        }
    }
    
    func observePlayerItem(_ playerItem: AVPlayerItem) {
        playerItem.publisher(for: \.status)
            .sink { [weak self] status in
                guard let self = self else { return }
                switch status {
                case .readyToPlay:
                    self.isLoading = false
                    self.errorMessage = nil
                case .failed:
                    self.isLoading = false
                    if let error = playerItem.error {
                        self.errorMessage = error.localizedDescription
                    } else {
                        self.errorMessage = "影片讀取失敗"
                    }
                default:
                    self.isLoading = true
                }
            }
            .store(in: &cancellables)
        
        playerItem.publisher(for: \.isPlaybackLikelyToKeepUp)
            .sink { [weak self] isLikelyToKeepUp in
                self?.isLoading = !isLikelyToKeepUp
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: .AVPlayerItemDidPlayToEndTime, object: playerItem)
            .sink { [weak self] _ in
                self?.isPlaying = false
            }
            .store(in: &cancellables)
    }
    
    func formatTime(_ seconds: Double) -> String {
        guard !seconds.isNaN else { return "00:00" }
        let minutes = Int(seconds) / 60
        let seconds = Int(seconds) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
