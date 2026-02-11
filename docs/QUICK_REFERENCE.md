# 🎯 Paika 快速參考卡

## 📍 專案位置
```
~/Documents/vibe_projects/paika/
```

## 🚀 首次部署（3 步驟）

### 1. 建立 Firebase 專案
https://console.firebase.google.com/ → 新增專案 → 名稱 "paika"

### 2. 登入並連結
```bash
firebase login
cd ~/Documents/vibe_projects/paika
firebase use --add
```

### 3. 部署
```bash
./scripts/deploy.sh
```

## 🔄 後續更新

```bash
cd ~/Documents/vibe_projects/paika
./scripts/deploy.sh
```

## 📱 本地測試

```bash
# 開啟編譯好的網頁
open build/web/index.html

# 或啟動開發模式
flutter run -d chrome
```

## 🛠️ 常用指令

| 指令 | 用途 |
|------|------|
| `./scripts/deploy.sh` | 完整部署流程 |
| `flutter build web --release` | 只編譯 |
| `firebase deploy` | 只部署 |
| `flutter test` | 執行測試 |
| `flutter analyze` | 程式碼檢查 |
| `firebase serve` | 本地預覽 |

## 📚 文件快速索引

| 文件 | 何時看 |
|------|--------|
| `HANDOVER.md` | 👉 **從這裡開始** |
| `FIREBASE_SETUP.md` | 設定 Firebase |
| `DEPLOY_CHECKLIST.md` | 部署前檢查 |
| `README.md` | 完整功能說明 |
| `QUICKSTART.md` | 使用教學 |
| `CHANGELOG.md` | 查看更新記錄 |

## 🔐 授權 Neo 自動部署

```bash
firebase login:ci
```
將產生的 token 給 Neo → 未來自動更新

## 🆘 出問題了？

### 部署失敗
1. 檢查網路
2. 確認已登入：`firebase login`
3. 確認專案連結：`firebase use`

### 編譯錯誤
```bash
flutter clean
flutter pub get
flutter build web --release
```

### 忘記網址
```bash
firebase hosting:sites:list
```

## 📊 監控

**Firebase Console**  
https://console.firebase.google.com/ → 選擇 paika → Hosting

查看：
- 流量數據
- 部署歷史
- 錯誤日誌

## 🎯 網址格式

- 預設：`https://paika.web.app`
- 備用：`https://paika.firebaseapp.com`
- 自訂：設定後可用自己的網域

---

**💡 提示**：第一次部署成功後，把網址存起來！
