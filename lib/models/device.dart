class Device {
  final String ip;
  String name;
  bool isOnline;

  Device({
    required this.ip,
    required this.name,
    required this.isOnline,
  });

  // Конструктор из JSON
  factory Device.fromJson(Map<String, dynamic> json) {
    return Device(
      ip: json['ip'],
      name: json['name'],
      isOnline: json['isOnline'],
    );
  }

  // Преобразование в JSON
  Map<String, dynamic> toJson() {
    return {
      'ip': ip,
      'name': name,
      'isOnline': isOnline,
    };
  }
}
