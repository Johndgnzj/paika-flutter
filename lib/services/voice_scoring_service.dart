import '../models/game.dart';
import '../models/player.dart';

/// 語音記分解析結果
class VoiceScoringResult {
  final Player? winner;       // 贏家
  final Player? loser;        // 輸家（胡牌時）
  final bool isSelfDraw;      // 是否自摸
  final int? tai;             // 台數
  final String? error;        // 錯誤訊息
  final String recognizedText; // 辨識到的文字

  VoiceScoringResult({
    this.winner,
    this.loser,
    this.isSelfDraw = false,
    this.tai,
    this.error,
    required this.recognizedText,
  });

  bool get isValid => winner != null && tai != null && error == null;
}

/// 語音記分服務
class VoiceScoringService {
  /// 解析語音指令
  /// 
  /// 支援格式：
  /// - 胡牌：「{贏家}胡{輸家}{N}台」例如「小明胡阿華5台」「東家胡南家3台」
  /// - 自摸：「{贏家}自摸{N}台」例如「莊家自摸4台」「西家自摸8台」
  static VoiceScoringResult parse(String text, Game game) {
    // 移除空白
    final cleanText = text.replaceAll(RegExp(r'\s+'), '');

    // 檢測是否為自摸
    final isSelfDraw = cleanText.contains('自摸');

    if (isSelfDraw) {
      return _parseSelfDraw(cleanText, game);
    } else if (cleanText.contains('胡')) {
      return _parseWin(cleanText, game);
    } else {
      return VoiceScoringResult(
        recognizedText: text,
        error: '無法辨識指令格式。請說「某某胡某某幾台」或「某某自摸幾台」',
      );
    }
  }

  /// 解析自摸指令
  static VoiceScoringResult _parseSelfDraw(String text, Game game) {
    // 嘗試提取台數
    final tai = _extractTai(text);
    
    // 嘗試找到贏家（自摸者）
    // 格式：{贏家}自摸{N}台
    final selfDrawIndex = text.indexOf('自摸');
    if (selfDrawIndex == -1) {
      return VoiceScoringResult(
        recognizedText: text,
        error: '無法找到「自摸」關鍵字',
      );
    }

    final winnerText = text.substring(0, selfDrawIndex);
    final winner = _findPlayer(winnerText, game);

    if (winner == null) {
      return VoiceScoringResult(
        recognizedText: text,
        tai: tai,
        isSelfDraw: true,
        error: '無法辨識玩家「$winnerText」',
      );
    }

    return VoiceScoringResult(
      recognizedText: text,
      winner: winner,
      isSelfDraw: true,
      tai: tai,
    );
  }

  /// 解析胡牌指令
  static VoiceScoringResult _parseWin(String text, Game game) {
    // 嘗試提取台數
    final tai = _extractTai(text);

    // 嘗試找到贏家和輸家
    // 格式：{贏家}胡{輸家}{N}台
    final huIndex = text.indexOf('胡');
    if (huIndex == -1) {
      return VoiceScoringResult(
        recognizedText: text,
        error: '無法找到「胡」關鍵字',
      );
    }

    final winnerText = text.substring(0, huIndex);
    final afterHu = text.substring(huIndex + 1);

    // 從「胡」之後的文字中提取輸家（移除台數部分）
    var loserText = afterHu;
    final taiMatch = RegExp(r'\d+').firstMatch(afterHu);
    if (taiMatch != null) {
      loserText = afterHu.substring(0, taiMatch.start);
    }
    loserText = loserText.replaceAll('台', '').trim();

    final winner = _findPlayer(winnerText, game);
    final loser = _findPlayer(loserText, game);

    if (winner == null) {
      return VoiceScoringResult(
        recognizedText: text,
        tai: tai,
        loser: loser,
        error: '無法辨識贏家「$winnerText」',
      );
    }

    if (loser == null) {
      return VoiceScoringResult(
        recognizedText: text,
        winner: winner,
        tai: tai,
        error: '無法辨識輸家「$loserText」',
      );
    }

    return VoiceScoringResult(
      recognizedText: text,
      winner: winner,
      loser: loser,
      tai: tai,
    );
  }

  /// 提取台數
  static int? _extractTai(String text) {
    // 先嘗試阿拉伯數字
    final match = RegExp(r'\d+').firstMatch(text);
    if (match != null) {
      return int.tryParse(match.group(0)!);
    }

    // 嘗試中文數字
    return _chineseToNumber(text);
  }

