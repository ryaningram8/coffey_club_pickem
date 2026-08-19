import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../blocs/payouts/payouts_bloc.dart';
import '../../repositories/payout_repository.dart';
import '../../repositories/standings_repository.dart';
import '../../widgets/empty_state_view.dart';
import '../../widgets/error_state_view.dart';
import '../../widgets/responsive_content.dart';

class PayoutsScreen extends StatelessWidget {
  const PayoutsScreen({super.key, required this.weekId});

  final String weekId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => PayoutsBloc(
        standingsRepository: context.read<StandingsRepository>(),
        payoutRepository: context.read<PayoutRepository>(),
        weekId: weekId,
      )..add(const PayoutsEvent.started()),
      child: const _PayoutsView(),
    );
  }
}

class _PayoutsView extends StatelessWidget {
  const _PayoutsView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Payouts')),
      body: BlocConsumer<PayoutsBloc, PayoutsState>(
        listener: (context, state) {
          if (state is PayoutsLoaded && state.errorMessage != null) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(state.errorMessage!)));
          }
        },
        builder: (context, state) {
          if (state is PayoutsInitial || state is PayoutsLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state is PayoutsFailure) {
            return ErrorStateView(
              message: 'Could not load payouts: ${state.message}',
              onRetry: () =>
                  context.read<PayoutsBloc>().add(const PayoutsEvent.started()),
            );
          }
          if (state is PayoutsLoaded) {
            final payable = state.standings
                .where((s) => s.payoutAmount != null)
                .toList();
            if (payable.isEmpty) {
              return const EmptyStateView(
                icon: Icons.payments_outlined,
                message:
                    "No payouts to track yet — results aren't final, or no pot "
                    'was set for this week.',
              );
            }
            return ResponsiveContent(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: payable.length,
                itemBuilder: (context, index) {
                  final s = payable[index];
                  final isUpdating = state.updatingUserId == s.userId;
                  return ListTile(
                    title: Text('${s.userName} · rank ${s.rank}'),
                    subtitle: Text(
                      s.venmoHandle == null
                          ? 'No Venmo handle on file'
                          : '@${s.venmoHandle}',
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '\$${double.parse(s.payoutAmount!).toStringAsFixed(2)}',
                        ),
                        const SizedBox(width: 12),
                        isUpdating
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Switch(
                                value: s.isPaid,
                                onChanged: (value) =>
                                    context.read<PayoutsBloc>().add(
                                      PayoutsEvent.paidToggled(
                                        userId: s.userId,
                                        isPaid: value,
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
          return const SizedBox.shrink();
        },
      ),
    );
  }
}
