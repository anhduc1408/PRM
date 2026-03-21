import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../core/constants/app_colors.dart';
import '../../core/providers/auth_provider.dart';
import '../../data/database_service.dart';
import '../../models/work_schedule_model.dart';

class WorkScheduleScreen extends StatefulWidget {
  const WorkScheduleScreen({super.key});
  @override
  State<WorkScheduleScreen> createState() => _WorkScheduleScreenState();
}

class _WorkScheduleScreenState extends State<WorkScheduleScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();
  late Future<List<ShiftAssignmentModel>> _schedulesFuture;

  @override
  void initState() {
    super.initState();
    _schedulesFuture = _fetch();
  }

  void _load() {
    final f = _fetch();
    if (mounted) setState(() { _schedulesFuture = f; });
  }

  Future<List<ShiftAssignmentModel>> _fetch() async {
    final userId = context.read<AuthProvider>().currentUser?.id;
    if (userId == null) return [];
    final from = DateTime.now().subtract(const Duration(days: 30));
    final to = DateTime.now().add(const Duration(days: 60));
    return DatabaseService.instance.getShiftAssignments(userId: userId, fromDate: from, toDate: to);
  }

  static const _shiftColors = [AppColors.success, AppColors.warning, AppColors.info];

  String _formatDate(DateTime date) {
    const weekdays = ['Thứ 2', 'Thứ 3', 'Thứ 4', 'Thứ 5', 'Thứ 6', 'Thứ 7', 'Chủ nhật'];
    return '${weekdays[date.weekday - 1]}, ${date.day}/${date.month}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: FutureBuilder<List<ShiftAssignmentModel>>(
        future: _schedulesFuture,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          final allSchedules = snap.data ?? [];

          final Map<DateTime, List<ShiftAssignmentModel>> scheduleMap = {};
          for (final s in allSchedules) {
            final key = DateTime(s.workDate.year, s.workDate.month, s.workDate.day);
            scheduleMap[key] = [...(scheduleMap[key] ?? []), s];
          }

          final selectedKey = DateTime(_selectedDay.year, _selectedDay.month, _selectedDay.day);
          final selectedSchedules = scheduleMap[selectedKey] ?? [];

          return SingleChildScrollView(
            child: Column(children: [
              Container(
                margin: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 12, offset: const Offset(0, 4))],
                ),
                child: TableCalendar<ShiftAssignmentModel>(
                  firstDay: DateTime.now().subtract(const Duration(days: 30)),
                  lastDay: DateTime.now().add(const Duration(days: 60)),
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
                    todayDecoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.3), shape: BoxShape.circle),
                    selectedDecoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                    markerDecoration: const BoxDecoration(color: AppColors.success, shape: BoxShape.circle),
                    markerSize: 6, markersMaxCount: 1,
                  ),
                  headerStyle: const HeaderStyle(
                    formatButtonVisible: false, titleCentered: true,
                    titleTextStyle: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                  calendarFormat: CalendarFormat.month,
                  availableCalendarFormats: const {CalendarFormat.month: 'Tháng'},
                ),
              ),

              Container(
                margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.surface, borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 12, offset: const Offset(0, 4))],
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    const Icon(Icons.calendar_today, size: 16, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Text(_formatDate(_selectedDay), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                    const Spacer(),
                    IconButton(icon: const Icon(Icons.refresh, size: 18, color: AppColors.primary), onPressed: _load, tooltip: 'Làm mới'),
                  ]),
                  const SizedBox(height: 16),
                  if (selectedSchedules.isEmpty)
                    const Center(child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Column(children: [
                        Text('😴', style: TextStyle(fontSize: 32)),
                        SizedBox(height: 8),
                        Text('Không có ca làm ngày này', style: TextStyle(color: AppColors.textHint)),
                      ]),
                    ))
                  else
                    ...selectedSchedules.map<Widget>((s) {
                      final color = _shiftColors[s.shiftId % _shiftColors.length];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: color.withValues(alpha: 0.3)),
                        ),
                        child: Row(children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(color: color.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8)),
                            child: Icon(Icons.access_time, size: 18, color: color),
                          ),
                          const SizedBox(width: 12),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(s.shiftName ?? 'Ca làm', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: color)),
                            if (s.shiftStartTime != null && s.shiftEndTime != null)
                              Text('${s.shiftStartTime} - ${s.shiftEndTime}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                          ])),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(color: AppColors.successLight, borderRadius: BorderRadius.circular(6)),
                            child: Text(
                              s.status == 'completed' ? 'Đã làm' : (s.status == 'scheduled' ? 'Đã xếp' : s.status),
                              style: const TextStyle(color: AppColors.success, fontSize: 11, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ]),
                      );
                    }),
                ]),
              ),
            ]),
          );
        },
      ),
    );
  }
}
