import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:collection';
import 'package:flutter/foundation.dart';

class ObdConnectionManager {
  static final ObdConnectionManager _instance = ObdConnectionManager._internal();
  factory ObdConnectionManager() => _instance;
  ObdConnectionManager._internal();

  BluetoothConnection? _connection;
  BluetoothDevice? _device;
  bool _isInitialized = false;

  // Command-response queue system
  final Queue<Completer<String>> _pendingCommands = Queue<Completer<String>>();
  final StringBuffer _responseBuffer = StringBuffer();
  StreamSubscription<List<int>>? _inputSubscription;
  Timer? _responseTimer;
  bool _isProcessingResponse = false;

  Future<bool> connectToDevice(BluetoothDevice device) async {
    try {
      debugPrint('🔌 OBD: Attempting to connect to ${device.name} (${device.address})');
      _connection = await BluetoothConnection.toAddress(device.address);
      _device = device;
      _isInitialized = false;
      
      debugPrint('🔌 OBD: Bluetooth connection established, setting up response listener');
      
      // Set up the response listener
      _setupResponseListener();
      
      // Initialize the OBD adapter
      debugPrint('🔌 OBD: Starting OBD adapter initialization...');
      bool initialized = await _initializeObdAdapter();
      if (!initialized) {
        debugPrint('❌ OBD: Adapter initialization failed, disconnecting');
        disconnect();
        return false;
      }
      
      debugPrint('✅ OBD: Successfully connected and initialized to ${device.name}');
      return true;
    } catch (e) {
      debugPrint('❌ OBD: Connection error: $e');
      _connection = null;
      _device = null;
      _isInitialized = false;
      _inputSubscription?.cancel();
      return false;
    }
  }

  void _setupResponseListener() {
    _inputSubscription?.cancel();
    _inputSubscription = _connection!.input!.listen(
      (data) {
        _handleIncomingData(data);
      },
      onError: (error) {
        debugPrint('❌ OBD: Bluetooth input error: $error');
        _clearPendingCommands('Connection error: $error');
      },
      onDone: () {
        debugPrint('⚠️ OBD: Bluetooth input stream closed');
        _clearPendingCommands('Connection closed');
      },
    );
    debugPrint('👂 OBD: Response listener set up successfully');
  }

  void _handleIncomingData(List<int> data) {
    if (_isProcessingResponse) {
      debugPrint('⚠️ OBD: Skipping data processing (already processing)');
      return;
    }
    _isProcessingResponse = true;
    
    try {
      String response = String.fromCharCodes(data);
      debugPrint('📥 OBD: Raw incoming data: ${response.replaceAll(RegExp(r'[\r\n]'), '\\r\\n')}');
      
      _responseBuffer.write(response);
      String bufferContent = _responseBuffer.toString();
      debugPrint('📦 OBD: Buffer content: ${bufferContent.replaceAll(RegExp(r'[\r\n]'), '\\r\\n')}');
      
      // Check if we have a complete response (ends with '>')
      if (bufferContent.contains('>')) {
        String fullResponse = bufferContent;
        _responseBuffer.clear();
        
        debugPrint('✅ OBD: Complete response detected, processing...');
        _processCompleteResponse(fullResponse);
      } else {
        debugPrint('⏳ OBD: Incomplete response, waiting for more data...');
      }
    } finally {
      _isProcessingResponse = false;
    }
  }

  void _processCompleteResponse(String response) {
    // Clean up the response
    String cleanResponse = response
        .replaceAll(RegExp(r'[\r\n]'), '')
        .replaceAll('>', '')
        .trim();
    
    debugPrint('🧹 OBD: Cleaned response: "$cleanResponse"');
    
    if (cleanResponse.isEmpty) {
      debugPrint('⚠️ OBD: Empty response, skipping');
      return;
    }
    
    // Complete the next pending command
    if (_pendingCommands.isNotEmpty) {
      Completer<String> completer = _pendingCommands.removeFirst();
      debugPrint('✅ OBD: Completing command with response: "$cleanResponse"');
      completer.complete(cleanResponse);
    } else {
      debugPrint('⚠️ OBD: Received response but no pending commands: "$cleanResponse"');
    }
  }

