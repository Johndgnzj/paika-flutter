# 🀄 Paika（牌咖）

一個使用 Flutter 開發的跨平台麻將記分應用程式，支援 Web、iOS 和 Android。

**Paika**，台語「牌咖」的諧音，意指打牌的人、牌友。讓你輕鬆記錄每一局精彩時刻！

## ✨ 功能特色

### MVP 版本（已完成）
- ✅ **即時記分介面** - 點擊玩家直接操作，快速記錄
- ✅ **胡牌記錄** - 支援放槍、自摸、詐胡
- ✅ **一炮多響** - 多人同時胡牌
- ✅ **電子骰子** - 內建隨機骰子
- ✅ **換位置** - 調整玩家座位
- ✅ **還原上局** - 誤操作可還原
- ✅ **本地儲存** - 自動儲存遊戲進度
- ✅ **歷史紀錄** - 查看過往牌局
- ✅ **深色模式** - 支援系統主題切換

### 計畫中功能
- [ ] 玩家統計分析
- [ ] 匯出報表（PDF/Excel）
- [ ] Firebase 雲端同步
- [ ] 一炮多響進階功能
- [ ] 流局處理
- [ ] 多人連線對戰

## 🎮 使用方式

### 網頁版（立即使用）

1. 打開瀏覽器，開啟 `build/web/index.html`
2. 或使用 HTTP 伺服器：
   ```bash
   cd build/web
   python3 -m http.server 8000
   ```
3. 瀏覽器訪問 `http://localhost:8000`

### 開發模式

```bash
# 安裝依賴
flutter pub get

# 執行網頁版（開發模式）
flutter run -d chrome

# 執行桌面版（macOS）
flutter run -d macos

# 編譯 Release 版本
flutter build web --release
flutter build apk --release  # Android
flutter build ios --release  # iOS (需 macOS + Xcode)
```

## 📱 螢幕截圖

*(待補充實際畫面截圖)*

## 🎯 遊戲規則設定

### 底台設定
- 預設組合：
  - 50×20
  - 100×20
  - 100×50
  - 300×50
  - 500×100
- 支援自訂底分和上限台數

### 計分規則
- **公式**：底分 × 2^台數
- **自摸**：加 1 台（可設定）
- **花牌**：由玩家自行計算輸入
- **詐胡**：
  - 賠付台數：8 台（可設定）
  - 可設定賠三家或賠一家

### 連莊規則
- 莊家胡牌 → 連莊
- 流局聽牌 → 連莊

## 🏗️ 技術架構

### 技術棧
- **框架**：Flutter 3.38.9
- **語言**：Dart 3.10.8
- **狀態管理**：Provider
- **本地儲存**：shared_preferences
- **路由**：go_router
- **UI**：Material 3

### 專案結構
```
lib/
├── main.dart                 # 應用入口
├── models/                   # 資料模型
│   ├── player.dart          # 玩家
│   ├── game.dart            # 牌局
│   ├── round.dart           # 單局
│   └── settings.dart        # 設定
├── screens/                 # 畫面
│   ├── home_screen.dart     # 首頁
│   ├── game_setup_screen.dart    # 新局設定
│   └── game_play_screen.dart     # 即時記分
├── widgets/                 # 可複用元件
├── services/                # 業務邏輯
│   ├── storage_service.dart # 本地儲存
│   └── calculation_service.dart # 分數計算
├── providers/               # 狀態管理
│   └── game_provider.dart   # 遊戲狀態
└── utils/                   # 工具函數
    ├── constants.dart       # 常數
    └── theme.dart          # 主題
```

## 🧪 測試

```bash
# 執行所有測試
flutter test

# 程式碼分析
flutter analyze

# 檢查套件更新
flutter pub outdated
```

## 📦 編譯產物

### 網頁版
- 位置：`build/web/`
- 大小：約 2-3 MB（壓縮後）
- 瀏覽器支援：Chrome, Safari, Firefox, Edge (最新版本)
- **線上版本**：https://paika.web.app（待部署）

### App 版本（未來）
- iOS：需 macOS + Xcode
- Android：需 Android SDK

## 🚀 部署到 Firebase

詳細步驟請參考 [FIREBASE_SETUP.md](docs/FIREBASE_SETUP.md)

快速部署：
```bash
./scripts/deploy.sh
```

## 🛠️ 開發筆記

### 已知問題
- [ ] 一炮多響功能待完整實作
- [ ] 換位置功能介面待優化
- [ ] 流局處理簡化版（不區分聽牌）

### 效能優化
- ✅ Icon 樹搖優化（減少 99.4% 字型檔案大小）
- ✅ Web 編譯最佳化
- [ ] 圖片資源壓縮
- [ ] 延遲載入歷史紀錄

### 未來改進
1. **UI/UX**
   - 加入動畫效果
   - 優化手機橫向模式
   - 加入音效回饋
   
2. **功能**
   - 匯出戰績為 PDF
   - 玩家頭像上傳
   - 多語言支援
   
3. **資料**
   - Firebase 即時同步
   - 跨裝置共享牌局
   - 雲端備份

## 📄 授權

MIT

## 👥 貢獻

歡迎提出 Issue 或 Pull Request！

## 📞 聯絡

*(請補充聯絡資訊)*

---

**開發時間**：2026-02-09  
**版本**：1.0.0 (MVP)  
**開發者**：Neo (小杰) - 虛擬邊界的觀測者
