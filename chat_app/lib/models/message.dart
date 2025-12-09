// models/message.dart
class Message {
  final String id;
  final String sender;
  final String text;
  final bool oneTimeView;
  final bool opened;

  Message({
    required this.id,
    required this.sender,
    required this.text,
    required this.oneTimeView,
    required this.opened,
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
      sender: json['sender'] ?? "unknown",
      text: json['text'] ?? "",
      oneTimeView: json['oneTimeView'] ?? false,
      opened: json['opened'] ?? false,
    );
  }

  Map<String, dynamic> toDto() {
    return {
      "id": id,
      "sender": sender,
      "text": text,
      "oneTimeView": oneTimeView,
      "opened": opened,
    };
  }

  Message copyWith({
    String? id,
    String? sender,
    String? text,
    bool? singleView,
    bool? opened,
  }) {
    return Message(
      id: id ?? this.id,
      sender: sender ?? this.sender,
      text: text ?? this.text,
      oneTimeView: singleView ?? this.oneTimeView,
      opened: opened ?? this.opened,
    );
  }
}
