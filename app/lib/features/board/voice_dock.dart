import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../l10n/soro_strings.dart';
import '../../theme/soro_theme.dart';
import 'board_strings.dart';
import 'tutor_script.dart';

/// Persistent bottom Voice Dock (Task A3 · Issue #11) inside the Notebook Board session.
///
/// Features:
/// - Always-worded turn cue ('Soro is speaking', 'Your turn: say it or write it',
///   or 'Listening…' when holding the voice orb).
/// - Two-line live caption strip showing the tutor's current line in English (`lang="en"`)
///   and Yorùbá (`lang="yo"`, flagged 'needs native check').
/// - Voice orb button: tap to hear Soro (recorded Spitch voice, the board writes
///   the line as it plays), tap again to stop. >= 56px target.
/// - Tap-to-hear bilingual term cards (`gbòngbò · roots`, `ibùdó · vertex`,
///   `ìlà-àárín · axis of symmetry`) with screen-reader `lang` attributes.
class VoiceDock extends StatefulWidget {
  const VoiceDock({
    super.key,
    required this.language,
    required this.networkStatus,
    required this.turnState,
    required this.captionEn,
    required this.captionYo,
    required this.onSpeak,
    this.isPlayingVoice = false,
    this.compact = false,
  });

  final SoroLanguage language;
  final SoroNetworkStatus networkStatus;
  final TutorTurnState turnState;
  final String captionEn;
  final String captionYo;

  /// Tapped to hear Soro: plays the recorded voice while the board writes the line.
  final VoidCallback onSpeak;

  /// True while a recording is playing (the orb then stops it when tapped).
  final bool isPlayingVoice;
  final bool compact;

  @override
  State<VoiceDock> createState() => _VoiceDockState();
}

class _VoiceDockState extends State<VoiceDock> {
  String? _activePlayingTermId;

  bool get _isListening => widget.turnState == TutorTurnState.listening;
  bool get _isSpeaking =>
      widget.turnState == TutorTurnState.soroSpeaking || widget.isPlayingVoice;

  String _turnCueText() {
    switch (widget.turnState) {
      case TutorTurnState.soroSpeaking:
        return BoardStrings.tr(widget.language, 'turnSoroSpeaking');
      case TutorTurnState.studentTurn:
        return BoardStrings.tr(widget.language, 'turnStudent');
      case TutorTurnState.listening:
        return BoardStrings.tr(widget.language, 'turnListening');
    }
  }

  String _mascotAsset() {
    switch (widget.turnState) {
      case TutorTurnState.soroSpeaking:
        return 'assets/mascot/soro-ilu-speaking.svg';
      case TutorTurnState.studentTurn:
        return 'assets/mascot/soro-ilu-encouraging.svg';
      case TutorTurnState.listening:
        return 'assets/mascot/soro-ilu-listening.svg';
    }
  }

  void _handleTermTap(BilingualTermCardData card) {
    setState(() {
      _activePlayingTermId = _activePlayingTermId == card.id ? null : card.id;
    });
  }

