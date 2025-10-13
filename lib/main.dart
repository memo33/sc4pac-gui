import 'package:flutter/material.dart';
import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:file_picker/file_picker.dart' show FilePicker;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as P;
import 'dart:io' as io;
import 'model.dart';
import 'data.dart';
import 'viewmodel.dart';
import 'widgets/dashboard.dart';
import 'widgets/findpackages.dart';
import 'widgets/myplugins.dart';
import 'widgets/settings.dart';
import 'widgets/fragments.dart';

void main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();  // important if PackageInfo.fromPlatform called before runApp (otherwise causes null check error in release build on web)
  final appInfo = await PackageInfo.fromPlatform();
  final cmdArgs = CommandlineArgs(args);
  if (cmdArgs.help) {
    final segments = io.File(io.Platform.resolvedExecutable).uri.pathSegments;
    final exeName = segments.isEmpty ? "sc4pac-gui" : segments.last;
    io.stdout.writeln(
"""Usage: $exeName [URI] [options]
Version ${appInfo.version}

URI: an optional "${CommandlineArgs.sc4pacProtocol}" URL passed as first argument

Options
  --port number              Port of sc4pac server (default: ${Sc4pacClient.defaultPort})
  --host IP                  Hostname of sc4pac server (default: localhost)
  --launch-server=false      Do not launch sc4pac server from GUI, but connect to external process instead (default: true)
  --profiles-dir path        Profiles directory for sc4pac server (default: platform-dependent), resolved relatively to current directory
  --sc4pac-cli-dir path      Contains sc4pac CLI scripts for launching the server (default: BUNDLEDIR/cli), resolved relative to current directory
  --register-protocol=false  Do not register "${CommandlineArgs.sc4pacProtocol}" protocol handler in Windows registry (default: true, Windows only).
                             Disabling this is useful if you manually changed the registry entry.
  -h, --help                 Print help message and exit"""
    );
    io.exit(0);
  } else {
    runApp(Sc4pacGuiApp(World(args: cmdArgs, appInfo: appInfo)));
  }
}

class CommandlineArgs {
  final List<String> arguments;
  bool help = false;
  int? port;
  String? host;
  String? profilesDir;
  String? cliDir;
  bool launchServer = true;
  bool registerProtocol = true;
  Uri? uri;  // currently unused
  static const sc4pacProtocolScheme = "sc4pac";
  static const sc4pacProtocol = "$sc4pacProtocolScheme://";
  CommandlineArgs(this.arguments) {
    List<String> args = arguments;
    if (args.isNotEmpty && args[0].startsWith(sc4pacProtocol)) {
      // URI currently needs to be the first argument, see https://github.com/llfbandit/app_links/issues/129
      uri = Uri.tryParse(args[0]);
      args = args.sublist(1);
    }
    while (args.isNotEmpty) {
      switch (args) {
        case ["--port", var p, ...(var rest)]:             port = int.tryParse(p);   args = rest; break;
        case ["--host", var h, ...(var rest)]:             host = h;                 args = rest; break;
        case ["--profiles-dir", var p, ...(var rest)]:     profilesDir = p;          args = rest; break;
        case ["--sc4pac-cli-dir", var p, ...(var rest)]:   cliDir = p;               args = rest; break;
        case ["--launch-server=true",  ...(var rest)]:     launchServer = true;      args = rest; break;
        case ["--launch-server=false", ...(var rest)]:     launchServer = false;     args = rest; break;
        case ["--register-protocol=true",  ...(var rest)]: registerProtocol = true;  args = rest; break;
        case ["--register-protocol=false", ...(var rest)]: registerProtocol = false; args = rest; break;
        case ["--help" || "-h", ...(var rest)]:            help = true;              args = rest; break;
        default:
          io.stderr.writeln("Unknown trailing arguments (try --help): ${args.join(" ")}");
          args = [];
          io.exit(1);
      }
    }
    if (uri != null) {
      registerProtocol = false;
    }
  }
}

