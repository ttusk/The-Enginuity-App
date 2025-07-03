import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:permission_handler/permission_handler.dart';
import '../obd_connection_manager.dart';

class ConnectScreen extends StatefulWidget {
  const ConnectScreen({super.key});

  @override
  State<ConnectScreen> createState() => _ConnectScreenState();
}

class _ConnectScreenState extends State<ConnectScreen> {
  bool _connecting = false;
  bool _connected = false;
  String _dialogText = 'Connecting...';

  Future<bool> _requestBluetoothPermissions() async {
    final bluetoothConnect = await Permission.bluetoothConnect.request();
    final bluetoothScan = await Permission.bluetoothScan.request();
    final location =
        await Permission.location
            .request(); // Needed for BLE and Bluetooth discovery

    if (!mounted) return false;
    if (bluetoothConnect.isGranted &&
        bluetoothScan.isGranted &&
        location.isGranted) {
      return true;
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bluetooth and Location permissions are required.'),
        ),
      );
      return false;
    }
  }

  Future<void> _connectToOBD() async {
    bool hasPermissions = await _requestBluetoothPermissions();
    if (!hasPermissions) return;
    if (!mounted) return;
    setState(() {
      _connecting = true;
      _connected = false;
      _dialogText = 'Connecting...';
    });
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _buildConnectingDialog(),
    );
    try {
      // Start Bluetooth if not enabled
      final btState = await FlutterBluetoothSerial.instance.state;
      if (btState != BluetoothState.STATE_ON) {
        await FlutterBluetoothSerial.instance.requestEnable();
      }
      // Discover devices
      List<BluetoothDevice> devices =
          await FlutterBluetoothSerial.instance.getBondedDevices();
      if (!mounted) return;
      // Try to find an OBD device (by name, e.g., contains 'OBD' or 'ELM')
      BluetoothDevice? obdDevice;
      try {
        obdDevice = devices.firstWhere(
          (d) =>
              d.name != null &&
              (d.name!.toUpperCase().contains('OBD') ||
                  d.name!.toUpperCase().contains('ELM')),
        );
      } catch (_) {
        obdDevice = null;
      }
      if (obdDevice != null) {
        // Try to connect
        bool connected = await ObdConnectionManager().connectToDevice(
          obdDevice,
        );
        if (!mounted) return;
        setState(() {
          _dialogText = connected ? 'Connected!' : 'Connection failed.';
          _connected = connected;
        });
        await Future.delayed(const Duration(seconds: 2));
        if (!mounted) return;
        Navigator.of(context).pop(); // Close dialog
        if (connected) {
          if (!mounted) return;
          Navigator.of(context).pop(); // Go back to home
        }
        return;
      } else {
        if (!mounted) return;
        setState(() {
          _dialogText = 'No OBD-II device found.';
        });
        await Future.delayed(const Duration(seconds: 2));
        if (!mounted) return;
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _dialogText = 'Connection failed.';
      });
      await Future.delayed(const Duration(seconds: 2));
      if (!mounted) return;
      Navigator.of(context).pop();
    } finally {
      if (mounted) {
        setState(() {
          _connecting = false;
        });
      }
    }
  }

  Widget _buildConnectingDialog() {
    return AlertDialog(
      backgroundColor: Colors.grey[900],
      content: SizedBox(
        height: 100,
        child: Center(
          child:
              _connected
                  ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.check_circle,
                        color: Colors.green,
                        size: 48,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _dialogText,
                        style: const TextStyle(color: Colors.white),
                      ),
                    ],
                  )
                  : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 12),
                      Text(
                        _dialogText,
                        style: const TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF101B20),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              const Text(
                'Set Up',
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Connect OBD-II device',
                style: TextStyle(fontSize: 16, color: Colors.white70),
              ),
              const SizedBox(height: 6),
              RichText(
                text: const TextSpan(
                  style: TextStyle(fontSize: 15, color: Colors.white60),
                  children: [
                    TextSpan(
                      text:
                          'To the OBD-II port in your car and make sure that Bluetooth is turned on. ',
                    ),
                    TextSpan(
                      text:
                          "Don't worry you don't need to remove the device after, we'll take good care of your car.",
                      style: TextStyle(
                        decoration: TextDecoration.underline,
                        color: Colors.lightBlueAccent,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              // First image: OBD device (scaled up)
              Center(
                child: Image.asset(
                  'assets/images/obd_device.png',
                  width: 300, // increased width
                  height: 200, // increased height
                  fit: BoxFit.contain,
                  errorBuilder:
                      (context, error, stackTrace) => Container(
                        width: 300,
                        height: 200,
                        color: Colors.grey[800],
                        child: const Center(
                          child: Icon(Icons.image, color: Colors.white38),
                        ),
                      ),
                ),
              ),
              const SizedBox(height: 6),

              // Second image: Port location (larger and no container/decoration)
              Center(
                child: Image.asset(
                  'assets/images/port_location_guide.png',
                  width: 420, // larger than the first image
                  height: 300,
                  fit: BoxFit.fill,
                  errorBuilder:
                      (context, error, stackTrace) => Container(
                        width: 420,
                        height: 300,
                        color: Colors.grey[800],
                        child: const Center(
                          child: Icon(Icons.image, color: Colors.white38),
                        ),
                      ),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'In most cars',
                style: TextStyle(fontSize: 14, color: Colors.white54),
              ),
              const SizedBox(height: 4),
              const Text(
                'You can find the OBD II port beneath the driving wheel facing downwards on the left side.',
                style: TextStyle(fontSize: 15, color: Colors.white70),
              ),
              const SizedBox(height: 12),
              Center(
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2C3A42),
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: _connecting ? null : _connectToOBD,
                    child: const Text(
                      'Connect',
                      style: TextStyle(fontSize: 20, color: Colors.white),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
