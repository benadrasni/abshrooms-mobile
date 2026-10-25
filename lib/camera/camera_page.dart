import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:image_picker/image_picker.dart';
import 'package:whats_that_mushroom/ads/ad_units.dart';
import 'package:whats_that_mushroom/camera/outside_page.dart';
import 'package:whats_that_mushroom/camera/plant_id.dart';
import 'package:whats_that_mushroom/copy.dart';
import 'package:whats_that_mushroom/data/models.dart';
import 'package:whats_that_mushroom/data/notebook.dart';
import 'package:whats_that_mushroom/field_guide/field_guide_page.dart';
import 'package:whats_that_mushroom/person/auth.dart';
import 'package:whats_that_mushroom/person/sign_in_page.dart';
import 'package:whats_that_mushroom/purchase/names.dart';
import 'package:whats_that_mushroom/purchase/purchases.dart';
import 'package:whats_that_mushroom/search/search_page.dart';
import 'package:whats_that_mushroom/shell/scope.dart';
import 'package:whats_that_mushroom/shell/theme.dart';
import 'package:whats_that_mushroom/species/species_page.dart';

const _well = Color(0xFF0D0C0A);
const _scrim = Color(0x66000000);

/// Full-screen field-guide camera, laid out like the plants guide.
///
/// A name in the book opens that species. A name outside the book opens
/// its own page. A guest has one name. A signed-in account has five each
/// UTC month, and a rewarded ad can add five more. Field Guide is unlimited.
/// `identifyMushroom` counts the name. There is no location question: this
/// guide has no floristic regions, and a photo name does not use a place.
class CameraPage extends StatefulWidget {
  /// When set, this stands in for the live camera. Production leaves it
  /// empty and opens the device camera.
  final WidgetBuilder? livePreview;
  final Future<String?> Function(ImageSource source)? pickPhoto;
  final Future<Uint8List> Function(String path)? readPhoto;
  final Future<List<NameGuess>> Function(Uint8List jpeg, String language)?
  identify;

  /// When set, tests skip the store receipt and use this.
  final bool? fieldGuide;

  /// When set, tests skip the Firebase account. A guest has one name.
  final bool? signedIn;
  final void Function(String latin)? onOpenSpecies;
  final VoidCallback? onKey;
  final VoidCallback? onClose;

  /// When set, the limit sheet calls this instead of loading a rewarded ad.
  final Future<void> Function()? onWatchAd;

  const CameraPage({
    super.key,
    this.livePreview,
    this.pickPhoto,
    this.readPhoto,
    this.identify,
    this.fieldGuide,
    this.signedIn,
    this.onOpenSpecies,
    this.onKey,
    this.onClose,
    this.onWatchAd,
  });

  @override
  State<CameraPage> createState() => _CameraPageState();
}

class _CameraPageState extends State<CameraPage> with WidgetsBindingObserver {
  var _busy = false;
  var _naming = false;
  var _ownsShot = false;
  String? _shotPath;
  bool _notMushroom = false;
  var _limit = false;
  var _countedEmpty = false;
  CameraController? _camera;
  var _previewEpoch = 0;
  var _previewStarting = false;
  RewardedAd? _rewarded;
  var _adLoading = false;
  var _adAttempts = 0;

  bool get _signedIn => widget.signedIn ?? photoAccountSignedIn();

  bool get _fieldGuide => widget.fieldGuide ?? Purchases.hasFieldGuide();

  NameAllowance get _allowance => Names.allowance(
    fieldGuide: _fieldGuide,
    signedIn: _signedIn,
  );

  bool get _canName => _allowance.unlimited || _allowance.namesLeft > 0;

