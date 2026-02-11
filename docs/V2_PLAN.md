# Paika v2.0.0 - 用戶歷程 開發計畫

## 目標

建立帳號系統與玩家登錄，讓牌局資料綁定帳號，並支援跨帳號的牌局共享與統計分析。

---

## 一、現狀分析

### 目前 Player 模型

```dart
// lib/models/player.dart
class Player {
  final String id;        // UUID，每場遊戲重新產生
  final String? userId;   // 未使用，預留欄位
  final String name;
  final String emoji;
  final String? avatarUrl; // 未使用
}
```

### 目前問題

1. **沒有帳號概念** — 所有資料存在本地 SharedPreferences，無身份識別
2. **玩家沒有持久身份** — 每次開新牌局，玩家 ID 都是全新的 UUID，無法跨牌局追蹤同一個人
3. **牌局無法共享** — 同一場牌局的 4 位玩家各自獨立，無法在不同裝置查看同一場牌局

---

## 二、資料架構

### 層級關係

```
Account（帳號）
  ├── PlayerProfile（帳號下登錄的玩家）
  │     ├── PlayerProfile A
  │     ├── PlayerProfile B
  │     └── ...
  └── Game（帳號擁有的牌局）
        ├── Game 1
        │     ├── Player（seat 0）→ 關聯到 PlayerProfile → 可連結到其他 Account
        │     ├── Player（seat 1）→ ...
        │     ├── Player（seat 2）→ ...
        │     └── Player（seat 3）→ ...
        └── Game 2
              └── ...
```

### Account 資料模型

```dart
class Account {
  final String id;              // UUID，永久不變
  final String name;            // 帳號顯示名稱
  final String? email;          // 可選，未來用於找回帳號或通知
  final String passwordHash;    // 密碼雜湊（SHA-256 + salt）
  final String salt;            // 隨機鹽值，每個帳號獨立
  final DateTime createdAt;     // 建立時間
  final DateTime lastLoginAt;   // 最後登入時間
}
```

**優化建議（相對你提供的結構）：**
- 加入 `salt` — 密碼不能只做 hash，需要加鹽防彩虹表攻擊
- 加入 `name` — 帳號需要顯示名稱，和 email 是不同用途
- `email` 保持 optional — 本地優先的 App 不強制收集 email
- 不存明文密碼 — 只存 `passwordHash`，登入時比對 hash

### PlayerProfile 資料模型

```dart
class PlayerProfile {
  final String id;              // 持久 UUID
  final String accountId;       // 所屬帳號
  final String name;            // 玩家名稱
  final String emoji;           // 頭像 emoji
  final String? linkedAccountId; // 連結到的另一個帳號（玩家共享用）
  final DateTime createdAt;
  final DateTime lastPlayedAt;
}
```

### 連結機制：跨帳號牌局共享

**場景：** 帳號 A 開了一場牌局，4 位玩家中「小明」其實是帳號 B 的使用者。透過連結功能，帳號 B 也能看到這場牌局。

**流程：**

```
帳號 A 的操作：
  1. 在玩家管理中，為「小明」建立 PlayerProfile
  2. 產生連結碼（6 位數，有效期 10 分鐘）

帳號 B 的操作：
  1. 輸入連結碼
  2. 系統將 帳號A 的「小明」PlayerProfile.linkedAccountId = 帳號B.id
  3. 帳號 B 查詢牌局時，同時查詢：
     - 自己帳號下的牌局
     - 所有 PlayerProfile.linkedAccountId == 自己帳號ID 的相關牌局
```

### 連結碼模型

```dart
class LinkCode {
  final String code;            // 6 位數連結碼
  final String playerProfileId; // 要連結的玩家
  final String fromAccountId;   // 發起方帳號
  final DateTime createdAt;
  final DateTime expiresAt;     // 過期時間（createdAt + 10 分鐘）
}
```

---

## 三、功能拆解

### Feature 0：帳號系統（Account System）

> App 的基礎身份層，所有資料綁定到帳號。

#### 0-1. Account model + AuthService

新增 `lib/models/account.dart`、`lib/services/auth_service.dart`：

**AuthService 職責：**
- `register(name, password, email?)` — 註冊新帳號
  - 產生 UUID + salt
  - 密碼做 SHA-256(password + salt) 存入 passwordHash
- `login(name, password)` — 登入驗證
  - 用帳號名稱查找 account
  - 比對 SHA-256(password + salt) == passwordHash
- `logout()` — 登出（清除 currentAccountId）
- `currentAccount` — 當前登入的帳號
- `updateAccount(name?, email?, newPassword?)` — 修改帳號資料

**本地儲存：**
- Storage key `'accounts'` — 所有帳號（StringList of JSON）
- Storage key `'current_account_id'` — 當前登入的帳號 ID

#### 0-2. 登入/註冊頁面

新增 `lib/screens/auth_screen.dart`：
- 切換「登入」/「註冊」模式
- 帳號名稱 + 密碼輸入
- Email 輸入（選填，僅註冊時顯示）
- 記住登入狀態（下次開 App 自動登入）

