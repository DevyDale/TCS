import 'package:flutter/material.dart';
import 'package:gradient_borders/gradient_borders.dart';
// import 'event_details.dart'; // Ensure this path is correct

class EventsPage extends StatefulWidget {
  const EventsPage({super.key});

  @override
  State<EventsPage> createState() => _EventsPageState();
}

class _EventsPageState extends State<EventsPage> {
  String searchQuery = '';
  String selectedCategory = 'All';

  final List<Map<String, dynamic>> allEvents = [
    {
      'title': 'Sports Carnival',
      'image': 'https://images.unsplash.com/photo-1506744038136-46273834b3fb',
      'dateTime': 'Feb 12, 2026, 10:00 AM',
      'organizer': 'Sports Club',
      'category': 'Sports',
      'location': 'Main Field',
      'description': 'Join the annual sports carnival with games, food, and prizes!',
      'attendees': 120,
      'isFeatured': true,
    },
    {
      'title': 'Math Workshop',
      'image': 'https://images.unsplash.com/photo-1464983953574-0892a716854b',
      'dateTime': 'Feb 15, 2026, 2:00 PM',
      'organizer': 'Math Society',
      'category': 'Academic',
      'location': 'Room 204',
      'description': 'Sharpen your math skills with expert tutors.',
      'attendees': 60,
      'isFeatured': true,
    },
    {
      'title': 'Art Club Meetup',
      'image': 'https://images.unsplash.com/photo-1515378791036-0648a3ef77b2',
      'dateTime': 'Feb 18, 2026, 4:00 PM',
      'organizer': 'Art Club',
      'category': 'Club',
      'location': 'Art Studio',
      'description': 'Paint, draw, and create with friends.',
      'attendees': 30,
      'isFeatured': false,
    },
    // ... add more events as needed
  ];

  // Logic: Filter events based on search and category
  List<Map<String, dynamic>> get _filteredEvents {
    return allEvents.where((e) {
      final matchesSearch = e['title'].toLowerCase().contains(searchQuery.toLowerCase()) ||
          e['category'].toLowerCase().contains(searchQuery.toLowerCase());
      final matchesCategory = selectedCategory == 'All' || e['category'] == selectedCategory;
      return matchesSearch && matchesCategory;
    }).toList();
  }

  List<Map<String, dynamic>> get _featuredEvents => 
      allEvents.where((e) => e['isFeatured'] == true).toList();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        title: const Text('Campus Events', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        elevation: 1.5,
        centerTitle: true,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color(0xFF6DD5FA),
                Color(0xFF8E54E9),
                Color(0xFFF7971E),
                Color(0xFFFF5858),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _buildSearchBar()),
          SliverToBoxAdapter(child: _buildCategoryFilters()),
          const SliverToBoxAdapter(child: _SectionHeader(title: "Featured Events", color: Color(0xFF8E54E9))),
          SliverToBoxAdapter(child: _buildFeaturedCarousel()),
          const SliverToBoxAdapter(child: _SectionHeader(title: "All Events", color: Color(0xFFF7971E))),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) => _EventListCard(event: _filteredEvents[index]),
                childCount: _filteredEvents.length,
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
      child: TextField(
        onChanged: (val) => setState(() => searchQuery = val),
        decoration: InputDecoration(
          hintText: 'Search for events...',
          prefixIcon: const Icon(Icons.search, color: Colors.deepPurple),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: Colors.grey.shade200),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryFilters() {
    final categories = ['All', 'Academic', 'Sports', 'Club', 'Social'];
    return SizedBox(
      height: 50,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: categories.length,
        itemBuilder: (context, i) => _FilterChip(
          label: categories[i],
          selected: selectedCategory == categories[i],
          onTap: () => setState(() => selectedCategory = categories[i]),
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
        itemBuilder: (context, i) => _FeaturedCard(event: _featuredEvents[i]),
      ),
    );
  }
}

/// A modern, high-contrast card for Featured Events
class _FeaturedCard extends StatelessWidget {
  final Map<String, dynamic> event;
  const _FeaturedCard({required this.event});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 300,
      margin: const EdgeInsets.only(right: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        image: DecorationImage(image: NetworkImage(event['image']), fit: BoxFit.cover),
        border: const GradientBoxBorder(
          gradient: LinearGradient(
            colors: [Color(0xFF6DD5FA), Color(0xFF8E54E9), Color(0xFFF7971E), Color(0xFFFF5858)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          width: 2.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.10),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [Color(0xFF8E54E9).withOpacity(0.85), Colors.transparent],
          ),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(event['title'], style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.calendar_month, color: Colors.white70, size: 14),
                const SizedBox(width: 5),
                Text(event['dateTime'], style: const TextStyle(color: Colors.white70, fontSize: 12)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Standard List Card for "All Events"
class _EventListCard extends StatelessWidget {
  final Map<String, dynamic> event;
  const _EventListCard({required this.event});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: const GradientBoxBorder(
          gradient: LinearGradient(
            colors: [Color(0xFF6DD5FA), Color(0xFF8E54E9), Color(0xFFF7971E), Color(0xFFFF5858)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          width: 1.8,
        ),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(event['image'], width: 60, height: 60, fit: BoxFit.cover),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(event['title'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: Color(0xFF8E54E9))),
                      const SizedBox(height: 4),
                      Text(event['organizer'], style: TextStyle(color: Color(0xFFF7971E), fontSize: 13, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
                _buildBadge(event['category']),
              ],
            ),
            const Divider(height: 24, color: Color(0xFF8E54E9)),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _IconText(icon: Icons.access_time, label: event['dateTime'], color: Color(0xFF6DD5FA)),
                    const SizedBox(height: 4),
                    _IconText(icon: Icons.location_on_outlined, label: event['location'], color: Color(0xFFF7971E)),
                  ],
                ),
                ElevatedButton(
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF8E54E9),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text("RSVP"),
                )
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildBadge(String label) {
    Color badgeColor;
    Color textColor;
    switch (label) {
      case 'Academic':
        badgeColor = const Color(0xFF6DD5FA).withOpacity(0.18);
        textColor = const Color(0xFF6DD5FA);
        break;
      case 'Sports':
        badgeColor = const Color(0xFFF7971E).withOpacity(0.18);
        textColor = const Color(0xFFF7971E);
        break;
      case 'Club':
        badgeColor = const Color(0xFF8E54E9).withOpacity(0.18);
        textColor = const Color(0xFF8E54E9);
        break;
      case 'Social':
        badgeColor = const Color(0xFFFF5858).withOpacity(0.18);
        textColor = const Color(0xFFFF5858);
        break;
      default:
        badgeColor = Colors.grey.shade200;
        textColor = Colors.grey.shade700;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: badgeColor, borderRadius: BorderRadius.circular(8)),
      child: Text(label, style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 11)),
    );
  }
}

// UI Components
class _SectionHeader extends StatelessWidget {
  final String title;
  final Color? color;
  const _SectionHeader({required this.title, this.color});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
      child: Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color ?? const Color(0xFF8E54E9))),
    );
  }
}

class _IconText extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _IconText({required this.icon, required this.label, required this.color});
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(fontSize: 13, color: Colors.grey.shade700)),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _FilterChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
        selectedColor: Colors.deepPurple,
        backgroundColor: Colors.white,
        labelStyle: TextStyle(color: selected ? Colors.white : Colors.black87, fontWeight: FontWeight.bold),
      ),
    );
  }
}