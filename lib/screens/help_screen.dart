import 'package:flutter/material.dart';

/// 使用手冊頁面
class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('使用手冊')),
      body: ListView(
        children: const [
          _HelpSection(
            icon: Icons.play_circle_outline,
            title: '開始新牌局',
            content: '1. 在首頁點擊「開始新局」按鈕。\n'
                '2. 設定四位玩家的名稱與 emoji，也可以從「選擇已登錄玩家」快速帶入。\n'
                '3. 選擇底台組合（例如 50×20），或自訂底注與每台金額。\n'
                '4. 進階設定可開啟「自摸加台」、「莊家加台」、「連莊加台」。\n'
                '5. 點擊「開始牌局」進入即時計分畫面。',
          ),
          _HelpSection(
            icon: Icons.emoji_events,
            title: '記錄胡牌',
            content: '在即時計分畫面中，點擊贏家的玩家卡片：\n\n'
                '1. 選擇「胡牌」分頁。\n'
                '2. 選擇放槍的玩家（輸家）。\n'
                '3. 輸入台數，可用快速按鈕或手動輸入。\n'
                '4. 確認預覽金額後，點擊「確定」記錄。',
          ),
          _HelpSection(
            icon: Icons.back_hand,
            title: '自摸',
            content: '在即時計分畫面中，點擊自摸贏家的玩家卡片：\n\n'
                '1. 選擇「自摸」分頁。\n'
                '2. 輸入台數。\n'
                '3. 其他三位玩家皆需付款。\n'
                '4. 確認預覽金額後，點擊「確定」記錄。',
          ),
          _HelpSection(
            icon: Icons.warning_amber,
            title: '詐胡',
            content: '當玩家誤報胡牌時：\n\n'
                '1. 點擊詐胡玩家的卡片。\n'
                '2. 選擇「詐胡」分頁。\n'
                '3. 系統會根據設定計算罰款金額。\n'
                '4. 可在「設定」中調整詐胡台數與賠付規則（賠三家或僅賠莊家）。',
          ),
          _HelpSection(
            icon: Icons.handshake,
            title: '流局',
            content: '當該局無人胡牌時：\n\n'
                '點擊畫面中央的「流局」按鈕即可。流局後莊家連莊，進入下一局。',
          ),
          _HelpSection(
            icon: Icons.groups,
            title: '一炮多響',
            content: '當一位玩家放槍，多位玩家同時胡牌：\n\n'
                '1. 點擊畫面中央的「一炮多響」按鈕。\n'
                '2. 選擇放槍的玩家（輸家）。\n'
                '3. 勾選所有贏家。\n'
                '4. 分別輸入每位贏家的台數。\n'
                '5. 確認預覽後記錄。',
          ),
          _HelpSection(
            icon: Icons.swap_horiz,
            title: '換位置',
            content: '需要交換玩家座位時：\n\n'
                '1. 點擊右上角選單 → 「換位置」。\n'
                '2. 依序點選要交換的兩位玩家。\n'
                '3. 確認後位置互換。',
          ),
          _HelpSection(
            icon: Icons.casino,
            title: '骰子',
            content: '點擊畫面中央的骰子圖示，會擲出三顆骰子，可用來決定開門方向或座位。',
          ),
          _HelpSection(
            icon: Icons.bar_chart,
            title: '牌局統計與歷史',
            content: '在即時計分畫面點選右上角選單 → 「查看詳情」，或在首頁點擊歷史牌局卡片：\n\n'
                '• 最終排名：依分數排序，顯示各玩家最終成績。\n'
                '• 數據統計：胡牌次數、自摸次數、放槍次數。\n'
                '• 局數詳情：每一局的記錄，按風圈分組，依時間倒序顯示。',
          ),
          _HelpSection(
            icon: Icons.file_download,
            title: '匯出報表',
            content: '在牌局詳情頁點擊右上角分享按鈕：\n\n'
                '• JSON：完整牌局資料，適合備份。\n'
                '• CSV：試算表格式，可用 Excel 開啟。\n'
                '• PDF：排版報表，包含排名與局數明細。\n\n'
                '也可在「設定 → 資料管理 → 匯出所有牌局」一次匯出全部資料。',
          ),
          _HelpSection(
            icon: Icons.people,
            title: '玩家管理',
            content: '在首頁點選右上角選單 → 「玩家管理」：\n\n'
                '• 新增玩家：設定名稱與 emoji，方便開局時快速選用。\n'
                '• 編輯玩家：修改名稱或 emoji。\n'
                '• 查看統計：點擊玩家可查看戰績總覽、對手分析與近期牌局。\n'
                '• 刪除玩家：長按或使用選單刪除。',
          ),
          _HelpSection(
            icon: Icons.manage_accounts,
            title: '帳號管理',
            content: '• 註冊：輸入 email 與密碼建立帳號，資料會自動同步至雲端。\n'
                '• 登入：在其他裝置用相同帳號登入，即可取得所有資料。\n'
                '• 登出：首頁右上角選單 → 「登出」。\n'
                '• 資料同步：所有牌局與玩家資料會自動同步，支援離線使用。',
          ),
          _HelpSection(
            icon: Icons.home,
            title: '首頁管理',
            content: '• 搜尋牌局：點擊搜尋圖示，輸入關鍵字篩選牌局。\n'
                '• 重新命名：點擊牌局卡片右上角「⋮」→「重新命名」。\n'
                '• 刪除牌局：點擊牌局卡片右上角「⋮」→「刪除」。\n'
                '• 繼續未完成的牌局：首頁上方會顯示進行中的牌局，點擊即可繼續。',
          ),
          SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _HelpSection extends StatelessWidget {
  final IconData icon;
  final String title;
  final String content;

  const _HelpSection({
    required this.icon,
    required this.title,
    required this.content,
  });

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      leading: Icon(icon),
      title: Text(title),
      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            content,
            style: const TextStyle(fontSize: 15, height: 1.6),
          ),
        ),
      ],
    );
  }
}
