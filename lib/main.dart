import 'package:flutter/material.dart';
import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:google_fonts/google_fonts.dart';
import 'model.dart';
import 'viewmodel.dart';
import 'widgets/dashboard.dart';
import 'widgets/findpackages.dart';
import 'widgets/myplugins.dart';
import 'widgets/fragments.dart';

void main() {
  runApp(Sc4pacGuiApp());
}

class NavigationService {
  static GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
}

class Sc4pacGuiApp extends StatelessWidget {
  final World _world = World(Profile());
  Sc4pacGuiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      navigatorKey: NavigationService.navigatorKey,  // allows to access global context for popup dialogs

      // Theme config for FlexColorScheme version 7.3.x. Make sure you use
      // same or higher package version, but still same major version. If you
      // use a lower package version, some properties may not be supported.
      // In that case remove them after copying this theme to your app.
      theme: FlexThemeData.light(
        scheme: FlexScheme.material,
        surfaceMode: FlexSurfaceMode.levelSurfacesLowScaffold,
        blendLevel: 7,
        subThemesData: const FlexSubThemesData(
          blendOnLevel: 10,
          blendOnColors: false,
          useTextTheme: true,
          useM2StyleDividerInM3: true,
          alignedDropdown: true,
          useInputDecoratorThemeInDialogs: true,
        ),
        visualDensity: FlexColorScheme.comfortablePlatformDensity,
        useMaterial3: true,
        swapLegacyOnMaterial3: true,
        fontFamily: GoogleFonts.notoSans().fontFamily,
      ),
      darkTheme: FlexThemeData.dark(
        scheme: FlexScheme.material,
        surfaceMode: FlexSurfaceMode.levelSurfacesLowScaffold,
        blendLevel: 13,
        subThemesData: const FlexSubThemesData(
          blendOnLevel: 20,
          useTextTheme: true,
          useM2StyleDividerInM3: true,
          alignedDropdown: true,
          useInputDecoratorThemeInDialogs: true,
        ),
        visualDensity: FlexColorScheme.comfortablePlatformDensity,
        useMaterial3: true,
        swapLegacyOnMaterial3: true,
        fontFamily: GoogleFonts.notoSans().fontFamily,
      ),
      // If you do not have a themeMode switch, uncomment this line
      // to let the device system mode control the theme mode:
      // themeMode: ThemeMode.system,
      themeMode: ThemeMode.dark,

      home: NavRail(_world),
    );
  }
}

class NavRail extends StatefulWidget {
  final World world;
  const NavRail(this.world, {super.key});

  @override
  State<NavRail> createState() => _NavRailState();
}

class _NavRailState extends State<NavRail> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Row(
          children: <Widget>[
            LayoutBuilder(builder: (context, constraint) =>
              SingleChildScrollView(child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraint.maxHeight),
                child: IntrinsicHeight(child:
                  NavigationRail(
                    selectedIndex: _selectedIndex,
                    onDestinationSelected: (int index) {
                      setState(() {
                        _selectedIndex = index;
                      });
                    },
                    labelType: NavigationRailLabelType.all,  // or selected,
                    destinations: const <NavigationRailDestination>[
                      NavigationRailDestination(
                        icon: Icon(Icons.speed_outlined),
                        selectedIcon: Icon(Icons.speed),
                        label: Text('Dashboard'),
                      ),
                      NavigationRailDestination(
                        icon: Icon(Icons.travel_explore_outlined),
                        selectedIcon: Icon(Icons.travel_explore),
                        label: Text('Find Packages'),
                      ),
                      NavigationRailDestination(
                        icon: Icon(Icons.widgets_outlined),
                        selectedIcon: Icon(Icons.widgets),
                        label: Text('My Plugins'),
                      ),
                      NavigationRailDestination(
                        icon: Icon(Icons.settings_outlined),
                        selectedIcon: Icon(Icons.settings),
                        label: Text('Settings'),
                      ),
                    ],
                  )
                )
              ))
            ),
            // const VerticalDivider(thickness: 1, width: 1),
            // This is the main content.
            Expanded(
              child:
                _selectedIndex == 0 ? DashboardScreen(widget.world.profile.dashboard, widget.world.client) :
                _selectedIndex == 1 ? FindPackagesScreen(widget.world.profile.findPackages) :
                _selectedIndex == 2 ? MyPluginsScreen(widget.world.profile.myPlugins) : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Text('selectedIndex: $_selectedIndex'),
                    const SizedBox(height: 20),
                    OverflowBar(
                      spacing: 10.0,
                      children: <Widget>[
                        ElevatedButton(
                          onPressed: () { },
                          child: const Text('Button 1'),
                        ),
                        ElevatedButton(
                          onPressed: () { },
                          child: const Text('Button 2'),
                        ),
                      ],
                    ),
                    PackageTile(BareModule("group", "name"), 0, subtitle: "summary"),
                    PackageTile(BareModule("group", "name"), 1, subtitle: "summary"),
                  ],
                ),
            ),
          ],
        ),
      ),
    );
  }
}
