# Paika 麻將系統重構計畫 v1.4.0

## 目標

修復兩個核心 Bug，並重構資料結構以支援未來擴展：

### Bug 1：座位旋轉問題
**現象**：玩家在螢幕上的座位會隨著莊家變化而旋轉  
**預期**：座位應該固定（例如：玩家 A 永遠在右側/東位）

### Bug 2：風圈進度卡死
**現象**：遊戲在「北風北」後無法進入下一圈的「東風東」  
**預期**：四圈輪完後應自動進入下一圈（東→南→西→北→東循環）

---

## 核心概念釐清

### 1. 座位（Seat）vs 風位（Wind Position）

**座位 = 固定的物理位置**
- 遊戲開始時，每位玩家被分配到一個固定座位（0=東位, 1=南位, 2=西位, 3=北位）
- **座位在整場遊戲中不變**（除非手動換位）
- 螢幕顯示位置由座位決定，不隨莊家變化

**風位 = 當前局的角色**
- 每局有四個風位：東（莊）、南、西、北
- 風位隨莊家輪轉而變化
- 例如：座位0的玩家可能在第一局是「東家」，第二局是「北家」

### 2. 圈風（Round Wind）vs 局風（Game Wind）

**圈風 = 當前是第幾圈**（東風/南風/西風/北風）
- 決定一輪的大週期（4局為一圈）

**局風 = 當前莊家是誰**（東局/南局/西局/北局）
- 顯示格式：「東風南局」= 東風圈的第二局，莊家是南家

### 3. 將（Jiang）概念

**將 = 4圈為一將**
- 一將 = 東風圈(4局) + 南風圈(4局) + 西風圈(4局) + 北風圈(4局) = 16局
- `jiangStartDealerIndex` = 這一將的起始莊家座位
- 作用：判斷何時進入下一將

---

## 資料結構重構方案

### 方案 A：BigRound 分層架構（推薦）

**新增 BigRound 模型**：
```dart
class BigRound {
  final String id;
  final int jiangNumber;          // 第幾將（1, 2, 3...）
  final List<String> seatOrder;   // 座位順序 [playerId0, playerId1, ...]
  final int startDealerPos;       // 起始莊家座位（0-3）
  final DateTime startTime;
  final DateTime? endTime;
}
```

**簡化 Round 模型**：
```dart
class Round {
  final String id;
  final String bigRoundId;        // 關聯到 BigRound
  final DateTime timestamp;
  final RoundType type;
  
  // 勝負資訊（純事實）
  final String? winnerId;
  final String? loserId;
  final List<String> winnerIds;   // 一炮多響
  
  // 計分資訊
  final int tai;
  final int flowers;
  final Map<String, int> scoreChanges;
  
  // 該局的狀態快照
  final Wind wind;                // 該局的風圈
  final int dealerPos;            // 該局的莊家座位（0-3）
  final int consecutiveWins;      // 該局的連莊數
  
  final String? notes;
}
```

**優點**：
- 清晰分離「將」和「局」的概念
- 座位順序集中管理，不會混亂
- 歷史記錄更清楚（可查「第 N 將」的所有局）
- 未來可支援中途換位（新建 BigRound）

**缺點**：
- 需要遷移現有資料
- Game 結構需要調整

---

### 方案 B：保留現有結構，僅修正邏輯（最小改動）

**保持 Game 和 Round 現有結構**，只修正：

1. **game_play_screen.dart**：
   ```dart
   // 固定座位（不旋轉）
   final windPos = index;  // 直接用 index 當風位
   ```

2. **game.dart 的 addRound()**：
   ```dart
   // 判斷是否完成一圈（回到起始莊家）
   if (newDealerIndex == jiangStartDealerIndex) {
     newWind = Wind.values[(currentWind.index + 1) % 4];
     newJiangStartDealerIndex = newDealerIndex;  // 更新為當前莊家
   }
   ```

**優點**：
- 改動最小，風險低
- 不需要資料遷移
- 可快速驗證修復效果

**缺點**：
- 「將」的概念還是不夠清晰
- 座位和風位還是容易混淆
- 未來擴展受限

---

## 建議執行方案

### 階段一：先修 Bug（方案 B）

**目標**：讓系統能正常運作  
**改動檔案**：
1. `lib/screens/game_play_screen.dart`（座位固定）
2. `lib/models/game.dart`（風圈進度判斷）

**驗證點**：
- [ ] 座位不再隨莊家旋轉
- [ ] 北風北 → 東風東 正常推進
- [ ] 連莊數正確顯示
- [ ] 歷史記錄完整

---

### 階段二：重構資料結構（方案 A）

**目標**：建立清晰的分層架構  
**步驟**：

#### 1. 新增 BigRound 模型
- 檔案：`lib/models/big_round.dart`
- 包含：座位順序、起始莊家、時間範圍

#### 2. 修改 Game 模型
```dart
class Game {
  final List<BigRound> bigRounds;  // 替代 jiangStartDealerIndex
  final String currentBigRoundId;  // 當前將
  // ... 其他保持不變
}
```

#### 3. 修改 Round 模型
```dart
class Round {
  final String bigRoundId;         // 新增：關聯到 BigRound
  final int dealerPos;             // 替代 dealerPlayerId（改用座位 index）
  // 移除 sequence（改用 wind + dealerPos 計算）
  // 移除 jiangStartDealerIndex（由 BigRound 管理）
}
```

#### 4. 資料遷移邏輯
- 掃描現有 Game 資料
- 根據 `jiangStartDealerIndex` 變化點切分 BigRound
- 轉換 Round 的 `dealerPlayerId` → `dealerPos`

#### 5. 更新所有引用處
- `GameProvider`
- `GameDetailScreen`
- `CalculationService`
- 所有建立 Round 的地方

**驗證點**：
- [ ] 舊資料能正確載入
- [ ] 新遊戲使用新結構
- [ ] 所有功能正常運作
- [ ] 歷史記錄正確顯示

---

## 風險評估

| 方案 | 風險 | 預計時間 | 向後相容 |
|------|------|----------|----------|
| 階段一（Bug修復） | 低 | 30分鐘 | ✅ 完全相容 |
| 階段二（資料重構） | 中 | 2-3小時 | ⚠️ 需要遷移邏輯 |

---

## 建議執行順序

**NOW（立即）**：
1. ✅ 先執行階段一（方案 B）
2. 部署到線上，讓老闆測試驗證

**NEXT（確認修復有效後）**：
3. 執行階段二（方案 A）
4. 增加單元測試覆蓋
5. 撰寫資料遷移工具

---

## 問題：為什麼 v1.3.2 修復無效？

需要檢查：
1. 部署的程式碼是否包含修改？（檢查 git log）
2. 瀏覽器是否有快取？（清除快取重新載入）
3. 邏輯是否正確？（需要實際測試驗證）

**下一步**：確認修改是否真的生效，如果沒有，需要 debug 找出原因。

---

**請老闆確認：**
- ✅ 先執行階段一（最小改動修 Bug）？
- 還是直接跳到階段二（完整重構）？
- 或者需要先 debug 為什麼 v1.3.2 沒生效？
