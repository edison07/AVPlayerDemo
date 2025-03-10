//
//  ViewController.swift
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
        setupObserver()
        setupBindings()
        viewModel.attachPlayerLayer(to: playerView)
        viewModel.setupPlayer()
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: any UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        guard let windowScene = view.window?.windowScene else { return }
            
        let newOrientation = windowScene.interfaceOrientation
        updateFullScreenButtonIcon(for: newOrientation.isPortrait ? .portrait : .landscapeRight)
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        updatePlayerLayerFrame()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self, name: UIApplication.didEnterBackgroundNotification, object: nil)
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
    
    @IBAction func progressSliderValueChanged(_ sender: UISlider) {
        viewModel.seek(to: Double(progressSlider.value))
    }
    
    @IBAction func progressSliderTouchDown(_ sender: UISlider) {
        seekBackgroundView.isHidden = false
    }
    @IBAction func progressSliderTouchUpInside(_ sender: UISlider) {
        seekBackgroundView.isHidden = true
    }
    
}

// MARK: - Private
extension VideoPlayerViewController {
    private func setupUI() {
        durationTimeLabel.font = .monospacedDigitSystemFont(ofSize: 14, weight: .medium)
        seekTimeLabel.font = .monospacedDigitSystemFont(ofSize: 14, weight: .medium)
        seekBackgroundView.layer.cornerRadius = 15
        seekBackgroundView.clipsToBounds = true
    }
    
    private func setupObserver() {
        NotificationCenter.default.addObserver(self, selector: #selector(handleAppDidEnterBackground), name: UIApplication.didEnterBackgroundNotification, object: nil)
    }
    
    @objc private func handleAppDidEnterBackground() {
        viewModel.pause()
        showControlView()
    }
    
    private func updateFullScreenButtonIcon(for orientation: UIInterfaceOrientationMask) {
        let iconName = (orientation == .portrait) ? "arrow.up.left.and.arrow.down.right.rectangle" : "arrow.down.right.and.arrow.up.left.rectangle"
        fullScreenButton.setImage(UIImage(systemName: iconName), for: .normal)
    }
    
    private func updatePlayerLayerFrame() {
        viewModel.updatePlayerLayerFrame(to: playerView.bounds)
    }

    private func setupBindings() {
        viewModel.$isLoading
                .receive(on: DispatchQueue.main)
                .sink { [weak self] isLoading in
                    guard let self = self else { return }
                    if isLoading {
                        self.loadingIndicator.startAnimating()
                    } else {
                        self.loadingIndicator.stopAnimating()
                    }
                }
                .store(in: &cancellables)
        
        viewModel.$isPlaying
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isPlaying in
                let icon = isPlaying ? "pause.fill" : "play.fill"
                self?.playPauseButton.setImage(UIImage(systemName: icon), for: .normal)
                if isPlaying {
                    self?.fadeOutControlView()
                } else {
                    self?.showControlView()
                }
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
    }
    
    private func showControlView() {
        fadeOutTask?.cancel()
        controlView.isHidden = false
        
        if viewModel.isPlaying {
            fadeOutControlView()
        }
    }
    
    private func hideControlView() {
        fadeOutTask?.cancel()
        controlView.isHidden = true
    }
    
    private func fadeOutControlView() {
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
}
