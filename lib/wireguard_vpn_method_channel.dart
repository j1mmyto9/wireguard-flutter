import 'dart:convert';

// import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:wireguard_vpn/src/models/event_names.dart';

import 'src/errors/exceptions.dart';
import 'src/models/models.dart';
import 'wireguard_vpn_platform_interface.dart';

/// An implementation of [WireguardVpnPlatform] that uses method channels.
class MethodChannelWireguardVpn extends WireguardVpnPlatform {
  /// The method channel used to interact with the native platform.
  final methodChannel = const MethodChannel('pingak9/wireguard-flutter');

  /// Implementation of the method [changeStateParams] using the PlatformChannel.
  @override
  Future<bool?> changeStateParams(SetStateParams params) async {
    try {
      final state = await methodChannel.invokeMethod<bool>(
          EventNames.methodSetState, jsonEncode(params.toJson()));

      return state;
    } on Exception catch (e) {
      throw ConnectionException(message: e.toString());
    }
  }

  /// Implementation of the method [runningTunnelNames] using the PlatformChannel.
  @override
  Future<String?> runningTunnelNames() async {
    try {
      final result =
          await methodChannel.invokeMethod(EventNames.methodGetTunnelNames);
      return result;
    } on PlatformException catch (e) {
      throw ConnectionException(message: e.message ?? '');
    }
  }

  /// Implementation of the method [tunnelGetStats] using the PlatformChannel.
  @override
  Future<Stats?> tunnelGetStats(String name) async {
    try {
      final result =
          await methodChannel.invokeMethod(EventNames.methodGetStats, name);
      final stats = Stats.fromJson(jsonDecode(result));
      return stats;
    } on Exception catch (e) {
      throw ConnectionException(message: e.toString());
    }
  }

  /// Implementation of the method [removeAllTunnels] using the PlatformChannel.
  @override
  Future removeAllTunnels() async {
    try {
      await methodChannel.invokeMethod(EventNames.methodRemoveAllTunnels);
    } on Exception catch (e) {
      throw ConnectionException(message: e.toString());
    }
  }
}
