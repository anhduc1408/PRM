import 'package:flutter/material.dart';
import '../core/constants/app_colors.dart';
import '../core/utils/format_utils.dart';

/// Widget bộ lọc theo khoảng ngày. Hiển thị 2 ô ngày (Từ / Đến) và
/// một nút "Áp dụng". Khi người dùng xác nhận, [onChanged] sẽ được gọi.
class DateRangeFilterBar extends StatefulWidget {
  final DateTime? initialFrom;
  final DateTime? initialTo;
  final ValueChanged<DateTimeRange> onChanged;

  const DateRangeFilterBar({
    super.key,
    this.initialFrom,
    this.initialTo,
    required this.onChanged,
  });

  @override
  State<DateRangeFilterBar> createState() => _DateRangeFilterBarState();
}

class _DateRangeFilterBarState extends State<DateRangeFilterBar> {
  late DateTime _from;
  late DateTime _to;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _from = widget.initialFrom ?? DateTime(now.year, now.month, 1);
    _to = widget.initialTo ?? now;
  }

  Future<void> _pickFrom() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _from,
      firstDate: DateTime(2020),
      lastDate: _to,
      locale: const Locale('vi'),
      builder: (context, child) => _calendarTheme(context, child),
    );
    if (picked != null) {
      setState(() => _from = picked);
      _notify();
    }
  }

  Future<void> _pickTo() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _to,
      firstDate: _from,
      lastDate: DateTime.now(),
      locale: const Locale('vi'),
      builder: (context, child) => _calendarTheme(context, child),
    );
    if (picked != null) {
      setState(() => _to = picked);
      _notify();
    }
  }

  void _notify() {
    // End of the "to" day
    final toEnd = DateTime(_to.year, _to.month, _to.day, 23, 59, 59);
    widget.onChanged(DateTimeRange(start: _from, end: toEnd));
  }

  Widget _calendarTheme(BuildContext context, Widget? child) {
    return Theme(
      data: Theme.of(context).copyWith(
        colorScheme: const ColorScheme.light(
          primary: AppColors.primary,
          onPrimary: Colors.white,
          surface: AppColors.surface,
        ),
      ),
      child: child!,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.date_range, size: 16, color: AppColors.primary),
          const SizedBox(width: 8),
          _DateChip(label: 'Từ', date: _from, onTap: _pickFrom),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: const Text('→', style: TextStyle(color: AppColors.textHint, fontSize: 14)),
          ),
          _DateChip(label: 'Đến', date: _to, onTap: _pickTo),
        ],
      ),
    );
  }
}

class _DateChip extends StatelessWidget {
  final String label;
  final DateTime date;
  final VoidCallback onTap;

  const _DateChip({required this.label, required this.date, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: AppColors.primaryLight.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 10,
                color: AppColors.textHint,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              FormatUtils.formatDate(date),
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
