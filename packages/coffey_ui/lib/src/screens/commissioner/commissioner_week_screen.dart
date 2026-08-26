import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../models/week_model.dart';
import '../../repositories/week_repository.dart';
import '../../widgets/error_state_view.dart';
import '../../widgets/responsive_content.dart';

/// Read-only detail view of a single week's published games — a simple
/// fetch-and-display screen, so it uses a plain FutureBuilder rather than a
/// dedicated BLoC.
class CommissionerWeekScreen extends StatefulWidget {
  const CommissionerWeekScreen({super.key, required this.weekId});

  final String weekId;

  @override
  State<CommissionerWeekScreen> createState() => _CommissionerWeekScreenState();
}

class _CommissionerWeekScreenState extends State<CommissionerWeekScreen> {
  late Future<WeekModel> _weekFuture;

  @override
  void initState() {
    super.initState();
    _weekFuture = _load();
  }

  Future<WeekModel> _load() =>
      context.read<WeekRepository>().getWeek(widget.weekId);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Week Detail'),
        actions: [
          IconButton(
            icon: const Icon(Icons.payments_outlined),
            tooltip: 'Payouts',
            onPressed: () => context.pushNamed(
              'commissionerPayouts',
              pathParameters: {'weekId': widget.weekId},
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.pushNamed(
          'commissionerGames',
          pathParameters: {'weekId': widget.weekId},
        ),
        icon: const Icon(Icons.edit_calendar_outlined),
        label: const Text('Edit Games'),
      ),
      body: FutureBuilder<WeekModel>(
        future: _weekFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || !snapshot.hasData) {
            return ErrorStateView(
              message: 'Could not load this week.',
              onRetry: () => setState(() {
                _weekFuture = _load();
              }),
            );
          }
          final week = snapshot.data!;
          return ResponsiveContent(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              children: [
                Text(
                  week.label,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 4),
                Text(
                  'Status: ${week.status.replaceAll('_', ' ')} · '
                  'Deadline: ${_formatDate(week.pickDeadline)}',
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Pick Deadline',
                                style: Theme.of(context).textTheme.titleSmall,
                              ),
                              const SizedBox(height: 4),
                              Text(_formatDate(week.pickDeadline)),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit_outlined),
                          tooltip: 'Edit deadline',
                          onPressed: () => _editDeadline(context, week),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Weekly Message',
                                style: Theme.of(context).textTheme.titleSmall,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                week.commissionerMessage?.isNotEmpty == true
                                    ? week.commissionerMessage!
                                    : 'No message set yet.',
                                style:
                                    week.commissionerMessage?.isNotEmpty == true
                                    ? const TextStyle(
                                        fontStyle: FontStyle.italic,
                                      )
                                    : TextStyle(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onSurfaceVariant,
                                      ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit_outlined),
                          tooltip: 'Edit message',
                          onPressed: () => _editMessage(context, week),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Weekly Pot',
                                style: Theme.of(context).textTheme.titleSmall,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                week.pot != null
                                    ? '\$${week.pot}'
                                    : 'No pot set — payouts won\'t be tracked.',
                                style: week.pot == null
                                    ? TextStyle(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onSurfaceVariant,
                                      )
                                    : null,
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit_outlined),
                          tooltip: 'Edit pot',
                          onPressed: () => _editPot(context, week),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                if (week.games.isEmpty)
                  const Text('No games assigned yet.')
                else
                  ...week.games.map(
                    (game) => Card(
                      child: ListTile(
                        title: Text(
                          '${game.awayTeam.abbreviation} @ ${game.homeTeam.abbreviation}',
                        ),
                        subtitle: Text(_sportLabel(game.sport)),
                        trailing:
                            (game.spread != null || game.overUnder != null)
                            ? Text(
                                [
                                  if (game.spread != null)
                                    'Spread ${game.spread}',
                                  if (game.overUnder != null)
                                    'O/U ${game.overUnder}',
                                ].join(' · '),
                              )
                            : null,
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _editDeadline(BuildContext context, WeekModel week) async {
    final weekRepository = context.read<WeekRepository>();
    final messenger = ScaffoldMessenger.of(context);
    final currentLocal = week.pickDeadline.toLocal();
    final firstDate = DateTime.now().subtract(const Duration(days: 365));

    DateTime? deadlineDate = DateTime(
      currentLocal.year,
      currentLocal.month,
      currentLocal.day,
    );
    TimeOfDay? deadlineTime = TimeOfDay(
      hour: currentLocal.hour,
      minute: currentLocal.minute,
    );

    final result = await showDialog<DateTime>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setState) {
            final deadline = (deadlineDate != null && deadlineTime != null)
                ? DateTime(
                    deadlineDate!.year,
                    deadlineDate!.month,
                    deadlineDate!.day,
                    deadlineTime!.hour,
                    deadlineTime!.minute,
                  )
                : null;
            return AlertDialog(
              title: const Text('Pick Deadline'),
              content: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Expanded(
                    child: Text(
                      deadline == null
                          ? 'No deadline selected'
                          : _formatDate(deadline),
                    ),
                  ),
                  TextButton(
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: dialogContext,
                        initialDate: deadlineDate ?? DateTime.now(),
                        firstDate: firstDate,
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (picked != null) {
                        setState(() => deadlineDate = picked);
                      }
                    },
                    child: const Text('Pick Date'),
                  ),
                  TextButton(
                    onPressed: () async {
                      final picked = await showTimePicker(
                        context: dialogContext,
                        initialTime:
                            deadlineTime ??
                            const TimeOfDay(hour: 23, minute: 59),
                      );
                      if (picked != null) {
                        setState(() => deadlineTime = picked);
                      }
                    },
                    child: const Text('Pick Time'),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: deadline == null
                      ? null
                      : () => Navigator.of(dialogContext).pop(deadline),
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
    if (result == null) return;

    try {
      await weekRepository.updateWeek(widget.weekId, pickDeadline: result);
      if (!mounted) return;
      setState(() {
        _weekFuture = weekRepository.getWeek(widget.weekId);
      });
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Could not save deadline: $e')),
      );
    }
  }

  Future<void> _editMessage(BuildContext context, WeekModel week) async {
    final controller = TextEditingController(
      text: week.commissionerMessage ?? '',
    );
    final weekRepository = context.read<WeekRepository>();
    final messenger = ScaffoldMessenger.of(context);

    final text = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Weekly Message'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 500,
          maxLines: 4,
          decoration: const InputDecoration(
            hintText: "Who's getting roasted this week?",
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (text == null) return;

    try {
      await weekRepository.updateCommissionerMessage(
        widget.weekId,
        text.trim().isEmpty ? null : text.trim(),
      );
      if (!mounted) return;
      setState(() {
        _weekFuture = weekRepository.getWeek(widget.weekId);
      });
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Could not save message: $e')),
      );
    }
  }

  Future<void> _editPot(BuildContext context, WeekModel week) async {
    final controller = TextEditingController(text: week.pot ?? '');
    final weekRepository = context.read<WeekRepository>();
    final messenger = ScaffoldMessenger.of(context);

    final text = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Weekly Pot'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(prefixText: r'$', hintText: '0.00'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (text == null) return;

    final trimmed = text.trim();
    final pot = trimmed.isEmpty ? null : double.tryParse(trimmed);
    if (trimmed.isNotEmpty && pot == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Enter a valid dollar amount.')),
      );
      return;
    }

    try {
      await weekRepository.updatePot(widget.weekId, pot);
      if (!mounted) return;
      setState(() {
        _weekFuture = weekRepository.getWeek(widget.weekId);
      });
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Could not save pot: $e')));
    }
  }

  static String _formatDate(DateTime dateTime) {
    final d = dateTime.toLocal();
    return '${d.month}/${d.day}/${d.year} '
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }
}

String _sportLabel(String sport) {
  switch (sport) {
    case 'college':
      return 'College';
    case 'nfl':
      return 'NFL';
    case 'mlb':
      return 'MLB';
    default:
      return sport;
  }
}
