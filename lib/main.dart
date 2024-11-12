import 'package:flutter/material.dart';
import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:file_picker/file_picker.dart' show FilePicker;
import 'dart:io' as io;
import 'model.dart';
import 'data.dart';
import 'viewmodel.dart';
import 'widgets/dashboard.dart';
import 'widgets/findpackages.dart';
import 'widgets/myplugins.dart';
import 'widgets/fragments.dart';

void main(List<String> args) {
  final cmdArgs = CommandlineArgs(args);
  if (cmdArgs.help) {
    final segments = io.File(io.Platform.resolvedExecutable).uri.pathSegments;
    final exeName = segments.isEmpty ? "sc4pac-gui" : segments.last;
    io.stdout.writeln(
"""Usage: $exeName [options]

Options
  --port number           Port of sc4pac server (default: ${Sc4pacClient.defaultPort})
  --host IP               Hostname of sc4pac server (default: localhost)
  --launch-server=false   Do not launch sc4pac server from GUI, but connect to external process instead (default: true)
  --profiles-dir path     Profiles directory for sc4pac server (default: BUNDLEDIR/profiles), resolved relative to current directory
  --sc4pac-cli-dir path   Contains sc4pac CLI scripts for launching the server (default: BUNDLEDIR/cli), resolved relative to current directory
  -h, --help              Print help message and exit"""
    );
    io.exit(0);
  } else {
    runApp(Sc4pacGuiApp(World(args: cmdArgs)));
  }
}

class CommandlineArgs {
  bool help = false;
  int? port;
  String? host;
  String? profilesDir;
  String? cliDir;
  bool launchServer = true;
  CommandlineArgs(List<String> args) {
    while (args.isNotEmpty) {
      switch (args) {
        case ["--port", var p, ...(var rest)]:           port = int.tryParse(p); args = rest; break;
        case ["--host", var h, ...(var rest)]:           host = h;               args = rest; break;
        case ["--profiles-dir", var p, ...(var rest)]:   profilesDir = p;        args = rest; break;
        case ["--sc4pac-cli-dir", var p, ...(var rest)]: cliDir = p;             args = rest; break;
        case ["--launch-server=true",  ...(var rest)]:   launchServer = true;    args = rest; break;
        case ["--launch-server=false", ...(var rest)]:   launchServer = false;   args = rest; break;
        case ["--help" || "-h", ...(var rest)]:          help = true;            args = rest; break;
        default:
          io.stderr.writeln("Unknown trailing arguments (try --help): ${args.join(" ")}");
          args = [];
          io.exit(1);
      }
    }
  }
}

class NavigationService {
  static GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
}

class Sc4pacGuiApp extends StatelessWidget {
  final World _world;
  const Sc4pacGuiApp(this._world, {super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      navigatorKey: NavigationService.navigatorKey,  // allows to access global context for popup dialogs
      title: "sc4pac GUI",

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
        builder: (context, child) => switch (_world.initPhase) {
          InitPhase.initialized => NavRail(_world),
          InitPhase.connecting => ConnectionScreen(_world),
          InitPhase.loadingProfiles => LoadingProfilesScreen(_world),
          InitPhase.initializingProfile => ReadingProfileScreen(_world),
        },
      ),
    );
  }
}

