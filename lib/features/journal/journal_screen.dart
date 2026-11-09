import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/theme.dart';
import '../../data/app_database.dart';
import '../../data/format.dart';
import '../../data/models.dart';
import '../../data/providers.dart';
import '../../shared/widgets.dart';

class JournalScreen extends ConsumerStatefulWidget {
  const JournalScreen({super.key});
  @override
  ConsumerState<JournalScreen> createState() => _JournalScreenState();
}

class _JournalScreenState extends ConsumerState<JournalScreen> {
  String mood = 'Calm';
  final note = TextEditingController();

  @override
  void dispose() {
    note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final text = note.text.trim();
    await AppDatabase.instance.insertJournal(
      JournalEntry(createdAt: DateTime.now(), mood: mood, note: text),
    );
    note.clear();
    ref.invalidate(journalProvider);
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Saved')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final entries = ref.watch(journalProvider).maybeWhen(
          data: (l) => l,
          orElse: () => <JournalEntry>[],
        );

    return ListView(padding: const EdgeInsets.all(22), children: [
      const Text('Journal', style: TextStyle(fontSize: 28, fontFamily: 'serif')),
      const Text('Optional. Skip anytime.', style: TextStyle(color: AppColors.muted)),
      const SizedBox(height: 16),
      AppCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SectionLabel('How did you feel?'),
          Wrap(spacing: 8, children: [
            for (final m in ['Calm', 'Restless', 'Sleepy', 'Neutral'])
              ChoiceChip(
                label: Text(m),
                selected: mood == m,
                onSelected: (_) => setState(() => mood = m),
              ),
          ]),
          const SizedBox(height: 12),
          TextField(
            controller: note,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Note',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: OutlinedButton(onPressed: () => note.clear(), child: const Text('Skip'))),
            const SizedBox(width: 8),
            Expanded(child: FilledButton(onPressed: _save, child: const Text('Save'))),
          ]),
        ]),
      ),
      const Text(
        'Private. Stored on this device, separate from camera measurements. You can view or delete entries.',
        style: TextStyle(color: AppColors.muted, fontSize: 12),
      ),
      const SizedBox(height: 12),
      AppCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SectionLabel('Past entries'),
          if (entries.isEmpty)
            const Text('No entries yet.', style: TextStyle(color: AppColors.muted)),
          for (final e in entries)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${fmtDate(e.createdAt)} · ${e.mood}',
                        style: const TextStyle(color: AppColors.muted, fontSize: 12)),
                    if (e.note.isNotEmpty) Text(e.note),
                  ]),
                ),
                IconButton(
                  tooltip: 'Delete entry',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () async {
                    if (await confirmDialog(context, 'Delete entry?', 'This cannot be undone.')) {
                      await AppDatabase.instance.deleteJournal(e.id!);
                      ref.invalidate(journalProvider);
                    }
                  },
                ),
              ]),
            ),
        ]),
      ),
    ]);
  }
}