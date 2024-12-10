// The classes in this file model the app state, i.e. state that is kept while the app is running.
// The view usually builds its widgets from this state.
//
// This is in contrast to ephemeral state (short-lived state implemented by StatefulWidget subclasses)
// and persistent state (long-lived state that outlives the running app and is stored on disk using the sc4pac API).
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:package_info_plus/package_info_plus.dart';
import 'dart:io';
import 'model.dart';
import 'data.dart';
import 'widgets/dashboard.dart';
import 'widgets/fragments.dart';
import 'main.dart' show CommandlineArgs;

enum InitPhase { connecting, loadingProfiles, initializingProfile, initialized }

class World extends ChangeNotifier {
  final CommandlineArgs args;
  final PackageInfo appInfo;
  late InitPhase initPhase;
  late String authority;
  late Sc4pacServer? server;
  late Future<Map<String, dynamic>> initialServerStatus;
  String? serverVersion;
  late Sc4pacClient client;
  late Future<Profiles> profilesFuture;
  late Profile profile;
  late Future<({bool initialized, Map<String, dynamic> data})> readProfileFuture;
  late SettingsData settings;
  // themeMode
  // other gui settings

  void updateConnection(String authority, {required bool notify}) {
    initPhase = InitPhase.connecting;
    this.authority = authority;
    // we call `serverStatus`, even if `ready` resolved to false (launching server failed), to allow connecting to external server process instead
    initialServerStatus = (server?.ready ?? Future.value(true)).then((_) => Sc4pacClient.serverStatus(authority));
    initialServerStatus.then(
      (serverStatus) {  // connection succeeded, so proceed to next phase
        if (serverStatus case {'sc4pacVersion': String version}) {
          serverVersion = version;
        }
        client = Sc4pacClient(authority, onConnectionLost: () => updateConnection(authority, notify: true));
        _switchToLoadingProfiles();
      },
      onError: (_) {},  // connection failed, so stay in InitPhase.connecting
    );
    if (notify) {
      notifyListeners();
    }
  }

  void _switchToLoadingProfiles() {
    initPhase = InitPhase.loadingProfiles;
    profilesFuture =
      client.getSettings()
      .then(updateSettings)
      .then((_) => client.profiles());
    notifyListeners();
  }

  void updateProfile(({String id, String name}) p) {
    profile = Profile(p.id, p.name);
    _switchToInitialzingProfile();
  }

  void _switchToInitialzingProfile() {
    initPhase = InitPhase.initializingProfile;
    readProfileFuture = client.profileRead(profileId: profile.id);
    notifyListeners();
  }

  void updatePaths(({String plugins, String cache}) paths) {
    profile.paths = paths;
    _switchToInitialized();
  }

  void _switchToInitialized() {
    initPhase = InitPhase.initialized;
    notifyListeners();
  }

  void updateSettings(SettingsData settings) {
    this.settings = settings;
    notifyListeners();
  }

  static late World world;

  World({required this.args, required this.appInfo}) {
    World.world = this;  // TODO for simplicity of access, we store a static reference to the one world

    const envPort = bool.hasEnvironment("port") ? int.fromEnvironment("port") : null;
    const envHost = bool.hasEnvironment("host") ? String.fromEnvironment("host") : null;
    final int port = args.port ?? envPort ?? Sc4pacClient.defaultPort;
    if (args.host != null || args.port != null || envHost != null || envPort != null) {
      final h = args.host ?? envHost ?? "localhost";
      authority = "$h:$port";
    } else {
      // for web, api server and webapp server are identical by default
      authority = kIsWeb ? Uri.base.authority : "localhost:$port";
    }

    if (!kIsWeb && args.launchServer) {
      final String bundleRoot = FileSystemEntity.parentOf(Platform.resolvedExecutable);
      server = Sc4pacServer(
        cliDir: args.cliDir ?? "$bundleRoot/cli",
        profilesDir: args.profilesDir ?? "$bundleRoot/profiles",
        port: port,
      );
    } else {
      server = null;
    }

    updateConnection(authority, notify: false);
  }
}

class Profile {
  final String id;
  final String name;
  ({String plugins, String cache})? paths;
  late Dashboard dashboard = Dashboard(this);
  late FindPackages findPackages = FindPackages();
  late MyPlugins myPlugins = MyPlugins();
  late Future<ChannelStats> channelStatsFuture = World.world.client.channelsStats(profileId: id);
  Profile(this.id, this.name);
}

class FindPackages {
  String? searchTerm;
  String? selectedCategory;
}