  bool get _offerAd =>
      nameOffersAd(_allowance) &&
      (widget.onWatchAd != null || (Ads.enabled && Ads.rewardUnitId() != null));

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    Names.revision.addListener(_onAllowance);
    Auth.revision.addListener(_onAllowance);
    Ads.ready.addListener(_onAllowance);
    unawaited(Names.restore());
    unawaited(_startPreview());
    _ensureAd();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    Names.revision.removeListener(_onAllowance);
    Auth.revision.removeListener(_onAllowance);
    Ads.ready.removeListener(_onAllowance);
    _previewEpoch++;
    final camera = _camera;
    _camera = null;
    camera?.dispose();
    _rewarded?.dispose();
    _rewarded = null;
    if (!_busy) _releaseShot();
    super.dispose();
  }

  void _onAllowance() {
    if (!mounted) return;
    if (_fieldGuide) {
      _rewarded?.dispose();
      _rewarded = null;
      _adLoading = false;
    }
    _ensureAd();
    setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (widget.livePreview != null) return;
    final camera = _camera;
    if (state == AppLifecycleState.inactive) {
      if (camera == null || !camera.value.isInitialized) return;
      unawaited(_stopPreview());
    } else if (state == AppLifecycleState.resumed &&
        _camera == null &&
        !_previewStarting) {
      unawaited(_startPreview());
    }
  }

  Future<void> _startPreview() async {
    if (widget.livePreview != null || _previewStarting) return;
    _previewStarting = true;
    final epoch = ++_previewEpoch;
    try {
      final previous = _camera;
      _camera = null;
      if (previous != null) await previous.dispose();
      if (!mounted || epoch != _previewEpoch) return;
      final cameras = await availableCameras();
      if (!mounted || epoch != _previewEpoch || cameras.isEmpty) return;
      var selected = cameras.first;
      for (final camera in cameras) {
        if (camera.lensDirection == CameraLensDirection.back) {
          selected = camera;
          break;
        }
      }
      final controller = CameraController(
        selected,
        ResolutionPreset.high,
        enableAudio: false,
      );
      await controller.initialize();
      if (!mounted || epoch != _previewEpoch) {
        await controller.dispose();
        return;
      }
      try {
        await controller.lockCaptureOrientation(DeviceOrientation.portraitUp);
      } catch (error) {
        debugPrint('camera orientation: $error');
      }
      if (!mounted || epoch != _previewEpoch) {
        await controller.dispose();
        return;
      }
      setState(() => _camera = controller);
    } catch (error) {
      debugPrint('camera preview: $error');
    } finally {
      _previewStarting = false;
    }
  }

  Future<void> _stopPreview() async {
    _previewEpoch++;
    final camera = _camera;
    _camera = null;
    if (mounted && camera != null) setState(() {});
    await camera?.dispose();
  }

  Future<void> _resumePreview() async {
    final camera = _camera;
    if (camera == null || !camera.value.isInitialized) {
      await _startPreview();
      return;
    }
    if (!camera.value.isPreviewPaused) return;
    try {
      await camera.resumePreview();
    } catch (error) {
      debugPrint('camera preview: $error');
      await _startPreview();
    }
  }

  void _releaseShot() {
    final path = _shotPath;
    _shotPath = null;
    if (path != null && _ownsShot) unawaited(_deleteFile(path));
  }

  Future<void> _deleteFile(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) await file.delete();
    } on FileSystemException {
      // The cache file is already gone.
    }
  }

  void _clearSheet() {
    _releaseShot();
    setState(() {
      _naming = false;
      _notMushroom = false;
      _limit = false;
      _countedEmpty = false;
      _shotPath = null;
    });
    unawaited(_resumePreview());
  }

  void _ensureAd() {
    if (!mounted ||
        widget.onWatchAd != null ||
        _rewarded != null ||
        _adLoading) {
      return;
    }
    if (_fieldGuide || !_signedIn) return;
    if (!Ads.enabled) return;
    final id = Ads.rewardUnitId();
    if (id == null) return;
    _adLoading = true;
    RewardedAd.load(
      adUnitId: id,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _adLoading = false;
          _adAttempts = 0;
          if (!mounted) {
            ad.dispose();
            return;
          }
          _rewarded = ad;
        },
        onAdFailedToLoad: (error) {
          debugPrint('camera ad: $error');
          _adLoading = false;
          _rewarded = null;
          _adAttempts += 1;
          if (!mounted || _adAttempts > 3) return;
          _ensureAd();
        },
      ),
    );
  }

  Future<void> _showRewardedAd() async {
    final ad = _rewarded;
    if (ad == null) {
      _adAttempts = 0;
      _ensureAd();
      if (!mounted) return;
      _snack(GuideScope.of(context).copy.adLoading);
      return;
    }
    final done = Completer<void>();
    var earned = false;
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        if (_rewarded == ad) _rewarded = null;
        _ensureAd();
        if (!done.isCompleted) done.complete();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        debugPrint('camera ad: $error');
        ad.dispose();
        if (_rewarded == ad) _rewarded = null;
        _ensureAd();
        if (!done.isCompleted) done.complete();
      },
    );
    _rewarded = null;
    await ad.show(
      onUserEarnedReward: (ad, reward) {
        earned = true;
      },
    );
    await done.future;
    if (!earned) return;
    if (Firebase.apps.isEmpty) {
      await Names.grant();
      return;
    }
    try {
      final granted = await grantPhotoName();
      if (!granted && mounted) {
        _snack(GuideScope.of(context).copy.cameraLimitAllBody);
      }
    } catch (error) {
      debugPrint('camera ad: $error');
      if (mounted) _snack(GuideScope.of(context).copy.adLoading);
    }
  }

  Future<void> _watchAd() async {
    final action = widget.onWatchAd ?? _showRewardedAd;
    await action();
    if (!mounted) return;
    setState(() {
      if (_canName) _limit = false;
    });
  }

  Future<void> _openFieldGuide() async {
    await Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => const FieldGuidePage()));
    if (!mounted) return;
    setState(() {
      if (_canName) _limit = false;
    });
  }

  Future<void> _openSignIn() async {
    await Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => const SignInPage()));
    if (!mounted) return;
    setState(() {
      if (_canName) _limit = false;
    });
  }

  void _close() {
    _releaseShot();
    final action = widget.onClose;
    if (action != null) {
      action();
      return;
    }
    Navigator.maybePop(context);
  }

  void _key() {
    _releaseShot();
    final action = widget.onKey;
    if (action != null) {
      action();
      return;
    }
    GuideScope.of(context).selectTab(0);
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<String?> _pickDefault(ImageSource source) async {
    if (source == ImageSource.camera) {
      final shot = await _takePreviewPicture();
      if (shot != null) return shot;
    }
    if (!mounted) return null;
    final image = await ImagePicker().pickImage(
      source: source,
      maxWidth: 1280,
      maxHeight: 1280,
      imageQuality: 85,
    );
    return image?.path;
  }

  Future<String?> _takePreviewPicture() async {
    final camera = _camera;
    if (camera == null ||
        !camera.value.isInitialized ||
        camera.value.isTakingPicture) {
      return null;
    }
    try {
      final shot = await camera.takePicture();
      return shot.path;
    } catch (error) {
      debugPrint('camera shutter: $error');
      return null;
    }
  }

  Future<Uint8List> _readPhoto(String path) async {
    return jpegMaxEdge(await File(path).readAsBytes());
  }

  Future<void> _openSpecies(String latin) async {
    final action = widget.onOpenSpecies;
    if (action != null) {
      action(latin);
      return;
    }
    if (!mounted) return;
    await Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => SpeciesPage(latin: latin)));
  }

  Future<void> _openSearch() async {
    if (!mounted) return;
    await Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const SearchPage()));
  }

  Future<void> _finishOutside(OutsideResult result) async {
    if (!mounted) return;
    final message = result.message;
    if (result.find || result.seen) {
      final messenger = ScaffoldMessenger.of(context);
      GuideScope.of(context).selectTab(result.seen ? 2 : 0);
      Navigator.of(context).popUntil((route) => route.isFirst);
      if (message != null && message.isNotEmpty) {
        messenger.showSnackBar(SnackBar(content: Text(message)));
      }
      return;
    }
    if (message != null && message.isNotEmpty) _snack(message);
    final species = result.species;
    if (species == null || !mounted) return;
    await _openSpecies(species);
  }

  Future<void> _capture(ImageSource source) async {
    if (_busy || _naming) return;
    if (!_canName) {
      setState(() => _limit = true);
      return;
    }
    final scope = GuideScope.of(context);
    final copy = scope.copy;
    final catalog = scope.catalog.data;
    if (catalog == null) {
      _snack(copy.catalogError);
      return;
    }
    setState(() => _busy = true);
    String? path;
    var keepFile = false;
    try {
      _ownsShot = widget.pickPhoto == null;
      final pick = widget.pickPhoto ?? _pickDefault;
      path = await pick(source);
      if (!mounted || path == null) return;
      final previous = _shotPath;
      if (previous != null && previous != path && _ownsShot) {
        unawaited(_deleteFile(previous));
      }
      setState(() {
        _naming = true;
        _notMushroom = false;
        _limit = false;
        _shotPath = path;
      });
      final read = widget.readPhoto ?? _readPhoto;
      final bytes = await read(path);
      if (!mounted) return;
      final identify = widget.identify ?? identifyMushroom;
      final guesses = await identify(bytes, scope.settings.language);
      final applied = Names.takeServerApply();
      if (!mounted) return;
      final outcome = _outcome(guesses, catalog);
      if (outcome.notMushroom) {
        setState(() {
          _naming = false;
          _notMushroom = true;
          _countedEmpty = applied && Names.lastCharged;
        });
        return;
      }
      final id = DateTime.now().microsecondsSinceEpoch.toString();
      final saved = await scope.notebook.savePhoto(bytes, id);
      final photoPath = saved ?? path;
      if (saved == null) keepFile = true;
      final leading = outcome.leading!;
      final species = outcome.speciesName;
      await scope.notebook.addFind(
        FindRecord(
          id: id,
          millis: DateTime.now().millisecondsSinceEpoch,
          latin: species,
          outsideName: species == null ? leading.scientificName : null,
          spoken: species == null ? _spoken(leading) : null,
          probability: leading.probability,
          photoPath: photoPath,
          others: [
            for (final guess in outcome.others)
              FindName(
                scientificName: guess.scientificName,
                probability: guess.probability,
                commonNames: guess.commonNames,
              ),
          ],
        ),
      );
      if (!applied && !_fieldGuide) {
        await Names.spend(signedIn: _signedIn);
      }
      if (!mounted) return;
      if (saved != null && _ownsShot && saved != path) {
        unawaited(_deleteFile(path));
      }
      setState(() {
        _naming = false;
        _shotPath = null;
      });
      await _stopPreview();
      if (!mounted) return;
      if (species != null) {
        await _openSpecies(species);
      } else {
        final result = await Navigator.of(context).push<OutsideResult>(
          MaterialPageRoute(
            builder: (_) => OutsidePage(
              recordId: id,
              onOpenSpecies: widget.onOpenSpecies,
              onSearch: () => unawaited(_openSearch()),
            ),
          ),
        );
        if (!mounted || result == null) return;
        await _finishOutside(result);
      }
      if (mounted) await _startPreview();
    } on NameRefused catch (error) {
      Names.takeServerApply();
      if (!mounted) return;
      final limit = error.reason == 'sign-in' || error.reason == 'no-names';
      setState(() {
        _naming = false;
        _notMushroom = false;
        _limit = limit;
      });
      if (!limit) _snack(_refusalCopy(error.reason, copy));
      _releaseShot();
    } catch (error) {
      debugPrint('camera: $error');
      if (!mounted) return;
      setState(() {
        _naming = false;
        _notMushroom = false;
      });
      _snack(cameraFailure(error, copy));
      _releaseShot();
    } finally {
      if (!mounted && path != null && _ownsShot && !keepFile) {
        unawaited(_deleteFile(path));
      }
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scope = GuideScope.of(context);
    final copy = scope.copy;
    final catalogMissing = scope.catalog.data == null;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: _well,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: _well,
        body: Stack(
          fit: StackFit.expand,
          children: [
            _View(
              path: _shotPath,
              camera: _camera,
              livePreview: widget.livePreview,
            ),
            const IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0x88000000),
                      Color(0x00000000),
                      Color(0x00000000),
                      Color(0xBB000000),
                    ],
                    stops: [0, 0.22, 0.64, 1],
                  ),
                ),
              ),
            ),
            SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final size = MediaQuery.sizeOf(context);
                  final wide = _wide(size);
                  final frameLeft = wide ? constraints.maxWidth * 0.10 : 44.0;
                  final frameRight = wide ? 150.0 : 44.0;
                  final frameTop = wide
                      ? constraints.maxHeight * 0.12
                      : (constraints.maxHeight * 0.22).clamp(72.0, 230.0);
                  final frameHeight = wide
                      ? constraints.maxHeight * 0.72
                      : math.min(300.0, constraints.maxHeight * 0.36);
                  final controls = _Controls(
                    column: wide,
                    shutterLabel: copy.cameraShutter,
                    rollLabel: copy.cameraRoll,
                    keyLabel: copy.cameraKey,
                    onShutter: () => _capture(ImageSource.camera),
                    onRoll: () => _capture(ImageSource.gallery),
                    onKey: _key,
                  );
                  return Stack(
                    children: [
                      Positioned(
                        left: frameLeft,
                        right: frameRight,
                        top: frameTop,
                        height: frameHeight,
                        child: const IgnorePointer(
                          child: CustomPaint(
                            painter: _CornerPainter(),
                            child: SizedBox.expand(),
                          ),
                        ),
                      ),
                      Positioned(
                        left: wide ? frameLeft : 24,
                        right: wide ? frameRight : 24,
                        top: wide ? null : frameTop + frameHeight + 16,
                        bottom: wide ? 12 : null,
                        child: Text(
                          catalogMissing ? copy.catalogError : copy.cameraTip,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      Positioned(
                        top: 8,
                        left: 16,
                        right: wide ? 130 : 16,
                        child: ListenableBuilder(
                          listenable: Listenable.merge([
                            Purchases.revision,
                            Names.revision,
                          ]),
                          builder: (context, _) {
                            final allowance = _allowance;
                            return _TopBar(
                              label: allowance.unlimited
                                  ? copy.cameraFieldGuide
                                  : copy.namesLeft(allowance.namesLeft),
                              dots: allowance.dotCount,
                              filled: allowance.filledDots,
                              closeLabel: copy.cameraClose,
                              onClose: _close,
                            );
                          },
                        ),
                      ),
                      if (wide)
                        Positioned(
                          top: 64,
                          bottom: 18,
                          right: 18,
                          width: 112,
                          child: controls,
                        )
                      else
                        Positioned(
                          left: 28,
                          right: 28,
                          bottom: 18,
                          child: controls,
                        ),
                    ],
                  );
                },
              ),
            ),
            if (_naming) _Naming(label: copy.naming),
            if (_notMushroom || _limit)
              _SheetLayer(
                onDismiss: _clearSheet,
                child: _limit
                    ? _LimitSheet(
                        allowance: _allowance,
                        offerAd: _offerAd,
                        onWatchAd: _offerAd
                            ? () => unawaited(_watchAd())
                            : null,
                        onSignIn: nameNeedsSignIn(_allowance)
                            ? () => unawaited(_openSignIn())
                            : null,
                        onFieldGuide: () => unawaited(_openFieldGuide()),
                        onKey: _key,
                      )
                    : _NotMushroomSheet(
                        title: copy.cameraNotTitle,
                        body: copy.cameraNotBody,
                        kept: _countedEmpty
                            ? copy.cameraNotCounted(
                                _allowance.unlimited
                                    ? null
                                    : _allowance.namesLeft,
                              )
                            : copy.cameraNotKept(
                                _allowance.unlimited
                                    ? null
                                    : _allowance.namesLeft,
                              ),
                        again: copy.cameraTryAgain,
                        keyLabel: copy.cameraKey,
                        onTryAgain: _clearSheet,
                        onKey: _key,
                      ),
              ),
          ],
        ),
      ),
    );
  }
}

