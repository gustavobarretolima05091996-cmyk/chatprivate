import 'dart:async';
import 'package:signalr_core/signalr_core.dart';
import '../models/message.dart';

class SignalRService {
  late HubConnection _hubConnection;

  // STREAM de mensagens normais
  final StreamController<Message> _msgController = StreamController.broadcast();
  Stream<Message> get messages => _msgController.stream;

  // STREAM do comando receber "ForceGoHome"
  final StreamController<bool> _forceGoHomeController = StreamController<bool>.broadcast();
  Stream<bool> get onForceGoHome => _forceGoHomeController.stream;

  // STREAM do comando "MessagesCleared"
  final StreamController<bool> _clearMessagesController = StreamController<bool>.broadcast();
  Stream<bool> get onClearMessages => _clearMessagesController.stream;

  bool get isConnected => _hubConnection.state == HubConnectionState.connected;


  Future<void> init(String role) async {
    _hubConnection = HubConnectionBuilder()
        .withUrl("https://chat.trampeiservicos.com.br/chatHub")
        //.withUrl("https://10.0.2.2:7215/chatHub")
        .build();

    _hubConnection.onclose((error) => print("SignalR desconectado: $error"));

    // 🔹 Quando receber mensagem normal
    _hubConnection.on("ReceiveMessage", (arguments) {
      if (arguments != null && arguments.isNotEmpty) {
        final data = Map<String, dynamic>.from(arguments[0]);
        _msgController.add(Message.fromJson(data));
      }
    });

    // 🔹 Quando o servidor manda "ForceGoHome"
    _hubConnection.on("ForceGoHome", (_) {
      _forceGoHomeController.add(true);
    });

    // 🔹 Quando o servidor manda "MessagesCleared"
    _hubConnection.on("MessagesCleared", (_) {
      _clearMessagesController.add(true);
    });

    await _hubConnection.start();
    print("SignalR conectado!");
  }

  Future<void> sendMessage(Message msg) async {
    if (_hubConnection.state == HubConnectionState.connected) {
      await _hubConnection.invoke("SendMessage", args: [msg.toDto()]);
    }
  }

  Future<void> invokeForceGoHome(String target) async {
    await _hubConnection.invoke("ForceGoHome");
  }

  Future<void> invokeClearMessages() async {
    await _hubConnection.invoke("ClearMessages");
  }

  Future<void> reconnect() async {
    if (_hubConnection.state == HubConnectionState.connected) return;

    await _hubConnection.stop();
    await _hubConnection.start();
    print("SignalR reconectado!");
  }

  void dispose() {
    _hubConnection.stop();
    _msgController.close();
    _forceGoHomeController.close();
    _clearMessagesController.close();
  }
}
