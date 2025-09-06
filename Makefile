# FLUTTER=flutter
FLUTTER=./vendor/flutter/bin/flutter
DART=./vendor/flutter/bin/dart
BASEHREF=/webapp/
CLIDIR=./vendor/sc4pac-tools/

build-linux:
	$(FLUTTER) build linux --release
build-web:
	$(FLUTTER) build web --base-href=$(BASEHREF) --release
build-windows:
	$(FLUTTER) build windows --release

# For fast debugging on desktop, we connect to external sc4pac process (the release version instead launches the server)
run-linux:
	$(FLUTTER) run --device-id linux --dart-entrypoint-args --launch-server=false
# The following relaunches the sc4pac server on every hot-restart, which makes it a bit slower.
run-linux-server:
	$(FLUTTER) run --device-id linux --dart-entrypoint-args --launch-server=true,--profiles-dir,profiles,--sc4pac-cli-dir,$(CLIDIR)
# By defining a port, we connect to external sc4pac process (the release version uses the same port for API and webapp instead)
run-web:
	$(FLUTTER) run --device-id chrome --dart-define=port=51515

test:
	$(FLUTTER) test test/* -r expanded

generate-code:
	$(DART) run build_runner build --delete-conflicting-outputs
generate-code-watch:
	$(DART) run build_runner watch --delete-conflicting-outputs

.PHONY: build-linux build-web run-linux run-linux-server run-web test
