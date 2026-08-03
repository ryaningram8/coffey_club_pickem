import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../blocs/notification_prefs/notification_prefs_cubit.dart';
import '../../repositories/notification_repository.dart';

class NotificationPrefsScreen extends StatelessWidget {
  const NotificationPrefsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => NotificationPrefsCubit(
        notificationRepository: context.read<NotificationRepository>(),
      ),
      child: const _NotificationPrefsView(),
    );
  }
}

const _reminderTimingOptions = [1, 3, 6, 12, 24, 48];

class _NotificationPrefsView extends StatelessWidget {
  const _NotificationPrefsView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: BlocConsumer<NotificationPrefsCubit, NotificationPrefsState>(
        listener: (context, state) {
          if (state is NotificationPrefsLoaded && state.errorMessage != null) {
            ScaffoldMessenger.of(context)
                .showSnackBar(SnackBar(content: Text(state.errorMessage!)));
          }
        },
        builder: (context, state) {
          if (state is NotificationPrefsInitial || state is NotificationPrefsLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state is NotificationPrefsFailure) {
            return Center(child: Text('Could not load preferences: ${state.message}'));
          }
          final loaded = state as NotificationPrefsLoaded;
          final cubit = context.read<NotificationPrefsCubit>();
          final prefs = loaded.prefs;

          return ListView(
            children: [
              const _SectionHeader('Pick Reminders'),
              SwitchListTile(
                title: const Text('Remind me to make picks'),
                value: prefs.pickReminders.enabled,
                onChanged: cubit.setPickRemindersEnabled,
              ),
              SwitchListTile(
                title: const Text('Push notification'),
                value: prefs.pickReminders.push,
                onChanged: prefs.pickReminders.enabled ? cubit.setPickRemindersPush : null,
              ),
              SwitchListTile(
                title: const Text('Email'),
                value: prefs.pickReminders.email,
                onChanged: prefs.pickReminders.enabled ? cubit.setPickRemindersEmail : null,
              ),
              ListTile(
                title: const Text('Remind me before deadline'),
                trailing: DropdownButton<int>(
                  value: prefs.pickReminders.hoursBeforeDeadline,
                  items: _reminderTimingOptions
                      .map((h) => DropdownMenuItem(value: h, child: Text('$h hours')))
                      .toList(),
                  onChanged: prefs.pickReminders.enabled
                      ? (hours) {
                          if (hours != null) cubit.setHoursBeforeDeadline(hours);
                        }
                      : null,
                ),
              ),
              const Divider(),
              const _SectionHeader('Weekly Results'),
              SwitchListTile(
                title: const Text('Notify me when results are final'),
                value: prefs.resultsNotifications.enabled,
                onChanged: cubit.setResultsEnabled,
              ),
              SwitchListTile(
                title: const Text('Push notification'),
                value: prefs.resultsNotifications.push,
                onChanged: prefs.resultsNotifications.enabled ? cubit.setResultsPush : null,
              ),
              SwitchListTile(
                title: const Text('Email'),
                value: prefs.resultsNotifications.email,
                onChanged: prefs.resultsNotifications.enabled ? cubit.setResultsEmail : null,
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(title, style: Theme.of(context).textTheme.titleMedium),
    );
  }
}
