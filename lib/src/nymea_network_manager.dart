library nymea_network_manager;

import 'dart:async';
import 'dart:convert';

import 'package:collection/collection.dart' show IterableExtension;
import 'package:flutter/cupertino.dart';
import 'package:flutter_blue/flutter_blue.dart';

class WiFiNetwork {
  final String ssid;
  final String macAddress;
  final int signalStrength;
  final bool isOpen;

  WiFiNetwork({required this.ssid, required this.macAddress, this.signalStrength = 0, this.isOpen = true});

  @override
  String toString() {
    return 'WiFiNetwork{ssid: $ssid, macAddress: $macAddress, signalStrength: $signalStrength, isOpen: $isOpen}';
  }
}

class ConnectionInfo {
  final String ip;
  final String name;
  final String macAddress;
  final bool isOpen;
  final int signalStrength;

  ConnectionInfo({required this.ip, required this.name, required this.macAddress, this.isOpen = true, this.signalStrength = 0});

  @override
  String toString() {
    return 'ConnectionInfo{ip: $ip, name: $name, macAddress: $macAddress, isOpen: $isOpen, signalStrength: $signalStrength}';
  }
}

/// An instance of nymea network manager.
class NymeaNetworkManager {
  static final String _characterisitcCommanderRequest = 'e081fec1-f757-4449-b9c9-bfa83133f7fc';
  static final String _characterisitcCommanderResult = 'e081fec2-f757-4449-b9c9-bfa83133f7fc';
  static final String _characterisitcWiFiStatus = 'e081fec3-f757-4449-b9c9-bfa83133f7fc';
  static final String _characterisitcWiFiMode = 'e081fec4-f757-4449-b9c9-bfa83133f7fc';

  static final String _serviceWiFiCommander = 'e081fec0-f757-4449-b9c9-bfa83133f7fc';

  final String advertisingName;
  final bool enableLogs;
  FlutterBlue _blue = FlutterBlue.instance;
  List<BluetoothService> _services = [];
  BluetoothDevice? _connectedDevice;

  NymeaNetworkManager({this.advertisingName = 'BT WLAN setup', this.enableLogs = false});

  BluetoothService? get _wifiService => _services.firstWhereOrNull((element) => element.uuid.toString() == _serviceWiFiCommander);

  BluetoothCharacteristic? get _wifiRequest =>
      _wifiService?.characteristics.firstWhereOrNull((element) => element.uuid.toString() == _characterisitcCommanderRequest);

  BluetoothCharacteristic? get _wifiResponse =>
      _wifiService?.characteristics.firstWhereOrNull((element) => element.uuid.toString() == _characterisitcCommanderResult);

  void _log(String message) {
    if (enableLogs) {
      debugPrint(message);
    }
  }

  /// Returns a list of [WiFiNetwork] available networks on the remote device
  Future<List<WiFiNetwork>> getNetworks() async {
    await scanNetwork();
    final command = 0;
    final data = await _write('{"c":$command}', _wifiRequest, _wifiResponse, command: command);
    final networks = <WiFiNetwork>[];
    data.forEach((network) => networks.add(WiFiNetwork(
          ssid: network['e'],
          signalStrength: network['s'],
          macAddress: network['m'],
          isOpen: network['p'] == 0,
        )));
    return networks;
  }

  Future<void> connectHiddenNetwork(String ssid, String password) async {
    final command = 2;
    return _write('{"c":$command,"p":{"e":"$ssid","p":"$password"}}', _wifiRequest, _wifiResponse, command: command);
  }