  void _clearPendingCommands(String error) {
    int pendingCount = _pendingCommands.length;
    debugPrint('🧹 OBD: Clearing $pendingCount pending commands due to: $error');
    
    while (_pendingCommands.isNotEmpty) {
      Completer<String> completer = _pendingCommands.removeFirst();
      completer.completeError(error);
    }
  }

  Future<bool> _initializeObdAdapter() async {
    try {
      debugPrint('🔄 OBD: Waiting for adapter to be ready...');
      await Future.delayed(const Duration(milliseconds: 1000));
      
      debugPrint('🔄 OBD: Sending ATZ (reset adapter)...');
      await _sendCommand('ATZ');
      await Future.delayed(const Duration(milliseconds: 2000));
      
      debugPrint('🔄 OBD: Sending ATI (get adapter info)...');
      String atiResponse = await _sendCommand('ATI');
      debugPrint('📋 OBD: Adapter info: $atiResponse');
      
      debugPrint('🔄 OBD: Configuring adapter settings...');
      await _sendCommand('ATE0'); // Turn off echo
      await _sendCommand('ATL0'); // Turn off linefeeds
      await _sendCommand('ATS0'); // Turn off spaces
      await _sendCommand('ATH0'); // Turn off headers
      await _sendCommand('ATSP0'); // Auto protocol
      
      debugPrint('🔄 OBD: Testing communication with 0100...');
      String protocolResponse = await _sendCommand('0100');
      debugPrint('🔍 OBD: Protocol detection response: $protocolResponse');
      
      if (protocolResponse.contains('41') && protocolResponse.length > 4) {
        _isInitialized = true;
        debugPrint('✅ OBD: Adapter initialized successfully');
        return true;
      } else {
        debugPrint('❌ OBD: Failed to detect OBD protocol. Response: $protocolResponse');
        return false;
      }
    } catch (e) {
      debugPrint('❌ OBD: Initialization error: $e');
      return false;
    }
  }

  Future<String> _sendCommand(String command) async {
    if (_connection == null || !_connection!.isConnected) {
      throw Exception('Not connected');
    }
    
    debugPrint('📤 OBD: Sending command: "$command"');
    
    Completer<String> completer = Completer<String>();
    _pendingCommands.add(completer);
    
    try {
      // Send the command
      _connection!.output.add(utf8.encode('$command\r'));
      await _connection!.output.allSent;
      debugPrint('📤 OBD: Command sent successfully, waiting for response...');
      
      // Wait for response with timeout
      String response = await completer.future.timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          _pendingCommands.remove(completer);
          throw TimeoutException('Command timeout: $command');
        },
      );
      
      debugPrint('📥 OBD: Received response for "$command": "$response"');
      return response;
    } catch (e) {
      _pendingCommands.remove(completer);
      debugPrint('❌ OBD: Command "$command" failed: $e');
      rethrow;
    }
  }

  void disconnect() {
    debugPrint('🔌 OBD: Disconnecting...');
    _connection?.finish();
    _connection = null;
    _device = null;
    _isInitialized = false;
    _inputSubscription?.cancel();
    _responseTimer?.cancel();
    _clearPendingCommands('Disconnected');
    _responseBuffer.clear();
    debugPrint('🔌 OBD: Disconnected successfully');
  }

  bool get isConnected => _connection != null && _connection!.isConnected && _isInitialized;

  BluetoothConnection? get connection => _connection;
  BluetoothDevice? get device => _device;

  // Send a command and await the next response
  Future<List<int>> sendObdCommand(String command) async {
    if (_connection == null || !_connection!.isConnected) {
      throw Exception('Not connected');
    }
    
    if (!_isInitialized) {
      throw Exception('OBD adapter not initialized');
    }
    
    try {
      debugPrint('🔧 OBD: Sending OBD command: $command');
      String response = await _sendCommand(command);
      List<int> responseBytes = utf8.encode(response);
      debugPrint('🔧 OBD: OBD response bytes: ${responseBytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')}');
      return responseBytes;
    } catch (e) {
      debugPrint('❌ OBD: OBD command error: $e');
      rethrow;
    }
  }
} 