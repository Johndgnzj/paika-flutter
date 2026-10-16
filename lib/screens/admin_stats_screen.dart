import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/admin_stats.dart';
import '../models/game.dart';
import '../services/admin_service.dart';
import '../services/calculation_service.dart';
import '../services/stats_service.dart';
import '../widgets/player_avatar.dart';

/// 管理員入口；持續監聽權限狀態，不能靠直接路由繞過。
class AdminStatsScreen extends StatefulWidget {
  const AdminStatsScreen({super.key});

  static const routeName = '/admin/stats';

  @override
  State<AdminStatsScreen> createState() => _AdminStatsScreenState();
}

class _AdminStatsScreenState extends State<AdminStatsScreen> {
  final _searchController = TextEditingController();
  AdminService? _service;
  List<AdminUserRecord> _users = const [];
  bool _loadingUsers = false;
  bool _fullyLoaded = false;
  String? _error;
  int _loadGeneration = 0;

  List<AdminUserRecord> get _filteredUsers {
    final query = _searchController.text;
    return _users.where((user) => user.matches(query)).toList();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _refreshAuthorization(),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final service = context.read<AdminService>();
    if (identical(service, _service)) return;
    _service?.removeListener(_handleAdminStateChanged);
    _service = service..addListener(_handleAdminStateChanged);
  }

