// lib/widgets/location_picker.dart
//
// A self-contained location picker backed by OpenStreetMap Nominatim —
// completely free, no API key, no signup, no billing.
//
// This file exposes TWO things:
//
//   1. LocationPicker        — the bottom-sheet picker itself
//   2. LocationFieldButton   — a drop-in chip widget that opens the
//                              picker and shows a loading spinner the
//                              entire time the picker is on screen
//
//
// ── PATH A · drop-in chip (handles loading automatically) ────
//
//   String? _locationName;
//   double? _lat, _lng;
//
//   LocationFieldButton(
//     value:       _locationName,
//     quickPicks:  _campusLocations,
//     onPicked:    (r) => setState(() {
//       _locationName = r?.name;
//       _lat = r?.latitude; _lng = r?.longitude;
//     }),
//   )
//
//
// ── PATH B · raw picker, your own UI ─────────────────────────
//
//   bool _pickingLocation = false;
//
//   Future<void> _openLocation() async {
//     setState(() => _pickingLocation = true);
//     final r = await LocationPicker.show(
//       context,
//       quickPicks: _campusLocations,
//       initialQuery: _location,
//     );
//     if (!mounted) return;
//     setState(() {
//       _pickingLocation = false;
//       if (r != null) _location = r.name;
//     });
//   }
//
//   // ...then in your build():
//   _pickingLocation
//     ? const SpinKitFadingCircle(color: _kG2, size: 16)
//     : Icon(Icons.place_rounded, ...)
//
//
// Compliance with Nominatim's Usage Policy:
//   • Sends a User-Agent header identifying the app  (required)
//   • Debounces input by 500 ms                       (max 1 req/sec)
//   • Caps results at 8 per request                   (light footprint)
//   • Shows "Powered by OpenStreetMap" attribution    (required)

import 'dart:async';
import 'package:tcs_app/services/translation_service.dart';
import 'package:tcs_app/widgets/t_text.dart';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:http/http.dart' as http;


// ─── Theme tokens (matches the rest of the app) ──────────────
const Color _kG2  = Color(0xFF8E54E9);
const Color _kInk = Color(0xFF1A1A2E);
const Color _kBg  = Color(0xFFF7F8FA);


// ─── Default quick-picks ─────────────────────────────────────
const List<String> kDefaultCampusPicks = [
  "Taylors College Sydney",
  "University of Sydney",
  "UTS",
  "Central Station",
  "Green Square",
  "Darling Harbour",
  "Sydney CBD",
];

/// Bounding box around Taylors College Sydney (965 Bourke St, Waterloo) —
/// covers the CBD, University of Sydney, UTS and the inner suburbs. Soft
/// ranking bias only; worldwide search still works. west,north,east,south
const String _kSydneyViewbox = '151.150,-33.840,151.260,-33.960';


// ═════════════════════════════════════════════════════════════
// LocationResult — what the picker returns
// ═════════════════════════════════════════════════════════════

class LocationResult {
  final String  name;
  final String? address;
  final double? latitude;
  final double? longitude;
  final bool    fromQuickPick;
  final bool    isFreeText;

  const LocationResult({
    required this.name,
    this.address,
    this.latitude,
    this.longitude,
    this.fromQuickPick = false,
    this.isFreeText    = false,
  });

  factory LocationResult.fromQuickPick(String name) =>
      LocationResult(name: name, fromQuickPick: true);

  factory LocationResult.freeText(String text) =>
      LocationResult(name: text, isFreeText: true);