  @override
  Widget build(BuildContext context) {
    final String turnText = _turnCueText();
    final Color turnBg = _isListening
        ? SoroTokens.blush
        : (_isSpeaking ? SoroTokens.sky : SoroTokens.sun);

    return Semantics(
      container: true,
      label: 'Voice tutor dock, turn state, live bilingual captions, and term cards',
      child: Container(
        key: const Key('board-voice-dock'),
        padding: EdgeInsets.symmetric(
          horizontal: widget.compact ? SoroTokens.s12 : SoroTokens.s16,
          vertical: widget.compact ? SoroTokens.s8 : SoroTokens.s12,
        ),
        decoration: const BoxDecoration(
          color: Color(0xFFF3F7FC),
          border: Border(top: BorderSide(color: Color(0xFFC4D6EC), width: 1.5)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Row 1: Turn cue pill + Bilingual caption strip + Voice Orb
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Wrap(
                        spacing: SoroTokens.s8,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          // Always-worded turn cue
                          Semantics(
                            liveRegion: true,
                            label: 'Turn status: $turnText',
                            child: Container(
                              key: const Key('voice-dock-turn-cue'),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: turnBg,
                                borderRadius: BorderRadius.circular(
                                  SoroTokens.rPill,
                                ),
                                border: Border.all(
                                  color: SoroTokens.ink,
                                  width: 1.4,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    _isListening
                                        ? Icons.graphic_eq_rounded
                                        : (_isSpeaking
                                              ? Icons.record_voice_over_rounded
                                              : Icons.edit_note_rounded),
                                    size: 15,
                                    color: SoroTokens.ink,
                                  ),
                                  const SizedBox(width: 5),
                                  Flexible(
                                    child: Text(
                                      turnText,
                                      style: SoroTokens.sans(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w700,
                                        color: SoroTokens.ink,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          // Yorùbá native check flag pill
                          Container(
                            key: const Key('dock-native-check-flag'),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: SoroTokens.sticky,
                              borderRadius: BorderRadius.circular(
                                SoroTokens.rPill,
                              ),
                              border: Border.all(color: SoroTokens.control),
                            ),
                            child: Text(
                              BoardStrings.nativeCheckNotice,
                              style: SoroTokens.sans(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: SoroTokens.ink,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      // Two-line caption strip (English + Yorùbá)
                      Container(
                        key: const Key('voice-dock-captions'),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: SoroTokens.paper,
                          borderRadius: BorderRadius.circular(SoroTokens.rSm),
                          border: Border.all(color: SoroTokens.line),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SoroLocalizedText(
                              'EN: ${widget.captionEn}',
                              key: const Key('caption-line-en'),
                              language: SoroLanguage.en,
                              style: SoroTokens.sans(
                                fontSize: widget.compact ? 13 : 14,
                                fontWeight: FontWeight.w600,
                                color: SoroTokens.ink,
                              ),
                            ),
                            const SizedBox(height: 2),
                            SoroLocalizedText(
                              'YO: ${widget.captionYo}',
                              key: const Key('caption-line-yo'),
                              language: SoroLanguage.yo,
                              style: SoroTokens.sans(
                                fontSize: widget.compact ? 12.5 : 13.5,
                                fontWeight: FontWeight.w500,
                                color: SoroTokens.crimsonDeep,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: SoroTokens.s12),
                // Voice Orb Button (tap-and-hold shows 'Listening…', >= 56px target)
                _buildVoiceOrbButton(),
              ],
            ),
            const SizedBox(height: 8),
            // Row 2: Tap-to-hear bilingual term cards
            Wrap(
              spacing: 8,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  BoardStrings.tr(widget.language, 'termCardsHeading'),
                  style: SoroTokens.sans(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: SoroTokens.ink2,
                  ),
                ),
                for (final BilingualTermCardData card in kQuadraticTermCards)
                  _BilingualTermChip(
                    key: Key('term-card-${card.id}'),
                    card: card,
                    isPlaying: _activePlayingTermId == card.id,
                    onTap: () => _handleTermTap(card),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVoiceOrbButton() {
    final String action = widget.isPlayingVoice ? 'Tap to stop' : 'Tap to hear Soro';

    return Semantics(
      button: true,
      toggled: widget.isPlayingVoice,
      label: 'Voice orb. $action',
      child: GestureDetector(
        key: const Key('voice-orb-button'),
        onTap: widget.onSpeak,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 64, minHeight: 64),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: SoroTokens.mFast,
                width: 56,
                height: 56,
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.isPlayingVoice
                      ? SoroTokens.crimsonDeep
                      : SoroTokens.crimson,
                  border: Border.all(
                    color: widget.isPlayingVoice
                        ? SoroTokens.sun
                        : SoroTokens.paper,
                    width: widget.isPlayingVoice ? 3.0 : 2.0,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: SoroTokens.crimson.withValues(
                        alpha: widget.isPlayingVoice ? 0.42 : 0.25,
                      ),
                      blurRadius: widget.isPlayingVoice ? 16 : 10,
                      spreadRadius: widget.isPlayingVoice ? 3 : 0,
                    ),
                  ],
                ),
                child: ExcludeSemantics(
                  child: SvgPicture.asset(
                    widget.isPlayingVoice
                        ? 'assets/mascot/soro-ilu-speaking.svg'
                        : _mascotAsset(),
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              const SizedBox(height: 3),
              Text(
                action,
                style: SoroTokens.sans(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: widget.isPlayingVoice
                      ? SoroTokens.crimsonDeep
                      : SoroTokens.ink2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BilingualTermChip extends StatelessWidget {
  const _BilingualTermChip({
    super.key,
    required this.card,
    required this.isPlaying,
    required this.onTap,
  });

  final BilingualTermCardData card;
  final bool isPlaying;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: isPlaying,
      label:
          'Bilingual term card: ${card.termYo} in Yorùbá, ${card.termEn} in English. Tap to hear pronunciation.',
      child: Material(
        color: isPlaying ? SoroTokens.sun : SoroTokens.sticky,
        borderRadius: BorderRadius.circular(SoroTokens.rSm),
        child: InkWell(
          borderRadius: BorderRadius.circular(SoroTokens.rSm),
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(
              minHeight: SoroTokens.minTapTarget,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(SoroTokens.rSm),
              border: Border.all(
                color: isPlaying ? SoroTokens.ink : SoroTokens.control,
                width: isPlaying ? 1.8 : 1.2,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isPlaying
                      ? Icons.volume_up_rounded
                      : Icons.play_arrow_rounded,
                  size: 16,
                  color: SoroTokens.crimsonDeep,
                ),
                const SizedBox(width: 4),
                SoroLocalizedText(
                  card.termYo,
                  language: SoroLanguage.yo,
                  style: SoroTokens.sans(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: SoroTokens.crimsonDeep,
                  ),
                ),
                Text(
                  ' · ',
                  style: SoroTokens.sans(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: SoroTokens.ink2,
                  ),
                ),
                SoroLocalizedText(
                  card.termEn,
                  language: SoroLanguage.en,
                  style: SoroTokens.sans(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: SoroTokens.ink,
                  ),
                ),
                if (isPlaying) ...[
                  const SizedBox(width: 6),
                  Text(
                    '(${card.phoneticHint})',
                    style: SoroTokens.sans(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: SoroTokens.ink,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
