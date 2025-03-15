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
    @IBOutlet weak var playRateButton: UIButton!
    
    @IBOutlet weak var loadingIndicator: UIActivityIndicatorView!
    
    @IBOutlet weak var tableView: UITableView!
    
    private var viewModel = VideoPlayerViewModel(/*mediaService: MockMediaService()*/)
    private var cancellables = Set<AnyCancellable>()
    // 用於控制控制面板自動淡出的任務
    private var fadeOutTask: Task<Void, Never>?
    // 播放速度選項
    private let playbackRates: [Float] = [0.5, 1.0, 1.5, 2.0]
    private var currentRateIndex: Int = 1 // 默認 1.0x
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupBindings()
        setupNotifications()
        setupGestures()
        // 將播放器層附加到播放器視圖上
        viewModel.attachPlayerLayer(to: playerView)
        viewModel.setupPlayer()
    }
    
    // 處理裝置旋轉時的介面調整
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        coordinator.animate(alongsideTransition: { [weak self] _ in
            guard let self = self, let windowScene = self.view.window?.windowScene else { return }
            let newOrientation = windowScene.interfaceOrientation
            // 根據新的方向更新全螢幕按鈕圖示
            self.updateFullScreenButtonIcon(for: newOrientation.isPortrait ? .portrait : .landscapeRight)
        })
    }
    
    // 視圖佈局更新時，同步更新播放器層的尺寸
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        viewModel.updatePlayerLayerFrame(to: playerView.bounds)
    }
}

// MARK: - IBActions
extension VideoPlayerViewController {
    // 點擊播放器視圖時顯示控制面板
    @IBAction func didTapPlayerView(_ sender: UITapGestureRecognizer) {
        showControlView()
    }
    
    // 點擊控制面板時隱藏控制面板
    @IBAction func didTapControlView(_ sender: UITapGestureRecognizer) {
        hideControlView()
    }
    
    // 點擊播放/暫停按鈕時切換播放狀態
    @IBAction func didTapPlayButton(_ sender: UIButton) {
        viewModel.togglePlayPause()
    }
    
    // 點擊快轉按鈕
    @IBAction func didTapSkipForwardButton(_ sender: UIButton) {
        viewModel.skipForward()
        fadeOutControlView()
    }
    
    // 點擊倒轉按鈕
    @IBAction func didTapSkipBackwardButton(_ sender: UIButton) {
        viewModel.skipBackward()
        fadeOutControlView()
    }
    
    // 新增：點擊播放速度按鈕
    @IBAction func didTapPlayRateButton(_ sender: UIButton) {
        // 循環切換播放速度
        currentRateIndex = (currentRateIndex + 1) % playbackRates.count
        let newRate = playbackRates[currentRateIndex]
        
        viewModel.setPlaybackRate(newRate)
        updatePlayRateButtonTitle()
    }
    
    // 點擊全螢幕按鈕時切換螢幕方向
    @IBAction func didTapFullScreenButton(_ sender: UIButton) {
        toggleFullScreen()
    }
    
    // 進度條按下時顯示拖曳背景視圖並設定拖曳狀態
    @IBAction func progressSliderTouchDown(_ sender: UISlider) {
        seekBackgroundView.isHidden = false
        viewModel.isSeeking = true
    }
    
    // 進度條釋放時隱藏拖曳背景視圖並跳轉到選擇的時間點
    @IBAction func progressSliderTouchUpInside(_ sender: UISlider) {
        seekBackgroundView.isHidden = true
        viewModel.seek(to: Double(sender.value))
    }
    
    // 進度條在外部釋放時的處理，與內部釋放相同
    @IBAction func progressSliderTouchUpOutside(_ sender: UISlider) {
        seekBackgroundView.isHidden = true
        viewModel.seek(to: Double(sender.value))
    }
    
    // 進度條值變化時更新顯示的時間文字
    @IBAction func progressSliderValueChanged(_ sender: UISlider) {
        let formattedTime = viewModel.formattedTime(for: Double(sender.value))
        viewModel.seekTimeText = formattedTime
    }
}

