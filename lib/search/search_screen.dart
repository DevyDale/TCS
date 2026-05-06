// lib/screens/search/search_screen.dart
//
// Phase 4 spec 8.1 — mode-first search picker.
//
// Replaces the old single-page tabbed search with a clean entry point
// where the user picks WHAT they're searching for (Posts / People /
// Clubs) before any query input. Each mode then routes to its own
// dedicated search screen with mode-specific filters.
//
// This file is the entry route — `Navigator.push(... SearchScreen())`
// from anywhere lands here. The three child screens are
// `search_posts_screen.dart`, `search_people_screen.dart`, and
// `search_clubs_screen.dart`.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'search_posts_screen.dart';
import 'search_people_screen.dart';
import 'search_clubs_screen.dart';

const _kG1     = Color(0xFF6DD5FA);
const _kG2     = Color(0xFF8E54E9);
const _kG3     = Color(0xFFF7971E);
const _kG4     = Color(0xFFFF5858);
const _kInk    = Color(0xFF1A1A2E);
const _kSlate  = Color(0xFF64687A);
const _kBg     = Color(0xFFF4F5FA);

class SearchScreen extends StatelessWidget {
  const SearchScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context),
            const SizedBox(height: 8),
            Expanded(child: _buildModeList(context)),
          ],
        ),
      ),
    );
  }

  // ── Header ──────────────────────────────────────────────────

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 12, 20, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: _kInk),
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 6),
                Text(
                  'WHAT ARE YOU LOOKING FOR?',
                  style: TextStyle(
                    fontFamily: 'Arch',
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                    color: _kG2,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Search',
                  style: TextStyle(
                    fontFamily: 'Alfa',
                    fontSize: 26,
                    color: _kInk,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Pick what you\'re looking for to get the right filters.',
                  style: TextStyle(
                    fontFamily: 'Momo',
                    fontSize: 13,
                    color: _kSlate.withOpacity(0.85),
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

  // ── Mode list ───────────────────────────────────────────────

  Widget _buildModeList(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      children: [
        _ModeCard(
          icon:        Icons.article_rounded,
          title:       'Posts',
          subtitle:    'Find posts by caption or location',
          gradient:    const [_kG1, _kG2],
          accentLabel: 'CAMPUS POSTS',
          onTap: () {
            HapticFeedback.lightImpact();
            Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => const SearchPostsScreen(),
            ));
          },
        ),
        const SizedBox(height: 14),
        _ModeCard(
          icon:        Icons.people_rounded,
          title:       'People',
          subtitle:    'Find students and staff by name or ID',
          gradient:    const [_kG2, _kG4],
          accentLabel: 'PEOPLE',
          onTap: () {
            HapticFeedback.lightImpact();
            Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => const SearchPeopleScreen(),
            ));
          },
        ),
        const SizedBox(height: 14),
        _ModeCard(
          icon:        Icons.groups_rounded,
          title:       'Clubs',
          subtitle:    'Find clubs by name or category',
          gradient:    const [_kG3, _kG4],
          accentLabel: 'CLUBS',
          onTap: () {
            HapticFeedback.lightImpact();
            Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => const SearchClubsScreen(),
            ));
          },
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// MODE CARD
// ─────────────────────────────────────────────────────────────

class _ModeCard extends StatelessWidget {
  final IconData     icon;
  final String       title;
  final String       subtitle;
  final List<Color>  gradient;
  final String       accentLabel;
  final VoidCallback onTap;

  const _ModeCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.gradient,
    required this.accentLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: gradient.first.withOpacity(0.10),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            // Gradient icon block
            Container(
              width: 56, height: 56,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: gradient,
                  begin: Alignment.topLeft,
                  end:   Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: gradient.last.withOpacity(0.25),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(icon, color: Colors.white, size: 28),
            ),
            const SizedBox(width: 16),

            // Text block
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    accentLabel,
                    style: TextStyle(
                      fontFamily: 'Arch',
                      fontWeight: FontWeight.bold,
                      fontSize: 9,
                      color: gradient.last,
                      letterSpacing: 1.3,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    title,
                    style: const TextStyle(
                      fontFamily: 'Alfa',
                      fontSize: 19,
                      color: _kInk,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontFamily: 'Momo',
                      fontSize: 12,
                      color: _kSlate.withOpacity(0.8),
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.chevron_right_rounded,
                color: gradient.last, size: 24),
          ],
        ),
      ),
    );
  }
}
