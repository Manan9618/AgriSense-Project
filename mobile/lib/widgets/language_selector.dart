import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_language.dart';
import '../state/language_provider.dart';

/// AppBar action: a globe icon that opens a language picker menu.
class LanguageSelector extends StatelessWidget {
  const LanguageSelector({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<LanguageProvider>();
    return PopupMenuButton<AppLanguage>(
      icon: const Icon(Icons.language),
      tooltip: provider.strings['selectLanguage'],
      initialValue: provider.language,
      onSelected: (language) =>
          context.read<LanguageProvider>().setLanguage(language),
      itemBuilder: (context) => [
        for (final language in AppLanguage.values)
          PopupMenuItem(value: language, child: Text(language.displayName)),
      ],
    );
  }
}
