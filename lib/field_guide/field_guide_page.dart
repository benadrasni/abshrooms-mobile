import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:whats_that_mushroom/copy.dart';
import 'package:whats_that_mushroom/data/text.dart';
import 'package:whats_that_mushroom/field_guide/catalog.dart';
import 'package:whats_that_mushroom/legal.dart';
import 'package:whats_that_mushroom/purchase/billing.dart';
import 'package:whats_that_mushroom/purchase/purchases.dart';
import 'package:whats_that_mushroom/shell/guide_analytics.dart';
import 'package:whats_that_mushroom/shell/scope.dart';
import 'package:whats_that_mushroom/shell/theme.dart';

const fieldGuidePlatePath =
    'photos/Agaricales/Amanitaceae/Amanita_muscaria/Amanita_muscaria@1600.webp';

const fieldGuideStartKey = Key('fieldGuideStart');
const fieldGuideRestoreKey = Key('fieldGuideRestore');
const fieldGuideYearlyKey = Key('fieldGuideYearly');
const fieldGuideMonthlyKey = Key('fieldGuideMonthly');

/// Field Guide: yearly and monthly, with the store price on each row.
/// A monthly plan bought on this phone can change to yearly.
class FieldGuidePage extends StatefulWidget {
  final Future<FieldGuideLoaded> Function()? load;
  final Future<bool> Function(FieldGuidePlan plan)? buy;
  final Future<void> Function()? restore;
  final WidgetBuilder? plate;

  const FieldGuidePage({super.key, this.load, this.buy, this.restore, this.plate});

  @override
  State<FieldGuidePage> createState() => _FieldGuidePageState();
}

class _FieldGuidePageState extends State<FieldGuidePage> {
  FieldGuideLoaded? _loaded;
  FieldGuidePlan _plan = FieldGuidePlan.yearly;
  var _planChosen = false;
  var _awaitingPrices = true;
  var _failed = false;
  var _busy = false;
  String? _error;
  var _ticket = 0;
  var _failures = 0;
  var _viewed = false;

  @override
  void initState() {
    super.initState();
    _failures = Purchases.failures.value;
    Purchases.revision.addListener(_onPlan);
    Purchases.failures.addListener(_onFailure);
    unawaited(_load());
  }

  @override
  void dispose() {
    Purchases.revision.removeListener(_onPlan);
    Purchases.failures.removeListener(_onFailure);
    super.dispose();
  }

  void _onPlan() {
    final loaded = _loaded;
    if (loaded == null || !mounted) return;
    setState(() {
      _loaded = FieldGuideLoaded(
        catalog: loaded.catalog.withOwnership(Purchases.owned),
        products: loaded.products,
      );
    });
  }

  void _onFailure() {
    if (!mounted || Purchases.failures.value == _failures) return;
    _failures = Purchases.failures.value;
    setState(() => _error = GuideScope.of(context).copy.purchaseFailed);
  }

  Future<void> _load() async {
    final ticket = ++_ticket;
    try {
      final loaded = await (widget.load ?? loadFieldGuide)();
      if (!mounted || ticket != _ticket) return;
      setState(() {
        _loaded = loaded;
        _awaitingPrices = false;
        _failed = false;
        if (!_planChosen) _plan = _openingPlan(loaded.catalog);
      });
      if (_viewed) return;
      _viewed = true;
      unawaited(
        GuideAnalytics.viewItem([
          loaded.catalog.yearly.productId,
          loaded.catalog.monthly.productId,
        ]),
      );
    } catch (error) {
      debugPrint('field guide: $error');
      if (!mounted || ticket != _ticket) return;
      setState(() {
        _failed = _loaded == null;
        _awaitingPrices = false;
      });
    }
  }

  FieldGuideIds get _ids {
    final loaded = _loaded;
    if (loaded == null) return FieldGuideIds.forPlatform(defaultTargetPlatform);
    return FieldGuideIds(
      monthly: loaded.catalog.monthly.productId,
      yearly: loaded.catalog.yearly.productId,
    );
  }

  FieldGuideAccess _access(FieldGuideCatalog catalog) {
    return fieldGuideAccess(
      catalog: catalog,
      monthlyOnThisStore: Purchases.purchases.containsKey(catalog.monthly.productId),
      fromAccountOnly: Purchases.fieldGuideFromAccountOnly,
    );
  }

  FieldGuidePlan _openingPlan(FieldGuideCatalog catalog) {
    return catalog.initialPlan;
  }

