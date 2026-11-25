import 'dart:convert';

import 'package:http/http.dart' as http;

/// Base URL of the tutor API. Override with `--dart-define=SORO_API=http://host:port`.
/// The default is the loopback address, reachable on a tablet through
/// `adb reverse tcp:8000 tcp:8000`.
const String kSoroApiBase =
    String.fromEnvironment('SORO_API', defaultValue: 'http://127.0.0.1:8000');

/// Per-request timeout; slower than this and the app falls back to the script.
const Duration kTutorTimeout = Duration(seconds: 6);

enum TutorMode { guide, solve }

/// Thrown for any failure the caller should answer with the scripted tutor.
class TutorClientException implements Exception {
  const TutorClientException(this.message);
  final String message;
  @override
  String toString() => 'TutorClientException: $message';
}

/// One board operation from `POST /tutor/turn`: `write`, `blank` or `mark`.
class BoardOp {
  const BoardOp({required this.op, this.text = '', this.kind, this.target});

  final String op;
  final String text;
  final String? kind;
  final String? target;
}

class TutorTurnResponse {
  const TutorTurnResponse({
    required this.sessionId,
    required this.stepId,
    required this.say,
    required this.board,
    required this.analogy,
    required this.done,
    required this.source,
  });

  final String sessionId;
  final String stepId;
  final String say;
  final List<BoardOp> board;
  final String analogy;
  final bool done;
  final String source;

  /// Throws [TutorClientException] when [body] is not a valid turn reply.
  factory TutorTurnResponse.parse(String body) {
    final Object? decoded;
    try {
      decoded = jsonDecode(body);
    } on FormatException {
      throw const TutorClientException('invalid JSON');
    }
    if (decoded is! Map<String, dynamic>) {
      throw const TutorClientException('reply is not an object');
    }
    final Object? say = decoded['say'];
    final Object? board = decoded['board'];
    if (say is! String || board is! List) {
      throw const TutorClientException('missing say or board');
    }
    final List<BoardOp> ops = <BoardOp>[];
    for (final Object? raw in board) {
      if (raw is! Map<String, dynamic> || raw['op'] is! String) {
        throw const TutorClientException('bad board op');
      }
      ops.add(
        BoardOp(
          op: raw['op'] as String,
          text: raw['text'] is String ? raw['text'] as String : '',
          kind: raw['kind'] is String ? raw['kind'] as String : null,
          target: raw['target'] is String ? raw['target'] as String : null,
        ),
      );
    }
    return TutorTurnResponse(
      sessionId: decoded['session_id'] is String
          ? decoded['session_id'] as String
          : '',
      stepId: decoded['step_id'] is String ? decoded['step_id'] as String : '',
      say: say,
      board: ops,
      analogy: decoded['analogy'] is String ? decoded['analogy'] as String : '',
      done: decoded['done'] == true,
      source: decoded['source'] is String ? decoded['source'] as String : '',
    );
  }
}

/// Client for `POST /tutor/turn` (issue #39).
class TutorClient {
  TutorClient({
    http.Client? httpClient,
    String baseUrl = kSoroApiBase,
    this.timeout = kTutorTimeout,
  })  : _http = httpClient ?? http.Client(),
        _base = baseUrl.endsWith('/')
            ? baseUrl.substring(0, baseUrl.length - 1)
            : baseUrl;

  final http.Client _http;
  final String _base;
  final Duration timeout;

  Future<TutorTurnResponse> turn({
    required String sessionId,
    required String lang,
    required TutorMode mode,
    required String text,
    String? problem,
    String? stepId,
  }) async {
    final Map<String, Object> payload = <String, Object>{
      'session_id': sessionId,
      'lang': lang,
      'mode': mode.name,
      'text': text,
      if (problem != null && problem.isNotEmpty) 'problem': problem,
      if (stepId != null && stepId.isNotEmpty) 'step_id': stepId,
    };
    try {
      final http.Response res = await _http
          .post(
            Uri.parse('$_base/tutor/turn'),
            headers: const <String, String>{
              'Content-Type': 'application/json',
            },
            body: jsonEncode(payload),
          )
          .timeout(timeout);
      if (res.statusCode != 200) {
        throw TutorClientException('HTTP ${res.statusCode}');
      }
      return TutorTurnResponse.parse(utf8.decode(res.bodyBytes));
    } on TutorClientException {
      rethrow;
    } catch (e) {
      // Timeout, socket, TLS or decode errors all mean the same thing here.
      throw TutorClientException('$e');
    }
  }

  void close() => _http.close();
}

final RegExp _solveIntent = RegExp(
  r"\b(solve (this|it|that) for me|just solve|please solve (this|it)|"
  r"show me how|show me the (solution|working|answer)|"
  r"(do|work) (it|this) (out )?for me|work it out|full (solution|working)|"
  r"give me the (solution|answer))",
  caseSensitive: false,
);

/// True when the student asked Soro to solve it rather than to guide them.
/// "How do I solve ..." is a question for guidance and stays in guide mode.
bool wantsSolve(String text) => _solveIntent.hasMatch(text);
