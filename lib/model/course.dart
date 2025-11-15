class Course {
  final int id;
  final String code;
  final String name;
  final String professor;
  final String time;

  Course({
    required this.id,
    required this.code,
    required this.name,
    required this.professor,
    required this.time,
  });

  factory Course.fromJson(Map<String, dynamic> json) {
    return Course(
      id: json["id"],
      code: json["code"],
      name: json["name"],
      professor: json["professor"],
      time: json["time"],
    );
  }
}
