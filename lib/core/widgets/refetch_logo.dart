import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme/app_theme.dart';

/// The Refetch logo from refetch.io: the purple mark (identical in every
/// theme) plus the wordmark in `--logo-wordmark` (near-black in light mode,
/// white in dark mode).
class RefetchLogo extends StatelessWidget {
  const RefetchLogo({super.key, this.height = 22, this.markOnly = false});

  final double height;

  /// Just the round mark, for tight spots and empty states.
  final bool markOnly;

  @override
  Widget build(BuildContext context) {
    if (markOnly) {
      return SvgPicture.asset(
        'assets/brand/logo-mark.svg',
        height: height,
        semanticsLabel: 'Refetch',
      );
    }
    return SvgPicture.asset(
      'assets/brand/logo-wordmark.svg',
      height: height,
      semanticsLabel: 'Refetch',
      theme: SvgTheme(currentColor: context.colors.logoWordmark),
    );
  }
}
