import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/community_question.dart';
import '../services/community_qa_provider.dart';
import '../state/language_provider.dart';
import '../theme/app_theme.dart';
import 'question_detail_screen.dart';

/// Crop/symptom option labels shown in the "Ask a Question" form. English
/// only, deliberately — same tradeoff already accepted for
/// PriceComparisonScreen's crop dropdown (Week 7); these are option labels
/// for a fixed 3-choice picker, not narrative UI chrome, and their
/// underlying values (backend/core/constants.py's CropChoice/SymptomChoice)
/// are what actually drives CommunityQARouter's lookup.
const _cropOptions = {
  'potato': 'Potato',
  'pepper_bell': 'Pepper (bell)',
  'tomato': 'Tomato',
};

const _symptomOptions = {
  'spots': 'Spots / blight',
  'wilting': 'Wilting / fast-spreading',
  'healthy': 'Looks healthy',
};

/// Community Q&A tab (Week 14, CommunityQARouter — docs/classes.md):
/// browse questions, ask a new one, and see CommunityQARouter's
/// auto-suggested answer immediately if the crop+symptom tags match known
/// treatment content.
class CommunityScreen extends StatefulWidget {
  const CommunityScreen({
    super.key,
    required this.communityQAProvider,
    required this.deviceId,
  });

  final CommunityQAProvider communityQAProvider;
  final String deviceId;

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> {
  late Future<List<CommunityQuestion>> _questionsFuture;

  @override
  void initState() {
    super.initState();
    _questionsFuture = widget.communityQAProvider.listQuestions();
  }

  void _refresh() {
    setState(() {
      _questionsFuture = widget.communityQAProvider.listQuestions();
    });
  }

  Future<void> _openQuestion(String id) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => QuestionDetailScreen(
          questionId: id,
          communityQAProvider: widget.communityQAProvider,
          deviceId: widget.deviceId,
        ),
      ),
    );
    _refresh();
  }

  Future<void> _askQuestion() async {
    final language = context.read<LanguageProvider>().language.code;
    final created = await showModalBottomSheet<CommunityQuestion>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _AskQuestionSheet(
        communityQAProvider: widget.communityQAProvider,
        deviceId: widget.deviceId,
        language: language,
      ),
    );
    if (created == null || !mounted) return;
    await _openQuestion(created.id);
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.watch<LanguageProvider>().strings;

    return Scaffold(
      appBar: AppBar(title: Text(strings['communityTab'])),
      body: FutureBuilder<List<CommunityQuestion>>(
        future: _questionsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('${snapshot.error}'));
          }
          final questions = snapshot.data!;
          if (questions.isEmpty) {
            return Center(child: Text(strings['communityNoQuestions']));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: questions.length,
            itemBuilder: (context, index) {
              final question = questions[index];
              return Card(
                child: ListTile(
                  title: Text(question.title),
                  subtitle: question.crop.isEmpty
                      ? null
                      : Text(_cropOptions[question.crop] ?? question.crop),
                  onTap: () => _openQuestion(question.id),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _askQuestion,
        icon: const Icon(Icons.add),
        label: Text(strings['askQuestion']),
      ),
    );
  }
}

class _AskQuestionSheet extends StatefulWidget {
  const _AskQuestionSheet({
    required this.communityQAProvider,
    required this.deviceId,
    required this.language,
  });

  final CommunityQAProvider communityQAProvider;
  final String deviceId;
  final String language;

  @override
  State<_AskQuestionSheet> createState() => _AskQuestionSheetState();
}

class _AskQuestionSheetState extends State<_AskQuestionSheet> {
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  String? _crop;
  String? _symptom;
  bool _isPosting = false;
  String? _error;

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final title = _titleController.text.trim();
    if (title.isEmpty || _isPosting) return;

    setState(() {
      _isPosting = true;
      _error = null;
    });
    try {
      final question = await widget.communityQAProvider.postQuestion(
        deviceId: widget.deviceId,
        crop: _crop ?? '',
        symptom: _symptom ?? '',
        title: title,
        body: _bodyController.text.trim(),
        language: widget.language,
      );
      if (mounted) Navigator.of(context).pop(question);
    } on CommunityQAException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _isPosting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.watch<LanguageProvider>().strings;

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _titleController,
              decoration: InputDecoration(
                labelText: strings['questionTitleHint'],
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _bodyController,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: strings['questionDetailsHint'],
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _crop,
              decoration: InputDecoration(labelText: strings['cropOptional']),
              items: [
                for (final entry in _cropOptions.entries)
                  DropdownMenuItem(value: entry.key, child: Text(entry.value)),
              ],
              onChanged: (value) => setState(() => _crop = value),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _symptom,
              decoration: InputDecoration(
                labelText: strings['symptomOptional'],
              ),
              items: [
                for (final entry in _symptomOptions.entries)
                  DropdownMenuItem(value: entry.key, child: Text(entry.value)),
              ],
              onChanged: (value) => setState(() => _symptom = value),
            ),
            const SizedBox(height: 16),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  _error!,
                  style: const TextStyle(color: AppTheme.highUrgency),
                ),
              ),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isPosting ? null : _submit,
                child: _isPosting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(strings['post']),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
