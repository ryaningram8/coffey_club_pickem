import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/auth/auth_bloc.dart';
import '../blocs/selected_pool/selected_pool_cubit.dart';

/// Header pool switcher — shows the currently selected pool, lets the user
/// switch between every pool they belong to, and offers a "Join another
/// pool" action that redeems an additional invite code without signing up
/// again. Reads [SelectedPoolCubit] from context; provide it above wherever
/// this is used (see app.dart).
class PoolSwitcherBar extends StatelessWidget {
  const PoolSwitcherBar({super.key});

  static const double height = 48;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: BlocBuilder<SelectedPoolCubit, SelectedPoolState>(
        builder: (context, state) {
          if (state is SelectedPoolLoaded) {
            final selected = state.pools.firstWhere(
              (p) => p.id == state.selectedPoolId,
            );
            return InkWell(
              onTap: () => _showPoolPicker(context, state),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.groups_outlined, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    '${selected.name} (${selected.year})',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const Icon(Icons.arrow_drop_down),
                ],
              ),
            );
          }
          if (state is SelectedPoolNoPools) {
            return Center(
              child: TextButton.icon(
                onPressed: () => _showJoinPoolDialog(context),
                icon: const Icon(Icons.add),
                label: const Text('Join a pool'),
              ),
            );
          }
          if (state is SelectedPoolFailure) {
            return Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      'Could not load pools: ${state.message}',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      final authState = context.read<AuthBloc>().state;
                      final isAdmin =
                          authState is AuthAuthenticated &&
                          authState.user.isAdmin;
                      context.read<SelectedPoolCubit>().load(isAdmin: isAdmin);
                    },
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }

  void _showPoolPicker(BuildContext context, SelectedPoolLoaded state) {
    final cubit = context.read<SelectedPoolCubit>();
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final pool in state.pools)
                ListTile(
                  title: Text('${pool.name} (${pool.year})'),
                  subtitle: Text(pool.status.replaceAll('_', ' ')),
                  trailing: pool.id == state.selectedPoolId
                      ? const Icon(Icons.check)
                      : null,
                  onTap: () {
                    cubit.selectPool(pool.id);
                    Navigator.of(sheetContext).pop();
                  },
                ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.add),
                title: const Text('Join another pool'),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _showJoinPoolDialog(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showJoinPoolDialog(BuildContext context) {
    final cubit = context.read<SelectedPoolCubit>();
    final codeController = TextEditingController();

    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        bool isSubmitting = false;
        String? errorText;
        return StatefulBuilder(
          builder: (dialogContext, setState) {
            return AlertDialog(
              title: const Text('Join Another Pool'),
              content: TextField(
                controller: codeController,
                textCapitalization: TextCapitalization.characters,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'Invite code',
                  errorText: errorText,
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting
                      ? null
                      : () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          final code = codeController.text.trim();
                          if (code.isEmpty) return;
                          setState(() {
                            isSubmitting = true;
                            errorText = null;
                          });
                          try {
                            await cubit.joinPool(code);
                            if (dialogContext.mounted)
                              Navigator.of(dialogContext).pop();
                          } catch (e) {
                            setState(() {
                              isSubmitting = false;
                              errorText = e.toString();
                            });
                          }
                        },
                  child: isSubmitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Join'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
