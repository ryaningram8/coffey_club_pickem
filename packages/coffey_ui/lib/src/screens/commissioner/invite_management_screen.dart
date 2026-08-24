import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../blocs/invitation_management/invitation_management_bloc.dart';
import '../../models/invitation_model.dart';
import '../../repositories/invitation_repository.dart';
import '../../repositories/season_repository.dart';
import '../../widgets/empty_state_view.dart';
import '../../widgets/error_state_view.dart';
import '../../widgets/responsive_content.dart';

class InviteManagementScreen extends StatelessWidget {
  const InviteManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => InvitationManagementBloc(
        seasonRepository: context.read<SeasonRepository>(),
        invitationRepository: context.read<InvitationRepository>(),
      )..add(const InvitationManagementEvent.started()),
      child: const _InvitationManagementView(),
    );
  }
}

/// Sentinel dropdown value for the "Create new pool" entry — distinct from
/// any real season id (uuid), so it can never collide.
const _createPoolValue = '__create_new_pool__';

class _InvitationManagementView extends StatelessWidget {
  const _InvitationManagementView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Invite Management')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showGenerateDialog(context),
        icon: const Icon(Icons.add),
        label: const Text('Generate'),
      ),
      body: BlocConsumer<InvitationManagementBloc, InvitationManagementState>(
        listener: (context, state) {
          if (state is InvitationManagementFailure) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(state.message)));
          }
        },
        builder: (context, state) {
          if (state is InvitationManagementInitial ||
              state is InvitationManagementLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state is InvitationManagementNoSeasons) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const EmptyStateView(
                    icon: Icons.groups_outlined,
                    message: 'No pools yet. Create one to start generating invites.',
                  ),
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    onPressed: () => _showCreatePoolDialog(context),
                    icon: const Icon(Icons.add),
                    label: const Text('Create Pool'),
                  ),
                ],
              ),
            );
          }
          if (state is InvitationManagementFailure) {
            return ErrorStateView(
              message: 'Something went wrong loading invites.',
              onRetry: () => context.read<InvitationManagementBloc>().add(
                const InvitationManagementEvent.started(),
              ),
            );
          }
          if (state is InvitationManagementLoaded) {
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: DropdownButtonFormField<String>(
                    initialValue: state.selectedSeasonId,
                    decoration: const InputDecoration(
                      labelText: 'Pool',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      ...state.seasons.map(
                        (season) => DropdownMenuItem(
                          value: season.id,
                          child: Text(
                            '${season.name} (${season.year}) · ${season.status}',
                          ),
                        ),
                      ),
                      const DropdownMenuItem(
                        value: _createPoolValue,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.add, size: 18),
                            SizedBox(width: 8),
                            Text('Create new pool'),
                          ],
                        ),
                      ),
                    ],
                    onChanged: (seasonId) {
                      if (seasonId == null) return;
                      if (seasonId == _createPoolValue) {
                        _showCreatePoolDialog(context);
                        return;
                      }
                      context.read<InvitationManagementBloc>().add(
                        InvitationManagementEvent.seasonSelected(seasonId),
                      );
                    },
                  ),
                ),
                Expanded(
                  child: state.invitations.isEmpty
                      ? const EmptyStateView(
                          icon: Icons.confirmation_number_outlined,
                          message:
                              'No invite codes yet for this pool. Tap + to generate one.',
                        )
                      : ResponsiveContent(
                          child: CustomScrollView(
                            slivers: [
                              SliverPadding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                  horizontal: 4,
                                ),
                                sliver: SliverList(
                                  delegate: SliverChildBuilderDelegate(
                                    (context, index) => _InvitationTile(
                                      invitation: state.invitations[index],
                                    ),
                                    childCount: state.invitations.length,
                                  ),
                                ),
                              ),
                            ],
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

  void _showGenerateDialog(BuildContext context) {
    final bloc = context.read<InvitationManagementBloc>();
    final emailController = TextEditingController();
    final countController = TextEditingController(text: '1');

    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        bool targeted = false;
        DateTime? expiresAt;
        return StatefulBuilder(
          builder: (dialogContext, setState) {
            return AlertDialog(
              title: const Text('Generate Invite'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Target a specific email'),
                    value: targeted,
                    onChanged: (value) => setState(() => targeted = value),
                  ),
                  if (targeted)
                    TextField(
                      controller: emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(labelText: 'Email'),
                    )
                  else
                    TextField(
                      controller: countController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'How many codes',
                        helperText: 'Up to 25 anonymous codes',
                      ),
                    ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          expiresAt == null
                              ? 'No expiry'
                              : 'Expires: ${_formatDate(expiresAt!)}',
                        ),
                      ),
                      TextButton(
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: dialogContext,
                            initialDate: DateTime.now(),
                            firstDate: DateTime.now(),
                            lastDate: DateTime.now().add(
                              const Duration(days: 365),
                            ),
                          );
                          if (picked != null)
                            setState(() => expiresAt = picked);
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
                    if (targeted && !emailController.text.contains('@')) return;
                    final count = int.tryParse(countController.text) ?? 1;
                    bloc.add(
                      InvitationManagementEvent.codeGenerateRequested(
                        email: targeted ? emailController.text.trim() : null,
                        count: targeted ? null : count,
                        expiresAt: expiresAt,
                      ),
                    );
                    Navigator.of(dialogContext).pop();
                  },
                  child: const Text('Generate'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showCreatePoolDialog(BuildContext context) {
    final bloc = context.read<InvitationManagementBloc>();
    final nameController = TextEditingController();
    final yearController = TextEditingController(
      text: DateTime.now().year.toString(),
    );

    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Create Pool'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Pool name',
                  hintText: 'e.g. 2026 Season',
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: yearController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Year'),
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
                final name = nameController.text.trim();
                final year = int.tryParse(yearController.text.trim());
                if (name.isEmpty || year == null) return;
                bloc.add(
                  InvitationManagementEvent.poolCreated(name: name, year: year),
                );
                Navigator.of(dialogContext).pop();
              },
              child: const Text('Create'),
            ),
          ],
        );
      },
    );
  }

  static String _formatDate(DateTime dateTime) {
    final d = dateTime.toLocal();
    return '${d.month}/${d.day}/${d.year} '
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }
}

