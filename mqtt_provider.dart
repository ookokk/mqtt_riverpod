import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'imqtt_controller.dart';

final mqttManagerProvider = ChangeNotifierProvider<IMQTTController>((ref) {
  return MQTTManager();
});