  Future<dynamic> _write(String data, BluetoothCharacteristic? characteristicRequest, BluetoothCharacteristic? characteristicResponse, {int? command}) async {
    late StreamSubscription subscription;
    Completer completer = Completer();
    if (characteristicResponse == null) {
      return Future.error(StateError('no characteristicResponse'));
    }

    var completeData = '';
    subscription = characteristicResponse.value.listen((element) {
      if (element.isNotEmpty) {
        final partData = String.fromCharCodes(element);
        completeData += partData;
        if (completeData.contains('\n')) {
          final response = jsonDecode(completeData);
          // response isn't for the given command, skip the response
          if (command != null && command != response['c']) {
            return;
          }
          _log('result: ${response.toString()}');

          if (response['r'] == 0) {
            completer.complete(response['p']);
          } else {
            completer.completeError(NetworkManagerException(response));
          }
          subscription.cancel();
        }
      }
    });
    final rawData = '$data\n'.codeUnits;
    _log('Will write: ' + data);
    final packets = (rawData.length / 20).ceil();
    for (var i = 0; i < packets; i++) {
      final endIndex = i == packets - 1 ? rawData.length : i * 20 + 20;
      final part = rawData.sublist(i * 20, endIndex);
      _log('Write part of $i/$packets: ' + String.fromCharCodes(part));
      await characteristicRequest!.write(part);
    }

    return completer.future;
  }

  Future<void> connectNetwork(String ssid, String password) async {
    final command = 1;
    return _write('{"c":$command,"p":{"e":"$ssid","p":"$password"}}', _wifiRequest, _wifiResponse, command: command);
  }

  Future<void> disconnectNetwork() async {
    final command = 3;
    return _write('{"c":$command}', _wifiRequest, _wifiResponse, command: command);
  }

  Future<void> scanNetwork() async {
    final command = 4;
    return _write('{"c":$command}', _wifiRequest, _wifiResponse, command: command);
  }

  Future<ConnectionInfo> getConnection() async {
    final command = 5;
    final data = await _write('{"c":$command}', _wifiRequest, _wifiResponse, command: command);
    return ConnectionInfo(
      name: data['e'],
      ip: data['i'],
      signalStrength: data['s'],
      macAddress: data['m'],
      isOpen: data['p'] == 0,
    );
  }

  Future<void> disconnect() async {
    await _connectedDevice?.disconnect();
  }

  Future<bool> connect() async {
    final completer = Completer<bool>();
    late StreamSubscription subscription;

    final connectedDevices = await _blue.connectedDevices;
    _log('already connected devices $connectedDevices');

    final device = connectedDevices.firstWhereOrNull((element) => element.name == advertisingName);
    bool deviceFound = false;
    if (device == null) {
      // Listen to scan results
      subscription = _blue.scanResults.listen((results) async {
        _log('scan results $results');
        final wantedDevice = results.firstWhereOrNull((element) => element.device.name == advertisingName);
        _log('wantedDevice $wantedDevice');
        if (wantedDevice != null) {
          deviceFound = true;
          try {
            // Stop scanning
            _blue.stopScan();
            subscription.cancel();
            await wantedDevice.device.connect(autoConnect: false, timeout: Duration(seconds: 4));
            _services = await wantedDevice.device.discoverServices();
            await _wifiResponse?.setNotifyValue(true);
            if (completer.isCompleted) {
              _log('search already completed, ignored connected device');
            } else {
              this._connectedDevice = wantedDevice.device;
              completer.complete(true);
              _log('device found $wantedDevice');
            }
          } catch(err) {
            if (completer.isCompleted) {
              _log('search already completed, ignoring error $err');
            } else {
              completer.completeError(err);
            }
          }
        }
      });
      _log('startScan');

      // Start scanning
      if (await _blue.isScanning.first) {
        await _blue.stopScan();
      }

      await _blue.startScan(timeout: Duration(seconds: 4)).catchError((err) {
        completer.completeError(err);
      });

      if (!completer.isCompleted && !deviceFound) {
        subscription.cancel();
        completer.completeError(NoDeviceException());
      }
    } else {
      final state = await device.state.firstWhere((element) => element == BluetoothDeviceState.connected, orElse: (() => BluetoothDeviceState.disconnected));
      if (state == BluetoothDeviceState.disconnected) {
        await device.connect(autoConnect: false, timeout: Duration(seconds: 4));
      }

      _services = await device.discoverServices();
      await _wifiResponse?.setNotifyValue(true);
      completer.complete(true);
    }
    return completer.future;
  }
}

class NoDeviceException implements Exception {

  @override
  String toString() {
    return 'NoDeviceException{}';
  }
}

class NetworkManagerException implements Exception {
  final Map<String, dynamic>? rawResponse;

  NetworkManagerException(this.rawResponse);

  @override
  String toString() {
    return 'NetworkManagerException{rawResponse: $rawResponse}';
  }
}
