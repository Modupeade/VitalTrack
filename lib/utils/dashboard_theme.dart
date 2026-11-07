import 'package:flutter/material.dart';

/// Single source of truth for the dashboard palette.
class AppColors {
  static const background = Color(0xFF0B0E13);
  static const backgroundTop = Color(0xFF11161D);
  static const card = Color(0xFF171B22);
  static const tile = Color(0xFF1B2028);
  static const row = Color(0xFF232830);
  static const stroke = Color(0xFF262C36);

  static const steps = Color(0xFF3BA7EE);
  static const stepsDeep = Color(0xFF1E6FA8);
  static const stepsTrack = Color(0xFF14202C);

  static const sleep = Color(0xFF4E8FD6);
  static const sleepTrack = Color(0xFF1A2A3D);

  static const exertion = Color(0xFFD9A441);
  static const exertionTrack = Color(0xFF3A2C15);

  static const textPrimary = Color(0xFFF2F5F8);
  static const textMuted = Color(0xFF8A93A0);
  static const textFaint = Color(0xFF5C6472);

  static const gaugeGreen = Color(0xFF2ED47A);
  static const gaugeTeal = Color(0xFF3BC9A8);
  static const gaugeYellow = Color(0xFFF2C744);
  static const gaugeOrange = Color(0xFFF08A24);

  static const heartRate = Color(0xFFE8615A);
  static const bloodOxygen = Color(0xFF2BB8C6);
  static const gridLine = Color(0xFF2A2F38);

  static const navActive = Color(0xFF17A05A);
  static const link = Color(0xFF4C9AFF);
}

class AppText {
  static const sectionLabel = TextStyle(
    color: AppColors.textMuted,
    fontSize: 13,
    fontWeight: FontWeight.w600,
    letterSpacing: 1.4,
  );

  static const cardTitle = TextStyle(
    color: AppColors.textPrimary,
    fontSize: 16,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.8,
  );

  static const tileTitle = TextStyle(
    color: AppColors.textPrimary,
    fontSize: 14,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.6,
    height: 1.2,
  );

  static const noData = TextStyle(
    color: AppColors.textFaint,
    fontSize: 12,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.8,
  );

  static const updated = TextStyle(
    color: AppColors.textMuted,
    fontSize: 14,
  );
}