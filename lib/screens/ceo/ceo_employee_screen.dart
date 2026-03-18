import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/enums.dart';
import '../../core/utils/format_utils.dart';
import '../../data/database_service.dart';
import '../../models/store_model.dart';
import '../../models/user_model.dart';

const int _kPageSize = 10;

class CeoEmployeeScreen extends StatefulWidget {
  const CeoEmployeeScreen({super.key});

  @override
  State<CeoEmployeeScreen> createState() => _CeoEmployeeScreenState();
}

class _CeoEmployeeScreenState extends State<CeoEmployeeScreen> {
  late Future<_EmpData> _dataFuture;

  // Filters
  String _searchQuery = '';
  String? _roleFilter;
  String? _storeFilter;
  String _statusFilter = 'all';
  String _sortBy = 'name';
  bool _sortAsc = true;

  // Pagination
  int _currentPage = 0;

  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _dataFuture = _fetch();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<_EmpData> _fetch() async {
    final users = await DatabaseService.instance.getAllUsers();
    final stores = await DatabaseService.instance.getAllStores();
    return _EmpData(users: users, stores: stores);
  }

  List<UserModel> _filtered(List<UserModel> all, List<StoreModel> stores) {
    var list = all.where((u) {
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        if (!u.fullName.toLowerCase().contains(q) &&
            !u.username.toLowerCase().contains(q) &&
            !(u.email?.toLowerCase().contains(q) ?? false) &&
            !(u.phone?.contains(q) ?? false)) {
          return false;
        }
      }
      if (_roleFilter != null && _userRoleKey(u.role) != _roleFilter) return false;
      if (_storeFilter != null) {
        if (_storeFilter == '__none__') {
          if (u.storeId != null) return false;
        } else {
          if (u.storeId?.toString() != _storeFilter) return false;
        }
      }
      if (_statusFilter == 'active' && u.status != 'active') return false;
      if (_statusFilter == 'inactive' && u.status == 'active') return false;
      return true;
    }).toList();

    list.sort((a, b) {
      int cmp;
      switch (_sortBy) {
        case 'role':
          cmp = _userRoleKey(a.role).compareTo(_userRoleKey(b.role));
          break;
        case 'store':
          final aName = stores.firstWhere((s) => s.id == a.storeId,
              orElse: () => StoreModel(id: 0, code: '', name: '', status: '', createdAt: DateTime.now(), updatedAt: DateTime.now())).name;
          final bName = stores.firstWhere((s) => s.id == b.storeId,
              orElse: () => StoreModel(id: 0, code: '', name: '', status: '', createdAt: DateTime.now(), updatedAt: DateTime.now())).name;
          cmp = aName.compareTo(bName);
          break;
        case 'status':
          cmp = a.status.compareTo(b.status);
          break;
        default:
          cmp = a.fullName.compareTo(b.fullName);
      }
      return _sortAsc ? cmp : -cmp;
    });