  factory LocationResult.fromNominatim(Map<String, dynamic> json) {
    final lat = double.tryParse(json['lat']?.toString() ?? '');
    final lng = double.tryParse(json['lon']?.toString() ?? '');
    final display = (json['display_name'] as String?) ?? '';

    String name = '';
    final addr = json['address'];
    if (addr is Map) {
      const priority = [
        'amenity', 'shop', 'tourism', 'leisure', 'office',
        'building', 'public_building', 'attraction',
        'neighbourhood', 'suburb', 'village', 'town', 'city',
        'road',
      ];
      for (final k in priority) {
        final v = addr[k];
        if (v is String && v.trim().isNotEmpty) {
          name = v.trim();
          break;
        }
      }
    }
    if (name.isEmpty && display.isNotEmpty) {
      name = display.split(',').first.trim();
    }

    String? line;
    if (display.isNotEmpty) {
      final parts = display.split(',').map((s) => s.trim()).toList();
      if (parts.length > 2) {
        final middle = parts.sublist(1, parts.length - 1);
        if (middle.isNotEmpty) line = middle.take(3).join(', ');
      }
    }

    return LocationResult(
      name: name, address: line,
      latitude: lat, longitude: lng,
    );
  }

  @override
  String toString() => name;
}


// ═════════════════════════════════════════════════════════════
// LocationPicker — the bottom-sheet picker
// ═════════════════════════════════════════════════════════════

class LocationPicker extends StatefulWidget {
  final List<String> quickPicks;
  final String?      initialQuery;
  final String?      viewbox;

  const LocationPicker({
    super.key,
    this.quickPicks   = const [],
    this.initialQuery,
    this.viewbox,
  });

  /// Convenience: opens the picker as a modal bottom sheet and returns
  /// the picked LocationResult (or null if the user dismissed).
  static Future<LocationResult?> show(
    BuildContext context, {
    List<String> quickPicks   = const [],
    String?      initialQuery,
    String?      viewbox,
  }) {
    return showModalBottomSheet<LocationResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => LocationPicker(
        quickPicks:   quickPicks.isEmpty ? kDefaultCampusPicks : quickPicks,
        initialQuery: initialQuery,
        viewbox:      viewbox,
      ),
    );
  }

  @override
  State<LocationPicker> createState() => _LocationPickerState();
}

class _LocationPickerState extends State<LocationPicker> {
  final _ctrl  = TextEditingController();
  final _focus = FocusNode();

  Timer?               _debounce;
  bool                 _searching = false;
  String               _lastQuery = '';
  List<LocationResult> _results   = [];
  String?              _error;

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(_onChanged);
    if (widget.initialQuery != null && widget.initialQuery!.trim().isNotEmpty) {
      _ctrl.text = widget.initialQuery!;
      _runSearch(widget.initialQuery!.trim());
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.removeListener(_onChanged);
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _onChanged() {
    setState(() {});
    final q = _ctrl.text.trim();
    _debounce?.cancel();
    if (q.isEmpty) {
      setState(() {
        _results   = [];
        _error     = null;
        _searching = false;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 500), () => _runSearch(q));
  }

  Future<void> _runSearch(String q) async {
    if (q == _lastQuery && _results.isNotEmpty) return;
    _lastQuery = q;
    setState(() { _searching = true; _error = null; });

    try {
      final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
        'q':               q,
        'format':          'json',
        'addressdetails':  '1',
        'limit':           '8',
        // No countrycodes filter — search is worldwide so students can
        // tag a place from anywhere they travel. The viewbox below only
        // *biases* ranking toward Sydney (bounded=0); it never excludes
        // far-away results.
        'viewbox':         widget.viewbox ?? _kSydneyViewbox,
        'bounded':         '0',
        'accept-language': 'en',
      });

      final res = await http.get(uri, headers: {
        'User-Agent': 'TCS-App/1.0 (Taylors College Social)',
      }).timeout(const Duration(seconds: 8));

      if (!mounted) return;

      if (res.statusCode != 200) {
        setState(() {
          _searching = false;
          _error     = 'Search service is unavailable. Try again in a moment.';
          _results   = [];
        });
        return;
      }

      final data = jsonDecode(res.body);
      final picks = (data is List ? data : <dynamic>[])
          .whereType<Map>()
          .map((m) => LocationResult.fromNominatim(m.cast<String, dynamic>()))
          .where((r) => r.name.trim().isNotEmpty)
          .toList();

      setState(() {
        _results   = picks;
        _searching = false;
      });
    } on TimeoutException {
      if (!mounted) return;
      setState(() {
        _searching = false;
        _error     = 'The search took too long. Check your connection.';
        _results   = [];
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _searching = false;
        _error     = "Couldn't reach the location service.";
        _results   = [];
      });
    }
  }

