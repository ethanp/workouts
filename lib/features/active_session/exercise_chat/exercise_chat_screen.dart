import 'dart:async';
import 'package:ethan_ui/ethan_ui.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:workouts/features/active_session/exercise_chat/exercise_chat_prompt.dart';
import 'package:workouts/models/chat_message.dart';
import 'package:workouts/models/workout_exercise.dart';
import 'package:workouts/services/llm/llm_service.dart';

class const ExerciseChatScreen({required final WorkoutExercise exercise})
    extends ConsumerStatefulWidget {
  @override
  ConsumerState<ExerciseChatScreen> createState() => _ExerciseChatScreenState();
}

class _ExerciseChatScreenState() extends ConsumerState<ExerciseChatScreen> {
  late final String _systemPrompt;
  final List<ChatMessage> _messages = [];
  String? _streamingDraft;
  String? _streamError;

  final TextEditingController _composer = TextEditingController();
  final FocusNode _composerFocus = FocusNode();
  final ScrollController _scrollController = ScrollController();
  final http.Client _httpClient = http.Client();
  StreamSubscription<String>? _streamSubscription;

  @override
  void initState() {
    super.initState();
    _systemPrompt = const ExerciseChatPromptBuilder().buildSystemPrompt(
      widget.exercise,
    );
  }

  @override
  void dispose() {
    _streamSubscription?.cancel();
    _httpClient.close();
    _composer.dispose();
    _composerFocus.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  bool get _isStreaming => _streamingDraft != null;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: EAppHeader(title: 'Ask about: ${widget.exercise.name}'),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(child: _conversation()),
            _composerRow(),
          ],
        ),
      ),
    );
  }

  Widget _conversation() {
    if (_messages.isEmpty && !_isStreaming && _streamError == null) {
      return _emptyState();
    }
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(ELayout.spaceMd),
      itemCount: _conversationItemCount,
      itemBuilder: (context, index) => _conversationItem(index),
    );
  }

  int get _conversationItemCount {
    var count = _messages.length;
    if (_isStreaming) count += 1;
    if (_streamError != null) count += 1;
    return count;
  }

  Widget _conversationItem(int index) {
    if (index < _messages.length) return _bubble(_messages[index]);
    if (_isStreaming) return _streamingBubble();
    return _errorBubble();
  }

  Widget _emptyState() => Padding(
    padding: const EdgeInsets.all(ELayout.spaceLg),
    child: Center(
      child: Text(
        "Ask about form, benefits, modifications, or any aches you're feeling.",
        textAlign: TextAlign.center,
        style: EText.body.medium.copyWith(color: EColors.textTertiary),
      ),
    ),
  );

  Widget _bubble(ChatMessage message) {
    final isUser = message.role == ChatRole.user;
    return Padding(
      padding: const EdgeInsets.only(bottom: ELayout.spaceSm),
      child: Row(
        mainAxisAlignment: isUser
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        children: [
          Flexible(child: _bubbleContainer(message.content, isUser: isUser)),
        ],
      ),
    );
  }

  Widget _streamingBubble() => Padding(
    padding: const EdgeInsets.only(bottom: ELayout.spaceSm),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        Flexible(
          child: _bubbleContainer(
            _streamingDraft!.isEmpty ? '…' : _streamingDraft!,
            isUser: false,
          ),
        ),
      ],
    ),
  );

  Widget _errorBubble() => Padding(
    padding: const EdgeInsets.only(bottom: ELayout.spaceSm),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        Flexible(
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: ELayout.spaceMd,
              vertical: ELayout.spaceSm,
            ),
            decoration: BoxDecoration(
              color: EColors.danger.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(ELayout.radiusMd),
              border: Border.all(color: EColors.danger.withValues(alpha: 0.4)),
            ),
            child: Text(
              _streamError!,
              style: EText.body.medium.copyWith(color: EColors.danger),
            ),
          ),
        ),
      ],
    ),
  );

  Widget _bubbleContainer(String text, {required bool isUser}) => Container(
    padding: const EdgeInsets.symmetric(
      horizontal: ELayout.spaceMd,
      vertical: ELayout.spaceSm,
    ),
    decoration: BoxDecoration(
      color: isUser ? EColors.accent : EColors.backgroundLift,
      borderRadius: BorderRadius.circular(ELayout.radiusMd),
      border: isUser ? null : Border.all(color: EColors.border),
    ),
    child: Text(
      text,
      style: EText.body.medium.copyWith(
        color: isUser ? Colors.white : EColors.textPrimary,
      ),
    ),
  );

  Widget _composerRow() => Container(
    padding: const EdgeInsets.all(ELayout.spaceMd),
    decoration: BoxDecoration(
      color: EColors.backgroundLift,
      border: Border(top: BorderSide(color: EColors.border)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: TextField(
            controller: _composer,
            focusNode: _composerFocus,
            minLines: 1,
            maxLines: 4,
            textInputAction: TextInputAction.send,
            onSubmitted: (_) => _send(),
            style: EText.body.medium.copyWith(color: EColors.textPrimary),
            decoration: EInput.filledMd(hintText: 'Ask anything…'),
          ),
        ),
        const SizedBox(width: ELayout.spaceSm),
        IconButton(
          onPressed: _isStreaming ? null : _send,
          icon: Icon(
            Icons.arrow_circle_up,
            size: 32,
            color: _isStreaming ? EColors.textMuted : EColors.accent,
          ),
        ),
      ],
    ),
  );

  void _send() {
    final text = _composer.text.trim();
    if (text.isEmpty || _isStreaming) return;

    setState(() {
      _messages.add(ChatMessage(role: ChatRole.user, content: text));
      _composer.clear();
      _streamingDraft = '';
      _streamError = null;
    });
    _scrollToBottom();

    final llmService = ref.read(llmServiceProvider);
    final draftBuffer = StringBuffer();

    _streamSubscription = llmService
        .streamChat(
          systemPrompt: _systemPrompt,
          history: List.unmodifiable(_messages),
          httpClient: _httpClient,
        )
        .listen(
          (token) {
            if (!mounted) return;
            draftBuffer.write(token);
            setState(() => _streamingDraft = draftBuffer.toString());
            _scrollToBottom();
          },
          onError: (Object error) {
            if (!mounted) return;
            setState(() {
              _streamingDraft = null;
              _streamError = 'Could not reach the assistant: $error';
            });
            _scrollToBottom();
          },
          onDone: () {
            if (!mounted) return;
            final completedDraft = draftBuffer.toString();
            setState(() {
              if (completedDraft.isNotEmpty) {
                _messages.add(
                  ChatMessage(
                    role: ChatRole.assistant,
                    content: completedDraft,
                  ),
                );
              }
              _streamingDraft = null;
            });
            _scrollToBottom();
          },
          cancelOnError: true,
        );
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
      );
    });
  }
}
