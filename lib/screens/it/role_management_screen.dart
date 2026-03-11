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
  late Future<List<UserModel>> _usersFuture;
  late Future<List<StoreModel>> _storesFuture;

  static const _roleColors = {
    UserRole.ceoAdmin:         AppColors.ceoColor,
    UserRole.itAdmin:          AppColors.itColor,
    UserRole.storeManager:     Color(0xFF7B1FA2),  // deep purple
    UserRole.inventoryChecker: Color(0xFF00838F),  // teal
    UserRole.staff:            AppColors.staffColor,
  };

  @override
  void initState() {
    super.initState();
    _usersFuture  = DatabaseService.instance.getAllUsers();
    _storesFuture = DatabaseService.instance.getAllStores();
  }

  void _reload() {
    final f = DatabaseService.instance.getAllUsers();
    if (mounted) setState(() => _usersFuture = f);
  }

  List<UserModel> _applyFilter(List<UserModel> users) {
    var res = users;
    if (_filterRole != null) res = res.where((u) => u.role == _filterRole).toList();
    if (_searchCtrl.text.isNotEmpty) {
      final q = _searchCtrl.text.toLowerCase();
      res = res.where((u) => u.name.toLowerCase().contains(q) || u.email.toLowerCase().contains(q)).toList();
    }
    return res;
  }

  // ─── ADD DIALOG ────────────────────────────────────────────────────────────
  void _showAddDialog(List<StoreModel> stores) {
    final nameCtrl  = TextEditingController();
    final emailCtrl = TextEditingController();
    final passCtrl  = TextEditingController();
    final phoneCtrl = TextEditingController();
    var selectedRole    = UserRole.staff;
    String? selectedStoreId = stores.isNotEmpty ? stores.first.id : null;

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
                // Header gradient
                Container(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(colors: [AppColors.primary, AppColors.primaryLight],
                      begin: Alignment.topLeft, end: Alignment.bottomRight),
                  ),
                  child: Row(children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(12)),
                      child: const Icon(Icons.person_add_rounded, color: Colors.white, size: 22),
                    ),
                    const SizedBox(width: 14),
                    const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Thêm nhân sự mới', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
                      Text('Điền thông tin để tạo tài khoản', style: TextStyle(color: Colors.white70, fontSize: 12)),
                    ]),
                    const Spacer(),
                    IconButton(onPressed: () => Navigator.pop(ctx),
                      icon: const Icon(Icons.close, color: Colors.white70)),
                  ]),
                ),
                // Form body
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      _sectionLabel('Thông tin cá nhân'),
                      const SizedBox(height: 12),
                      _buildTextField(nameCtrl,  'Họ và tên *',  Icons.person_outline),
                      const SizedBox(height: 10),
                      _buildTextField(emailCtrl, 'Email *',       Icons.email_outlined),
                      const SizedBox(height: 10),
                      _buildTextField(phoneCtrl, 'Số điện thoại', Icons.phone_outlined),
                      const SizedBox(height: 10),
                      _buildTextField(passCtrl,  'Mật khẩu (mặc định: 123456)', Icons.lock_outline, obscure: true),
                      const SizedBox(height: 20),
                      _sectionLabel('Phân quyền'),
                      const SizedBox(height: 12),
                      // Role chips
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
                        DropdownButtonFormField<String>(
                          value: selectedStoreId,
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
                  decoration: const BoxDecoration(
                    border: Border(top: BorderSide(color: Color(0xFFEEEEEE))),
                  ),
                  child: Row(children: [
                    Expanded(child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                      child: const Text('Hủy'),
                    )),
                    const SizedBox(width: 12),
                    Expanded(child: ElevatedButton(
                      onPressed: () async {
                        if (nameCtrl.text.isEmpty || emailCtrl.text.isEmpty) return;
                        final storeNeeded = selectedRole == UserRole.staff || selectedRole == UserRole.storeManager || selectedRole == UserRole.inventoryChecker;
                        final storeId   = storeNeeded ? selectedStoreId : null;
                        final storeName = storeId != null ? stores.firstWhere((s) => s.id == storeId).name : null;
                        final newUser = UserModel(
                          id: 'u_${DateTime.now().millisecondsSinceEpoch}',
                          name: nameCtrl.text.trim(), email: emailCtrl.text.trim(),
                          password: passCtrl.text.isEmpty ? '123456' : passCtrl.text,
                          phone: phoneCtrl.text.isEmpty ? null : phoneCtrl.text.trim(),
                          role: selectedRole, storeId: storeId, storeName: storeName,
                        );
                        await DatabaseService.instance.insertUser(newUser);
                        if (ctx.mounted) Navigator.pop(ctx);
                        _reload();
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text('Đã thêm ${newUser.name}'),
                            backgroundColor: AppColors.success, behavior: SnackBarBehavior.floating,
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

  // ─── EDIT DIALOG ────────────────────────────────────────────────────────────
  void _showEditDialog(UserModel user, List<StoreModel> stores) {
    final nameCtrl  = TextEditingController(text: user.name);
    final emailCtrl = TextEditingController(text: user.email);
    final phoneCtrl = TextEditingController(text: user.phone ?? '');
    var selectedRole    = user.role;
    String? selectedStoreId = user.storeId ?? (stores.isNotEmpty ? stores.first.id : null);

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
                      colors: [_roleColors[user.role] ?? AppColors.primary, (_roleColors[user.role] ?? AppColors.primary).withValues(alpha: 0.7)],
                      begin: Alignment.topLeft, end: Alignment.bottomRight),
                  ),
                  child: Row(children: [
                    CircleAvatar(
                      radius: 22,
                      backgroundColor: Colors.white.withValues(alpha: 0.25),
                      child: Text(user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18)),
                    ),
                    const SizedBox(width: 14),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('Chỉnh sửa nhân sự', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
                      Text(user.email, style: const TextStyle(color: Colors.white70, fontSize: 12), overflow: TextOverflow.ellipsis),
                    ])),
                    IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close, color: Colors.white70)),
                  ]),
                ),
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      _sectionLabel('Thông tin cá nhân'),
                      const SizedBox(height: 12),
                      _buildTextField(nameCtrl,  'Họ và tên *', Icons.person_outline),
                      const SizedBox(height: 10),
                      _buildTextField(emailCtrl, 'Email *',      Icons.email_outlined),
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
                        DropdownButtonFormField<String>(
                          value: selectedStoreId,
                          decoration: _inputDeco('Chọn cửa hàng', Icons.store_outlined),
                          items: stores.map((s) => DropdownMenuItem(value: s.id, child: Text(s.name, style: const TextStyle(fontSize: 13)))).toList(),
                          onChanged: (v) => setDS(() => selectedStoreId = v),
                        ),
                      ],
                    ]),
                  ),
                ),
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
                            content: Text('Mật khẩu của ${user.name} sẽ được đặt lại về 123456.'),
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
                          if (ctx.mounted) Navigator.pop(ctx);
                          if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text('Đã reset mật khẩu ${user.name} về 123456'),
                            backgroundColor: AppColors.warning, behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ));
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
                        if (nameCtrl.text.isEmpty || emailCtrl.text.isEmpty) return;
                        final storeNeeded = selectedRole == UserRole.staff || selectedRole == UserRole.storeManager || selectedRole == UserRole.inventoryChecker;
                        final storeId   = storeNeeded ? selectedStoreId : null;
                        final storeName = storeId != null ? stores.firstWhere((s) => s.id == storeId).name : null;
                        final updated = UserModel(
                          id: user.id, password: user.password,
                          name: nameCtrl.text.trim(), email: emailCtrl.text.trim(),
                          phone: phoneCtrl.text.isEmpty ? null : phoneCtrl.text.trim(),
                          role: selectedRole, storeId: storeId, storeName: storeName,
                        );
                        await DatabaseService.instance.updateUser(updated);
                        await context.read<AuthProvider>().updateUserRole(user.id, selectedRole, storeId, storeName);
                        if (ctx.mounted) Navigator.pop(ctx);
                        _reload();
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text('Đã cập nhật ${updated.name}'),
                            backgroundColor: AppColors.success, behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ));
                        }
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

  // ─── HELPERS ────────────────────────────────────────────────────────────────
  Widget _sectionLabel(String text) => Row(children: [
    Container(width: 3, height: 14, decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(2))),
    const SizedBox(width: 8),
    Text(text, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.textPrimary)),
  ]);

  Widget _buildTextField(TextEditingController ctrl, String label, IconData icon, {bool obscure = false}) =>
    TextField(
      controller: ctrl, obscureText: obscure,
      decoration: _inputDeco(label, icon),
    );

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
                // Header row
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
                Row(children: [
                  Expanded(flex: 3, child: TextField(
                    controller: _searchCtrl,
                    onChanged: (_) => setState(() {}),
                    decoration: _inputDeco('Tìm theo tên, email...', Icons.search),
                  )),
                  const SizedBox(width: 12),
                  Expanded(flex: 2, child: DropdownButtonFormField<UserRole?>(
                    value: _filterRole,
                    decoration: _inputDeco('Lọc role', Icons.filter_list),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('Tất cả')),
                      ...UserRole.values.map((r) => DropdownMenuItem(value: r, child: Text(r.displayName))),
                    ],
                    onChanged: (v) => setState(() => _filterRole = v),
                  )),
                ]),
                const SizedBox(height: 16),
                Expanded(
                  child: FutureBuilder<List<UserModel>>(
                    future: _usersFuture,
                    builder: (context, snap) {
                      if (snap.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (snap.hasError) return Center(child: Text('Lỗi: ${snap.error}'));
                      final allUsers  = snap.data ?? [];
                      final filtered  = _applyFilter(allUsers);
                      return Column(children: [
                        // Stats row
                        Row(children: UserRole.values.map((r) {
                          final cnt = allUsers.where((u) => u.role == r).length;
                          final c = _roleColors[r] ?? AppColors.primary;
                          return Expanded(child: Container(
                            margin: const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(color: c.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: c.withValues(alpha: 0.2))),
                            child: Column(children: [
                              Text('$cnt', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: c)),
                              Text(r.displayName, style: const TextStyle(fontSize: 11)),
                            ]),
                          ));
                        }).toList()),
                        const SizedBox(height: 12),
                        const Divider(),
                        Expanded(child: ListView.builder(
                          itemCount: filtered.length,
                          itemBuilder: (ctx, i) {
                            final u = filtered[i];
                            final c = _roleColors[u.role] ?? AppColors.primary;
                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: BorderRadius.circular(14),
                                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0 ,2))],
                              ),
                              child: Row(children: [
                                CircleAvatar(
                                  backgroundColor: c.withValues(alpha: 0.15), radius: 22,
                                  child: Text(u.name.isNotEmpty ? u.name[0].toUpperCase() : '?',
                                    style: TextStyle(color: c, fontWeight: FontWeight.w800, fontSize: 16)),
                                ),
                                const SizedBox(width: 14),
                                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Text(u.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                                  Text(u.email, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                                  if (u.phone != null) Text('📞 ${u.phone}', style: const TextStyle(color: AppColors.textHint, fontSize: 11)),
                                  if (u.storeName != null) Text('📍 ${u.storeName}', style: const TextStyle(color: AppColors.textHint, fontSize: 11)),
                                ])),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(color: c.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
                                  child: Text(u.role.displayName, style: TextStyle(color: c, fontWeight: FontWeight.w600, fontSize: 12)),
                                ),
                                const SizedBox(width: 6),
                                IconButton(
                                  tooltip: 'Chỉnh sửa',
                                  onPressed: stores.isEmpty ? null : () => _showEditDialog(u, stores),
                                  icon: const Icon(Icons.edit_outlined, size: 20, color: AppColors.textSecondary),
                                ),
                              ]),
                            );
                          },
                        )),
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
