import 'dart:async';
import 'dart:io';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'package:flutter/services.dart';
import 'package:device_info_plus/device_info_plus.dart';

class MQTTManager extends IMQTTController {
  StreamController<String> _messageStreamController = StreamController.broadcast();
  Stream<String> get messageStream => _messageStreamController.stream;
  final DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
  MQTTAppState _currentState = MQTTAppState();
  MqttServerClient? _client;
  String _topic = "chats";
  String? deviceId;
  MQTTAppState get currentState => _currentState;

  @override
  void init() {
    getDeviceId();
    _client = MqttServerClient('push.flows.com.tr', deviceId ?? "unknownDevice");
    _client!.autoReconnect = true;
    _client!.port = 3169;
    _client!.keepAlivePeriod = 20;
    _client!.onDisconnected = onDisconnected;
    _client!.secure = false;
    _client!.logging(on: true);
    _client!.onConnected = onConnected;
    _client!.onSubscribed = onSubscribed;
    _client!.onUnsubscribed = onUnsubscribed;
    final MqttConnectMessage connMess = MqttConnectMessage()
        .withClientIdentifier(deviceId ?? "Unknown Device")
        .withWillTopic('willtopic')
        .withWillMessage('My Will message')
        .startClean()
        .withWillQos(MqttQos.atLeastOnce);
    print('EXAMPLE::Mosquitto client connecting....');
    _client!.connectionMessage = connMess;
  }

  Future<void> getDeviceId() async {
    try {
      if (Platform.isAndroid) {
        AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
        deviceId = androidInfo.id;
      } else if (Platform.isIOS) {
        IosDeviceInfo iosInfo = await deviceInfo.iosInfo;
        deviceId = iosInfo.identifierForVendor;
      } else {
        deviceId = 'failed to get device Id';
      }
    } on PlatformException {
      deviceId = 'Failed to get device ID.';
    }
  }

  @override
  void connect() async {
    assert(_client != null);
    try {
      print('EXAMPLE:start client connecting....');
      await _client!.connect();
      _currentState.setAppConnectionState(MQTTAppConnectionState.connected);
      updateState();
    } on Exception catch (e) {
      print('EXAMPLE::client exception - $e');
      disconnect();
    }
  }

  @override
  void disconnect() {
    print('Disconnected');
    _client!.disconnect();
  }

  @override
  void publish(String message) {
    final MqttClientPayloadBuilder builder = MqttClientPayloadBuilder();
    builder.addString(message);
    _client!.publishMessage(_topic, MqttQos.exactlyOnce, builder.payload!);
  }

  @override
  void published() {
    _client!.published!.listen((MqttPublishMessage message) {
      print(
          'EXAMPLE::Published notification:: topic is ${message.variableHeader!.topicName}, with Qos ${message.header!.qos}');
    });
  }

  void onSubscribed(String topic) {
    print('EXAMPLE::Subscription confirmed for topic $topic');
    _currentState.setAppConnectionState(MQTTAppConnectionState.connectedSubscribed);
    updateState();
  }

  @override
  void listen() {
    _client!.updates!.listen((List<MqttReceivedMessage<MqttMessage?>>? c) {
      final recMess = c![0].payload as MqttPublishMessage;
      final pt = MqttPublishPayload.bytesToStringAsString(recMess.payload.message);
      _messageStreamController.add(pt);
      print('EXAMPLE::Change notification:: topic is <${c[0].topic}>, payload is <-- $pt -->');
    });
  }

  void onUnsubscribed(String? topic) {
    print('EXAMPLE::onUnsubscribed confirmed for topic $topic');
    _currentState.clearText();
    _currentState.setAppConnectionState(MQTTAppConnectionState.connectedUnSubscribed);
    updateState();
  }

  void onDisconnected() {
    print('EXAMPLE::OnDisconnected client callback - Client disconnection');
    if (_client!.connectionStatus!.returnCode == MqttConnectReturnCode.noneSpecified) {
      print('EXAMPLE::OnDisconnected callback is solicited, this is correct');
    }
    _currentState.clearText();
    _currentState.setAppConnectionState(MQTTAppConnectionState.disconnected);
    updateState();
  }

  void onConnected() {
    _currentState.setAppConnectionState(MQTTAppConnectionState.connected);
    updateState();
    print('EXAMPLE::Mosquitto client connected....');
    _client!.updates!.listen((List<MqttReceivedMessage<MqttMessage>> c) {
      final MqttPublishMessage recMess = c[0].payload as MqttPublishMessage;
      final String pt = MqttPublishPayload.bytesToStringAsString(recMess.payload.message);
      _currentState.setReceivedText(pt);
      updateState();
      print('EXAMPLE::Change notification:: topic is <${c[0].topic}>, payload is <-- $pt -->');
    });
    print('EXAMPLE::OnConnected client callback - Client connection was successful');
  }

  @override
  void subScribeTo(String topic) {
    _topic = topic;
    _client!.subscribe(topic, MqttQos.atLeastOnce);
  }

  @override
  void unSubscribe(String topic) {
    _client!.unsubscribe(topic);
  }

  @override
  void unSubscribeFromCurrentTopic() {
    _client!.unsubscribe(_topic);
  }

  void updateState() {
    notifyListeners();
  }
}
