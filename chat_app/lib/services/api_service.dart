import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';
import '../models/message.dart';


class ApiService {
  static const API_BASE = "https://chat.trampeiservicos.com.br";
  //static const API_BASE = "https://10.0.2.2:7215";

  static Map<String, String> get headers => {
    "Content-Type": "application/json",
    "Authorization": "Bearer ${AuthService.getToken()}"
  };


  static Future<List<Message>> getMessages() async {
    final res = await http.get(Uri.parse("$API_BASE/messages"));
    final data = jsonDecode(res.body);
    return (data as List).map((m) => Message.fromJson(m)).toList();
  }


  static Future sendMessage(String text, bool singleView, String sender) async {
    await http.post(
      Uri.parse("$API_BASE/messages"),
      headers: headers,
      body: jsonEncode({
        "text": text,
        "sender": sender,
        "oneTimeView": singleView
      }),
    );
  }

  static Future<void> markAsOpened(String id) async {
    final res = await http.put(
      Uri.parse("$API_BASE/messages/$id/opened"),
      headers: headers
    );

    if (res.statusCode != 200) {
      throw Exception("Erro ao marcar como aberta");
    }
  }

  static Future<bool> login(String username, String password) async {
    final res = await http.post(
      Uri.parse("$API_BASE/auth/login"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "username": username.trim().toLowerCase(),
        "password": password.trim().toLowerCase(),
      }),
    );

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);

      final token = data["token"];
      final role = data["role"];

      await AuthService.setToken(token);
      await AuthService.setRole(role); // SALVANDO O PERFIL (PessoaA ou PessoaB)

      return true;
    }

    return false;
  }

  static Future deleteMessage(String id) async {
    final res = await http.delete(Uri.parse("$API_BASE/messages/$id"), headers: headers);
    return res;
  }

  static Future clearMessages() async {
    await http.delete(Uri.parse("$API_BASE/messages/clear"));
  }
}