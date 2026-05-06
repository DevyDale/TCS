// lib/screens/event_details_screen.dart
//
// Phase 2 spec 10.4 — full-screen event detail with poster, title,
// description, date/time, location, and 3-state RSVP wired to the backend.
//
// REPLACES the old hardcoded `event_details.dart` which simulated RSVP
// with a fake 900ms delay. Routing change required at every call site:
//
//   OLD: Navigator.push(... EventDetailsPage(title: '...', ...))
//   NEW: Navigator.push(... EventDetailsScreen(eventId: id))
//
// The screen fetches the event itself, so callers only need to pass an ID.

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:tcs_app/rsvp_picker.dart';

import '../services/api_service.dart';

const _kG1 = Color(0xFF6DD5FA);
const _kG2 = Color(0xFF8E54E9);
const _kG3 = Color(0xFFF7971E);
const _kG4 = Color(0xFFFF5858);
const _kInk = Color(0xFF1A1A2E);

class EventDetailsScreen extends StatefulWidget {
  final String eventId;

  /// Optional: pre-loaded data to render immediately while the fresh fetch
  /// runs. Useful when navigating from a list/carousel that already has it.
  final Map<String, dynamic>? initial;

  const EventDetailsScreen({
    super.key,
    required this.eventId,
    this.initial,
  });

  @override
  State<EventDetailsScreen> createState() => _EventDetailsScreenState();
}

