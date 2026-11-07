
import 'package:flutter/material.dart';
import 'package:vitals_10/ui/devices/dashboard/constants/page_colors.dart';

class GlassCard extends StatelessWidget{
    
    final Widget child;

    const GlassCard({
      super.key,
      required this.child,
    });

    @override
    Widget build(BuildContext context){
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cCardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: cBorder),
        ),
        child: child,
      );
    }
}

