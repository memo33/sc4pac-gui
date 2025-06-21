import 'dart:collection' show LinkedHashSet;
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey, KeyDownEvent, KeyRepeatEvent;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:material_symbols_icons/material_symbols_icons.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'package:badges/badges.dart' as badges;
import 'package:url_launcher/url_launcher.dart';
import '../model.dart';
import '../viewmodel.dart';
import 'fragments.dart';
import '../data.dart';
import '../main.dart' show NavigationService;

class PackagePage extends StatefulWidget {
  final BareModule module;
  final Set<String>? debugChannelUrls;  // for messaging purposes on 404 error
  const PackagePage(this.module, {super.key, this.debugChannelUrls});

  @override
  State<PackagePage> createState() => _PackagePageState();

  static Future<dynamic> pushPkg(BuildContext context, BareModule module, {required void Function() refreshPreviousPage, Set<String>? debugChannelUrls}) {
    return Navigator.push(
      context,
      MaterialPageRoute(barrierDismissible: true, builder: (context1) => PackagePage(module, debugChannelUrls: debugChannelUrls)),
    ).then((_) => refreshPreviousPage());
  }

  static const tableLabelPadding = EdgeInsets.fromLTRB(10, 5, 20, 5);


  static Future<bool?> showUnknownChannelsDialog(List<String> unknownChannelUrls) {
    return showDialog<bool>(
      context: NavigationService.navigatorKey.currentContext!,
      builder: (context) => AlertDialog(
        icon: const Icon(Symbols.stacks),
        title: Text(unknownChannelUrls.length > 1 ? "Add ${unknownChannelUrls.length} new channels?" : "Add a new channel?"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "One or more packages come from another channel."
              " Do you want to add ${unknownChannelUrls.length > 1 ? "these channels" : "this channel"} to your profile?"
            ),
            const SizedBox(height: 10),
            ...unknownChannelUrls.map((url) => Text(url, style: TextStyle(color: Theme.of(context).colorScheme.tertiary))),
          ]
        ),
        actions: [
          OutlinedButton(
            child: const Text("Cancel"),
            onPressed: () => Navigator.pop(context, false),
          ),
          OutlinedButton(
            child: const Text("OK"),
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );
  }

}
class _PackagePageState extends State<PackagePage> {
  late Future<PackageInfoResult> futureJson;

