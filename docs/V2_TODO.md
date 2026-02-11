# Paika v2.0.0 - 開發任務清單

> **目的：** 供 AI Developer 按順序逐步實作，每個任務獨立可驗證。
> **參考：** [V2_PLAN.md](./V2_PLAN.md)

---

## 使用指引

- 每個任務以 `[ ]` 標記，完成後改為 `[x]`
- 任務按依賴順序排列，請從上往下依序執行
- 每個任務包含：目標、涉及檔案、具體步驟、驗收標準
- 遇到不確定的設計決策，以 V2_PLAN.md 為準

---

## Phase 1 — 帳號系統（Feature 0）

### Task 1.1：Account Model
- [x] **建立帳號資料模型**

**新增檔案：** `lib/models/account.dart`

**步驟：**
1. 建立 `Account` class，欄位如下：
   - `id` (String) — UUID，永久不變
   - `name` (String) — 帳號顯示名稱
   - `email` (String?) — 可選
   - `passwordHash` (String) — SHA-256 雜湊
   - `salt` (String) — 隨機鹽值
   - `createdAt` (DateTime)
   - `lastLoginAt` (DateTime)
2. 實作 `toJson()` / `fromJson()` 序列化
3. 實作 `copyWith()` 方法

**驗收：**
- Account 物件可正確建立、序列化、反序列化
- 所有欄位都有涵蓋

---

### Task 1.2：AuthService
- [x] **建立帳號驗證服務**

**新增檔案：** `lib/services/auth_service.dart`
**新增依賴：** 在 `pubspec.yaml` 加入 `crypto` 套件（用於 SHA-256）

**步驟：**
1. 建立 `AuthService` class（使用 ChangeNotifier 或獨立 service 皆可）
2. 實作以下方法：
   - `register(name, password, {email})` — 產生 UUID + salt，密碼做 SHA-256(password + salt) 存入 passwordHash，儲存到 SharedPreferences key `'accounts'`
   - `login(name, password)` — 根據名稱查找帳號，比對 hash，成功後寫入 `'current_account_id'`
   - `logout()` — 清除 `'current_account_id'`
   - `currentAccount` getter — 回傳當前登入帳號（從 `'current_account_id'` 讀取）
   - `updateAccount(name?, email?, newPassword?)` — 修改帳號資料
   - `isLoggedIn` getter — 是否有登入中的帳號
3. 帳號資料存於 SharedPreferences key `'accounts'`（JSON List）
4. 當前登入帳號 ID 存於 `'current_account_id'`

**驗收：**
- 可註冊新帳號、登入、登出
- 密碼存的是 hash + salt，非明文
- 同名帳號註冊應拋出錯誤
- 登入錯誤密碼應拋出錯誤

---

### Task 1.3：登入/註冊頁面
- [x] **建立 AuthScreen**

**新增檔案：** `lib/screens/auth_screen.dart`

**步驟：**
1. 建立 `AuthScreen` StatefulWidget
2. 頁面可切換「登入」/「註冊」模式
3. 表單欄位：
   - 帳號名稱（必填）
   - 密碼（必填，obscureText）
   - Email（選填，僅註冊模式顯示）
4. 驗證邏輯：名稱不得為空、密碼至少 4 碼
5. 呼叫 `AuthService.register()` 或 `AuthService.login()`
6. 成功後導航到 `HomeScreen`
7. 錯誤時顯示 SnackBar 提示

**UI 風格：**
- 沿用現有 App 的 theme 和設計語言（參考 `lib/utils/theme.dart`）
- 簡潔的表單卡片設計

**驗收：**
- 可正常註冊新帳號並自動登入
- 可正常登入已有帳號
- 錯誤輸入有適當提示
- 成功後跳轉到 HomeScreen

---

### Task 1.4：App 啟動流程調整
- [x] **修改 main.dart 加入帳號檢查**

**修改檔案：** `lib/main.dart`

**步驟：**
1. App 啟動時檢查 `'current_account_id'` 是否存在
2. 存在 → 直接進入 `HomeScreen`（現有行為）
3. 不存在 → 導向 `AuthScreen`
4. 將 `AuthService` 整合到 Provider 體系中（或直接作為 service 注入 GameProvider）
5. 確保 go_router 路由表包含 `/auth` 路由

**驗收：**
- 首次啟動 App 會看到 AuthScreen
- 登入後再開 App 自動進入 HomeScreen
- 登出後回到 AuthScreen

---

### Task 1.5：StorageService 加入帳號隔離
- [x] **所有資料操作加上 accountId 過濾**