String _refusalCopy(String reason, Copy copy) {
  switch (reason) {
    case 'cooldown':
      return copy.cameraTooSoon;
    case 'repeat-photo':
      return copy.cameraSamePhoto;
    case 'daily-ceiling':
      return copy.cameraPausedToday;
    default:
      return copy.cameraNeedsAccount;
  }
}

String? _spoken(NameGuess guess) {
  for (final name in guess.commonNames) {
    final trimmed = name.trim();
    if (trimmed.isNotEmpty) return trimmed;
  }
  return null;
}

class _CameraOutcome {
  final bool notMushroom;
  final NameGuess? leading;
  final String? speciesName;
  final List<NameGuess> others;

  const _CameraOutcome.notMushroom()
    : notMushroom = true,
      leading = null,
      speciesName = null,
      others = const [];

  const _CameraOutcome.species(this.leading, this.speciesName, this.others)
    : notMushroom = false;

  const _CameraOutcome.outside(this.leading, this.others)
    : notMushroom = false,
      speciesName = null;
}

_CameraOutcome _outcome(List<NameGuess> guesses, Catalog catalog) {
  if (guesses.isEmpty) return const _CameraOutcome.notMushroom();
  final leading = guesses.first;
  final others = <NameGuess>[];
  for (final guess in guesses.skip(1)) {
    if (catalog.byName(guess.scientificName) == null) continue;
    others.add(guess);
    if (others.length == 2) break;
  }
  final species = catalog.byName(leading.scientificName);
  if (species != null) {
    return _CameraOutcome.species(leading, species.name, others);
  }
  return _CameraOutcome.outside(leading, others);
}

