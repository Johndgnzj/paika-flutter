# 🀄 Paika（牌咖）— 麻將記分系統

[![Flutter](https://img.shields.io/badge/Flutter-3.38-blue?logo=flutter)](https://flutter.dev)
[![Firebase](https://img.shields.io/badge/Firebase-Hosting-orange?logo=firebase)](https://firebase.google.com)
[![License](https://img.shields.io/badge/License-MIT-green)](LICENSE)

**Paika**，台語「牌咖」的諧音，意指打牌的人、牌友。

一款使用 Flutter 開發的跨平台麻將記分 App，支援 Web、iOS、Android。不用紙筆、不用算數，讓你專心享受打牌的樂趣！

👉 **立即使用**：[https://paika-13250.web.app](https://paika-13250.web.app)

---

## ✨ 功能特色

### 即時計分
- 點擊玩家卡片即可記錄 **胡牌**、**自摸**、**詐胡**
- **一炮多響** — 一位放槍、多位同時胡牌
- **流局** — 一鍵處理，自動連莊
- **電子骰子** — 三顆骰子隨機擲出
- **換位置** — 點選交換玩家座位
- **還原上局** — 誤操作可一鍵還原
- 自動計算莊家輪替、風圈（東風東局、南風西局…）

### 計分規則（可自訂）
- 底台組合：50×20、100×20、100×50、300×50、500×100，或自訂
- 公式：底分 × 台數
- 進階設定：自摸加台、莊家加台、連莊加台（皆可開關）
- 詐胡台數與賠付規則可調整

### 帳號與雲端同步
- 註冊/登入帳號，資料自動同步至雲端（Firebase）
- 支援多裝置登入，資料即時同步
- 離線也能使用，上線後自動同步

### 玩家管理
- 建立常用玩家名單，開局時快速選用
- 每位玩家有專屬 emoji 頭像（32 款可選）
- 連結碼機制：分享 6 位數連結碼，讓牌友也能查看共同牌局

### 統計與圖表
- **戰績總覽**：勝率、平均得分、胡牌/自摸/放槍次數
- **分數趨勢圖**：近 20 場分數折線圖
- **勝率圓餅圖**：直覺顯示勝負比例
- **台數分布圖**：分析常見台數範圍
- **對手分析**：與每位對手的勝負紀錄

### 牌局管理
- 搜尋、重新命名、刪除歷史牌局
- 牌局詳情：最終排名、數據統計、每局明細（按風圈分組）
- 匯出報表：支援 **JSON**、**CSV**、**PDF** 三種格式

### 其他
- 深色 / 淺色模式切換
- 內建使用手冊
- 服務條款與隱私權政策

---

## 📱 螢幕截圖

*(即將補充)*

---

## 🛠️ 技術架構

| 項目 | 技術 |
|------|------|
| 框架 | Flutter 3.38 / Dart 3.10 |
| 狀態管理 | Provider |
| 後端 | Firebase (Auth + Cloud Firestore) |
| 部署 | Firebase Hosting |
| UI | Material 3 |
| 圖表 | fl_chart |
| 匯出 | pdf / csv / share_plus |

---

## 🚀 開發與部署

### 本地開發

```bash
# 安裝依賴
flutter pub get

# 執行網頁版
flutter run -d chrome

# 執行 macOS 桌面版
flutter run -d macos
```

### 編譯與部署

```bash
# 編譯 Web
flutter build web --release

# 部署到 Firebase Hosting
firebase deploy --only hosting
```

詳細 Firebase 設定請參考 [FIREBASE_SETUP.md](docs/FIREBASE_SETUP.md)。

---

## 📋 版本紀錄

| 版本 | 說明 |
|------|------|
| v1.0.0 | MVP：即時計分、胡牌/自摸/詐胡/流局、骰子、換位、歷史紀錄 |
| v1.1.0 | 一炮多響、換位優化、流局完整版、動畫效果、設定頁面 |
| v2.0.0 | 帳號系統、玩家登錄與連結、玩家統計、圖表視覺化 |
| v3.0.0 | Firebase 雲端同步、多場次管理、匯出報表（JSON/CSV/PDF） |
| v3.1.0 | 金色主題、全新 Logo、使用手冊、服務條款與隱私權政策 |
| v3.2.x | 語音記分、UI 優化、Bug 修復（開發中） |

---

## 📄 授權

MIT License

---

**開發者**：Neo (小杰)