**修改檔案：** `lib/services/storage_service.dart`, `lib/models/game.dart`, `lib/providers/game_provider.dart`

**步驟：**
1. `Game` model 新增 `accountId` 欄位（String）
   - `toJson()` / `fromJson()` 支援此欄位
   - 舊資料（沒有 accountId 的牌局）需要向後相容處理
2. `StorageService` 修改：
   - `saveGame(game)` — game 自動帶上當前 accountId
   - `loadGames()` → 新增 `loadGames({String? accountId})` — 只載入指定帳號的牌局
   - `savePlayers()` / `loadPlayers()` — 加入 accountId prefix 到 storage key（例如 `'players_$accountId'`）
   - `saveSettings()` / `loadSettings()` — 加入 accountId prefix
   - `saveCurrentGame()` / `loadCurrentGame()` — 加入 accountId prefix
3. `GameProvider` 修改：
   - 持有 `currentAccountId`
   - 所有 Storage 操作傳入 `currentAccountId`
   - `init()` 時讀取 `currentAccountId`

**向後相容：**
- 沒有 accountId 的舊牌局，在第一次登入時自動綁定到該帳號
- 遷移邏輯：首次登入時檢查是否有 orphan games，批次更新 accountId

**驗收：**
- 不同帳號登入只看到自己的牌局
- 不同帳號有各自的設定和 savedPlayers
- 舊資料在首次登入後自動遷移到新帳號下
- 切換帳號後資料正確隔離

---

## Phase 2 — 玩家登錄（Feature 1）

### Task 2.1：PlayerProfile Model
- [x] **建立玩家檔案資料模型**

**新增檔案：** `lib/models/player_profile.dart`

**步驟：**
1. 建立 `PlayerProfile` class，欄位如下：
   - `id` (String) — 持久 UUID
   - `accountId` (String) — 所屬帳號
   - `name` (String) — 玩家名稱
   - `emoji` (String) — 頭像 emoji
   - `linkedAccountId` (String?) — 連結到的另一個帳號
   - `createdAt` (DateTime)
   - `lastPlayedAt` (DateTime)
2. 實作 `toJson()` / `fromJson()` 序列化
3. 實作 `copyWith()` 方法

**驗收：**
- PlayerProfile 物件可正確建立、序列化、反序列化

---

### Task 2.2：PlayerProfile CRUD — StorageService
- [x] **在 StorageService 新增 PlayerProfile 的增刪改查**

**修改檔案：** `lib/services/storage_service.dart`

**步驟：**
1. 新增方法：
   - `savePlayerProfile(PlayerProfile profile)` — 建立或更新
   - `loadPlayerProfiles(String accountId)` — 載入該帳號的所有玩家
   - `deletePlayerProfile(String id, String accountId)` — 刪除
2. Storage key 格式：`'player_profiles_$accountId'`（JSON List）

**驗收：**
- 可建立、讀取、更新、刪除 PlayerProfile
- 按 accountId 隔離

---

### Task 2.3：GameProvider 擴展 PlayerProfile 管理
- [x] **在 GameProvider 中管理 PlayerProfile 狀態**

**修改檔案：** `lib/providers/game_provider.dart`

**步驟：**
1. 新增狀態：
   - `List<PlayerProfile> _playerProfiles`
   - `playerProfiles` getter（依 lastPlayedAt 降序排列）
2. 新增方法：
   - `loadPlayerProfiles()` — 從 StorageService 載入
   - `addPlayerProfile(String name, String emoji)` — 建立新 profile，自動帶 currentAccountId
   - `updatePlayerProfile(String id, {String? name, String? emoji})` — 編輯
   - `deletePlayerProfile(String id)` — 刪除
3. 在 `init()` 中呼叫 `loadPlayerProfiles()`

**驗收：**
- Provider 可正確管理 PlayerProfile 的 CRUD
- UI 能透過 Provider 讀取 PlayerProfile 列表

---

### Task 2.4：玩家管理頁面
- [x] **建立 PlayerListScreen**

**新增檔案：** `lib/screens/player_list_screen.dart`

**步驟：**
1. 建立 `PlayerListScreen` StatelessWidget（使用 Consumer<GameProvider>）
2. 頁面功能：
   - 列出當前帳號下的所有 PlayerProfile（依 lastPlayedAt 排序）
   - 每個玩家顯示：emoji、名稱、最後遊玩時間
   - 已連結的玩家顯示連結標記（linkedAccountId 非空時）
