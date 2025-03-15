# GlossikaPlayer - 播放範例

這個專案提供一個簡單的播放畫面，利用 AVPlayer 播放影片，並結合 UIKit 與 Combine 管理播放狀態與進度更新。適用於 iOS 16.6 以上，僅供展示播放功能使用。

## 介紹

**GlossikaPlayer 播放畫面** 只包含單一畫面，提供基本的影片播放功能：
- 使用 **AVPlayer** 播放影片
- 透過 **UIKit** 建構簡單的使用者介面
- 結合 **Combine** 管理播放狀態、進度更新與錯誤處理

此專案旨在展示如何整合 AVPlayer、UIKit 與 Combine 的基本用法。

## 前置需求

- **開發工具：** Xcode 14 以上
- **目標平台：** iOS 16.6 以上
- **Swift 版本：** Swift 5.7 或更新版本

## 建置與運行

1. **複製專案：**

   ```bash
   git clone https://github.com/yourusername/GlossikaPlayer.git
   ```

2. **打開專案：**

   使用 Xcode 開啟 `GlossikaPlayer.xcodeproj`。

3. **運行專案：**

   選擇 iOS 模擬器（例如 iPhone 16），然後按下 Run 按鈕，即可看到簡單的播放畫面顯示並執行播放功能。

## 使用說明

- **播放功能：**  
  畫面上有一個播放/暫停按鈕，點擊後會切換播放狀態，並透過 Combine 更新播放進度。

- **進度控制：**  
  使用滑桿來控制影片進度，顯示目前播放時間。

- **擴充性：**  
  此專案架構簡單，未包含完整 App 功能。
