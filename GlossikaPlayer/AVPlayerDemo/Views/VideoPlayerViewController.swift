//
//  VideoPlayerViewController.swift
//  AVPlayerDemo
//
//  Created by Edison on 2025/3/10.
//

import UIKit
import AVKit
import Combine

// MARK: - VideoPlayerViewController
final class VideoPlayerViewController: UIViewController {
    
    // MARK: - IBOutlets
    @IBOutlet weak var playerView: UIView!
    @IBOutlet weak var controlView: UIView!
    @IBOutlet weak var seekBackgroundView: UIView!
    
    @IBOutlet weak var progressSlider: UISlider!
    
    @IBOutlet weak var videoTimeLabel: UILabel!
    @IBOutlet weak var seekTimeLabel: UILabel!
    
    @IBOutlet weak var fullScreenButton: UIButton!
    @IBOutlet weak var playPauseButton: UIButton!
    @IBOutlet weak var nextVideoButton: UIButton!
    @IBOutlet weak var prevVideoButton: UIButton!
    @IBOutlet weak var playRateButton: UIButton!
    @IBOutlet weak var showMoreButton: UIButton!
    
    @IBOutlet weak var videoTitleLabel: UILabel!
    @IBOutlet weak var videoSubtitleLabel: UILabel!
    @IBOutlet weak var videoDescriptionLabel: UILabel!
    @IBOutlet weak var loadingIndicator: UIActivityIndicatorView!
    
    @IBOutlet weak var tableView: UITableView!
    
    // MARK: - Properties
    private var viewModel = VideoPlayerViewModel(/*mediaService: MockMediaService()*/)
    private var cancellables = Set<AnyCancellable>()
    /// 用於控制控制面板自動淡出的任務
    private var fadeOutTask: Task<Void, Never>?
    /// 播放速度選項
    private let playbackRates: [Float] = [0.5, 1.0, 1.5, 2.0]
    private var currentRateIndex: Int = 1 // 默認 1.0x
    /// 是否展開影片描述（顯示更多）
    private var isShowingMore: Bool = false
    
    // MARK: - Lifecycle Methods
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupBindings()
        setupNotifications()
        setupGestures()
        viewModel.attachPlayerLayer(to: playerView)
        viewModel.setupPlayer()
    }
    
    // 處理裝置旋轉時的介面調整
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        coordinator.animate(alongsideTransition: { [weak self] _ in
            guard let self, let windowScene = self.view.window?.windowScene else { return }
            
            let newOrientation = windowScene.interfaceOrientation
            // 根據新的方向更新全螢幕按鈕圖示
            self.updateFullScreenButtonIcon(for: newOrientation.isPortrait ? .portrait : .landscapeRight)
        })
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        viewModel.updatePlayerLayerFrame(to: playerView.bounds)
    }
    
    deinit {
        fadeOutTask?.cancel()
        fadeOutTask = nil
        cancellables.removeAll()
    }
}

// MARK: - IBActions
extension VideoPlayerViewController {
    
    @IBAction func didTapShowMoreButton(_ sender: UIButton) {
        isShowingMore.toggle()
        let title = isShowingMore ? UIConstants.showLessText : UIConstants.showMoreText
        showMoreButton.setTitle(title, for: .normal)
        
        UIView.animate(withDuration: AnimationConstants.defaultDuration) { [weak self] in
            guard let self = self else { return }
            self.videoDescriptionLabel.numberOfLines = self.isShowingMore ? 0 : 1
            self.view.layoutIfNeeded()
        }
    }
    
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
    
    // 點擊下一個影片按鈕
    @IBAction func didTapNextVideoButton(_ sender: UIButton) {
        videoTimeLabel.isHidden = true
        viewModel.nextVideo()
    }
    
    // 點擊上一個影片按鈕
    @IBAction func didTapPrevVideoButton(_ sender: UIButton) {
        videoTimeLabel.isHidden = true
        viewModel.prevVideo()
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
        // 取消可能存在的淡出任務
        cancelFadeOutTask()
    }
    
    // 進度條釋放時隱藏拖曳背景視圖並跳轉到選擇的時間點
    @IBAction func progressSliderTouchUpInside(_ sender: UISlider) {
        seekBackgroundView.isHidden = true
        viewModel.seek(to: Double(sender.value))
        // 如果正在播放，重新啟動淡出任務
        if viewModel.isPlaying {
            fadeOutControlView()
        }
    }
    
    @IBAction func progressSliderTouchUpOutside(_ sender: UISlider) {
        seekBackgroundView.isHidden = true
        viewModel.seek(to: Double(sender.value))
        // 如果正在播放，重新啟動淡出任務
        if viewModel.isPlaying {
            fadeOutControlView()
        }
    }
    
