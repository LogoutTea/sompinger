import 'package:flutter/foundation.dart';
import '../models/device.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/device_status.dart';

class DeviceProvider with ChangeNotifier {
  final List<Device> _devices = [];
  bool _isScanning = false;
  static const String _storageKey = 'devices';

  List<Device> get devices => _devices;
  bool get isScanning => _isScanning;

  DeviceProvider() {
    _loadDevices();
  }

  Future<void> _loadDevices() async {
    final prefs = await SharedPreferences.getInstance();
    final String? devicesJson = prefs.getString(_storageKey);
    
    if (devicesJson != null) {
      try {
        final List<dynamic> decoded = jsonDecode(devicesJson);
        _devices.clear();
        _devices.addAll(
          decoded.map((json) => Device.fromJson(json)).toList()
        );
        notifyListeners();
      } catch (e) {
        if (kDebugMode) {
          print("Ошибка загрузки устройств: $e");
        }
      }
    }
  }

  Future<void> _saveDevices() async {
    final prefs = await SharedPreferences.getInstance();
    final String devicesJson = jsonEncode(
      _devices.map((d) => d.toJson()).toList()
    );
    await prefs.setString(_storageKey, devicesJson);
  }

  void addDevice(Device device) {
    final existing = _devices.indexWhere((d) => d.ip == device.ip);
    if (existing != -1) {
      _devices[existing] = device;
    } else {
      _devices.add(device);
    }
    notifyListeners();
    _saveDevices();
  }

  void updateDeviceStatus(String ip, bool status) {
    final index = _devices.indexWhere((d) => d.ip == ip);
    if (index != -1) {
      _devices[index].isOnline = status;
      notifyListeners();
      _saveDevices();
    }
  }

  void startScan() {
    _isScanning = true;
    notifyListeners();
  }

  void stopScan() {
    _isScanning = false;
    notifyListeners();
  }

  void removeDevice(String ip) {
    _devices.removeWhere((d) => d.ip == ip);
    notifyListeners();
    _saveDevices();
  }

  void updateDevice(String oldIp, Device newDevice) {
    final index = _devices.indexWhere((d) => d.ip == oldIp);
    if (index != -1) {
      _devices[index] = newDevice;
      notifyListeners();
      _saveDevices();
    }
  }
  
  // Новый метод для получения количества устройств по статусу
  int getDeviceCountByStatus(bool isOnline) {
    return _devices.where((d) => d.isOnline == isOnline).length;
  }
  
  // Метод для получения количества проверяемых устройств
  int getCheckingCount(List<DeviceStatus> statuses) {
    // Этот метод требует внешних данных, поэтому оставим его в UI
    return 0;
  }
}