class _InvitationTile extends StatelessWidget {
  const _InvitationTile({required this.invitation});

  final InvitationModel invitation;

  bool get _isExpired =>
      invitation.expiresAt != null &&
      invitation.expiresAt!.isBefore(DateTime.now());

  @override
  Widget build(BuildContext context) {
    final usedBy = invitation.usedBy;
    return ListTile(
      leading: const Icon(Icons.confirmation_number_outlined),
      title: Text(
        invitation.code,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      subtitle: Text(_subtitle()),
      trailing: usedBy != null
          ? const _StatusChip(label: 'Redeemed')
          : _isExpired
          ? const _StatusChip(label: 'Expired')
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.copy),
                  tooltip: 'Copy code',
                  onPressed: () => _copyCode(context),
                ),
                if (kIsWeb)
                  IconButton(
                    icon: const Icon(Icons.link),
                    tooltip: 'Copy signup link',
                    onPressed: () => _copyLink(context),
                  ),
              ],
            ),
    );
  }

  String _subtitle() {
    final usedBy = invitation.usedBy;
    if (usedBy != null) {
      return 'Redeemed by ${usedBy.name}';
    }
    if (_isExpired) {
      return 'Expired ${_formatShortDate(invitation.expiresAt!)}';
    }
    if (invitation.email != null) {
      return 'Reserved for ${invitation.email} · Unused';
    }
    return 'Unused';
  }

  Future<void> _copyCode(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    await Clipboard.setData(ClipboardData(text: invitation.code));
    if (!context.mounted) return;
    messenger.showSnackBar(
      const SnackBar(content: Text('Code copied to clipboard')),
    );
  }

  Future<void> _copyLink(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final link = '${Uri.base.origin}/signup?code=${invitation.code}';
    await Clipboard.setData(ClipboardData(text: link));
    if (!context.mounted) return;
    messenger.showSnackBar(
      const SnackBar(content: Text('Link copied to clipboard')),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Chip(
      label: Text(label),
      backgroundColor: theme.colorScheme.secondaryContainer,
      labelStyle: TextStyle(color: theme.colorScheme.onSecondaryContainer),
    );
  }
}

String _formatShortDate(DateTime dateTime) {
  final d = dateTime.toLocal();
  return '${d.month}/${d.day}/${d.year}';
}
