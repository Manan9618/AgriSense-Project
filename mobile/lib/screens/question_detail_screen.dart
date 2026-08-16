import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/community_question.dart';
import '../services/community_qa_provider.dart';
import '../state/language_provider.dart';
import '../theme/app_theme.dart';

/// One community question with its answers, and a form to post a new one
/// (Week 14, CommunityQARouter). Always fetches fresh from the backend on
/// load rather than trusting a possibly-stale object passed in — this is
/// also where a just-created question's auto-suggested answer (if any)
/// first becomes visible.
class QuestionDetailScreen extends StatefulWidget {
  const QuestionDetailScreen({
    super.key,
    required this.questionId,
    required this.communityQAProvider,
    required this.deviceId,
  });

  final String questionId;
  final CommunityQAProvider communityQAProvider;
  final String deviceId;

  @override
  State<QuestionDetailScreen> createState() => _QuestionDetailScreenState();
}

class _QuestionDetailScreenState extends State<QuestionDetailScreen> {
  late Future<CommunityQuestion> _questionFuture;
  final _answerController = TextEditingController();
  bool _isPosting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _questionFuture = widget.communityQAProvider.getQuestion(
      widget.questionId,
    );
  }

  @override
  void dispose() {
    _answerController.dispose();
    super.dispose();
  }

  Future<void> _postAnswer() async {
    final body = _answerController.text.trim();
    if (body.isEmpty || _isPosting) return;

    setState(() {
      _isPosting = true;
      _error = null;
    });
    try {
      await widget.communityQAProvider.postAnswer(
        questionId: widget.questionId,
        deviceId: widget.deviceId,
        body: body,
      );
      _answerController.clear();
      if (!mounted) return;
      setState(() {
        _questionFuture = widget.communityQAProvider.getQuestion(
          widget.questionId,
        );
      });
    } on CommunityQAException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _isPosting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.watch<LanguageProvider>().strings;

    return Scaffold(
      appBar: AppBar(title: Text(strings['communityTab'])),
      body: FutureBuilder<CommunityQuestion>(
        future: _questionFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('${snapshot.error}'));
          }
          final question = snapshot.data!;
          return Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Text(
                      question.title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (question.body.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(question.body),
                    ],
                    const SizedBox(height: 16),
                    Text(
                      strings['answers'],
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (question.answers.isEmpty)
                      Text(
                        strings['noAnswersYet'],
                        style: const TextStyle(color: Colors.black54),
                      )
                    else
                      for (final answer in question.answers)
                        _AnswerTile(answer: answer, strings: strings),
                  ],
                ),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: AppTheme.highUrgency),
                  ),
                ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _answerController,
                          decoration: InputDecoration(
                            hintText: strings['writeAnswerHint'],
                            border: const OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _isPosting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : IconButton(
                              icon: const Icon(Icons.send),
                              onPressed: _postAnswer,
                            ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _AnswerTile extends StatelessWidget {
  const _AnswerTile({required this.answer, required this.strings});

  final CommunityAnswer answer;
  final dynamic strings;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: answer.isAutoSuggested ? AppTheme.lightGreenBg : null,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (answer.isAutoSuggested)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  strings['autoSuggested'],
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryGreen,
                  ),
                ),
              ),
            Text(answer.body),
          ],
        ),
      ),
    );
  }
}
