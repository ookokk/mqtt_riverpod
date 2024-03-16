import 'package:flutter/cupertino.dart';

abstract class IMQTTController extends ChangeNotifier {
  MQTTAppState get currentState;
  void init();
  void connect();
  void disconnect();
  void listen();
  void published();
  void publish(String message);
  void subScribeTo(String topic);
  void unSubscribe(String topic);
  void unSubscribeFromCurrentTopic();
  Stream<String> get messageStream;
}
