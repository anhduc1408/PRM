import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/enums.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/utils/format_utils.dart';
import '../../data/database_service.dart';
import '../../models/user_model.dart';
import '../../models/work_schedule_model.dart';

class ManagerStaffScreen extends StatefulWidget {
  const ManagerStaffScreen({super.key});
  @override
  State<ManagerStaffScreen> createState() => _ManagerStaffScreenState();
}

class _ManagerStaffScreenState extends State<ManagerStaffScreen> {
  late Future<_StaffPageData> _dataFuture;
  _StaffPageData? _cachedData;
  late DateTime _startDate;
  late DateTime _endDate;
  late DateTime _selectedListDate;
  int _viewMode = 0; // 0: Schedule View, 1: List View

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _startDate = DateTime(now.year, now.month, now.day).subtract(Duration(days: now.weekday - 1));
    _endDate = _startDate.add(const Duration(days: 6));
    _selectedListDate = DateTime(now.year, now.month, now.day);
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
    
    final Map<int, Map<String, List<ShiftAssignmentModel>>> assignmentMap = {};
    for (var staff in staffOnly) {
      // Get assignments for BOTH schedule view range AND selected list date
      final assignments = await DatabaseService.instance.getShiftAssignments(
        userId: staff.id,
        fromDate: _startDate.isBefore(_selectedListDate) ? _startDate : _selectedListDate,
        toDate: _endDate.isAfter(_selectedListDate) ? _endDate : _selectedListDate,
      );
      final staffMap = <String, List<ShiftAssignmentModel>>{};
      for (var a in assignments) {
        final key = '${a.workDate.year}-${a.workDate.month}-${a.workDate.day}';
        staffMap[key] = (staffMap[key] ?? [])..add(a);
      }
      assignmentMap[staff.id] = staffMap;
    }

