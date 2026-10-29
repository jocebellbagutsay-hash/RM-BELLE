import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_settings.dart';
import '../widgets/primary_button.dart';

/// Activity screen with persistent notes list powered by Provider.
class ActivityNotesScreen extends StatefulWidget {
  const ActivityNotesScreen({super.key});

  @override
  State<ActivityNotesScreen> createState() => _ActivityNotesScreenState();
}

class _ActivityNotesScreenState extends State<ActivityNotesScreen> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _addNote() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    context.read<AppSettings>().addNote(text);
    _controller.clear();
  }

  void _clearNotes() {
    context.read<AppSettings>().clearNotes();
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettings>();
    final notes = settings.notes;

    return Scaffold(
      appBar: AppBar(

      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .primaryContainer
                      .withOpacity(0.5),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.bookmark_border,
                      size: 18,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Persistent notes',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _controller,
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(
                  labelText: 'New note',
                  hintText: 'Type something, then add',
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (_) => _addNote(),
              ),
              const SizedBox(height: 12),
              LayoutBuilder(
                builder: (context, constraints) {
                  final stacked = constraints.maxWidth < 420;
                  final add = PrimaryButton(
                    label: 'Add note',
                    icon: Icons.add,
                    expanded: stacked,
                    onPressed: _addNote,
                  );
                  final clear = OutlinedButton(
                    onPressed: notes.isEmpty ? null : _clearNotes,
                    child: const Text('Clear all'),
                  );

                  if (stacked) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        add,
                        const SizedBox(height: 8),
                        clear,
                      ],
                    );
                  }

                  return Row(
                    children: [
                      Flexible(flex: 2, child: add),
                      const SizedBox(width: 12),
                      Expanded(child: clear),
                    ],
                  );
                },
              ),
              const SizedBox(height: 16),
              Expanded(
                child: notes.isEmpty
                    ? Center(
                        child: Text(
                          'No notes yet. Add one above to persist across activities!',
                          style: Theme.of(context).textTheme.bodyLarge,
                          textAlign: TextAlign.center,
                        ),
                      )
                    : ListView.separated(
                        itemCount: notes.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          return Card(
                            child: ListTile(
                              leading: const Icon(Icons.sticky_note_2_outlined),
                              title: Text(notes[index]),
                              trailing: IconButton(
                                icon: const Icon(Icons.close, size: 18),
                                tooltip: 'Delete note',
                                onPressed: () {
                                  context
                                      .read<AppSettings>()
                                      .removeNoteAt(index);
                                },
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
