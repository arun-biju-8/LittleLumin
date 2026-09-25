import 'package:flutter/material.dart';
import '../../../services/tip_service.dart';
import '../parent_theme.dart';

class TipCard extends StatefulWidget {
  const TipCard({super.key});

  @override
  State<TipCard> createState() => _TipCardState();
}

class _TipCardState extends State<TipCard> {
  late final Future<String> _tipFuture;

  @override
  void initState() {
    super.initState();
    _tipFuture = TipService().getTipOfTheDay();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFDF5),
        borderRadius: ParentRadius.card,
        boxShadow: ParentShadows.card,
        border: Border.all(
          color: ParentColors.accent.withOpacity(0.35),
          width: 1.2,
        ),
      ),
      child: FutureBuilder<String>(
        future: _tipFuture,
        builder: (context, snapshot) {
          final tip = snapshot.data ??
              'Every child develops at their own pace. Celebrate small wins!';

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: ParentColors.accent.withOpacity(0.18),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: const Text('💡', style: TextStyle(fontSize: 20)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'TIP OF THE DAY',
                      style: ParentTypography.caption.copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.0,
                        color: const Color(0xFFB45309),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '"$tip"',
                      style: ParentTypography.body.copyWith(
                        fontStyle: FontStyle.italic,
                        color: ParentColors.textPrimary,
                        fontSize: 13,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