    final result = _StaffPageData(
      staffList: staffOnly,
      shifts: shifts,
      storeId: storeId,
      assignmentMap: assignmentMap,
    );
    if (mounted) setState(() => _cachedData = result);
    return result;
  }

  Future<void> _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (ctx, child) => Theme(
        data: ThemeData(colorSchemeSeed: AppColors.primary),
        child: child!,
      ),
    );
    
    if (picked != null) {
      setState(() {
         // Limit to 14 days max to avoid overflowing UI columns
         final diff = picked.end.difference(picked.start).inDays;
         _startDate = picked.start;
         if (diff > 14) {
             _endDate = picked.start.add(const Duration(days: 14));
             if(mounted) {
                 ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Chỉ hiển thị tối đa 14 ngày trên bảng để đảm bảo hiệu năng UI.')));
             }
         } else {
             _endDate = picked.end;
         }
      });
      _load();
    }
  }

  Future<void> _assignShift(UserModel staff, DateTime date, List<WorkShiftModel> shifts, List<ShiftAssignmentModel> currentAssignments) async {
    final curUser = context.read<AuthProvider>().currentUser;
    if (curUser == null) return;
    
    final initiallySelected = currentAssignments.map((a) => a.shiftId).toSet();
    final selectedShiftIds = Set<int>.from(initiallySelected);

    final bool? saved = await showDialog<bool>(context: context, builder: (ctx) {
      return StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Text('Xếp ca cho ${staff.fullName}\nNgày ${FormatUtils.formatDate(date)}'),
            content: SizedBox(
              width: 320,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: shifts.map((s) {
                  final isSelected = selectedShiftIds.contains(s.id);
                  return CheckboxListTile(
                    title: Text(s.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('${s.startTime.substring(0,5)} - ${s.endTime.substring(0,5)}'),
                    value: isSelected,
                    activeColor: AppColors.primary,
                    controlAffinity: ListTileControlAffinity.leading,
                    onChanged: (val) {
                      setDialogState(() {
                        if (val == true) {
                          selectedShiftIds.add(s.id);
                        } else {
                          selectedShiftIds.remove(s.id);
                        }
                      });
                    },
                  );
                }).toList(),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true), 
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
                child: const Text('Lưu ca làm')
              ),
            ],
          );
        }
      );
    });

    if (saved == true) {
      // Find what to delete
      final toDelete = currentAssignments.where((a) => !selectedShiftIds.contains(a.shiftId)).toList();
      for (var a in toDelete) {
        await DatabaseService.instance.deleteShiftAssignment(a.id);
      }
      
      // Find what to add
      final toAddIds = selectedShiftIds.where((id) => !initiallySelected.contains(id)).toList();
      for (var id in toAddIds) {
        final assignment = ShiftAssignmentModel(
          id: 0,
          shiftId: id,
          userId: staff.id,
          workDate: date,
          status: 'scheduled',
          assignedBy: curUser.id,
          createdAt: DateTime.now(),
        );
        await DatabaseService.instance.insertShiftAssignment(assignment);
      }
            _load();
      if (mounted) {
        final curUser = context.read<AuthProvider>().currentUser;
        await DatabaseService.instance.insertNotification(
          type: 'system',
          title: 'Cập nhật lịch làm',
          content: '${curUser?.fullName ?? "Quản lý"} đã cập nhật lịch làm ngày ${FormatUtils.formatDate(date)} cho ${staff.fullName}.',
          targetUserId: staff.id,
          storeId: staff.storeId,
        );
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Đã cập nhật ca thành công cho ${staff.fullName}'), backgroundColor: AppColors.success));
      }
    }
  }

  Future<void> _markAbsentWithModal(UserModel staff, DateTime date, List<WorkShiftModel> shifts, List<ShiftAssignmentModel> assignments) async {
    if (assignments.isEmpty) {
       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nhân viên không có ca làm vào ngày này.')));
       return;
    }

    final curUser = context.read<AuthProvider>().currentUser;
    if (curUser == null) return;

    List<int> toMarkIds = [];

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Text('Chọn ca nghỉ - ${staff.fullName}'),
            content: SizedBox(
               width: 400,
               child: Column(
                 mainAxisSize: MainAxisSize.min,
                 children: assignments.map((a) {
                    final shift = shifts.firstWhere((s) => s.id == a.shiftId, orElse: () => WorkShiftModel(id:0, name:'Unk', startTime:'', endTime:'', status:'', createdAt: DateTime.now(), updatedAt: DateTime.now()));
                    final isMarked = toMarkIds.contains(a.id);
                    return CheckboxListTile(
                       title: Text(shift.name),
                       subtitle: Text('${shift.startTime} - ${shift.endTime}'),
                       value: isMarked,
                       onChanged: (v) {
                          setDialogState(() {
                             if (v == true) toMarkIds.add(a.id);
                             else toMarkIds.remove(a.id);
                          });
                       },
                    );
                 }).toList(),
               ),
            ),
            actions: [
               TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Huỷ')),
               ElevatedButton(
                 onPressed: toMarkIds.isEmpty ? null : () async {
                    for (var id in toMarkIds) {
                       await DatabaseService.instance.updateShiftAssignmentStatus(id, 'absent');
                    }
                    Navigator.pop(ctx);
                 }, 
                 child: const Text('Xác nhận nghỉ')
               ),
            ],
          );
        }
      )
    );

    if (toMarkIds.isNotEmpty) {
       await DatabaseService.instance.insertNotification(
          type: 'system',
          title: 'Báo nghỉ ca làm',
          content: 'Quản lý ${curUser.fullName} đã đánh dấu nghỉ ${toMarkIds.length} ca cho ${staff.fullName} vào ngày ${FormatUtils.formatDate(date)}.',
          targetUserId: staff.id,
          storeId: staff.storeId,
       );
       _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: FutureBuilder<_StaffPageData>(
        future: _dataFuture,
        builder: (context, snap) {
          final data = snap.data ?? _cachedData;
          if (data == null) {
            if (snap.hasError) return Center(child: Text('Lỗi: ${snap.error}'));
            return const Center(child: CircularProgressIndicator());
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (snap.connectionState == ConnectionState.waiting) const LinearProgressIndicator(minHeight: 2, backgroundColor: Colors.transparent),
              Container(
                padding: const EdgeInsets.all(24),
                color: Colors.white,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Nhân viên & Lịch làm', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                    SegmentedButton<int>(
                      segments: const [
                        ButtonSegment(value: 0, label: Text('Lịch làm việc bao quát'), icon: Icon(Icons.calendar_month)),
                        ButtonSegment(value: 1, label: Text('Danh sách NV'), icon: Icon(Icons.people)),
                      ],
                      selected: {_viewMode},
                      onSelectionChanged: (val) => setState(() => _viewMode = val.first),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _viewMode == 0 
                  ? _buildScheduleView(data)
                  : _buildListView(data),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildScheduleView(_StaffPageData data) {
    return Card(
      margin: const EdgeInsets.all(24),
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Lịch làm việc bao quát', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                InkWell(
                  onTap: _pickDateRange,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.border),
                      borderRadius: BorderRadius.circular(8),
                      color: Colors.white,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.calendar_today, size: 18, color: AppColors.textSecondary),
                        const SizedBox(width: 8),
                        Text(
                          '${FormatUtils.formatDate(_startDate)} - ${FormatUtils.formatDate(_endDate)}',
                          style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.arrow_drop_down, color: AppColors.textSecondary),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          if (data.staffList.isEmpty)
            const Expanded(child: Center(child: Text('Không có nhân viên nào trong cửa hàng.')))
          else
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SingleChildScrollView(
                  child: DataTable(
                    dataRowMinHeight: 60,
                    dataRowMaxHeight: double.infinity,
                    headingRowColor: WidgetStateProperty.all(Colors.grey[100]),
                    columns: [
                      const DataColumn(label: Text('Nhân viên', style: TextStyle(fontWeight: FontWeight.bold))),
                      ...List.generate(_endDate.difference(_startDate).inDays + 1, (i) {
                        final day = _startDate.add(Duration(days: i));
                        final wd = ['T2','T3','T4','T5','T6','T7','CN'][day.weekday-1];
                        return DataColumn(label: Text('$wd\n${day.day}/${day.month}', textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold)));
                      }),
                    ],
                    rows: data.staffList.map((staff) {
                      final daysCount = _endDate.difference(_startDate).inDays + 1;
                      return DataRow(
                        cells: [
                          DataCell(
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                CircleAvatar(
                                  radius: 14,
                                  backgroundColor: AppColors.primary,
                                  child: Text(staff.fullName[0].toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 12)),
                                ),
                                const SizedBox(width: 8),
                                Text(staff.fullName, style: const TextStyle(fontWeight: FontWeight.bold)),
                              ],
                            )
                          ),
                          ...List.generate(daysCount, (i) {
                            final day = _startDate.add(Duration(days: i));
                            final key = '${day.year}-${day.month}-${day.day}';
                            final matches = data.assignmentMap[staff.id]?[key] ?? [];
                            
                            return DataCell(
                              Container(
                                constraints: const BoxConstraints(minWidth: 80, minHeight: 60),
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                child: InkWell(
                                  onTap: () => _assignShift(staff, day, data.shifts, matches),
                                  child: matches.isNotEmpty
                                     ? Wrap(
                                          spacing: 4,
                                          runSpacing: 4,
                                          children: matches.map((match) {
                                              final shiftModel = data.shifts.firstWhere((s) => s.id == match.shiftId, orElse: () => WorkShiftModel(id: 0, name: 'Unk', startTime: '', endTime: '', status: '', createdAt: DateTime.now(), updatedAt: DateTime.now()));
                                              return Container(
                                                 padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                                 decoration: BoxDecoration(color: AppColors.primary.withAlpha(20), borderRadius: BorderRadius.circular(4), border: Border.all(color: AppColors.primary.withAlpha(50))),
                                                 child: Text(shiftModel.name, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary)),
                                              );
                                          }).toList()
                                       )
                                     : const Center(
                                         child: Icon(Icons.add_circle_outline, color: Colors.grey, size: 24),
                                       )
                                ),
                              )
                            );
                          }),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildListView(_StaffPageData data) {
    return Card(
      margin: const EdgeInsets.all(24),
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
               mainAxisAlignment: MainAxisAlignment.spaceBetween,
               children: [
                   const Text('Danh sách nhân viên', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                   Row(
                      children: [
                         const Text('Ngày xem: ', style: TextStyle(color: AppColors.textSecondary)),
                         const SizedBox(width: 8),
                         OutlinedButton.icon(
                            icon: const Icon(Icons.calendar_today, size: 16),
                            label: Text(FormatUtils.formatDate(_selectedListDate)),
                            onPressed: () async {
                               final date = await showDatePicker(
                                  context: context, 
                                  initialDate: _selectedListDate, 
                                  firstDate: DateTime(2020), 
                                  lastDate: DateTime.now().add(const Duration(days: 365))
                               );
                               if (date != null) {
                                  setState(() => _selectedListDate = date);
                                  _load();
                               }
                            },
                         )
                      ],
                   )
               ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: ConstrainedBox(
                   constraints: BoxConstraints(minWidth: constraints.maxWidth),
                   child: SingleChildScrollView(
                    child: DataTable(
                      headingRowColor: WidgetStateProperty.all(Colors.grey[50]),
                      showCheckboxColumn: false,
                      columns: const [
                        DataColumn(label: Text('Nhân viên', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('SĐT / Email', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Ca làm', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Trạng thái', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Tùy chọn', style: TextStyle(fontWeight: FontWeight.bold))),
                      ],
                      rows: data.staffList.map((staff) {
                        final isActive = staff.status == 'active';
                        final key = '${_selectedListDate.year}-${_selectedListDate.month}-${_selectedListDate.day}';
                        final assignments = data.assignmentMap[staff.id]?[key] ?? [];

                        return DataRow(
                          cells: [
                            DataCell(
                               Row(
                                 children: [
                                   CircleAvatar(
                                     backgroundColor: AppColors.primary,
                                     child: Text(staff.fullName[0].toUpperCase(), style: const TextStyle(color: Colors.white)),
                                   ),
                                   const SizedBox(width: 12),
                                   Text(staff.fullName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                 ],
                               )
                            ),
                            DataCell(Text(staff.phone ?? staff.email ?? staff.username)),
                            DataCell(
                               assignments.isEmpty 
                               ? const Text('Trống', style: TextStyle(color: AppColors.textHint))
                               : Wrap(
                                   spacing: 4,
                                   children: assignments.map((a) {
                                      final s = data.shifts.firstWhere((sh) => sh.id == a.shiftId, orElse: () => WorkShiftModel(id:0, name:'Unk', startTime:'', endTime:'', status:'', createdAt: DateTime.now(), updatedAt: DateTime.now()));
                                      final isAbsent = a.status == 'absent';
                                      return Container(
                                         padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                         decoration: BoxDecoration(
                                            color: isAbsent ? AppColors.errorLight : AppColors.primaryLight,
                                            borderRadius: BorderRadius.circular(4),
                                            border: Border.all(color: isAbsent ? AppColors.error : AppColors.primary, width: 0.5)
                                         ),
                                         child: Text(s.name, style: TextStyle(fontSize: 10, color: isAbsent ? AppColors.error : AppColors.primary, fontWeight: FontWeight.bold)),
                                      );
                                   }).toList()
                               )
                            ),
                            DataCell(
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: isActive ? AppColors.successLight : AppColors.warningLight,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(isActive ? 'Đang làm' : 'Nghỉ phép', style: TextStyle(fontSize: 12, color: isActive ? AppColors.success : AppColors.warning, fontWeight: FontWeight.bold)),
                              ),
                            ),
                            DataCell(
                              Row(
                                children: [
                                  OutlinedButton.icon(
                                    icon: Icon(isActive ? Icons.event_busy : Icons.play_arrow, size: 16),
                                    label: Text(isActive ? 'Đánh dấu nghỉ' : 'Kích hoạt', style: TextStyle(color: isActive ? AppColors.error : AppColors.success)),
                                    onPressed: () async {
                                      if (isActive) {
                                         // Show modal to pick shifts
                                         _markAbsentWithModal(staff, _selectedListDate, data.shifts, assignments);
                                      } else {
                                         final updated = staff.copyWith(status: 'active');
                                         await DatabaseService.instance.updateUser(updated);
                                         await DatabaseService.instance.insertNotification(
                                            type: 'system',
                                            title: 'Kích hoạt tài khoản',
                                            content: 'Quản lý đã kích hoạt lại tài khoản cho ${staff.fullName}.',
                                            targetUserId: staff.id,
                                            storeId: staff.storeId,
                                         );
                                         _load();
                                      }
                                    },
                                  ),
                                  const SizedBox(width: 8),
                                  OutlinedButton.icon(
                                    icon: const Icon(Icons.password, size: 16),
                                    label: const Text('Reset MK'),
                                    onPressed: () async {
                                      await DatabaseService.instance.resetPassword(staff.id);
                                      if (mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('MK đã reset về 123456')));
                                      }
                                    },
                                  )
                                ],
                              )
                            ),
                          ]
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StaffPageData {
  final List<UserModel> staffList;
  final List<WorkShiftModel> shifts;
  final int? storeId;
  final Map<int, Map<String, List<ShiftAssignmentModel>>> assignmentMap;

  _StaffPageData({
    required this.staffList,
    required this.shifts,
    required this.storeId,
    required this.assignmentMap,
  });
}
