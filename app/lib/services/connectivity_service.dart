import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';

class ConnectivityService {
  static final ConnectivityService _instance = ConnectivityService._();
  factory ConnectivityService() => _instance;
  ConnectivityService._();

  final _controller = StreamController<bool>.broadcast();
  Stream<bool> get onStatusChange => _controller.stream;

  bool _isOnline = true;
  bool get isOnline => _isOnline;

  Timer? _timer;

  void startMonitoring({Duration interval = const Duration(seconds: 15)}) {
    _checkConnection();
    _timer = Timer.periodic(interval, (_) => _checkConnection());
  }

  void stopMonitoring() {
    _timer?.cancel();
    _timer = null;
  }

  Future<bool> _checkConnection() async {
    try {
      final result = await InternetAddress.lookup('graph.facebook.com')
          .timeout(const Duration(seconds: 5));
      final online = result.isNotEmpty && result[0].rawAddress.isNotEmpty;
      if (online != _isOnline) {
        _isOnline = online;
        _controller.add(online);
      }
      return online;
    } catch (_) {
      if (_isOnline) {
        _isOnline = false;
        _controller.add(false);
      }
      return false;
    }
  }

  Future<bool> checkNow() => _checkConnection();

  void dispose() {
    _timer?.cancel();
    _controller.close();
  }
}

/// Wrap your Scaffold body to show offline banner
class ConnectivityBanner extends StatelessWidget {
  final Widget child;
  const ConnectivityBanner({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<bool>(
      stream: ConnectivityService().onStatusChange,
      initialData: ConnectivityService().isOnline,
      builder: (context, snapshot) {
        final online = snapshot.data ?? true;
        return Column(
          children: [
            if (!online)
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: const Color(0xFFFF1744),
                child: const SafeArea(
                  bottom: false,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.wifi_off_rounded,
                          color: Colors.white, size: 16),
                      SizedBox(width: 8),
                      Text(
                        'No internet connection',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            Expanded(child: child),
          ],
        );
      },
    );
  }
}