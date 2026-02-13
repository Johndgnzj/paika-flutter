# Paika v3.0.0 — Firebase 雲端同步 開發計畫

> **目的：** 供 AI Developer 按 Phase 順序逐步實作。
> **前置文件：** [V2_TODO.md](./V2_TODO.md)（已完成）

## Context

目前 Paika 所有資料存在本地 SharedPreferences，無法跨裝置、無雲端備份。v3 目標是將資料上雲（Cloud Firestore），同時加入多場次管理和匯出報表功能。

**使用者決策：**
- 認證：保留本地 Auth（SHA-256），不遷移到 Firebase Auth
- 資料庫：Cloud Firestore
- 範圍：雲端同步 + 多場次管理 + 匯出報表（不含社群、頭像上傳、App 上架）

---

## 一、安全性架構設計

### 核心問題：沒有 Firebase Auth 如何保護 Firestore？

使用 **Firebase Anonymous Auth** 作為透明安全層：
- App 啟動時自動靜默登入 Anonymous Auth（使用者完全無感）
- 每台裝置獲得唯一 Firebase UID
- Firestore Security Rules 以此 UID 限制存取範圍
- 本地 Auth（登入/註冊/登出）UI 和邏輯完全不變
- **密碼 hash 永遠不上傳到 Firestore**，只有牌局資料/玩家檔案/設定會同步

### 三層安全防護

```
第 1 層：Firebase Anonymous Auth
  → 每個請求帶有 Firebase UID
  → Security Rules 確保 users/{uid}/ 只能被 uid 本人存取

第 2 層：Firestore Security Rules
  → 欄位驗證（型別、長度、大小）
  → 禁止跨用戶存取
  → 禁止刪除用戶 profile

第 3 層：Firebase App Check
  → Web: reCAPTCHA v3（驗證請求來自合法網站）
  → iOS: App Attest（驗證請求來自合法 App）
  → Android: Play Integrity（驗證請求來自合法 App）
  → 阻擋 curl / 腳本等非法來源的請求
```

### API Key 限制（每平台）

| 平台 | 限制方式 | 限制值 |
|------|---------|--------|
| Web | HTTP Referrer | `paika-13250.web.app/*`, `localhost:*` |
| iOS | Bundle ID | `com.vibeprojects.mahjongScorer` |
| Android | Package Name + SHA-1 | `com.vibeprojects.mahjong_scorer` + 簽章指紋 |

---

## 二、Firestore 資料結構

```
users/{firebaseUid}                         ← 用戶根文件（profile）
  ├── settings/default                      ← GameSettings
  ├── playerProfiles/{profileId}            ← PlayerProfile 文件
  ├── games/{gameId}                        ← Game 文件（含嵌入的 rounds）
  └── savedPlayers/default                  ← 快速選擇玩家列表
```

**設計決策：**
- Rounds 嵌入 Game 文件（非 subcollection）：典型牌局 16-64 局 × ~300 bytes ≈ 5-20KB，遠低於 Firestore 1MB 上限
- Account / passwordHash / salt **不存入 Firestore**，永遠只在本地
- Link codes 保持本地（本機多帳號功能，不需上雲）

### 對應 SharedPreferences Keys → Firestore Paths

| SharedPreferences Key | Firestore Path |
|----------------------|----------------|
| `games` (filtered by accountId) | `users/{uid}/games/{gameId}` |
| `settings_{accountId}` | `users/{uid}/settings/default` |
| `player_profiles_{accountId}` | `users/{uid}/playerProfiles/{profileId}` |
| `players_{accountId}` | `users/{uid}/savedPlayers/default` |
| `accounts` | **不上傳**（含密碼 hash） |
| `current_account_id` | **不上傳**（本地狀態） |
| `link_codes` | **不上傳**（本機功能） |

---

## 三、同步策略

```
寫入流程：
  UI 操作 → GameProvider → StorageService
    ├── 寫入 SharedPreferences（同步，保證本地即時可用）
    └── 寫入 Firestore（非同步 fire-and-forget，失敗只 log 不 throw）

啟動流程：
  App 啟動 → Firebase.initializeApp() → Anonymous Auth
    → StorageService.syncFromCloud()（從 Firestore 拉最新資料到本地）
    → 正常載入（從 SharedPreferences 讀取）

離線流程：
  Firestore 自帶離線快取（iOS/Android: SQLite, Web: IndexedDB）
  → 寫入操作排入離線佇列
  → 恢復連線時自動同步
  → 使用者完全無感
```