bool _wide(Size size) {
  return size.shortestSide >= 650 &&
      size.width > size.height &&
      size.width >= 1000;
}

bool _tablet(Size size) => size.shortestSide >= 650;

class _View extends StatelessWidget {
  final String? path;
  final CameraController? camera;
  final WidgetBuilder? livePreview;

  const _View({
    required this.path,
    required this.camera,
    required this.livePreview,
  });

  @override
  Widget build(BuildContext context) {
    final shot = path;
    if (shot != null && File(shot).existsSync()) {
      return Image(
        image: FileImage(File(shot)),
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _live(context),
      );
    }
    return _live(context);
  }

  Widget _live(BuildContext context) {
    final camera = this.camera;
    if (camera != null &&
        camera.value.isInitialized &&
        camera.value.aspectRatio > 0) {
      return _LivePreview(controller: camera);
    }
    final fallback = livePreview;
    if (fallback != null) return fallback(context);
    return const SizedBox.expand();
  }
}

class _LivePreview extends StatelessWidget {
  final CameraController controller;

  const _LivePreview({required this.controller});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    var scale = size.aspectRatio * controller.value.aspectRatio;
    if (scale < 1) scale = 1 / scale;
    return ClipRect(
      child: Transform.scale(
        scale: scale,
        alignment: Alignment.center,
        child: Center(child: CameraPreview(controller)),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  final String label;
  final int dots;
  final int filled;
  final String closeLabel;
  final VoidCallback onClose;

  const _TopBar({
    required this.label,
    required this.dots,
    required this.filled,
    required this.closeLabel,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _GlassButton(
          key: const Key('guide-camera-close'),
          label: closeLabel,
          onPressed: onClose,
          child: const Icon(Icons.close, color: Colors.white, size: 22),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: DecoratedBox(
              key: const Key('guide-camera-meter'),
              decoration: BoxDecoration(
                color: _scrim,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (dots > 0) ...[
                      for (var i = 0; i < dots; i++) ...[
                        if (i > 0) const SizedBox(width: 4),
                        _NameDot(filled: i < filled),
                      ],
                      const SizedBox(width: 8),
                    ],
                    Flexible(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 48),
      ],
    );
  }
}

class _NameDot extends StatelessWidget {
  final bool filled;
  final Color color;

  const _NameDot({required this.filled, this.color = Colors.white});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 9,
      height: 9,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: filled ? color : Colors.transparent,
        border: Border.all(color: color, width: 1.5),
      ),
    );
  }
}

class _Controls extends StatelessWidget {
  final bool column;
  final String shutterLabel;
  final String rollLabel;
  final String keyLabel;
  final VoidCallback onShutter;
  final VoidCallback onRoll;
  final VoidCallback onKey;