class NavigationService {
  static GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
}

class Sc4pacGuiApp extends StatelessWidget {
  final World _world;
  const Sc4pacGuiApp(this._world, {super.key});

  static ThemeData _adjustTheme(ThemeData data) =>
    data.copyWith(
      searchBarTheme: data.searchBarTheme.copyWith(
        hintStyle: WidgetStateProperty.resolveWith((states) => data.textTheme.bodyLarge?.copyWith(
          color: data.colorScheme.onSurfaceVariant.withAlpha(states.isEmpty ? 0 : 0x66),
        )),
      ),
    );

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
      theme: _adjustTheme(FlexThemeData.light(
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
      )),
      darkTheme: _adjustTheme(FlexThemeData.dark(
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
      )),
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
            child: Column(children: switch (widget.world.server?.launchError) {
              ApiError error => [
                ApiErrorWidget(error),  // this is a dead end (e.g. Java not found or too old), so requires restarting the application once resolved
                const SizedBox(height: 20),
                const Text("Restart the application once the above problem is resolved."),
              ],
              null => [
                // ApiErrorWidget(ApiError.from(snapshot.error!)),
                // const SizedBox(height: 20),
                ExpansionTile(
                  trailing: const Icon(Icons.info_outlined),
                  leading: const Icon(Icons.wifi_tethering_error),
                  title: Text("Connection to local sc4pac server not possible at ${widget.world.authority}"),
                  children: const [Text("The sc4pac GUI is a lightweight interface to the background sc4pac process which performs all the heavy operations on your local file system. "
                    "The local backend server is either not running or the GUI does not know its address."
                    " As a workaround, you may connect to an existing sc4pac server process using the input field below."
                    " Alternatively, restarting the application might resolve the problem.")],
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
            }),
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
        Widget content;
        if (snapshot.hasError) {
          content = ApiErrorWidget.scroll(ApiError.from(snapshot.error!));
        } else {
          if (snapshot.hasData) {
            final data = snapshot.data!;
            if (data.currentProfileId.isEmpty || world.createNewProfile) {
              return CreateProfileDialog(world);
            }
            final String id = data.currentProfileId.first;
            final p = data.profiles.firstWhere((p) => p.id == id);
            WidgetsBinding.instance.addPostFrameCallback((_) {
              world.updateProfile((id: p.id, name: p.name));  // switches to next initPhase
            });
          }
          content = const ListTile(title: Text("Loading profiles…"));
        }
        return Center(child: Card(child: content));
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
      (p) {
        widget.world.updateProfilesFast();  // reloads profiles with new current profile (async)
        widget.world.updateProfile(p);  // instantly switches to next initPhase
      },
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
              icon: Icon(Symbols.person_pin_circle),
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
          Wrap(
            direction: Axis.horizontal,
            spacing: 20,
            runSpacing: 10,
            children: [
              if (widget.world.createNewProfile)
                ElevatedButton(
                  onPressed: () {
                    widget.world.reloadProfiles(createNewProfile: false);
                  },
                  child: const Text("Cancel"),
                ),
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
        Widget content;
        if (snapshot.hasError) {
          content = ApiErrorWidget.scroll(ApiError.from(snapshot.error!));
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
          content = const ListTile(title: Text("Loading profile data…"));
        }
        return Center(child: Card(child: content));
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
  late final Future<Profiles> _profilesFuture = World.world.client.profiles(includePlugins: true);
  late Future<List<Widget>> _conflictWarningsFuture;

  @override
  void initState() {
    super.initState();
    _updateConflictWarnings();
  }

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

  void _updateConflictWarnings() {
    final pluginsPath = _pluginsPathController.text.trim();
    _conflictWarningsFuture = _profilesFuture
      .then((profiles) => World.world.conflictingPluginsPaths(profiles, currentPluginsRoot: pluginsPath))
      .catchError((e) {
        debugPrint("Unexpected error while reading all profiles: $e");
        return <ProfilesListItem>[];  // ignore
      })
      .then((conflicts) {
        return [
          if (conflicts.isNotEmpty) PluginsConflictWarning(conflicts, atNewProfile: true),
          if (P.basename(pluginsPath) != "Plugins") const PluginsSymlinkWarning(),
        ];
      });
    setState(() {});
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
            children: [
              Text("Choose a different folder for each new profile you create."
              " This folder is going to contain all the SimCity 4 mods and assets you choose to install."
              " If your Plugins folder is not empty, check the documentation on how to migrate your existing plugin files before continuing."),
            ],
          ),
          const SizedBox(height: 15),
          FolderPathEdit(_pluginsPathController, labelText: "Plugins folder path", onChanged: _updateConflictWarnings, onSelected: _updateConflictWarnings),
          FutureBuilder(
            future: _conflictWarningsFuture,
            builder: (context, snapshot) =>
              snapshot.data?.isNotEmpty != true ? const SizedBox(height: 0) :
                Column(children: snapshot.data!
                  .map((w) => Padding(padding: const EdgeInsets.only(top: 15), child: w)).toList()),
          ),
          const SizedBox(height: 30),
          const ExpansionTile(
            trailing: Icon(Icons.info_outlined),
            title: Text("Download cache folder"),
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

class PluginsSymlinkWarning extends StatelessWidget {
  const PluginsSymlinkWarning({super.key});
  @override
  Widget build(BuildContext context) {
    return Text.rich(TextSpan(
      children: [
        const TextSpan(text:
          """Note: The selected folder is not named "Plugins"."""
          """ This is probably a mistake (unless you are sure you want to manually create Symbolic Links to make the game load files from this location)."""
          """ Instead, choose a folder named "Plugins", and use the """
        ),
        PluginsConflictWarning.link("-UserDir SC4 launch option"),
        const TextSpan(text: " to make the game load the Plugins of this Profile if you have more than one Profile."),
      ],
      style: TextStyle(color: Theme.of(context).colorScheme.error),
    ));
  }
}

class FolderPathEdit extends StatelessWidget {
  final TextEditingController controller;
  final String? labelText;
  final void Function()? beforeSelected;
  final void Function() onSelected;
  final void Function()? onChanged;
  final bool pickFile;
  final bool enabled;
  const FolderPathEdit(this.controller, {this.labelText, this.beforeSelected, required this.onSelected, this.pickFile = false, this.enabled = true, this.onChanged, super.key});
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
                "To change this, open your file explorer and copy the full path of ${pickFile ? "the file" : "a directory"} to paste it in here.",
            ),
            readOnly: supportsDirectoryPicker,
            enabled: enabled,
            onChanged: (_) => onChanged != null ? onChanged!() : {},
          ),
        ),
        const SizedBox(width: 10),
        if (supportsDirectoryPicker && !pickFile) OutlinedButton.icon(
          icon: const Icon(Symbols.bookmark_manager),
          label: const Text("Edit"),
          onPressed: () async {
            if (beforeSelected != null) beforeSelected!();
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
        ),
        if (supportsDirectoryPicker && pickFile)
          TextButton.icon(
            icon: const Icon(Symbols.file_open),
            label: const Text("Select"),
            onPressed: () async {
              if (beforeSelected != null) beforeSelected!();
              final result = await FilePicker.platform.pickFiles(allowMultiple: false, withData: false);
              final path = result?.files.single.path;
              if (path != null) {
                controller.text = path;
                onSelected();
              }
            },
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
                    selectedIndex: widget.world.navRailIndex,
                    onDestinationSelected: (int index) {
                      setState(() {
                        widget.world.navRailIndex = index;
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
              child: switch (widget.world.navRailIndex) {
                0 => DashboardScreen(widget.world.profile.dashboard, widget.world.client),
                1 => FindPackagesScreen(widget.world.profile.findPackages),
                2 => MyPluginsScreen(widget.world.profile.myPlugins),
                _ => const SettingsScreen(),
              },
            ),
          ],
        ),
      ),
    );
  }
}
