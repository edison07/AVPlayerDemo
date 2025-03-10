//
//  Untitled.swift
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
    
    private var player: AVPlayer?
    private var playerLayer: AVPlayerLayer?
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        guard let videoURL = URL(string: VideoPlayerModel.videoURL) else { return }
        let playerItem = AVPlayerItem(url: videoURL)
        self.player = AVPlayer(playerItem: playerItem)
        observePlayerItem(playerItem)
        setupTimeObserver()
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
        if isPlaying {
            player?.pause()
        } else {
            player?.play()
        }
        isPlaying.toggle()
    }
    
    func pause() {
        player?.pause()
        isPlaying = false
    }
    
    
    func seek(to value: Double) {
        let duration = player?.currentItem?.duration.seconds ?? 1
        let newTime = value * duration
        seekTimeText = self.formatTime(newTime)
        player?.seek(to: CMTime(seconds: newTime, preferredTimescale: 600))
    }
    
    func skipForward(by seconds: Double = 10.0) {
        guard let player = player, let duration = player.currentItem?.duration.seconds else { return }
        let currentTime = player.currentTime().seconds
        let newTime = min(currentTime + seconds, duration)
        player.seek(to: CMTime(seconds: newTime, preferredTimescale: 600))
    }
    
    func skipBackward(by seconds: Double = 10.0) {
        guard let currentTime = player?.currentTime().seconds else { return }
        let newTime = max(currentTime - seconds, 0)
        player?.seek(to: CMTime(seconds: newTime, preferredTimescale: 600))
    }
    
}

// MARK: - Private
extension VideoPlayerViewModel {
    private func setupTimeObserver() {
        guard let player = player else { return }
        
        player.addPeriodicTimeObserver(forInterval: CMTime(seconds: 1, preferredTimescale: 600), queue: .main) { [weak self] time in
            guard let self = self else { return }
            let currentTime = time.seconds
            let duration = player.currentItem?.duration.seconds ?? 0
            self.currentTimeText = self.formatTime(currentTime) + " / " + self.formatTime(duration)
            if duration > 0 {
                self.progress = currentTime / duration
            }
        }
    }
    
    private func observePlayerItem(_ playerItem: AVPlayerItem) {
           playerItem.publisher(for: \.status)
               .sink { [weak self] status in
                   guard let self = self else { return }
                   self.isLoading = (status != .readyToPlay)
               }
               .store(in: &cancellables)

           playerItem.publisher(for: \.isPlaybackLikelyToKeepUp)
               .sink { [weak self] isLikelyToKeepUp in
                   guard let self = self else { return }
                   self.isLoading = !isLikelyToKeepUp
               }
               .store(in: &cancellables)
       }
    
    private func formatTime(_ seconds: Double) -> String {
        guard !seconds.isNaN else { return "00:00" }
        let minutes = Int(seconds) / 60
        let seconds = Int(seconds) % 60
        return String(format: "\(minutes):%02d", seconds)
    }
}
