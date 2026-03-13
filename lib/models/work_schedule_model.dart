class WorkShiftModel {
  final int id;
  final String name;
  final String startTime; // 'HH:mm'
  final String endTime;   // 'HH:mm'
  final String status; // 'active' | 'inactive'
  final DateTime createdAt;
  final DateTime updatedAt;

  const WorkShiftModel({
    required this.id,
    required this.name,
    required this.startTime,
    required this.endTime,
    this.status = 'active',
    required this.createdAt,
    required this.updatedAt,
  });
}

class ShiftAssignmentModel {
  final int id;
  final int shiftId;
  final int userId;
  final DateTime workDate;
  final String status; // 'scheduled' | 'confirmed' | 'absent' | 'completed'
  final int assignedBy;
  final DateTime createdAt;

  // For display
  final String? shiftName;
  final String? shiftStartTime;
  final String? shiftEndTime;
  final String? userName;
  final String? assignedByName;

  const ShiftAssignmentModel({
    required this.id,
    required this.shiftId,
    required this.userId,
    required this.workDate,
    this.status = 'scheduled',
    required this.assignedBy,
    required this.createdAt,
    this.shiftName,
    this.shiftStartTime,
    this.shiftEndTime,
    this.userName,
    this.assignedByName,
  });
}