  const _Controls({
    this.column = false,
    required this.shutterLabel,
    required this.rollLabel,
    required this.keyLabel,
    required this.onShutter,
    required this.onRoll,
    required this.onKey,
  });

  @override
  Widget build(BuildContext context) {
    final roll = _GlassButton(
      key: const Key('guide-camera-roll'),
      label: rollLabel,
      onPressed: onRoll,
      radius: 10,
      child: const Icon(Icons.photo_outlined, color: Colors.white, size: 22),
    );
    final shutter = Semantics(
      button: true,
      label: shutterLabel,
      child: GestureDetector(
        key: const Key('guide-camera-shutter'),
        onTap: onShutter,
        child: Container(
          width: 76,
          height: 76,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 4),
          ),
          child: Container(
            width: 60,
            height: 60,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
    final keyButton = _GlassButton(
      key: const Key('guide-camera-key'),
      label: keyLabel,
      onPressed: onKey,
      child: const CustomPaint(size: Size(22, 22), painter: _KeyPainter()),
    );
    if (column) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          roll,
          const SizedBox(height: 22),
          shutter,
          const SizedBox(height: 22),
          keyButton,
        ],
      );
    }
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [roll, shutter, keyButton],
    );
  }
}

class _GlassButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  final Widget child;
  final double radius;

  const _GlassButton({
    super.key,
    required this.label,
    required this.onPressed,
    required this.child,
    this.radius = 19,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: _scrim,
        borderRadius: BorderRadius.circular(radius),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: SizedBox(width: 48, height: 48, child: Center(child: child)),
        ),
      ),
    );
  }
}

