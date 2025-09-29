import 'package:flutter/cupertino.dart';

class AppColors {
  static const backgroundDepth1 = Color(0xFF0E0E11);
  static const backgroundDepth2 = Color(0xFF15151A);
  static const backgroundDepth3 = Color(0xFF1E1E24);
  static const backgroundDepth4 = Color(0xFF2A2A31);
  static const backgroundDepth5 = Color(0xFF35353E);

  static const borderDepth1 = Color(0xFF2E2E36);
  static const borderDepth2 = Color(0xFF3C3C45);
  static const borderDepth3 = Color(0xFF4B4B55);
  static const borderDepth4 = Color(0xFF5B5B66);
  static const borderDepth5 = Color(0xFF6B6B77);

  static const textColor1 = Color(0xFFF4F4F6);
  static const textColor2 = Color(0xFFD6D6DF);
  static const textColor3 = Color(0xFFABABB5);
  static const textColor4 = Color(0xFF7F7F8A);

  static const accentPrimary = Color(0xFF4C7DF0);
  static const accentSecondary = Color(0xFF7A5CFA);
  static const success = Color(0xFF3FB37F);
  static const warning = Color(0xFFF0B347);
  static const error = Color(0xFFE15A64);
}

class AppTypography {
  static TextStyle displayLarge(BuildContext context) =>
      CupertinoTheme.of(context).textTheme.navLargeTitleTextStyle.copyWith(
        color: AppColors.textColor1,
        fontWeight: FontWeight.w600,
      );

  static const TextStyle title = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w600,
    color: AppColors.textColor1,
  );

  static const TextStyle subtitle = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w500,
    color: AppColors.textColor2,
  );

  static const TextStyle body = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w400,
    color: AppColors.textColor2,
  );

  static const TextStyle caption = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    color: AppColors.textColor3,
  );

  static const TextStyle button = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w600,
    color: AppColors.textColor1,
  );
}

class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
}

class AppRadius {
  static const double sm = 10;
  static const double md = 16;
  static const double lg = 22;
}

CupertinoThemeData buildAppTheme() {
  return const CupertinoThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AppColors.backgroundDepth1,
    barBackgroundColor: AppColors.backgroundDepth2,
    primaryColor: AppColors.accentPrimary,
    textTheme: CupertinoTextThemeData(
      textStyle: TextStyle(color: AppColors.textColor1),
      actionTextStyle: TextStyle(
        inherit: false,
        color: AppColors.accentPrimary,
      ),
      navTitleTextStyle: TextStyle(
        inherit: false,
        color: AppColors.textColor1,
        fontSize: 17,
        fontWeight: FontWeight.w600,
      ),
      navLargeTitleTextStyle: TextStyle(
        inherit: false,
        color: AppColors.textColor1,
        fontSize: 32,
        fontWeight: FontWeight.w700,
      ),
      tabLabelTextStyle: TextStyle(
        inherit: false,
        color: AppColors.textColor3,
        fontSize: 12,
        fontWeight: FontWeight.w500,
      ),
    ),
  );
}
