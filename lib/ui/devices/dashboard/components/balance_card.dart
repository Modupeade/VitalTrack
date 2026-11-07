import 'package:flutter/material.dart';
import 'package:vitals_10/ui/devices/dashboard/components/glass_card.dart';
import 'package:vitals_10/ui/devices/dashboard/constants/page_colors.dart';

class BalanceCard extends StatelessWidget {
  const BalanceCard({super.key});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Row(
            children: [
              Text(
                'Balance',
                style: TextStyle(
                    color: cWhite, fontSize: 15, fontWeight: FontWeight.w700),
              ),
              Spacer(),
              Icon(Icons.chevron_right, color: cGray, size: 20),
            ],
          ),
          SizedBox(height: 14),
          Center(child: Text('😐', style: TextStyle(fontSize: 36))),
          SizedBox(height: 10),
          Center(
            child: Text(
              'Please wear the Device all day to evaluate\nyour stress and balance.',
              textAlign: TextAlign.center,
              style: TextStyle(color: cGray, fontSize: 13, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}
