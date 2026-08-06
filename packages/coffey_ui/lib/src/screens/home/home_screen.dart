import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../blocs/auth/auth_bloc.dart';
import '../../repositories/week_repository.dart';
import '../../widgets/coffey_logo.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthBloc>().state;
    final user = authState is AuthAuthenticated ? authState.user : null;
    final isCommissioner = user?.role == 'commissioner' || user?.role == 'admin';

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            CoffeyLogo(height: 32),
            SizedBox(width: 10),
            Text('Coffey Club Pickem'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
            onPressed: () => context.pushNamed('settings'),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Log out',
            onPressed: () => context.read<AuthBloc>().add(const AuthEvent.logoutRequested()),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (user != null) ...[
                  Text('Signed in as ${user.name} (${user.role})'),
                  const SizedBox(height: 24),
                ],
                FilledButton.icon(
                  onPressed: () => _openCurrentWeek(context, 'pickSheet'),
                  icon: const Icon(Icons.checklist),
                  label: const Text("This Week's Picks"),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () => _openCurrentWeek(context, 'liveResults'),
                  icon: const Icon(Icons.live_tv_outlined),
                  label: const Text('Live Results'),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () => _openCurrentWeek(context, 'weeklyStandings'),
                  icon: const Icon(Icons.leaderboard_outlined),
                  label: const Text('Weekly Standings'),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () => context.pushNamed('seasonStandings'),
                  icon: const Icon(Icons.emoji_events_outlined),
                  label: const Text('Season Standings'),
                ),
                if (isCommissioner) ...[
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () => context.pushNamed('commissioner'),
                    icon: const Icon(Icons.admin_panel_settings_outlined),
                    label: const Text('Commissioner Dashboard'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openCurrentWeek(BuildContext context, String routeName) async {
    final weekRepository = context.read<WeekRepository>();
    final messenger = ScaffoldMessenger.of(context);
    try {
      final week = await weekRepository.getCurrentWeek();
      if (week == null) {
        messenger.showSnackBar(const SnackBar(content: Text('No active week yet.')));
        return;
      }
      if (!context.mounted) return;
      context.pushNamed(routeName, pathParameters: {'weekId': week.id});
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Could not load current week: $e')));
    }
  }
}
