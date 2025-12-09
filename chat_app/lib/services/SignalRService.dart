import 'dart:async';
import 'package:signalr_core/signalr_core.dart';
import '../models/message.dart';

class SignalRService {
  late HubConnection _hubConnection;
  final StreamController<Message> _controller = StreamController.broadcast();

  Stream<Message> get messages => _controller.stream;

  Future<void> init(String role) async {
    _hubConnection = HubConnectionBuilder()
        .withUrl("https://chat.trampeiservicos.com.br/chatHub")
        .build();

    _hubConnection.onclose((error) => print("SignalR desconectado: $error"));

    _hubConnection.on("ReceiveMessage", (arguments) {
      if (arguments != null && arguments.isNotEmpty) {
        final data = Map<String, dynamic>.from(arguments[0]);
        _controller.add(Message.fromJson(data));
      }
    });

    await _hubConnection.start();
    print("SignalR conectado!");
  }

  Future<void> sendMessage(Message msg) async {
    if (_hubConnection.state == HubConnectionState.connected) {
      await _hubConnection.invoke("SendMessage", args: [msg.toDto()]);
    }
  }

  void dispose() {
    _hubConnection.stop();
    _controller.close();
  }
}