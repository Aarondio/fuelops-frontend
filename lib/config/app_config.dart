class Shift {
  final String name;
  final int startHour;
  final int endHour;

  const Shift(this.name, this.startHour, this.endHour);
}

class AppConfig {
  static const List<Shift> shifts = [
    Shift('Morning', 6, 14),
    Shift('Afternoon', 14, 22),
    Shift('Night', 22, 6),
  ];

  static Shift getCurrentShift() {
    final now = DateTime.now();
    final hour = now.hour;

    for (final shift in shifts) {
      if (shift.startHour <= shift.endHour) {
        if (hour >= shift.startHour && hour < shift.endHour) {
          return shift;
        }
      } else { // Overnight shift
        if (hour >= shift.startHour || hour < shift.endHour) {
          return shift;
        }
      }
    }
    return shifts.first;
  }
}
