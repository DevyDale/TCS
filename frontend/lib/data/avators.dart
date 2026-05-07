// lib/data/avatars.dart
//
// 100 curated avatars rendered procedurally — no image assets needed.
// Each avatar is identified by its integer `id` (0-99) and is composed of:
//   • an emoji "face"
//   • a 2-color gradient background
//   • a category tag (for picker filtering)
//
// The actual rendering happens in widgets/avatar/avatar_view.dart.
//
// Categories: animals, fantasy, sci_fi, campus, food, mythical,
//             action, cosmic
//
// USAGE:
//   const def = kAvatars[user.avatarId];
//   AvatarView(avatarId: user.avatarId, size: 56)

import 'package:flutter/material.dart';

class AvatarDef {
  final int    id;
  final String name;
  final String emoji;
  final List<Color> gradient;
  final String category;

  const AvatarDef({
    required this.id,
    required this.name,
    required this.emoji,
    required this.gradient,
    required this.category,
  });
}

/// All 100 avatars. Index in this list IS the avatar id.
const List<AvatarDef> kAvatars = [
  // ── ANIMALS (0-19) ───────────────────────────────────────
  AvatarDef(id: 0,  name: 'Cosmic Cat',       emoji: '🐱',
      gradient: [Color(0xFFFF9A9E), Color(0xFFFAD0C4)], category: 'animals'),
  AvatarDef(id: 1,  name: 'Sleepy Doggo',     emoji: '🐶',
      gradient: [Color(0xFFFFD89B), Color(0xFFEF8B6C)], category: 'animals'),
  AvatarDef(id: 2,  name: 'Wild Fox',         emoji: '🦊',
      gradient: [Color(0xFFFF6B35), Color(0xFFF7931E)], category: 'animals'),
  AvatarDef(id: 3,  name: 'Forest Bear',      emoji: '🐻',
      gradient: [Color(0xFF8B4513), Color(0xFFD2691E)], category: 'animals'),
  AvatarDef(id: 4,  name: 'Bamboo Panda',     emoji: '🐼',
      gradient: [Color(0xFF2C3E50), Color(0xFF95A5A6)], category: 'animals'),
  AvatarDef(id: 5,  name: 'Wise Owl',         emoji: '🦉',
      gradient: [Color(0xFF614385), Color(0xFF516395)], category: 'animals'),
  AvatarDef(id: 6,  name: 'Snow Bunny',       emoji: '🐰',
      gradient: [Color(0xFFF5F7FA), Color(0xFFC3CFE2)], category: 'animals'),
  AvatarDef(id: 7,  name: 'Lucky Hamster',    emoji: '🐹',
      gradient: [Color(0xFFFFE8C5), Color(0xFFFAB29B)], category: 'animals'),
  AvatarDef(id: 8,  name: 'Speedy Turtle',    emoji: '🐢',
      gradient: [Color(0xFF11998E), Color(0xFF38EF7D)], category: 'animals'),
  AvatarDef(id: 9,  name: 'Brave Lion',       emoji: '🦁',
      gradient: [Color(0xFFFFC371), Color(0xFFFF5F6D)], category: 'animals'),
  AvatarDef(id: 10, name: 'Stealthy Tiger',   emoji: '🐯',
      gradient: [Color(0xFFFF6F00), Color(0xFFFF8E53)], category: 'animals'),
  AvatarDef(id: 11, name: 'Loyal Wolf',       emoji: '🐺',
      gradient: [Color(0xFF485563), Color(0xFF29323C)], category: 'animals'),
  AvatarDef(id: 12, name: 'Cheeky Monkey',    emoji: '🐵',
      gradient: [Color(0xFFC79081), Color(0xFFDFA579)], category: 'animals'),
  AvatarDef(id: 13, name: 'Rainbow Frog',     emoji: '🐸',
      gradient: [Color(0xFF56AB2F), Color(0xFFA8E063)], category: 'animals'),
  AvatarDef(id: 14, name: 'Royal Pig',        emoji: '🐷',
      gradient: [Color(0xFFFFC1CC), Color(0xFFFFB6C1)], category: 'animals'),
  AvatarDef(id: 15, name: 'Curious Otter',    emoji: '🦦',
      gradient: [Color(0xFF8E9EAB), Color(0xFFEEF2F3)], category: 'animals'),
  AvatarDef(id: 16, name: 'Galaxy Dolphin',   emoji: '🐬',
      gradient: [Color(0xFF00B4DB), Color(0xFF0083B0)], category: 'animals'),
  AvatarDef(id: 17, name: 'Funky Penguin',    emoji: '🐧',
      gradient: [Color(0xFF0F2027), Color(0xFF2C5364)], category: 'animals'),
  AvatarDef(id: 18, name: 'Buzzy Bee',        emoji: '🐝',
      gradient: [Color(0xFFFFD700), Color(0xFFFFA000)], category: 'animals'),
  AvatarDef(id: 19, name: 'Mystic Butterfly', emoji: '🦋',
      gradient: [Color(0xFFA770EF), Color(0xFFFDB99B)], category: 'animals'),

  // ── FANTASY (20-34) ──────────────────────────────────────
  AvatarDef(id: 20, name: 'Code Wizard',      emoji: '🧙',
      gradient: [Color(0xFF6A11CB), Color(0xFF2575FC)], category: 'fantasy'),
  AvatarDef(id: 21, name: 'Pixel Dragon',     emoji: '🐉',
      gradient: [Color(0xFFE52D27), Color(0xFFB31217)], category: 'fantasy'),
  AvatarDef(id: 22, name: 'Sparkle Unicorn',  emoji: '🦄',
      gradient: [Color(0xFFFC466B), Color(0xFF3F5EFB)], category: 'fantasy'),
  AvatarDef(id: 23, name: 'Tiny Fairy',       emoji: '🧚',
      gradient: [Color(0xFFFBC2EB), Color(0xFFA6C1EE)], category: 'fantasy'),
  AvatarDef(id: 24, name: 'Friendly Ghost',   emoji: '👻',
      gradient: [Color(0xFFE0EAFC), Color(0xFFCFDEF3)], category: 'fantasy'),
  AvatarDef(id: 25, name: 'Cute Vampire',     emoji: '🧛',
      gradient: [Color(0xFF870000), Color(0xFF190A05)], category: 'fantasy'),
  AvatarDef(id: 26, name: 'Forest Nymph',     emoji: '🧝',
      gradient: [Color(0xFF134E5E), Color(0xFF71B280)], category: 'fantasy'),
  AvatarDef(id: 27, name: 'Sky Genie',        emoji: '🧞',
      gradient: [Color(0xFF1488CC), Color(0xFF2B32B2)], category: 'fantasy'),
  AvatarDef(id: 28, name: 'Ice Queen',        emoji: '🥶',
      gradient: [Color(0xFF89F7FE), Color(0xFF66A6FF)], category: 'fantasy'),
  AvatarDef(id: 29, name: 'Fire Mage',        emoji: '🔥',
      gradient: [Color(0xFFFF512F), Color(0xFFF09819)], category: 'fantasy'),
  AvatarDef(id: 30, name: 'Crystal Knight',   emoji: '⚔️',
      gradient: [Color(0xFF4568DC), Color(0xFFB06AB3)], category: 'fantasy'),
  AvatarDef(id: 31, name: 'Time Sorceress',   emoji: '🪄',
      gradient: [Color(0xFF9D50BB), Color(0xFF6E48AA)], category: 'fantasy'),
  AvatarDef(id: 32, name: 'Storm Caller',     emoji: '⚡',
      gradient: [Color(0xFF373B44), Color(0xFF4286F4)], category: 'fantasy'),
  AvatarDef(id: 33, name: 'Earth Druid',      emoji: '🌿',
      gradient: [Color(0xFF134E5E), Color(0xFF71B280)], category: 'fantasy'),
  AvatarDef(id: 34, name: 'Moon Witch',       emoji: '🌙',
      gradient: [Color(0xFF232526), Color(0xFF414345)], category: 'fantasy'),

  // ── SCI-FI / TECH (35-49) ────────────────────────────────
  AvatarDef(id: 35, name: 'Beep Bot',         emoji: '🤖',
      gradient: [Color(0xFF8E2DE2), Color(0xFF4A00E0)], category: 'sci_fi'),
  AvatarDef(id: 36, name: 'Neon Robot',       emoji: '🦾',
      gradient: [Color(0xFF00F260), Color(0xFF0575E6)], category: 'sci_fi'),
  AvatarDef(id: 37, name: 'Star Alien',       emoji: '👽',
      gradient: [Color(0xFF00B09B), Color(0xFF96C93D)], category: 'sci_fi'),
  AvatarDef(id: 38, name: 'Astro Cadet',      emoji: '👨‍🚀',
      gradient: [Color(0xFF000428), Color(0xFF004E92)], category: 'sci_fi'),
  AvatarDef(id: 39, name: 'Cyber Punk',       emoji: '🕶️',
      gradient: [Color(0xFFFF006E), Color(0xFF8338EC)], category: 'sci_fi'),
  AvatarDef(id: 40, name: 'Code Breaker',     emoji: '💻',
      gradient: [Color(0xFF1A2980), Color(0xFF26D0CE)], category: 'sci_fi'),
  AvatarDef(id: 41, name: 'Pixel Pilot',      emoji: '🚀',
      gradient: [Color(0xFFFF512F), Color(0xFFDD2476)], category: 'sci_fi'),
  AvatarDef(id: 42, name: 'Quantum Hacker',   emoji: '⌨️',
      gradient: [Color(0xFF11998E), Color(0xFF38EF7D)], category: 'sci_fi'),
  AvatarDef(id: 43, name: 'Lab Genius',       emoji: '🧪',
      gradient: [Color(0xFFB24592), Color(0xFFF15F79)], category: 'sci_fi'),
  AvatarDef(id: 44, name: 'AI Companion',     emoji: '🧠',
      gradient: [Color(0xFFEE0979), Color(0xFFFF6A00)], category: 'sci_fi'),
  AvatarDef(id: 45, name: 'Glitch Master',    emoji: '👾',
      gradient: [Color(0xFFAA076B), Color(0xFF61045F)], category: 'sci_fi'),
  AvatarDef(id: 46, name: 'Void Walker',      emoji: '🌀',
      gradient: [Color(0xFF141E30), Color(0xFF243B55)], category: 'sci_fi'),
  AvatarDef(id: 47, name: 'Hologram',         emoji: '💎',
      gradient: [Color(0xFF00C9FF), Color(0xFF92FE9D)], category: 'sci_fi'),
  AvatarDef(id: 48, name: 'Data Knight',      emoji: '🛡️',
      gradient: [Color(0xFF3A1C71), Color(0xFFD76D77)], category: 'sci_fi'),
  AvatarDef(id: 49, name: 'Synth Star',       emoji: '🎛️',
      gradient: [Color(0xFFFC466B), Color(0xFF3F5EFB)], category: 'sci_fi'),

  // ── CAMPUS LIFE (50-59) ──────────────────────────────────
  AvatarDef(id: 50, name: 'Grad Star',        emoji: '🎓',
      gradient: [Color(0xFF1E3C72), Color(0xFF2A5298)], category: 'campus'),
  AvatarDef(id: 51, name: 'Lab Geek',         emoji: '🥽',
      gradient: [Color(0xFF11998E), Color(0xFF38EF7D)], category: 'campus'),
  AvatarDef(id: 52, name: 'Art Soul',         emoji: '🎨',
      gradient: [Color(0xFFFF9A9E), Color(0xFFFAD0C4)], category: 'campus'),
  AvatarDef(id: 53, name: 'Sports Hero',      emoji: '🏆',
      gradient: [Color(0xFFF7971E), Color(0xFFFFD200)], category: 'campus'),
  AvatarDef(id: 54, name: 'Pro Gamer',        emoji: '🎮',
      gradient: [Color(0xFF8E54E9), Color(0xFF4776E6)], category: 'campus'),
  AvatarDef(id: 55, name: 'Book Lover',       emoji: '📚',
      gradient: [Color(0xFF8E2DE2), Color(0xFF4A00E0)], category: 'campus'),
  AvatarDef(id: 56, name: 'Math Whiz',        emoji: '📐',
      gradient: [Color(0xFF1FA2FF), Color(0xFF12D8FA)], category: 'campus'),
  AvatarDef(id: 57, name: 'Music Maker',      emoji: '🎧',
      gradient: [Color(0xFFEE0979), Color(0xFFFF6A00)], category: 'campus'),
  AvatarDef(id: 58, name: 'Dance Star',       emoji: '💃',
      gradient: [Color(0xFFFF0099), Color(0xFF493240)], category: 'campus'),
  AvatarDef(id: 59, name: 'Drama Queen',      emoji: '🎭',
      gradient: [Color(0xFF833AB4), Color(0xFFFD1D1D)], category: 'campus'),

  // ── FOOD (60-69) ─────────────────────────────────────────
  AvatarDef(id: 60, name: 'Pizza King',       emoji: '🍕',
      gradient: [Color(0xFFFFC371), Color(0xFFFF5F6D)], category: 'food'),
  AvatarDef(id: 61, name: 'Sushi Master',     emoji: '🍣',
      gradient: [Color(0xFFFF512F), Color(0xFFF09819)], category: 'food'),
  AvatarDef(id: 62, name: 'Donut Queen',      emoji: '🍩',
      gradient: [Color(0xFFFFB6C1), Color(0xFFFF69B4)], category: 'food'),
  AvatarDef(id: 63, name: 'Taco Bandit',      emoji: '🌮',
      gradient: [Color(0xFFFFD89B), Color(0xFFEF8B6C)], category: 'food'),
  AvatarDef(id: 64, name: 'Boba Fan',         emoji: '🧋',
      gradient: [Color(0xFFC79081), Color(0xFFDFA579)], category: 'food'),
  AvatarDef(id: 65, name: 'Ramen Slurp',      emoji: '🍜',
      gradient: [Color(0xFFD66D75), Color(0xFFE29587)], category: 'food'),
  AvatarDef(id: 66, name: 'Cupcake Cutie',    emoji: '🧁',
      gradient: [Color(0xFFFBC2EB), Color(0xFFA6C1EE)], category: 'food'),
  AvatarDef(id: 67, name: 'Burger Boss',      emoji: '🍔',
      gradient: [Color(0xFFFF6F00), Color(0xFFFF8E53)], category: 'food'),
  AvatarDef(id: 68, name: 'Fries Lord',       emoji: '🍟',
      gradient: [Color(0xFFFFD700), Color(0xFFFFA000)], category: 'food'),
  AvatarDef(id: 69, name: 'Smoothie Star',    emoji: '🥤',
      gradient: [Color(0xFFFC5C7D), Color(0xFF6A82FB)], category: 'food'),

  // ── MYTHICAL (70-79) ─────────────────────────────────────
  AvatarDef(id: 70, name: 'Phoenix Rising',   emoji: '🔥',
      gradient: [Color(0xFFFF512F), Color(0xFFDD2476)], category: 'mythical'),
  AvatarDef(id: 71, name: 'Kraken Lord',      emoji: '🐙',
      gradient: [Color(0xFF134E5E), Color(0xFF71B280)], category: 'mythical'),
  AvatarDef(id: 72, name: 'Yeti Cool',        emoji: '☃️',
      gradient: [Color(0xFF89F7FE), Color(0xFF66A6FF)], category: 'mythical'),
  AvatarDef(id: 73, name: 'Ocean Mermaid',    emoji: '🧜',
      gradient: [Color(0xFF1A2980), Color(0xFF26D0CE)], category: 'mythical'),
  AvatarDef(id: 74, name: 'Centaur Sage',     emoji: '🐎',
      gradient: [Color(0xFF8B4513), Color(0xFFD2691E)], category: 'mythical'),
  AvatarDef(id: 75, name: 'Pegasus Wing',     emoji: '🦄',
      gradient: [Color(0xFFE0EAFC), Color(0xFFCFDEF3)], category: 'mythical'),
  AvatarDef(id: 76, name: 'Hydra Head',       emoji: '🐍',
      gradient: [Color(0xFF134E5E), Color(0xFF71B280)], category: 'mythical'),
  AvatarDef(id: 77, name: 'Sphinx Mystery',   emoji: '🐈',
      gradient: [Color(0xFFFFC371), Color(0xFFFF5F6D)], category: 'mythical'),
  AvatarDef(id: 78, name: 'Minotaur Strong',  emoji: '🐂',
      gradient: [Color(0xFF870000), Color(0xFF190A05)], category: 'mythical'),
  AvatarDef(id: 79, name: 'Garuda Sky',       emoji: '🦅',
      gradient: [Color(0xFFFF512F), Color(0xFFF09819)], category: 'mythical'),

  // ── ACTION / SPORTS (80-89) ──────────────────────────────
  AvatarDef(id: 80, name: 'Shadow Ninja',     emoji: '🥷',
      gradient: [Color(0xFF232526), Color(0xFF414345)], category: 'action'),
  AvatarDef(id: 81, name: 'Steel Samurai',    emoji: '🗡️',
      gradient: [Color(0xFF870000), Color(0xFF190A05)], category: 'action'),
  AvatarDef(id: 82, name: 'Knight Errant',    emoji: '🤺',
      gradient: [Color(0xFF485563), Color(0xFF29323C)], category: 'action'),
  AvatarDef(id: 83, name: 'Sea Pirate',       emoji: '🏴‍☠️',
      gradient: [Color(0xFF0F2027), Color(0xFF2C5364)], category: 'action'),
  AvatarDef(id: 84, name: 'Bow Archer',       emoji: '🏹',
      gradient: [Color(0xFF134E5E), Color(0xFF71B280)], category: 'action'),
  AvatarDef(id: 85, name: 'Sword Hero',       emoji: '⚔️',
      gradient: [Color(0xFF4568DC), Color(0xFFB06AB3)], category: 'action'),
  AvatarDef(id: 86, name: 'Mountain Climber', emoji: '🧗',
      gradient: [Color(0xFF8E9EAB), Color(0xFFEEF2F3)], category: 'action'),
  AvatarDef(id: 87, name: 'Snow Boarder',     emoji: '🏂',
      gradient: [Color(0xFF89F7FE), Color(0xFF66A6FF)], category: 'action'),
  AvatarDef(id: 88, name: 'Roller Skater',    emoji: '🛼',
      gradient: [Color(0xFFFF0099), Color(0xFF493240)], category: 'action'),
  AvatarDef(id: 89, name: 'Surf Rider',       emoji: '🏄',
      gradient: [Color(0xFF00B4DB), Color(0xFF0083B0)], category: 'action'),

  // ── COSMIC / NATURE (90-99) ──────────────────────────────
  AvatarDef(id: 90, name: 'Solar Flare',      emoji: '☀️',
      gradient: [Color(0xFFF7971E), Color(0xFFFFD200)], category: 'cosmic'),
  AvatarDef(id: 91, name: 'Lunar Eclipse',    emoji: '🌚',
      gradient: [Color(0xFF232526), Color(0xFF414345)], category: 'cosmic'),
  AvatarDef(id: 92, name: 'Star Twinkle',     emoji: '⭐',
      gradient: [Color(0xFF1E3C72), Color(0xFF2A5298)], category: 'cosmic'),
  AvatarDef(id: 93, name: 'Comet Trail',      emoji: '☄️',
      gradient: [Color(0xFFFC466B), Color(0xFF3F5EFB)], category: 'cosmic'),
  AvatarDef(id: 94, name: 'Aurora Light',     emoji: '🌌',
      gradient: [Color(0xFF8E2DE2), Color(0xFF4A00E0)], category: 'cosmic'),
  AvatarDef(id: 95, name: 'Volcano Heart',    emoji: '🌋',
      gradient: [Color(0xFFFF512F), Color(0xFFDD2476)], category: 'cosmic'),
  AvatarDef(id: 96, name: 'Ocean Wave',       emoji: '🌊',
      gradient: [Color(0xFF1A2980), Color(0xFF26D0CE)], category: 'cosmic'),
  AvatarDef(id: 97, name: 'Forest Spirit',    emoji: '🌲',
      gradient: [Color(0xFF134E5E), Color(0xFF71B280)], category: 'cosmic'),
  AvatarDef(id: 98, name: 'Desert Storm',     emoji: '🏜️',
      gradient: [Color(0xFFFFD89B), Color(0xFFEF8B6C)], category: 'cosmic'),
  AvatarDef(id: 99, name: 'Crystal Cave',     emoji: '💠',
      gradient: [Color(0xFF00C9FF), Color(0xFF92FE9D)], category: 'cosmic'),
];

/// Display names for category filter chips.
const Map<String, String> kAvatarCategoryLabels = {
  'all':      'All',
  'animals':  '🐾 Animals',
  'fantasy':  '✨ Fantasy',
  'sci_fi':   '🚀 Sci-Fi',
  'campus':   '🎓 Campus',
  'food':     '🍕 Foodie',
  'mythical': '🐉 Mythical',
  'action':   '⚔️ Action',
  'cosmic':   '🌌 Cosmic',
};

/// Look up an avatar by id with safe fallback.
AvatarDef avatarById(int? id) {
  if (id == null || id < 0 || id >= kAvatars.length) {
    return kAvatars[0];
  }
  return kAvatars[id];
}
