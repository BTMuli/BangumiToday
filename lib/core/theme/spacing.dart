import 'package:flutter_screenutil/flutter_screenutil.dart';

class BTSpacing {
  BTSpacing._();

  static double get xs => 4.w;
  static double get sm => 8.w;
  static double get md => 12.w;
  static double get lg => 16.w;
  static double get xl => 24.w;
  static double get xxl => 32.w;

  static double get verticalXs => 4.h;
  static double get verticalSm => 8.h;
  static double get verticalMd => 12.h;
  static double get verticalLg => 16.h;
  static double get verticalXl => 24.h;
  static double get verticalXxl => 32.h;
}

class BTCardPadding {
  BTCardPadding._();

  static double get small => 8.w;
  static double get medium => 12.w;
  static double get large => 16.w;
}

class BTBorderRadius {
  BTBorderRadius._();

  static double get small => 4.r;
  static double get medium => 8.r;
  static double get large => 12.r;
  static double get xlarge => 16.r;
}

class BTFontSize {
  BTFontSize._();

  static double get caption => 12.sp;
  static double get body => 14.sp;
  static double get subtitle => 16.sp;
  static double get title => 20.sp;
  static double get headline => 24.sp;
  static double get display => 32.sp;
}

class BTIconSize {
  BTIconSize._();

  static double get small => 16.sp;
  static double get medium => 20.sp;
  static double get large => 24.sp;
  static double get xlarge => 32.sp;
}

class BTImageSize {
  BTImageSize._();

  static double get thumbnail => 48.w;
  static double get small => 100.w;
  static double get medium => 150.w;
  static double get large => 200.w;
  static double get xlarge => 300.w;
}