class ConnectionScreen extends StatefulWidget {
  final World world;
  const ConnectionScreen(this.world, {super.key});
  @override State<ConnectionScreen> createState() => _ConnectionScreenState();
}
class _ConnectionScreenState extends State<ConnectionScreen> {
  late final TextEditingController _controller = TextEditingController();
  bool _isValid = true;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _controller.text;
    final uri = Uri.tryParse(text.startsWith('http://') || text.startsWith('https://') ? text : "http://$text");
    setState(() {
      _isValid = uri != null;
      if (uri != null) {
        _controller.text = uri.authority;
        widget.world.updateConnection(uri.authority, notify: true);
      }
    });
  }

  @override build(BuildContext context) {
    return FutureBuilder(
      future: widget.world.initialServerStatus,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return CenteredFullscreenDialog(
            title: const Text("Establish connection"),
            child: Column(
              children: [
                ExpansionTile(
                  trailing: const Icon(Icons.info_outlined),
                  leading: const Icon(Icons.wifi_tethering_error),
                  title: Text("Connection to local sc4pac server not possible at ${widget.world.authority}"),
                  children: const [Text("The sc4pac GUI is a lightweight interface to the background sc4pac process which performs all the heavy operations on your local file system. "
                    "The local backend server is either not running or the GUI does not know its address.")],
                ),
                const SizedBox(height: 15),
                TextField(
                  controller: _controller,
                  decoration: InputDecoration(
                    icon: const Icon(Icons.edit),
                    labelText: "Host and Port",
                    helperText: "Enter \"host:port\" for local sc4pac backend server to connect to.",
                    errorText: _isValid ? null : "Enter \"host:port\" for local sc4pac backend server to connect to.",
                    helperMaxLines: 10,
                    hintText: "localhost:${Sc4pacClient.defaultPort} or 127.0.0.1:${Sc4pacClient.defaultPort}",
                  ),
                  onSubmitted: (String text) {
                    if (text.isNotEmpty) {
                      _submit();
                    }
                  }
                ),
                const SizedBox(height: 20),
                ListenableBuilder(
                  listenable: _controller,
                  builder: (context, child) => FilledButton(
                    onPressed: _controller.text.isEmpty ? null : _submit,
                    child: child,
                  ),
                  child: const Text("Connect")
                ),
              ],
            ),
          );
        } else {
          // connecting (or connection established; we don't care about the result, as initPhase change triggers next screen)
          final text = widget.world.server?.status == ServerStatus.launching ? "Launching sc4pac…" : "Connecting…";
          return Center(child: Card(child: ListTile(title: Text(text))));
        }
      },
    );
  }
}

class LoadingProfilesScreen extends StatelessWidget {
  final World world;
  const LoadingProfilesScreen(this.world, {super.key});
  @override build(BuildContext context) {
    return FutureBuilder<Profiles>(
      future: world.profilesFuture,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Card(child: ApiErrorWidget(ApiError.from(snapshot.error!))));
        } else {
          if (snapshot.hasData) {
            final data = snapshot.data!;
            if (data.currentProfileId.isEmpty) {
              return CreateProfileDialog(world);
            }
            final String id = data.currentProfileId.first;
            final p = data.profiles.firstWhere((p) => p.id == id);
            WidgetsBinding.instance.addPostFrameCallback((_) {
              world.updateProfile(p);  // switches to next initPhase
            });
          }
          return const Center(child: Card(child: ListTile(title: Text("Loading profiles…"))));
        }
      },
    );
  }
}

class CreateProfileDialog extends StatefulWidget {
  final World world;
  const CreateProfileDialog(this.world, {super.key});
  @override State<CreateProfileDialog> createState() => _CreateProfileDialogState();
}
class _CreateProfileDialogState extends State<CreateProfileDialog> {
  late final TextEditingController _profileNameController = TextEditingController();

  @override
  void dispose() {
    _profileNameController.dispose();
    super.dispose();
  }

  void _submit() {
    widget.world.client.addProfile(_profileNameController.text).then(
      (p) => widget.world.updateProfile(p),  // switches to next initPhase
      onError: ApiErrorWidget.dialog,
    );
  }

  @override
  Widget build(BuildContext context) {
    return CenteredFullscreenDialog(
      title: const Text('Create a new profile'),
      child: Column(
        children: [
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
        ],
      ),
    );
  }
}

