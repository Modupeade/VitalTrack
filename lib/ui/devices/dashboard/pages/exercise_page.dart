import 'package:flutter/material.dart';

import 'package:vitals_10/ui/devices/dashboard/constants/page_colors.dart';

class ExercisePage extends StatelessWidget {
  const ExercisePage({super.key});

  @override
  Widget build(BuildContext context) => const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.directions_run, size: 60, color: cDimGray),
            SizedBox(height: 12),
            Text('Exercise tracking coming soon',
                style: TextStyle(color: cGray, fontSize: 15)),
          ],
        ),
      );
}