  static TableRow packageTableRow(Widget? label, Widget child) {
    return TableRow(
      children: [
        Padding(
          padding: PackagePage.tableLabelPadding,
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
    futureJson = World.world.client.info(widget.module, profileId: World.world.profile.id)
      .then((PackageInfoResult data) async {
        final debugChannelUrls = widget.debugChannelUrls;
        if (data == PackageInfoResult.notFound && debugChannelUrls != null && debugChannelUrls.isNotEmpty == true) {
          return World.world.profile.dashboard.addUnknownChannelUrls(debugChannelUrls)
            .then((channelsAdded) =>
              !channelsAdded ? data :
                // 2nd attempt at fetching info, using new channels (errors will be handled in Widget build)
                World.world.client.info(widget.module, profileId: World.world.profile.id)
            );
        } else {
          return data;
        }
      });
  }

  void _refresh() {
    setState(_fetchInfo);
  }

  @override
  Widget build(BuildContext context) {
    final moduleStr = widget.module.toString();
    return Scaffold(
      appBar: AppBar(
        title: TextWithCopyButton(
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
            return Center(child: ApiErrorWidget.scroll(ApiError.from(snapshot.error!)));
          } else if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.data == PackageInfoResult.notFound) {
            return Center(child: PackageNotFoundMessage(widget.module, widget.debugChannelUrls));
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
            final conflicting = LinkedHashSet<BareModule>.from(switch (remote) {
              {'variants': List<dynamic> variants} =>
                variants.expand((variant) => switch (variant) {
                  {'conflictingPackages': List<dynamic> mods} =>
                    mods.map((s) => BareModule.parse(s as String)).whereType<BareModule>(),
                  _ => <BareModule>[],
                }),
              _ => <BareModule>[],
            });
            conflicting.addAll(switch (remote) {
              {'info': {'reverseConflictingPackages': List<dynamic> mods }} =>
                mods.map((s) => BareModule.parse(s as String)).whereType<BareModule>(),
              _ => <BareModule>[],
            });
            final List<String> images = switch (remote) {
              {'info': {'images': List<dynamic> images }} =>
                images.map((url) => ImageDialog.redirectImages
                  ? World.world.client.redirectImageUrl(url as String).toString()
                  : url as String  // on non-web platforms there's no CORS issue, so prefer direct url for incremental loading progress indicator
                ).toList(),
              _ => <String>[],
            };
            final Map<String, Map<String, String>> descriptions = switch (remote) {
              {'variantInfo': Map<String, dynamic> infos} =>
                infos.map((variantId, info) => MapEntry(variantId, switch (info) {
                  {'valueDescriptions': Map<String, dynamic> descs} =>
                    descs.cast<String, String>(),
                  _ => {},
                })),
              _ => {},
            };
            final List<({String variantId, List<String> choices})> variantChoices = switch (remote) {
              {'variantChoices': List<dynamic> vcs} =>
                vcs.expand((vc) => switch (vc) {
                  {'variantId': String variantId, 'choices': List<dynamic> choices} =>
                    [(variantId: variantId, choices: choices.cast<String>())],
                  _ => <({String variantId, List<String> choices})>[],
                }).toList(),
              _ => [],
            };
            final status = statuses[moduleStr];
            bool addedExplicitly = status?.explicit ?? false;
            final installDates = status?.timeLabel2() ?? "Not installed";
            final installedVersion = status?.installed?.version;

            final table = Table(
              columnWidths: const {0: IntrinsicColumnWidth(), 1: FlexColumnWidth()},
              children: <TableRow>[
                if (images.isNotEmpty)
                  packageTableRow(null, ImageCarousel(images)),
                packageTableRow(null, AddPackageButton(widget.module, addedExplicitly, refreshParent: _refresh)),  // TODO positioning
                packageTableRow(Align(alignment:Alignment.centerLeft, child: InstalledStatusIcon(status)), Text(installDates)),
                packageTableRow(const Text("Version"), SelectionArea(child: Text(switch (remote) {
                  {'version': String v} => installedVersion != null && installedVersion != v ? "$v (currently installed: $installedVersion)" : v,
                  _ => 'Unknown'
                }))),
                if (remote case {'info': dynamic info})
                  packageTableRow(const Text("Summary"), switch (info) { {'summary': String text} => SelectionArea(child: MarkdownText(text, refreshParent: _refresh)), _ => const Text('-') }),
                if (remote case {'info': {'description': String text}})
                  packageTableRow(const Text("Description"), SelectionArea(child: MarkdownText(text, refreshParent: _refresh))),
                if (remote case {'info': {'warning': String text}})
                  packageTableRow(const Text("Warning"), SelectionArea(child: MarkdownText(text, refreshParent: _refresh))),
                if (remote case {'info': {'author': String text}})
                  packageTableRow(const Text("Author"), SelectionArea(child: Text(text))),
                if (remote case {'info': {'websites': List<dynamic> urls}})
                  if (urls.isNotEmpty)
                    packageTableRow(Text(urls.length > 1 ? "Websites" : "Website"), Column(crossAxisAlignment: CrossAxisAlignment.start, children: urls.cast<String>().map((url) => Hyperlink(url: url)).toList())),
                if (remote case {'channelLabel': [String label]})
                  packageTableRow(const Text("Channel"), SelectionArea(child: Text(label))),
                packageTableRow(const Text("Subfolder"), SelectionArea(child: Text(switch (remote) { {'subfolder': String v} => v, _ => 'Unknown' }))),
                packageTableRow(const Text("Variants"),
                  VariantsPanel(
                    variantChoices: variantChoices,
                    installedStatus: status,
                    descriptions: descriptions,
                    module: widget.module,
                  ),
                ),
                if (remote case {'info': dynamic info})
                  packageTableRow(const Text("Incompatibilities"), SelectionArea(child: switch (info) { {'conflicts': String text} => MarkdownText(text, refreshParent: _refresh), _ => const Text('None') })),
              ],
            );

            return LayoutBuilder(builder: (context, constraint) =>
              SingleChildScrollView(
                child: Column(
                  children: [
                    const SizedBox(height: 8),
                    Align(
                      alignment: const Alignment(-0.75, 0),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(/*minHeight: constraint.maxHeight,*/ maxWidth: 600),
                        child: table,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 8, bottom: 20, left: 15, right: 15),
                      child: switch ([
                        if (conflicting.isNotEmpty)
                          DependenciesCard(
                            conflicting,
                            title: "Conflicts With",
                            statuses: statuses,
                            refreshParent: _refresh,
                            icon: Icon(Symbols.multiple_stop, color: Theme.of(context).hintColor)
                          ),
                        DependenciesCard(dependencies,
                          title: "Dependencies",
                          statuses: statuses,
                          refreshParent: _refresh,
                          icon: Icon(Symbols.call_merge, color: Theme.of(context).hintColor),
                        ),
                        DependenciesCard(requiredBy,
                          title: "Required By",
                          statuses: statuses,
                          refreshParent: _refresh,
                          icon: RotatedBox(quarterTurns: 2, child: Icon(Symbols.call_split, color: Theme.of(context).hintColor)),
                        ),
                      ]) {
                        final pkgLists => switch (290 * pkgLists.length > constraint.maxWidth) {
                          bool vertical =>
                            Flex(
                              direction: vertical ? Axis.vertical : Axis.horizontal,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              // spacing: 15,  // TODO requires Flutter 3.27+
                              children: vertical ? pkgLists : pkgLists.map((c) => Expanded(child: c)).toList(),
                            ),
                        },
                      },
                    ),
                    Wrap(
                      spacing: 50,
                      children: [
                        if (remote case {'metadataSourceUrl': [String metadataSourceUrl]})
                          Padding(
                            padding: const EdgeInsets.only(bottom: 20),
                            child: MetadataUrlButton(
                              url: metadataSourceUrl,
                              icon: badges.Badge(
                                badgeContent: const Icon(Symbols.visibility, size: 14),
                                position: badges.BadgePosition.bottomEnd(bottom: -3, end: -3),
                                badgeAnimation: const badges.BadgeAnimation.scale(toAnimate: false),
                                badgeStyle: badges.BadgeStyle(
                                  shape: badges.BadgeShape.square,
                                  padding: const EdgeInsets.symmetric(vertical: 0.4, horizontal: 2.5),
                                  borderRadius: BorderRadius.circular(10),
                                  badgeColor: Theme.of(context).colorScheme.surface,
                                ),
                                child: const Icon(Symbols.draft),
                              ),
                              text: "View metadata",
                            ),
                          ),
                        if (remote case {'metadataIssueUrl': [String metadataIssueUrl]})
                          Padding(
                            padding: const EdgeInsets.only(bottom: 20),
                            child: MetadataUrlButton(
                              url: metadataIssueUrl,
                              icon: const Icon(Symbols.feedback),
                              text: "Report a problem",
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }
        }
      ),
    );
  }
}

class VariantsPanel extends StatelessWidget {
  final List<({String variantId, List<String> choices})> variantChoices;
  final InstalledStatus? installedStatus;
  final Map<String, Map<String, String>> descriptions;
  final BareModule module;
  const VariantsPanel({required this.variantChoices, required this.installedStatus, required this.descriptions, required this.module, super.key});
  @override
  Widget build(BuildContext context) {
    if (variantChoices.isEmpty) {
      return const Text('None');
    } else {
      return ListenableBuilder(
        listenable: World.world.profile.dashboard,
        builder: (context, child) => FutureBuilder(
          future: World.world.profile.dashboard.variantsFuture,
          builder: (context, snapshot) {
            final selected = snapshot.data?.variants ?? {};
            return LayoutBuilder(builder: (context, constraint) => Wrap(
              direction: Axis.vertical,
              spacing: 12,
              crossAxisAlignment: WrapCrossAlignment.start,
              children: variantChoices.map((vc) => Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      switch (PackageTileChip.stripVariantPackagePrefix(variantId: vc.variantId, package: module.toString())) {
                        final variantIdShort => switch (variantIdShort.split(":")) {
                          final parts => parts.length >= 3
                            ? PkgNameFragment(
                                BareModule(parts[0], parts[1]),
                                localVariant: parts.sublist(2).join(":"),
                                asInlineButton: true,
                                refreshParent: null,  // for now, we do not pass a refresh callback, as we listen to dashboard
                              )
                            : Text(variantIdShort),
                        },
                      },
                      const SizedBox(height: 5),
                      Wrap(
                        spacing: 5,
                        runSpacing: 5,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: vc.choices.map((value) => PackageTileChip.variantValue(
                          value: value,
                          filled: (selected[vc.variantId]?.value ?? installedStatus?.installed?.variant[vc.variantId]) == value,
                          description: descriptions[vc.variantId]?[value],
                        )).toList(),
                      ),
                    ],
                  )),
                  SelectVariantButton(
                    module: module,
                    variantId: vc.variantId,
                    installedValue: installedStatus?.installed?.variant[vc.variantId],
                  ),
                ],
              )).map((row) => ConstrainedBox(constraints: constraint, child: row)).toList(),
            ));
          },
        ),
      );
    }
  }
}

class SelectVariantButton extends StatefulWidget {
  final BareModule module;
  final String variantId;
  final String? installedValue;
  const SelectVariantButton({required this.module, required this.variantId, required this.installedValue, super.key});
  @override
  State<SelectVariantButton> createState() => _SelectVariantButtonState();
}
class _SelectVariantButtonState extends State<SelectVariantButton> {
  bool inProgress = false;
  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(inProgress ? Symbols.pending : Symbols.edit_square),
      tooltip: "Select a variant",
      onPressed: inProgress ? null : () async {
        setState(() => inProgress = true);
        await World.world.profile.dashboard.selectVariant(
          widget.module,
          variantId: widget.variantId,
          installedValue: widget.installedValue,
        );
        setState(() => inProgress = false);
      },
    );
  }
}

class PackageNotFoundMessage extends StatelessWidget {
  final BareModule module;
  final Set<String>? debugChannelUrls;
  const PackageNotFoundMessage(this.module, this.debugChannelUrls, {super.key});
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Set<String>>(
      // If openPackages was called with debugChannelUrls, determine
      // which of the channels are not known yet to show a meaningful error.
      future: debugChannelUrls?.isNotEmpty == true
        ? World.world.profile.channelStatsFuture
          .then((stats) => debugChannelUrls!.difference(stats.channels.map((item) => item.url).toSet()))
        : Future.value({}),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox();
        } else {
          Set<String> unknownChannelUrls = snapshot.data!;
          return ApiErrorWidget.scroll(unknownChannelUrls.isNotEmpty
            ? ApiError.unexpected(
              """The opened package "$module" comes from another channel."""
              " To display packages from this channel, first go to your Dashboard and add the new channel URL.",  // TODO provide dialog option to do this automatically
              unknownChannelUrls.join("\n"),
            )
            : ApiError.unexpected(
              """The package "$module" was not found in any of your channels.""",
              "Maybe the package was renamed or removed from its channel, or it comes from a channel that is not in your list of configured channels yet.",
            ),
          );
        }
      },
    );
  }
}

