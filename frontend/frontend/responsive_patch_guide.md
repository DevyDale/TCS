# Responsive Patch Guide — TCS Flutter App

## Files already fully rewritten (drop in directly):
- responsive_helper.dart         → lib/utils/
- role_selection_screen.dart     → lib/screens/auth/
- splash_screen.dart             → lib/screens/
- login_id_screen.dart           → lib/screens/auth/
- login_password_screen.dart     → lib/screens/auth/
- dashboard_screen.dart          → lib/screens/dashboard/

## Files that need 3 targeted changes (apply to your existing files):

### CHANGE 1 — Add import (top of file, after other imports):
```dart
import '../../utils/responsive_helper.dart';
```

### CHANGE 2 — Add res variable (first line inside build method):
```dart
final res = R(context);
```

### CHANGE 3 — Wrap scrollable body content with ConstrainedBox:

**For SingleChildScrollView screens** (registration, bio, events, create_post, etc.):
```dart
// BEFORE:
SingleChildScrollView(
  padding: const EdgeInsets.symmetric(horizontal: 24),
  child: Column(...)
)

// AFTER:
SingleChildScrollView(
  padding: EdgeInsets.symmetric(horizontal: res.isPhone ? 24 : 32),
  child: Center(
    child: ConstrainedBox(
      constraints: BoxConstraints(maxWidth: res.formMaxW),
      child: Column(...)
    ),
  ),
)
```

**For CustomScrollView/NestedScrollView screens** (feed, profile, groups, arcade):
```dart
// Wrap the SliverToBoxAdapter children:
SliverToBoxAdapter(
  child: Center(
    child: ConstrainedBox(
      constraints: BoxConstraints(maxWidth: 680),
      child: YourContent(),
    ),
  ),
)
```

**For ListView screens** (chat list, leaderboard):
```dart
// Add to ListView:
ListView.builder(
  padding: EdgeInsets.fromLTRB(
    context.isPhone ? 16 : 32,   // responsive horizontal
    12,
    context.isPhone ? 16 : 32,
    80,
  ),
  ...
)
```

### CHANGE 4 — Replace hardcoded font sizes (optional, pick the most visible ones):
```dart
// Font sizes
fontSize: 24  →  fontSize: res.heading
fontSize: 14  →  fontSize: res.body
fontSize: 12  →  fontSize: res.caption

// Padding
EdgeInsets.all(20)  →  res.cardPad
EdgeInsets.symmetric(horizontal: 16)  →  res.pagePad

// Button heights
height: 56  →  height: res.btnH
height: 52  →  height: res.btnH

// Icon sizes
size: 22  →  size: res.iconMd
size: 44  →  size: res.avatarSize
```

## Screens where original code is already responsive enough:
- arcade_screen.dart      (uses CustomScrollView, BouncingScrollPhysics, Expanded)
- chat_room_screen.dart   (full-screen chat, no width constraint needed)
- chat_list_screen.dart   (full-screen list)
- feed_screen.dart        (NestedScrollView, fine as-is)
- groups_screen.dart      (SafeArea + ListView, fine as-is)
- profile_screen.dart     (NestedScrollView, fine as-is)
- events.dart             (CustomScrollView, fine as-is)
- interests.dart          (ListView + Stack, fine as-is)
- bio.dart                (SingleChildScrollView, add ConstrainedBox only)
- create_posts.dart       (Column layout, add ConstrainedBox only)
- create_fweet.dart       (Column layout, add ConstrainedBox only)
- event_details.dart      (CustomScrollView, fine as-is)

## The 3 screens that need the most work (already done):
1. role_selection_screen.dart  ✅ — complete responsive layout with 2-col grid on tablet
2. login_id_screen.dart        ✅ — constrained, responsive spacing
3. login_password_screen.dart  ✅ — constrained, responsive spacing

## Grid breakpoints summary:
| Device         | Width      | Columns | Max Content Width |
|----------------|------------|---------|-------------------|
| Phone          | < 600px    | 1       | 100%              |
| Tablet         | 600–900px  | 2       | 520px             |
| iPad/Laptop    | 900–1200px | 2–3     | 600px             |
| Desktop        | > 1200px   | 3       | 680px             |