// MARK: - 手勢和動畫相關方法
private extension VideoPlayerViewController {
    func setupGestures() {
        let gestureViews: [UIView] = [playerView, controlView]
        
        gestureViews.forEach { view in
            addSwipeGesture(to: view, direction: .up, action: #selector(handleSwipeUp(_:)))
            addSwipeGesture(to: view, direction: .down, action: #selector(handleSwipeDown(_:)))
        }
    }

    private func addSwipeGesture(to view: UIView, direction: UISwipeGestureRecognizer.Direction, action: Selector) {
        let swipeGesture = UISwipeGestureRecognizer(target: self, action: action)
        swipeGesture.direction = direction
        view.addGestureRecognizer(swipeGesture)
    }

    // 上滑進入全螢幕
    @objc func handleSwipeUp(_ gesture: UISwipeGestureRecognizer) {
        guard let windowScene = view.window?.windowScene else { return }
        let currentOrientation = windowScene.interfaceOrientation
        
        // 只有在直向模式下才進入全螢幕
        if currentOrientation.isPortrait {
            toggleFullScreen()
        }
    }

    // 下滑退出全螢幕
    @objc func handleSwipeDown(_ gesture: UISwipeGestureRecognizer) {
        guard let windowScene = view.window?.windowScene else { return }
        let currentOrientation = windowScene.interfaceOrientation
        
        // 只有在橫向模式下才退出全螢幕
        if !currentOrientation.isPortrait {
            toggleFullScreen()
        }
    }

    // 切換全螢幕
    func toggleFullScreen() {
        guard let windowScene = view.window?.windowScene else { return }
        let currentOrientation = windowScene.interfaceOrientation
        // 根據目前方向決定新的方向
        let newOrientationMask: UIInterfaceOrientationMask = currentOrientation.isPortrait ? .landscapeRight : .portrait
        let geometryPreferences = UIWindowScene.GeometryPreferences.iOS(interfaceOrientations: newOrientationMask)
        
        // 請求更新螢幕方向，並處理可能的錯誤
        windowScene.requestGeometryUpdate(geometryPreferences) { [weak self] error in
            self?.showErrorAlert(with: "無法切換螢幕方向: \(error.localizedDescription)")
        }
        updateFullScreenButtonIcon(for: newOrientationMask)
    }

    // 更新播放速度按鈕的標題
    func updatePlayRateButtonTitle() {
        let currentRate = playbackRates[currentRateIndex]
        let rateText = String(format: "%.1fx", currentRate)
        playRateButton.setTitle(rateText, for: .normal)
        fadeOutControlView()
    }
}

// MARK: - Private Methods
private extension VideoPlayerViewController {
    // 設定介面初始狀態
    func setupUI() {
        tableView.delegate = self
        tableView.dataSource = self
        durationTimeLabel.font = .monospacedDigitSystemFont(ofSize: 14, weight: .medium)
        seekTimeLabel.font = .monospacedDigitSystemFont(ofSize: 14, weight: .medium)
        seekBackgroundView.addRoundedCorners(radius: 15)
        
        playPauseButton.setImage(UIImage(systemName: IconConstants.playIcon), for: .normal)
        skipForwardButton.setImage(UIImage(systemName: IconConstants.skipForwardIcon), for: .normal)
        skipBackwardButton.setImage(UIImage(systemName: IconConstants.skipBackwardIcon), for: .normal)
    }
    
    // 設定資料綁定，監聽 ViewModel 中的狀態變化
    func setupBindings() {
        // 監聽載入狀態變化
        viewModel.$isLoading
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isLoading in
                guard let self = self else { return }
                if isLoading {
                    // 開始載入時顯示載入指示器並隱藏控制面板
                    self.loadingIndicator.startAnimating()
                    self.hideControlView()
                } else {
                    // 載入完成時隱藏載入指示器，如果影片未播放則顯示控制面板
                    self.loadingIndicator.stopAnimating()
                    if !self.viewModel.isPlaying {
                        self.showControlView()
                    }
                }
            }
            .store(in: &cancellables)
        
        // 監聽播放狀態變化
        viewModel.$isPlaying
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isPlaying in
                guard let self = self else { return }
                // 根據播放狀態更新播放/暫停按鈕圖示
                let iconName = isPlaying ? "pause.fill" : "play.fill"
                self.playPauseButton.setImage(UIImage(systemName: iconName), for: .normal)
                if isPlaying {
                    // 播放時如果尚未啟動淡出任務，開始淡出控制面板
                    if self.fadeOutTask == nil {
                        self.fadeOutControlView()
                    }
                } else {
                    // 暫停時：如果控制面板已隱藏或幾乎看不見，直接顯示控制面板
                    if self.controlView.isHidden || self.controlView.alpha < 0.1 {
                        self.showControlView()
                    } else {
                        // 取消正在進行的淡出任務
                        if let task = self.fadeOutTask {
                            task.cancel()
                            self.fadeOutTask = nil
                        }
                    }
                }
            }
            .store(in: &cancellables)
        
        // 監聽播放進度變化，更新進度條
        viewModel.$progress
            .receive(on: DispatchQueue.main)
            .sink { [weak self] progress in
                self?.progressSlider.value = Float(progress)
            }
            .store(in: &cancellables)
        
        // 監聽目前時間文字變化，更新時間標籤
        viewModel.$currentTimeText
            .receive(on: DispatchQueue.main)
            .sink { [weak self] timeText in
                self?.durationTimeLabel.text = timeText
            }
            .store(in: &cancellables)
        
        // 監聽拖曳時間文字變化，更新拖曳時間標籤
        viewModel.$seekTimeText
            .receive(on: DispatchQueue.main)
            .sink { [weak self] timeText in
                self?.seekTimeLabel.text = timeText
            }
            .store(in: &cancellables)
        
        // 監聽錯誤訊息變化，顯示錯誤提示
        viewModel.$errorMessage
            .receive(on: DispatchQueue.main)
            .sink { [weak self] errorMessage in
                if let message = errorMessage {
                    self?.showErrorAlert(with: message)
                }
            }
            .store(in: &cancellables)
        
        // 監聽媒體資料變化，重新整理列表
        viewModel.$media
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.tableView.reloadData()
            }
            .store(in: &cancellables)
        
