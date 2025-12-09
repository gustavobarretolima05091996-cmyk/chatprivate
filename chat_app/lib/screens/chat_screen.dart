import 'dart:math';
import 'package:flutter/material.dart';
import '../services/SignalRService.dart';
import '../services/api_service.dart';
import '../models/message.dart';
import '../services/auth_service.dart';

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

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController msgCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  final SignalRService signalRService = SignalRService();

  List<Message> msgs = [];
  String? sender;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _initChat();
  }

  @override
  void dispose() {
    msgCtrl.dispose();
    _scrollCtrl.dispose();
    signalRService.dispose();
    super.dispose();
  }

  Future<void> _initChat() async {
    sender = await AuthService.getRole();
    if (sender == null) return;

    await signalRService.init(sender!);

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

    // Opcional: carregar mensagens antigas do backend
    final fetched = await ApiService.getMessages();
    setState(() => msgs = fetched);
  }

  Future<void> send(bool oneTime) async {
    final text = msgCtrl.text.trim();
    if (text.isEmpty || sender == null) return;

    setState(() => _loading = true);

    final msg = Message(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      sender: sender!,
      text: text,
      oneTimeView: oneTime,
      opened: false,
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
    return Scaffold(
      appBar: AppBar(
        title: const Text("Sala da comunidade"),
        actions: [
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
                                  fontWeight: FontWeight.bold,
                                  color: fake["color"])),
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
                        ],
                      ),
                    ),
                  );
                }

                return Align(
                  alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
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
