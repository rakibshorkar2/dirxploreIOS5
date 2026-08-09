import 'dart:io' show Platform;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

/// Apple Liquid Glass floating bottom navigation bar.
///
/// Renders the iOS 26-style floating glass pill with a frosted capsule
/// indicator, spring physics, subtle glow and magnification for the
/// selected tab. All five tabs, their order, labels and icons are
/// identical to the previous navigation bar.
class LiquidGlassNavBar extends StatelessWidget {
  const LiquidGlassNavBar({
    super.key,
    required this.currentIndex,
    required this.onTabSelected,
  });

  final int currentIndex;
  final ValueChanged<int> onTabSelected;

  static const List<GlassTab> _tabs = [
    GlassTab(
      icon: Icon(CupertinoIcons.compass),
      activeIcon: Icon(CupertinoIcons.compass_fill),
      label: 'Browser',
      glowColor: Color(0xFF0A84FF),
      thickness: 1.2,
    ),
    GlassTab(
      icon: Icon(CupertinoIcons.arrow_down_circle),
      activeIcon: Icon(CupertinoIcons.arrow_down_circle_fill),
      label: 'Downloads',
      glowColor: Color(0xFF30D158),
      thickness: 1.2,
    ),
    GlassTab(
      icon: Icon(CupertinoIcons.shield),
      activeIcon: Icon(CupertinoIcons.shield_fill),
      label: 'Proxy',
      glowColor: Color(0xFFBF5AF2),
      thickness: 1.2,
    ),
    GlassTab(
      icon: Icon(CupertinoIcons.globe),
      label: 'BRWSR',
      glowColor: Color(0xFF64D2FF),
      thickness: 1.2,
    ),
    GlassTab(
      icon: Icon(CupertinoIcons.gear),
      activeIcon: Icon(CupertinoIcons.gear_solid),
      label: 'Settings',
      glowColor: Color(0xFFFF9F0A),
      thickness: 1.2,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final selectedColor = scheme.primary;
    final unselectedColor = scheme.onSurface.withValues(alpha: 0.55);
    final indicatorColor = isDark
        ? Colors.white.withValues(alpha: 0.14)
        : Colors.white.withValues(alpha: 0.62);

    return GlassTabBar.bottom(
      tabs: _tabs,
      selectedIndex: currentIndex,
      onTabSelected: onTabSelected,
      barHeight: 64,
      spacing: 8,
      horizontalPadding: 20,
      verticalPadding: 20,
      iconSize: 24,
      iconLabelSpacing: 4,
      textStyle: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        letterSpacing: -0.2,
      ),
      selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600),
      selectedIconColor: selectedColor,
      selectedLabelColor: selectedColor,
      unselectedIconColor: unselectedColor,
      unselectedLabelColor: unselectedColor,
      indicatorColor: indicatorColor,
      indicatorExpansion:
          const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      indicatorPinchStrength: 0.4,
      innerBlur: 8,
      magnification: 1.18,
      glowDuration: const Duration(milliseconds: 240),
      glowBlurRadius: 28,
      glowSpreadRadius: 7,
      glowOpacity: 0.35,
      interactionGlowColor: selectedColor.withValues(alpha: 0.12),
      interactionGlowRadius: 1.2,
      pressScale: 1.04,
      enableBlend: true,
      blendAmount: 10,
      quality: GlassQuality.premium,
      maskingQuality: MaskingQuality.high,
      adaptiveBrightness: true,
      platformViewBackdrop: Platform.isIOS,
      settings: LiquidGlassSettings(
        blur: 14,
        thickness: 26,
        saturation: 1.45,
        lightIntensity: 0.6,
        ambientRim: 0.18,
        fresnelStrength: 1.25,
        refractiveIndex: 1.25,
        chromaticAberration: 0.018,
        specularSharpness: GlassSpecularSharpness.medium,
        shadowElevation: 2.0,
        whitenStrength: isDark ? 0.0 : 0.2,
        standardOpacityMultiplier: isDark ? 1.0 : 0.4,
      ),
      indicatorSettings: const LiquidGlassSettings(
        blur: 6,
        thickness: 18,
        fresnelStrength: 1.3,
        ambientRim: 0.12,
        specularSharpness: GlassSpecularSharpness.soft,
      ),
    );
  }
}