3. 操作：
   - 右上角「+」按鈕 → 新增玩家（彈出對話框輸入名稱和 emoji）
   - 長按或左滑 → 編輯 / 刪除
   - 點擊 → 進入玩家統計頁面（Phase 4 實作，先留空或跳轉到 placeholder）
4. 空狀態提示：「尚未登錄任何玩家」

**修改檔案：** `lib/screens/home_screen.dart`
- 在首頁新增「玩家管理」入口按鈕，導航到 PlayerListScreen

**驗收：**
- 可從 HomeScreen 進入玩家管理頁面
- 可新增、編輯、刪除玩家
- 列表依最後遊玩時間排序
- 空狀態有適當提示

---

### Task 2.5：GameSetupScreen 整合玩家選擇
- [x] **在開局流程中可選擇已登錄的玩家**

**修改檔案：** `lib/screens/game_setup_screen.dart`

**步驟：**
1. 每個玩家輸入欄位旁新增「選擇已有玩家」按鈕（圖示按鈕即可）
2. 點擊後彈出 BottomSheet 或 Dialog，列出所有 PlayerProfile
3. 選擇後自動填入名稱、emoji
4. 記錄 `Player.userId = profile.id`（利用 Player model 已有的 userId 欄位）
5. 仍允許手動輸入（不關聯 PlayerProfile）
6. 開局後更新被選中的 PlayerProfile 的 `lastPlayedAt`

**驗收：**
- 開局時可快速選擇已登錄的玩家
- 選擇後名稱和 emoji 自動填入
- Player.userId 正確關聯到 PlayerProfile.id
- 不選擇也能正常手動輸入開局

---

## Phase 3 — 玩家連結（Feature 1.5）

### Task 3.1：LinkCode Model + LinkService
- [x] **建立連結碼機制**

**新增檔案：** `lib/models/link_code.dart`, `lib/services/link_service.dart`

**步驟：**
1. 建立 `LinkCode` class：
   - `code` (String) — 6 位數連結碼
   - `playerProfileId` (String) — 要連結的玩家
   - `fromAccountId` (String) — 發起方帳號
   - `createdAt` (DateTime)
   - `expiresAt` (DateTime) — createdAt + 10 分鐘
2. 建立 `LinkService` class：
   - `generateLinkCode(playerProfileId, fromAccountId)` — 產生 6 位數隨機碼，存入 SharedPreferences，10 分鐘後過期
   - `redeemLinkCode(code, myAccountId)` — 驗證碼有效性、未過期，將對應 PlayerProfile 的 `linkedAccountId` 設為 myAccountId
   - `unlinkPlayer(playerProfileId)` — 清除 linkedAccountId
3. 連結碼存於 SharedPreferences key `'link_codes'`（JSON List）

**驗收：**
- 可產生 6 位數連結碼
- 可在有效期內兌換連結碼
- 過期碼無法兌換
- 兌換後 PlayerProfile.linkedAccountId 正確更新

---

### Task 3.2：連結 UI
- [x] **在玩家管理頁面加入連結操作**

**修改檔案：** `lib/screens/player_list_screen.dart`

**步驟：**
1. 每個 PlayerProfile 項目新增操作選單：
   - 「產生連結碼」— 呼叫 LinkService.generateLinkCode()，彈窗顯示 6 位數碼 + 10 分鐘倒數計時
   - 已連結的玩家顯示「解除連結」選項
2. 頁面上方或設定中新增「輸入連結碼」入口：
   - 彈窗輸入 6 位數碼
   - 呼叫 LinkService.redeemLinkCode()
   - 成功 / 失敗提示

**驗收：**
- 可產生連結碼並顯示倒數
- 另一帳號可輸入碼完成連結
- 已連結玩家有視覺標記
- 可解除連結

---

### Task 3.3：牌局查詢擴展
- [x] **loadGames 納入連結帳號的牌局**

**修改檔案：** `lib/services/storage_service.dart`, `lib/providers/game_provider.dart`

**步驟：**
1. `StorageService.loadGames()` 擴展邏輯：
   ```
   結果 = 自己帳號的牌局
         + 掃描所有帳號的牌局中，包含 player.userId 對應的 PlayerProfile
           且該 PlayerProfile.linkedAccountId == myAccountId 的牌局
   ```
2. 連結牌局以視覺區分（如灰色標記或「來自 XXX」提示）
3. `GameProvider` 更新 `loadGameHistory()` 使用新邏輯

**注意：** 目前為本地儲存，連結功能僅限同裝置多帳號。

