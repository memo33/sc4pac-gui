import 'dart:collection' show LinkedHashSet;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey, KeyDownEvent, KeyRepeatEvent;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:material_symbols_icons/material_symbols_icons.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'package:badges/badges.dart' as badges;
import '../model.dart';
import '../viewmodel.dart';
import 'fragments.dart';
import '../data.dart';

class PackagePage extends StatefulWidget {
  final BareModule module;
  const PackagePage(this.module, {super.key});

  @override
  State<PackagePage> createState() => _PackagePageState();

  static Future<dynamic> pushPkg(BuildContext context, BareModule module, {required void Function() refreshPreviousPage}) {
    return Navigator.push(
      context,
      MaterialPageRoute(barrierDismissible: true, builder: (context1) => PackagePage(module)),
    ).then((_) => refreshPreviousPage());
  }
}
class _PackagePageState extends State<PackagePage> {
  late Future<PackageInfoResult> futureJson;

  static TableRow packageTableRow(Widget? label, Widget child) {
    return TableRow(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 5, 20, 5),
          child: label ?? const SizedBox(),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: child,
        ),
      ],
    );
  }

  @override
  void initState() {
    super.initState();
    _fetchInfo();
  }

  void _fetchInfo() {
    futureJson = World.world.client.info(widget.module, profileId: World.world.profile.id);
  }

  void _refresh() {
    setState(_fetchInfo);
  }

  @override
  Widget build(BuildContext context) {
    final moduleStr = widget.module.toString();
    return Scaffold(
      appBar: AppBar(
        title: CopyButton(
          copyableText: moduleStr,
          child: PkgNameFragment(widget.module, asButton: false, colored: false, refreshParent: _refresh),
        ),
        actions: [
          IconButton(icon: const Icon(Icons.close), tooltip: 'Close all', onPressed: () {
            Navigator.popUntil(context, ModalRoute.withName('/'));
          }),
        ],
      ),
      body: FutureBuilder<PackageInfoResult>(
        future: futureJson,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: ApiErrorWidget(ApiError.from(snapshot.error!)));
          } else if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          } else {
            final remote = snapshot.data!.remote;
            final statuses = snapshot.data!.local.statuses;
            final dependencies = LinkedHashSet<BareModule>.from(switch (remote) {
              {'variants': List<dynamic> variants} =>
                variants.expand((variant) => switch (variant) {
                  {'dependencies': List<dynamic> deps} =>
                    deps.expand((dep) => [if (dep case {'group': String group, 'name': String name}) BareModule(group, name)]),
                  _ => <BareModule>[]
                }),
              _ => <BareModule>[]
            });
            final Iterable<BareModule> requiredBy = switch (remote) {
              {'info': {'requiredBy': List<dynamic> mods }} =>
                mods.map((s) => BareModule.parse(s as String)).whereType<BareModule>(),
              _ => <BareModule>[]
            };
            final List<String> images = switch (remote) {
              {'info': {'images': List<dynamic> images }} =>
                images.map((url) => ImageDialog.redirectImages
                  ? World.world.client.redirectImageUrl(url as String).toString()
                  : url as String  // on non-web platforms there's no CORS issue, so prefer direct url for incremental loading progress indicator
                ).toList(),
              _ => <String>[],
            };
            final Map<String, Map<String, String>> descriptions = switch (remote) {
              {'variantDescriptions': Map<String, dynamic> descs} =>
                descs.map((label, values) => MapEntry(label, (values as Map<String, dynamic>).cast<String, String>())),
              _ => {},
            };
            final List<Iterable<({String label, String value, String? desc})>> variants = switch (remote) {
              {'variants': List<dynamic> vds} =>
                vds.map((vd) => switch (vd) {
                  {'variant': Map<String, dynamic> variant} =>
                    variant.entries.map<({String label, String value, String? desc})>((e) => (label: e.key, value: e.value, desc: descriptions[e.key]?[e.value])),
                  _ => <({String label, String value, String? desc})>[]
                }).toList(),
              _ => []
            };
            final status = statuses[moduleStr];
            bool addedExplicitly = status?.explicit ?? false;
            final installDates = status?.timeLabel2() ?? "Not installed";
            final installedVersion = status?.installed?.version;

            return LayoutBuilder(builder: (context, constraint) =>
              SingleChildScrollView(child: Align(alignment: const Alignment(-0.75, 0), child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraint.maxHeight, maxWidth: 600),
                child: IntrinsicHeight(child: Padding(
                  padding: const EdgeInsets.only(top: 8, bottom: 50),  // sometimes the end of the table is cut off, so we add some space
                  child: Table(
                    columnWidths: const {0: IntrinsicColumnWidth(), 1: FlexColumnWidth()},
                    children: <TableRow>[
                      if (images.isNotEmpty)
                        packageTableRow(null, ImageCarousel(images)),
                      packageTableRow(null, AddPackageButton(widget.module, addedExplicitly, refreshParent: _refresh)),  // TODO positioning
                      packageTableRow(Align(alignment:Alignment.centerLeft, child: InstalledStatusIcon(status)), Text(installDates)),
                      packageTableRow(const Text("Version"), Text(switch (remote) {
                        {'version': String v} => installedVersion != null && installedVersion != v ? "$v (currently installed: $installedVersion)" : v,
                        _ => 'Unknown'
                      })),
                      if (remote case {'info': dynamic info})
                        packageTableRow(const Text("Summary"), switch (info) { {'summary': String text} => MarkdownText(text), _ => const Text('-') }),
                      if (remote case {'info': {'description': String text}})
                        packageTableRow(const Text("Description"), MarkdownText(text)),
                      if (remote case {'info': {'warning': String text}})
                        packageTableRow(const Text("Warning"), MarkdownText(text)),
                      if (remote case {'info': dynamic info})
                        packageTableRow(const Text("Conflicts"), switch (info) { {'conflicts': String text} => MarkdownText(text), _ => const Text('None') }),
                      if (remote case {'info': {'author': String text}})
                        packageTableRow(const Text("Author"), Text(text)),
                      if (remote case {'info': {'website': String text}})
                        packageTableRow(const Text("Website"), CopyButton(copyableText: text, child: Hyperlink(url: text))),
                      packageTableRow(const Text("Subfolder"), Text(switch (remote) { {'subfolder': String v} => v, _ => 'Unknown' })),
                      packageTableRow(const Text("Variants"),
                        variants.isEmpty || variants.length == 1 && variants[0].isEmpty ? const Text('None') : Wrap(
                          direction: Axis.vertical,
                          spacing: 12,
                          crossAxisAlignment: WrapCrossAlignment.start,
                          children: variants.map((vs) => Wrap(spacing: 5, children: vs.map((v) =>
                            PackageTileChip.variant(v.label, v.value, description: v.desc),
                          ).toList())).toList()
                        )
                      ),
                      packageTableRow(const Text("Dependenies"),
                        dependencies.isEmpty ? const Text('None') : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: dependencies.map((module) => PkgNameFragment(module, asButton: true, refreshParent: _refresh, status: statuses[module.toString()])).toList(),
                        )
                      ),
                      packageTableRow(const Text("Required By"),
                        requiredBy.isEmpty ? const Text('None') : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: requiredBy.map((module) => PkgNameFragment(module, asButton: true, refreshParent: _refresh, status: statuses[module.toString()])).toList(),
                        )
                      ),
                    ],
                  ),
                )),
              ))),
            );
          }
        }
      ),
    );
  }
}

