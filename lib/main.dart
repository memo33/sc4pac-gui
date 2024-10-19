import 'package:flutter/material.dart';
import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';
import 'package:file_picker/file_picker.dart' show FilePicker;
import 'model.dart';
import 'data.dart';
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
  final World _world = World();
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

      home: ListenableBuilder(
        listenable: _world,
        builder: (context, child) => _world.profile == null ? FutureBuilder<Profiles>(
          future: Api.profiles(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(child: Card(child: ApiErrorWidget(ApiError.from(snapshot.error!))));
            } else if (!snapshot.hasData) {
              return const Center(child: Card(child: ListTile(leading: CircularProgressIndicator(), title: Text("Loading profiles"))));
            } else {
              final data = snapshot.data!;
              if (data.currentProfileId.isEmpty) {
                return CreateProfileDialog(_world);
              } else {
                final String id = data.currentProfileId.first;
                final p = data.profiles.firstWhere((p) => p.id == id);
                _world.updateProfile(p, notify: false);
                return InitProfileWrapper(_world);
              }
            }
          },
        ) : _world.profile!.paths == null ? InitProfileWrapper(_world) : NavRail(_world)
      ),
    );
  }
}

class InitProfileWrapper extends StatelessWidget {
  final World world;
  const InitProfileWrapper(this.world, {super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: Api.profileRead(profileId: world.profile!.id),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Card(child: ApiErrorWidget(ApiError.from(snapshot.error!))));
        } else if (!snapshot.hasData) {
          return const Center(child: Card(child: ListTile(leading: CircularProgressIndicator(), title: Text("Loading profile data"))));
        } else {
          final profileData = snapshot.data!;
          if (profileData.initialized) {
            final paths = (plugins: profileData.data['pluginsRoot'] as String, cache: profileData.data['cacheRoot'] as String);
            world.updatePaths(paths, notify: false);
            return NavRail(world);
          } else {
            final defaults = profileData.data['platformDefaults'];
            return InitProfileDialog(
              world,
              initialPluginsPath: defaults['plugins'].first as String,
              initialCachePath: defaults['cache'].first as String,
            );
          }
        }
      },
    );
  }
}

class CreateProfileDialog extends StatefulWidget {
  final World world;
  const CreateProfileDialog(this.world, {super.key});
  @override
  State<CreateProfileDialog> createState() => _CreateProfileDialogState();
}
class _CreateProfileDialogState extends State<CreateProfileDialog> {
  late final TextEditingController _profileNameController = TextEditingController();

  @override
  void dispose() {
    _profileNameController.dispose();
    super.dispose();
  }

  void _submit() {
    Api.addProfile(_profileNameController.text).then(
      (p) => widget.world.updateProfile(p, notify: true),
      onError: ApiErrorWidget.dialog,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(centerTitle: true, title: const Text('Create a new profile')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Column(
            children: [
              const Spacer(),
              TextField(
                controller: _profileNameController,
                decoration: const InputDecoration(
                  icon: Icon(Icons.edit),
                  labelText: "Profile name",
                  helperText: "Each profile corresponds to a Plugins folder. This allows you to manage multiple Plugins folders for different regions.",
                  helperMaxLines: 10,
                  hintText: "Timbuktu, London-with-CAM, Futuristic, …",
                ),
                onSubmitted: (String name) {
                  if (name.isNotEmpty) {
                    _submit();
                  }
                }
              ),
              const SizedBox(height: 20),
              ListenableBuilder(
                listenable: _profileNameController,
                builder: (context, child) => FilledButton(
                  onPressed: _profileNameController.text.isEmpty ? null : _submit,
                  child: child,
                ),
                child: const Text("Create profile")
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}

class FolderPathEdit extends StatelessWidget {
  final TextEditingController controller;
  final String? labelText;
  final void Function() onSelected;
  const FolderPathEdit(this.controller, {this.labelText, required this.onSelected, super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(child:
          TextField(
            controller: controller,
            decoration: InputDecoration(labelText: labelText),
            readOnly: true,
          ),
        ),
        const SizedBox(width: 10),
        OutlinedButton.icon(
          icon: const Icon(Symbols.bookmark_manager),
          onPressed: () async {
            String? selectedDirectory = await FilePicker.platform.getDirectoryPath(initialDirectory: controller.text);
            if (selectedDirectory != null && selectedDirectory.isNotEmpty) {
              controller.text = selectedDirectory;
              onSelected();
            }
          },
          label: const Text("Edit"),
        ),
      ],
    );
  }
}

class InitProfileDialog extends StatefulWidget {
  final World world;
  final String initialPluginsPath;
  final String initialCachePath;
  const InitProfileDialog(this.world, {required this.initialPluginsPath, required this.initialCachePath, super.key});
  @override
  State<InitProfileDialog> createState() => _InitProfileDialogState();
}
class _InitProfileDialogState extends State<InitProfileDialog> {
  late final TextEditingController _pluginsPathController = TextEditingController(text: widget.initialPluginsPath);
  late final TextEditingController _cachePathController = TextEditingController(text: widget.initialCachePath);

  @override
  void dispose() {
    _pluginsPathController.dispose();
    _cachePathController.dispose();
    super.dispose();
  }

  void _submit() {
    Api.profileInit(
      profileId: widget.world.profile!.id,
      paths: (plugins: _pluginsPathController.text, cache: _cachePathController.text),
    ).then(
      (data) => widget.world.updatePaths((plugins: data['pluginsRoot'], cache: data['cacheRoot']), notify: true),
      onError: ApiErrorWidget.dialog,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(centerTitle: true, title: Text('Select folders for profile "${widget.world.profile?.name}"')),
      body: SingleChildScrollView(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Column(
              children: [
                const ExpansionTile(
                  trailing: Icon(Icons.info_outlined),
                  title: Text("Plugins folder"),
                  children: [Text("This folder is going to contain all the SimCity 4 mods and assets you choose to install."
                    " If your Plugins folder is not empty, check the documentation on how to migrate your existing plugin files before continuing.")],
                ),
                const SizedBox(height: 15),
                FolderPathEdit(_pluginsPathController, labelText: "Plugins folder path", onSelected: () => setState(() {})),
                const SizedBox(height: 30),
                const ExpansionTile(
                  trailing: Icon(Icons.info_outlined),
                  title: Text("Cache folder"),
                  children: [Text("The Cache folder stores all the files that are downloaded."
                    " It requires several gigabytes of space."
                    " To avoid unnecessary downloads, it is best to keep the default location for the cache, so that all your profiles share the same Cache folder.")],
                ),
                const SizedBox(height: 15),
                FolderPathEdit(_cachePathController, labelText: "Cache folder path", onSelected: () => setState(() {})),
                const SizedBox(height: 30),
                FilledButton(
                  onPressed: _submit,
                  child: const Text("OK"),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
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
                _selectedIndex == 0 ? DashboardScreen(widget.world.profile!.dashboard, widget.world.client) :
                _selectedIndex == 1 ? FindPackagesScreen(widget.world.profile!.findPackages) :
                _selectedIndex == 2 ? MyPluginsScreen(widget.world.profile!.myPlugins) : Column(
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
