import 'dart:math';
import 'package:flutter/material.dart';
import 'package:micommunity/screens/home_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/SignalRService.dart';
import '../services/api_service.dart';
import '../models/message.dart';
import '../services/auth_service.dart';
import 'login_screen.dart';

// Usuários e cores fake
final List<String> randomNames = [
  "Lucas", "Amanda", "Bruno", "Carla", "Diego", "Elisa",
  "Felipe", "Giovana", "Henrique", "Isabela", "João", "Karina",
  "Luan", "Marina", "Nathan", "Olívia", "Paulo", "Rafaela",
  "Samuel", "Tatiane", "Victor", "Yasmin", "Thiago", "Camila",
];

final List<Color> userColors = [
  Colors.blue, Colors.green, Colors.purple, Colors.orange,
  Colors.red, Colors.teal, Colors.indigo, Colors.brown,
];

Map<String, Map<String, dynamic>> fakeProfiles = {};

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with WidgetsBindingObserver {
  final TextEditingController msgCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  final SignalRService signalRService = SignalRService();

  List<Message> msgs = [];
  String? sender;
  bool _loading = false;
  bool _connecting = true;
  String? role;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadRole();
    _initChat();

    signalRService.onForceGoHome.listen((_) async {
      if (!mounted) return;

      if (role == "PessoaA") {
        await AuthService.logout();

        if (!mounted) return;

        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => HomeScreen()),
        );
      }
      if (role == "PessoaB") {
        Future.microtask(() {
          showDialog(
            context: context,
            builder: (_) => AlertDialog(
              title: const Text("Usuário desconectado"),
              content: const Text("Você desconectou a pessoa com sucesso."),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("OK"),
                ),
              ],
            ),
          );
        });
        return;
      }
    });
  }


  Future<void> _loadRole() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      role = prefs.getString("role");
    });
  }

  Future<void> _attemptReconnect() async {
    if (sender == null) return;

    int attempts = 0;
    bool connected = false;

    while (attempts < 3 && !connected) {
      try {
        await signalRService.reconnect();
        connected = true;
        print("SignalR reconectado com sucesso!");
      } catch (e) {
        attempts++;
        print("Falha ao reconectar SignalR, tentativa $attempts: $e");
        await Future.delayed(const Duration(seconds: 2));
      }
    }

    if (!connected && mounted) {
      await AuthService.logout();
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }


  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _attemptReconnect();
    }
  }

  Future<void> _reconnectSignalR() async {
    if (sender == null) return;

    int attempts = 0;
    bool connected = false;

    setState(() => _connecting = true);

    while (attempts < 3 && !connected) {
      try {
        signalRService.dispose(); // fecha conexão antiga
        await signalRService.init(sender!);
        connected = true;
        print("SignalR reconectado com sucesso!");
      } catch (e) {
        attempts++;
        print("Falha ao reconectar SignalR, tentativa $attempts: $e");
        await Future.delayed(const Duration(seconds: 2));
      }
    }

    if (!connected && mounted) {
      await AuthService.logout();
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
      return;
    }

    // reconectou
    setState(() => _connecting = false);
  }

  @override
  void dispose() {
    msgCtrl.dispose();
    _scrollCtrl.dispose();
    signalRService.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _initChat() async {
    sender = await AuthService.getRole();
    if (sender == null) return;

    int attempts = 0;
    bool connected = false;

    while (attempts < 3 && !connected) {
      try {
        await signalRService.init(sender!);
        connected = true;
      } catch (e) {
        attempts++;
        print("Falha ao conectar SignalR, tentativa $attempts: $e");
        await Future.delayed(const Duration(seconds: 2));
      }
    }

    if (!connected) {
      if (!mounted) return;
      await AuthService.logout();
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
      return;
    }

    // Conectou com sucesso
    setState(() => _connecting = false);
    // ADICIONAR AQUI — ouvir ClearMessages
    signalRService.onClearMessages.listen((_) {
      setState(() => msgs.clear());
    });

    // Ouvir mensagens ao vivo
    signalRService.messages.listen((msg) {
      setState(() => msgs.add(msg));
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollCtrl.hasClients) {
          _scrollCtrl.animateTo(
            _scrollCtrl.position.maxScrollExtent,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          );
        }
      });
    });

    // Carregar mensagens antigas
    final fetched = await ApiService.getMessages();
    setState(() => msgs = fetched);
  }

  Future<void> send(bool oneTime) async {
    if (!signalRService.isConnected) {
      try {
        await signalRService.reconnect();
      } catch (e) {
        print("Não foi possível reconectar SignalR: $e");
        return;
      }
    }


    final text = msgCtrl.text.trim();
    if (text.isEmpty || sender == null) return;

    setState(() => _loading = true);

    final now = DateTime.now().toUtc().subtract(const Duration(hours: 3)); // Brasília
    final msg = Message(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      sender: sender!,
      text: text,
      oneTimeView: oneTime,
      opened: false,
      timestamp: now.toIso8601String(),
    );

    try {
      await signalRService.sendMessage(msg);
      msgCtrl.clear();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Map<String, dynamic> _getFakeProfile(String msgId) {
    if (fakeProfiles.containsKey(msgId)) return fakeProfiles[msgId]!;

    randomNames.shuffle();
    userColors.shuffle();
    final profile = {
      "name": randomNames.first,
      "color": userColors.first,
    };
    fakeProfiles[msgId] = profile;
    return profile;
  }

  String formatTimestamp(String ts) {
    try {
      final dt = DateTime.parse(ts);
      final br = dt.toUtc().subtract(const Duration(hours: 3)); // Brasília
      final day = br.day.toString().padLeft(2, '0');
      final month = br.month.toString().padLeft(2, '0');
      final year = br.year.toString();
      final hour = br.hour.toString().padLeft(2, '0');
      final min = br.minute.toString().padLeft(2, '0');
      return "$day/$month/$year $hour:$min";
    } catch (e) {
      return ts;
    }
  }

  Future<void> _viewOneTime(Message m) async {
    final fake = _getFakeProfile(m.id);

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text("${fake['name']} (visualização única)"),
        content: Text(m.text),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Fechar"),
          ),
        ],
      ),
    );

    try {
      await ApiService.markAsOpened(m.id);
      setState(() {
        final idx = msgs.indexWhere((x) => x.id == m.id);
        if (idx != -1) msgs[idx] = msgs[idx].copyWith(opened: true);
      });
    } catch (e) {
      print("Erro ao marcar como aberta: $e");
    }
  }

  Future<void> _logout() async {
    await AuthService.logout();
    if (!mounted) return;
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    if (_connecting) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 12),
              Text("Conectando à sala..."),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Sala da comunidade"),
        actions: [
          if (role == "PessoaB")
            IconButton(
              icon: const Icon(Icons.warning, color: Colors.red),
              onPressed: () async {
                await signalRService.invokeForceGoHome("PessoaA");
              },
            ),
          IconButton(
            icon: const Icon(Icons.delete_forever),
            onPressed: () async {
              final confirm = await showDialog(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text("Apagar tudo?"),
                  content: const Text("Isso vai apagar TODAS as mensagens."),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text("Cancelar")),
                    TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text("Apagar"))
                  ],
                ),
              );
              if (confirm == true) {
                await ApiService.clearMessages();
                await signalRService.invokeClearMessages();
                setState(() => msgs.clear());
              }
            },
          ),
          IconButton(icon: const Icon(Icons.logout), onPressed: _logout),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollCtrl,
              padding: const EdgeInsets.all(12),
              itemCount: msgs.length,
              itemBuilder: (context, index) {
                final m = msgs[index];
                final isMine = m.sender == sender;
                final fake = _getFakeProfile(m.id);

                if (m.oneTimeView) {
                  return Align(
                    alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      constraints: BoxConstraints(
                        maxWidth: MediaQuery.of(context).size.width * 0.7,
                      ),
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      decoration: BoxDecoration(
                        color: isMine ? Colors.orange.shade200 : Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(fake["name"],
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, color: fake["color"])),
                          const SizedBox(height: 6),
                          if (m.opened)
                            const Text("Visualização única aberta",
                                style: TextStyle(
                                    fontStyle: FontStyle.italic,
                                    fontWeight: FontWeight.w600))
                          else if (isMine)
                            const Text("Visualização única enviada",
                                style: TextStyle(fontStyle: FontStyle.italic))
                          else
                            ElevatedButton(
                              onPressed: () => _viewOneTime(m),
                              child: const Text("Ver agora (única)"),
                            ),
                          if (m.opened || isMine)
                            Align(
                              alignment: Alignment.bottomRight,
                              child: Text(
                                formatTimestamp(m.timestamp),
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: Colors.black54,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                }

                return Align(
                  alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.7,
                    ),
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    decoration: BoxDecoration(
                      color: isMine ? Colors.orange.shade200 : Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(fake["name"],
                            style: TextStyle(
                                color: fake["color"], fontWeight: FontWeight.bold)),
                        const SizedBox(height: 6),
                        Text(m.text),
                        const SizedBox(height: 4),
                        Align(
                          alignment: Alignment.bottomRight,
                          child: Text(
                            formatTimestamp(m.timestamp),
                            style: const TextStyle(
                              fontSize: 10,
                              color: Colors.black54,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: msgCtrl,
                    decoration: const InputDecoration(
                        hintText: "Mensagem", border: InputBorder.none),
                  ),
                ),
                IconButton(
                  icon: _loading
                      ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                      : const Icon(Icons.send),
                  onPressed: _loading ? null : () => send(false),
                ),
                IconButton(
                  icon: const Icon(Icons.lock),
                  onPressed: _loading ? null : () => send(true),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
