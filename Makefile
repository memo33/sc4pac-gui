# FLUTTER=flutter
FLUTTER=./vendor/flutter/bin/flutter
DART=./vendor/flutter/bin/dart
BASEHREF=/webapp/

build-linux:
	$(FLUTTER) build linux --release
build-web:
	$(FLUTTER) build web --base-href=$(BASEHREF) --release
run-linux:
	$(FLUTTER) run --device-id linux
# for debugging on web, we connect to external sc4pac process (the release version uses the same port for API and webapp instead)
run-web:
	$(FLUTTER) run --device-id chrome --dart-define=port=51515

generate-code:
	$(DART) run build_runner build --delete-conflicting-outputs
generate-code-watch:
	$(DART) run build_runner watch --delete-conflicting-outputs