---

## 四、實作任務清單

### Phase 0 — Firebase 專案設定

**Task 0-1：Firebase Console 設定**
- 在 Firebase Console (`paika-13250`) 啟用 Cloud Firestore（production mode, `asia-east1`）
- 啟用 Authentication > Anonymous 登入方式

**Task 0-2：FlutterFire CLI 設定**
```bash
dart pub global activate flutterfire_cli
flutterfire configure --project=paika-13250 \
  --platforms=ios,android,web \
  --ios-bundle-id=com.vibeprojects.mahjongScorer \
  --android-package-name=com.vibeprojects.mahjong_scorer
```
產出檔案：
- `lib/firebase_options.dart`
- `ios/Runner/GoogleService-Info.plist`
- `android/app/google-services.json`
- 更新 `web/index.html`

**Task 0-3：新增依賴**

修改 `pubspec.yaml`：
```yaml
# Firebase
firebase_core: ^3.13.0
firebase_auth: ^5.7.0
cloud_firestore: ^5.8.0
firebase_app_check: ^0.3.3+1

# Export
pdf: ^3.11.3
path_provider: ^2.1.5
share_plus: ^10.1.4
csv: ^6.0.0
```

**Task 0-4：建立 Firestore 設定檔**
- 新增 `firestore.rules`（內容見 Phase 2）
- 新增 `firestore.indexes.json`（空索引）
- 更新 `firebase.json` 加入 firestore 區塊
- 更新 `.gitignore` 排除平台設定檔

---

### Phase 1 — Firebase Anonymous Auth（靜默整合）

**Task 1-1：建立 FirebaseInitService**

新增 `lib/services/firebase_init_service.dart`

職責：
1. `Firebase.initializeApp()`
2. `FirebaseAppCheck.instance.activate()`（各平台 provider）
3. `FirebaseAuth.instance.signInAnonymously()`（如尚未登入）
4. 提供 `firebaseUid` getter

**Task 1-2：更新 main.dart**

在 `runApp()` 前呼叫 `FirebaseInitService.initialize()`

**驗收：**
- 三平台啟動無錯誤
- `FirebaseAuth.instance.currentUser` 非 null
- 使用者看不到任何差異

---

### Phase 2 — Firestore Security Rules