  void _pickResult(LocationResult r) {
    HapticFeedback.lightImpact();
    Navigator.of(context).pop(r);
  }

  void _pickQuickPick(String name) {
    HapticFeedback.selectionClick();
    Navigator.of(context).pop(LocationResult.fromQuickPick(name));
  }

  void _pickFreeText() {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    HapticFeedback.lightImpact();
    Navigator.of(context).pop(LocationResult.freeText(text));
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.78,
      minChildSize:     0.40,
      maxChildSize:     0.94,
      expand:           false,
      builder: (_, scrollCtrl) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(children: [
          _buildDragHandle(),
          _buildHeader(),
          _buildSearchField(),
          const SizedBox(height: 12),
          Expanded(child: _buildBody(scrollCtrl)),
          _buildAttribution(),
        ]),
      ),
    );
  }

  Widget _buildDragHandle() => Container(
    margin: const EdgeInsets.only(top: 10),
    width: 40, height: 4,
    decoration: BoxDecoration(
      color: Colors.grey.shade300,
      borderRadius: BorderRadius.circular(2),
    ),
  );

  Widget _buildHeader() => Padding(
    padding: const EdgeInsets.fromLTRB(20, 14, 12, 12),
    child: Row(children: [
      const Icon(Icons.place_rounded, color: _kG2, size: 20),
      const SizedBox(width: 8),
      const T('Add a location',
          style: TextStyle(fontFamily: 'Alfa', fontSize: 17, color: _kInk)),
      const Spacer(),
      IconButton(
        onPressed: () => Navigator.pop(context),
        icon: Icon(Icons.close_rounded, color: Colors.grey.shade500),
      ),
    ]),
  );

  Widget _buildSearchField() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 20),
    child: Container(
      decoration: BoxDecoration(
        color: _kBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: TextField(
        controller: _ctrl,
        focusNode:  _focus,
        autofocus:  true,
        textInputAction: TextInputAction.search,
        onSubmitted: (_) {
          if (_results.isNotEmpty) {
            _pickResult(_results.first);
          } else {
            _pickFreeText();
          }
        },
        style: const TextStyle(
            fontFamily: 'Momo', fontSize: 14, color: _kInk),
        decoration: InputDecoration(
          hintText: TranslationService.I.tr('Search any place — café, mall, building…'),
          hintStyle: TextStyle(
            fontFamily: 'Momo',
            fontSize: 13,
            color: Colors.grey.shade400,
          ),
          prefixIcon: Icon(Icons.search_rounded,
              color: Colors.grey.shade400),
          suffixIcon: _ctrl.text.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.close_rounded,
                      color: Colors.grey.shade400, size: 18),
                  onPressed: () { _ctrl.clear(); },
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    ),
  );

  Widget _buildBody(ScrollController scrollCtrl) {
    final hasText        = _ctrl.text.trim().isNotEmpty;
    final hasResults     = _results.isNotEmpty;
    final showQuickPicks = !hasText ||
        (!_searching && !hasResults && _error == null);

    return ListView(
      controller: scrollCtrl,
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      children: [
        if (hasText) _buildFreeTextOption(),
        if (_searching) _buildSearching(),
        if (_error != null) _buildError(),
        if (hasResults && !_searching) _buildResultsList(),
        if (showQuickPicks) _buildQuickPicksSection(),
      ],
    );
  }

  Widget _buildFreeTextOption() {
    final text = _ctrl.text.trim();
    return GestureDetector(
      onTap: _pickFreeText,
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _kG2.withOpacity(0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _kG2.withOpacity(0.20)),
        ),
        child: Row(children: [
          const Icon(Icons.text_fields_rounded, size: 18, color: _kG2),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Use "$text"',
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'Arch',
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: _kInk,
                    )),
                T('Keep your text as a free-form label',
                    style: TextStyle(
                      fontFamily: 'Momo',
                      fontSize: 11,
                      color: Colors.grey.shade500,
                    )),
              ],
            ),
          ),
          const Icon(Icons.arrow_forward_ios_rounded,
              size: 12, color: _kG2),
        ]),
      ),
    );
  }

  Widget _buildSearching() => const Padding(
    padding: EdgeInsets.symmetric(vertical: 28),
    child: Center(child: SpinKitThreeBounce(color: _kG2, size: 22)),
  );

  Widget _buildError() => Padding(
    padding: const EdgeInsets.symmetric(vertical: 28),
    child: Center(
      child: Column(children: [
        Icon(Icons.cloud_off_rounded,
            size: 38, color: Colors.grey.shade300),
        const SizedBox(height: 10),
        Text(_error!, textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Momo',
              fontSize: 12,
              color: Colors.grey.shade500,
            )),
      ]),
    ),
  );

  Widget _buildResultsList() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.only(bottom: 6, left: 4),
        child: T('SUGGESTIONS',
            style: TextStyle(
              fontFamily: 'Arch',
              fontWeight: FontWeight.bold,
              fontSize: 10,
              color: Colors.grey.shade500,
              letterSpacing: 1.2,
            )),
      ),
      ..._results.map(_buildResultRow),
    ],
  );

  Widget _buildResultRow(LocationResult r) => InkWell(
    onTap: () => _pickResult(r),
    borderRadius: BorderRadius.circular(12),
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
      child: Row(children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            color: _kG2.withOpacity(0.10),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.place_outlined, color: _kG2, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(r.name,
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'Arch',
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: _kInk,
                  )),
              if (r.address != null && r.address!.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(r.address!,
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Momo',
                      fontSize: 11,
                      color: Colors.grey.shade500,
                    )),
              ],
            ],
          ),
        ),
      ]),
    ),
  );

  Widget _buildQuickPicksSection() {
    if (widget.quickPicks.isEmpty) return _buildEmptyHint();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 4, 0, 8),
          child: T('CAMPUS QUICK PICKS',
              style: TextStyle(
                fontFamily: 'Arch',
                fontWeight: FontWeight.bold,
                fontSize: 10,
                color: Colors.grey.shade500,
                letterSpacing: 1.2,
              )),
        ),
        Wrap(
          spacing: 8, runSpacing: 8,
          children: widget.quickPicks.map(_buildQuickPickChip).toList(),
        ),
      ],
    );
  }

  Widget _buildQuickPickChip(String label) => GestureDetector(
    onTap: () => _pickQuickPick(label),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200, width: 1.5),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.school_rounded, size: 13, color: _kG2),
        const SizedBox(width: 6),
        Text(label,
            style: const TextStyle(
              fontFamily: 'Arch',
              fontWeight: FontWeight.bold,
              fontSize: 12,
              color: _kInk,
            )),
      ]),
    ),
  );

  Widget _buildEmptyHint() => Padding(
    padding: const EdgeInsets.symmetric(vertical: 36),
    child: Center(
      child: Column(children: [
        Icon(Icons.travel_explore_rounded,
            size: 48, color: Colors.grey.shade300),
        const SizedBox(height: 12),
        T('Type a place to search',
            style: TextStyle(
              fontFamily: 'Momo',
              fontSize: 12,
              color: Colors.grey.shade500,
            )),
      ]),
    ),
  );

  Widget _buildAttribution() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    decoration: BoxDecoration(
      border: Border(top: BorderSide(color: Colors.grey.shade100)),
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        T('Powered by ',
            style: TextStyle(
              fontFamily: 'Momo',
              fontSize: 10,
              color: Colors.grey.shade400,
            )),
        T('OpenStreetMap',
            style: TextStyle(
              fontFamily: 'Momo',
              fontSize: 10,
              color: Colors.grey.shade500,
              fontWeight: FontWeight.bold,
            )),
        T(' contributors',
            style: TextStyle(
              fontFamily: 'Momo',
              fontSize: 10,
              color: Colors.grey.shade400,
            )),
      ],
    ),
  );
}


