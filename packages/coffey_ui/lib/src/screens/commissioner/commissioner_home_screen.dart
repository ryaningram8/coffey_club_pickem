import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../blocs/commissioner/commissioner_bloc.dart';
import '../../blocs/selected_pool/selected_pool_cubit.dart';
import '../../repositories/season_repository.dart';

class CommissionerHomeScreen extends StatelessWidget {
  const CommissionerHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Reachable only when the pool switcher has a pool selected and the
    // Home screen's Commissioner entry point is visible for it (see
    // home_screen.dart), so a loaded selection is always expected here.
    final poolState = context.read<SelectedPoolCubit>().state;
    final season = (poolState as SelectedPoolLoaded)
        .pools
        .firstWhere((p) => p.id == poolState.selectedPoolId);

    return BlocProvider(
      create: (context) => CommissionerBloc(
        seasonRepository: context.read<SeasonRepository>(),
      )..add(CommissionerEvent.started(season: season)),
      child: const _CommissionerHomeView(),
    );
  }
}

class _CommissionerHomeView extends StatelessWidget {
  const _CommissionerHomeView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Commissioner')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateWeekDialog(context),
        icon: const Icon(Icons.add),
        label: const Text('New Week'),
      ),
      body: BlocConsumer<CommissionerBloc, CommissionerState>(
        listener: (context, state) {
          if (state is CommissionerFailure) {
            ScaffoldMessenger.of(context)
                .showSnackBar(SnackBar(content: Text(state.message)));
          }
        },
        builder: (context, state) {
          if (state is CommissionerInitial || state is CommissionerLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state is CommissionerFailure) {
            return const Center(child: Text('Something went wrong loading weeks.'));
          }
          if (state is CommissionerLoaded) {
            final season = state.season;
            final weeks = state.weeks;
            if (weeks.isEmpty) {
              return Center(
                child: Text('No weeks yet for ${season.name}. Tap + to create one.'),
              );
            }
            return CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final week = weeks[index];
                        return ListTile(
                          title: Text(week.label),
                          subtitle: Text(
                            '${week.gameCount} games · deadline ${_formatDate(week.pickDeadline)}',
                          ),
                          trailing: _StatusBadge(status: week.status),
                          onTap: () => context.pushNamed(
                            'commissionerWeek',
                            pathParameters: {'weekId': week.id},
                          ),
                        );
                      },
                      childCount: weeks.length,
                    ),
                  ),
                ),
              ],
            );
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }

  static String _formatDate(DateTime dateTime) {
    final d = dateTime.toLocal();
    return '${d.month}/${d.day}/${d.year} '
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  void _showCreateWeekDialog(BuildContext context) {
    final bloc = context.read<CommissionerBloc>();
    final labelController = TextEditingController();
    final weekNumberController = TextEditingController();

    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        DateTime? deadline;
        return StatefulBuilder(
          builder: (dialogContext, setState) {
            return AlertDialog(
              title: const Text('Create Week'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: weekNumberController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Week Number'),
                  ),
                  TextField(
                    controller: labelController,
                    decoration: const InputDecoration(labelText: 'Label (e.g. Week 7)'),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          deadline == null
                              ? 'No deadline selected'
                              : 'Deadline: ${_formatDate(deadline!)}',
                        ),
                      ),
                      TextButton(
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: dialogContext,
                            initialDate: DateTime.now(),
                            firstDate: DateTime.now(),
                            lastDate: DateTime.now().add(const Duration(days: 365)),
                          );
                          if (picked != null) setState(() => deadline = picked);
                        },
                        child: const Text('Pick Date'),
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    final weekNumber = int.tryParse(weekNumberController.text);
                    if (weekNumber == null ||
                        labelController.text.trim().isEmpty ||
                        deadline == null) {
                      return;
                    }
                    bloc.add(
                      CommissionerEvent.weekCreateRequested(
                        weekNumber: weekNumber,
                        label: labelController.text.trim(),
                        pickDeadline: deadline!,
                      ),
                    );
                    Navigator.of(dialogContext).pop();
                  },
                  child: const Text('Create'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Chip(
      label: Text(status.replaceAll('_', ' ')),
      backgroundColor: theme.colorScheme.secondaryContainer,
      labelStyle: TextStyle(color: theme.colorScheme.onSecondaryContainer),
    );
  }
}