class _EventDetailsScreenState extends State<EventDetailsScreen> {
  final _api = ApiService();
  Map<String, dynamic>? _event;
  bool _loading   = true;
  bool _rsvpBusy  = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.initial != null) {
      _event   = Map<String, dynamic>.from(widget.initial!);
      _loading = false;
    }
    _fetch();
  }

  Future<void> _fetch() async {
    try {
      final data = await _api.getEvent(widget.eventId) as Map<String, dynamic>;
      if (!mounted) return;
      setState(() {
        _event   = data;
        _loading = false;
        _error   = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error   = 'Could not load event. Pull down to retry.';
      });
    }
  }

  Future<void> _setRsvp(String? newStatus) async {
    if (_event == null || _rsvpBusy) return;
    HapticFeedback.mediumImpact();
    setState(() => _rsvpBusy = true);

    final prev = _event!['rsvp_status'] as String?;
    final prevGoingCount = _event!['going_count'] as int?
        ?? _event!['attendees_count'] as int? ?? 0;

    // Optimistic update so the UI feels instant.
    setState(() {
      _event!['rsvp_status'] = newStatus;
      _event!['is_rsvped']   = (newStatus == kRsvpGoing);
      // Going-count only shifts when the going-state itself shifts.
      final wasGoing  = prev == kRsvpGoing;
      final nowGoing  = newStatus == kRsvpGoing;
      if (wasGoing && !nowGoing) {
        _event!['going_count'] = (prevGoingCount - 1).clamp(0, 1 << 30);
      } else if (!wasGoing && nowGoing) {
        _event!['going_count'] = prevGoingCount + 1;
      }
      _event!['attendees_count'] = _event!['going_count']; // keep in sync
    });

    try {
      final result = await _api.setRsvp(widget.eventId, newStatus)
          as Map<String, dynamic>;
      if (!mounted) return;
      setState(() {
        _event!['rsvp_status']     = result['rsvp_status'];
        _event!['going_count']     = result['going_count'];
        _event!['attendees_count'] = result['going_count'];
        _event!['is_full']         = result['is_full'] ?? false;
        if (result.containsKey('interested_count')) {
          _event!['interested_count'] = result['interested_count'];
        }
      });
      _showSnack(_messageFor(result['rsvp_status'] as String?),
          color: _accentFor(result['rsvp_status'] as String?));
    } catch (e) {
      // Roll back the optimistic update.
      if (!mounted) return;
      setState(() {
        _event!['rsvp_status']     = prev;
        _event!['is_rsvped']       = (prev == kRsvpGoing);
        _event!['going_count']     = prevGoingCount;
        _event!['attendees_count'] = prevGoingCount;
      });
      _showSnack(
        e.toString().replaceAll('Exception: ', ''),
        color: _kG4,
      );
    } finally {
      if (mounted) setState(() => _rsvpBusy = false);
    }
  }

  String _messageFor(String? status) {
    switch (status) {
      case kRsvpGoing:      return "You're going! See you there 🎉";
      case kRsvpInterested: return 'Marked as interested ⭐';
      case kRsvpNotGoing:   return 'Marked as not going';
      default:              return 'RSVP cleared';
    }
  }

  Color _accentFor(String? status) {
    switch (status) {
      case kRsvpGoing:      return const Color(0xFF1D9E75);
      case kRsvpInterested: return _kG3;
      case kRsvpNotGoing:   return _kG4;
      default:              return _kG2;
    }
  }

  void _showSnack(String msg, {required Color color}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontFamily: 'Momo')),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      margin: const EdgeInsets.all(16),
      duration: const Duration(seconds: 2),
    ));
  }

  // ── Build ──────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      body: _event == null
          ? _buildLoadingOrError()
          : RefreshIndicator(
              color: _kG2,
              onRefresh: _fetch,
              child: CustomScrollView(
                slivers: [
                  _buildSliverHeader(),
                  SliverToBoxAdapter(child: _buildBody()),
                ],
              ),
            ),
      bottomNavigationBar: _event == null ? null : _buildRsvpBar(),
    );
  }

  Widget _buildLoadingOrError() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: _kG2));
    }
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded, size: 64, color: Colors.grey),
            const SizedBox(height: 12),
            Text(
              _error ?? 'Event not available.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontFamily: 'Momo', fontSize: 14),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () { setState(() { _loading = true; }); _fetch(); },
              child: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }

  // ── Header (image + back button) ────────────────────────────

  Widget _buildSliverHeader() {
    final posterUrl = (_event!['poster_url'] as String?)
        ?? (_event!['card_url']   as String?)
        ?? (_event!['image_url']  as String?)
        ?? '';
    return SliverAppBar(
      expandedHeight: 280,
      pinned: true,
      backgroundColor: _kInk,
      leading: Padding(
        padding: const EdgeInsets.all(8),
        child: ClipOval(
          child: Material(
            color: Colors.black.withOpacity(0.4),
            child: InkWell(
              onTap: () => Navigator.pop(context),
              child: const SizedBox(
                width: 38, height: 38,
                child: Icon(Icons.arrow_back_rounded, color: Colors.white, size: 20),
              ),
            ),
          ),
        ),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            if (posterUrl.isNotEmpty)
              CachedNetworkImage(
                imageUrl: posterUrl,
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(color: const Color(0xFFEDEEF3)),
                errorWidget: (_, __, ___) => _gradientFallback(),
              )
            else
              _gradientFallback(),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end:   Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.0),
                    Colors.black.withOpacity(0.55),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _gradientFallback() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [_kG1, _kG2, _kG3, _kG4],
          begin: Alignment.topLeft,
          end:   Alignment.bottomRight,
        ),
      ),
      child: const Center(
        child: Icon(Icons.event_rounded, size: 80, color: Colors.white24),
      ),
    );
  }

  // ── Body content ────────────────────────────────────────────

  Widget _buildBody() {
    final e = _event!;
    final title       = e['title']          as String? ?? '';
    final description = e['description']    as String? ?? '';
    final category    = e['category']       as String? ?? '';
    final organizer   = e['organizer_name'] as String? ?? 'Campus';
    final location    = e['location']       as String? ?? '';
    final isOnline    = e['is_online']      as bool?   ?? false;
    final going       = e['going_count']
        ?? e['attendees_count'] as int? ?? 0;
    final interested  = e['interested_count'] as int? ?? 0;

    final start = _parseDate(e['start_time'] as String?);
    final end   = _parseDate(e['end_time']   as String?);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Category chip
          if (category.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _categoryColor(category).withOpacity(0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                category[0].toUpperCase() + category.substring(1),
                style: TextStyle(
                  fontFamily: 'Arch',
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                  color: _categoryColor(category),
                ),
              ),
            ),

          const SizedBox(height: 12),

          Text(
            title,
            style: const TextStyle(
              fontFamily: 'Alfa',
              fontSize: 26,
              color: _kInk,
              height: 1.15,
            ),
          ),

          const SizedBox(height: 8),

          // Organizer line
          Row(
            children: [
              Icon(Icons.person_rounded, size: 14, color: Colors.grey.shade500),
              const SizedBox(width: 4),
              Text(
                'by $organizer',
                style: TextStyle(
                  fontFamily: 'Momo',
                  fontSize: 13,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),

          const SizedBox(height: 22),

          // Stats row: going / interested
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              children: [
                _stat(Icons.check_circle_rounded, '$going going',
                      const Color(0xFF1D9E75)),
                _vDivider(),
                _stat(Icons.star_rounded, '$interested interested', _kG3),
              ],
            ),
          ),

          const SizedBox(height: 22),

          // When
          if (start != null) _infoRow(
            icon: Icons.calendar_today_rounded,
            color: _kG2,
            label: 'WHEN',
            value: _formatDateRange(start, end),
          ),

          // Where
          if (location.isNotEmpty || isOnline) _infoRow(
            icon: isOnline ? Icons.videocam_rounded : Icons.location_on_rounded,
            color: _kG4,
            label: 'WHERE',
            value: isOnline ? 'Online' : location,
          ),

          const SizedBox(height: 22),

          // Description
          const Text('ABOUT', style: TextStyle(
            fontFamily: 'Arch',
            fontWeight: FontWeight.bold,
            fontSize: 11,
            color: _kG2,
            letterSpacing: 1.2,
          )),
          const SizedBox(height: 8),
          Text(
            description.isEmpty ? 'No description provided.' : description,
            style: const TextStyle(
              fontFamily: 'Momo',
              fontSize: 14,
              color: _kInk,
              height: 1.55,
            ),
          ),
        ],
      ),
    );
  }

  Widget _stat(IconData icon, String label, Color color) => Expanded(
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'Momo',
            fontWeight: FontWeight.bold,
            fontSize: 13,
            color: _kInk,
          ),
        ),
      ],
    ),
  );

  Widget _vDivider() => Container(
    width: 1, height: 24, color: Colors.grey.shade200,
  );

  Widget _infoRow({
    required IconData icon,
    required Color color,
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontFamily: 'Arch',
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                    color: Colors.grey.shade500,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontFamily: 'Momo',
                    fontSize: 14,
                    color: _kInk,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Bottom RSVP bar ─────────────────────────────────────────

  Widget _buildRsvpBar() {
    final status = _event!['rsvp_status'] as String?;
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Colors.grey.shade200)),
        ),
        child: RsvpPicker(
          status:    status,
          onChanged: _setRsvp,
          busy:      _rsvpBusy,
        ),
      ),
    );
  }

  // ── Helpers ────────────────────────────────────────────────

  DateTime? _parseDate(String? s) {
    if (s == null || s.isEmpty) return null;
    try {
      return DateTime.parse(s).toLocal();
    } catch (_) {
      return null;
    }
  }

  String _formatDateRange(DateTime start, DateTime? end) {
    final dateFmt = DateFormat('EEE, MMM d • h:mm a');
    if (end == null) return dateFmt.format(start);
    final sameDay = start.year == end.year &&
                    start.month == end.month &&
                    start.day == end.day;
    if (sameDay) {
      return '${dateFmt.format(start)} – ${DateFormat('h:mm a').format(end)}';
    }
    return '${dateFmt.format(start)}\n→ ${dateFmt.format(end)}';
  }

  Color _categoryColor(String c) {
    switch (c.toLowerCase()) {
      case 'academic': return _kG1;
      case 'sports':   return _kG3;
      case 'club':     return _kG2;
      case 'social':   return _kG4;
      case 'arcade':   return _kG2;
      default:         return Colors.grey.shade500;
    }
  }
}