// ═════════════════════════════════════════════════════════════
// LocationFieldButton — drop-in chip with built-in loading state
// ═════════════════════════════════════════════════════════════
//
// Use this when you want zero state plumbing in your screen.
// Shows a spinner the WHOLE time the picker is on screen, swaps back
// to the location label as soon as the user picks (or dismisses).

class LocationFieldButton extends StatefulWidget {
  /// Currently-selected location label, or null if nothing's picked.
  final String? value;

  /// Optional latitude/longitude hint — kept here so you can pass it back
  /// in if your parent state holds them too. Not displayed.
  final double? latitude;
  final double? longitude;

  /// Quick-pick chips shown at the top of the picker.
  final List<String> quickPicks;

  /// Called when the user picks a location, types a free-text label, or
  /// clears the current value via the × button. Receives `null` when the
  /// user clears the chip.
  final ValueChanged<LocationResult?> onPicked;

  /// Placeholder text shown when [value] is null.
  final String placeholder;

  /// Optional override for the chip's accent colour (default: brand violet).
  final Color accent;

  /// Show a small × to clear the current value. Default true.
  final bool clearable;

  const LocationFieldButton({
    super.key,
    this.value,
    this.latitude,
    this.longitude,
    this.quickPicks   = const [],
    required this.onPicked,
    this.placeholder  = 'Add location',
    this.accent       = _kG2,
    this.clearable    = true,
  });