class _Naming extends StatelessWidget {
  final String label;

  const _Naming({required this.label});

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: GestureDetector(
        onTap: () {},
        child: ColoredBox(
          color: const Color(0x99000000),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 44,
                  height: 44,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    color: Colors.white,
                    backgroundColor: Color(0x44FFFFFF),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  label,
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SheetLayer extends StatelessWidget {
  final VoidCallback onDismiss;
  final Widget child;

  const _SheetLayer({required this.onDismiss, required this.child});

  @override
  Widget build(BuildContext context) {
    final colors = GuideColors.of(context);
    final tablet = _tablet(MediaQuery.sizeOf(context));
    final height = MediaQuery.sizeOf(context).height;
    final maxHeight = tablet
        ? (height * 0.88 < 680 ? height * 0.88 : 680.0)
        : height * 0.86;
    return Positioned.fill(
      child: Stack(
        children: [
          GestureDetector(
            onTap: onDismiss,
            child: const ColoredBox(color: Color(0x6B1A1612)),
          ),
          Align(
            alignment: tablet ? Alignment.center : Alignment.bottomCenter,
            child: Padding(
              padding: tablet ? const EdgeInsets.all(32) : EdgeInsets.zero,
              child: Material(
                color: colors.paper,
                borderRadius: tablet
                    ? BorderRadius.circular(22)
                    : const BorderRadius.vertical(top: Radius.circular(22)),
                clipBehavior: Clip.antiAlias,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: tablet ? 520 : double.infinity,
                    maxHeight: maxHeight,
                  ),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
                    child: child,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NotMushroomSheet extends StatelessWidget {
  final String title;
  final String body;
  final String kept;
  final String again;
  final String keyLabel;
  final VoidCallback onTryAgain;
  final VoidCallback onKey;

  const _NotMushroomSheet({
    required this.title,
    required this.body,
    required this.kept,
    required this.again,
    required this.keyLabel,
    required this.onTryAgain,
    required this.onKey,
  });

  @override
  Widget build(BuildContext context) {
    final colors = GuideColors.of(context);
    final tablet = _tablet(MediaQuery.sizeOf(context));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!tablet)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Center(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: colors.rule,
                  borderRadius: BorderRadius.circular(2),
                ),
                child: const SizedBox(width: 36, height: 4),
              ),
            ),
          ),
        Text(
          title,
          style: TextStyle(
            fontFamily: GuideType.display,
            fontWeight: FontWeight.w500,
            fontSize: 23,
            height: 1.12,
            color: colors.ink,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          body,
          style: TextStyle(fontSize: 15, height: 1.4, color: colors.ink2),
        ),
        const SizedBox(height: 8),
        Text(
          kept,
          style: TextStyle(fontSize: 15, height: 1.4, color: colors.ink2),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: TextButton(
            onPressed: onTryAgain,
            style: TextButton.styleFrom(
              minimumSize: const Size.fromHeight(34),
              backgroundColor: colors.mossFill,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(17),
              ),
              textStyle: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            child: Text(again),
          ),
        ),
        const SizedBox(height: 4),
        SizedBox(
          width: double.infinity,
          child: TextButton(
            onPressed: onKey,
            child: Text(
              keyLabel,
              style: TextStyle(color: colors.moss, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ],
    );
  }
}

class _LimitSheet extends StatelessWidget {
  final NameAllowance allowance;
  final bool offerAd;
  final VoidCallback? onWatchAd;
  final VoidCallback? onSignIn;
  final VoidCallback onFieldGuide;
  final VoidCallback onKey;

  const _LimitSheet({
    required this.allowance,
    required this.offerAd,
    required this.onWatchAd,
    required this.onSignIn,
    required this.onFieldGuide,
    required this.onKey,
  });

  @override
  Widget build(BuildContext context) {
    final colors = GuideColors.of(context);
    final copy = GuideScope.of(context).copy;
    final tablet = _tablet(MediaQuery.sizeOf(context));
    final signIn = nameNeedsSignIn(allowance);
    final exhausted = nameMonthExhausted(allowance);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!tablet)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Center(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: colors.rule,
                  borderRadius: BorderRadius.circular(2),
                ),
                child: const SizedBox(width: 36, height: 4),
              ),
            ),
          ),
        if (!signIn && allowance.dotCount > 0) ...[
          Row(
            children: [
              for (var i = 0; i < allowance.dotCount; i++) ...[
                if (i > 0) const SizedBox(width: 4),
                _NameDot(filled: i < allowance.filledDots, color: colors.moss),
              ],
            ],
          ),
          const SizedBox(height: 10),
        ],
        Text(
          signIn
              ? copy.cameraGuestTitle
              : exhausted
              ? copy.cameraLimitAllTitle
              : copy.cameraLimitTitle,
          style: TextStyle(
            fontFamily: GuideType.display,
            fontWeight: FontWeight.w500,
            fontSize: 23,
            height: 1.12,
            color: colors.ink,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          signIn
              ? copy.cameraGuestBody
              : offerAd
              ? copy.cameraLimitBody
              : copy.cameraLimitAllBody,
          style: TextStyle(fontSize: 15, height: 1.4, color: colors.ink2),
        ),
        const SizedBox(height: 14),
        if (onSignIn != null)
          _Choice(
            title: copy.signIn,
            note: copy.signInPerkAccountNote,
            icon: Icons.person_outline,
            iconColor: colors.ink,
            iconGround: colors.paper2,
            onPressed: onSignIn,
          ),
        if (onWatchAd != null)
          _Choice(
            title: copy.cameraWatchAd,
            note: copy.cameraWatchAdNote,
            icon: Icons.smart_display_outlined,
            iconColor: colors.ink,
            iconGround: colors.paper2,
            onPressed: onWatchAd,
          ),
        _Choice(
          title: copy.cameraFieldGuideRow,
          note: copy.cameraFieldGuideNote,
          icon: Icons.eco_outlined,
          iconColor: Colors.white,
          iconGround: colors.mossFill,
          border: colors.moss,
          onPressed: onFieldGuide,
        ),
        _Choice(
          title: copy.cameraKeyRow,
          note: copy.cameraKeyNote,
          icon: Icons.apps_outlined,
          iconColor: colors.madder,
          iconGround: colors.paper2,
          onPressed: onKey,
        ),
      ],
    );
  }
}

class _Choice extends StatelessWidget {
  final String title;
  final String note;
  final IconData icon;
  final Color iconColor;
  final Color iconGround;
  final Color? border;
  final VoidCallback? onPressed;

  const _Choice({
    required this.title,
    required this.note,
    required this.icon,
    required this.iconColor,
    required this.iconGround,
    required this.onPressed,
    this.border,
  });

  @override
  Widget build(BuildContext context) {
    final colors = GuideColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: colors.cream,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: border ?? colors.rule,
            width: border == null ? 1 : 1.5,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: iconGround,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: SizedBox(
                    width: 40,
                    height: 40,
                    child: Icon(icon, color: iconColor, size: 22),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: colors.ink,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        note,
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.35,
                          color: colors.ink3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CornerPainter extends CustomPainter {
  const _CornerPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    const arm = 34.0;
    const radius = 10.0;
    final w = size.width;
    final h = size.height;
    canvas.drawPath(_corner(0, 0, 1, 1, arm, radius), paint);
    canvas.drawPath(_corner(w, 0, -1, 1, arm, radius), paint);
    canvas.drawPath(_corner(0, h, 1, -1, arm, radius), paint);
    canvas.drawPath(_corner(w, h, -1, -1, arm, radius), paint);
  }

  Path _corner(
    double x,
    double y,
    double dx,
    double dy,
    double arm,
    double radius,
  ) {
    return Path()
      ..moveTo(x, y + dy * arm)
      ..lineTo(x, y + dy * radius)
      ..arcToPoint(
        Offset(x + dx * radius, y),
        radius: Radius.circular(radius),
        clockwise: dx == dy,
      )
      ..lineTo(x + dx * arm, y);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _KeyPainter extends CustomPainter {
  const _KeyPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final w = size.width;
    canvas.drawPath(
      Path()
        ..moveTo(w * 0.18, w * 0.46)
        ..quadraticBezierTo(w * 0.5, w * 0.08, w * 0.82, w * 0.46),
      paint,
    );
    canvas.drawLine(
      Offset(w * 0.22, w * 0.46),
      Offset(w * 0.78, w * 0.46),
      paint,
    );
    canvas.drawPath(
      Path()
        ..moveTo(w * 0.42, w * 0.46)
        ..lineTo(w * 0.38, w * 0.78)
        ..quadraticBezierTo(w * 0.5, w * 0.9, w * 0.62, w * 0.78)
        ..lineTo(w * 0.58, w * 0.46),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