class MetadataUrlButton extends StatelessWidget {
  final String url;
  final Widget icon;
  final String text;
  const MetadataUrlButton({required this.url, required this.icon, required this.text, super.key});
  @override
  Widget build(BuildContext context) {
    return CopyLinkAddress(
      url: url,
      child: Tooltip(
        message: switch (url.indexOf('?')) { final i => i < 0 ? url : "${url.substring(0, i)}?..." },
        child: TextButton.icon(
          icon: icon,
          label: Text(text),
          onPressed: switch (Uri.tryParse(url)) {
            null => null,
            (Uri uri) => () {
              ContextMenuController.removeAny();
              launchUrl(uri, mode: LaunchMode.externalApplication);
            },
          }
        ),
      ),
    );
  }
}

class DependenciesCard extends StatelessWidget {
  final Iterable<BareModule> dependencies;
  final String title;
  final Map<String, InstalledStatus> statuses;
  final void Function() refreshParent;
  final Widget icon;
  const DependenciesCard(this.dependencies, {required this.title, required this.statuses, required this.refreshParent, required this.icon, super.key});
  static const double _left = 10;
  @override
  Widget build(BuildContext context) {
    return Card(
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(_left, 5, _left, 5),
                  child: Row(children: [
                    icon,
                    const SizedBox(width: 8),
                    Text(title),
                    const SizedBox(width: 8),
                    const Spacer(),
                    if (dependencies.isNotEmpty) Text("(${dependencies.length})"),
                  ]),
                ),
                Divider(color: Theme.of(context).scaffoldBackgroundColor),
                if (dependencies.isEmpty)
                  const Padding(
                    padding: EdgeInsets.fromLTRB(_left, 8, 0, 10),  // roughly aligned with single package in other card
                    child: Text("None"),
                  ),
                ...dependencies.map((module) =>
                  PkgNameFragment(module, asButton: true, refreshParent: refreshParent, status: statuses[module.toString()])
                ),
              ],
            ),
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
          World.world.profile.dashboard.pendingUpdates.onToggledStarButton(widget.module, _addedExplicitly).then((_) => widget.refreshParent());
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

  static const double imageHeight = 300;
  static const double imageWidth = 450;
  static const double viewportFraction = 0.99;  // TODO primitive prefetching of next image

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        CarouselSlider.builder(
          carouselController: _controller,
          options: CarouselOptions(
            enlargeCenterPage: false,
            height: imageHeight,
            enableInfiniteScroll: false,
            viewportFraction: viewportFraction,
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
                    frameBuilder: ImageDialog.imageFrameBuilderCoverShrink(const Size(imageWidth, imageHeight)),
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
              effect: ScrollingDotsEffect(
                maxVisibleDots: 15,
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

// This image painter emulates a new BoxFit type: a combination of `cover` and `scaleDown`,
// i.e. the image is scaled down such that it still covers the rectangle, but is never scaled up.
class CoverShrinkImagePainter extends CustomPainter with ChangeNotifier {
  final RawImage _raw;
  CoverShrinkImagePainter(this._raw);

  @override
  void paint(Canvas canvas, Size size) {
    if (_raw.image == null) return;
    final image = _raw.image!;
    BoxFit? fit;
    Rect rect;
    final viewportRect = const Offset(0, 0) & size;
    var w = image.width * _raw.scale;
    var h = image.height * _raw.scale;
    if (w > size.width && h > size.height) {
      // scale down until one side fits
      final shrinkFactor = max(size.width / w, size.height / h);
      final imgSize = Size(w * shrinkFactor, h * shrinkFactor);
      final offset = Offset(  // center the overlapping axis
        imgSize.width > size.width ? (size.width - imgSize.width) / 2 : 0,
        imgSize.height > size.height ? (size.height - imgSize.height) / 2 : 0,
      );
      rect = offset & imgSize;
    } else {
      // no scaling, show actual size
      fit = BoxFit.none;
      rect = viewportRect;
    }
    canvas.save();
    canvas.clipRect(viewportRect);
    paintImage(
      fit: fit,
      canvas: canvas,
      rect: rect,
      image: image,
      debugImageLabel: _raw.debugImageLabel,
      scale: 1,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CoverShrinkImagePainter oldDelegate) {
    return true;  // at least needed for animated gifs
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
  static int _totalErrCount = 0;

  static Widget imageFrameBuilder(BuildContext context, Widget child, int? frame, bool wasSynchronouslyLoaded) {
    return frame == null ? const ImagePlaceholder() : child;
  }
  static ImageFrameBuilder imageFrameBuilderCoverShrink(Size size) => (context, child, frame, wasSynchronouslyLoaded) {
    if (frame == null) {
      return const ImagePlaceholder();
    } else if (child is Semantics && child.child is RawImage) {
      return CustomPaint(
        size: size,
        willChange: true,
        painter: CoverShrinkImagePainter(child.child as RawImage),
      );
    } else {  // should not happen unless a Flutter upgrade changes the widget tree
      if (_totalErrCount < 5) {
        _totalErrCount++;
        debugPrint("Unexpected image frame type in custom ImageFrameBuilder: $child");
      }
      return const ImagePlaceholder(isError: true);
    }
  };

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
