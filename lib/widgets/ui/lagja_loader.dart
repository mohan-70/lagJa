import 'package:flutter/material.dart';
import 'ui_constants.dart';
import 'shimmer_loader.dart';

class LagjaLoader extends StatelessWidget {
  final String? message;

  const LagjaLoader({super.key, this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const ShimmerContainer(
            width: 100,
            height: 100,
            borderRadius: 50,
          ),
          if (message != null) ...[
            const SizedBox(height: 24),
            Text(
              message!,
              textAlign: TextAlign.center,
              style: AppStyles.body.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
