// The classes in this file model the app state, i.e. state that is kept while the app is running.
// The view usually builds its widgets from this state.
//
// This is in contrast to ephemeral state (short-lived state implemented by StatefulWidget subclasses)
// and persistent state (long-lived state that outlives the running app and is stored on disk using the sc4pac API).
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'model.dart';
import 'data.dart';
import 'widgets/dashboard.dart';

class World extends ChangeNotifier {
  Profile? profile;
  // themeMode
  // server
  // other gui settings
  final Sc4pacClient client = Sc4pacClient();

  void updateProfileAndNotify(({String id, String name}) p) {
    profile = Profile(p.id, p.name);
    notifyListeners();
  }

  static late World world;

  World() {
    World.world = this;  // TODO for simplicity of access, we store a static reference to the one world
  }
}

class Profile {
  final String id;
  final String name;
  late Dashboard dashboard = Dashboard((id: id, name: name));
  late FindPackages findPackages = FindPackages();
  late MyPlugins myPlugins = MyPlugins();
  Profile(this.id, this.name);
}

class FindPackages {
  String? searchTerm;
}

enum InstallStateType { markedForInstall, explicitlyInstalled, installedAsDependency }

class MyPlugins {
  Set<InstallStateType> installStateSelection =
    {InstallStateType.markedForInstall, InstallStateType.explicitlyInstalled, InstallStateType.installedAsDependency};
}

class Dashboard extends ChangeNotifier {
  UpdateProcess? _updateProcess;
  UpdateProcess? get updateProcess => _updateProcess;
  set updateProcess(UpdateProcess? updateProcess) {
    _updateProcess = updateProcess;
    notifyListeners();
  }
  final ({String id, String name}) profile;
  Dashboard(this.profile);
}

enum UpdateStatus { running, finished, finishedWithError, canceled }

class UpdateProcess {
  late final WebSocketChannel _ws;
  late final Stream<Map<String, dynamic>> stream;

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
      onFinished();
    }
  }

  final void Function() onFinished;

  UpdateProcess({required this.onFinished}) {
    _ws = Api.update(profileId: World.world.profile!.id);
    stream =
      _ws.ready
        .then((_) => true, onError: (e) {
          err = ApiError.unexpected('Failed to open websocket. Make sure the local sc4pac server is running.', e.toString());
          status = UpdateStatus.finishedWithError;
          return false;
        })
        .asStream()
        .asyncExpand((isReady) => !isReady
          ? const Stream<Map<String, dynamic>>.empty()
          : _ws.stream.map((data) {
            final msg = jsonDecode(data as String) as Map<String, dynamic>;  // TODO jsonDecode could be run on a background thread
            handleMessage(msg);  // must be called on EVERY message of the stream
            return msg;
          })
        )
        .asBroadcastStream();  // TODO reconsider this (this was needed to reopen a StreamBuilder widget built from this stream)
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
        if (plan.nothingToDo){
          _ws.sink.add(jsonEncode(plan.responses['Yes']));  // everything up-to-date
        } else {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            DashboardScreen.showUpdatePlan(plan)
              .then((choice) => _ws.sink.add(jsonEncode(plan.responses[choice])));
          });
        }
      } else if (type == '/prompt/confirmation/update/warnings') {
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
        WidgetsBinding.instance.addPostFrameCallback((_) {
          DashboardScreen.showVariantDialog(msg).then((choice) => _ws.sink.add(jsonEncode(msg.responses[choice])));
        });
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
      } else if (type == '/progress/update/extraction') {
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
    } else {
      debugPrint('Unexpected message format: $data');  // TODO
    }
  }
}
