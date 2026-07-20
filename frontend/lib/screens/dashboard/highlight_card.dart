// lib/widgets/highlight_card.dart
//
// Phase 2 spec 10.3 — unified carousel card used on the campus feed.
// Renders an event OR an announcement consistently. The backend's
// /api/events/highlights/ endpoint returns items with a `kind` field
// distinguishing the two. Tap dispatch is the caller's responsibility:
// this widget exposes `onTap(item)` and lets the feed screen route to
// the correct detail view.

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:tcs_app/theme/app_colors.dart';
import 'package:intl/intl.dart';

const _kViolet = Color(0xFF8E54E9);
const _kBlue   = Color(0xFF6DD5FA);
const _kAmber  = Color(0xFFF7971E);
const _kCoral  = Color(0xFFFF5858);
Color get _kInk => AppC.text;

class HighlightCard extends StatelessWidget {
  /// Map shape from `/api/events/highlights/`:
  /// {
  ///   kind: 'event' | 'announcement',
  ///   id, title, preview, card_url, tag,
  ///   start_time?, location?, created_at
  /// }
  final Map<String, dynamic> item;
  final VoidCallback onTap;

  const HighlightCard({
    super.key,
    required this.item,
    required this.onTap,
  });

  bool   get _isEvent  => (item['kind'] as String? ?? '') == 'event';
  String get _title    => (item['title']    as String? ?? '').trim();
  String get _preview  => (item['preview']  as String? ?? '').trim();
  String get _imageUrl => (item['card_url'] as String? ?? '').trim();
  String get _tag      => (item['tag']      as String? ?? '').trim();
  String get _location => (item['location'] as String? ?? '').trim();

  String? get _startTime {
    final raw = item['start_time'] as String?;
    if (raw == null || raw.isEmpty) return null;
    try {
      final dt = DateTime.parse(raw).toLocal();
      return DateFormat('MMM d • h:mm a').format(dt);
    } catch (_) {
      return null;
    }
  }

  Color get _accent => _isEvent ? _kAmber : _kViolet;

  String get _kindLabel => _isEvent ? 'EVENT' : 'ANNOUNCEMENT';

  IconData get _kindIcon =>
      _isEvent ? Icons.event_rounded : Icons.campaign_rounded;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: AppC.card,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: _accent.withOpacity(0.18),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            children: [
              // ── Poster (or fallback gradient if no image) ──────
              Positioned.fill(child: _buildPoster()),

              // Gradient overlay so text stays readable
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end:   Alignment.bottomCenter,
                      colors: [
                        Colors.black.withOpacity(0.0),
                        Colors.black.withOpacity(0.25),
                        Colors.black.withOpacity(0.78),
                      ],
                      stops: const [0.0, 0.45, 1.0],
                    ),
                  ),
                ),
              ),

              // ── Top-left: kind badge ───────────────────────────
              Positioned(
                top: 14, left: 14,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_kindIcon, size: 13, color: _accent),
                      const SizedBox(width: 5),
                      Text(
                        _kindLabel,
                        style: TextStyle(
                          fontFamily: 'Arch',
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                          color: _accent,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ── Top-right: tag (category or author) ────────────
              if (_tag.isNotEmpty)
                Positioned(
                  top: 14, right: 14,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.45),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _tag,
                      style: const TextStyle(
                        fontFamily: 'Momo',
                        fontWeight: FontWeight.w600,
                        fontSize: 11,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),

              // ── Bottom: title + preview + meta row ─────────────
              Positioned(
                left: 16, right: 16, bottom: 14,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'Alfa',
                        fontSize: 18,
                        color: Colors.white,
                        height: 1.15,
                      ),
                    ),
                    if (_preview.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        _preview,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'Momo',
                          fontSize: 12,
                          color: Colors.white.withOpacity(0.85),
                        ),
                      ),
                    ],
                    if (_isEvent) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          if (_startTime != null) ...[
                            Icon(Icons.calendar_month_rounded,
                                size: 13, color: Colors.white.withOpacity(0.9)),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                _startTime!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontFamily: 'Momo',
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white.withOpacity(0.95),
                                ),
                              ),
                            ),
                          ],
                          if (_startTime != null && _location.isNotEmpty)
                            Container(
                              width: 3, height: 3,
                              margin: const EdgeInsets.symmetric(horizontal: 8),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.6),
                                shape: BoxShape.circle,
                              ),
                            ),
                          if (_location.isNotEmpty)
                            Flexible(
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.location_on_rounded,
                                      size: 13, color: Colors.white.withOpacity(0.9)),
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: Text(
                                      _location,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontFamily: 'Momo',
                                        fontSize: 11,
                                        color: Colors.white.withOpacity(0.9),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPoster() {
    if (_imageUrl.isEmpty) return _buildFallback();
    return CachedNetworkImage(
      imageUrl:    _imageUrl,
      fit:         BoxFit.cover,
      placeholder: (_, __) => Container(color: const Color(0xFFEDEEF3)),
      errorWidget: (_, __, ___) => _buildFallback(),
    );
  }

  Widget _buildFallback() {
    // No poster set — render a tasteful gradient with the kind icon
    // so the carousel still has visual identity.
    final colors = _isEvent
        ? const [_kAmber, _kCoral]
        : const [_kBlue, _kViolet];
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: colors,
          begin: Alignment.topLeft,
          end:   Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Icon(_kindIcon, size: 56, color: Colors.white.withOpacity(0.35)),
      ),
    );
  }
}