class AddPackageButton extends StatefulWidget {
  final BareModule module;
  final bool initialAddedExplicitly;
  final void Function() refreshParent;
  //bool isInstalled;
  const AddPackageButton(this.module, this.initialAddedExplicitly, {required this.refreshParent, super.key});

  @override
  State<AddPackageButton> createState() => _AddPackageButtonState();
}
class _AddPackageButtonState extends State<AddPackageButton> {
  late bool _addedExplicitly = widget.initialAddedExplicitly;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      icon: Icon(Symbols.star, fill: _addedExplicitly ? 1 : 0),
      label: Text(_addedExplicitly ? "Added to Plugins explicitly" : "Add to Plugins explicitly"),
      onPressed: () {
        setState(() {
          _addedExplicitly = !_addedExplicitly;
          World.world.profile.dashboard.onToggledStarButton(widget.module, _addedExplicitly, refreshParent: widget.refreshParent);
        });
      },
    );
  }
}

class ImageCarousel extends StatefulWidget {
  final List<String> images;
  final int initialIndex;
  const ImageCarousel(this.images, {this.initialIndex = 0, super.key});
  @override State<ImageCarousel> createState() => _ImageCarouselState();
}
class _ImageCarouselState extends State<ImageCarousel> {
  late int currentIndex = widget.initialIndex;
  late final _controller = CarouselSliderController();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        CarouselSlider.builder(
          carouselController: _controller,
          options: CarouselOptions(
            height: 150,
            enableInfiniteScroll: false,
            viewportFraction: 0.6,
            onPageChanged: (index, reason) => setState(() => currentIndex = index),
          ),
          itemCount: widget.images.length,
          itemBuilder: (BuildContext context, int itemIndex, int pageViewIndex) {
            return Container(
              // width: 400,
              margin: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Center(
                child: GestureDetector(
                  onTap: () => showDialog(
                    context: context,
                    barrierDismissible: true,
                    builder: (context) => ImageDialog(images: widget.images, initialIndex: itemIndex),
                  ),
                  child: Image.network(widget.images[itemIndex],
                    fit: BoxFit.cover, width: 280, height: 150,
                    frameBuilder: ImageDialog.imageFrameBuilder,
                    loadingBuilder: ImageDialog.redirectImages ? null : ImageDialog.imageLoadingBuilder,
                    errorBuilder: ImageDialog.imageErrorBuilder,
                  ),
                ),
              ),
            );
          }
        ),
        Row(
          children: [
            const Spacer(),
            IconButton(
              icon: const Icon(Symbols.arrow_back_ios_new, size: 16),
              onPressed: currentIndex > 0 ? _controller.previousPage : null,
            ),
            AnimatedSmoothIndicator(
              activeIndex: currentIndex,
              count: widget.images.length,
              effect: SlideEffect(
                dotColor: Theme.of(context).colorScheme.outlineVariant,
                activeDotColor: Theme.of(context).colorScheme.onSurface,
                dotHeight: 12,
                dotWidth: 12,
              ),
              onDotClicked: _controller.animateToPage,
            ),
            IconButton(
              icon: const Icon(Symbols.arrow_forward_ios, size: 16),
              onPressed: currentIndex < widget.images.length - 1 ? _controller.nextPage : null,
            ),
            const Spacer(),
          ],
        ),
      ],
    );
  }
}

