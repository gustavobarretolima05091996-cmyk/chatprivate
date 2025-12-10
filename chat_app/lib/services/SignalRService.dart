import 'dart:async';
import 'package:signalr_core/signalr_core.dart';
import '../models/message.dart';

class SignalRService {
  late HubConnection _hubConnection;
  final StreamController<Message> _controller = StreamController.broadcast();

  Stream<Message> get messages => _controller.stream;

  // ✅ Getter para verificar se está conectado
  bool get isConnected => _hubConnection.state == HubConnectionState.connected;

  Future<void> init(String role) async {
    _hubConnection = HubConnectionBuilder()
        .withUrl("https://chat.trampeiservicos.com.br/chatHub")
    //.withUrl("https://10.0.2.2:7215/chatHub")
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

  // ✅ dispose sem async
  void dispose() {
    _hubConnection.stop(); // não precisa await
    _controller.close();
  }

  Future<void> reconnect() async {
    if (_hubConnection.state == HubConnectionState.connected) return;

    await _hubConnection.stop();
    await _hubConnection.start();
    print("SignalR reconectado!");
  }
}
