# 🔥 Firebase 設定與部署指南

## 📋 前置準備

### 1. 建立 Firebase 專案

1. 前往 [Firebase Console](https://console.firebase.google.com/)
2. 點擊「新增專案」或「Add project」
3. 專案名稱輸入：**paika** 或 **Paika**
4. 專案 ID 建議設為：**paika**（如果可用）
5. 選擇是否啟用 Google Analytics（建議啟用）
6. 完成建立

### 2. 啟用 Firebase Hosting

1. 在 Firebase Console 左側選單選擇「Hosting」
2. 點擊「開始使用」
3. 跟隨步驟（我們已經準備好配置檔案了）

## 🚀 部署步驟

### 方式 1：使用部署腳本（推薦）

1. **首次登入 Firebase**
   ```bash
   firebase login
   ```
   會開啟瀏覽器讓你登入 Google 帳號

2. **初始化專案（只需執行一次）**
   ```bash
   cd ~/Documents/vibe_projects/paika
   firebase use --add
   ```
   選擇你剛建立的 Firebase 專案（paika）

3. **執行自動部署腳本**
   ```bash
   cd ~/Documents/vibe_projects/paika
   ./deploy.sh
   ```
   
   腳本會自動：
   - 清理舊檔案
   - 安裝依賴
   - 編譯 Web 版本
   - 部署到 Firebase

4. **完成！**
   部署成功後會顯示網址，通常是：
   - https://paika.web.app
   - https://paika.firebaseapp.com

### 方式 2：手動部署

```bash
cd ~/Documents/vibe_projects/paika

# 1. 登入
firebase login

# 2. 選擇專案
firebase use paika

# 3. 編譯
flutter build web --release

# 4. 部署
firebase deploy --only hosting
```

## 🔄 後續更新流程

每次要更新線上版本：

```bash
cd ~/Documents/vibe_projects/paika
./deploy.sh
```

或

```bash
flutter build web --release
firebase deploy --only hosting
```

## 📝 設定自訂網域（選用）

1. 在 Firebase Console 的 Hosting 頁面
2. 點擊「新增自訂網域」
3. 輸入你的網域（例如：paika.app）
4. 依照指示設定 DNS 記錄
5. 等待驗證完成（通常幾分鐘到幾小時）

## 🎯 自動化部署（進階）

### 使用 GitHub Actions

建立 `.github/workflows/deploy.yml`：

```yaml
name: Deploy to Firebase

on:
  push:
    branches: [ main ]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.38.9'
      - run: flutter pub get
      - run: flutter build web --release
      - uses: FirebaseExtended/action-hosting-deploy@v0
        with:
          repoToken: '${{ secrets.GITHUB_TOKEN }}'
          firebaseServiceAccount: '${{ secrets.FIREBASE_SERVICE_ACCOUNT }}'
          channelId: live
          projectId: paika
```

## 🛠️ 常用指令

```bash
# 查看當前專案
firebase projects:list

# 切換專案
firebase use paika

# 本地測試
firebase serve

# 查看部署歷史
firebase hosting:channel:list

# 回滾到上一版本
firebase hosting:clone SOURCE_SITE_ID:SOURCE_CHANNEL_ID TARGET_SITE_ID:live
```

## 📊 監控和分析

### Firebase Console
- **Hosting**: 查看流量、請求數
- **Analytics**: 使用者行為分析（如有啟用）
- **Performance**: 效能監控

### 設定 Google Analytics（選用）

1. 在 Firebase Console 啟用 Analytics
2. 在 Flutter 專案中加入：
   ```yaml
   dependencies:
     firebase_core: latest
     firebase_analytics: latest
   ```
3. 初始化並使用

## ⚠️ 注意事項

1. **首次部署前**：確認 `.firebaserc` 中的專案 ID 正確
2. **安全性**：不要將 `firebase-debug.log` 提交到 Git
3. **快取**：部署後可能需要等 5-10 分鐘才完全生效
4. **憑證**：定期檢查 Firebase token 是否過期

## 🆘 疑難排解

### 問題：`firebase: command not found`
```bash
npm install -g firebase-tools
```

### 問題：權限錯誤
```bash
firebase login --reauth
```

### 問題：部署失敗
1. 檢查網路連線
2. 確認 Firebase 專案存在
3. 檢查 `firebase.json` 配置
4. 確認 `build/web` 資料夾存在

---

**準備好了嗎？執行 `./deploy.sh` 開始部署！** 🚀