class ImagePlaceholder extends StatelessWidget {
  final bool isError;
  const ImagePlaceholder({this.isError = false, super.key});
  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).disabledColor;
    final icon = Icon(isError ? Symbols.broken_image : Symbols.image, size: 48, color: color);
    return Tooltip(
      message: isError ? "Image failed to load" : "Loading image",
      child: isError ? icon : badges.Badge(
        badgeContent: Icon(Symbols.downloading, size: 28, color: color),
        position: badges.BadgePosition.bottomEnd(bottom: -7, end: -9),
        badgeAnimation: const badges.BadgeAnimation.scale(toAnimate: false),
        badgeStyle: badges.BadgeStyle(
          padding: const EdgeInsets.all(1),
          borderRadius: BorderRadius.circular(4),
          badgeColor: Theme.of(context).colorScheme.surface,
        ),
        child: icon,
      ),
    );
  }
}

class ImageDialog extends StatefulWidget {
  final List<String> images;
  final int initialIndex;
  const ImageDialog({required this.images, required this.initialIndex, super.key});
  @override State<ImageDialog> createState() => _ImageDialogState();

  static const bool redirectImages = kIsWeb;  // redirect to solve CORS problems and show no dynamic loading progress as image is not loaded incrementally

  static Widget imageFrameBuilder(BuildContext context, Widget child, int? frame, bool wasSynchronouslyLoaded) {
    return frame == null ? const ImagePlaceholder() : child;
  }

  static Widget imageLoadingBuilder(BuildContext context, Widget child, ImageChunkEvent? loadingProgress) {
    return loadingProgress == null ? child : CircularProgressIndicator(
        value: loadingProgress.expectedTotalBytes != null
            ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
            : null,
    );
  }

  static Widget imageErrorBuilder(BuildContext context, Object error, StackTrace? stackTrace) {
    // return ApiErrorWidget(ApiError.from(error));
    return const ImagePlaceholder(isError: true);
  }
}
class _ImageDialogState extends State<ImageDialog> {
  late int index = widget.initialIndex;
  late Set<int> prefetched = {widget.initialIndex};
  late final _focusNode = FocusNode();

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  void initState() {
    Future.delayed(const Duration(seconds: 0), () => _focusNode.requestFocus());  // gain focus to be able to handle arrow keys
    super.initState();
  }

  void _prefetch(int nextIndex) {
    if (!prefetched.contains(nextIndex)) {
      prefetched.add(nextIndex);
      WidgetsBinding.instance.addPostFrameCallback((_) {
          precacheImage(NetworkImage(widget.images[nextIndex]), context);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasNext = index < widget.images.length - 1;
    if (hasNext) {
      _prefetch(index + 1);
    }
    final moveLeft = index > 0 ? () => setState(() => index -= 1) : null;
    final moveRight = hasNext ? () => setState(() => index += 1) : null;
    return AlertDialog(
      content: Focus(
        focusNode: _focusNode,
        onKeyEvent: (FocusNode node, KeyEvent event) {
          if (event is KeyDownEvent || event is KeyRepeatEvent) {
            if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
              if (moveLeft != null) moveLeft();
              return KeyEventResult.handled;
            } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
              if (moveRight != null) moveRight();
              return KeyEventResult.handled;
            }
          }
          return KeyEventResult.ignored;
        },
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Symbols.arrow_back_ios_new, size: 16),
              onPressed: moveLeft,
            ),
            const SizedBox(width: 8),
            Flexible(  // important to fit the image tightly within the surrounding row
              child: Center(
                heightFactor: 1,
                child: Image.network(widget.images[index],
                  fit: BoxFit.scaleDown,
                  frameBuilder: ImageDialog.imageFrameBuilder,
                  loadingBuilder: ImageDialog.redirectImages ? null : ImageDialog.imageLoadingBuilder,
                  errorBuilder: ImageDialog.imageErrorBuilder,
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Symbols.arrow_forward_ios, size: 16),
              onPressed: moveRight,
            ),
          ],
        ),
      ),
    );
  }
}
