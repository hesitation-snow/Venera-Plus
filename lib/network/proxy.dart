import 'dart:io';

import 'package:flutter/services.dart';
import 'package:venera_plus/foundation/app.dart';
import 'package:venera_plus/foundation/appdata.dart';
import 'package:venera_plus/foundation/extensions.dart';

String? _cachedProxy;

DateTime? _cachedProxyTime;

Future<String?> getProxy() async {
  if (_cachedProxyTime != null &&
      DateTime.now().difference(_cachedProxyTime!).inSeconds < 1) {
    return _cachedProxy;
  }
  String? proxy = await _getProxy();
  _cachedProxy = proxy;
  _cachedProxyTime = DateTime.now();
  return proxy;
}

Future<String?> _getProxy() async {
  if ((appdata.settings['proxy'] as String).removeAllBlank == "direct") {
    return null;
  }
  if (appdata.settings['proxy'] != "system") return appdata.settings['proxy'];

  String res;
  if (!App.isLinux) {
    const channel = MethodChannel("venera/method_channel");
    try {
      res = await channel.invokeMethod("getProxy");
    } catch (e) {
      return null;
    }
  } else {
    res = "No Proxy";
  }
  if (res == "No Proxy") return null;

  if (res.contains(";")) {
    var proxies = res.split(";");
    for (String proxy in proxies) {
      proxy = proxy.removeAllBlank;
      if (proxy.startsWith('https=')) {
        return proxy.substring(6);
      }
    }
  }

  final RegExp regex = RegExp(
    r'^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}:\d+$',
    caseSensitive: false,
    multiLine: false,
  );
  if (!regex.hasMatch(res)) {
    return null;
  }

  return _ignoreDeadLoopback(res);
}

/// A system proxy on loopback that is not listening makes every cloud request
/// fail with "connection refused". Fall back to a direct connection.
Future<String?> _ignoreDeadLoopback(String proxy) async {
  final endpoint = _loopbackEndpoint(proxy);
  if (endpoint == null) return proxy;
  try {
    final socket = await Socket.connect(
      endpoint.$1,
      endpoint.$2,
      timeout: const Duration(milliseconds: 400),
    );
    await socket.close();
    return proxy;
  } catch (_) {
    return null;
  }
}

(String, int)? _loopbackEndpoint(String proxy) {
  final value = proxy.removeAllBlank;
  final uri = Uri.tryParse(value.contains('://') ? value : 'http://$value');
  final host = uri?.host ?? '';
  final port = uri?.port ?? 0;
  if (port <= 0 || !_isLoopback(host)) return null;
  return (host, port);
}

bool _isLoopback(String host) {
  if (host == 'localhost' || host == '::1') return true;
  final address = InternetAddress.tryParse(host);
  return address != null && address.isLoopback;
}
