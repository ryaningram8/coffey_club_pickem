import 'package:flutter/material.dart';

/// A block that sweeps a soft highlight left-to-right on a loop — the base
/// primitive every skeleton placeholder below is built from. No external
/// shimmer package: just a looping gradient shifted by an AnimationController.
class ShimmerBox extends StatefulWidget {
  const ShimmerBox({super.key, this.width, this.height, this.borderRadius = 8});

  final double? width;
  final double? height;
  final double borderRadius;

  @override
  State<ShimmerBox> createState() => _ShimmerBoxState();
}

class _ShimmerBoxState extends State<ShimmerBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final base = scheme.surfaceContainerHighest;
    final highlight = scheme.surface;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value;
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            gradient: LinearGradient(
              begin: Alignment(-1 + 2 * t, 0),
              end: Alignment(1 + 2 * t, 0),
              colors: [base, highlight, base],
              stops: const [0.35, 0.5, 0.65],
            ),
          ),
        );
      },
    );
  }
}

/// Placeholder matching the rough shape of [PickGameCard]/[LiveGameCard]:
/// a time/label row and two team-button rows.
class SkeletonGameCard extends StatelessWidget {
  const SkeletonGameCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [
                ShimmerBox(width: 80, height: 14),
                ShimmerBox(width: 60, height: 14),
              ],
            ),
            const SizedBox(height: 12),
            const Row(
              children: [
                Expanded(child: ShimmerBox(height: 44)),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: SizedBox(),
                ),
                Expanded(child: ShimmerBox(height: 44)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Placeholder matching the rough shape of a standings/leaderboard row
/// (rank badge + name/subtitle + trailing value).
class SkeletonLeaderboardRow extends StatelessWidget {
  const SkeletonLeaderboardRow({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            const ShimmerBox(width: 40, height: 40, borderRadius: 20),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  ShimmerBox(width: 120, height: 16),
                  SizedBox(height: 6),
                  ShimmerBox(width: 90, height: 12),
                ],
              ),
            ),
            const SizedBox(width: 12),
            const ShimmerBox(width: 48, height: 16),
          ],
        ),
      ),
    );
  }
}

/// A scrollable column of [count] skeleton game cards, for a loading pick
/// sheet / live results list.
class SkeletonGameCardList extends StatelessWidget {
  const SkeletonGameCardList({super.key, this.count = 6});

  final int count;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: count,
      itemBuilder: (context, index) => const SkeletonGameCard(),
    );
  }
}

/// A scrollable column of [count] skeleton leaderboard rows, for a loading
/// standings screen.
class SkeletonLeaderboardList extends StatelessWidget {
  const SkeletonLeaderboardList({super.key, this.count = 6});

  final int count;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: count,
      itemBuilder: (context, index) => const SkeletonLeaderboardRow(),
    );
  }
}
