import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focus_sessions/models/focus_timer_state.dart';
import 'package:focus_sessions/models/session.dart';
import 'package:focus_sessions/providers/focus_timer_provider.dart';
import 'package:focus_sessions/screens/history_screen.dart';

/// Shows whichever step the timer is in.
///
/// The view is chosen from the timer state rather than pushed as a dialog,
/// so the note step still appears if a session finishes while another screen
/// is open.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(focusTimerProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Focus Sessions'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'History',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const HistoryScreen()),
            ),
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: switch (state) {
            TimerIdle() => const _LengthPicker(),
            TimerRunning() => _Countdown(state: state),
            TimerEnded() => const _NoteForm(),
          },
        ),
      ),
    );
  }
}

class _LengthPicker extends ConsumerWidget {
  const _LengthPicker();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Start a focus session',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 16),
        for (final length in FocusLength.values)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: FilledButton(
              onPressed: () =>
                  ref.read(focusTimerProvider.notifier).start(length),
              child: Text('${length.minutes} min'),
            ),
          ),
      ],
    );
  }
}

class _Countdown extends ConsumerWidget {
  const _Countdown({required this.state});

  final TimerRunning state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          _formatSeconds(state.remainingSeconds),
          style: Theme.of(context).textTheme.displayLarge,
        ),
        const SizedBox(height: 24),
        OutlinedButton(
          onPressed: () => ref.read(focusTimerProvider.notifier).end(),
          child: const Text('End Session'),
        ),
      ],
    );
  }

  static String _formatSeconds(int totalSeconds) {
    final minutes = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}

class _NoteForm extends ConsumerStatefulWidget {
  const _NoteForm();

  @override
  ConsumerState<_NoteForm> createState() => _NoteFormState();
}

class _NoteFormState extends ConsumerState<_NoteForm> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    try {
      await ref.read(focusTimerProvider.notifier).saveNote(_controller.text);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save the session. Try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Session ended',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _controller,
          maxLines: 1,
          decoration: const InputDecoration(
            labelText: 'Note (optional)',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: _save,
          child: const Text('Save'),
        ),
      ],
    );
  }
}
