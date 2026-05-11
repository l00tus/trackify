import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';

class SocketService {
  WebSocketChannel? _channel;
  final String _baseUrl = "ws://localhost:8000/ws";

  void connect(String userId, Function(Map<String, dynamic>) onMessage) {
    _channel = WebSocketChannel.connect(Uri.parse("$_baseUrl/$userId"));

    _channel!.stream.listen((data) {
      print("Incoming WebSocket JSON: $data");
      final Map<String, dynamic> message = jsonDecode(data);
      onMessage(message);
    }, onError: (err) {
      print("Socket Error: $err");
    }, onDone: () {
      print("Socket Closed");
    });
  }

  void disconnect() {
    _channel?.sink.close();
  }
}