        // 監聽控制項啟用狀態變化，更新 UI 元素的啟用狀態
        viewModel.$controlsEnabled
            .receive(on: DispatchQueue.main)
            .sink { [weak self] enabled in
                self?.playPauseButton.isEnabled = enabled
                self?.progressSlider.isEnabled = enabled
                self?.fullScreenButton.isEnabled = enabled
                self?.skipForwardButton.isEnabled = enabled
                self?.skipBackwardButton.isEnabled = enabled
                self?.playRateButton.isEnabled = enabled
                // 如果控制項被停用，重設播放按鈕圖示和進度條
                if !enabled {
                    self?.playPauseButton.setImage(UIImage(systemName: "play.fill"), for: .normal)
                    self?.progressSlider.value = 0
                }
            }
            .store(in: &cancellables)
    }
    
    // 設定通知監聽
    func setupNotifications() {
        // 監聽應用程式進入背景的通知
        NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)
            .sink { [weak self] _ in
                self?.handleAppDidEnterBackground()
            }
            .store(in: &cancellables)
    }
    
    // 處理應用程式進入背景的事件
    @objc func handleAppDidEnterBackground() {
        // 進入背景時暫停播放並顯示控制面板
        viewModel.pause()
        showControlView()
    }
    
    // 根據螢幕方向更新全螢幕按鈕圖示和列表顯示狀態
    func updateFullScreenButtonIcon(for orientation: UIInterfaceOrientationMask) {
        // 定義橫向和直向模式下的按鈕尺寸
        let buttonSizes: (playButton: CGFloat, skipButton: CGFloat) = orientation.isLandscape ?
        (playButton: 50, skipButton: 40) :
        (playButton: 30, skipButton: 20)
        
        // 設定播放/暫停按鈕的尺寸
        let playButtonConfig = UIImage.SymbolConfiguration(pointSize: buttonSizes.playButton)
        playPauseButton.setPreferredSymbolConfiguration(playButtonConfig, forImageIn: .normal)
        
        // 設定快轉/倒轉按鈕的尺寸
        let skipButtonConfig = UIImage.SymbolConfiguration(pointSize: buttonSizes.skipButton)
        skipForwardButton.setPreferredSymbolConfiguration(skipButtonConfig, forImageIn: .normal)
        skipBackwardButton.setPreferredSymbolConfiguration(skipButtonConfig, forImageIn: .normal)
        
        // 根據方向設定 UI
        if orientation.isLandscape {
            // 橫向模式：顯示縮小圖示
            fullScreenButton.setImage(UIImage(systemName: IconConstants.landscapeIcon), for: .normal)
        } else {
            // 直向模式：顯示全螢幕圖示
            fullScreenButton.setImage(UIImage(systemName: IconConstants.portraitIcon), for: .normal)
        }
    }
    
    // 顯示控制面板
    func showControlView() {
        // 如果正在載入，不顯示控制面板
        if loadingIndicator.isAnimating {
            return
        }
        
        // 取消可能存在的淡出任務
        if let task = fadeOutTask {
            task.cancel()
            fadeOutTask = nil
        }
        // 淡入顯示控制面板
        controlView.fadeIn(targetAlpha: 0.45)
        // 如果影片正在播放，啟動淡出任務
        if viewModel.isPlaying {
            fadeOutControlView()
        }
    }
    
    // 隱藏控制面板
    func hideControlView() {
        // 取消可能存在的淡出任務
        if let task = fadeOutTask {
            task.cancel()
            fadeOutTask = nil
        }
        // 淡出隱藏控制面板
        controlView.fadeOut()
    }
    
    // 設定控制面板的自動淡出
    func fadeOutControlView() {
        // 取消可能存在的淡出任務
        if let task = fadeOutTask {
            task.cancel()
            fadeOutTask = nil
        }
        // 建立新的淡出任務
        fadeOutTask = Task {
            do {
                // 等待指定時間後執行淡出
                try await Task.sleep(nanoseconds: TimeConstants.controlsFadeOutTime)
            } catch {
                return
            }
            // 在主執行緒上執行 UI 更新
            await MainActor.run {
                // 只有在播放且控制面板顯示時才淡出控制面板
                if self.viewModel.isPlaying && !self.controlView.isHidden {
                    self.controlView.fadeOut()
                }
                self.fadeOutTask = nil
            }
        }
    }
    
    // 顯示錯誤提示
    func showErrorAlert(with message: String) {
        ErrorAlertManager.showErrorAlert(on: self, message: message)
    }
}