  /// 中文數字轉阿拉伯數字
  static int? _chineseToNumber(String text) {
    final map = {
      '一': 1, '二': 2, '三': 3, '四': 4, '五': 5,
      '六': 6, '七': 7, '八': 8, '九': 9, '十': 10,
      '壹': 1, '貳': 2, '參': 3, '肆': 4, '伍': 5,
      '陸': 6, '柒': 7, '捌': 8, '玖': 9, '拾': 10,
    };

    // 簡單匹配（例如「三台」「五台」）
    for (final entry in map.entries) {
      if (text.contains(entry.key)) {
        return entry.value;
      }
    }

    // 處理「十幾」的情況（例如「十二台」）
    if (text.contains('十')) {
      final after = text.substring(text.indexOf('十') + 1);
      for (final entry in map.entries) {
        if (after.contains(entry.key) && entry.value < 10) {
          return 10 + entry.value;
        }
      }
      return 10; // 只有「十」
    }

    return null;
  }

  /// 根據名稱或風位找玩家（智慧對應）
  static Player? _findPlayer(String identifier, Game game) {
    identifier = identifier.trim();
    if (identifier.isEmpty) return null;

    // 1. 檢查是否為風位（完整對應）
    final windMap = {
      '東': 0, '東家': 0,
      '南': 1, '南家': 1,
      '西': 2, '西家': 2,
      '北': 3, '北家': 3,
    };

    if (windMap.containsKey(identifier)) {
      final seatIndex = windMap[identifier]!;
      if (seatIndex < game.players.length) {
        return game.players[seatIndex];
      }
    }

    // 2. 檢查是否為莊家
    if (identifier == '莊' || identifier == '莊家') {
      return game.dealer;
    }

    // 3. 精確匹配玩家名稱
    for (final player in game.players) {
      if (player.name == identifier) {
        return player;
      }
    }

    // 4. 部分匹配（玩家名稱包含輸入文字）
    for (final player in game.players) {
      if (player.name.contains(identifier)) {
        return player;
      }
    }

    // 5. 反向匹配（輸入文字包含玩家名稱）
    for (final player in game.players) {
      if (identifier.contains(player.name)) {
        return player;
      }
    }

    // 6. 模糊匹配（編輯距離 ≤ 2）
    Player? bestMatch;
    int bestDistance = 999;

    for (final player in game.players) {
      final distance = _levenshteinDistance(identifier, player.name);
      
      // 允許的誤差：名字越長容錯率越高
      final maxAllowedDistance = (player.name.length / 3).ceil().clamp(1, 3);
      
      if (distance <= maxAllowedDistance && distance < bestDistance) {
        bestDistance = distance;
        bestMatch = player;
      }
    }

    if (bestMatch != null) {
      return bestMatch;
    }

    // 7. 音似匹配（檢查常見語音辨識錯誤）
    final phoneSimilarMap = {
      '明': ['名', '銘', '鳴'],
      '華': ['花', '話', '畫'],
      '傑': ['杰', '結', '潔'],
      '宇': ['雨', '羽', '語'],
      '林': ['琳', '霖'],
      '家': ['加', '佳'],
    };

    for (final player in game.players) {
      if (_isPhoneticallySimilar(identifier, player.name, phoneSimilarMap)) {
        return player;
      }
    }

    return null;
  }

  /// 計算 Levenshtein Distance（編輯距離）
  static int _levenshteinDistance(String s1, String s2) {
    if (s1 == s2) return 0;
    if (s1.isEmpty) return s2.length;
    if (s2.isEmpty) return s1.length;

    final len1 = s1.length;
    final len2 = s2.length;
    
    // 使用動態規劃計算
    List<List<int>> dp = List.generate(
      len1 + 1,
      (i) => List.filled(len2 + 1, 0),
    );

    for (int i = 0; i <= len1; i++) {
      dp[i][0] = i;
    }
    for (int j = 0; j <= len2; j++) {
      dp[0][j] = j;
    }

    for (int i = 1; i <= len1; i++) {
      for (int j = 1; j <= len2; j++) {
        if (s1[i - 1] == s2[j - 1]) {
          dp[i][j] = dp[i - 1][j - 1];
        } else {
          dp[i][j] = 1 + [
            dp[i - 1][j],     // 刪除
            dp[i][j - 1],     // 插入
            dp[i - 1][j - 1], // 替換
          ].reduce((a, b) => a < b ? a : b);
        }
      }
    }

    return dp[len1][len2];
  }

  /// 檢查是否音似（語音辨識容易混淆的字）
  static bool _isPhoneticallySimilar(
    String input,
    String target,
    Map<String, List<String>> similarMap,
  ) {
    if (input.length != target.length) return false;

    for (int i = 0; i < input.length; i++) {
      final inputChar = input[i];
      final targetChar = target[i];

      if (inputChar == targetChar) continue;

      // 檢查是否在音似對應表中
      bool found = false;
      for (final entry in similarMap.entries) {
        final key = entry.key;
        final similars = entry.value;

        if ((inputChar == key && similars.contains(targetChar)) ||
            (targetChar == key && similars.contains(inputChar)) ||
            (similars.contains(inputChar) && similars.contains(targetChar))) {
          found = true;
          break;
        }
      }

      if (!found) return false;
    }

    return true;
  }
}