    return list;
  }

  String _userRoleKey(UserRole role) {
    switch (role) {
      case UserRole.ceoAdmin:         return 'ceoAdmin';
      case UserRole.itAdmin:          return 'itAdmin';
      case UserRole.storeManager:     return 'storeManager';
      case UserRole.inventoryChecker: return 'inventoryChecker';
      case UserRole.staff:            return 'staff';
    }
  }

  void _toggleSort(String col) {
    setState(() {
      if (_sortBy == col) {
        _sortAsc = !_sortAsc;
      } else {
        _sortBy = col;
        _sortAsc = true;
      }
      _currentPage = 0;
    });
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          // ── Header ─────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
            color: AppColors.surface,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.group, color: AppColors.primary, size: 24),
                    const SizedBox(width: 10),
                    Text(
                      'Danh sách nhân viên',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => setState(() {
                        _dataFuture = _fetch();
                        _currentPage = 0;
                      }),
                      icon: const Icon(Icons.refresh, color: AppColors.primary),
                      tooltip: 'Làm mới',
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                FutureBuilder<_EmpData>(
                  future: _dataFuture,
                  builder: (context, snap) {
                    final stores = snap.data?.stores ?? [];
                    return _FilterRow(
                      searchCtrl: _searchCtrl,
                      stores: stores,
                      roleFilter: _roleFilter,
                      storeFilter: _storeFilter,
                      statusFilter: _statusFilter,
                      onSearch: (v) { setState(() { _searchQuery = v; _currentPage = 0; }); },
                      onRoleChanged: (v) { setState(() { _roleFilter = v; _currentPage = 0; }); },
                      onStoreChanged: (v) { setState(() { _storeFilter = v; _currentPage = 0; }); },
                      onStatusChanged: (v) { setState(() { _statusFilter = v; _currentPage = 0; }); },
                      onClear: () => setState(() {
                        _searchQuery = '';
                        _searchCtrl.clear();
                        _roleFilter = null;
                        _storeFilter = null;
                        _statusFilter = 'all';
                        _currentPage = 0;
                      }),
                    );
                  },
                ),
              ],
            ),
          ),

          // ── Body ───────────────────────────────────────
          Expanded(
            child: FutureBuilder<_EmpData>(
              future: _dataFuture,
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  return Center(child: Text('Lỗi: ${snap.error}'));
                }
                final data = snap.data!;
                final filtered = _filtered(data.users, data.stores);

                // Pagination
                final totalPages = (filtered.length / _kPageSize).ceil().clamp(1, 99999);
                final safePage = _currentPage.clamp(0, totalPages - 1);
                final pageStart = safePage * _kPageSize;
                final pageEnd = (pageStart + _kPageSize).clamp(0, filtered.length);
                final pageUsers = filtered.sublist(pageStart, pageEnd);

                return Column(
                  children: [
                    // Summary
                    _SummaryBar(all: data.users, filtered: filtered),

                    // Table
                    Expanded(
                      child: filtered.isEmpty
                          ? const Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.search_off, size: 56, color: AppColors.textHint),
                                  SizedBox(height: 14),
                                  Text(
                                    'Không tìm thấy nhân viên phù hợp',
                                    style: TextStyle(color: AppColors.textHint, fontSize: 15),
                                  ),
                                ],
                              ),
                            )
                          : SingleChildScrollView(
                              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                              child: _EmployeeTable(
                                users: pageUsers,
                                stores: data.stores,
                                globalOffset: pageStart,
                                sortBy: _sortBy,
                                sortAsc: _sortAsc,
                                onSort: _toggleSort,
                              ),
                            ),
                    ),

                    // Pagination bar
                    if (filtered.isNotEmpty)
                      _PaginationBar(
                        currentPage: safePage,
                        totalPages: totalPages,
                        totalItems: filtered.length,
                        pageSize: _kPageSize,
                        onPageChanged: (p) => setState(() => _currentPage = p),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Filter Row ───────────────────────────────────────────────────────────────
class _FilterRow extends StatelessWidget {
  final TextEditingController searchCtrl;
  final List<StoreModel> stores;
  final String? roleFilter;
  final String? storeFilter;
  final String statusFilter;
  final ValueChanged<String> onSearch;
  final ValueChanged<String?> onRoleChanged;
  final ValueChanged<String?> onStoreChanged;
  final ValueChanged<String> onStatusChanged;
  final VoidCallback onClear;

  const _FilterRow({
    required this.searchCtrl,
    required this.stores,
    required this.roleFilter,
    required this.storeFilter,
    required this.statusFilter,
    required this.onSearch,
    required this.onRoleChanged,
    required this.onStoreChanged,
    required this.onStatusChanged,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(
          width: 240,
          height: 42,
          child: TextField(
            controller: searchCtrl,
            onChanged: onSearch,
            style: const TextStyle(fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Tìm tên, username, email...',
              hintStyle: const TextStyle(fontSize: 13),
              prefixIcon: const Icon(Icons.search, size: 20, color: AppColors.textHint),
              contentPadding: const EdgeInsets.symmetric(vertical: 0),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.divider)),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.divider)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
              filled: true,
              fillColor: AppColors.background,
            ),
          ),
        ),
        _DropdownFilter<String?>(
          hint: 'Vai trò',
          value: roleFilter,
          items: const [
            DropdownMenuItem(value: null, child: Text('Tất cả vai trò')),
            DropdownMenuItem(value: 'ceoAdmin', child: Text('CEO Admin')),
            DropdownMenuItem(value: 'itAdmin', child: Text('IT Admin')),
            DropdownMenuItem(value: 'storeManager', child: Text('Cửa hàng trưởng')),
            DropdownMenuItem(value: 'inventoryChecker', child: Text('Kiểm kho')),
            DropdownMenuItem(value: 'staff', child: Text('Nhân viên')),
          ],
          onChanged: onRoleChanged,
        ),
        _DropdownFilter<String?>(
          hint: 'Cửa hàng',
          value: storeFilter,
          items: [
            const DropdownMenuItem(value: null, child: Text('Tất cả cửa hàng')),
            const DropdownMenuItem(value: '__none__', child: Text('Không có cửa hàng')),
            ...stores.map((s) => DropdownMenuItem(value: s.id.toString(), child: Text(s.name))),
          ],
          onChanged: onStoreChanged,
        ),
        _DropdownFilter<String>(
          hint: 'Trạng thái',
          value: statusFilter,
          items: const [
            DropdownMenuItem(value: 'all', child: Text('Tất cả')),
            DropdownMenuItem(value: 'active', child: Text('Đang làm')),
            DropdownMenuItem(value: 'inactive', child: Text('Nghỉ phép')),
          ],
          onChanged: (v) => onStatusChanged(v ?? 'all'),
        ),
        OutlinedButton.icon(
          onPressed: onClear,
          icon: const Icon(Icons.clear_all, size: 18),
          label: const Text('Xóa lọc', style: TextStyle(fontSize: 13)),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.textSecondary,
            side: const BorderSide(color: AppColors.divider),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            minimumSize: const Size(0, 42),
          ),
        ),
      ],
    );
  }
}

