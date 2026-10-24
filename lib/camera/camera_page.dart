import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:whats_that_mushroom/camera/plant_id.dart';
import 'package:whats_that_mushroom/data/notebook.dart';
import 'package:whats_that_mushroom/shell/scope.dart';
import 'package:whats_that_mushroom/shell/theme.dart';
import 'package:whats_that_mushroom/shell/widgets.dart';
import 'package:whats_that_mushroom/species/species_page.dart';

class CameraPage extends StatefulWidget {
  const CameraPage({super.key});

  @override
  State<CameraPage> createState() => _CameraPageState();
}

class _CameraPageState extends State<CameraPage> {
  var _busy = false;
  String? _message;
  List<NameGuess> _guesses = const [];

  @override
  Widget build(BuildContext context) {
    final scope = GuideScope.of(context);
    final copy = scope.copy;
    final colors = GuideColors.of(context);
    final catalog = scope.catalog.data;
    return Scaffold(
      backgroundColor: colors.paper,
      appBar: AppBar(
        title: Text(
          copy.cameraTitle,
          style: GuideType.spoken(colors, size: 22),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          Text(copy.cameraLede, style: GuideType.body(colors)),
          const SizedBox(height: 16),
          if (catalog == null)
            CatalogMessage(
              copy: copy,
              error: scope.catalog.error,
              onRetry: scope.reload,
            )
          else ...[
            FilledButton(
              onPressed: _busy ? null : () => _pick(ImageSource.camera),
              child: Text(_busy ? copy.naming : copy.takePhoto),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: _busy ? null : () => _pick(ImageSource.gallery),
              child: Text(copy.choosePhoto),
            ),
            if (_message != null) ...[
              const SizedBox(height: 16),
              Text(_message!, style: GuideType.body(colors)),
            ],
            for (final guess in _guesses) _card(context, guess),
          ],
        ],
      ),
    );
  }

  Future<void> _pick(ImageSource source) async {
    final scope = GuideScope.of(context);
    final copy = scope.copy;
    final catalog = scope.catalog.data;
    if (catalog == null) return;
    final shot = await ImagePicker().pickImage(
      source: source,
      maxWidth: 1280,
      maxHeight: 1280,
      imageQuality: 85,
    );
    if (shot == null || !mounted) return;
    setState(() {
      _busy = true;
      _message = copy.naming;
      _guesses = const [];
    });
    try {
      final jpeg = jpegMaxEdge(await shot.readAsBytes());
      final guesses = await identifyMushroom(jpeg, scope.settings.language);
      if (!mounted) return;
      if (guesses.isEmpty) {
        setState(() {
          _busy = false;
          _message = copy.notMushroom;
          _guesses = const [];
        });
        return;
      }
      final leading = guesses.first;
      final species = catalog.byName(leading.scientificName);
      await _remember(scope.notebook, jpeg, leading, species?.name);
      if (!mounted) return;
      if (species != null) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => SpeciesPage(latin: species.name)),
        );
        return;
      }
      setState(() {
        _busy = false;
        _message = copy.outsideBook;
        _guesses = guesses;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _message = cameraFailure(error, copy);
        _guesses = const [];
      });
    }
  }

  Future<void> _remember(
    Notebook notebook,
    Uint8List jpeg,
    NameGuess guess,
    String? latin,
  ) async {
    final id = DateTime.now().microsecondsSinceEpoch.toString();
    final path = await notebook.savePhoto(jpeg, id);
    await notebook.addFind(
      FindRecord(
        id: id,
        millis: DateTime.now().millisecondsSinceEpoch,
        latin: latin,
        outsideName: latin == null ? guess.scientificName : null,
        probability: guess.probability,
        photoPath: path,
      ),
    );
  }

  Widget _card(BuildContext context, NameGuess guess) {
    final scope = GuideScope.of(context);
    final copy = scope.copy;
    final colors = GuideColors.of(context);
    final species = scope.catalog.data?.byName(guess.scientificName);
    final percent = '${(guess.probability * 100).round()}%';
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Material(
        color: colors.cream,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: colors.rule),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                guess.scientificName,
                style: GuideType.latin(colors, size: 20),
              ),
              const SizedBox(height: 4),
              Text(
                '${confidenceLabel(guess.probability, copy)} · $percent',
                style: GuideType.muted(colors),
              ),
              if (guess.commonNames.isNotEmpty)
                Text(
                  guess.commonNames.join(', '),
                  style: GuideType.body(colors),
                ),
              if (species != null)
                TextButton(
                  onPressed: () => openSpecies(context, species.name),
                  child: Text(copy.openSpecies),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