  @override
  void dispose() {
    _loadGeneration++;
    _service?.removeListener(_handleAdminStateChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _handleAdminStateChanged() {
    if (!mounted) return;
    final service = _service!;
    if (!service.isAdmin) {
      _loadGeneration++;
      setState(() {
        _users = const [];
        _loadingUsers = false;
        _fullyLoaded = false;
        _error = null;
        _searchController.clear();
      });
      return;
    }
    setState(() {});
    if (!service.isChecking && !_loadingUsers && !_fullyLoaded) {
      unawaited(_loadAllUsers());
    }
  }

  Future<void> _refreshAuthorization() async {
    final service = _service;
    if (service == null) return;
    try {
      final authorized = await service.refreshAdminStatus(forceRefresh: true);
      if (mounted && authorized && !_loadingUsers && !_fullyLoaded) {
        await _loadAllUsers();
      }
    } on Object catch (error) {
      if (!mounted) return;
      setState(() => _error = _friendlyError(error));
    }
  }

  Future<void> _reloadUsers() async {
    final service = _service;
    if (service == null) return;
    _loadGeneration++;
    setState(() {
      _users = const [];
      _fullyLoaded = false;
      _error = null;
    });
    await _refreshAuthorization();
  }

  Future<void> _loadAllUsers() async {
    final service = _service;
    if (service == null || !service.isAdmin || _loadingUsers) return;
    final generation = ++_loadGeneration;
    setState(() {
      _loadingUsers = true;
      _fullyLoaded = false;
      _error = null;
    });

    DocumentSnapshot<Map<String, dynamic>>? cursor;
    final loaded = <AdminUserRecord>[];
    try {
      while (true) {
        final page = await service.loadUsersPage(after: cursor, limit: 50);
        if (!mounted ||
            generation != _loadGeneration ||
            !identical(service, _service) ||
            !service.isAdmin) {
          return;
        }
        loaded.addAll(page.users);
        loaded.sort((a, b) {
          final byName = a.label.toLowerCase().compareTo(b.label.toLowerCase());
          return byName != 0 ? byName : a.uid.compareTo(b.uid);
        });
        setState(() => _users = List.unmodifiable(loaded));
        if (!page.hasMore || page.cursor == null) break;
        cursor = page.cursor;
      }
      if (mounted && generation == _loadGeneration && service.isAdmin) {
        setState(() => _fullyLoaded = true);
      }
    } on Object catch (error) {
      if (!mounted || generation != _loadGeneration) return;
      setState(() => _error = _friendlyError(error));
    } finally {
      if (mounted && generation == _loadGeneration) {
        setState(() => _loadingUsers = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final service = _service;
    return Scaffold(
      appBar: AppBar(title: const Text('管理員戰績查詢')),
      body: service == null || service.isChecking
          ? const Center(child: CircularProgressIndicator())
          : !service.isAdmin
          ? _buildAccessDenied()
          : _buildUserSearch(),
    );
  }

  Widget _buildAccessDenied() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.lock_outline,
              size: 72,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 16),
            const Text(
              '拒絕存取',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text('管理員權限已失效或帳號已登出。'),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => Navigator.maybePop(context),
              icon: const Icon(Icons.arrow_back),
              label: const Text('返回'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserSearch() {
    final users = _filteredUsers;
    final header = <Widget>[
      TextField(
        controller: _searchController,
        decoration: InputDecoration(
          labelText: '搜尋使用者',
          hintText: '輸入顯示名稱或 Email',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _searchController.text.isEmpty
              ? null
              : IconButton(
                  tooltip: '清除',
                  onPressed: () {
                    _searchController.clear();
                    setState(() {});
                  },
                  icon: const Icon(Icons.clear),
                ),
          border: const OutlineInputBorder(),
        ),
        onChanged: (_) => setState(() {}),
      ),
      const SizedBox(height: 16),
      Row(
        children: [
          Text(
            '使用者 (${users.length})',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const Spacer(),
          IconButton(
            onPressed: _loadingUsers ? null : _reloadUsers,
            tooltip: '重新整理',
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      if (_loadingUsers) ...[
        const LinearProgressIndicator(),
        const SizedBox(height: 8),
        Text('正在分批載入全部使用者（已載入 ${_users.length} 位），搜尋結果可能尚未完整。'),
      ] else if (_fullyLoaded)
        Text('已載入全部 ${_users.length} 位使用者。'),
      if (_error != null)
        Card(
          color: Theme.of(context).colorScheme.errorContainer,
          child: ListTile(
            leading: const Icon(Icons.error_outline),
            title: Text(_error!),
            trailing: TextButton(
              onPressed: _reloadUsers,
              child: const Text('重試'),
            ),
          ),
        ),
      if (!_loadingUsers && _error == null && users.isEmpty)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 48),
          child: Column(
            children: [
              Icon(Icons.person_search, size: 64, color: Colors.grey),
              SizedBox(height: 12),
              Text('找不到符合的使用者'),
            ],
          ),
        ),
    ];

    return RefreshIndicator(
      onRefresh: _reloadUsers,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            sliver: SliverList.list(children: header),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            sliver: SliverList.builder(
              itemCount: users.length,
              itemBuilder: (context, index) {
                final user = users[index];
                return Card(
                  child: ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.person)),
                    title: Text(user.label),
                    subtitle: user.email.isEmpty || user.email == user.label
                        ? null
                        : Text(user.email),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => _AdminUserStatsScreen(user: user),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  String _friendlyError(Object error) {
    if (error is StateError) return '管理員權限已失效，請重新登入後再試。';
    return '無法載入使用者資料：$error';
  }
}

class _AdminUserStatsScreen extends StatefulWidget {
  const _AdminUserStatsScreen({required this.user});

  final AdminUserRecord user;

  @override
  State<_AdminUserStatsScreen> createState() => _AdminUserStatsScreenState();
}

class _AdminUserStatsScreenState extends State<_AdminUserStatsScreen> {
  AdminService? _service;
  Future<AdminUserStats>? _statsFuture;
  final _dateFormat = DateFormat('yyyy/MM/dd HH:mm');

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final service = context.read<AdminService>();
    if (identical(service, _service)) return;
    _service?.removeListener(_handleAdminStateChanged);
    _service = service..addListener(_handleAdminStateChanged);
    if (service.isAdmin && !service.isChecking) _reload();
  }

  @override
  void dispose() {
    _service?.removeListener(_handleAdminStateChanged);
    _statsFuture = null;
    super.dispose();
  }

  void _handleAdminStateChanged() {
    if (!mounted) return;
    final service = _service!;
    if (!service.isAdmin) {
      setState(() => _statsFuture = null);
    } else if (!service.isChecking && _statsFuture == null) {
      setState(_reload);
    } else {
      setState(() {});
    }
  }

  void _reload() {
    final service = _service;
    _statsFuture = service == null || !service.isAdmin
        ? null
        : service.loadUserStats(widget.user);
  }

  @override
  Widget build(BuildContext context) {
    final service = _service;
    return Scaffold(
      appBar: AppBar(title: Text(widget.user.label)),
      body: service == null || service.isChecking
          ? const Center(child: CircularProgressIndicator())
          : !service.isAdmin
          ? const Center(child: Text('管理員權限已失效，已清除戰績資料。'))
          : _buildStats(),
    );
  }

  Widget _buildStats() {
    final future = _statsFuture;
    if (future == null) return const Center(child: CircularProgressIndicator());
    return FutureBuilder<AdminUserStats>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.grey),
                  const SizedBox(height: 12),
                  Text('無法讀取此使用者的戰績：${snapshot.error}'),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () => setState(_reload),
                    child: const Text('重試'),
                  ),
                ],
              ),
            ),
          );
        }

        final stats = snapshot.requireData;
        final header = <Widget>[
          if (widget.user.email.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(widget.user.email, textAlign: TextAlign.center),
            ),
          if (stats.invalidGameCount > 0)
            Card(
              color: Theme.of(context).colorScheme.errorContainer,
              child: ListTile(
                leading: const Icon(Icons.warning_amber_rounded),
                title: Text(
                  '有 ${stats.invalidGameCount} 筆牌局資料格式錯誤，以下統計未包含這些資料。',
                ),
              ),
            ),
          _buildOverview(stats),
          const SizedBox(height: 20),
          Text(
            '玩家檔案（${stats.profiles.length}）',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          if (stats.profiles.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: Text('此帳號尚未建立玩家檔案')),
              ),
            )
          else
            Card(
              child: Column(
                children: stats.profiles
                    .map((summary) => _buildProfileTile(summary, stats.games))
                    .toList(),
              ),
            ),
          const SizedBox(height: 20),
          Text('全部牌局', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          if (stats.games.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: Text('尚無可顯示的牌局紀錄')),
              ),
            ),
        ];
        return CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              sliver: SliverList.list(children: header),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              sliver: SliverList.builder(
                itemCount: stats.games.length,
                itemBuilder: (context, index) =>
                    _buildGameCard(stats.games[index]),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildProfileTile(AdminProfileSummary summary, List<Game> games) {
    final profile = summary.profile;
    final tag = profile.isSelf
        ? '本人'
        : summary.isRegistered
        ? '已連結帳號'
        : '未註冊';
    return ListTile(
      leading: PlayerAvatar(profile: profile, size: 40),
      title: Text(profile.name),
      subtitle: Text('$tag ・ ${summary.gameCount} 場'),
      trailing: const Icon(Icons.chevron_right),
      onTap: summary.gameCount == 0
          ? null
          : () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => _AdminProfileStatsScreen(
                  ownerLabel: widget.user.label,
                  summary: summary,
                  games: games,
                ),
              ),
            ),
    );
  }

  Widget _buildOverview(AdminUserStats stats) {
    final recent = stats.recentGame;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                _Metric(label: '有效牌局', value: '${stats.totalGames}'),
                _Metric(label: '完成場數', value: '${stats.completedGames}'),
                _Metric(label: '總局數', value: '${stats.totalRounds}'),
              ],
            ),
            const Divider(height: 28),
            Row(
              children: [
                const Icon(Icons.schedule, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    recent == null
                        ? '最近牌局：無'
                        : '最近牌局：${recent.name?.trim().isNotEmpty == true ? recent.name : '未命名牌局'}\n${_dateFormat.format(recent.createdAt)}',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGameCard(Game game) {
    final scores = game.currentScores;
    final players = game.players.toList()
      ..sort((a, b) => (scores[b.id] ?? 0).compareTo(scores[a.id] ?? 0));
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        leading: Icon(
          game.status == GameStatus.finished
              ? Icons.check_circle_outline
              : Icons.play_circle_outline,
        ),
        title: Text(
          game.name?.trim().isNotEmpty == true ? game.name! : '未命名牌局',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          '${_dateFormat.format(game.createdAt)} ・ ${game.rounds.length} 局 ・ '
          '${game.status == GameStatus.finished ? '已完成' : '進行中'}',
        ),
        children: [
          const Divider(height: 1),
          ...players.indexed.map((entry) {
            final (index, player) = entry;
            final score = scores[player.id] ?? 0;
            return ListTile(
              dense: true,
              leading: CircleAvatar(radius: 16, child: Text('${index + 1}')),
              title: Text('${player.emoji} ${player.name}'),
              trailing: Text(
                CalculationService.formatScore(score),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: score > 0
                      ? Colors.green
                      : score < 0
                      ? Colors.red
                      : null,
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

/// 單一玩家檔案（含未註冊好友）在該帳號牌局中的全期統計。
class _AdminProfileStatsScreen extends StatelessWidget {
  _AdminProfileStatsScreen({
    required this.ownerLabel,
    required this.summary,
    required List<Game> games,
  }) : stats = StatsService.getPlayerStats(
         summary.profileIds.toList(),
         games,
         // custom 且不給起訖 = 不限時間範圍
         timeRange: TimeRange.custom,
       );

  final String ownerLabel;
  final AdminProfileSummary summary;
  final PlayerStats stats;

  static final _dateFormat = DateFormat('yyyy/MM/dd HH:mm');

  @override
  Widget build(BuildContext context) {
    final service = context.watch<AdminService>();
    final profile = summary.profile;
    return Scaffold(
      appBar: AppBar(title: Text(profile.name)),
      body: service.isChecking
          ? const Center(child: CircularProgressIndicator())
          : !service.isAdmin
          ? const Center(child: Text('管理員權限已失效，已清除戰績資料。'))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Center(child: PlayerAvatar(profile: profile, size: 64)),
                const SizedBox(height: 8),
                Text(
                  '建立於 $ownerLabel 的玩家檔案',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 16),
                _buildSummaryCard(context),
                const SizedBox(height: 20),
                if (stats.opponents.isNotEmpty) ...[
                  Text('常見對手', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Card(
                    child: Column(
                      children: stats.opponents
                          .take(5)
                          .map(
                            (opponent) => ListTile(
                              dense: true,
                              leading: Text(
                                opponent.emoji,
                                style: const TextStyle(fontSize: 24),
                              ),
                              title: Text(opponent.name),
                              subtitle: Text(
                                '同場 ${opponent.gamesTogether} 場 ・ '
                                '胡他 ${opponent.winsBy} 次 ・ 放槍給他 ${opponent.lossesBy} 次',
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
                Text('參與牌局', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                ...stats.recentGames.map(
                  (game) => Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: CircleAvatar(child: Text('${game.rank}')),
                      title: Text(
                        game.gameName?.trim().isNotEmpty == true
                            ? game.gameName!
                            : '未命名牌局',
                      ),
                      subtitle: Text(
                        '${_dateFormat.format(game.date)} ・ ${game.rounds} 局',
                      ),
                      trailing: _scoreText(game.score),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildSummaryCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                _Metric(label: '場數', value: '${stats.totalGames}'),
                _Metric(label: '局數', value: '${stats.totalRounds}'),
                _Metric(
                  label: '累計得分',
                  value: CalculationService.formatScore(stats.totalScore),
                ),
              ],
            ),
            const Divider(height: 28),
            Row(
              children: [
                _Metric(
                  label: '勝率',
                  value: '${(stats.winRate * 100).toStringAsFixed(1)}%',
                ),
                _Metric(label: '胡牌', value: '${stats.wins}'),
                _Metric(label: '自摸', value: '${stats.selfDraws}'),
                _Metric(label: '放槍', value: '${stats.losses}'),
              ],
            ),
            const Divider(height: 28),
            Row(
              children: [
                _Metric(
                  label: '平均每場',
                  value: CalculationService.formatScore(
                    stats.avgScorePerGame.round(),
                  ),
                ),
                _Metric(
                  label: '單場最佳',
                  value: CalculationService.formatScore(stats.bestGameScore),
                ),
                _Metric(
                  label: '單場最差',
                  value: CalculationService.formatScore(stats.worstGameScore),
                ),
              ],
            ),
            const Divider(height: 28),
            Row(
              children: [
                _Metric(label: '平均台數', value: stats.avgTai.toStringAsFixed(1)),
                _Metric(label: '最高台數', value: '${stats.maxTai}'),
                _Metric(label: '詐胡', value: '${stats.falseWins}'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _scoreText(int score) {
    return Text(
      CalculationService.formatScore(score),
      style: TextStyle(
        fontWeight: FontWeight.bold,
        color: score > 0
            ? Colors.green
            : score < 0
            ? Colors.red
            : null,
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(value, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 4),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}
