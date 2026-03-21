import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/enums.dart';
import '../../core/providers/auth_provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _usernameCtrl = TextEditingController();
  final _pwCtrl       = TextEditingController();
  bool _obscure  = true;
  bool _loading  = false;
  String? _error;

  // ── Quick-login presets cho tất cả roles ──────────────────────────────────
  final _quickLogins = [
    (role: UserRole.ceoAdmin,         username: 'ceo1',     label: 'CEO',      icon: '👑', color: AppColors.ceoColor),
    (role: UserRole.itAdmin,          username: 'it1',      label: 'IT Admin', icon: '💻', color: AppColors.itColor),
    (role: UserRole.storeManager,     username: 'manager1', label: 'Manager',  icon: '🏪', color: const Color(0xFF1A237E)),
    (role: UserRole.inventoryChecker, username: 'checker1', label: 'Checker',  icon: '📦', color: const Color(0xFF2D7A50)),
    (role: UserRole.staff,            username: 'staff1',   label: 'Staff',    icon: '🛍️', color: AppColors.staffColor),
  ];

  void _quickLogin(String username) {
    _usernameCtrl.text = username;
    _pwCtrl.text       = '123456';
    _doLogin();
  }

  Future<void> _doLogin() async {
    // ── Validate trống ─────────────────────────────────────────────────────
    final username = _usernameCtrl.text.trim();
    final password = _pwCtrl.text.trim();
    if (username.isEmpty || password.isEmpty) {
      setState(() => _error = 'Vui lòng nhập tên đăng nhập và mật khẩu');
      return;
    }

    setState(() { _loading = true; _error = null; });
    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;

    final auth = context.read<AuthProvider>();
    final ok   = await auth.login(username, password);
    if (!ok) {
      setState(() { _loading = false; _error = auth.errorMessage; });
    }
    // Nếu ok = true, go_router tự redirect theo role (authProvider.isLoggedIn = true)
  }

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _pwCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      body: Row(
        children: [
          // ── Left branding panel (wide screen) ──────────────────────────
          if (size.width > 700)
            Expanded(
              child: Container(
                decoration: const BoxDecoration(gradient: AppColors.primaryGradient),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: const Text('🏪', style: TextStyle(fontSize: 72)),
                    ),
                    const SizedBox(height: 32),
                    const Text(
                      'MINH CHÂU',
                      style: TextStyle(
                        fontSize: 40, fontWeight: FontWeight.w900,
                        color: Colors.white, letterSpacing: 6,
                      ),
                    ),
                    const Text(
                      'Hệ Thống Tạp Hóa',
                      style: TextStyle(fontSize: 18, color: Colors.white70),
                    ),
                    const SizedBox(height: 48),
                    _buildInfoChip('🏪', '3 Chi nhánh'),
                    const SizedBox(height: 10),
                    _buildInfoChip('👥', '9 Nhân sự'),
                    const SizedBox(height: 10),
                    _buildInfoChip('📦', 'Quản lý hàng hóa'),
                  ],
                ),
              ),
            ),

          // ── Right login form ────────────────────────────────────────────
          Container(
            width: size.width > 700 ? 440 : size.width,
            color: Colors.white,
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 16),
                  const Text(
                    'Đăng nhập',
                    style: TextStyle(
                      fontSize: 28, fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Chào mừng trở lại hệ thống Tạp Hóa Minh Châu',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
                  ),
                  const SizedBox(height: 28),

                  // ── Quick login buttons ─────────────────────────────────
                  const Text(
                    'Đăng nhập nhanh:',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _quickLogins.map((q) => _QuickLoginBtn(
                      icon: q.icon,
                      label: q.label,
                      color: q.color,
                      onTap: () => _quickLogin(q.username),
                    )).toList(),
                  ),

                  const SizedBox(height: 24),
                  Row(children: const [
                    Expanded(child: Divider()),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 10),
                      child: Text('hoặc', style: TextStyle(color: AppColors.textHint)),
                    ),
                    Expanded(child: Divider()),
                  ]),
                  const SizedBox(height: 24),

                  // ── Username field ──────────────────────────────────────
                  TextFormField(
                    controller: _usernameCtrl,
                    keyboardType: TextInputType.text,
                    decoration: const InputDecoration(
                      labelText: 'Tên đăng nhập',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                    onFieldSubmitted: (_) => _doLogin(),
                  ),
                  const SizedBox(height: 16),

                  // ── Password field ──────────────────────────────────────
                  TextFormField(
                    controller: _pwCtrl,
                    obscureText: _obscure,
                    decoration: InputDecoration(
                      labelText: 'Mật khẩu',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
                        onPressed: () => setState(() => _obscure = !_obscure),
                      ),
                    ),
                    onFieldSubmitted: (_) => _doLogin(),
                  ),

                  // ── Error message ───────────────────────────────────────
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.errorLight,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, color: AppColors.error, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _error!,
                              style: const TextStyle(color: AppColors.error, fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),

                  // ── Login button ────────────────────────────────────────
                  ElevatedButton(
                    onPressed: _loading ? null : _doLogin,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: _loading
                        ? const SizedBox(
                            height: 20, width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('Đăng nhập', style: TextStyle(fontSize: 15)),
                  ),

                  const SizedBox(height: 32),
                  const Divider(),
                  const SizedBox(height: 12),

                  // ── Demo accounts ───────────────────────────────────────
                  const Text(
                    'Tài khoản demo (password: 123456):',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  ...[
                    ('👑', 'CEO Admin:', 'ceo1'),
                    ('💻', 'IT Admin:', 'it1'),
                    ('🏪', 'Store Manager:', 'manager1'),
                    ('📦', 'Inventory Checker:', 'checker1'),
                    ('🛍️', 'Staff:', 'staff1'),
                  ].map((e) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: GestureDetector(
                      onTap: () => _quickLogin(e.$3),
                      child: Row(
                        children: [
                          Text(e.$1, style: const TextStyle(fontSize: 14)),
                          const SizedBox(width: 6),
                          Text(
                            '${e.$2} ',
                            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                          ),
                          Text(
                            e.$3,
                            style: const TextStyle(
                              fontSize: 12, color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(String icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(icon, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 14)),
        ],
      ),
    );
  }
}

// ── Quick Login Button Widget ──────────────────────────────────────────────
class _QuickLoginBtn extends StatelessWidget {
  final String icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickLoginBtn({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 74,
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Text(icon, style: const TextStyle(fontSize: 20)),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color),
            ),
          ],
        ),
      ),
    );
  }
}