class _DropdownFilter<T> extends StatelessWidget {
  final String hint;
  final T value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;

  const _DropdownFilter({
    required this.hint,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.divider),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          hint: Text(hint, style: const TextStyle(fontSize: 13, color: AppColors.textHint)),
          style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
          icon: const Icon(Icons.keyboard_arrow_down, size: 20, color: AppColors.textHint),
          items: items,
          onChanged: onChanged,
          isDense: true,
        ),
      ),
    );
  }
}

// ─── Summary Bar ──────────────────────────────────────────────────────────────
class _SummaryBar extends StatelessWidget {
  final List<UserModel> all;
  final List<UserModel> filtered;

  const _SummaryBar({required this.all, required this.filtered});

  @override
  Widget build(BuildContext context) {
    final active   = filtered.where((u) => u.status == 'active').length;
    final inactive = filtered.length - active;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      color: AppColors.surface,
      child: Row(
        children: [
          _SummaryChip(label: 'Hiển thị', value: '${filtered.length}/${all.length}', color: AppColors.info),
          const SizedBox(width: 12),
          _SummaryChip(label: 'Đang làm', value: '$active', color: AppColors.success),
          const SizedBox(width: 12),
          _SummaryChip(label: 'Nghỉ phép', value: '$inactive', color: AppColors.warning),
        ],
      ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _SummaryChip({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w500)),
          const SizedBox(width: 8),
          Text(value, style: TextStyle(fontSize: 15, color: color, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

// ─── Pagination Bar ───────────────────────────────────────────────────────────
class _PaginationBar extends StatelessWidget {
  final int currentPage;
  final int totalPages;
  final int totalItems;
  final int pageSize;
  final ValueChanged<int> onPageChanged;

  const _PaginationBar({
    required this.currentPage,
    required this.totalPages,
    required this.totalItems,
    required this.pageSize,
    required this.onPageChanged,
  });

  @override
  Widget build(BuildContext context) {
    final from = currentPage * pageSize + 1;
    final to   = ((currentPage + 1) * pageSize).clamp(1, totalItems);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.divider)),
      ),
      child: Row(
        children: [
          Text(
            'Hiển thị $from–$to / $totalItems nhân viên',
            style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
          const Spacer(),
          // Prev
          _PageBtn(
            icon: Icons.chevron_left,
            enabled: currentPage > 0,
            onTap: () => onPageChanged(currentPage - 1),
          ),
          const SizedBox(width: 4),
          // Page numbers
          ..._buildPageNumbers(),
          const SizedBox(width: 4),
          // Next
          _PageBtn(
            icon: Icons.chevron_right,
            enabled: currentPage < totalPages - 1,
            onTap: () => onPageChanged(currentPage + 1),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildPageNumbers() {
    final pages = <Widget>[];
    // Show at most 7 page buttons
    int start = (currentPage - 3).clamp(0, (totalPages - 7).clamp(0, totalPages));
    int end   = (start + 7).clamp(0, totalPages);

    for (int i = start; i < end; i++) {
      final isActive = i == currentPage;
      pages.add(
        GestureDetector(
          onTap: () => onPageChanged(i),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 2),
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: isActive ? AppColors.primary : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isActive ? AppColors.primary : AppColors.divider,
              ),
            ),
            child: Center(
              child: Text(
                '${i + 1}',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isActive ? Colors.white : AppColors.textPrimary,
                ),
              ),
            ),
          ),
        ),
      );
    }
    return pages;
  }
}

class _PageBtn extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  const _PageBtn({required this.icon, required this.enabled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: enabled ? AppColors.divider : AppColors.divider.withValues(alpha: 0.4)),
        ),
        child: Icon(
          icon,
          size: 20,
          color: enabled ? AppColors.textPrimary : AppColors.textHint,
        ),
      ),
    );
  }
}

