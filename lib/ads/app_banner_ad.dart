import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:whats_that_mushroom/ads/ad_units.dart';
import 'package:whats_that_mushroom/purchase/purchases.dart';
import 'package:whats_that_mushroom/shell/theme.dart';

class AppBannerAd extends StatefulWidget {
  /// Stays empty until the ad has loaded. A Field Guide purchase releases it.
  final bool pinned;

  const AppBannerAd({super.key, this.pinned = false});

  @override
  State<AppBannerAd> createState() => _AppBannerAdState();
}

class _AppBannerAdState extends State<AppBannerAd> {
  BannerAd? _ad;
  var _loaded = false;

  @override
  void initState() {
    super.initState();
    Ads.ready.addListener(_onReady);
    Purchases.revision.addListener(_onReady);
    _loadIfNeeded();
  }

  @override
  void dispose() {
    Ads.ready.removeListener(_onReady);
    Purchases.revision.removeListener(_onReady);
    _ad?.dispose();
    super.dispose();
  }

  void _onReady() {
    if (!mounted) return;
    if (!Ads.enabled || !Purchases.showsAds()) {
      _release();
      return;
    }
    _loadIfNeeded();
  }

  void _loadIfNeeded() {
    if (_ad != null || !Ads.enabled || !Purchases.showsAds()) return;
    final id = Ads.bannerUnitId();
    if (id == null) return;
    final ad = BannerAd(
      adUnitId: id,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (loaded) {
          if (!mounted) {
            loaded.dispose();
            return;
          }
          setState(() => _loaded = true);
        },
        onAdFailedToLoad: (failed, error) {
          debugPrint('banner: $error');
          failed.dispose();
          if (_ad == failed) _ad = null;
          if (mounted) setState(() => _loaded = false);
        },
      ),
    );
    _ad = ad;
    ad.load();
  }

  void _release() {
    final ad = _ad;
    _ad = null;
    _loaded = false;
    ad?.dispose();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final ad = _ad;
    if (!_loaded || ad == null || !Purchases.showsAds()) {
      return const SizedBox.shrink();
    }
    final colors = GuideColors.of(context);
    final view = SizedBox(
      width: ad.size.width.toDouble(),
      height: ad.size.height.toDouble(),
      child: AdWidget(ad: ad),
    );
    if (widget.pinned) {
      return DecoratedBox(
        decoration: BoxDecoration(
          color: colors.paper,
          border: Border(top: BorderSide(color: colors.rule)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Center(child: view),
        ),
      );
    }
    return Container(
      alignment: Alignment.center,
      margin: const EdgeInsets.only(bottom: 5, top: 5),
      child: view,
    );
  }
}