class ReadingProfileScreen extends StatelessWidget {
  final World world;
  const ReadingProfileScreen(this.world, {super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: world.readProfileFuture,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Card(child: ApiErrorWidget(ApiError.from(snapshot.error!))));
        } else {
          if (snapshot.hasData) {
            final profileData = snapshot.data!;
            if (!profileData.initialized) {
              final defaults = profileData.data['platformDefaults'];
              return InitProfileDialog(
                world,
                initialPluginsPath: defaults['plugins'].first as String,
                initialCachePath: defaults['cache'].first as String,
              );
            } else {
              final paths = (plugins: profileData.data['pluginsRoot'] as String, cache: profileData.data['cacheRoot'] as String);
              WidgetsBinding.instance.addPostFrameCallback((_) {
                world.updatePaths(paths);  // switches to next initPhase
              });
            }
          }
          return const Center(child: Card(child: ListTile(title: Text("Loading profile data…"))));
        }
      },
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
    widget.world.client.profileInit(
      profileId: widget.world.profile.id,
      paths: (plugins: _pluginsPathController.text.trim(), cache: _cachePathController.text.trim()),
    ).then(
      (data) => widget.world.updatePaths((plugins: data['pluginsRoot'], cache: data['cacheRoot'])),  // switches to next initPhase
      onError: ApiErrorWidget.dialog,
    );
  }

  @override
  Widget build(BuildContext context) {
    return CenteredFullscreenDialog(
      title: Text('Select folders for profile "${widget.world.profile.name}"'),
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
    );
  }
}

class FolderPathEdit extends StatelessWidget {
  final TextEditingController controller;
  final String? labelText;
  final void Function() onSelected;
  const FolderPathEdit(this.controller, {this.labelText, required this.onSelected, super.key});
  static const supportsDirectoryPicker = !kIsWeb;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(child:
          TextField(
            controller: controller,
            decoration: InputDecoration(
              labelText: labelText,
              helperMaxLines: 10,
              helperText: supportsDirectoryPicker ? null :
                "To change this, open your file explorer and copy the full path of a directory to paste it in here.",
            ),
            readOnly: supportsDirectoryPicker,
          ),
        ),
        const SizedBox(width: 10),
        if (supportsDirectoryPicker) OutlinedButton.icon(
          icon: const Icon(Symbols.bookmark_manager),
          onPressed: () async {
            // we attempt to open the directory picker in an existing directory (might otherwise cause problems on Windows)
            String? initialDirectory = controller.text.trim();
            if (!io.Directory(initialDirectory).existsSync() && !io.Link(initialDirectory).existsSync()) {
              initialDirectory = io.FileSystemEntity.parentOf(initialDirectory);
              if (!io.Directory(initialDirectory).existsSync() && !io.Link(initialDirectory).existsSync()) {
                initialDirectory = null;
              }
            }
            String? selectedDirectory = await FilePicker.platform.getDirectoryPath(initialDirectory: initialDirectory);  // does not work in web
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
                    destinations: <NavigationRailDestination>[
                      NavigationRailDestination(
                        icon: DashboardIcon(widget.world.profile.dashboard, selected: false),
                        selectedIcon: DashboardIcon(widget.world.profile.dashboard, selected: true),
                        label: const Text('Dashboard'),
                      ),
                      const NavigationRailDestination(
                        icon: Icon(Icons.travel_explore_outlined),
                        selectedIcon: Icon(Icons.travel_explore),
                        label: Text('Find Packages'),
                      ),
                      const NavigationRailDestination(
                        icon: Icon(Icons.widgets_outlined),
                        selectedIcon: Icon(Icons.widgets),
                        label: Text('My Plugins'),
                      ),
                      const NavigationRailDestination(
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
              child: switch (_selectedIndex) {
                0 => DashboardScreen(widget.world.profile.dashboard, widget.world.client),
                1 => FindPackagesScreen(widget.world.profile.findPackages),
                2 => MyPluginsScreen(widget.world.profile.myPlugins),
                _ => const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Text("Not implemented yet")
                    /*
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
                    PackageTile(const BareModule("group", "name"), 0, subtitle: "summary", refreshParent: () {}),
                    PackageTile(const BareModule("group", "name"), 1, subtitle: "summary", refreshParent: () {}),
                    */
                  ],
                ),
              },
            ),
          ],
        ),
      ),
    );
  }
}