  Future<void> _start() async {
    final loaded = _loaded;
    if (loaded == null || _busy) return;
    final access = _access(loaded.catalog);
    final offer = loaded.catalog.offer(_plan);
    if (access.locked || offer.owned || offer.price == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final started = await (widget.buy ?? _buySelected)(_plan);
      if (!started && mounted) {
        setState(() => _error = GuideScope.of(context).copy.purchaseFailed);
      }
    } catch (error) {
      debugPrint('field guide buy: $error');
      if (mounted) {
        setState(() => _error = GuideScope.of(context).copy.purchaseFailed);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool> _buySelected(FieldGuidePlan plan) {
    final product = _loaded?.products[_ids.forPlan(plan)];
    if (product == null) return Future<bool>.value(false);
    final replaceId = fieldGuideReplaces(plan, _ids, Purchases.purchases.keys.toSet());
    return buyFieldGuide(
      product: product,
      replaces: replaceId == null ? null : Purchases.purchases[replaceId],
    );
  }

  Future<void> _restore() async {
    final custom = widget.restore;
    if (custom != null) {
      await custom();
      return;
    }
    final copy = GuideScope.of(context).copy;
    final started = await restoreFieldGuidePurchases();
    if (!mounted) return;
    if (!started) {
      setState(() => _error = copy.restoreFailed);
      return;
    }
    setState(() => _error = null);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(copy.restoring)));
  }

  void _choose(FieldGuidePlan plan) {
    setState(() {
      _plan = plan;
      _planChosen = true;
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = GuideColors.of(context);
    return Scaffold(
      backgroundColor: colors.paper,
      body: SafeArea(bottom: false, child: _body(context)),
    );
  }

  FieldGuideCatalog _catalog() {
    return _loaded?.catalog ??
        fieldGuideCatalog(
          ids: FieldGuideIds.forPlatform(defaultTargetPlatform),
          storeAvailable: false,
          yearlyPrice: null,
          monthlyPrice: null,
          owned: Purchases.owned,
        );
  }

  Widget _body(BuildContext context) {
    final colors = GuideColors.of(context);
    final copy = GuideScope.of(context).copy;
    if (_failed && _loaded == null) {
      return Column(
        children: [
          const _Back(),
          const Spacer(),
          Text(copy.couldNotLoad, style: TextStyle(color: colors.ink2)),
          TextButton(onPressed: _load, child: Text(copy.retry)),
          const Spacer(),
        ],
      );
    }
    return _content(
      context,
      _catalog(),
      pricesPending: _awaitingPrices && _loaded == null,
    );
  }

  Widget _content(
    BuildContext context,
    FieldGuideCatalog catalog, {
    required bool pricesPending,
  }) {
    final colors = GuideColors.of(context);
    final copy = GuideScope.of(context).copy;
    final bottom = 24 + MediaQuery.paddingOf(context).bottom;
    final selected = catalog.offer(_plan);
    final owned = selected.owned;
    final access = _access(catalog);
    final canBuy = !access.locked && !owned && selected.price != null && !_busy;
    final ios = defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS;
    return ListView(
      padding: EdgeInsets.only(bottom: bottom),
      children: [
        SizedBox(
          height: 220,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: 250,
                child: _Hero(plate: widget.plate),
              ),
              const PositionedDirectional(top: 10, start: 12, child: _BackCircle()),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 6),
          child: Text(
            copy.fieldGuide,
            style: TextStyle(
              fontFamily: GuideType.display,
              fontWeight: FontWeight.w500,
              fontSize: 34,
              letterSpacing: -0.68,
              height: 1.05,
              color: colors.ink,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            copy.fieldGuideSub,
            style: TextStyle(
              fontFamily: GuideType.sans,
              color: colors.ink2,
              fontSize: 16,
              height: 1.45,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _Column(
                  title: copy.fieldGuideFree,
                  titleColor: colors.ink2,
                  lines: [
                    copy.fieldGuideFreeSearch,
                    copy.fieldGuideFreeKey,
                    copy.fieldGuideFreeSpecies,
                    copy.fieldGuideFreeSeen,
                    copy.fieldGuideFreeNames,
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _Column(
                  title: copy.fieldGuideAdds,
                  titleColor: colors.moss,
                  border: colors.moss,
                  lines: [
                    copy.fieldGuideAddNames,
                    copy.fieldGuideAddAds,
                    copy.fieldGuideAddSeen,
                    copy.fieldGuideAddOffline,
                  ],
                ),
              ),
            ],
          ),
        ),
        if (access.locked) const _Included(),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: Column(
            children: [
              _Plan(
                planKey: fieldGuideYearlyKey,
                title: copy.fieldGuideYearly,
                note: _planNote(
                  copy,
                  locked: access.locked,
                  owned: catalog.yearly.owned,
                  trial: copy.fieldGuideThenYearly,
                ),
                price: catalog.yearly.price ?? copy.fieldGuideStorePrice,
                pricePending: pricesPending && catalog.yearly.price == null,
                selected: _plan == FieldGuidePlan.yearly,
                onPressed: access.locked ? null : () => _choose(FieldGuidePlan.yearly),
              ),
              const SizedBox(height: 8),
              _Plan(
                planKey: fieldGuideMonthlyKey,
                title: copy.fieldGuideMonthly,
                note: _planNote(
                  copy,
                  locked: access.locked,
                  owned: catalog.monthly.owned,
                  trial: copy.fieldGuideThenMonthly,
                ),
                price: catalog.monthly.price ?? copy.fieldGuideStorePrice,
                pricePending: pricesPending && catalog.monthly.price == null,
                selected: _plan == FieldGuidePlan.monthly,
                onPressed: access.locked ? null : () => _choose(FieldGuidePlan.monthly),
              ),
            ],
          ),
        ),
        if (!access.locked && selected.price == null && !pricesPending)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
            child: Text(
              copy.fieldGuideUnavailable,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: GuideType.sans,
                color: colors.ink2,
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          child: _StartButton(
            label: access.locked || owned
                ? copy.subscribed
                : access.upgrade
                ? copy.changePlan
                : copy.fieldGuideStart,
            spinning: _busy,
            onPressed: canBuy ? () => unawaited(_start()) : null,
          ),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            child: Text(
              _error!,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: GuideType.sans,
                color: colors.madder,
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
          child: _TextButton(
            buttonKey: fieldGuideRestoreKey,
            label: copy.restore,
            onPressed: access.locked ? null : () => unawaited(_restore()),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
          child: Text(
            ios ? copy.fieldGuideDisclaimerIos : copy.fieldGuideDisclaimerAndroid,
            style: TextStyle(
              fontFamily: GuideType.sans,
              color: colors.ink2,
              fontSize: 12,
              height: 1.45,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Wrap(
            alignment: WrapAlignment.center,
            children: [
              _LegalLink(
                label: copy.termsOfUse,
                onPressed: () => openLegal(termsOfUseUrl),
              ),
              _LegalLink(
                label: copy.privacyPolicy,
                onPressed: () => openLegal(privacyPolicyUrl),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _planNote(
    Copy copy, {
    required bool locked,
    required bool owned,
    required String trial,
  }) {
    if (!locked) return trial;
    return owned ? copy.subscribed : '';
  }
}

extension on FieldGuideIds {
  String forPlan(FieldGuidePlan plan) {
    return plan == FieldGuidePlan.yearly ? yearly : monthly;
  }
}

Future<FieldGuideLoaded> loadFieldGuide() async {
  final ids = FieldGuideIds.forPlatform(defaultTargetPlatform);
  final store = InAppPurchase.instance;
  final owned = Set<String>.of(Purchases.owned);
  final available = await store.isAvailable();
  if (!available) {
    return fieldGuideFromStore(
      ids: ids,
      storeAvailable: false,
      products: const [],
      owned: owned,
    );
  }
  final response = await store.queryProductDetails({ids.monthly, ids.yearly});
  return fieldGuideFromStore(
    ids: ids,
    storeAvailable: true,
    products: response.productDetails,
    owned: owned,
    error: response.error?.message,
  );
}

class _Hero extends StatelessWidget {
  final WidgetBuilder? plate;

  const _Hero({this.plate});

  @override
  Widget build(BuildContext context) {
    final colors = GuideColors.of(context);
    return ClipRect(
      child: Stack(
        fit: StackFit.expand,
        children: [
          ColoredBox(color: colors.plateWell),
          plate?.call(context) ?? const _Plate(),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  colors.paper.withValues(alpha: 0),
                  colors.paper.withValues(alpha: 0),
                  colors.paper,
                ],
                stops: const [0, 0.4, 1],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Plate extends StatelessWidget {
  const _Plate();

  @override
  Widget build(BuildContext context) {
    final colors = GuideColors.of(context);
    final placeholder = ColoredBox(color: colors.plateWell);
    return CachedNetworkImage(
      imageUrl: mediaUrl(fieldGuidePlatePath),
      fit: BoxFit.cover,
      alignment: const Alignment(0, -0.2),
      placeholder: (context, url) => placeholder,
      errorWidget: (context, url, error) => placeholder,
    );
  }
}

class _Back extends StatelessWidget {
  const _Back();

  @override
  Widget build(BuildContext context) {
    final colors = GuideColors.of(context);
    final copy = GuideScope.of(context).copy;
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: TextButton.icon(
        onPressed: () => Navigator.maybePop(context),
        icon: IconTheme(
          data: IconThemeData(color: colors.moss, size: 20),
          child: const BackButtonIcon(),
        ),
        label: Text(copy.back),
      ),
    );
  }
}

class _BackCircle extends StatelessWidget {
  const _BackCircle();

  @override
  Widget build(BuildContext context) {
    final colors = GuideColors.of(context);
    final copy = GuideScope.of(context).copy;
    return Semantics(
      button: true,
      label: copy.back,
      child: Tooltip(
        message: copy.back,
        child: Material(
          color: colors.cream,
          shape: CircleBorder(side: BorderSide(color: colors.rule)),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => Navigator.maybePop(context),
            customBorder: const CircleBorder(),
            child: SizedBox(
              width: 38,
              height: 38,
              child: IconTheme(
                data: IconThemeData(color: colors.ink, size: 20),
                child: const BackButtonIcon(),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Column extends StatelessWidget {
  final String title;
  final Color titleColor;
  final List<String> lines;
  final Color? border;

  const _Column({
    required this.title,
    required this.titleColor,
    required this.lines,
    this.border,
  });

  @override
  Widget build(BuildContext context) {
    final colors = GuideColors.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.cream,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border ?? colors.rule, width: border == null ? 1 : 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title.toUpperCase(),
              style: TextStyle(
                fontFamily: GuideType.sans,
                color: titleColor,
                fontSize: 12,
                letterSpacing: 0.96,
                fontWeight: FontWeight.w600,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 6),
            for (final line in lines)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Text(
                  line,
                  style: TextStyle(
                    fontFamily: GuideType.sans,
                    color: colors.ink,
                    fontSize: 13,
                    height: 1.35,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Plan extends StatelessWidget {
  final Key planKey;
  final String title;
  final String note;
  final String price;
  final bool pricePending;
  final bool selected;
  final VoidCallback? onPressed;

  const _Plan({
    required this.planKey,
    required this.title,
    required this.note,
    required this.price,
    required this.selected,
    required this.onPressed,
    this.pricePending = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = GuideColors.of(context);
    final enabled = onPressed != null;
    return Material(
      key: planKey,
      color: colors.cream,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: selected ? colors.moss : colors.rule,
          width: selected ? 2 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          child: Row(
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selected ? colors.moss : colors.ink2,
                    width: selected ? 6 : 1.5,
                  ),
                ),
                child: const SizedBox(width: 20, height: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontFamily: GuideType.sans,
                        color: enabled ? colors.ink : colors.ink2,
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                        height: 1.2,
                      ),
                    ),
                    if (note.isNotEmpty)
                      Text(
                        note,
                        style: TextStyle(
                          fontFamily: GuideType.sans,
                          color: colors.ink2,
                          fontSize: 13,
                          height: 1.3,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              pricePending
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: colors.moss),
                    )
                  : Text(
                      price,
                      style: TextStyle(
                        fontFamily: GuideType.sans,
                        color: enabled ? colors.ink2 : colors.ink2,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Included extends StatelessWidget {
  const _Included();

  @override
  Widget build(BuildContext context) {
    final colors = GuideColors.of(context);
    final copy = GuideScope.of(context).copy;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.cream,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: colors.moss, width: 1.5),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Text(
            copy.fieldGuideIncluded,
            style: TextStyle(
              fontFamily: GuideType.sans,
              color: colors.ink,
              fontWeight: FontWeight.w600,
              fontSize: 16,
              height: 1.3,
            ),
          ),
        ),
      ),
    );
  }
}

class _StartButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool spinning;

  const _StartButton({
    required this.label,
    required this.onPressed,
    required this.spinning,
  });

  @override
  Widget build(BuildContext context) {
    final colors = GuideColors.of(context);
    final enabled = onPressed != null;
    return Material(
      key: fieldGuideStartKey,
      color: enabled || spinning ? colors.moss : colors.paper2,
      borderRadius: BorderRadius.circular(22),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: spinning ? null : onPressed,
        child: SizedBox(
          height: 44,
          child: Center(
            child: spinning
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: colors.onMoss),
                  )
                : Text(
                    label,
                    style: TextStyle(
                      fontFamily: GuideType.sans,
                      color: enabled ? colors.onMoss : colors.ink2,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

class _LegalLink extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;

  const _LegalLink({required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final colors = GuideColors.of(context);
    return TextButton(
      onPressed: onPressed,
      child: Text(
        label,
        style: TextStyle(
          fontFamily: GuideType.sans,
          color: colors.moss,
          fontSize: 13,
          fontWeight: FontWeight.w600,
          decoration: TextDecoration.underline,
          decorationColor: colors.moss,
        ),
      ),
    );
  }
}

class _TextButton extends StatelessWidget {
  final Key buttonKey;
  final String label;
  final VoidCallback? onPressed;

  const _TextButton({
    required this.buttonKey,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final colors = GuideColors.of(context);
    return Material(
      key: buttonKey,
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(22),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        child: SizedBox(
          height: 44,
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontFamily: GuideType.sans,
                color: onPressed == null ? colors.ink2 : colors.moss,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
