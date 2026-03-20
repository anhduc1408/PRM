import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/enums.dart';
import '../../core/providers/auth_provider.dart';
import '../../data/database_service.dart';
import '../../models/store_model.dart';
import '../../models/user_model.dart';

class RoleManagementScreen extends StatefulWidget {
  const RoleManagementScreen({super.key});
  @override
  State<RoleManagementScreen> createState() => _RoleManagementScreenState();
}

class _RoleManagementScreenState extends State<RoleManagementScreen> {
  final _searchCtrl = TextEditingController();
  UserRole? _filterRole;
  int? _filterStoreId; // null = tất cả, -1 = không cửa hàng
  late Future<List<UserModel>> _usersFuture;
  late Future<List<StoreModel>> _storesFuture;

  // ── Pagination ────────────────────────────────────────────────────────────
  int _currentPage = 1;
  static const int _pageSize = 10;

  static const _roleColors = {
    UserRole.ceoAdmin:         AppColors.ceoColor,
    UserRole.itAdmin:          AppColors.itColor,
    UserRole.storeManager:     Color(0xFF7B1FA2),
    UserRole.inventoryChecker: Color(0xFF00838F),
    UserRole.staff:            AppColors.staffColor,
  };

  @override
  void initState() {
    super.initState();
    _usersFuture  = DatabaseService.instance.getAllUsers();
    _storesFuture = DatabaseService.instance.getAllStores();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // FIX: _reload không được gọi bên trong setState, phải tách ra
  void _reload() {
    if (!mounted) return;
    final newFuture = DatabaseService.instance.getAllUsers();
    setState(() {
      _usersFuture = newFuture;
      _currentPage = 1;
    });
  }

  List<UserModel> _applyFilter(List<UserModel> users) {
    var res = users;
    if (_filterRole != null) {
      res = res.where((u) => u.role == _filterRole).toList();
    }
    if (_filterStoreId != null) {
      if (_filterStoreId == -1) {
        res = res.where((u) => u.storeId == null).toList();
      } else {
        res = res.where((u) => u.storeId == _filterStoreId).toList();
      }
    }
    if (_searchCtrl.text.isNotEmpty) {
      final q = _searchCtrl.text.toLowerCase();
      res = res.where((u) =>
        u.fullName.toLowerCase().contains(q) ||
        u.username.toLowerCase().contains(q) ||
        (u.email ?? '').toLowerCase().contains(q) ||
        (u.phone ?? '').contains(q),
      ).toList();
    }
    return res;
  }

  // ─── Gửi thông báo khi chỉnh sửa nhân sự ─────────────────────────────────
  Future<void> _sendEditNotification({
    required UserModel user,
    required UserRole oldRole,
    required UserRole newRole,
    required int? oldStoreId,
    required int? newStoreId,
    required List<StoreModel> stores,
  }) async {
    String resolveStoreName(int? id) {
      if (id == null) return 'Không có cửa hàng';
      try {
        return stores.firstWhere((s) => s.id == id).name;
      } catch (_) {
        return 'Cửa hàng #$id';
      }
    }

    final changes = <String>[];
    if (oldRole != newRole) {
      changes.add('Vai trò: ${oldRole.displayName} → ${newRole.displayName}');
    }
    if (oldStoreId != newStoreId) {
      changes.add('Cửa hàng: ${resolveStoreName(oldStoreId)} → ${resolveStoreName(newStoreId)}');
    }
    if (changes.isEmpty) return;

    final now = DateTime.now();

    // 1. Thông báo đến chính user bị chỉnh sửa
    await DatabaseService.instance.insertNotification(
      type: 'role_update',
      title: 'Thông tin tài khoản của bạn đã được cập nhật',
      content: 'IT Admin đã thay đổi: ${changes.join('; ')}',
      targetUserId: user.id,
    );

    // 2. Nếu chuyển cửa hàng → thông báo manager cửa hàng mới
    if (newStoreId != null && newStoreId != oldStoreId) {
      final allUsers = await DatabaseService.instance.getAllUsers();
      final managers = allUsers.where((u) =>
        u.role == UserRole.storeManager && u.storeId == newStoreId && u.status == 'active',
      );
      for (final mgr in managers) {
        await DatabaseService.instance.insertNotification(
          type: 'role_update',
          title: 'Nhân viên mới được thêm vào cửa hàng của bạn',
          content: '${user.fullName} (${newRole.displayName}) đã được thêm vào ${resolveStoreName(newStoreId)}',
          targetUserId: mgr.id,
          storeId: newStoreId,
        );
      }
    }
  }

  // ─── Gửi thông báo khi tạo user mới ──────────────────────────────────────
  Future<void> _sendWelcomeNotification({
    required int userId,
    required UserModel user,
    required String password,
    required List<StoreModel> stores,
  }) async {
    String resolveStoreName(int? id) {
      if (id == null) return '';
      try {
        return stores.firstWhere((s) => s.id == id).name;
      } catch (_) {
        return '';
      }
    }

    final storePart = user.storeId != null ? ' tại ${resolveStoreName(user.storeId)}' : '';
    await DatabaseService.instance.insertNotification(
      type: 'system',
      title: 'Tài khoản của bạn đã được tạo',
      content: 'Chào mừng ${user.fullName}! Vai trò: ${user.role.displayName}$storePart.'
          ' Tên đăng nhập: ${user.username}. Mật khẩu: $password',
      targetUserId: userId,
      storeId: user.storeId,
    );
  }

  // ─── Gửi thông báo khi reset mật khẩu ────────────────────────────────────
  Future<void> _sendResetPasswordNotification(UserModel user) async {
    await DatabaseService.instance.insertNotification(
      type: 'system',
      title: 'Mật khẩu của bạn đã được đặt lại',
      content: 'IT Admin đã reset mật khẩu của bạn về 123456. Vui lòng đổi mật khẩu sau khi đăng nhập.',
      targetUserId: user.id,
    );
  }

  // ─── ADD DIALOG ───────────────────────────────────────────────────────────
  void _showAddDialog(List<StoreModel> stores) {
    final nameCtrl  = TextEditingController();
    final emailCtrl = TextEditingController();
    final passCtrl  = TextEditingController();
    final phoneCtrl = TextEditingController();
    var selectedRole = UserRole.staff;
    int? selectedStoreId = stores.isNotEmpty ? stores.first.id : null;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setDS) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          clipBehavior: Clip.hardEdge,
          child: SizedBox(
            width: 480,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppColors.primary, AppColors.primaryLight],
                      begin: Alignment.topLeft, end: Alignment.bottomRight,
                    ),
                  ),
                  child: Row(children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.person_add_rounded, color: Colors.white, size: 22),
                    ),
                    const SizedBox(width: 14),
                    const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Thêm nhân sự mới', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
                      Text('Điền thông tin để tạo tài khoản', style: TextStyle(color: Colors.white70, fontSize: 12)),
                    ]),
                    const Spacer(),
                    IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close, color: Colors.white70)),
                  ]),
                ),
                // Form
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      _sectionLabel('Thông tin cá nhân'),
                      const SizedBox(height: 12),
                      _buildTextField(nameCtrl,  'Họ và tên *',                  Icons.person_outline),
                      const SizedBox(height: 10),
                      _buildTextField(emailCtrl, 'Email',                         Icons.email_outlined),
                      const SizedBox(height: 10),
                      _buildTextField(phoneCtrl, 'Số điện thoại',                Icons.phone_outlined),
                      const SizedBox(height: 10),
                      _buildTextField(passCtrl,  'Mật khẩu (mặc định: 123456)', Icons.lock_outline, obscure: true),
                      const SizedBox(height: 20),
                      _sectionLabel('Phân quyền'),
                      const SizedBox(height: 12),
                      Wrap(spacing: 8, children: UserRole.values.map((r) {
                        final selected = selectedRole == r;
                        final color = _roleColors[r] ?? AppColors.primary;
                        return ChoiceChip(
                          label: Text(r.displayName, style: TextStyle(color: selected ? Colors.white : color, fontWeight: FontWeight.w600, fontSize: 12)),
                          selected: selected,
                          selectedColor: color,
                          backgroundColor: color.withValues(alpha: 0.08),
                          side: BorderSide(color: selected ? color : color.withValues(alpha: 0.3)),
                          onSelected: (_) => setDS(() => selectedRole = r),
                        );
                      }).toList()),
                      if ((selectedRole == UserRole.staff || selectedRole == UserRole.storeManager || selectedRole == UserRole.inventoryChecker) && stores.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        _sectionLabel('Cửa hàng làm việc'),
                        const SizedBox(height: 10),
                        DropdownButtonFormField<int>(
                          initialValue: selectedStoreId,
                          decoration: _inputDeco('Chọn cửa hàng', Icons.store_outlined),
                          items: stores.map((s) => DropdownMenuItem(value: s.id, child: Text(s.name, style: const TextStyle(fontSize: 13)))).toList(),
                          onChanged: (v) => setDS(() => selectedStoreId = v),
                        ),
                      ],
                    ]),
                  ),
                ),
                // Actions
                Container(
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
                  decoration: const BoxDecoration(border: Border(top: BorderSide(color: Color(0xFFEEEEEE)))),
                  child: Row(children: [
                    Expanded(child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                      child: const Text('Hủy'),
                    )),
                    const SizedBox(width: 12),
                    Expanded(child: ElevatedButton(
                      onPressed: () async {
                        if (nameCtrl.text.isEmpty) return;
                        final storeNeeded = selectedRole == UserRole.staff ||
                            selectedRole == UserRole.storeManager ||
                            selectedRole == UserRole.inventoryChecker;
                        final storeId = storeNeeded ? selectedStoreId : null;
                        final password = passCtrl.text.isEmpty ? '123456' : passCtrl.text;
                        final now = DateTime.now();
                        final newUser = UserModel(
                          id: 0,
                          username: emailCtrl.text.trim().isNotEmpty
                              ? emailCtrl.text.trim().split('@').first
                              : nameCtrl.text.trim().replaceAll(' ', '').toLowerCase(),
                          passwordHash: password,
                          fullName: nameCtrl.text.trim(),
                          email: emailCtrl.text.trim().isNotEmpty ? emailCtrl.text.trim() : null,
                          phone: phoneCtrl.text.isEmpty ? null : phoneCtrl.text.trim(),
                          role: selectedRole, storeId: storeId,
                          createdAt: now, updatedAt: now, startDate: now,
                        );
                        await DatabaseService.instance.insertUser(newUser);

                        // Lấy id user vừa tạo (insertUser trả về void)
                        final allAfter = await DatabaseService.instance.getAllUsers();
                        final created = allAfter.where((u) => u.username == newUser.username).toList();
                        final newUserId = created.isNotEmpty ? created.first.id : 0;

                        // Gửi thông báo chào mừng đến user mới
                        await _sendWelcomeNotification(
                          userId: newUserId, user: newUser,
                          password: password, stores: stores,
                        );

                        if (ctx.mounted) Navigator.pop(ctx);
                        // FIX: gọi _reload() NGOÀI async context, sau khi await xong
                        _reload();
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text('Đã tạo tài khoản ${newUser.fullName} & gửi thông báo'),
                            backgroundColor: AppColors.success,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ));
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text('Tạo tài khoản', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                    )),
                  ]),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }

  // ─── EDIT DIALOG ──────────────────────────────────────────────────────────
  void _showEditDialog(UserModel user, List<StoreModel> stores) {
    final nameCtrl   = TextEditingController(text: user.fullName);
    final emailCtrl  = TextEditingController(text: user.email ?? '');
    final phoneCtrl  = TextEditingController(text: user.phone ?? '');
    var selectedRole    = user.role;
    int? selectedStoreId = user.storeId ?? (stores.isNotEmpty ? stores.first.id : null);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setDS) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          clipBehavior: Clip.hardEdge,
          child: SizedBox(
            width: 480,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        _roleColors[user.role] ?? AppColors.primary,
                        (_roleColors[user.role] ?? AppColors.primary).withValues(alpha: 0.7),
                      ],
                      begin: Alignment.topLeft, end: Alignment.bottomRight,
                    ),
                  ),
                  child: Row(children: [
                    CircleAvatar(
                      radius: 22,
                      backgroundColor: Colors.white.withValues(alpha: 0.25),
                      child: Text(
                        user.fullName.isNotEmpty ? user.fullName[0].toUpperCase() : '?',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('Chỉnh sửa nhân sự', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
                      Text(user.email ?? user.username, style: const TextStyle(color: Colors.white70, fontSize: 12), overflow: TextOverflow.ellipsis),
                    ])),
                    IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close, color: Colors.white70)),
                  ]),
                ),
                // Form
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      _sectionLabel('Thông tin cá nhân'),
                      const SizedBox(height: 12),
                      _buildTextField(nameCtrl,  'Họ và tên *',   Icons.person_outline),
                      const SizedBox(height: 10),
                      _buildTextField(emailCtrl, 'Email',          Icons.email_outlined),
                      const SizedBox(height: 10),
                      _buildTextField(phoneCtrl, 'Số điện thoại', Icons.phone_outlined),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF8E1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFFFE082)),
                        ),
                        child: const Row(children: [
                          Icon(Icons.lock_outline, size: 14, color: Color(0xFFF9A825)),
                          SizedBox(width: 6),
                          Expanded(child: Text('Mật khẩu không thể thay đổi ở đây', style: TextStyle(fontSize: 11, color: Color(0xFFF9A825)))),
                        ]),
                      ),
                      const SizedBox(height: 20),
                      _sectionLabel('Phân quyền'),
                      const SizedBox(height: 12),
                      Wrap(spacing: 8, runSpacing: 8, children: UserRole.values.map((r) {
                        final selected = selectedRole == r;
                        final color = _roleColors[r] ?? AppColors.primary;
                        return ChoiceChip(
                          label: Text(r.displayName, style: TextStyle(color: selected ? Colors.white : color, fontWeight: FontWeight.w600, fontSize: 12)),
                          selected: selected,
                          selectedColor: color,
                          backgroundColor: color.withValues(alpha: 0.08),
                          side: BorderSide(color: selected ? color : color.withValues(alpha: 0.3)),
                          onSelected: (_) => setDS(() => selectedRole = r),
                        );
                      }).toList()),
                      if ((selectedRole == UserRole.staff || selectedRole == UserRole.storeManager || selectedRole == UserRole.inventoryChecker) && stores.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        _sectionLabel('Cửa hàng làm việc'),
                        const SizedBox(height: 10),
                        DropdownButtonFormField<int>(
                          initialValue: selectedStoreId,
                          decoration: _inputDeco('Chọn cửa hàng', Icons.store_outlined),
                          items: stores.map((s) => DropdownMenuItem(value: s.id, child: Text(s.name, style: const TextStyle(fontSize: 13)))).toList(),
                          onChanged: (v) => setDS(() => selectedStoreId = v),
                        ),
                      ],
                      const SizedBox(height: 14),
                      // Info: sẽ gửi thông báo
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.info.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.info.withValues(alpha: 0.3)),
                        ),
                        child: const Row(children: [
                          Icon(Icons.notifications_outlined, size: 14, color: AppColors.info),
                          SizedBox(width: 6),
                          Expanded(child: Text('Lưu thay đổi sẽ gửi thông báo đến nhân viên này', style: TextStyle(fontSize: 11, color: AppColors.info))),
                        ]),
                      ),
                    ]),
                  ),
                ),
                // Actions
                Container(
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
                  decoration: const BoxDecoration(border: Border(top: BorderSide(color: Color(0xFFEEEEEE)))),
                  child: Row(children: [
                    // Reset mật khẩu
                    OutlinedButton.icon(
                      onPressed: () async {
                        final confirmed = await showDialog<bool>(
                          context: ctx,
                          builder: (c) => AlertDialog(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            title: const Text('Reset mật khẩu?'),
                            content: Text('Mật khẩu của ${user.fullName} sẽ được đặt lại về 123456.'),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Hủy')),
                              ElevatedButton(
                                onPressed: () => Navigator.pop(c, true),
                                style: ElevatedButton.styleFrom(backgroundColor: AppColors.warning),
                                child: const Text('Reset', style: TextStyle(color: Colors.white)),
                              ),
                            ],
                          ),
                        );
                        if (confirmed == true) {
                          await DatabaseService.instance.resetPassword(user.id);
                          await _sendResetPasswordNotification(user);
                          if (ctx.mounted) Navigator.pop(ctx);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                              content: Text('Đã reset mật khẩu ${user.fullName} & gửi thông báo'),
                              backgroundColor: AppColors.warning,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ));
                          }
                        }
                      },
                      icon: const Icon(Icons.lock_reset, size: 16, color: AppColors.warning),
                      label: const Text('Reset MK', style: TextStyle(color: AppColors.warning, fontSize: 12)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.warning),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                      child: const Text('Hủy'),
                    )),
                    const SizedBox(width: 8),
                    Expanded(child: ElevatedButton(
                      onPressed: () async {
                        final storeNeeded = selectedRole == UserRole.staff ||
                            selectedRole == UserRole.storeManager ||
                            selectedRole == UserRole.inventoryChecker;
                        final storeId = storeNeeded ? selectedStoreId : null;
                        final updated = user.copyWith(
                          fullName: nameCtrl.text.trim(),
                          email: emailCtrl.text.trim().isNotEmpty ? emailCtrl.text.trim() : null,
                          phone: phoneCtrl.text.isEmpty ? null : phoneCtrl.text.trim(),
                          role: selectedRole, storeId: storeId,
                          updatedAt: DateTime.now(),
                        );
                        // Lưu reference trước await để tránh BuildContext across async gap
                        final authProvider = context.read<AuthProvider>();
                        final messenger = ScaffoldMessenger.of(context);

                        await DatabaseService.instance.updateUser(updated);
                        await authProvider.updateUserRole(user.id, selectedRole, storeId);

                        // Gửi thông báo vào DB
                        await _sendEditNotification(
                          user: user,
                          oldRole: user.role, newRole: selectedRole,
                          oldStoreId: user.storeId, newStoreId: storeId,
                          stores: stores,
                        );

                        if (ctx.mounted) Navigator.pop(ctx);
                        // FIX: gọi _reload() sau khi await xong - không phải trong setState callback
                        _reload();
                        messenger.showSnackBar(SnackBar(
                          content: Text('Đã cập nhật ${updated.fullName} & gửi thông báo'),
                          backgroundColor: AppColors.success,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ));
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text('Lưu thay đổi', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                    )),
                  ]),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }

  // ─── HELPERS ──────────────────────────────────────────────────────────────
  Widget _sectionLabel(String text) => Row(children: [
    Container(width: 3, height: 14, decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(2))),
    const SizedBox(width: 8),
    Text(text, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.textPrimary)),
  ]);

  Widget _buildTextField(TextEditingController ctrl, String label, IconData icon, {bool obscure = false}) =>
    TextField(controller: ctrl, obscureText: obscure, decoration: _inputDeco(label, icon));

  InputDecoration _inputDeco(String label, IconData icon) => InputDecoration(
    labelText: label,
    prefixIcon: Icon(icon, size: 18, color: AppColors.textSecondary),
    isDense: true,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE0E0E0))),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE0E0E0))),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
    filled: true, fillColor: AppColors.surfaceVariant,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
  );

  // ─── PAGINATION WIDGET ────────────────────────────────────────────────────
  Widget _buildPagination(int totalItems) {
    final totalPages = (totalItems / _pageSize).ceil().clamp(1, 999999);
    if (totalPages <= 1) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Prev button
          _PaginationBtn(
            icon: Icons.chevron_left,
            enabled: _currentPage > 1,
            onTap: () => setState(() => _currentPage--),
          ),
          const SizedBox(width: 6),
          // Page numbers
          ...List.generate(totalPages, (i) {
            final page = i + 1;
            // Hiển thị tối đa 5 trang xung quanh trang hiện tại
            final showPage = page == 1 ||
                page == totalPages ||
                (page >= _currentPage - 1 && page <= _currentPage + 1);
            final showEllipsisBefore = page == 2 && _currentPage > 3;
            final showEllipsisAfter = page == totalPages - 1 && _currentPage < totalPages - 2;

            if (showEllipsisBefore && !showPage) {
              return const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4),
                child: Text('...', style: TextStyle(color: AppColors.textHint)),
              );
            }
            if (showEllipsisAfter && page == totalPages - 1 && _currentPage < totalPages - 2) {
              return const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4),
                child: Text('...', style: TextStyle(color: AppColors.textHint)),
              );
            }
            if (!showPage) return const SizedBox.shrink();

            final isActive = page == _currentPage;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: InkWell(
                onTap: isActive ? null : () => setState(() => _currentPage = page),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  width: 34,
                  height: 34,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isActive ? AppColors.primary : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isActive ? AppColors.primary : const Color(0xFFE0E0E0),
                    ),
                  ),
                  child: Text(
                    '$page',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                      color: isActive ? Colors.white : AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
            );
          }),
          const SizedBox(width: 6),
          // Next button
          _PaginationBtn(
            icon: Icons.chevron_right,
            enabled: _currentPage < totalPages,
            onTap: () => setState(() => _currentPage++),
          ),
        ],
      ),
    );
  }

  // ─── BUILD ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<StoreModel>>(
      future: _storesFuture,
      builder: (context, storeSnap) {
        final stores = storeSnap.data ?? [];

        return Scaffold(
          backgroundColor: AppColors.background,
          body: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Header ────────────────────────────────────────────
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  const Text('Quản lý nhân sự', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                  ElevatedButton.icon(
                    onPressed: stores.isEmpty ? null : () => _showAddDialog(stores),
                    icon: const Icon(Icons.person_add_rounded, size: 18),
                    label: const Text('Thêm nhân sự'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary, foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ]),
                const SizedBox(height: 16),

                // ── Filters ───────────────────────────────────────────
                // FIX: Dùng Wrap thay vì Row để tránh overflow
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    // Search
                    SizedBox(
                      width: 220,
                      child: TextField(
                        controller: _searchCtrl,
                        onChanged: (_) => setState(() => _currentPage = 1),
                        decoration: _inputDeco('Tìm tên, email, SĐT...', Icons.search),
                      ),
                    ),
                    // FIX: Wrap DropdownButtonFormField với ConstrainedBox để tránh overflow
                    ConstrainedBox(
                      constraints: const BoxConstraints(minWidth: 160, maxWidth: 200),
                      child: IntrinsicWidth(
                        child: DropdownButtonFormField<UserRole?>(
                          value: _filterRole,
                          isExpanded: true,
                          decoration: _inputDeco('Lọc vai trò', Icons.badge_outlined),
                          items: [
                            const DropdownMenuItem(value: null, child: Text('Tất cả vai trò', overflow: TextOverflow.ellipsis)),
                            ...UserRole.values.map((r) => DropdownMenuItem(
                              value: r,
                              child: Text(r.displayName, overflow: TextOverflow.ellipsis),
                            )),
                          ],
                          onChanged: (v) => setState(() {
                            _filterRole = v;
                            _currentPage = 1;
                          }),
                        ),
                      ),
                    ),
                    // FIX: DropdownButtonFormField cửa hàng
                    ConstrainedBox(
                      constraints: const BoxConstraints(minWidth: 170, maxWidth: 220),
                      child: IntrinsicWidth(
                        child: DropdownButtonFormField<int?>(
                          value: _filterStoreId,
                          isExpanded: true,
                          decoration: _inputDeco('Lọc cửa hàng', Icons.store_outlined),
                          items: [
                            const DropdownMenuItem(value: null,  child: Text('Tất cả cửa hàng', overflow: TextOverflow.ellipsis)),
                            const DropdownMenuItem(value: -1, child: Text('Không có cửa hàng', overflow: TextOverflow.ellipsis)),
                            ...stores.map((s) => DropdownMenuItem(
                              value: s.id,
                              child: Text(s.name, overflow: TextOverflow.ellipsis),
                            )),
                          ],
                          onChanged: (v) => setState(() {
                            _filterStoreId = v;
                            _currentPage = 1;
                          }),
                        ),
                      ),
                    ),
                    if (_searchCtrl.text.isNotEmpty || _filterRole != null || _filterStoreId != null)
                      TextButton.icon(
                        onPressed: () => setState(() {
                          _searchCtrl.clear();
                          _filterRole = null;
                          _filterStoreId = null;
                          _currentPage = 1;
                        }),
                        icon: const Icon(Icons.clear_all, size: 16),
                        label: const Text('Xóa lọc'),
                      ),
                  ],
                ),
                const SizedBox(height: 14),

                // ── Data ───────────────────────────────────────────────
                Expanded(
                  child: FutureBuilder<List<UserModel>>(
                    future: _usersFuture,
                    builder: (context, snap) {
                      if (snap.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (snap.hasError) return Center(child: Text('Lỗi: ${snap.error}'));
                      final allUsers = snap.data ?? [];
                      final filtered = _applyFilter(allUsers);

                      // Pagination
                      final totalPages = (filtered.length / _pageSize).ceil().clamp(1, 999999);
                      final safePage = _currentPage.clamp(1, totalPages);
                      final startIdx = (safePage - 1) * _pageSize;
                      final endIdx = (startIdx + _pageSize).clamp(0, filtered.length);
                      final pageItems = filtered.sublist(startIdx, endIdx);

                      return Column(children: [
                        // Stats bar
                        Row(children: UserRole.values.map((r) {
                          final cnt = allUsers.where((u) => u.role == r).length;
                          final c = _roleColors[r] ?? AppColors.primary;
                          return Expanded(child: Container(
                            margin: const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: c.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: c.withValues(alpha: 0.2)),
                            ),
                            child: Column(children: [
                              Text('$cnt', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: c)),
                              Text(r.displayName, style: const TextStyle(fontSize: 11), textAlign: TextAlign.center),
                            ]),
                          ));
                        }).toList()),
                        const SizedBox(height: 10),

                        // Count + pagination info
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Hiển thị ${filtered.isEmpty ? 0 : startIdx + 1}–$endIdx / ${filtered.length} nhân sự',
                              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                            ),
                            if (filtered.length != allUsers.length)
                              Text(
                                '(tổng ${allUsers.length} người)',
                                style: const TextStyle(fontSize: 12, color: AppColors.textHint),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        // Table
                        Expanded(
                          child: filtered.isEmpty
                            ? const Center(child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.search_off, size: 52, color: AppColors.textHint),
                                  SizedBox(height: 12),
                                  Text('Không tìm thấy nhân sự', style: TextStyle(color: AppColors.textHint, fontSize: 14)),
                                ],
                              ))
                            : SingleChildScrollView(
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: AppColors.surface,
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 12, offset: const Offset(0, 4))],
                                  ),
                                  clipBehavior: Clip.antiAlias,
                                  child: Table(
                                    columnWidths: const {
                                      0: FixedColumnWidth(44),   // #
                                      1: FlexColumnWidth(2.5),   // Họ tên + email
                                      2: FlexColumnWidth(1.4),   // Username
                                      3: FlexColumnWidth(1.5),   // SĐT
                                      4: FlexColumnWidth(1.8),   // Vai trò
                                      5: FlexColumnWidth(2),     // Cửa hàng
                                      6: FixedColumnWidth(95),   // Trạng thái
                                      7: FixedColumnWidth(54),   // Edit
                                    },
                                    children: [
                                      // ── Header ──
                                      TableRow(
                                        decoration: const BoxDecoration(color: Color(0xFF1A1A2E)),
                                        children: [
                                          _buildTh('#'),
                                          _buildTh('Họ tên'),
                                          _buildTh('Username'),
                                          _buildTh('SĐT'),
                                          _buildTh('Vai trò'),
                                          _buildTh('Cửa hàng'),
                                          _buildTh('Trạng thái'),
                                          _buildTh(''),
                                        ],
                                      ),
                                      // ── Data rows (chỉ trang hiện tại) ──
                                      ...pageItems.asMap().entries.map((entry) {
                                        final idx = entry.key;
                                        final u   = entry.value;
                                        final c   = _roleColors[u.role] ?? AppColors.primary;
                                        final storeName = u.storeId != null
                                          ? stores.firstWhere(
                                              (s) => s.id == u.storeId,
                                              orElse: () => StoreModel(id: 0, code: '', name: '—', status: '', createdAt: DateTime.now(), updatedAt: DateTime.now()),
                                            ).name
                                          : null;

                                        // Số thứ tự theo toàn bộ danh sách
                                        final globalIdx = startIdx + idx;

                                        return TableRow(
                                          decoration: BoxDecoration(
                                            color: idx.isEven ? AppColors.surface : AppColors.background,
                                          ),
                                          children: [
                                            // #
                                            _buildTd(child: Text('${globalIdx + 1}',
                                              style: const TextStyle(fontSize: 12, color: AppColors.textHint),
                                              textAlign: TextAlign.center)),
                                            // Họ tên
                                            _buildTd(child: Row(children: [
                                              CircleAvatar(
                                                backgroundColor: c.withValues(alpha: 0.15), radius: 17,
                                                child: Text(
                                                  u.fullName.isNotEmpty ? u.fullName[0].toUpperCase() : '?',
                                                  style: TextStyle(color: c, fontWeight: FontWeight.w800, fontSize: 13),
                                                ),
                                              ),
                                              const SizedBox(width: 10),
                                              Expanded(child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Text(u.fullName,
                                                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                                                    overflow: TextOverflow.ellipsis),
                                                  if (u.email != null)
                                                    Text(u.email!,
                                                      style: const TextStyle(fontSize: 11, color: AppColors.textHint),
                                                      overflow: TextOverflow.ellipsis),
                                                ],
                                              )),
                                            ])),
                                            // Username
                                            _buildTd(child: Text(u.username,
                                              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontFamily: 'monospace'),
                                              overflow: TextOverflow.ellipsis)),
                                            // SĐT
                                            _buildTd(child: Text(u.phone ?? '—',
                                              style: const TextStyle(fontSize: 12))),
                                            // Vai trò
                                            _buildTd(child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: c.withValues(alpha: 0.1),
                                                borderRadius: BorderRadius.circular(7),
                                                border: Border.all(color: c.withValues(alpha: 0.3)),
                                              ),
                                              child: Text(u.role.displayName,
                                                style: TextStyle(fontSize: 11, color: c, fontWeight: FontWeight.w600),
                                                overflow: TextOverflow.ellipsis),
                                            )),
                                            // Cửa hàng
                                            _buildTd(child: storeName != null
                                              ? Row(children: [
                                                  const Icon(Icons.store, size: 12, color: AppColors.textHint),
                                                  const SizedBox(width: 4),
                                                  Expanded(child: Text(storeName,
                                                    style: const TextStyle(fontSize: 12),
                                                    overflow: TextOverflow.ellipsis)),
                                                ])
                                              : const Text('—', style: TextStyle(color: AppColors.textHint, fontSize: 12)),
                                            ),
                                            // Trạng thái
                                            _buildTd(child: FittedBox(
                                              fit: BoxFit.scaleDown,
                                              alignment: Alignment.centerLeft,
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                decoration: BoxDecoration(
                                                  color: (u.status == 'active' ? AppColors.success : AppColors.warning).withValues(alpha: 0.1),
                                                  borderRadius: BorderRadius.circular(6),
                                                  border: Border.all(color: (u.status == 'active' ? AppColors.success : AppColors.warning).withValues(alpha: 0.3)),
                                                ),
                                                child: Text(
                                                  u.status == 'active' ? 'Hoạt động' : 'Tạm nghỉ',
                                                  style: TextStyle(
                                                    fontSize: 11, fontWeight: FontWeight.w600,
                                                    color: u.status == 'active' ? AppColors.success : AppColors.warning,
                                                  ),
                                                ),
                                              ),
                                            )),
                                            // Edit
                                            _buildTd(child: IconButton(
                                              tooltip: 'Chỉnh sửa',
                                              onPressed: stores.isEmpty ? null : () => _showEditDialog(u, stores),
                                              icon: const Icon(Icons.edit_outlined, size: 18, color: AppColors.primary),
                                              padding: EdgeInsets.zero,
                                              constraints: const BoxConstraints(),
                                            )),
                                          ],
                                        );
                                      }),
                                    ],
                                  ),
                                ),
                              ),
                        ),

                        // ── Pagination bar ──
                        _buildPagination(filtered.length),
                      ]);
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ─── Pagination button helper ─────────────────────────────────────────────────
class _PaginationBtn extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  const _PaginationBtn({required this.icon, required this.enabled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 34,
        height: 34,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: enabled ? const Color(0xFFE0E0E0) : const Color(0xFFF0F0F0)),
          color: enabled ? Colors.white : const Color(0xFFF8F8F8),
        ),
        child: Icon(
          icon,
          size: 18,
          color: enabled ? AppColors.textSecondary : AppColors.textHint,
        ),
      ),
    );
  }
}

// ─── Table cell helpers (top-level) ──────────────────────────────────────────
Widget _buildTh(String label) => TableCell(
  verticalAlignment: TableCellVerticalAlignment.middle,
  child: Padding(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 13),
    child: Text(
      label,
      style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.4),
    ),
  ),
);

Widget _buildTd({required Widget child}) => TableCell(
  verticalAlignment: TableCellVerticalAlignment.middle,
  child: Padding(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
    child: child,
  ),
);
