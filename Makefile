# FLUTTER=flutter
FLUTTER=./vendor/flutter/bin/flutter
DART=./vendor/flutter/bin/dart

build-linux:
	$(FLUTTER) build linux --release
run-linux:
	$(FLUTTER) run --device-id linux
run-web:
	$(FLUTTER) run --device-id chrome

generate-code:
	$(DART) run build_runner build --delete-conflicting-outputs
generate-code-watch:
	$(DART) run build_runner watch --delete-conflicting-outputs
