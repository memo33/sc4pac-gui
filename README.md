# sc4pac GUI

Mod Manager for SimCity 4. Graphical UI for the package manager [sc4pac](https://memo33.github.io/sc4pac/).

This is an early prototype and work-in-progress.


## Overview

The GUI is built using Flutter, a cross-platform app framework.
Flutter can be compiled for multiple platforms,
such as `web` (which runs as web-app in the browser) and `linux`/`windows`/`macos` (which are native desktop apps).
The current goal is to first only build a functional GUI for `web`, which is fully cross-platform,
and later on build desktop apps for supported platforms.

The sc4pac GUI app interacts in a client-server fashion with sc4pac, the core package manager functionality,
using the [sc4pac API](https://memo33.github.io/sc4pac/#/api).
The API server is bundled with the sc4pac CLI.


## State management

- persistent storage: As the `web` frontend does not support persistent storage,
all state that should outlive the running GUI process needs to be written to disk via the API.

- app state: main state that is kept while the app is running. The GUI builds its widgets from the app state.

- ephemeral state: short-lived state implemented by `StatefulWidget`s, such as animations or button states.


## Repository layout

    lib/                  # main source code
    ├── data.dart         # JSON-serializable data classes used by the API
    ├── data.g.dart       # auto-generated serialization code
    ├── main.dart         # main app process
    ├── model.dart        # non-UI logic such as the API client
    ├── viewmodel.dart    # app state
    └── widgets/          # widgets for the different pages of the app
        └── …
    vendor/
    ├── flutter/          # submodule: pinned Flutter version
    └── sc4pac-tools/     # submodule: sc4pac API


## Build instructions

**Once:** Install Flutter with the following commands:

    git submodule update --init --recursive              # downloads Flutter repository (~2GB)
    ./vendor/flutter/bin/flutter config --no-analytics   # downloads Dart SDK and deactivates analytics
    ./vendor/flutter/bin/flutter doctor                  # inspect output to check everything is ok
    ./vendor/flutter/bin/flutter devices                 # inspect available devices, e.g. chrome (web) and linux (desktop)
    ./vendor/flutter/bin/dart run build_runner build --delete-conflicting-outputs   # needs to be rerun whenever ./lib/data.dart is modified

**Once:** Build the development version of the sc4pac CLI (requires the build tool `sbt`).
Repeat this whenever the `sc4pac-tools` submodule is updated.

    git submodule update --init --recursive              # downloads submodule repositories
    (cd ./vendor/sc4pac-tools/ && sbt assembly)          # compiles sc4pac-cli.jar

**Always:** Start the sc4pac server and keep it running. Open a new terminal afterwards.
(If you are in a Windows terminal, create a copy of `sc4pac.bat` and edit it to adjust the path to the jar file:
`./vendor/sc4pac-tools/target/scala-<x.y.z>/sc4pac-cli.jar`)

    ./vendor/sc4pac-tools/sc4pac server --indent 1 --profile-root profiles/profile-1

**Once:** Initialize the plugins profile (requires `curl` or a similar tool).
This merely creates the file `./profiles/profile-1/sc4pac-plugins.json` (which could alternatively be done using the sc4pac CLI).

    curl -X POST http://localhost:51515/init     # First, inspect the output for the recommended "cache" location. Ideally re-use the CACHE of your sc4pac CLI installation.
    curl -X POST -d '{"plugins":"plugins","cache":"CACHE"}' http://localhost:51515/init    # Then, set the "cache" location accordingly.

**Always:** Finally, build and run the GUI.

    ./vendor/flutter/bin/flutter run                     # you can directly choose a device with `--device-id <id>`

Flutter supports hot-reloading, so that changes of the source code become visible in an instant.
Useful Flutter command keys: `R` hot restart, `r` hot reload (unsupported for web), `?` help, `q` quit.