新增 `firestore.rules`

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // 預設拒絕所有
    match /{document=**} {
      allow read, write: if false;
    }

    match /users/{userId} {
      function isOwner() {
        return request.auth != null && request.auth.uid == userId;
      }

      // 用戶 profile
      allow read: if isOwner();
      allow create: if isOwner()
        && request.resource.data.keys().hasAll(['localAccountId', 'createdAt'])
        && request.resource.data.size() <= 10;
      allow update: if isOwner()
        && request.resource.data.size() <= 10;
      allow delete: if false;

      // 設定
      match /settings/{doc} {
        allow read, write: if isOwner()
          && request.resource.data.size() <= 20;
      }

      // 玩家檔案
      match /playerProfiles/{profileId} {
        allow read: if isOwner();
        allow create, update: if isOwner()
          && request.resource.data.keys().hasAll(['name', 'emoji'])
          && request.resource.data.name is string
          && request.resource.data.name.size() <= 50
          && request.resource.data.size() <= 15;
        allow delete: if isOwner();
      }

      // 牌局
      match /games/{gameId} {
        allow read: if isOwner();
        allow create, update: if isOwner()
          && request.resource.data.keys().hasAll(['id', 'status', 'players'])
          && request.resource.data.size() <= 500;
        allow delete: if isOwner();
      }

      // 已存玩家
      match /savedPlayers/{doc} {
        allow read, write: if isOwner()
          && request.resource.data.size() <= 100;
      }
    }
  }
}
```

**安全性保障：**
- `isOwner()` 確保只有 UID 本人可存取自己的資料
- 欄位驗證防止注入不合法資料
- 文件大小限制防止濫用
- 預設 deny-all，只開放明確路徑

---

### Phase 3 — Firebase App Check

**Task 3-1：Web — reCAPTCHA v3**
- 在 Google reCAPTCHA 管理後台註冊站點
- 允許域名：`paika-13250.web.app`, `localhost`
- 在 Firebase Console App Check 中註冊

**Task 3-2：iOS — App Attest**
- Apple Developer Portal 啟用 App Attest
- Firebase Console App Check 註冊

**Task 3-3：Android — Play Integrity**
- Firebase Console App Check 註冊
- 關聯 Google Play Console

**Task 3-4：啟用強制執行**
- 在所有平台測試通過後，Firebase Console > App Check > Firestore > Enforce

---

### Phase 4 — FirestoreService（新服務）

新增 `lib/services/firestore_service.dart`

提供靜態方法，對應現有 StorageService 的 API：

| 方法 | 說明 |
|------|------|
| `saveUserProfile(localAccountId, localAccountName)` | 建立/更新用戶 profile |
| `saveGame(Game)` | 儲存牌局 |
| `loadGames()` | 載入所有牌局 |
| `deleteGame(gameId)` | 刪除牌局 |
| `saveSettings(GameSettings)` | 儲存設定 |
| `loadSettings()` | 載入設定 |
| `savePlayerProfile(PlayerProfile)` | 儲存玩家檔案 |
| `loadPlayerProfiles()` | 載入所有玩家檔案 |
| `deletePlayerProfile(id)` | 刪除玩家檔案 |
| `saveSavedPlayers(List<Player>)` | 儲存快速選擇列表 |
| `loadSavedPlayers()` | 載入快速選擇列表 |

所有方法透過 `FirebaseAuth.instance.currentUser!.uid` 取得路徑前綴。

---

### Phase 5 — StorageService 重構（Write-Through）

修改 `lib/services/storage_service.dart`

**新增：**
- `_cloudEnabled` flag（Firebase 初始化後開啟）
- `enableCloud()` 方法
- `_syncToCloudAsync(Future<void> Function())` — 非同步雲端寫入，錯誤只 log
- `syncFromCloud({required String accountId})` — 從 Firestore 拉取資料覆蓋本地

**修改所有寫入方法：**
- `saveGame()` → 尾部加 `_syncToCloudAsync(() => FirestoreService.saveGame(game))`
- `deleteGame()` → 同上
- `saveSettings()` → 同上
- `savePlayerProfile()` → 同上
- `deletePlayerProfile()` → 同上
- `savePlayers()` → 同上

**讀取方法不變**（始終從 SharedPreferences 讀取，啟動時已從雲端同步）

---

### Phase 6 — GameProvider 更新

修改 `lib/providers/game_provider.dart`

在 `_initializeForAccount()` 中加入：
```dart
// 既有
await StorageService.migrateOrphanGames(accountId);

// 新增
StorageService.enableCloud();
await StorageService.syncFromCloud(accountId: accountId);