enum InstallStateType { markedForInstall, explicitlyInstalled, installedAsDependency }
enum SortOrder { relevance, updated, installed }

class MyPlugins {
  String? searchTerm;
  String? selectedCategory;
  Set<InstallStateType> installStateSelection =
    {/*InstallStateType.markedForInstall,*/ InstallStateType.explicitlyInstalled, InstallStateType.installedAsDependency};
  SortOrder sortOrder = SortOrder.relevance;  // default order as returned by Api
}

enum PendingUpdateStatus { add, remove, reinstall }

class Dashboard extends ChangeNotifier {
  UpdateProcess? _updateProcess;
  UpdateProcess? get updateProcess => _updateProcess;
  set updateProcess(UpdateProcess? updateProcess) {
    _updateProcess = updateProcess;
    notifyListeners();
  }
  final Profile profile;
  final pendingUpdates = PendingUpdates();
  late Future<Map<String, dynamic>> variantsFuture;
  Dashboard(this.profile) {
    fetchVariants();
  }

  void fetchVariants() {
    variantsFuture = World.world.client.variantsList(profileId: profile.id);
    notifyListeners();
  }

  void onUpdateFinished(UpdateStatus status) {
    if (status == UpdateStatus.finished) {  // no error/no canceled
      pendingUpdates.clear();
    }
    fetchVariants();
    notifyListeners();
  }

}

class PendingUpdates extends ChangeNotifier {

  final Map<BareModule, PendingUpdateStatus> _overwrites = {};  // these are used as overrides of package installation states in the UI
  // Mark the explicit-install state for a package. If the star button is toggled twice, this removes the package from `pendingUpdates` again.
  void setPendingUpdate(BareModule pkg, PendingUpdateStatus status) {
    final previous = _overwrites[pkg];
    if (previous == null) {
      _overwrites[pkg] = status;
      notifyListeners();
    } else if (previous == status) {
      // nothing to do
    } else if (previous == PendingUpdateStatus.reinstall || status == PendingUpdateStatus.reinstall) {
      _overwrites[pkg] = status;
      notifyListeners();
    } else if (previous != status) {  // add/remove only
      _overwrites.remove(pkg);
      notifyListeners();
    } else {
      // should never happen
    }
  }
  void clear() {
    _overwrites.clear();
    notifyListeners();
  }

  onToggledStarButton(BareModule module, bool checked, {required void Function() refreshParent}) {
    final task = checked ?
        World.world.client.add(module, profileId: World.world.profile.id) :
        World.world.client.remove(module, profileId: World.world.profile.id);
    task.then((_) {
      setPendingUpdate(module, checked ? PendingUpdateStatus.add : PendingUpdateStatus.remove);
      refreshParent();
    }, onError: ApiErrorWidget.dialog);  // async, but we do not need to await result
  }

  int getCount() {
    return _overwrites.length;
  }

  List<MapEntry<BareModule, PendingUpdateStatus>> sortedEntries() {
    final elems = _overwrites.entries.toList();
    elems.sort((a, b) => BareModule.compareAlphabetically(a.key, b.key));
    return elems;
  }
}

enum UpdateStatus { running, finished, finishedWithError, canceled }

class UpdateProcess extends ChangeNotifier {
  late final WebSocketChannel _ws;
  late final Stream<Map<String, dynamic>> _stream;

  UpdatePlan? plan;
  final downloads = <String>[];
  final Map<String, int> downloadLength = {};
  final Map<String, int> downloadDownloaded = {};
  final Map<String, bool> downloadSuccess = {};
  bool downloadsFailed = false;
  bool downloadsCompleted = false;
  ProgressUpdateExtraction? extractionProgress;
  bool _extractionFinishedOnNextMsg = false;
  bool extractionFinished = false;
  ApiError? err;

  UpdateStatus _status = UpdateStatus.running;
  UpdateStatus get status => _status;
  set status(UpdateStatus status) {
    _status = status;
    if (_status != UpdateStatus.running) {
      onFinished(_status);
    }
  }

  final PendingUpdates pendingUpdates;
  final void Function(UpdateStatus) onFinished;
  final bool isBackground;

