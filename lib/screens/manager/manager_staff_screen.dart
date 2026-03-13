import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/enums.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/utils/format_utils.dart';
import '../../data/database_service.dart';
import '../../models/user_model.dart';
import '../../models/order_model.dart';
import '../../models/work_schedule_model.dart';

class ManagerStaffScreen extends StatefulWidget {
  const ManagerStaffScreen({super.key});
  @override
  State<ManagerStaffScreen> createState() => _ManagerStaffScreenState();
}

class _ManagerStaffScreenState extends State<ManagerStaffScreen> {
  late Future<_StaffPageData> _dataFuture;

  @override
  void initState() {
    super.initState();
    _dataFuture = _fetch();
  }

  void _load() {
    final f = _fetch();
    if (mounted) setState(() => _dataFuture = f);
  }

  Future<_StaffPageData> _fetch() async {
    final storeId = context.read<AuthProvider>().currentUser?.storeId;
    final users = storeId != null
        ? await DatabaseService.instance.getUsersByStore(storeId)
        : await DatabaseService.instance.getAllUsers();
    final staffOnly = users.where((u) => u.role == UserRole.staff).toList();
    final shifts = await DatabaseService.instance.getAllShifts();
    return _StaffPageData(staffList: staffOnly, shifts: shifts, storeId: storeId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: FutureBuilder<_StaffPageData>(
        future: _dataFuture,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('Lỗi: ${snap.error}'));
          }
          final data = snap.data!;
          return RefreshIndicator(
            onRefresh: () async => _load(),
            color: const Color(0xFF1A237E),
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Danh sách nhân viên',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            Text(
                              '${data.staffList.length} nhân viên',
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                        IconButton(
                          onPressed: _load,
                          icon: const Icon(Icons.refresh, color: Color(0xFF1A237E)),
                        ),
                      ],
                    ),
                  ),
                ),

                // Summary chips
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        _SummaryChip(
                          label: 'Đang làm',
                          count: data.staffList.where((u) => u.status == 'active').length,
                          color: AppColors.success,
                          icon: Icons.check_circle_outline,
                        ),
                        const SizedBox(width: 10),
                        _SummaryChip(
                          label: 'Nghỉ phép',
                          count: data.staffList.where((u) => u.status != 'active').length,
                          color: AppColors.warning,
                          icon: Icons.pause_circle_outline,
                        ),
                      ],
                    ),
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 16)),

                // Staff list
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, i) {
                      final staff = data.staffList[i];
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 6,
                        ),
                        child: _StaffCard(
                          staff: staff,
                          shifts: data.shifts,
                          storeId: data.storeId,
                          managerId:
                              context.read<AuthProvider>().currentUser?.id ?? 0,
                          onChanged: _load,
                        ),
                      );
                    },
                    childCount: data.staffList.length,
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 20)),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ─── Staff Card ────────────────────────────────────────────────────────────────
class _StaffCard extends StatefulWidget {
  final UserModel staff;
  final List<WorkShiftModel> shifts;
  final int? storeId;
  final int managerId;
  final VoidCallback onChanged;

  const _StaffCard({
    required this.staff,
    required this.shifts,
    required this.storeId,
    required this.managerId,
    required this.onChanged,
  });

  @override
  State<_StaffCard> createState() => _StaffCardState();
}

class _StaffCardState extends State<_StaffCard> {
  bool _expanded = false;
  bool _showHistory = false;
  bool _showSchedule = false;

