# sc4pac GUI

Mod Manager for SimCity 4. Graphical UI for the package manager [sc4pac](https://github.com/memo33/sc4pac-tools) ([website](https://memo33.github.io/sc4pac/)).

This is an early prototype and work-in-progress.


## Overview

The sc4pac GUI is built using Flutter, a cross-platform app framework.
Flutter can be compiled for multiple platforms, such as

- `web` (which runs as web-app in the browser) and
- `linux`/`windows`/`macos` (which are native desktop apps).

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

```sh
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
```

## Build instructions

1. **Once:** Install Flutter with the following commands:
   ```sh
   git submodule update --init --recursive              # downloads Flutter repository (~2GB)
   ./vendor/flutter/bin/flutter config --no-analytics   # downloads Dart SDK and deactivates analytics
   ./vendor/flutter/bin/flutter doctor                  # inspect output to check everything is ok
   ./vendor/flutter/bin/flutter devices                 # inspect available devices, e.g. chrome (web) and linux (desktop)
   ./vendor/flutter/bin/dart run build_runner build --delete-conflicting-outputs   # needs to be rerun whenever ./lib/data.dart is modified
   ```

2. **Once:** Build the development version of the sc4pac CLI (requires the build tool `sbt`).
   Repeat this whenever the `sc4pac-tools` submodule is updated.
   ```sh
   git submodule update --init --recursive              # downloads submodule repositories
   (cd ./vendor/sc4pac-tools/ && sbt assembly)          # compiles sc4pac-cli.jar
   ```

3. **Always:** Start the sc4pac server and keep it running. Open a new terminal afterwards.
   (If you are in a Windows terminal, create a copy of `sc4pac.bat` and edit it to adjust the path to the jar file:
   `./vendor/sc4pac-tools/target/scala-<x.y.z>/sc4pac-cli.jar`)
   ```sh
   ./vendor/sc4pac-tools/sc4pac server --indent 1 --profiles-dir profiles
   ```

4. **Always:** Finally, build and run the GUI.
   ```sh
   ./vendor/flutter/bin/flutter run             # you can directly choose a device with `--device-id <id>`
   ```

Flutter supports hot-reloading, so that changes of the source code become visible in an instant.
Useful Flutter command keys: `R` hot restart, `r` hot reload (unsupported for web), `h` help, `q` quit.


## Roadmap

- [ ] managing multiple Plugins folders/profiles:
  The API requires some changes for this, as currently the server can only handle a single profile.
  The GUI needs to implement the initialization of new profiles, in particular, as well as switching of profiles.

- [x] persistent profile-independent storage, such as GUI settings:
  This is related to the previous point; the goal is a file layout such as:
  ```sh
  profiles/
  ├── <id-1>/
  │   └── sc4pac-plugins.json    # plugins for profile 1
  ├── <id-2>/
  │   └── sc4pac-plugins.json    # plugins for profile 2
  ├── …
  └── sc4pac-profiles.json       # profile names, GUI settings
  ```

- [x] configuring variants: should be part of the dashboard.

- [ ] filtering: limiting search results to selected categories. This might require some API changes to avoid unwieldy computations in the GUI.
  Searching only among installed packages is not implemented yet either.

- [ ] displaying whether a dependency is already installed or not: This would probably best be added to the `packages.info` API.

- [ ] images: should be displayed with the package details.

- [ ] image cache: should be implemented in sc4pac-tools to conserve external resources.
  The images for a package only need to be refreshed when a package is updated, i.e. when the package JSON checksum changes.

- [ ] inter-channel reverse dependencies (non-GUI related): for the "required by" field to show dependencies from other channels,
  each channel must provide a list of packages that it depends on, as well as a JSON file for each such package that contains the reverse dependencies.

- [ ] color scheme.

- [ ] deployment: launch scripts for each platform for reliably starting both server and client.
  If one of the processes terminates, this should be handled gracefully by the other.

- [ ] split-pane layout for wide screens: list of packages on the left, individual package details on the right (similar to an email app).