#### 0-3. App 啟動流程調整

修改 `lib/main.dart`：
```
App 啟動
  → 檢查 current_account_id
  → 有 → 直接進 HomeScreen
  → 無 → 進 AuthScreen（登入/註冊）
```

#### 0-4. 現有資料綁定帳號

所有 StorageService 的 CRUD 都加上 `accountId` 過濾：
- `saveGame(game)` → game 自動帶上 `accountId`
- `loadGames()` → 只載入當前帳號的牌局 + 透過 linkedAccountId 關聯的牌局
- `savePlayers()` / `loadPlayers()` → 按帳號隔離
- `saveSettings()` / `loadSettings()` → 按帳號隔離

---

### Feature 1：玩家登錄（Player Registry）

> 帳號下建立持久的玩家資料庫。

#### 1-1. PlayerProfile 資料模型

新增 `lib/models/player_profile.dart`（見上方資料架構）。

#### 1-2. PlayerProfile CRUD

在 `StorageService` 新增：
- `savePlayerProfile(profile)` — 建立/更新
- `loadPlayerProfiles(accountId)` — 載入該帳號的所有玩家
- `deletePlayerProfile(id)` — 刪除

在 `GameProvider` 新增：
- `playerProfiles` getter
- `addPlayerProfile(name, emoji)` — 自動帶入 currentAccountId
- `updatePlayerProfile(id, name?, emoji?)` — 編輯
- `deletePlayerProfile(id)` — 刪除

#### 1-3. 玩家管理頁面

新增 `lib/screens/player_list_screen.dart`：
- 列出當前帳號下的所有玩家（依最後參與時間排序）
- 新增 / 編輯 / 刪除玩家
- 顯示已連結標記（linkedAccountId 非空時）
- 點擊進入玩家統計頁面

入口：HomeScreen 新增「玩家管理」按鈕。

#### 1-4. 整合到開局流程

修改 `GameSetupScreen`：
- 每個玩家欄位增加「選擇已有玩家」按鈕
- 點擊後彈出 PlayerProfile 列表
- 選擇後自動填入名稱、emoji，並記錄 `Player.userId = profile.id`
- 仍允許臨時輸入（不關聯 profile）

---

### Feature 1.5：玩家連結（Player Linking）

> 讓不同帳號之間可以共享牌局資料。

#### 1.5-1. 連結碼機制

新增 `lib/models/link_code.dart`、`lib/services/link_service.dart`：

**LinkService 職責：**
- `generateLinkCode(playerProfileId)` — 產生 6 位數連結碼，存入本地，10 分鐘過期
- `redeemLinkCode(code, myAccountId)` — 驗證連結碼，將 playerProfile.linkedAccountId = myAccountId
- `unlinkPlayer(playerProfileId)` — 解除連結

#### 1.5-2. 連結 UI

在玩家管理頁面中：
- 每個玩家旁顯示「產生連結碼」按鈕
- 產生後顯示 6 位數碼 + 倒數計時
- 對方帳號在設定或玩家頁面輸入連結碼

#### 1.5-3. 牌局查詢擴展

修改 `loadGames()` 邏輯：
```
載入牌局 =
  自己帳號的牌局
  + 掃描所有帳號的牌局中，包含 linkedAccountId == myAccountId 的 PlayerProfile 的牌局
```

> **注意：** 目前是本地儲存，連結功能僅適用於同一裝置上的多帳號。未來接入 Firebase 後才能實現跨裝置共享。在本地版本中，此功能讓同一台手機/電腦上的不同帳號可以看到彼此的相關牌局。

---

### Feature 2：玩家統計頁面

> 顯示單一玩家的跨牌局戰績分析。

#### 2-1. 統計計算

新增 `lib/services/stats_service.dart`：

```dart
class PlayerStats {
  final int totalGames;        // 總場次
  final int totalRounds;       // 總局數
  final int wins;              // 胡牌次數
  final int selfDraws;         // 自摸次數
  final int losses;            // 放槍次數
  final int falseWins;         // 詐胡次數
  final double winRate;        // 勝率（胡+自摸 / 總局數）
  final int totalScore;        // 累計總得分
  final double avgScorePerGame;// 平均每場得分
  final int bestGameScore;     // 單場最高分
  final int worstGameScore;    // 單場最低分
  final double avgTai;         // 平均台數
  final int maxTai;            // 最高台數
  final Map<String, int> opponentWinCount;  // 對手勝負統計
  final List<GameSummary> recentGames;      // 近期牌局摘要
}
```

`StatsService.getPlayerStats(profileId, gameHistory)` — 遍歷所有牌局計算統計。

#### 2-2. 玩家統計頁面

新增 `lib/screens/player_stats_screen.dart`：

**頂部區塊：**
- 玩家 emoji + 名稱
- 總場次 / 勝率 / 累計得分

**戰績概覽區：**
- 胡牌、自摸、放槍、詐胡次數（4 格統計卡片）
- 平均台數 / 最高台數