  @override
  State<LocationFieldButton> createState() => _LocationFieldButtonState();
}

class _LocationFieldButtonState extends State<LocationFieldButton> {
  bool _picking = false;

  Future<void> _open() async {
    if (_picking) return;
    HapticFeedback.lightImpact();
    setState(() => _picking = true);

    final result = await LocationPicker.show(
      context,
      quickPicks:   widget.quickPicks,
      initialQuery: widget.value,
    );

    if (!mounted) return;
    setState(() => _picking = false);

    // Only fire onPicked if the user actually picked something. Dismiss
    // with no result (drag-down / tap outside) leaves the value alone.
    if (result != null) widget.onPicked(result);
  }

  void _clear() {
    HapticFeedback.selectionClick();
    widget.onPicked(null);
  }

  @override
  Widget build(BuildContext context) {
    final hasValue = (widget.value ?? '').trim().isNotEmpty;
    final label    = hasValue ? widget.value!.trim() : widget.placeholder;
    final accent   = widget.accent;

    return GestureDetector(
      onTap: _open,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: hasValue || _picking
              ? accent.withOpacity(0.08)
              : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: hasValue || _picking
                ? accent.withOpacity(0.30)
                : Colors.grey.shade200,
            width: 1.5,
          ),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          // ── Leading icon OR loader ─────────────────────────
          if (_picking)
            SizedBox(
              width: 16, height: 16,
              child: SpinKitFadingCircle(color: accent, size: 16),
            )
          else
            Icon(
              hasValue
                  ? Icons.place_rounded
                  : Icons.add_location_alt_rounded,
              size: 14,
              color: accent,
            ),
          const SizedBox(width: 6),

          // ── Label ─────────────────────────────────────────
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 180),
            child: Text(
              _picking ? 'Picking…' : label,
              maxLines: 1, overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'Arch',
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: hasValue || _picking ? _kInk : Colors.grey.shade600,
              ),
            ),
          ),

          // ── Clear (×) ─────────────────────────────────────
          if (hasValue && !_picking && widget.clearable) ...[
            const SizedBox(width: 6),
            GestureDetector(
              onTap: _clear,
              child: Icon(Icons.close_rounded,
                  size: 13, color: Colors.grey.shade500),
            ),
          ],
        ]),
      ),
    );
  }
}