// MARK: - UITableViewDataSource
extension VideoPlayerViewController: UITableViewDataSource {
    // 回傳列表的分區數量
    func numberOfSections(in tableView: UITableView) -> Int {
        return viewModel.media?.categories.count ?? 0
    }
    
    // 回傳每個分區的列數
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return viewModel.media?.categories[section].videos.count ?? 0
    }
    
    // 回傳分區標題
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return viewModel.media?.categories[section].name
    }
    
    // 設定每個儲存格
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let video = viewModel.media?.categories[indexPath.section].videos[indexPath.row] else {
            return UITableViewCell()
        }
        
        let cell = tableView.dequeueReusableCell(withIdentifier: "VideoListTableViewCell", for: indexPath) as! VideoListTableViewCell
        cell.configure(with: video)
        
        return cell
    }
}

// MARK: - UITableViewDelegate
extension VideoPlayerViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let video = viewModel.media?.categories[indexPath.section].videos[indexPath.row],
              let urlString = video.sources.first,
              let videoURL = URL(string: urlString) else { return }
        
        // 更新播放器以播放選取的影片
        viewModel.updateVideo(with: videoURL)
        progressSlider.value = 0
    }
}

// MARK: - UIInterfaceOrientationMask Extension
extension UIInterfaceOrientationMask {
    // 判斷方向是否為橫向
    var isLandscape: Bool {
        return self == .landscapeRight || self == .landscapeLeft || self == .landscape
    }
}
