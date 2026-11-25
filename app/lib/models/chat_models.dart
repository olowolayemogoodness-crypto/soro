import '../l10n/soro_strings.dart';

enum ChatSender {
  tutor,
  student,
}

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.sender,
    required this.text,
    this.bilingualNote,
    this.opensBoard = false,
    this.inputMethodLabel,
    this.language = SoroLanguage.en,
  });

  final String id;
  final ChatSender sender;
  final String text;
  final String? bilingualNote;
  final bool opensBoard;
  final String? inputMethodLabel;
  final SoroLanguage language;
}

class SuggestedTopic {
  const SuggestedTopic({
    required this.id,
    required this.titleKey,
    required this.promptKey,
    required this.tagKey,
  });

  final String id;
  final String titleKey;
  final String promptKey;
  final String tagKey;
}