// 既有（此時本地資料已是最新）
_settings = await StorageService.loadSettings(accountId: accountId);
// ... 其餘載入邏輯不變
```

新增方法（多場次管理）：
- `renameGame(gameId, name)` — 更新 Game.name 並存儲
- `deleteGameFromHistory(gameId)` — 刪除牌局
- `searchGames(query)` — 按玩家名/牌局名/日期搜尋

---

### Phase 7 — 多場次管理 UI

**Task 8-1：Game model 新增 name 欄位**

修改 `lib/models/game.dart`：
- 新增 `final String? name`
- 更新 `toJson()`, `fromJson()`, `copyWith()`

**Task 8-2：更新 HomeScreen**

修改 `lib/screens/home_screen.dart`：
- 改為 StatefulWidget（持有搜尋狀態）
- 新增搜尋欄位（TextField + 搜尋圖示）
- 牌局卡片新增 PopupMenuButton（重新命名 / 刪除）
- 重新命名彈窗（TextField dialog）
- 刪除確認彈窗

---

### Phase 8 — 匯出報表

**Task 9-1：建立 ExportService**

新增 `lib/services/export_service.dart`

| 方法 | 輸出 |
|------|------|
| `exportGameToJson(Game)` | JSON 字串（完整牌局資料） |
| `exportAllGamesToJson(List<Game>)` | JSON 字串（批次匯出） |
| `exportGameToCsv(Game)` | CSV 字串（局號/風位/類型/各玩家分數） |
| `exportGameToPdf(Game)` | PDF bytes（排版報表含排名和局數明細） |
| `shareFile(content, filename, mimeType)` | 分享/下載（平台適配） |
| `sharePdf(bytes, filename)` | 分享/下載 PDF |

Web 平台需 conditional import（`dart:html` 的 download 機制）。

**Task 9-2：GameDetailScreen 匯出入口**

修改 `lib/screens/game_detail_screen.dart`：
- 實作匯出 BottomSheet（JSON / CSV / PDF 三選項）

**Task 9-3：SettingsScreen 批次匯出**

修改 `lib/screens/settings_screen.dart`：
- 新增「資料管理」區塊
- 「匯出所有牌局」按鈕（JSON 格式）

---

### Phase 9 — 離線支援

在 `FirebaseInitService.initialize()` 中設定：
```dart
FirebaseFirestore.instance.settings = const Settings(
  persistenceEnabled: true,
  cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
);
```

- iOS/Android：Firestore 預設啟用離線快取（SQLite）
- Web：透過 IndexedDB 啟用離線快取
- 離線寫入自動排入佇列，恢復連線後同步

---

## 五、檔案影響總覽

### 新增檔案（6 個 + 3 個自動產生）

| 檔案 | 任務 |
|------|------|
| `lib/firebase_options.dart` | Phase 0（FlutterFire CLI 自動產生） |
| `lib/services/firebase_init_service.dart` | Phase 1 |
| `lib/services/firestore_service.dart` | Phase 4 |
| `lib/services/export_service.dart` | Phase 8 |
| `firestore.rules` | Phase 2 |
| `firestore.indexes.json` | Phase 0 |
| `ios/Runner/GoogleService-Info.plist` | Phase 0（自動產生） |
| `android/app/google-services.json` | Phase 0（自動產生） |
| `docs/V3_PLAN.md` | 本文件 |

### 修改檔案（9 個）

| 檔案 | 變更 |
|------|------|
| `pubspec.yaml` | 新增 Firebase + 匯出相關依賴 |
| `lib/main.dart` | runApp 前初始化 Firebase |
| `lib/services/storage_service.dart` | Write-through 雲端同步 |
| `lib/providers/game_provider.dart` | 雲端初始化 + 多場次管理方法 |
| `lib/models/game.dart` | 新增 name 欄位 |
| `lib/screens/home_screen.dart` | 搜尋 + 重新命名/刪除 UI |
| `lib/screens/game_detail_screen.dart` | 匯出 BottomSheet |
| `lib/screens/settings_screen.dart` | 批次匯出入口 |
| `firebase.json` | 新增 Firestore 區塊 |

### 不變動

- `lib/services/auth_service.dart`（本地 Auth 不變）
- `lib/services/link_service.dart`（本機功能不變）
- `lib/services/calculation_service.dart`
- `lib/services/stats_service.dart`
- 所有現有 widgets / charts
- `lib/utils/theme.dart`, `lib/utils/constants.dart`

---

## 六、風險評估

| 風險 | 影響 | 緩解措施 |
|------|------|---------|
| Anonymous Auth UID 遺失（清除 App 資料） | 雲端資料孤立，無法存取 | 本地 SharedPreferences 仍可用；未來可加帳號恢復機制 |
| Firestore 文件大小超限（超長牌局） | 寫入失敗 | 200 局 ≈ 60KB，遠低於 1MB；極端情況才可能超限 |
| Web 離線快取被瀏覽器清除 | 離線資料遺失 | 提示使用者勿清除瀏覽器資料；重新上線後從雲端拉回 |
| PDF 在 Web 的 conditional import | 編譯複雜度 | 使用 Dart conditional import 分離 web / native 實作 |

---

## 七、驗證計畫

### 安全性驗證
1. Firebase Console Rules Playground 測試：自己的 UID → 允許，其他 UID → 拒絕
2. 未認證請求 → 拒絕
3. 不合法資料結構 → 拒絕
4. 啟用 App Check 後，curl 請求 → 403

### 功能驗證
1. 全新安裝 → 註冊 → 建立牌局 → 打完 → 資料出現在 Firebase Console
2. 離線模式 → 打完一局 → 上線 → 資料自動同步
3. 多場次管理 → 搜尋/重命名/刪除 → 本地和雲端一致
4. 匯出 JSON/CSV/PDF → 在三個平台都可正常分享/下載

### 平台測試矩陣

| 測試項目 | iOS | Android | Web |
|---------|-----|---------|-----|
| Firebase 初始化 | | | |
| Anonymous Auth | | | |
| Firestore 讀寫 | | | |
| 離線快取 | | | |
| App Check | | | |
| 匯出 JSON/CSV/PDF | | | |

---

*最後更新：2026-02-12*