  UpdateProcess({required this.pendingUpdates, required this.onFinished, this.isBackground = false}) {
    final stAuth = World.world.settings.stAuth;
    if (stAuth?.expired == true) {
      err = ApiError.unexpected("The Simtropolis authentication cookie has expired. Go to Settings to create a new one.", "");
      status = UpdateStatus.finishedWithError;
    } else {
      _ws = World.world.client.update(profileId: World.world.profile.id, simtropolisCookie: stAuth?.cookie);
      _stream = _ws.ready
        .then((_) => true, onError: (e) {
          err = ApiError.unexpected('Failed to open websocket. Make sure the local sc4pac server is running.', e.toString());
          status = UpdateStatus.finishedWithError;
          return false;
        })
        .asStream()
        .asyncExpand((isReady) => !isReady
          ? const Stream<Map<String, dynamic>>.empty()
          : _ws.stream.map((data) {
            return jsonDecode(data as String) as Map<String, dynamic>;  // TODO jsonDecode could be run on a background thread
          })
        );
      _stream.listen(handleMessage);
    }
  }

  void cancel() {
    _ws.sink.close();
    status = UpdateStatus.canceled;
  }

  void handleMessage(Map<String, dynamic> data) {
    if (data case {'\$type': String type}) {
      if (_extractionFinishedOnNextMsg) {
        extractionFinished = true;
        _extractionFinishedOnNextMsg = false;
      }

      if (type == '/prompt/confirmation/update/plan') {
        final plan = UpdatePlan.fromJson(data);
        this.plan = plan;
        for (final entry in plan.changes.entries) {
          final change = entry.value;
          pendingUpdates.setPendingUpdate(BareModule.parse(entry.key),
            change.versionTo == null ? PendingUpdateStatus.remove :
            change.versionFrom == null ? PendingUpdateStatus.add :
            PendingUpdateStatus.reinstall,
          );
        }
        if (isBackground) {
          cancel();  // for background process we are done, as we do not want to install anything
        } else if (plan.nothingToDo){
          _ws.sink.add(jsonEncode(plan.responses['Yes']));  // everything up-to-date
        } else {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            DashboardScreen.showUpdatePlan(plan)
              .then((choice) => _ws.sink.add(jsonEncode(plan.responses[choice])));
          });
        }
      } else if (type == '/prompt/confirmation/update/warnings') {  // not relevant for isBackground, as these warnings are triggered during installation
        final msg = ConfirmationUpdateWarnings.fromJson(data);
        if (msg.warnings.isEmpty) {
          _ws.sink.add(jsonEncode(msg.responses['Yes']));  // no warnings
        } else {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            DashboardScreen.showWarningsDialog(msg)
              .then((choice) => _ws.sink.add(jsonEncode(msg.responses[choice])));
          });
        }
      } else if (type == '/prompt/choice/update/variant') {
        final msg = ChoiceUpdateVariant.fromJson(data);
        if (isBackground) {
          // we cannot make this selection without user interaction
          pendingUpdates.setPendingUpdate(BareModule.parse(msg.package), PendingUpdateStatus.reinstall);
          cancel();
        } else {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            DashboardScreen.showVariantDialog(msg).then((choice) {
              if (choice == null) {
                cancel();
              } else {
                _ws.sink.add(jsonEncode(msg.responses[choice]));
              }
            });
          });
        }
      } else if (type.startsWith('/progress/download/')) {
        switch (type) {
          case '/progress/download/started':
            final msg = ProgressDownloadStarted.fromJson(data);
            downloads.add(msg.url);
            break;
          case '/progress/download/length':
            final msg = ProgressDownloadLength.fromJson(data);
            downloadLength[msg.url] = msg.length;
            break;
          case '/progress/download/downloaded':
            final msg = ProgressDownloadDownloaded.fromJson(data);
            downloadDownloaded[msg.url] = msg.downloaded;
            break;
          case '/progress/download/finished':
            final msg = ProgressDownloadFinished.fromJson(data);
            downloadSuccess[msg.url] = msg.success;
            downloadsFailed |= !msg.success;
            downloadsCompleted |= downloadSuccess.length == downloads.length;
            break;
          default:
            debugPrint('Message type not implemented: $data');  // TODO
            break;
        }
      } else if (type == '/progress/update/extraction') {  // not relevant for isBackground
        final msg = ProgressUpdateExtraction.fromJson(data);
        extractionProgress = msg;
        if (msg.progress.numerator == msg.progress.denominator) {
          _extractionFinishedOnNextMsg = true;
        }
      } else if (type == '/result') {
        status = UpdateStatus.finished;
      } else if (type.startsWith('/error/')) {
        err = ApiError(data);
        status = UpdateStatus.finishedWithError;  // TODO handle error
      } else {
        debugPrint('Message type not implemented: $data');  // TODO
      }
      notifyListeners();
    } else {
      debugPrint('Unexpected message format: $data');  // TODO
    }
  }
}
