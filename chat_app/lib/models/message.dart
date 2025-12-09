class Message {
  final String id;
  final String sender;
  final String text;
  final bool singleView;
  final bool opened;


  Message({
    required this.id,
    required this.sender,
    required this.text,
    required this.singleView,
    required this.opened,
  });


  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['id'],
      sender: json['sender'],
      text: json['text'],
      singleView: json['oneTimeView'],
      opened: json['opened'],
    );
  }

  Message copyWith({
    String? id,
    String? text,
    String? sender,
    bool? singleView,
    bool? opened,
  }) {
    return Message(
      id: id ?? this.id,
      text: text ?? this.text,
      sender: sender ?? this.sender,
      singleView: singleView ?? this.singleView,
      opened: opened ?? this.opened,
    );
  }

}