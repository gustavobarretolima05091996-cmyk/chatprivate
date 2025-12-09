import 'dart:math';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/message.dart';
import '../services/auth_service.dart';

final List<String> randomNames = [
  "Lucas", "Amanda", "Bruno", "Carla", "Diego", "Elisa",
  "Felipe", "Giovana", "Henrique", "Isabela", "João", "Karina",
  "Luan", "Marina", "Nathan", "Olívia", "Paulo", "Rafaela",
  "Samuel", "Tatiane", "Victor", "Yasmin", "Thiago", "Camila",
];

// CORES PARA SIMULAR VÁRIAS PESSOAS
final List<Color> userColors = [
  Colors.blue,
  Colors.green,
  Colors.purple,
  Colors.orange,
  Colors.red,
  Colors.teal,
  Colors.indigo,
  Colors.brown,
];

// Cada mensagem terá um perfil fake fixo
Map<String, Map<String, dynamic>> fakeProfiles = {};

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController msgCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  List<Message> msgs = [];

  String? sender;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    msgCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  // Cria um usuário fake para cada mensagem
  Map<String, dynamic> _getFakeProfile(String msgId) {
    if (fakeProfiles.containsKey(msgId)) {
      return fakeProfiles[msgId]!;
    }

    randomNames.shuffle();
    userColors.shuffle();

    final newProfile = {
      "name": randomNames.first,
      "color": userColors.first,
    };

    fakeProfiles[msgId] = newProfile;
    return newProfile;
  }

  Future<void> _load() async {
    sender = await AuthService.getRole();

    if (sender == null) {
      print("ERRO: usuário não logado.");
      return;
    }

    final fetched = await ApiService.getMessages();
    setState(() => msgs = fetched);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.jumpTo(_scrollCtrl.position.maxScrollExtent);
      }
    });
  }

  Future<void> send(bool singleView) async {
    final text = msgCtrl.text.trim();
    if (text.isEmpty) return;

    setState(() => _loading = true);

    try {
      await ApiService.sendMessage(text, singleView, sender!);
      msgCtrl.clear();
      await _load();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _viewOneTime(Message m) async {
    final fake = _getFakeProfile(m.id);
    final senderName = fake['name'];

    // mostra o conteúdo
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text("$senderName (visualização única)"),
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
      // marca como aberta no backend (PUT /messages/{id}/opened)
      await ApiService.markAsOpened(m.id);

      // Atualiza localmente para refletir imediatamente a mudança sem depender só do reload
      setState(() {
        final idx = msgs.indexWhere((x) => x.id == m.id);
        if (idx != -1) msgs[idx] = msgs[idx].copyWith(opened: true);
      });

      // Se quiser recarregar do servidor (opcional)
      // await _load();
    } catch (e) {
      // tratar erro se quiser
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
                      child: const Text("Cancelar"),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text("Apagar"),
                    )
                  ],
                ),
              );

              if (confirm == true) {
                await ApiService.clearMessages();
                await _load();
              }
            },
          ),

          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
          ),
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

                // pega o fake user dessa mensagem
                final fake = _getFakeProfile(m.id);

                // VISUALIZAÇÃO ÚNICA
                if (m.singleView) {
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
                          Text(
                            fake["name"],
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: fake["color"],
                            ),
                          ),
                          const SizedBox(height: 6),

                          // AGORA MOSTRA "Visualização única aberta"
                          if (m.opened)
                            const Text(
                              "Visualização única aberta",
                              style: TextStyle(
                                fontStyle: FontStyle.italic,
                                fontWeight: FontWeight.w600,
                              ),
                            )

                          // Se for minha mensagem e ainda não abriu
                          else if (isMine)
                            const Text(
                              "Visualização única enviada",
                              style: TextStyle(fontStyle: FontStyle.italic),
                            )

                          // Se for do outro e ainda não abriu
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

                // MENSAGEM NORMAL
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
                        Text(
                          fake["name"],
                          style: TextStyle(
                            color: fake["color"],
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(m.text),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // CAMPO DE DIGITAÇÃO
          const Divider(height: 1),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: msgCtrl,
                    decoration: const InputDecoration(
                      hintText: "Mensagem",
                      border: InputBorder.none,
                    ),
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
