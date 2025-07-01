import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';

class ObdConnectionManager {
  static final ObdConnectionManager _instance = ObdConnectionManager._internal();
  factory ObdConnectionManager() => _instance;
  ObdConnectionManager._internal();

  BluetoothConnection? _connection;
  BluetoothDevice? _device;

  Future<bool> connectToDevice(BluetoothDevice device) async {
    try {
      _connection = await BluetoothConnection.toAddress(device.address);
      _device = device;
      return true;
    } catch (e) {
      _connection = null;
      _device = null;
      return false;
    }
  }

  void disconnect() {
    _connection?.finish();
    _connection = null;
    _device = null;
  }

  bool get isConnected => _connection != null && _connection!.isConnected;

  BluetoothConnection? get connection => _connection;
  BluetoothDevice? get device => _device;
} 