// ─── Employee Table ───────────────────────────────────────────────────────────
class _EmployeeTable extends StatelessWidget {
  final List<UserModel> users;
  final List<StoreModel> stores;
  final int globalOffset;
  final String sortBy;
  final bool sortAsc;
  final ValueChanged<String> onSort;

  const _EmployeeTable({
    required this.users,
    required this.stores,
    required this.globalOffset,
    required this.sortBy,
    required this.sortAsc,
    required this.onSort,
  });

  String _storeName(int? storeId) {
    if (storeId == null) return '—';
    try {
      return stores.firstWhere((s) => s.id == storeId).name;
    } catch (_) {
      return '—';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 12, offset: const Offset(0, 4))
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Table(
        columnWidths: const {
          0: FixedColumnWidth(50),   // #
          1: FlexColumnWidth(2.5),   // Họ tên
          2: FlexColumnWidth(1.5),   // Username
          3: FlexColumnWidth(1.8),   // SĐT / Email
          4: FlexColumnWidth(2),     // Vai trò
          5: FlexColumnWidth(2),     // Cửa hàng
          6: FixedColumnWidth(110),  // Ngày vào
          7: FixedColumnWidth(120),  // Trạng thái
        },
        children: [
          // Header
          TableRow(
            decoration: const BoxDecoration(color: Color(0xFF1A1A2E)),
            children: [
              _buildTh('#'),
              _buildThSort('Họ tên', 'name', sortBy, sortAsc, onSort),
              _buildThSort('Username', 'username', sortBy, sortAsc, onSort),
              _buildTh('Liên hệ'),
              _buildThSort('Vai trò', 'role', sortBy, sortAsc, onSort),
              _buildThSort('Cửa hàng', 'store', sortBy, sortAsc, onSort),
              _buildTh('Ngày vào'),
              _buildThSort('Trạng thái', 'status', sortBy, sortAsc, onSort),
            ],
          ),
          // Data rows
          ...users.asMap().entries.map((entry) {
            final i = entry.key;
            final u = entry.value;
            final isEven = i.isEven;
            return TableRow(
              decoration: BoxDecoration(
                color: isEven ? AppColors.surface : AppColors.background,
              ),
              children: [
                _buildTd(
                  child: Text(
                    '${globalOffset + i + 1}',
                    style: const TextStyle(fontSize: 13, color: AppColors.textHint),
                    textAlign: TextAlign.center,
                  ),
                ),
                _buildTd(
                  child: Row(
                    children: [
                      _Avatar(name: u.fullName, active: u.status == 'active'),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          u.fullName,
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                _buildTd(
                  child: Text(
                    u.username,
                    style: const TextStyle(
                        fontSize: 13, color: AppColors.textSecondary, fontFamily: 'monospace'),
                  ),
                ),
                _buildTd(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (u.phone != null)
                        Text(u.phone!, style: const TextStyle(fontSize: 13)),
                      if (u.email != null)
                        Text(
                          u.email!,
                          style: const TextStyle(fontSize: 12, color: AppColors.textHint),
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                _buildTd(child: _RoleBadge(role: u.role)),
                _buildTd(
                  child: u.storeId != null
                      ? Row(
                          children: [
                            const Icon(Icons.store, size: 13, color: AppColors.textHint),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                _storeName(u.storeId),
                                style: const TextStyle(fontSize: 13),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        )
                      : const Text('—', style: TextStyle(color: AppColors.textHint, fontSize: 13)),
                ),
                _buildTd(
                  child: Text(
                    u.startDate != null
                        ? FormatUtils.formatDate(u.startDate!)
                        : FormatUtils.formatDate(u.createdAt),
                    style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                  ),
                ),
                _buildTd(child: _StatusBadge(active: u.status == 'active')),
              ],
            );
          }),
        ],
      ),
    );
  }
}

// ─── Table cell helpers ───────────────────────────────────────────────────────
Widget _buildTh(String label) {
  return TableCell(
    verticalAlignment: TableCellVerticalAlignment.middle,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.4,
        ),
      ),
    ),
  );
}

Widget _buildThSort(
    String label, String col, String currentSort, bool asc, ValueChanged<String> onSort) {
  final isActive = currentSort == col;
  return TableCell(
    verticalAlignment: TableCellVerticalAlignment.middle,
    child: InkWell(
      onTap: () => onSort(col),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: isActive ? AppColors.primary : Colors.white70,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.4,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              isActive
                  ? (asc ? Icons.arrow_upward : Icons.arrow_downward)
                  : Icons.unfold_more,
              size: 13,
              color: isActive ? AppColors.primary : Colors.white38,
            ),
          ],
        ),
      ),
    ),
  );
}