  @override
  Widget build(BuildContext context) {
    final staff = widget.staff;
    final isActive = staff.status == 'active';

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isActive
              ? AppColors.success.withValues(alpha: 0.3)
              : AppColors.warning.withValues(alpha: 0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header
          InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // Avatar
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isActive
                            ? [
                                AppColors.success.withValues(alpha: 0.8),
                                AppColors.success,
                              ]
                            : [
                                AppColors.warning.withValues(alpha: 0.8),
                                AppColors.warning,
                              ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        staff.fullName.isNotEmpty
                            ? staff.fullName[0].toUpperCase()
                            : '?',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          staff.fullName,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          staff.phone ?? staff.email ?? staff.username,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Status badge
                  GestureDetector(
                    onTap: () => _toggleStatus(staff, isActive),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: isActive
                            ? AppColors.successLight
                            : AppColors.warningLight,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isActive ? Icons.check_circle : Icons.pause_circle,
                            size: 13,
                            color: isActive
                                ? AppColors.success
                                : AppColors.warning,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            isActive ? 'Đang làm' : 'Nghỉ phép',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: isActive
                                  ? AppColors.success
                                  : AppColors.warning,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: AppColors.textHint,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),

          // Expanded panel
          if (_expanded)
            Container(
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: AppColors.divider)),
              ),
              child: Column(
                children: [
                  // Action buttons row
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: Row(
                      children: [
                        _ActionBtn(
                          icon: Icons.history,
                          label: 'Lịch sử bán',
                          color: AppColors.info,
                          active: _showHistory,
                          onTap: () => setState(() {
                            _showHistory = !_showHistory;
                            if (_showHistory) _showSchedule = false;
                          }),
                        ),
                        const SizedBox(width: 8),
                        _ActionBtn(
                          icon: Icons.calendar_today,
                          label: 'Xếp lịch',
                          color: AppColors.primary,
                          active: _showSchedule,
                          onTap: () => setState(() {
                            _showSchedule = !_showSchedule;
                            if (_showSchedule) _showHistory = false;
                          }),
                        ),
                        const SizedBox(width: 8),
                        _ActionBtn(
                          icon: Icons.lock_reset,
                          label: 'Reset MK',
                          color: AppColors.warning,
                          active: false,
                          onTap: () => _resetPassword(staff),
                        ),
                      ],
                    ),
                  ),

                  // Sales history panel
                  if (_showHistory)
                    _StaffSalesHistoryPanel(
                      staffId: staff.id,
                      storeId: widget.storeId,
                    ),

                  // Schedule assign panel
                  if (_showSchedule)
                    _StaffSchedulePanel(
                      staff: staff,
                      shifts: widget.shifts,
                      managerId: widget.managerId,
                      onAssigned: widget.onChanged,
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _toggleStatus(UserModel staff, bool isActive) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          isActive ? 'Đặt nghỉ phép?' : 'Kích hoạt lại?',
          style: const TextStyle(fontSize: 16),
        ),
        content: Text(
          isActive
              ? 'Nhân viên ${staff.fullName} sẽ được đặt trạng thái nghỉ phép.'
              : 'Nhân viên ${staff.fullName} sẽ được kích hoạt lại.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: isActive ? AppColors.warning : AppColors.success,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(isActive ? 'Đặt nghỉ phép' : 'Kích hoạt'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      final updated = staff.copyWith(status: isActive ? 'inactive' : 'active');
      await DatabaseService.instance.updateUser(updated);
      widget.onChanged();
    }
  }

  Future<void> _resetPassword(UserModel staff) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Reset mật khẩu?', style: TextStyle(fontSize: 16)),
        content:
            Text('Mật khẩu của ${staff.fullName} sẽ được đặt về "123456".'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.warning,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await DatabaseService.instance.resetPassword(staff.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Đã reset mật khẩu về 123456'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    }
  }
}

// ─── Staff Sales History Panel ─────────────────────────────────────────────────
class _StaffSalesHistoryPanel extends StatefulWidget {
  final int staffId;
  final int? storeId;
  const _StaffSalesHistoryPanel({required this.staffId, required this.storeId});

  @override
  State<_StaffSalesHistoryPanel> createState() =>
      _StaffSalesHistoryPanelState();
}

class _StaffSalesHistoryPanelState extends State<_StaffSalesHistoryPanel> {
  PeriodFilter _period = PeriodFilter.week;
  late Future<_StaffSalesData> _future;

  @override
  void initState() {
    super.initState();
    _future = _fetch();
  }

  Future<_StaffSalesData> _fetch() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    DateTime from;
    DateTime to = today.add(const Duration(days: 1)).subtract(const Duration(milliseconds: 1));

    switch (_period) {
      case PeriodFilter.day:
        from = today;
        break;
      case PeriodFilter.week:
        from = today.subtract(Duration(days: today.weekday - 1));
        break;
      case PeriodFilter.month:
        from = DateTime(now.year, now.month, 1);
        break;
    }

    // Get all orders for the period
    final orders = await DatabaseService.instance.getSalesOrders(
      storeId: widget.storeId,
      from: from,
      to: to,
    );
    // Filter by staff
    final staffOrders =
        orders.where((o) => o.staffUserId == widget.staffId).toList();
    final revenue = staffOrders.fold<double>(0, (s, o) => s + o.finalAmount);
    return _StaffSalesData(orders: staffOrders, revenue: revenue);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      decoration: BoxDecoration(
        color: AppColors.infoLight.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.info.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                const Icon(Icons.analytics_outlined, size: 15, color: AppColors.info),
                const SizedBox(width: 6),
                const Text(
                  'Lịch sử bán hàng',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.info),
                ),
                const Spacer(),
                _PeriodChips(
                  selected: _period,
                  onChanged: (p) => setState(() {
                    _period = p;
                    _future = _fetch();
                  }),
                ),
              ],
            ),
          ),
          FutureBuilder<_StaffSalesData>(
            future: _future,
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              final d = snap.data!;
              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Row(
                      children: [
                        Expanded(
                          child: _MiniStat(
                            label: 'Doanh thu',
                            value: FormatUtils.formatCurrency(d.revenue),
                            color: AppColors.success,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _MiniStat(
                            label: 'Số đơn',
                            value: '${d.orders.length}',
                            color: AppColors.info,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (d.orders.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(
                        child: Text(
                          'Không có đơn hàng',
                          style: TextStyle(color: AppColors.textHint, fontSize: 13),
                        ),
                      ),
                    )
                  else
                    ListView.separated(
                      physics: const NeverScrollableScrollPhysics(),
                      shrinkWrap: true,
                      padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                      itemCount: d.orders.length > 5 ? 5 : d.orders.length,
                      separatorBuilder: (_, __) =>
                          const Divider(height: 1, color: AppColors.divider),
                      itemBuilder: (ctx, i) {
                        final o = d.orders[i];
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  o.orderNo,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              Text(
                                FormatUtils.formatDate(o.orderDate),
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                FormatUtils.formatCurrency(o.finalAmount),
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primary,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  if (d.orders.length > 5)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        '+${d.orders.length - 5} đơn khác',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textHint,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

// ─── Staff Schedule Panel ──────────────────────────────────────────────────────
class _StaffSchedulePanel extends StatefulWidget {
  final UserModel staff;
  final List<WorkShiftModel> shifts;
  final int managerId;
  final VoidCallback onAssigned;

  const _StaffSchedulePanel({
    required this.staff,
    required this.shifts,
    required this.managerId,
    required this.onAssigned,
  });

  @override
  State<_StaffSchedulePanel> createState() => _StaffSchedulePanelState();
}

class _StaffSchedulePanelState extends State<_StaffSchedulePanel> {
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();
  WorkShiftModel? _selectedShift;
  late Future<List<ShiftAssignmentModel>> _assignFuture;

  @override
  void initState() {
    super.initState();
    _assignFuture = _fetchAssignments();
  }

  Future<List<ShiftAssignmentModel>> _fetchAssignments() {
    return DatabaseService.instance.getShiftAssignments(
      userId: widget.staff.id,
      fromDate: DateTime.now().subtract(const Duration(days: 7)),
      toDate: DateTime.now().add(const Duration(days: 30)),
    );
  }

  Future<void> _assignShift() async {
    if (_selectedShift == null) return;

    // ── Fetch current assignments for selected day to check duplicates ──
    final existing = await DatabaseService.instance.getShiftAssignments(
      userId: widget.staff.id,
      fromDate: _selectedDay,
      toDate: _selectedDay,
    );
    final selectedKey = DateTime(
      _selectedDay.year,
      _selectedDay.month,
      _selectedDay.day,
    );
    final dayAssignments = existing.where((a) {
      final key = DateTime(a.workDate.year, a.workDate.month, a.workDate.day);
      return key == selectedKey;
    }).toList();

    // Check duplicate shift_id on the same day
    final isDuplicate = dayAssignments.any((a) => a.shiftId == _selectedShift!.id);
    if (isDuplicate) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '⚠️ ${widget.staff.fullName} đã có ca ${_selectedShift!.name} ngày ${_selectedDay.day}/${_selectedDay.month}!',
            ),
            backgroundColor: AppColors.warning,
            duration: const Duration(seconds: 3),
          ),
        );
      }
      return;
    }

    final assignment = ShiftAssignmentModel(
      id: 0,
      shiftId: _selectedShift!.id,
      userId: widget.staff.id,
      workDate: _selectedDay,
      status: 'scheduled',
      assignedBy: widget.managerId,
      createdAt: DateTime.now(),
    );
    await DatabaseService.instance.insertShiftAssignment(assignment);

    // Auto-refresh local calendar immediately
    setState(() {
      _assignFuture = _fetchAssignments();
      _selectedShift = null; // reset selection
    });

    // Notify parent to refresh staff list too
    widget.onAssigned();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '✅ Đã xếp ca ${assignment.shiftId == 1 ? 'Sáng' : assignment.shiftId == 2 ? 'Chiều' : 'Tối'} cho ${widget.staff.fullName} ngày ${_selectedDay.day}/${_selectedDay.month}',
          ),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      decoration: BoxDecoration(
        color: AppColors.primaryLight.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
      ),
      child: FutureBuilder<List<ShiftAssignmentModel>>(
        future: _assignFuture,
        builder: (context, snap) {
          final assignments = snap.data ?? [];
          final Map<DateTime, List<ShiftAssignmentModel>> scheduleMap = {};
          for (final s in assignments) {
            final key = DateTime(s.workDate.year, s.workDate.month, s.workDate.day);
            scheduleMap[key] = [...(scheduleMap[key] ?? []), s];
          }
          final selectedKey = DateTime(_selectedDay.year, _selectedDay.month, _selectedDay.day);
          final dayAssignments = scheduleMap[selectedKey] ?? [];

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_month_outlined, size: 15, color: AppColors.primary),
                    const SizedBox(width: 6),
                    const Text(
                      'Xếp lịch làm việc',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.primary),
                    ),
                  ],
                ),
              ),
              TableCalendar<ShiftAssignmentModel>(
                firstDay: DateTime.now().subtract(const Duration(days: 7)),
                lastDay: DateTime.now().add(const Duration(days: 30)),
                focusedDay: _focusedDay,
                selectedDayPredicate: (day) => isSameDay(day, _selectedDay),
                eventLoader: (day) {
                  final key = DateTime(day.year, day.month, day.day);
                  return scheduleMap[key] ?? [];
                },
                onDaySelected: (selected, focused) => setState(() {
                  _selectedDay = selected;
                  _focusedDay = focused;
                }),
                calendarStyle: CalendarStyle(
                  todayDecoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.3),
                    shape: BoxShape.circle,
                  ),
                  selectedDecoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                  markerDecoration: const BoxDecoration(
                    color: AppColors.success,
                    shape: BoxShape.circle,
                  ),
                  markerSize: 5,
                  markersMaxCount: 1,
                  outsideDaysVisible: false,
                ),
                headerStyle: const HeaderStyle(
                  formatButtonVisible: false,
                  titleCentered: true,
                  titleTextStyle: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                ),
                calendarFormat: CalendarFormat.month,
                availableCalendarFormats: const {CalendarFormat.month: 'Tháng'},
              ),
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (dayAssignments.isNotEmpty) ...[
                      Text(
                        'Ca hôm ${_selectedDay.day}/${_selectedDay.month}:',
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 6),
                      ...dayAssignments.map(
                        (a) => Container(
                          margin: const EdgeInsets.only(bottom: 4),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.successLight,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.access_time, size: 13, color: AppColors.success),
                              const SizedBox(width: 6),
                              Text(
                                '${a.shiftName ?? ''} (${a.shiftStartTime ?? ''} - ${a.shiftEndTime ?? ''})',
                                style: const TextStyle(fontSize: 12, color: AppColors.success, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                    const Text(
                      'Chọn ca để xếp:',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: widget.shifts.map((shift) {
                        final isSelected = _selectedShift?.id == shift.id;
                        // Already assigned this shift on selected day?
                        final alreadyAssigned = dayAssignments.any((a) => a.shiftId == shift.id);
                        return GestureDetector(
                          onTap: alreadyAssigned
                              ? null
                              : () => setState(() => _selectedShift = isSelected ? null : shift),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                            decoration: BoxDecoration(
                              color: alreadyAssigned
                                  ? AppColors.successLight
                                  : (isSelected ? AppColors.primary : AppColors.surfaceVariant),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: alreadyAssigned
                                    ? AppColors.success.withValues(alpha: 0.5)
                                    : (isSelected ? AppColors.primary : AppColors.border),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (alreadyAssigned)
                                  const Padding(
                                    padding: EdgeInsets.only(right: 4),
                                    child: Icon(Icons.check_circle, size: 12, color: AppColors.success),
                                  ),
                                Text(
                                  '${shift.name} (${shift.startTime}-${shift.endTime})',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: alreadyAssigned
                                        ? AppColors.success
                                        : (isSelected ? Colors.white : AppColors.textPrimary),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _selectedShift != null ? _assignShift : null,
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('Xếp ca'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1A237E),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ─── Helper Widgets ───────────────────────────────────────────────────────────

class _SummaryChip extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  final IconData icon;
  const _SummaryChip({
    required this.label,
    required this.count,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$count',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    color: color,
                  ),
                ),
                Text(
                  label,
                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool active;
  final VoidCallback onTap;

  const _ActionBtn({
    required this.icon,
    required this.label,
    required this.color,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: active ? color.withValues(alpha: 0.15) : AppColors.surfaceVariant,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: active ? color.withValues(alpha: 0.5) : AppColors.border,
            ),
          ),
          child: Column(
            children: [
              Icon(icon, size: 18, color: active ? color : AppColors.textSecondary),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: active ? color : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _MiniStat({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 15,
              color: color,
            ),
          ),
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _PeriodChips extends StatelessWidget {
  final PeriodFilter selected;
  final ValueChanged<PeriodFilter> onChanged;

  const _PeriodChips({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: PeriodFilter.values.map((p) {
        final isSelected = p == selected;
        return GestureDetector(
          onTap: () => onChanged(p),
          child: Container(
            margin: const EdgeInsets.only(left: 4),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: isSelected ? AppColors.info : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: isSelected ? AppColors.info : AppColors.border,
              ),
            ),
            child: Text(
              p.label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : AppColors.textSecondary,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ─── Data Models ──────────────────────────────────────────────────────────────
class _StaffPageData {
  final List<UserModel> staffList;
  final List<WorkShiftModel> shifts;
  final int? storeId;
  _StaffPageData({
    required this.staffList,
    required this.shifts,
    required this.storeId,
  });
}

class _StaffSalesData {
  final List<SalesOrderModel> orders;
  final double revenue;
  _StaffSalesData({required this.orders, required this.revenue});
}
