import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/enums.dart';
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
  late Future<List<WorkScheduleModel>> _schedulesFuture;

  @override
  void initState() {
    super.initState();
    // Assign directly — no setState in initState
    final staffId = context.read<AuthProvider>().currentUser?.id ?? '';
    _schedulesFuture = DatabaseService.instance.getSchedulesForStaff(staffId);
  }

  void _load() {
    final staffId = context.read<AuthProvider>().currentUser?.id ?? '';
    final f = DatabaseService.instance.getSchedulesForStaff(staffId);
    if (mounted) setState(() => _schedulesFuture = f);
  }

  static const shiftColors = {
    ShiftType.morning:   AppColors.success,
    ShiftType.afternoon: AppColors.warning,
    ShiftType.evening:   AppColors.info,
  };

  String _formatDate(DateTime date) {
    const weekdays = ['Thứ 2', 'Thứ 3', 'Thứ 4', 'Thứ 5', 'Thứ 6', 'Thứ 7', 'Chủ nhật'];
    return '${weekdays[date.weekday - 1]}, ${date.day}/${date.month}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: FutureBuilder<List<WorkScheduleModel>>(
        future: _schedulesFuture,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          final allSchedules = snap.data ?? [];

          final Map<DateTime, List<WorkScheduleModel>> scheduleMap = {};
          for (final s in allSchedules) {
            final key = DateTime(s.date.year, s.date.month, s.date.day);
            scheduleMap[key] = [...(scheduleMap[key] ?? []), s];
          }

          final selectedKey = DateTime(_selectedDay.year, _selectedDay.month, _selectedDay.day);
          final selectedSchedules = scheduleMap[selectedKey] ?? [];

          return SingleChildScrollView(
            child: Column(
              children: [
                Container(
                  margin: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 12, offset: const Offset(0, 4))],
                  ),
                  child: TableCalendar<WorkScheduleModel>(
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
                      markerSize: 6,
                      markersMaxCount: 1,
                    ),
                    headerStyle: const HeaderStyle(
                      formatButtonVisible: false, titleCentered: true,
                      titleTextStyle: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                    ),
                    calendarFormat: CalendarFormat.month,
                    availableCalendarFormats: const {CalendarFormat.month: 'Tháng'},
                  ),
                ),

                // Shift type legend
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: ShiftType.values.map((s) {
                      final color = shiftColors[s] ?? AppColors.textSecondary;
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Row(children: [
                          Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                          const SizedBox(width: 4),
                          Text(s.shortLabel, style: const TextStyle(fontSize: 12)),
                        ]),
                      );
                    }).toList(),
                  ),
                ),

                const SizedBox(height: 8),

                // Selected day card
                Container(
                  margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.surface, borderRadius: BorderRadius.circular(16),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 12, offset: const Offset(0, 4))],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        const Icon(Icons.calendar_today, size: 16, color: AppColors.primary),
                        const SizedBox(width: 8),
                        Text(_formatDate(_selectedDay), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
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
                          final color = shiftColors[s.shift] ?? AppColors.textSecondary;
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
                                Text(s.shift.label, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: color)),
                                Text(s.staffName, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                              ])),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(color: AppColors.successLight, borderRadius: BorderRadius.circular(6)),
                                child: const Text('Đã xếp', style: TextStyle(color: AppColors.success, fontSize: 11, fontWeight: FontWeight.w600)),
                              ),
                            ]),
                          );
                        }),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
