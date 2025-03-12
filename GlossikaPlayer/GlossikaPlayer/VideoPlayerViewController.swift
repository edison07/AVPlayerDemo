//
//  VideoPlayerViewController.swift
//  GlossikaPlayer
//
//  Created by Edison on 2025/3/10.
//

import UIKit
import AVKit
import Combine

final class VideoPlayerViewController: UIViewController {
    
    @IBOutlet weak var playerView: UIView!
    @IBOutlet weak var controlView: UIView!
    @IBOutlet weak var seekBackgroundView: UIView!
    
    @IBOutlet weak var progressSlider: UISlider!
    
    @IBOutlet weak var durationTimeLabel: UILabel!
    @IBOutlet weak var seekTimeLabel: UILabel!
    
    @IBOutlet weak var fullScreenButton: UIButton!
    @IBOutlet weak var playPauseButton: UIButton!
    
    @IBOutlet weak var loadingIndicator: UIActivityIndicatorView!
    
    private var viewModel = VideoPlayerViewModel()
    private var cancellables = Set<AnyCancellable>()
    private var fadeOutTask: Task<Void, Never>?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupBindings()
        setupNotifications()
        viewModel.attachPlayerLayer(to: playerView)
        viewModel.setupPlayer()
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        guard let windowScene = view.window?.windowScene else { return }
        let newOrientation = windowScene.interfaceOrientation
        updateFullScreenButtonIcon(for: newOrientation.isPortrait ? .portrait : .landscapeRight)
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        viewModel.updatePlayerLayerFrame(to: playerView.bounds)
    }
}

// MARK: - IBActions
extension VideoPlayerViewController {
    @IBAction func didTapPlayerView(_ sender: UITapGestureRecognizer) {
        showControlView()
    }
    
    @IBAction func didTapControlView(_ sender: UITapGestureRecognizer) {
        hideControlView()
    }
    
    @IBAction func didTapPlayButton(_ sender: UIButton) {
        viewModel.togglePlayPause()
    }
    
    @IBAction func didTapSkipForwardButton(_ sender: UIButton) {
        viewModel.skipForward()
    }
    
    @IBAction func didTapSkipBackwardButton(_ sender: UIButton) {
        viewModel.skipBackward()
    }
    
    @IBAction func didTapFullScreenButton(_ sender: UIButton) {
        guard let windowScene = view.window?.windowScene else { return }
        let currentOrientation = windowScene.interfaceOrientation
        let newOrientationMask: UIInterfaceOrientationMask = currentOrientation.isPortrait ? .landscapeRight : .portrait
        let geometryPreferences = UIWindowScene.GeometryPreferences.iOS(interfaceOrientations: newOrientationMask)
        windowScene.requestGeometryUpdate(geometryPreferences) { error in
            print("Failed to change orientation: \(error.localizedDescription)")
        }
        updateFullScreenButtonIcon(for: newOrientationMask)
    }
    
    @IBAction func progressSliderTouchDown(_ sender: UISlider) {
        seekBackgroundView.isHidden = false
        viewModel.isSeeking = true
    }
    
    @IBAction func progressSliderTouchUpInside(_ sender: UISlider) {
        seekBackgroundView.isHidden = true
        viewModel.seek(to: Double(sender.value))
    }
    
    @IBAction func progressSliderTouchUpOutside(_ sender: UISlider) {
        seekBackgroundView.isHidden = true
        viewModel.seek(to: Double(sender.value))
    }
    
    @IBAction func progressSliderValueChanged(_ sender: UISlider) {
        let formattedTime = viewModel.formattedTime(for: Double(sender.value))
        viewModel.seekTimeText = formattedTime
    }
}

// MARK: - Private Methods
private extension VideoPlayerViewController {
    func setupUI() {
        durationTimeLabel.font = .monospacedDigitSystemFont(ofSize: 14, weight: .medium)
        seekTimeLabel.font = .monospacedDigitSystemFont(ofSize: 14, weight: .medium)
        seekBackgroundView.layer.cornerRadius = 15
        seekBackgroundView.clipsToBounds = true
    }
    
    func setupBindings() {
        viewModel.$isLoading
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isLoading in
                isLoading ? self?.loadingIndicator.startAnimating() : self?.loadingIndicator.stopAnimating()
            }
            .store(in: &cancellables)
        
        viewModel.$isPlaying
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isPlaying in
                let iconName = isPlaying ? "pause.fill" : "play.fill"
                self?.playPauseButton.setImage(UIImage(systemName: iconName), for: .normal)
                isPlaying ? self?.fadeOutControlView() : self?.showControlView()
            }
            .store(in: &cancellables)
        
        viewModel.$progress
            .receive(on: DispatchQueue.main)
            .sink { [weak self] progress in
                self?.progressSlider.value = Float(progress)
            }
            .store(in: &cancellables)
        
        viewModel.$currentTimeText
            .receive(on: DispatchQueue.main)
            .sink { [weak self] timeText in
                self?.durationTimeLabel.text = timeText
            }
            .store(in: &cancellables)
        
        viewModel.$seekTimeText
            .receive(on: DispatchQueue.main)
            .sink { [weak self] timeText in
                self?.seekTimeLabel.text = timeText
            }
            .store(in: &cancellables)
        
        viewModel.$errorMessage
            .receive(on: DispatchQueue.main)
            .sink { [weak self] errorMessage in
                if let message = errorMessage {
                    self?.showErrorAlert(with: message)
                }
            }
            .store(in: &cancellables)
    }
    
    func setupNotifications() {
        NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)
            .sink { [weak self] _ in
                self?.handleAppDidEnterBackground()
            }
            .store(in: &cancellables)
    }
    
    @objc func handleAppDidEnterBackground() {
        viewModel.pause()
        showControlView()
    }
    
    func updateFullScreenButtonIcon(for orientation: UIInterfaceOrientationMask) {
        let iconName = (orientation == .portrait) ? IconConstants.portraitIcon : IconConstants.landscapeIcon
        fullScreenButton.setImage(UIImage(systemName: iconName), for: .normal)
    }
    
    func showControlView() {
        fadeOutTask?.cancel()
        controlView.isHidden = false
        if viewModel.isPlaying {
            fadeOutControlView()
        }
    }
    
    func hideControlView() {
        fadeOutTask?.cancel()
        controlView.isHidden = true
    }
    
    func fadeOutControlView() {
        fadeOutTask?.cancel()
        fadeOutTask = Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            await MainActor.run {
                if self.viewModel.isPlaying && !self.controlView.isHidden {
                    self.controlView.isHidden = true
                }
            }
        }
    }
    
    func showErrorAlert(with message: String) {
        ErrorAlertManager.showErrorAlert(on: self, message: message)
    }
}
