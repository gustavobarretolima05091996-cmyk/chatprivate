class Message {
  final String id;
  final String sender;
  final String text;
  final bool oneTimeView;
  final bool opened;
  final String timestamp; // nova propriedade

  Message({
    required this.id,
    required this.sender,
    required this.text,
    required this.oneTimeView,
    required this.opened,
    required this.timestamp, // adicione no construtor
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
      sender: json['sender'] ?? "unknown",
      text: json['text'] ?? "",
      oneTimeView: json['oneTimeView'] ?? false,
      opened: json['opened'] ?? false,
      timestamp: json['timestamp'] ?? DateTime.now().toString(), // valor padrão
    );
  }

  Map<String, dynamic> toDto() {
    return {
      "id": id,
      "sender": sender,
      "text": text,
      "oneTimeView": oneTimeView,
      "opened": opened,
      "timestamp": timestamp,
    };
  }

  Message copyWith({
    String? id,
    String? sender,
    String? text,
    bool? singleView,
    bool? opened,
    String? timestamp,
  }) {
    return Message(
      id: id ?? this.id,
      sender: sender ?? this.sender,
      text: text ?? this.text,
      oneTimeView: singleView ?? this.oneTimeView,
      opened: opened ?? this.opened,
      timestamp: timestamp ?? this.timestamp,
    );
  }
}