    // 進度條值變化時更新顯示的時間文字
    @IBAction func progressSliderValueChanged(_ sender: UISlider) {
        viewModel.updateProgress(to: Double(sender.value))
    }
}

// MARK: - 手勢與動畫相關方法
private extension VideoPlayerViewController {
    
    func setupGestures() {
        let gestureViews: [UIView] = [playerView, controlView]
        gestureViews.forEach { view in
            addSwipeGesture(to: view, direction: .up, action: #selector(handleSwipeUp(_:)))
            addSwipeGesture(to: view, direction: .down, action: #selector(handleSwipeDown(_:)))
        }
    }
    
    private func addSwipeGesture(to view: UIView,
                                 direction: UISwipeGestureRecognizer.Direction,
                                 action: Selector) {
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
            guard let self else { return }
            
            self.showErrorAlert(with: "無法切換螢幕方向: \(error.localizedDescription)")
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

// MARK: - Private Methods (UI Setup & Binding)
private extension VideoPlayerViewController {
    
    func setupUI() {
        tableView.delegate = self
        tableView.dataSource = self
        
        videoTimeLabel.font = .monospacedDigitSystemFont(ofSize: 14, weight: .medium)
        seekTimeLabel.font = .monospacedDigitSystemFont(ofSize: 14, weight: .medium)
        seekBackgroundView.addRoundedCorners(radius: 15)
        controlView.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        
        let configuration = UIImage.SymbolConfiguration(pointSize: 15)
        let image = UIImage(systemName: "circle.fill", withConfiguration: configuration)
        progressSlider.setThumbImage(image, for: .normal)
        progressSlider.setThumbImage(image, for: .highlighted)
        
        videoTitleLabel.text = ""
        videoSubtitleLabel.text = ""
        videoDescriptionLabel.text = ""
        showMoreButton.isHidden = true

        updatePlayRateButtonTitle()
    }
    
    // 設定資料綁定，監聽 ViewModel 中的狀態變化
    func setupBindings() {
        // 監聽是否準備好播放
        viewModel.$isReadyToPlay
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isReadyToPlay in
                guard let self else { return }
                
                isReadyToPlay ? self.loadingIndicator.stopAnimating() : self.loadingIndicator.startAnimating()
                self.playPauseButton.alpha = isReadyToPlay ? 1 : 0
                self.playPauseButton.isUserInteractionEnabled = isReadyToPlay
                self.progressSlider.isHidden = !isReadyToPlay
            }
            .store(in: &cancellables)
        
        // 監聽播放狀態變化
        viewModel.$isPlaying
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isPlaying in
                guard let self else { return }
                // 根據播放狀態更新播放/暫停按鈕圖示
                let iconName = isPlaying ? IconConstants.pauseIcon : IconConstants.playIcon
                UIView.transition(with: self.playPauseButton,
                                  duration: AnimationConstants.defaultDuration,
                                  options: .transitionCrossDissolve,
                                  animations: {
                    self.playPauseButton.setImage(UIImage(systemName: iconName), for: .normal)
                }, completion: nil)

                if isPlaying {
                    // 播放時如果尚未啟動淡出任務，開始淡出控制面板
                    if self.fadeOutTask == nil {
                        self.fadeOutControlView()
                    }
                } else {
                    // 暫停時：如果控制面板已隱藏，直接顯示控制面板
                    if self.controlView.isHidden {
                        self.showControlView()
                    } else {
                        // 取消正在進行的淡出任務
                        self.cancelFadeOutTask()
                    }
                }
            }
            .store(in: &cancellables)
        
        // 監聽播放進度變化，更新進度條
        viewModel.$progress
            .receive(on: DispatchQueue.main)
            .sink { [weak self] progress in
                guard let self else { return }
                
                self.progressSlider.value = Float(progress)
            }
            .store(in: &cancellables)
        
        // 監聽目前時間文字變化，更新時間標籤
        viewModel.$videoTimeText
            .receive(on: DispatchQueue.main)
            .sink { [weak self] videoTimeText in
                guard let self else { return }

                let fullText = "\(videoTimeText.current) / \(videoTimeText.duration)"
                let attributedText = NSMutableAttributedString(string: fullText)
                let currentTimeRange = (fullText as NSString).range(of: videoTimeText.current)
                attributedText.addAttribute(.foregroundColor, value: UIColor.white, range: currentTimeRange)
                self.videoTimeLabel.attributedText = attributedText
                self.videoTimeLabel.isHidden = false
            }
            .store(in: &cancellables)
        
        // 監聽拖曳時間文字變化，更新拖曳時間標籤
        viewModel.$seekTimeText
            .receive(on: DispatchQueue.main)
            .sink { [weak self] timeText in
                guard let self else { return }

                self.seekTimeLabel.text = timeText
            }
            .store(in: &cancellables)
        
        // 監聽錯誤訊息變化，顯示錯誤提示
        viewModel.$errorMessage
            .receive(on: DispatchQueue.main)
            .compactMap { $0 }
            .sink { [weak self] errorMessage in
                guard let self else { return }

                self.showErrorAlert(with: errorMessage)
            }
            .store(in: &cancellables)
        
        // 監聽媒體資料變化，重新整理列表
        viewModel.$media
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self else { return }

                self.tableView.reloadData()
            }
            .store(in: &cancellables)
        
        // 監聽影片詳細資訊，更新 UI 元素
        viewModel.$videoDetail
            .receive(on: DispatchQueue.main)
            .sink { [weak self] videoDetail in
                guard let self, let videoDetail = videoDetail else { return }
                self.resetShowMore()
                self.videoTitleLabel.text = videoDetail.title
                self.videoSubtitleLabel.text = videoDetail.subtitle
                self.videoDescriptionLabel.text = videoDetail.description
                self.showMoreButton.isHidden = !self.videoDescriptionLabel.isTextExceedOneLine
            }
            .store(in: &cancellables)
        
        // 監聽當前影片index
        viewModel.$currentVideoIndex
            .receive(on: DispatchQueue.main)
            .sink { [weak self] index in
                guard let self = self,
                      let count = self.viewModel.media?.categories.first?.videos.count,
                      index < count else { return }
                self.tableView.selectRow(at: IndexPath(row: index, section: 0),
                                          animated: true,
                                          scrollPosition: .middle)
            }
            .store(in: &cancellables)
    }
    
    // 設定通知監聽
    func setupNotifications() {
        // 監聽應用程式進入背景的通知
        NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)
            .sink { [weak self] _ in
                guard let self else { return }

                self.handleAppDidEnterBackground()
            }
            .store(in: &cancellables)
    }
    
