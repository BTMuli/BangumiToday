import 'package:flutter/widgets.dart';

class BTBreakpoints {
  BTBreakpoints._();

  static const double mobile = 600;
  static const double tablet = 900;
  static const double desktop = 1200;
  static const double wide = 1600;

  static DeviceType getDeviceType(double width) {
    if (width < mobile) return DeviceType.compact;
    if (width < tablet) return DeviceType.mobile;
    if (width < desktop) return DeviceType.tablet;
    if (width < wide) return DeviceType.desktop;
    return DeviceType.wide;
  }

  static bool isCompact(double width) => width < mobile;
  static bool isMobile(double width) => width >= mobile && width < tablet;
  static bool isTablet(double width) => width >= tablet && width < desktop;
  static bool isDesktop(double width) => width >= desktop && width < wide;
  static bool isWide(double width) => width >= wide;

  static int getGridColumns(
    double width, {
    int minColumns = 1,
    int maxColumns = 5,
  }) {
    var type = getDeviceType(width);
    var columns = switch (type) {
      DeviceType.compact => 1,
      DeviceType.mobile => 2,
      DeviceType.tablet => 3,
      DeviceType.desktop => 4,
      DeviceType.wide => 5,
    };
    return columns.clamp(minColumns, maxColumns);
  }

  static double getSidebarWidth(double width) {
    if (width < tablet) return width * 0.8;
    if (width < desktop) return 250;
    return 280;
  }

  static double getDetailPaneWidth(double width) {
    if (width < desktop) return width;
    return (width * 0.4).clamp(400.0, 600.0);
  }

  static EdgeInsets getScreenPadding(double width) {
    if (width < mobile) return const EdgeInsets.all(8);
    if (width < tablet) return const EdgeInsets.all(12);
    if (width < desktop) return const EdgeInsets.all(16);
    return const EdgeInsets.all(24);
  }

  static double getCardWidth(double width, int columns, double spacing) {
    var padding = getScreenPadding(width);
    var availableWidth =
        width - padding.left - padding.right - (spacing * (columns - 1));
    return availableWidth / columns;
  }
}

enum DeviceType { compact, mobile, tablet, desktop, wide }

class BTResponsiveBuilder extends StatelessWidget {
  final Widget Function(BuildContext context, DeviceType deviceType) builder;

  const BTResponsiveBuilder({super.key, required this.builder});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        var deviceType = BTBreakpoints.getDeviceType(constraints.maxWidth);
        return builder(context, deviceType);
      },
    );
  }
}

class BTResponsiveWidget extends StatelessWidget {
  final Widget compact;
  final Widget? mobile;
  final Widget? tablet;
  final Widget? desktop;
  final Widget? wide;

  const BTResponsiveWidget({
    super.key,
    required this.compact,
    this.mobile,
    this.tablet,
    this.desktop,
    this.wide,
  });

  @override
  Widget build(BuildContext context) {
    return BTResponsiveBuilder(
      builder: (context, deviceType) {
        return switch (deviceType) {
          DeviceType.compact => compact,
          DeviceType.mobile => mobile ?? compact,
          DeviceType.tablet => tablet ?? mobile ?? compact,
          DeviceType.desktop => desktop ?? tablet ?? mobile ?? compact,
          DeviceType.wide => wide ?? desktop ?? tablet ?? mobile ?? compact,
        };
      },
    );
  }
}

class BTResponsiveGridView extends StatelessWidget {
  final int? crossAxisCount;
  final int minColumns;
  final int maxColumns;
  final double childAspectRatio;
  final double mainAxisSpacing;
  final double crossAxisSpacing;
  final EdgeInsetsGeometry? padding;
  final int itemCount;
  final Widget Function(BuildContext, int) itemBuilder;

  const BTResponsiveGridView({
    super.key,
    this.crossAxisCount,
    this.minColumns = 1,
    this.maxColumns = 5,
    this.childAspectRatio = 1.0,
    this.mainAxisSpacing = 8.0,
    this.crossAxisSpacing = 8.0,
    this.padding,
    required this.itemCount,
    required this.itemBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        var columns =
            crossAxisCount ??
            BTBreakpoints.getGridColumns(
              constraints.maxWidth,
              minColumns: minColumns,
              maxColumns: maxColumns,
            );

        return GridView.builder(
          padding:
              padding ?? BTBreakpoints.getScreenPadding(constraints.maxWidth),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            childAspectRatio: childAspectRatio,
            mainAxisSpacing: mainAxisSpacing,
            crossAxisSpacing: crossAxisSpacing,
          ),
          itemCount: itemCount,
          itemBuilder: itemBuilder,
          cacheExtent: 500,
        );
      },
    );
  }
}

class BTResponsiveListView extends StatelessWidget {
  final EdgeInsetsGeometry? padding;
  final int itemCount;
  final Widget Function(BuildContext, int) itemBuilder;
  final double? itemExtent;
  final bool addAutomaticKeepAlives;
  final bool addRepaintBoundaries;
  final ScrollController? controller;

  const BTResponsiveListView({
    super.key,
    this.padding,
    required this.itemCount,
    required this.itemBuilder,
    this.itemExtent,
    this.addAutomaticKeepAlives = true,
    this.addRepaintBoundaries = true,
    this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return ListView.builder(
          controller: controller,
          padding:
              padding ?? BTBreakpoints.getScreenPadding(constraints.maxWidth),
          itemCount: itemCount,
          itemBuilder: itemBuilder,
          itemExtent: itemExtent,
          addAutomaticKeepAlives: addAutomaticKeepAlives,
          addRepaintBoundaries: addRepaintBoundaries,
          cacheExtent: 500,
        );
      },
    );
  }
}

class BTResponsivePadding extends StatelessWidget {
  final Widget child;

  const BTResponsivePadding({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Padding(
          padding: BTBreakpoints.getScreenPadding(constraints.maxWidth),
          child: child,
        );
      },
    );
  }
}
