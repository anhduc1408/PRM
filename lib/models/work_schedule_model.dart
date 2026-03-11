import 'package:mixue_manager/core/constants/enums.dart';

class WorkScheduleModel {
  final String id;
  final String staffId;
  final String staffName;
  final String storeId;
  final DateTime date;
  final ShiftType shift;
  final bool isConfirmed;

  const WorkScheduleModel({
    required this.id,
    required this.staffId,
    required this.staffName,
    required this.storeId,
    required this.date,
    required this.shift,
    this.isConfirmed = true,
  });
}
