import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../blocs/user_management/user_management_bloc.dart';
import '../../models/admin_membership_model.dart';
import '../../models/admin_user_model.dart';
import '../../repositories/admin_users_repository.dart';
import '../../repositories/season_repository.dart';
import '../../widgets/empty_state_view.dart';
import '../../widgets/error_state_view.dart';
import '../../widgets/responsive_content.dart';

class UserManagementScreen extends StatelessWidget {
  const UserManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => UserManagementBloc(
        adminUsersRepository: context.read<AdminUsersRepository>(),
        seasonRepository: context.read<SeasonRepository>(),
      )..add(const UserManagementEvent.started()),
      child: const _UserManagementView(),
    );
  }
}

class _UserManagementView extends StatelessWidget {
  const _UserManagementView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('User Management')),
      body: BlocConsumer<UserManagementBloc, UserManagementState>(
        listener: (context, state) {
          if (state is UserManagementLoaded && state.errorMessage != null) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(state.errorMessage!)));
          }
        },
        builder: (context, state) {
          if (state is UserManagementInitial ||
              state is UserManagementLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state is UserManagementFailure) {
            return ErrorStateView(
              message: 'Could not load users: ${state.message}',
              onRetry: () => context.read<UserManagementBloc>().add(
                const UserManagementEvent.started(),
              ),
            );
          }
          if (state is UserManagementLoaded) {
            final rows = <_MembershipRow>[
              for (final user in state.users)
                for (final membership in user.memberships)
                  if (state.poolFilter == null ||
                      membership.seasonId == state.poolFilter)
                    _MembershipRow(user: user, membership: membership),
            ];

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: DropdownButtonFormField<String?>(
                    initialValue: state.poolFilter,
                    decoration: const InputDecoration(
                      labelText: 'Filter by pool',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      const DropdownMenuItem(
                        value: null,
                        child: Text('All pools'),
                      ),
                      for (final pool in state.pools)
                        DropdownMenuItem(
                          value: pool.id,
                          child: Text('${pool.name} (${pool.year})'),
                        ),
                    ],
                    onChanged: (seasonId) => context
                        .read<UserManagementBloc>()
                        .add(UserManagementEvent.poolFilterChanged(seasonId)),
                  ),
                ),
                Expanded(
                  child: rows.isEmpty
                      ? const EmptyStateView(
                          icon: Icons.people_outline,
                          message: 'No members yet for this pool.',
                        )
                      : ResponsiveContent(
                          child: ListView.builder(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            itemCount: rows.length,
                            itemBuilder: (context, index) {
                              final row = rows[index];
                              final key =
                                  '${row.user.id}:${row.membership.seasonId}';
                              return _MembershipTile(
                                row: row,
                                isMutating: state.mutatingKey == key,
                              );
                            },
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
}

class _MembershipRow {
  const _MembershipRow({required this.user, required this.membership});
  final AdminUserModel user;
  final AdminMembershipModel membership;
}

class _MembershipTile extends StatelessWidget {
  const _MembershipTile({required this.row, required this.isMutating});

  final _MembershipRow row;
  final bool isMutating;

  @override
  Widget build(BuildContext context) {
    final user = row.user;
    final membership = row.membership;

    return ListTile(
      title: Text('${user.name} · ${membership.seasonName}'),
      subtitle: Text(user.isAdmin ? '${user.email} · Admin' : user.email),
      trailing: isMutating
          ? const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'player', label: Text('Player')),
                    ButtonSegment(
                      value: 'commissioner',
                      label: Text('Commissioner'),
                    ),
                  ],
                  selected: {membership.role},
                  onSelectionChanged: (selection) {
                    context.read<UserManagementBloc>().add(
                      UserManagementEvent.roleChangeRequested(
                        userId: user.id,
                        seasonId: membership.seasonId,
                        role: selection.first,
                      ),
                    );
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.person_remove_outlined),
                  tooltip: 'Remove from pool',
                  onPressed: () => _confirmRemove(context, row),
                ),
              ],
            ),
    );
  }

  void _confirmRemove(BuildContext context, _MembershipRow row) {
    final bloc = context.read<UserManagementBloc>();
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Remove from Pool'),
          content: Text(
            'Remove ${row.user.name} from ${row.membership.seasonName}? '
            'Their past picks and results stay on record — they just lose access going forward.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(dialogContext).colorScheme.error,
                foregroundColor: Theme.of(dialogContext).colorScheme.onError,
              ),
              onPressed: () {
                bloc.add(
                  UserManagementEvent.removeRequested(
                    userId: row.user.id,
                    seasonId: row.membership.seasonId,
                  ),
                );
                Navigator.of(dialogContext).pop();
              },
              child: const Text('Remove'),
            ),
          ],
        );
      },
    );
  }
}
