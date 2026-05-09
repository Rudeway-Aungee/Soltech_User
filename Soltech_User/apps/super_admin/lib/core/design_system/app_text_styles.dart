import 'package:flutter/material.dart';

import 'app_colors.dart';

class AppTextStyles {
  static const TextStyle pageTitle = TextStyle(
    fontSize: 26,
    fontWeight: FontWeight.w900,
    color: AppColors.text,
  );

  static const TextStyle cardTitle = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w800,
    color: AppColors.text,
  );

  static const TextStyle muted = TextStyle(
    color: AppColors.muted,
    fontSize: 14,
  );
}