// lib/screens/events_screen.dart
//
// Phase 2 spec: replaces the old `events.dart` which used a hardcoded
// `allEvents` list. This version pulls from `/api/events/` with the same
// search box, category filters, and featured carousel as before, but
// every card is now a real backend event and tapping it opens the new
// EventDetailsScreen (which handles RSVP itself).
//
// Drop-in replacement: any router that pointed to `EventsPage` should
// point to `EventsScreen` instead. The widget name was changed to make
// the migration explicit and avoid silent import collisions.

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gradient_borders/gradient_borders.dart';
import 'package:intl/intl.dart';

import '../services/api_service.dart';
import 'event_details.dart';

const _kG1 = Color(0xFF6DD5FA);
const _kG2 = Color(0xFF8E54E9);
const _kG3 = Color(0xFFF7971E);
const _kG4 = Color(0xFFFF5858);
const _kInk = Color(0xFF1A1A2E);

class EventsScreen extends StatefulWidget {
  const EventsScreen({super.key});

  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen> {
  final _api = ApiService();

  List<Map<String, dynamic>> _events = [];
  bool   _loading = true;
  String _searchQuery       = '';
  String _selectedCategory  = 'All';
  String? _error;

  // Category strings as shown to the user; the backend uses the lowercase form.
  static const _categories = ['All', 'Academic', 'Sports', 'Club', 'Social'];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() { _loading = true; _error = null; });
    try {
      final data = await _api.getEvents(
        category: _selectedCategory == 'All'
            ? null
            : _selectedCategory.toLowerCase(),
      );
      // Endpoint may be paginated (results+count) or a bare list.
      final List list = data is Map && data['results'] is List
          ? data['results'] as List
          : (data as List);
      if (!mounted) return;
      setState(() {
        _events  = list.cast<Map<String, dynamic>>();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error   = 'Could not load events. Pull to retry.';
      });
    }
  }

  List<Map<String, dynamic>> get _filteredEvents {
    if (_searchQuery.isEmpty) return _events;
    final q = _searchQuery.toLowerCase();
    return _events.where((e) {
      final title    = (e['title']    as String? ?? '').toLowerCase();
      final desc     = (e['description'] as String? ?? '').toLowerCase();
      final location = (e['location'] as String? ?? '').toLowerCase();
      final org      = (e['organizer_name'] as String? ?? '').toLowerCase();
      return title.contains(q) || desc.contains(q)
          || location.contains(q) || org.contains(q);
    }).toList();
  }

  List<Map<String, dynamic>> get _featuredEvents =>
      _events.where((e) => e['is_featured'] == true).toList();

  void _openDetails(Map<String, dynamic> event) {
    HapticFeedback.lightImpact();
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => EventDetailsScreen(
        eventId: event['id'].toString(),
        initial: event,
      ),
    ));
  }

  // ── Build ──────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      body: SafeArea(
        child: RefreshIndicator(
          color: _kG2,
          onRefresh: _load,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics()),
            slivers: [
              SliverToBoxAdapter(child: _buildSearchBar()),
              SliverToBoxAdapter(child: _buildCategoryFilters()),
              if (_featuredEvents.isNotEmpty) ...[
                const SliverToBoxAdapter(child: _SectionHeader(title: 'Featured')),
                SliverToBoxAdapter(child: _buildFeaturedCarousel()),
              ],
              const SliverToBoxAdapter(child: _SectionHeader(title: 'All Events')),
              if (_loading)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: CircularProgressIndicator(color: _kG2)),
                )
              else if (_error != null)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _buildError(_error!),
                )
              else if (_filteredEvents.isEmpty)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: _EmptyState(),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (_, i) => _EventListCard(
                        event: _filteredEvents[i],
                        onTap: () => _openDetails(_filteredEvents[i]),
                      ),
                      childCount: _filteredEvents.length,
                    ),
                  ),
                ),
              const SliverToBoxAdapter(child: SizedBox(height: 40)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildError(String msg) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.cloud_off_rounded, size: 56, color: Colors.grey),
          const SizedBox(height: 12),
          Text(msg,
              textAlign: TextAlign.center,
              style: const TextStyle(fontFamily: 'Momo', fontSize: 13)),
          const SizedBox(height: 16),
          TextButton(onPressed: _load, child: const Text('Try again')),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
      child: TextField(
        onChanged: (v) => setState(() => _searchQuery = v),
        style: const TextStyle(fontFamily: 'Momo', fontSize: 14),
        decoration: InputDecoration(
          hintText: 'Search for events...',
          hintStyle: TextStyle(
              fontFamily: 'Momo', color: Colors.grey.shade400, fontSize: 13),
          prefixIcon: const Icon(Icons.search_rounded, color: _kG2),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: Colors.grey.shade200),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryFilters() {
    return SizedBox(
      height: 50,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: _categories.length,
        itemBuilder: (_, i) => _FilterChip(
          label:    _categories[i],
          selected: _selectedCategory == _categories[i],
          onTap: () {
            HapticFeedback.selectionClick();
            setState(() => _selectedCategory = _categories[i]);
            _load();
          },
        ),
      ),
    );
  }

  Widget _buildFeaturedCarousel() {
    return SizedBox(
      height: 220,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: _featuredEvents.length,
        itemBuilder: (_, i) => _FeaturedCard(
          event: _featuredEvents[i],
          onTap: () => _openDetails(_featuredEvents[i]),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────

String _eventDateLine(Map<String, dynamic> e) {
  final raw = e['start_time'] as String?;
  if (raw == null || raw.isEmpty) return '';
  try {
    final dt = DateTime.parse(raw).toLocal();
    return DateFormat('MMM d, yyyy • h:mm a').format(dt);
  } catch (_) {
    return raw;
  }
}

String _eventImageUrl(Map<String, dynamic> e) =>
    (e['card_url']  as String?)
    ?? (e['image_url'] as String?)
    ?? (e['poster_url'] as String?)
    ?? '';

Color _categoryColor(String c) {
  switch (c.toLowerCase()) {
    case 'academic': return _kG1;
    case 'sports':   return _kG3;
    case 'club':     return _kG2;
    case 'social':   return _kG4;
    case 'arcade':   return _kG2;
    default:         return Colors.blueGrey;
  }
}

Widget _eventImage(String url, {required double w, required double h, BorderRadius? br}) {
  if (url.isEmpty) {
    return Container(
      width: w, height: h,
      decoration: BoxDecoration(
        borderRadius: br ?? BorderRadius.circular(12),
        gradient: const LinearGradient(
          colors: [_kG1, _kG2],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
      ),
      child: const Icon(Icons.event_rounded, color: Colors.white54, size: 28),
    );
  }
  return ClipRRect(
    borderRadius: br ?? BorderRadius.circular(12),
    child: CachedNetworkImage(
      imageUrl: url,
      width: w, height: h,
      fit: BoxFit.cover,
      placeholder: (_, __) => Container(width: w, height: h, color: const Color(0xFFEDEEF3)),
      errorWidget: (_, __, ___) => Container(width: w, height: h, color: const Color(0xFFEDEEF3)),
    ),
  );
}

// ─────────────────────────────────────────────────────────────
// Featured carousel card
// ─────────────────────────────────────────────────────────────

class _FeaturedCard extends StatelessWidget {
  final Map<String, dynamic> event;
  final VoidCallback onTap;
  const _FeaturedCard({required this.event, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final title = event['title'] as String? ?? '';
    final url   = _eventImageUrl(event);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 300,
        margin: const EdgeInsets.only(right: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: const GradientBoxBorder(
            gradient: LinearGradient(
              colors: [_kG1, _kG2, _kG3, _kG4],
              begin: Alignment.topLeft, end: Alignment.bottomRight,
            ),
            width: 2.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.10),
              blurRadius: 16, offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: Stack(
            children: [
              Positioned.fill(child: _eventImage(url, w: 300, h: 220, br: BorderRadius.zero)),
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end:   Alignment.topCenter,
                      colors: [
                        _kG2.withOpacity(0.85),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 16, right: 16, bottom: 16,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 19,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.calendar_month, color: Colors.white70, size: 14),
                        const SizedBox(width: 5),
                        Flexible(
                          child: Text(
                            _eventDateLine(event),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// List card
// ─────────────────────────────────────────────────────────────

class _EventListCard extends StatelessWidget {
  final Map<String, dynamic> event;
  final VoidCallback onTap;
  const _EventListCard({required this.event, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final title    = event['title']          as String? ?? '';
    final org      = event['organizer_name'] as String? ?? 'Campus';
    final cat      = event['category']       as String? ?? '';
    final location = event['location']       as String? ?? '';

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: const GradientBoxBorder(
            gradient: LinearGradient(
              colors: [_kG1, _kG2, _kG3, _kG4],
              begin: Alignment.topLeft, end: Alignment.bottomRight,
            ),
            width: 1.8,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10, offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _eventImage(_eventImageUrl(event), w: 60, h: 60),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: _kG2,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          org,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: _kG3,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (cat.isNotEmpty) _CategoryBadge(label: cat),
                ],
              ),
              const Divider(height: 24, color: _kG2),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _IconText(icon: Icons.access_time,
                            label: _eventDateLine(event), color: _kG1),
                        const SizedBox(height: 4),
                        if (location.isNotEmpty)
                          _IconText(icon: Icons.location_on_outlined,
                              label: location, color: _kG3),
                      ],
                    ),
                  ),
                  ElevatedButton(
                    onPressed: onTap,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _kG2,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Details'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryBadge extends StatelessWidget {
  final String label;
  const _CategoryBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    final color = _categoryColor(label);
    final pretty = label.isEmpty ? '' : label[0].toUpperCase() + label.substring(1);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.18),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        pretty,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 11,
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: _kG2,
        ),
      ),
    );
  }
}

class _IconText extends StatelessWidget {
  final IconData icon;
  final String   label;
  final Color    color;
  const _IconText({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
          ),
        ),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String       label;
  final bool         selected;
  final VoidCallback onTap;
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
        selectedColor: _kG2,
        backgroundColor: Colors.white,
        labelStyle: TextStyle(
          color: selected ? Colors.white : Colors.black87,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('📭', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 12),
            const Text(
              'No events to show',
              style: TextStyle(fontFamily: 'Alfa', fontSize: 18, color: _kInk),
            ),
            const SizedBox(height: 6),
            Text(
              'Check back soon — new events appear here as they are scheduled.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontFamily: 'Momo', fontSize: 13, color: Colors.grey.shade500),
            ),
          ],
        ),
      ),
    );
  }
}
