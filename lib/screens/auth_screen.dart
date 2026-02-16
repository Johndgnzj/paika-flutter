import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/game_provider.dart';
import '../services/auth_service.dart';
import '../widgets/animation_helpers.dart';
import 'home_screen.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool _isRegister = false;
  bool _obscurePassword = true;

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final authService = context.read<AuthService>();
    final gameProvider = context.read<GameProvider>();
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      if (_isRegister) {
        // 先設定 pending name，確保 register 觸發 onAuthChanged 時能建立玩家檔案
        gameProvider.createSelfProfileAfterRegister(_nameController.text);
        await authService.register(
          _emailController.text,
          _passwordController.text,
          _nameController.text,
        );
      } else {
        await authService.login(
          _emailController.text,
          _passwordController.text,
        );
      }
      navigator.pop(); // 關閉 loading
      navigator.pushReplacement(
        FadeSlidePageRoute(page: const HomeScreen()),
      );
    } catch (e) {
      navigator.pop(); // 關閉 loading
      messenger.showSnackBar(
        SnackBar(content: Text(e is ArgumentError ? e.message.toString() : '$e')),
      );
    }
  }

  void _showPasswordResetDialog() {
    final emailCtrl = TextEditingController(text: _emailController.text);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('重設密碼'),
        content: TextField(
          controller: emailCtrl,
          decoration: const InputDecoration(
            labelText: 'Email',
            border: OutlineInputBorder(),
          ),
          keyboardType: TextInputType.emailAddress,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () async {
              final navigator = Navigator.of(context);
              final messenger = ScaffoldMessenger.of(this.context);
              try {
                await this.context.read<AuthService>().sendPasswordReset(emailCtrl.text);
                navigator.pop();
                messenger.showSnackBar(
                  const SnackBar(content: Text('重設密碼信已寄出，請檢查信箱')),
                );
              } catch (e) {
                messenger.showSnackBar(
                  SnackBar(content: Text(e is ArgumentError ? e.message.toString() : '$e')),
                );
              }
            },
            child: const Text('寄送'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('🀄', style: TextStyle(fontSize: 64)),
                  const SizedBox(height: 8),
                  const Text(
                    '牌咖 Paika',
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 48),

                  // Email
                  TextFormField(
                    controller: _emailController,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      prefixIcon: Icon(Icons.email),
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return '請輸入 Email';
                      if (!v.contains('@') || !v.contains('.')) return 'Email 格式不正確';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // 密碼
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    decoration: InputDecoration(
                      labelText: '密碼',
                      prefixIcon: const Icon(Icons.lock),
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                        onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                      ),
                    ),
                    textInputAction: _isRegister ? TextInputAction.next : TextInputAction.done,
                    onFieldSubmitted: _isRegister ? null : (_) => _submit(),
                    validator: (v) {
                      if (v == null || v.isEmpty) return '請輸入密碼';
                      if (v.length < 6) return '密碼至少需要 6 碼';
                      return null;
                    },
                  ),
                  const SizedBox(height: 8),

                  // 忘記密碼（僅登入時顯示）
                  if (!_isRegister)
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: _showPasswordResetDialog,
                        child: const Text('忘記密碼？'),
                      ),
                    ),

                  // 顯示名稱（僅註冊時顯示）
                  if (_isRegister) ...[
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: '顯示名稱',
                        prefixIcon: Icon(Icons.person),
                        border: OutlineInputBorder(),
                      ),
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _submit(),
                      validator: (v) => v == null || v.trim().isEmpty ? '請輸入顯示名稱' : null,
                    ),
                    const SizedBox(height: 16),
                  ],

                  const SizedBox(height: 8),

                  // 登入/註冊按鈕
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _submit,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: Text(
                        _isRegister ? '註冊' : '登入',
                        style: const TextStyle(fontSize: 18),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 切換模式
                  TextButton(
                    onPressed: () => setState(() {
                          _isRegister = !_isRegister;
                          _nameController.clear();
                        }),
                    child: Text(
                      _isRegister ? '已有帳號？登入' : '沒有帳號？註冊',
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
