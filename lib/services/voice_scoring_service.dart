import '../models/game.dart';
import '../models/player.dart';

/// 語音記分解析結果
class VoiceScoringResult {
  final Player? winner;
  final Player? loser;
  final bool isSelfDraw;
  final int? tai;
  final String? error;
  final String recognizedText;

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

/// 關鍵字匹配結果
class _KwMatch {
  final int index;
  final int length;
  const _KwMatch({required this.index, required this.length});
}

/// 語音記分服務
class VoiceScoringService {
  // ──────────────────────────────────────────
  // 關鍵字同音/近音字表
  // ──────────────────────────────────────────

  /// 「胡」的同音/近音字
  static const _huSynonyms = ['胡', '湖', '虎', '護', '壺', '糊', '互', '戶', '滬', '祜'];

  /// 「自摸」的同音/近音組合
  static const _selfDrawSynonyms = [
    '自摸', '自模', '自末', '自默', '字摸', '自磨', '自莫', '子摸',
  ];

  /// 「台」的同音/近音字（用於清理尾綴）
  static const _taiChars = '台抬太泰態臺';

  // ──────────────────────────────────────────
  // 音似字群組
  // 同一個群組內的字可以互相替代
  // ──────────────────────────────────────────
  static const List<List<String>> _phoneticGroups = [
    // ── 人名常見字 ──
    ['明', '名', '銘', '鳴', '冥', '命', '茗'],
    ['華', '花', '話', '畫', '化', '樺', '划'],
    ['傑', '杰', '結', '潔', '接', '節', '捷'],
    ['宇', '雨', '羽', '語', '玉', '育', '郁'],
    ['林', '琳', '霖', '臨', '鄰', '麟'],
    ['家', '加', '佳', '嘉', '甲', '夾', '假'],
    ['志', '治', '至', '置', '智', '致', '織'],
    ['軍', '君', '俊', '均', '菌', '鈞'],
    ['偉', '維', '威', '微', '為', '韋', '偉'],
    ['建', '健', '鍵', '見', '劍', '箭'],
    ['豪', '浩', '好', '號', '毫', '皓'],
    ['翔', '祥', '詳', '香', '想', '鄉', '享'],
    ['文', '聞', '紋', '問', '吻', '溫'],
    ['強', '搶', '槍', '腔', '牆', '搶'],
    ['凱', '楷', '開', '愷', '凱'],
    ['峰', '鋒', '封', '豐', '風', '楓', '瘋'],
    ['哲', '者', '折', '浙', '這', '蔗'],
    ['澤', '則', '責', '擇', '窄', '昃'],
    ['昊', '好', '浩', '豪', '號', '皓'],
    ['瑋', '偉', '威', '維', '味', '緯'],
    ['丞', '承', '城', '成', '誠', '程'],
    ['彥', '晏', '燕', '炎', '言', '研'],
    ['睿', '瑞', '銳', '惠', '慧'],
    ['奕', '益', '義', '易', '意', '異'],
    ['安', '暗', '岸', '案', '鞍'],
    ['英', '鷹', '迎', '硬', '嬰', '鸚'],
    ['恩', '嗯', '摁'],
    ['玲', '零', '靈', '鈴', '令', '領'],
    ['婷', '停', '庭', '廷', '亭', '聽'],
    ['萱', '宣', '選', '旋'],
    ['欣', '心', '新', '薪', '辛', '芯'],
    ['怡', '宜', '一', '儀', '疑'],
    ['雅', '啞', '壓', '亞', '訝'],
    ['晴', '清', '請', '青', '輕', '情'],
    ['穎', '應', '映', '迎', '影'],
    ['柔', '肉', '揉', '柔'],
    ['俐', '力', '立', '麗', '歷', '利'],
    ['瑜', '語', '玉', '遇', '預', '魚'],
    ['涵', '含', '寒', '韓', '漢'],
    ['嘉', '家', '加', '佳', '甲'],
    ['政', '正', '鄭', '整', '爭'],
    ['凌', '靈', '令', '另', '鄰'],
    ['冠', '關', '觀', '管', '慣'],
    ['昌', '長', '場', '嘗', '唱', '倡'],
    ['敏', '民', '閩', '眠'],
    ['旭', '序', '敘', '續', '緒'],
    ['培', '佩', '配', '陪'],
    ['浩', '好', '號', '豪', '毫'],
    ['宸', '晨', '陳', '塵', '沉'],
    ['廷', '停', '庭', '婷', '亭'],
    ['梓', '子', '紫', '字', '自'],
    ['勝', '升', '聖', '盛', '聲'],
    ['耀', '搖', '藥', '鑰', '曜'],
    ['宏', '紅', '洪', '鴻', '弘'],
    ['駿', '俊', '均', '君', '軍'],
    ['銘', '明', '名', '鳴', '命'],
    ['哲', '者', '折', '浙', '摺'],
    ['皓', '浩', '好', '豪', '號'],
    ['韻', '暈', '運', '雲', '允'],
    ['澄', '橙', '城', '程', '誠'],
    ['熙', '希', '西', '喜', '習'],

    // ── 風位 ──
    ['東', '冬', '懂', '動', '棟', '董'],
    ['南', '難', '男', '納', '那'],
    ['西', '喜', '希', '習', '息', '惜', '熙'],
    ['北', '被', '貝', '背', '備', '悲'],

    // ── 莊閒 ──
    ['莊', '狀', '裝', '撞', '壯', '妝'],
    ['閒', '間', '賢', '嫌', '弦', '鹹'],

    // ── 台數尾綴 ──
    ['台', '抬', '太', '泰', '態', '臺', '胎'],
  ];