Widget _buildTd({required Widget child}) {
  return TableCell(
    verticalAlignment: TableCellVerticalAlignment.middle,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      child: child,
    ),
  );
}

// ─── Avatar ───────────────────────────────────────────────────────────────────
class _Avatar extends StatelessWidget {
  final String name;
  final bool active;

  const _Avatar({required this.name, required this.active});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: active
              ? [AppColors.success.withValues(alpha: 0.7), AppColors.success]
              : [AppColors.warning.withValues(alpha: 0.7), AppColors.warning],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : '?',
          style: const TextStyle(
              color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

// ─── Role Badge ───────────────────────────────────────────────────────────────
class _RoleBadge extends StatelessWidget {
  final UserRole role;

  const _RoleBadge({required this.role});

  Color get _color {
    switch (role) {
      case UserRole.ceoAdmin:         return const Color(0xFF7C3AED);
      case UserRole.itAdmin:          return const Color(0xFF0284C7);
      case UserRole.storeManager:     return AppColors.primary;
      case UserRole.inventoryChecker: return AppColors.warning;
      case UserRole.staff:            return AppColors.info;
    }
  }

  IconData get _icon {
    switch (role) {
      case UserRole.ceoAdmin:         return Icons.corporate_fare;
      case UserRole.itAdmin:          return Icons.computer;
      case UserRole.storeManager:     return Icons.manage_accounts;
      case UserRole.inventoryChecker: return Icons.inventory;
      case UserRole.staff:            return Icons.person;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: _color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_icon, size: 12, color: _color),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              role.displayName,
              style: TextStyle(fontSize: 12, color: _color, fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Status Badge ─────────────────────────────────────────────────────────────
class _StatusBadge extends StatelessWidget {
  final bool active;

  const _StatusBadge({required this.active});

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.success : AppColors.warning;
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(7),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              active ? Icons.check_circle_outline : Icons.pause_circle_outline,
              size: 13,
              color: color,
            ),
            const SizedBox(width: 4),
            Text(
              active ? 'Đang làm' : 'Nghỉ phép',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Data models ──────────────────────────────────────────────────────────────
class _EmpData {
  final List<UserModel> users;
  final List<StoreModel> stores;
  const _EmpData({required this.users, required this.stores});
}