**驗收：**
- 被連結的帳號可看到關聯的牌局
- 連結牌局與自己的牌局有視覺區分
- 解除連結後牌局不再出現

---

## Phase 4 — 統計功能（Feature 2）

### Task 4.1：StatsService
- [x] **建立統計計算服務**

**新增檔案：** `lib/services/stats_service.dart`

**步驟：**
1. 建立 `PlayerStats` class，欄位如下：
   - `totalGames` (int) — 總場次
   - `totalRounds` (int) — 總局數
   - `wins` (int) — 胡牌次數
   - `selfDraws` (int) — 自摸次數
   - `losses` (int) — 放槍次數
   - `falseWins` (int) — 詐胡次數
   - `winRate` (double) — 勝率 = (胡 + 自摸) / 總局數
   - `totalScore` (int) — 累計總得分
   - `avgScorePerGame` (double) — 平均每場得分
   - `bestGameScore` (int) — 單場最高分
   - `worstGameScore` (int) — 單場最低分
   - `avgTai` (double) — 平均台數
   - `maxTai` (int) — 最高台數
   - `opponentRecord` (Map<String, OpponentRecord>) — 對手勝負統計
   - `recentGames` (List<GameSummary>) — 近期牌局摘要
2. 建立 `GameSummary` class（日期、排名、得分、牌局ID）
3. 建立 `OpponentRecord` class（對手名稱、同場次數、勝/負次數）
4. 建立 `StatsService` class：
   - `getPlayerStats(String profileId, List<Game> games)` — 遍歷所有牌局，篩選包含該 profileId 的場次，計算統計數據
5. 統計來源：遍歷 `Game.rounds` 中每一 `Round`，根據 `Round` 的結果欄位計算

**驗收：**
- 給定 profileId 和牌局列表，能正確計算所有統計欄位
- 沒有牌局時回傳零值（不報錯）
- 勝率計算正確（分母為實際參與局數）

---

### Task 4.2：玩家統計頁面
- [x] **建立 PlayerStatsScreen**

**新增檔案：** `lib/screens/player_stats_screen.dart`

**步驟：**
1. 建立 `PlayerStatsScreen`，接收 `PlayerProfile` 參數
2. 頂部區塊：
   - 玩家 emoji（大尺寸）+ 名稱
   - 總場次 / 勝率 / 累計得分（3 個 highlight 數字）
3. 戰績概覽區：
   - 4 格統計卡片：胡牌、自摸、放槍、詐胡（次數）
   - 平均台數 / 最高台數
4. 最近牌局區：
   - 列出最近 10 場牌局（ListView）
   - 每項顯示：日期、最終排名、得分
   - 點擊跳轉到 `GameDetailScreen`
5. 常見對手區：
   - 列出最常同場的玩家 Top 5
   - 顯示同場次數、對該對手的勝負記錄

**修改檔案：** `lib/screens/player_list_screen.dart`
- 點擊玩家 → 導航到 PlayerStatsScreen

**驗收：**
- 從玩家管理頁面點擊玩家可進入統計頁面
- 統計數據正確顯示
- 最近牌局可點擊跳轉
- 沒有牌局時顯示空狀態提示

---

## Phase 5 — 圖表視覺化（Feature 3）

### Task 5.1：加入 fl_chart 依賴
- [x] **安裝圖表套件**

**修改檔案：** `pubspec.yaml`

**步驟：**
1. 新增依賴：`fl_chart: ^0.69.0`（確認最新穩定版）
2. 執行 `flutter pub get`

**驗收：**
- `flutter pub get` 成功
- 專案可正常編譯

---

### Task 5.2：分數趨勢圖
- [x] **建立 ScoreTrendChart 元件**

**新增檔案：** `lib/widgets/charts/score_trend_chart.dart`

**步驟：**
1. 建立 `ScoreTrendChart` widget
2. 使用 `LineChart`，X 軸為牌局時間，Y 軸為累計得分
3. 顯示最近 20 場的分數趨勢
4. 接收參數：`List<GameSummary>` 或類似的統計數據
5. 零分線標記（Y=0 的參考線）
6. 沿用 App theme 顏色

**驗收：**
- 正確顯示折線趨勢
- 少於 2 場時顯示適當提示
- 響應式大小適配

---

### Task 5.3：勝率圓餅圖
- [x] **建立 WinRatePieChart 元件**

**新增檔案：** `lib/widgets/charts/win_rate_pie_chart.dart`

