import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import 'features/graph_friction/graph_friction_screen.dart';
import 'features/progress/progress_screen.dart';
import 'features/progress/progress_strings.dart';
import 'l10n/soro_strings.dart';
import 'models/chat_models.dart';
import 'screens/home_screen.dart';
import 'screens/placeholder_screens.dart';
import 'theme/soro_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SemanticsBinding.instance.ensureSemantics();
  runApp(const SoroApp());
}

/// Top-level route identifiers for Sọ̀rọ̀ app shell.
enum SoroRoute {
  home('/'),
  board('/board'),
  progress('/progress'),
  graphFriction(kGraphFrictionRoute);

  const SoroRoute(this.path);
  final String path;
}

class SoroApp extends StatefulWidget {
  const SoroApp({super.key});

  @override
  State<SoroApp> createState() => _SoroAppState();
}

class _SoroAppState extends State<SoroApp> {
  SoroLanguage _language = SoroLanguage.en;
  SoroNetworkStatus _networkStatus = SoroNetworkStatus.live;
  SoroRoute _activeRoute = SoroRoute.home;
  String _activeBoardQuestion = '';
  late List<ChatMessage> _messages;

  @override
  void initState() {
    super.initState();
    _messages = <ChatMessage>[
      _buildInitialGreetingMessage(_language),
    ];
  }

  ChatMessage _buildInitialGreetingMessage(SoroLanguage lang) {
    return ChatMessage(
      id: 'welcome-turn',
      sender: ChatSender.tutor,
      text: SoroStrings.tr(lang, 'initialTutorMessage'),
      bilingualNote: SoroStrings.tr(lang, 'initialTutorBilingualNote'),
      language: lang,
    );
  }

  void _handleLanguageChanged(SoroLanguage newLang) {
    setState(() {
      _language = newLang;
      if (_messages.isNotEmpty && _messages.first.id == 'welcome-turn') {
        _messages[0] = _buildInitialGreetingMessage(newLang);
      }
    });
  }

  void _handleCycleNetworkStatus() {
    setState(() {
      switch (_networkStatus) {
        case SoroNetworkStatus.live:
          _networkStatus = SoroNetworkStatus.weakSignalVoiceOnly;
        case SoroNetworkStatus.weakSignalVoiceOnly:
          _networkStatus = SoroNetworkStatus.offline;
        case SoroNetworkStatus.offline:
          _networkStatus = SoroNetworkStatus.live;
      }
    });
  }

  void _handleSubmitQuestion(
    String question, {
    String? inputMethodLabel,
  }) {
    final String trimmed = question.trim();
    if (trimmed.isEmpty) return;

    final int turnNum = _messages.length + 1;
    setState(() {
      _messages.add(
        ChatMessage(
          id: 'student-$turnNum',
          sender: ChatSender.student,
          text: trimmed,
          opensBoard: true,
          inputMethodLabel: inputMethodLabel,
          language: _language,
        ),
      );
      _messages.add(
        ChatMessage(
          id: 'tutor-${turnNum + 1}',
          sender: ChatSender.tutor,
          text: '${SoroStrings.tr(_language, 'chatTutorReplyPrefix')}$trimmed',
          opensBoard: true,
          language: _language,
        ),
      );
      _activeBoardQuestion = trimmed;
      _activeRoute = SoroRoute.board;
    });
  }

  void _handleOpenBoard(String question) {
    setState(() {
      _activeBoardQuestion = question;
      _activeRoute = SoroRoute.board;
    });
  }

  void _handleOpenMyProgress() {
    setState(() {
      _activeRoute = SoroRoute.progress;
    });
  }

  void _handleBackToHome() {
    setState(() {
      _activeRoute = SoroRoute.home;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sọ̀rọ̀',
      debugShowCheckedModeBanner: false,
      theme: SoroTokens.buildTheme(),
      routes: <String, WidgetBuilder>{
        kGraphFrictionRoute: (BuildContext context) =>
            const GraphFrictionScreen(),
      },
      home: _buildActiveScreen(),
    );
  }

  Widget _buildActiveScreen() {
    switch (_activeRoute) {
      case SoroRoute.home:
        return HomeScreen(
          language: _language,
          networkStatus: _networkStatus,
          messages: _messages,
          onLanguageChanged: _handleLanguageChanged,
          onNetworkStatusChanged: (SoroNetworkStatus status) {
            setState(() {
              _networkStatus = status;
            });
          },
          onCycleNetworkStatus: _handleCycleNetworkStatus,
          onSubmitQuestion: _handleSubmitQuestion,
          onOpenBoard: _handleOpenBoard,
          onOpenMyProgress: _handleOpenMyProgress,
        );
      case SoroRoute.board:
        return BoardPlaceholderScreen(
          language: _language,
          networkStatus: _networkStatus,
          activeQuestion: _activeBoardQuestion,
          onLanguageChanged: _handleLanguageChanged,
          onCycleNetworkStatus: _handleCycleNetworkStatus,
          onBackToChat: _handleBackToHome,
        );
      case SoroRoute.progress:
        return ProgressScreen(
          initialLang:
              _language == SoroLanguage.yo ? ProgressLang.yo : ProgressLang.en,
          onLangChanged: (ProgressLang l) => _handleLanguageChanged(
            l == ProgressLang.yo ? SoroLanguage.yo : SoroLanguage.en,
          ),
          onBack: _handleBackToHome,
        );
      case SoroRoute.graphFriction:
        return const GraphFrictionScreen();
    }
  }
}