    // 處理應用程式進入背景的事件
    func handleAppDidEnterBackground() {
        // 進入背景時暫停播放並顯示控制面板
        viewModel.pause()
        showControlView()
    }
    
    // 根據螢幕方向更新全螢幕按鈕圖示和列表顯示狀態
    func updateFullScreenButtonIcon(for orientation: UIInterfaceOrientationMask) {
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
        // 取消可能存在的淡出任務
        cancelFadeOutTask()
        // 淡入顯示控制面板
        controlView.fadeIn(targetAlpha: 1)
        // 如果影片正在播放，啟動淡出任務
        if viewModel.isPlaying {
            fadeOutControlView()
        }
    }
    
    // 隱藏控制面板
    func hideControlView() {
        // 取消可能存在的淡出任務
        cancelFadeOutTask()
        // 淡出隱藏控制面板
        controlView.fadeOut()
    }
    
    // 取消淡出任務
    func cancelFadeOutTask() {
        fadeOutTask?.cancel()
        fadeOutTask = nil
    }
    
    // 設定控制面板的自動淡出
    func fadeOutControlView() {
        // 取消可能存在的淡出任務
        cancelFadeOutTask()
        // 建立新的淡出任務
        fadeOutTask = Task {
            do {
                // 等待指定時間後執行淡出
                try await Task.sleep(nanoseconds: TimeConstants.controlsFadeOutTime)
            } catch {
                return
            }
            await MainActor.run { [weak self] in
                guard let self = self else { return }
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
    
    // 重設ShowMore
    func resetShowMore() {
        isShowingMore = false
        showMoreButton.setTitle(UIConstants.showMoreText, for: .normal)
        videoDescriptionLabel.numberOfLines = 1
    }
}

// MARK: - UITableViewDataSource
extension VideoPlayerViewController: UITableViewDataSource {
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return viewModel.media?.categories.count ?? 0
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return viewModel.media?.categories[safe: section]?.videos.count ?? 0
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return viewModel.media?.categories[safe: section]?.name
    }
    
    func tableView(_ tableView: UITableView,
                   cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "VideoListTableViewCell",
                                                       for: indexPath) as? VideoListTableViewCell,
              let video = viewModel.media?.categories[safe: indexPath.section]?.videos[safe: indexPath.row] else {
            return UITableViewCell()
        }
        cell.configure(with: video)
        return cell
    }
}

// MARK: - UITableViewDelegate
extension VideoPlayerViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView,
                   didSelectRowAt indexPath: IndexPath) {
        guard indexPath.section == 0 else { return }
        videoTimeLabel.isHidden = true
        viewModel.updateVideo(at: indexPath.row)
        progressSlider.value = 0
    }
}