**步驟：**
1. 建立 `WinRatePieChart` widget
2. 使用 `PieChart`，顯示胡牌 / 自摸 / 放槍 / 詐胡 / 其他 的比例
3. 各項目用不同顏色標記
4. 顯示百分比標籤
5. 接收參數：`PlayerStats`

**驗收：**
- 各項比例加總 100%
- 數值為 0 的項目不顯示
- 顏色清晰可辨

---

### Task 5.4：台數分布圖
- [x] **建立 TaiDistributionChart 元件**

**新增檔案：** `lib/widgets/charts/tai_distribution_chart.dart`

**步驟：**
1. 建立 `TaiDistributionChart` widget
2. 使用 `BarChart`，X 軸為台數（1, 2, 3, ...），Y 軸為出現次數
3. 接收參數：`Map<int, int>`（台數 → 次數）
4. 標記最常出現的台數

**驗收：**
- 正確顯示各台數的分布
- 沒有數據時顯示適當提示

---

### Task 5.5：圖表整合到統計頁面
- [x] **在 PlayerStatsScreen 中展示圖表**

**修改檔案：** `lib/screens/player_stats_screen.dart`

**步驟：**
1. 在統計頁面中新增圖表區塊
2. 排列方式：使用 Tab 或上下捲動展示三張圖表
3. 每張圖表有標題說明
4. StatsService 需提供圖表所需的數據格式（如台數分布 Map）

**驗收：**
- 三張圖表正確顯示在統計頁面中
- 捲動或切換 Tab 流暢
- 沒有足夠數據時顯示替代訊息

---

## 收尾任務

### Task 6.1：HomeScreen 帳號資訊顯示
- [x] **首頁顯示當前帳號 + 登出功能**

**修改檔案：** `lib/screens/home_screen.dart`

**步驟：**
1. 在 AppBar 或頁面頂部顯示當前帳號名稱
2. 設定頁面或 AppBar 提供「登出」按鈕
3. 登出後清除狀態並返回 AuthScreen

**驗收：**
- 可看到目前登入的帳號名稱
- 可正常登出並回到登入頁面

---

### Task 6.2：全流程測試
- [x] **端到端驗證**

**驗證項目：**
1. 首次啟動 → AuthScreen → 註冊 → HomeScreen
2. 登出 → AuthScreen → 登入 → HomeScreen
3. 關閉 App 重開 → 自動登入 → HomeScreen
4. 建立 PlayerProfile → 開新牌局選擇已有玩家 → 打完牌局
5. 查看玩家統計 → 數據正確 → 圖表顯示
6. 帳號 A 產生連結碼 → 帳號 B 輸入碼 → 帳號 B 可看到關聯牌局
7. 解除連結 → 關聯牌局消失
8. 舊版資料（無 accountId）升級後正確遷移
9. 不同帳號資料完全隔離

---

## 檔案影響總覽

### 新增檔案（12 個）
| 檔案 | 對應任務 |
|------|----------|
| `lib/models/account.dart` | Task 1.1 |
| `lib/models/player_profile.dart` | Task 2.1 |
| `lib/models/link_code.dart` | Task 3.1 |
| `lib/services/auth_service.dart` | Task 1.2 |
| `lib/services/link_service.dart` | Task 3.1 |
| `lib/services/stats_service.dart` | Task 4.1 |
| `lib/screens/auth_screen.dart` | Task 1.3 |
| `lib/screens/player_list_screen.dart` | Task 2.4 |
| `lib/screens/player_stats_screen.dart` | Task 4.2 |
| `lib/widgets/charts/score_trend_chart.dart` | Task 5.2 |
| `lib/widgets/charts/win_rate_pie_chart.dart` | Task 5.3 |
| `lib/widgets/charts/tai_distribution_chart.dart` | Task 5.4 |

### 修改檔案（6 個）
| 檔案 | 對應任務 |
|------|----------|
| `pubspec.yaml` | Task 1.2, 5.1 |
| `lib/main.dart` | Task 1.4 |
| `lib/models/game.dart` | Task 1.5 |
| `lib/services/storage_service.dart` | Task 1.5, 2.2, 3.3 |
| `lib/providers/game_provider.dart` | Task 1.5, 2.3, 3.3 |
| `lib/screens/home_screen.dart` | Task 2.4, 6.1 |
| `lib/screens/game_setup_screen.dart` | Task 2.5 |

### 不變動
- `lib/models/player.dart` — 利用已有 `userId` 欄位
- `lib/services/calculation_service.dart`
- `lib/screens/game_play_screen.dart`
- `lib/screens/game_detail_screen.dart`
- 所有現有 widgets（`lib/widgets/` 下既有檔案）
