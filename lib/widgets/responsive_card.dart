import 'package:flutter/material.dart';
import '../utils/responsive_helper.dart';

class ResponsiveCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Color? backgroundColor;
  final double? elevation;
  final BorderRadius? borderRadius;

  const ResponsiveCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.backgroundColor,
    this.elevation,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = constraints.maxWidth;
        final responsivePadding = ResponsiveHelper.getContentPadding(screenWidth);
        
        return Container(
          margin: margin ?? EdgeInsets.all(responsivePadding / 2),
          child: Card(
            elevation: elevation ?? 2,
            color: backgroundColor ?? Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: borderRadius ?? BorderRadius.circular(12),
            ),
            child: Container(
              padding: padding ?? EdgeInsets.all(responsivePadding),
              child: child,
            ),
          ),
        );
      },
    );
  }
}

class ResponsiveGridView extends StatelessWidget {
  final List<Widget> children;
  final double? childAspectRatio;
  final EdgeInsetsGeometry? padding;

  const ResponsiveGridView({
    super.key,
    required this.children,
    this.childAspectRatio,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = constraints.maxWidth;
        final columns = ResponsiveHelper.getGridColumns(screenWidth);
        final responsivePadding = ResponsiveHelper.getContentPadding(screenWidth);
        
        return GridView.builder(
          padding: padding ?? EdgeInsets.all(responsivePadding),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: responsivePadding,
            mainAxisSpacing: responsivePadding,
            childAspectRatio: childAspectRatio ?? 1.0,
          ),
          itemCount: children.length,
          itemBuilder: (context, index) => children[index],
        );
      },
    );
  }
}

class ResponsiveText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;

  const ResponsiveText(
    this.text, {
    super.key,
    this.style,
    this.textAlign,
    this.maxLines,
    this.overflow,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = constraints.maxWidth;
        final fontScale = ResponsiveHelper.getFontScale(screenWidth);
        
        return Text(
          text,
          style: style?.copyWith(
            fontSize: (style?.fontSize ?? 14) * fontScale,
          ) ?? TextStyle(fontSize: 14 * fontScale),
          textAlign: textAlign,
          maxLines: maxLines,
          overflow: overflow,
        );
      },
    );
  }
} 