  // ──────────────────────────────────────────
  // 主要解析入口
  // ──────────────────────────────────────────

  static VoiceScoringResult parse(String text, Game game) {
    final cleanText = text.replaceAll(RegExp(r'\s+'), '');

    // 優先檢測「自摸」（因為包含「摸」字，不會被胡誤判）
    final selfDrawMatch = _findKeywordMatch(cleanText, _selfDrawSynonyms);
    if (selfDrawMatch != null) {
      return _parseSelfDraw(cleanText, game, selfDrawMatch);
    }

    // 檢測「胡」（及同音字）
    final huMatch = _findKeywordMatch(cleanText, _huSynonyms);
    if (huMatch != null) {
      return _parseWin(cleanText, game, huMatch);
    }

    return VoiceScoringResult(
      recognizedText: text,
      error: '無法辨識指令格式。請說「某某胡某某幾台」或「某某自摸幾台」',
    );
  }

  // ──────────────────────────────────────────
  // 解析自摸
  // ──────────────────────────────────────────

  static VoiceScoringResult _parseSelfDraw(
      String text, Game game, _KwMatch kwMatch) {
    final tai = _extractTai(text);
    final winnerText = text.substring(0, kwMatch.index).trim();
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

  // ──────────────────────────────────────────
  // 解析胡牌（放槍）
  // ──────────────────────────────────────────

  static VoiceScoringResult _parseWin(
      String text, Game game, _KwMatch kwMatch) {
    final tai = _extractTai(text);

    final winnerText = text.substring(0, kwMatch.index).trim();
    final afterHu = text.substring(kwMatch.index + kwMatch.length);

    // 從「胡」之後提取輸家（移除台數）
    var loserText = afterHu;
    final taiMatch = RegExp(r'\d+').firstMatch(afterHu);
    if (taiMatch != null) {
      loserText = afterHu.substring(0, taiMatch.start);
    }
    // 移除「台」及其同音字尾綴
    loserText =
        loserText.replaceAll(RegExp('[$_taiChars]'), '').trim();

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

  // ──────────────────────────────────────────
  // 提取台數
  // ──────────────────────────────────────────

  static int? _extractTai(String text) {
    // 阿拉伯數字
    final match = RegExp(r'\d+').firstMatch(text);
    if (match != null) {
      return int.tryParse(match.group(0)!);
    }
    // 中文數字
    return _chineseToNumber(text);
  }

  static int? _chineseToNumber(String text) {
    final map = {
      '一': 1, '二': 2, '三': 3, '四': 4, '五': 5,
      '六': 6, '七': 7, '八': 8, '九': 9, '十': 10,
      '壹': 1, '貳': 2, '參': 3, '肆': 4, '伍': 5,
      '陸': 6, '柒': 7, '捌': 8, '玖': 9, '拾': 10,
    };

    for (final entry in map.entries) {
      if (text.contains(entry.key)) {
        return entry.value;
      }
    }

    if (text.contains('十')) {
      final after = text.substring(text.indexOf('十') + 1);
      for (final entry in map.entries) {
        if (after.contains(entry.key) && entry.value < 10) {
          return 10 + entry.value;
        }
      }
      return 10;
    }

    return null;
  }

  // ──────────────────────────────────────────
  // 玩家辨識（多層次容錯）
  // ──────────────────────────────────────────

  static Player? _findPlayer(String identifier, Game game) {
    identifier = identifier.trim();
    if (identifier.isEmpty) return null;

    // 1. 風位（含同音字）
    final windSynonyms = {
      0: ['東', '冬', '懂', '動', '棟', '東家', '冬家'],
      1: ['南', '難', '男', '那', '南家'],
      2: ['西', '喜', '希', '習', '熙', '西家', '喜家'],
      3: ['北', '被', '貝', '背', '北家'],
    };
    for (final entry in windSynonyms.entries) {
      if (entry.value.contains(identifier)) {
        final idx = entry.key;
        if (idx < game.players.length) return game.players[idx];
      }
    }

    // 2. 莊/閒家（含同音字）
    const dealerSynonyms = ['莊', '莊家', '狀', '裝', '撞', '壯', '妝'];
    if (dealerSynonyms.contains(identifier)) return game.dealer;

    // 3. 精確匹配
    for (final p in game.players) {
      if (p.name == identifier) return p;
    }

    // 4. 部分匹配（名稱包含輸入 or 輸入包含名稱）
    for (final p in game.players) {
      if (p.name.contains(identifier) || identifier.contains(p.name)) {
        return p;
      }
    }

    // 5. 音似匹配（整體同音字替換）
    for (final p in game.players) {
      if (_isPhoneticallySimilar(identifier, p.name)) return p;
    }

    // 6. Levenshtein 模糊匹配
    Player? bestMatch;
    int bestDistance = 999;
    for (final p in game.players) {
      final distance = _levenshteinDistance(identifier, p.name);
      final maxAllowed = (p.name.length / 3).ceil().clamp(1, 3);
      if (distance <= maxAllowed && distance < bestDistance) {
        bestDistance = distance;
        bestMatch = p;
      }
    }
    if (bestMatch != null) return bestMatch;

    // 7. 音似 + 模糊混合（每個字允許音似替換後再比 Levenshtein）
    for (final p in game.players) {
      if (_phoneticLevenshtein(identifier, p.name) <= 1) return p;
    }

    return null;
  }

  // ──────────────────────────────────────────
  // 音似比對工具
  // ──────────────────────────────────────────

  /// 查找兩個字符所屬的群組 index（-1 表示不在任何群組）
  static int _groupOf(String char) {
    for (int i = 0; i < _phoneticGroups.length; i++) {
      if (_phoneticGroups[i].contains(char)) return i;
    }
    return -1;
  }

  /// 兩個字是否音似（同一群組 or 相同）
  static bool _charsSimilar(String a, String b) {
    if (a == b) return true;
    final ga = _groupOf(a);
    final gb = _groupOf(b);
    return ga != -1 && ga == gb;
  }

  /// 整個字串逐字音似比對（長度需相同）
  static bool _isPhoneticallySimilar(String input, String target) {
    if (input.length != target.length) return false;
    for (int i = 0; i < input.length; i++) {
      if (!_charsSimilar(input[i], target[i])) return false;
    }
    return true;
  }

  /// 音似版 Levenshtein（把音似替換的 cost 計為 0）
  static int _phoneticLevenshtein(String s1, String s2) {
    if (s1 == s2) return 0;
    if (s1.isEmpty) return s2.length;
    if (s2.isEmpty) return s1.length;

    final len1 = s1.length;
    final len2 = s2.length;
    final dp = List.generate(len1 + 1, (i) => List.filled(len2 + 1, 0));

    for (int i = 0; i <= len1; i++) dp[i][0] = i;
    for (int j = 0; j <= len2; j++) dp[0][j] = j;

    for (int i = 1; i <= len1; i++) {
      for (int j = 1; j <= len2; j++) {
        // 音似視為相同（cost = 0）
        final substituteCost = _charsSimilar(s1[i - 1], s2[j - 1]) ? 0 : 1;
        dp[i][j] = [
          dp[i - 1][j] + 1,             // 刪除
          dp[i][j - 1] + 1,             // 插入
          dp[i - 1][j - 1] + substituteCost, // 替換/音似
        ].reduce((a, b) => a < b ? a : b);
      }
    }

    return dp[len1][len2];
  }

  /// 標準 Levenshtein Distance
  static int _levenshteinDistance(String s1, String s2) {
    if (s1 == s2) return 0;
    if (s1.isEmpty) return s2.length;
    if (s2.isEmpty) return s1.length;

    final len1 = s1.length;
    final len2 = s2.length;
    final dp = List.generate(len1 + 1, (i) => List.filled(len2 + 1, 0));

    for (int i = 0; i <= len1; i++) dp[i][0] = i;
    for (int j = 0; j <= len2; j++) dp[0][j] = j;

    for (int i = 1; i <= len1; i++) {
      for (int j = 1; j <= len2; j++) {
        if (s1[i - 1] == s2[j - 1]) {
          dp[i][j] = dp[i - 1][j - 1];
        } else {
          dp[i][j] = 1 +
              [dp[i - 1][j], dp[i][j - 1], dp[i - 1][j - 1]]
                  .reduce((a, b) => a < b ? a : b);
        }
      }
    }

    return dp[len1][len2];
  }

  // ──────────────────────────────────────────
  // 關鍵字搜尋工具
  // ──────────────────────────────────────────

  /// 在文字中搜尋第一個匹配的關鍵字（任一同音字）
  static _KwMatch? _findKeywordMatch(String text, List<String> synonyms) {
    int minIndex = -1;
    String? matched;

    for (final syn in synonyms) {
      final idx = text.indexOf(syn);
      if (idx >= 0 && (minIndex == -1 || idx < minIndex)) {
        minIndex = idx;
        matched = syn;
      }
    }

    if (minIndex == -1 || matched == null) return null;
    return _KwMatch(index: minIndex, length: matched.length);
  }
}
