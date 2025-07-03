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

  Future<bool> _requestBluetoothPermissions() async {
    debugPrint('🔐 CONNECT: Requesting Bluetooth permissions...');
    final bluetoothConnect = await Permission.bluetoothConnect.request();
    final bluetoothScan = await Permission.bluetoothScan.request();
    final location =
        await Permission.location
            .request(); // Needed for BLE and Bluetooth discovery

    if (!mounted) return false;
    
    bool allGranted = bluetoothConnect.isGranted &&
        bluetoothScan.isGranted &&
        location.isGranted;
        
    debugPrint('🔐 CONNECT: Permissions granted: $allGranted');
    
    if (!allGranted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bluetooth and Location permissions are required.'),
        ),
      );
    }
    
    return allGranted;
  }

  Future<void> _connectToOBD() async {
    debugPrint('🔌 CONNECT: Starting OBD connection process');
    bool hasPermissions = await _requestBluetoothPermissions();
    debugPrint('🔌 CONNECT: Permissions granted: $hasPermissions');
    if (!hasPermissions) return;
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const ConnectionDialog(),
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

class ConnectionDialog extends StatefulWidget {
  const ConnectionDialog({super.key});

  @override
  State<ConnectionDialog> createState() => _ConnectionDialogState();
}

class _ConnectionDialogState extends State<ConnectionDialog> {
  late Future<bool> _connectionFuture;

  @override
  void initState() {
    super.initState();
    debugPrint('🔌 DIALOG: ConnectionDialog initialized');
    _connectionFuture = _connect();
  }

  Future<bool> _connect() async {
    debugPrint('🔌 DIALOG: Starting connection process');
    
    // Start Bluetooth if not enabled
    final btState = await FlutterBluetoothSerial.instance.state;
    debugPrint('🔌 DIALOG: Bluetooth state: $btState');
    if (btState != BluetoothState.STATE_ON) {
      debugPrint('🔌 DIALOG: Requesting Bluetooth enable...');
      await FlutterBluetoothSerial.instance.requestEnable();
    }
    
    // Discover devices
    debugPrint('🔌 DIALOG: Getting bonded devices...');
    List<BluetoothDevice> devices =
        await FlutterBluetoothSerial.instance.getBondedDevices();
    debugPrint('🔌 DIALOG: Found ${devices.length} bonded devices: ${devices.map((d) => d.name).toList()}');
    
    if (!mounted) return false;
    
    // Try to find an OBD device (by name, e.g., contains 'OBD' or 'ELM')
    BluetoothDevice? obdDevice;
    try {
      obdDevice = devices.firstWhere(
        (d) =>
            d.name != null &&
            (d.name!.toUpperCase().contains('OBD') ||
                d.name!.toUpperCase().contains('ELM')),
      );
      debugPrint('🔌 DIALOG: Found OBD device: ${obdDevice.name}');
    } catch (_) {
      obdDevice = null;
      debugPrint('🔌 DIALOG: No OBD device found in bonded devices');
    }
    
    if (obdDevice != null) {
      // Try to connect with timeout
      try {
        debugPrint('🔌 DIALOG: Attempting to connect to ${obdDevice.name}...');
        bool connected = await ObdConnectionManager()
            .connectToDevice(obdDevice)
            .timeout(const Duration(seconds: 15));
        debugPrint('🔌 DIALOG: Connection result: $connected');
        debugPrint('🔌 DIALOG: ObdConnectionManager().isConnected: ${ObdConnectionManager().isConnected}');
        return connected;
      } catch (e) {
        debugPrint('❌ DIALOG: Connection attempt failed: $e');
        return false;
      }
    } else {
      debugPrint('❌ DIALOG: No OBD-II device found');
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('🔌 DIALOG: Building connection dialog');
    return AlertDialog(
      backgroundColor: Colors.grey[900],
      content: SizedBox(
        height: 140,
        child: FutureBuilder<bool>(
          future: _connectionFuture,
          builder: (context, snapshot) {
            debugPrint('🔌 DIALOG: FutureBuilder state: ${snapshot.connectionState}, hasError: ${snapshot.hasError}, data: ${snapshot.data}');
            if (snapshot.connectionState == ConnectionState.waiting) {
              debugPrint('🔌 DIALOG: Showing waiting state');
              return Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 12),
                  const Text(
                    'Connecting...',
                    style: TextStyle(color: Colors.white),
                  ),
                ],
              );
            } else if (snapshot.hasError || !(snapshot.data ?? false)) {
              debugPrint('🔌 DIALOG: Showing error state');
              return Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error, color: Colors.red, size: 48),
                  const SizedBox(height: 12),
                  const Text(
                    'Connection failed.',
                    style: TextStyle(color: Colors.white),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                    ),
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    child: const Text('Close'),
                  ),
                ],
              );
            } else {
              debugPrint('🔌 DIALOG: Showing success state');
              return Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.check_circle, color: Colors.green, size: 48),
                  const SizedBox(height: 12),
                  const Text(
                    'Connected!',
                    style: TextStyle(color: Colors.white),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                    ),
                    onPressed: () {
                      Navigator.of(context).pop(); // Close dialog
                      Navigator.of(context).pop(); // Go back to home
                    },
                    child: const Text('Awesome!'),
                  ),
                ],
              );
            }
          },
        ),
      ),
    );
  }
}