**最近牌局：**
- 列出最近 10 場牌局
- 顯示日期、最終排名、得分
- 點擊可跳到 GameDetailScreen

**常見對手：**
- 最常一起打牌的玩家
- 對該對手的勝負記錄

---

### Feature 3：圖表視覺化

> 將統計數據以圖表方式呈現。

#### 3-1. 依賴套件

新增 `fl_chart` 套件（Flutter 圖表庫，輕量且高度自訂）。

#### 3-2. 圖表元件

新增 `lib/widgets/charts/`：

**分數趨勢圖** (`score_trend_chart.dart`)：
- 折線圖，X 軸為牌局時間，Y 軸為累計得分
- 顯示最近 20 場趨勢

**勝率圓餅圖** (`win_rate_pie_chart.dart`)：
- 胡牌 / 自摸 / 放槍 / 詐胡 / 流局 比例

**台數分布圖** (`tai_distribution_chart.dart`)：
- 長條圖，X 軸為台數，Y 軸為出現次數
- 顯示最常胡的台數區間

#### 3-3. 整合到統計頁面

在 `PlayerStatsScreen` 中以 Tab 或捲動方式展示三張圖表。

---

## 四、實作順序

```
Phase 1 — 帳號系統（Feature 0）
  ├── 1. Account model + AuthService
  ├── 2. AuthScreen（登入/註冊頁面）
  ├── 3. App 啟動流程調整（main.dart）
  └── 4. StorageService 加入 accountId 隔離

Phase 2 — 玩家登錄（Feature 1）
  ├── 5. PlayerProfile model
  ├── 6. StorageService CRUD
  ├── 7. GameProvider 擴展
  ├── 8. PlayerListScreen（玩家管理頁面）
  ├── 9. GameSetupScreen 修改（選擇已有玩家）
  └── 10. 開局時自動關聯 userId

Phase 3 — 玩家連結（Feature 1.5）
  ├── 11. LinkCode model + LinkService
  ├── 12. 連結 UI（產生碼 / 輸入碼）
  └── 13. loadGames 擴展查詢

Phase 4 — 統計功能（Feature 2）
  ├── 14. StatsService
  └── 15. PlayerStatsScreen

Phase 5 — 圖表（Feature 3）
  ├── 16. 加入 fl_chart 依賴
  ├── 17. 三個圖表元件
  └── 18. 整合到統計頁面
```

---

## 五、影響範圍

### 新增檔案
| 檔案 | 說明 |
|------|------|
| `lib/models/account.dart` | 帳號模型 |
| `lib/models/player_profile.dart` | 玩家檔案模型 |
| `lib/models/link_code.dart` | 連結碼模型 |
| `lib/services/auth_service.dart` | 帳號驗證服務 |
| `lib/services/link_service.dart` | 玩家連結服務 |
| `lib/services/stats_service.dart` | 統計計算服務 |
| `lib/screens/auth_screen.dart` | 登入/註冊頁面 |
| `lib/screens/player_list_screen.dart` | 玩家管理頁面 |
| `lib/screens/player_stats_screen.dart` | 玩家統計頁面 |
| `lib/widgets/charts/score_trend_chart.dart` | 分數趨勢圖 |
| `lib/widgets/charts/win_rate_pie_chart.dart` | 勝率圓餅圖 |
| `lib/widgets/charts/tai_distribution_chart.dart` | 台數分布圖 |

### 修改檔案
| 檔案 | 變更 |
|------|------|
| `lib/main.dart` | 啟動流程加入帳號檢查 |
| `lib/services/storage_service.dart` | 新增 Account/PlayerProfile/LinkCode CRUD，加入 accountId 過濾 |
| `lib/providers/game_provider.dart` | 新增帳號狀態、playerProfiles 管理 |
| `lib/screens/home_screen.dart` | 新增「玩家管理」入口、顯示帳號資訊 |
| `lib/screens/game_setup_screen.dart` | 玩家選擇器整合 |
| `pubspec.yaml` | 新增 fl_chart、crypto 依賴 |

### 不變動
- `lib/models/player.dart` — 不修改，利用已有的 `userId` 欄位
- `lib/models/game.dart` — 新增 `accountId` 欄位（小改）
- `lib/services/calculation_service.dart` — 不修改
- `lib/screens/game_play_screen.dart` — 不修改
- 所有現有 widgets — 不修改

---

## 六、風險與注意事項

1. **本地帳號安全性** — 密碼以 SHA-256 + salt 儲存，但 SharedPreferences 在裝置上非加密儲存。這對本地 App 可接受，未來上雲端後需改用 Firebase Auth。
2. **連結功能限制** — 目前為本地儲存，連結僅在同一裝置的多帳號間生效。跨裝置共享需等 v3.0.0 Firebase 同步。
3. **SharedPreferences 容量** — 加入 Account + PlayerProfile 後資料量增加不多，不影響效能。
4. **fl_chart 套件大小** — 約增加 ~300KB，對 Web 版影響可控。
5. **統計計算效能** — 牌局數量多時（100+ 場），遍歷計算可能需要 loading 狀態。可考慮快取。
