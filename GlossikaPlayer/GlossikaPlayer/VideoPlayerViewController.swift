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
    @IBOutlet weak var skipForwardButton: UIButton!
    @IBOutlet weak var skipBackwardButton: UIButton!
    
    @IBOutlet weak var loadingIndicator: UIActivityIndicatorView!
    
    @IBOutlet weak var tableView: UITableView!
    
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
        coordinator.animate(alongsideTransition: { [weak self] _ in
            guard let self = self, let windowScene = self.view.window?.windowScene else { return }
            let newOrientation = windowScene.interfaceOrientation
            self.updateFullScreenButtonIcon(for: newOrientation.isPortrait ? .portrait : .landscapeRight)
        })
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
        tableView.delegate = self
        tableView.dataSource = self
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
                if isPlaying {
                    if self?.fadeOutTask == nil {
                        self?.fadeOutControlView()
                    }
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
        
        viewModel.$errorMessage
            .receive(on: DispatchQueue.main)
            .sink { [weak self] errorMessage in
                if let message = errorMessage {
                    self?.showErrorAlert(with: message)
                }
            }
            .store(in: &cancellables)
        
        viewModel.$media
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.tableView.reloadData()
            }
            .store(in: &cancellables)
        
        viewModel.$controlsEnabled
            .receive(on: DispatchQueue.main)
            .sink { [weak self] enabled in
                self?.playPauseButton.isEnabled = enabled
                self?.progressSlider.isEnabled = enabled
                self?.fullScreenButton.isEnabled = enabled
                self?.skipForwardButton.isEnabled = enabled
                self?.skipBackwardButton.isEnabled = enabled
                if !enabled {
                    self?.playPauseButton.setImage(UIImage(systemName: "play.fill"), for: .normal)
                    self?.progressSlider.value = 0
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
        if orientation == .landscapeRight || orientation == .landscapeLeft {
                tableView.isHidden = true
            fullScreenButton.setImage(UIImage(systemName: IconConstants.landscapeIcon), for: .normal)
            } else {
                tableView.isHidden = false
                fullScreenButton.setImage(UIImage(systemName: IconConstants.portraitIcon), for: .normal)
            }
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
            do {
                try await Task.sleep(nanoseconds: 2_000_000_000)
            } catch {
                return
            }
            await MainActor.run {
                if self.viewModel.isPlaying && !self.controlView.isHidden {
                    self.controlView.isHidden = true
                }
                self.fadeOutTask = nil
            }
        }
    }
    
    
    func showErrorAlert(with message: String) {
        ErrorAlertManager.showErrorAlert(on: self, message: message)
    }
}

extension VideoPlayerViewController: UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        return viewModel.media?.categories.count ?? 0
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return viewModel.media?.categories[section].videos.count ?? 0
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return viewModel.media?.categories[section].name
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let video = viewModel.media?.categories[indexPath.section].videos[indexPath.row] else {
            return UITableViewCell()
        }
        
        let cell = tableView.dequeueReusableCell(withIdentifier: "VideoListTableViewCell", for: indexPath) as! VideoListTableViewCell
        cell.configure(with: video)
        
        return cell
    }
}

extension VideoPlayerViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let video = viewModel.media?.categories[indexPath.section].videos[indexPath.row],
              let urlString = video.sources.first,
              let videoURL = URL(string: urlString) else { return }
        
        viewModel.updateVideo(with: videoURL)
    }
}
