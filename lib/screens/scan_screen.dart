import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/device_provider.dart';
import '../models/device.dart';

enum DeviceStatus { online, offline, checking }

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> with SingleTickerProviderStateMixin {
  final _ipController = TextEditingController();
  final _nameController = TextEditingController();

  final Map<String, DateTime> _lastChecked = {};
  final Map<String, int> _lastPing = {};
  final Map<String, DeviceStatus> _statuses = {};
  final Map<String, DeviceStatus> _lastResultStatus = {};

  Timer? _autoCheckTimer;
  late final AnimationController _gradientController;

  final Map<String, bool> _hovered = {};

  @override
  void initState() {
    super.initState();
    _gradientController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
    _startAutoCheck();
  }

  void _startAutoCheck() {
    _autoCheckTimer?.cancel();
    _autoCheckTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      final provider = Provider.of<DeviceProvider>(context, listen: false);
      final now = DateTime.now();
      for (final device in provider.devices) {
        final status = _statuses[device.ip] ?? (device.isOnline ? DeviceStatus.online : DeviceStatus.offline);
        final last = _lastChecked[device.ip];
        final durationSinceLast = last == null ? Duration(days: 1) : now.difference(last);

        if (status == DeviceStatus.online && durationSinceLast.inSeconds >= 5) {
          await _pollDevice(device, provider, now, timeoutSeconds: 1);
        } else if (status == DeviceStatus.offline && durationSinceLast.inSeconds >= 10) {
          await _pollDevice(device, provider, now, timeoutSeconds: 10);
        }
      }
    });
  }

  Future<void> _pollDevice(Device device, DeviceProvider provider, DateTime now, {int timeoutSeconds = 1}) async {
    setState(() {
      _statuses[device.ip] = DeviceStatus.checking;
    });
    final stopwatch = Stopwatch()..start();
    final isOnline = await _pingIp(device.ip, timeoutSeconds: timeoutSeconds);
    stopwatch.stop();
    provider.updateDevice(device.ip, Device(
      ip: device.ip,
      name: device.name,
      isOnline: isOnline,
    ));
    setState(() {
      _statuses[device.ip] = isOnline ? DeviceStatus.online : DeviceStatus.offline;
      _lastChecked[device.ip] = now;
      _lastPing[device.ip] = stopwatch.elapsedMilliseconds;
      _lastResultStatus[device.ip] = isOnline ? DeviceStatus.online : DeviceStatus.offline;
    });
  }

  @override
  void dispose() {
    _autoCheckTimer?.cancel();
    _gradientController.dispose();
    super.dispose();
  }

  Future<void> _addDeviceDialog({Device? device}) async {
    final provider = Provider.of<DeviceProvider>(context, listen: false);
    _ipController.text = device?.ip ?? '';
    _nameController.text = device?.name ?? '';

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF23232b),
        title: Text(device == null ? 'Добавить IP-адрес' : 'Редактировать устройство', style: const TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _ipController,
              decoration: const InputDecoration(
                labelText: 'IP-адрес',
                hintText: 'например, 192.168.1.100',
                labelStyle: TextStyle(color: Colors.white70),
                hintStyle: TextStyle(color: Colors.white38),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.blue)),
              ),
              style: const TextStyle(color: Colors.white),
              keyboardType: TextInputType.number,
              enabled: device == null,
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Имя устройства',
                hintText: 'например, Сервер',
                labelStyle: TextStyle(color: Colors.white70),
                hintStyle: TextStyle(color: Colors.white38),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.blue)),
              ),
              style: const TextStyle(color: Colors.white),
            ),
          ],
        ),
        actions: [
          if (device != null)
            TextButton(
              onPressed: () {
                provider.removeDevice(device.ip);
                Navigator.of(ctx).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Устройство ${device.name} удалено')),
                );
              },
              child: const Text(
                'Удалить',
                style: TextStyle(color: Colors.red),
              ),
            ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Отмена', style: TextStyle(color: Colors.white70)),
          ),
          TextButton(
            onPressed: () async {
              final ip = _ipController.text.trim();
              final name = _nameController.text.trim().isEmpty ? ip : _nameController.text.trim();
              if (ip.isEmpty) return;
              Navigator.of(ctx).pop();

              final stopwatch = Stopwatch()..start();
              final isOnline = await _pingIp(ip, timeoutSeconds: 1);
              stopwatch.stop();

              if (device == null) {
                provider.addDevice(Device(ip: ip, name: name, isOnline: isOnline));
              } else {
                provider.updateDevice(device.ip, Device(ip: ip, name: name, isOnline: isOnline));
              }

              setState(() {
                _statuses[ip] = isOnline ? DeviceStatus.online : DeviceStatus.offline;
                _lastChecked[ip] = DateTime.now();
                _lastPing[ip] = stopwatch.elapsedMilliseconds;
                _lastResultStatus[ip] = isOnline ? DeviceStatus.online : DeviceStatus.offline;
              });
            },
            child: Text(device == null ? 'Добавить' : 'Сохранить', style: const TextStyle(color: Colors.blue)),
          ),
        ],
      ),
    );
  }

  Future<bool> _pingIp(String ip, {int timeoutSeconds = 1}) async {
    try {
      if (Platform.isWindows) {
        final result = await Process.run(
          'ping',
          ['-n', '1', '-w', '${timeoutSeconds * 1000}', ip],
        );
        return result.exitCode == 0;
      } else {
        final result = await Process.run(
          'ping',
          ['-c', '1', '-W', '$timeoutSeconds', ip],
        );
        return result.exitCode == 0;
      }
    } catch (_) {
      return false;
    }
  }

  int _compareIp(String ipA, String ipB) {
    List<int> a = ipA.split('.').map(int.parse).toList();
    List<int> b = ipB.split('.').map(int.parse).toList();
    for (int i = 0; i < 4; i++) {
      if (a[i] != b[i]) return a[i].compareTo(b[i]);
    }
    return 0;
  }

  String _formatTime(DateTime? dt) {
    if (dt == null) return '--:--:--';
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}';
  }

  Color _statusColor(DeviceStatus status) {
    switch (status) {
      case DeviceStatus.online:
        return Colors.green;
      case DeviceStatus.offline:
        return Colors.red;
      case DeviceStatus.checking:
        return Colors.orange;
    }
  }

  String _statusText(DeviceStatus status) {
    switch (status) {
      case DeviceStatus.online:
        return 'ОНЛАЙН';
      case DeviceStatus.offline:
        return 'ОФЛАЙН';
      case DeviceStatus.checking:
        return 'ПРОВЕРКА';
    }
  }

  LinearGradient _statusGradient(DeviceStatus status, double shift) {
    switch (status) {
      case DeviceStatus.online:
        return LinearGradient(
          colors: [
            Colors.green,
            Colors.lightGreenAccent,
            Colors.greenAccent,
            Colors.green,
          ],
          stops: [
            shift,
            (shift + 0.3) % 1.0,
            (shift + 0.6) % 1.0,
            (shift + 0.9) % 1.0,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          tileMode: TileMode.mirror,
        );
      case DeviceStatus.offline:
        return LinearGradient(
          colors: [
            Colors.red,
            Colors.redAccent,
            Colors.deepOrange,
            Colors.red,
          ],
          stops: [
            shift,
            (shift + 0.3) % 1.0,
            (shift + 0.6) % 1.0,
            (shift + 0.9) % 1.0,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          tileMode: TileMode.mirror,
        );
      case DeviceStatus.checking:
        return LinearGradient(
          colors: [
            Colors.yellow,
            Colors.amber,
            Colors.orangeAccent,
            Colors.yellow,
          ],
          stops: [
            shift,
            (shift + 0.3) % 1.0,
            (shift + 0.6) % 1.0,
            (shift + 0.9) % 1.0,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          tileMode: TileMode.mirror,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeData.dark().copyWith(
      scaffoldBackgroundColor: const Color(0xFF181820),
      cardColor: const Color(0xFF23232b),
      textTheme: const TextTheme(
        bodyLarge: TextStyle(color: Colors.white),
        bodyMedium: TextStyle(color: Colors.white),
        bodySmall: TextStyle(color: Colors.white70),
      ),
    );

    return Theme(
      data: theme,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Мониторинг IP-адресов'),
          backgroundColor: const Color(0xFF23232b),
        ),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              const SizedBox(height: 48),
              Center(
                child: ElevatedButton(
                  onPressed: () => _addDeviceDialog(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text(
                    'Добавить устройство',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Colors.white),
                  ),
                ),
              ),
              const SizedBox(height: 32),
              // Легенда с количеством устройств по статусам
              Consumer<DeviceProvider>(
                builder: (ctx, provider, _) {
                  int onlineCount = 0;
                  int offlineCount = 0;
                  int checkingCount = 0;
                  for (final d in provider.devices) {
                    final status = _statuses[d.ip] ?? (d.isOnline ? DeviceStatus.online : DeviceStatus.offline);
                    if (status == DeviceStatus.online) {
                      onlineCount++;
                    } else if (status == DeviceStatus.offline) offlineCount++;
                    else if (status == DeviceStatus.checking) checkingCount++;
                  }
                  return Row(
                    children: [
                      const Text('Список IP-адресов', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      const Spacer(),
                      _legendDot(Colors.green, 'Онлайн ($onlineCount)'),
                      const SizedBox(width: 12),
                      _legendDot(Colors.red, 'Офлайн ($offlineCount)'),
                      const SizedBox(width: 12),
                      _legendDot(const Color.fromARGB(255, 255, 238, 0), 'Проверка ($checkingCount)'),
                    ],
                  );
                },
              ),
              const SizedBox(height: 16),
              // Список карточек
              Expanded(
                child: Consumer<DeviceProvider>(
                  builder: (ctx, provider, _) {
                    final sortedDevices = List<Device>.from(provider.devices)
                      ..sort((a, b) => _compareIp(a.ip, b.ip));
                    return GridView.builder(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 4,
                        mainAxisSpacing: 20,
                        crossAxisSpacing: 20,
                        childAspectRatio: 1.3,
                      ),
                      itemCount: sortedDevices.length,
                      itemBuilder: (ctx, i) {
                        final device = sortedDevices[i];
                        final status = _statuses[device.ip] ??
                            (device.isOnline ? DeviceStatus.online : DeviceStatus.offline);
                        final lastStatus = _lastResultStatus[device.ip] ??
                            (device.isOnline ? DeviceStatus.online : DeviceStatus.offline);
                        final isDesktop = !kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS);

                        return MouseRegion(
                          onEnter: (_) {
                            if (isDesktop) setState(() => _hovered[device.ip] = true);
                          },
                          onExit: (_) {
                            if (isDesktop) setState(() => _hovered[device.ip] = false);
                          },
                          child: GestureDetector(
                            onTap: () => _addDeviceDialog(device: device),
                            child: Stack(
                              children: [
                                AnimatedBuilder(
                                  animation: _gradientController,
                                  builder: (context, child) {
                                    final double shift = _gradientController.value;
                                    return Container(
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: Stack(
                                        children: [
                                          // Градиентная рамка по статусу
                                          Positioned.fill(
                                            child: ShaderMask(
                                              shaderCallback: (rect) {
                                                return _statusGradient(status, shift).createShader(rect);
                                              },
                                              blendMode: BlendMode.srcATop,
                                              child: Container(
                                                decoration: BoxDecoration(
                                                  borderRadius: BorderRadius.circular(16),
                                                  border: Border.all(width: 4, color: Colors.white),
                                                ),
                                              ),
                                            ),
                                          ),
                                          // Контент карточки
                                          Padding(
                                            padding: const EdgeInsets.all(4),
                                            child: Container(
                                              decoration: BoxDecoration(
                                                color: theme.cardColor,
                                                borderRadius: BorderRadius.circular(12),
                                              ),
                                              padding: const EdgeInsets.all(8),
                                              child: Stack(
                                                children: [
                                                  // Кнопка удалить
                                                  Positioned(
                                                    right: 0,
                                                    top: 0,
                                                    child: IconButton(
                                                      icon: const Icon(Icons.close, color: Color.fromARGB(136, 255, 255, 255)),
                                                      onPressed: () {
                                                        Provider.of<DeviceProvider>(context, listen: false)
                                                            .removeDevice(device.ip);
                                                      },
                                                    ),
                                                  ),
                                                  // Контент карточки
                                                  Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Text(device.ip,
                                                          style: const TextStyle(
                                                              fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
                                                      if (device.name.isNotEmpty && device.name != device.ip)
                                                        Padding(
                                                          padding: const EdgeInsets.only(top: 2, bottom: 4),
                                                          child: Text(
                                                            device.name,
                                                            style: const TextStyle(
                                                              fontSize: 24,
                                                              color: Color.fromARGB(255, 255, 230, 0),
                                                              fontWeight: FontWeight.w500,
                                                            ),
                                                          ),
                                                        ),
                                                      if (device.name.isEmpty || device.name == device.ip)
                                                        const SizedBox(height: 6),
                                                      // Статус и кнопка (оставляем как было)
                                                      Row(
                                                        children: [
                                                          Icon(Icons.circle, color: _statusColor(status), size: 12),
                                                          const SizedBox(width: 6),
                                                          Text(
                                                            _statusText(status),
                                                            style: TextStyle(
                                                              color: _statusColor(status),
                                                              fontWeight: FontWeight.bold,
                                                              fontSize: 13,
                                                            ),
                                                          ),
                                                          const Spacer(),
                                                          ElevatedButton(
                                                            onPressed: status == DeviceStatus.checking
                                                                ? null
                                                                : () async {
                                                                    setState(() {
                                                                      _statuses[device.ip] = DeviceStatus.checking;
                                                                    });
                                                                    final stopwatch = Stopwatch()..start();
                                                                    final isOnline = await _pingIp(
                                                                      device.ip,
                                                                      timeoutSeconds: (status == DeviceStatus.offline) ? 10 : 1,
                                                                    );
                                                                    stopwatch.stop();
                                                                    Provider.of<DeviceProvider>(context, listen: false)
                                                                        .updateDevice(device.ip, Device(
                                                                          ip: device.ip,
                                                                          name: device.name,
                                                                          isOnline: isOnline,
                                                                        ));
                                                                    setState(() {
                                                                      _statuses[device.ip] = isOnline
                                                                          ? DeviceStatus.online
                                                                          : DeviceStatus.offline;
                                                                      _lastChecked[device.ip] = DateTime.now();
                                                                      _lastPing[device.ip] = stopwatch.elapsedMilliseconds;
                                                                      _lastResultStatus[device.ip] = isOnline
                                                                          ? DeviceStatus.online
                                                                          : DeviceStatus.offline;
                                                                    });
                                                                  },
                                                            style: ElevatedButton.styleFrom(
                                                              backgroundColor: _statusColor(status),
                                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                                              shape: RoundedRectangleBorder(
                                                                  borderRadius: BorderRadius.circular(6)),
                                                            ),
                                                            child: Text(
                                                              status == DeviceStatus.checking
                                                                  ? 'ПРОВЕРКА'
                                                                  : status == DeviceStatus.online
                                                                      ? 'ОНЛАЙН'
                                                                      : 'ОФЛАЙН',
                                                              style: const TextStyle(
                                                                color: Colors.black,
                                                                fontWeight: FontWeight.bold,
                                                                fontSize: 12,
                                                              ),
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                      const SizedBox(height: 6),
                                                      // Статус последней проверки (только онлайн/офлайн)
                                                      Row(
                                                        children: [
                                                          Text(
                                                            'ПОСЛЕДНЯЯ ПРОВЕРКА: ',
                                                            style: TextStyle(
                                                              color: Colors.white70,
                                                              fontSize: 10,
                                                              fontWeight: FontWeight.w500,
                                                            ),
                                                          ),
                                                          Text(
                                                            _statusText(lastStatus),
                                                            style: TextStyle(
                                                              color: _statusColor(lastStatus),
                                                              fontWeight: FontWeight.bold,
                                                              fontSize: 10,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                      Text(
                                                        _formatTime(_lastChecked[device.ip]),
                                                        style: const TextStyle(
                                                          color: Colors.white,
                                                          fontWeight: FontWeight.bold,
                                                          fontSize: 12,
                                                        ),
                                                      ),
                                                      const SizedBox(height: 4),
                                                      Text(
                                                        'ВРЕМЯ ОТКЛИКА',
                                                        style: TextStyle(
                                                            color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w500),
                                                      ),
                                                      Text(
                                                        _lastPing[device.ip] != null
                                                            ? '${_lastPing[device.ip]}мс'
                                                            : '--',
                                                        style: const TextStyle(
                                                            color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                                                      ),
                                                    ],
                                                  ),
                                                  // Плашка редактирования при наведении (только для десктопа)
                                                  if (isDesktop && (_hovered[device.ip] ?? false))
                                                    Positioned.fill(
                                                      child: Container(
                                                        decoration: BoxDecoration(
                                                          color: Colors.black.withOpacity(0.35),
                                                          borderRadius: BorderRadius.circular(12),
                                                        ),
                                                        child: Center(
                                                          child: Row(
                                                            mainAxisAlignment: MainAxisAlignment.center,
                                                            children: const [
                                                              Icon(Icons.edit, color: Colors.white, size: 28),
                                                              SizedBox(width: 8),
                                                              Text(
                                                                'Редактировать',
                                                                style: TextStyle(
                                                                  color: Colors.white,
                                                                  fontWeight: FontWeight.bold,
                                                                  fontSize: 18,
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _legendDot(Color color, String text) {
    return Row(
      children: [
        Icon(Icons.circle, color: color, size: 14),
        const SizedBox(width: 4),
        Text(text, style: TextStyle(color: color, fontWeight: FontWeight.w600)),
      ],
    );
  }
}
