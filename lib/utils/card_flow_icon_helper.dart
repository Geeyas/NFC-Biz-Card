import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// A utility class for CardFlow assets
class CardFlowAssets {
  /// SVG widget for the CardFlow icon
  static Widget cardFlowIcon({double? width, double? height, Color? color}) {
    return SvgPicture.asset(
      'assets/cardflow_icon.svg',
      width: width,
      height: height,
      colorFilter:
          color != null ? ColorFilter.mode(color, BlendMode.srcIn) : null,
    );
  }

  /// SVG widget for the CardFlow logo
  static Widget cardFlowLogo({double? width, double? height, Color? color}) {
    return SvgPicture.asset(
      'assets/cardflow_logo.svg',
      width: width,
      height: height,
      colorFilter:
          color != null ? ColorFilter.mode(color, BlendMode.srcIn) : null,
    );
  }

  /// Constants for asset paths
  static const String iconSvgPath = 'assets/cardflow_icon.svg';
  static const String logoSvgPath = 'assets/cardflow_logo.svg';
}
