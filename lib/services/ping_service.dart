import 'dart:async';
import 'dart:io';
import '../providers/device_provider.dart';

class PingService {
  final DeviceProvider provider;
  Timer? _timer;

  PingService(this.provider);

  void startMonitoring() {
    _timer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => _checkDevices(),
    );
  }

  void stopMonitoring() {
    _timer?.cancel();
  }

  Future<bool> _pingIp(String ip) async {
    try {
      if (Platform.isWindows) {
        final result = await Process.run('ping', ['-n', '1', '-w', '1000', ip]);
        return result.exitCode == 0;
      } else {
        final result = await Process.run('ping', ['-c', '1', '-W', '1', ip]);
        return result.exitCode == 0;
      }
    } catch (_) {
      return false;
    }
  }

  Future<void> _checkDevices() async {
    for (final device in provider.devices) {
      final status = await _pingIp(device.ip);
      // Вызываем метод обновления статуса через провайдер
      provider.updateDeviceStatus(device.ip, status);
    }
  }
}
