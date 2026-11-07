import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focus_sessions/models/session.dart';
import 'package:focus_sessions/providers/session_history_provider.dart';
import 'package:intl/intl.dart';

/// Lists saved sessions, newest first, with swipe to delete.
class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(sessionHistoryProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('History')),
      body: history.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const Center(child: Text('Could not load sessions.')),
        data: (sessions) => sessions.isEmpty
            ? const Center(child: Text('No sessions yet.'))
            : ListView.builder(
                itemCount: sessions.length,
                itemBuilder: (context, index) =>
                    _SessionRow(session: sessions[index]),
              ),
      ),
    );
  }
}

class _SessionRow extends ConsumerWidget {
  const _SessionRow({required this.session});

  final Session session;

  /// Called from onDismissed. The call to deleteSession removes the row from
  /// state before it first awaits, as Dismissible requires.
  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    // Read now: the screen may have been closed by the time storage fails.
    final messenger = ScaffoldMessenger.of(context);
    final notifier = ref.read(sessionHistoryProvider.notifier);
    try {
      await notifier.deleteSession(
        session,
        // A row restored before the next frame would reuse the dismissed
        // element, and Flutter would throw. Let the removal build first.
        beforeRestore: () => WidgetsBinding.instance.endOfFrame,
      );
    } catch (error, stack) {
      // Reported as well as shown, so a real bug is not hidden behind the
      // SnackBar.
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stack,
          library: 'focus_sessions',
          context: ErrorDescription('while deleting a session'),
        ),
      );
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not delete the session.')),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final planned = session.plannedLength.minutes;
    final actual = _formatDuration(session.actualDuration);
    return Dismissible(
      key: ValueKey(session.startTime),
      direction: DismissDirection.endToStart,
      background: const ColoredBox(
        color: Colors.red,
        child: Align(
          alignment: Alignment.centerRight,
          child: Padding(
            padding: EdgeInsets.only(right: 24),
            child: Icon(Icons.delete, color: Colors.white),
          ),
        ),
      ),
      onDismissed: (_) => _delete(context, ref),
      child: ListTile(
        title: Text(DateFormat.yMMMd().format(session.startTime.toLocal())),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Planned $planned min · Actual $actual'),
            if (session.note.isNotEmpty) Text(session.note),
          ],
        ),
      ),
    );
  }

  static String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds.remainder(60);
    if (minutes == 0) return '$seconds sec';
    if (seconds == 0) return '$minutes min';
    return '$minutes min $seconds sec';
  }
}
