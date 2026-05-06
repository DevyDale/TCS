// lib/l10n/app_localizations.dart
// Full translation table for EN / MS / ZH / TA / AR
// Access via: AppL10n.of(context).key

import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────
// TRANSLATION MAP
// ─────────────────────────────────────────────────────────────
const _translations = {
  // ── Navigation ──────────────────────────────────────────
  'nav_feed':     {'en':'Feed',        'ms':'Suapan',     'zh':'动态',        'ta':'ஊட்டம்',     'ar':'الموجز'},
  'nav_groups':   {'en':'Groups',      'ms':'Kumpulan',   'zh':'群组',        'ta':'குழுக்கள்',  'ar':'المجموعات'},
  'nav_events':   {'en':'Events',      'ms':'Acara',      'zh':'活动',        'ta':'நிகழ்வுகள்', 'ar':'الفعاليات'},
  'nav_arcade':   {'en':'Arcade',      'ms':'Arkad',      'zh':'游戏厅',      'ta':'ஆர்கேட்',    'ar':'الألعاب'},
  'nav_chat':     {'en':'Chat',        'ms':'Chat',       'zh':'聊天',        'ta':'அரட்டை',    'ar':'الدردشة'},
  'nav_profile':  {'en':'Profile',     'ms':'Profil',     'zh':'我的',        'ta':'சுயவிவரம்', 'ar':'الملف'},
  'nav_settings': {'en':'Settings',    'ms':'Tetapan',    'zh':'设置',        'ta':'அமைப்புகள்','ar':'الإعدادات'},

  // ── Common ───────────────────────────────────────────────
  'btn_save':      {'en':'Save',       'ms':'Simpan',     'zh':'保存',        'ta':'சேமி',       'ar':'حفظ'},
  'btn_cancel':    {'en':'Cancel',     'ms':'Batal',      'zh':'取消',        'ta':'ரத்து',      'ar':'إلغاء'},
  'btn_close':     {'en':'Close',      'ms':'Tutup',      'zh':'关闭',        'ta':'மூடு',       'ar':'إغلاق'},
  'btn_confirm':   {'en':'Confirm',    'ms':'Sahkan',     'zh':'确认',        'ta':'உறுதி',      'ar':'تأكيد'},
  'btn_edit':      {'en':'Edit',       'ms':'Edit',       'zh':'编辑',        'ta':'திருத்து',   'ar':'تعديل'},
  'btn_delete':    {'en':'Delete',     'ms':'Padam',      'zh':'删除',        'ta':'நீக்கு',     'ar':'حذف'},
  'btn_follow':    {'en':'Follow',     'ms':'Ikuti',      'zh':'关注',        'ta':'பின்தொடர்',  'ar':'متابعة'},
  'btn_unfollow':  {'en':'Unfollow',   'ms':'Berhenti',   'zh':'取消关注',    'ta':'நிறுத்து',   'ar':'إلغاء المتابعة'},
  'btn_join':      {'en':'Join',       'ms':'Sertai',     'zh':'加入',        'ta':'சேரு',       'ar':'انضم'},
  'btn_leave':     {'en':'Leave',      'ms':'Keluar',     'zh':'退出',        'ta':'வெளியேறு',   'ar':'مغادرة'},
  'btn_send':      {'en':'Send',       'ms':'Hantar',     'zh':'发送',        'ta':'அனுப்பு',    'ar':'إرسال'},
  'btn_search':    {'en':'Search',     'ms':'Cari',       'zh':'搜索',        'ta':'தேடு',       'ar':'بحث'},
  'btn_create':    {'en':'Create',     'ms':'Cipta',      'zh':'创建',        'ta':'உருவாக்கு',  'ar':'إنشاء'},
  'btn_back':      {'en':'Back',       'ms':'Kembali',    'zh':'返回',        'ta':'திரும்பு',   'ar':'رجوع'},
  'btn_got_it':    {'en':'Got it',     'ms':'Faham',      'zh':'明白了',      'ta':'புரிந்தது',  'ar':'حسناً'},
  'lbl_loading':   {'en':'Loading...', 'ms':'Memuatkan...','zh':'加载中...',  'ta':'ஏற்றுகிறது...','ar':'جاري التحميل...'},
  'lbl_error':     {'en':'Something went wrong','ms':'Ralat berlaku','zh':'出错了','ta':'பிழை ஏற்பட்டது','ar':'حدث خطأ'},
  'lbl_no_results':{'en':'No results', 'ms':'Tiada keputusan','zh':'无结果',  'ta':'முடிவுகள் இல்லை','ar':'لا توجد نتائج'},

  // ── Feed ─────────────────────────────────────────────────
  'feed_title':       {'en':'Feed',            'ms':'Suapan',         'zh':'动态',           'ta':'ஊட்டம்',         'ar':'الموجز'},
  'feed_home':        {'en':'Home',            'ms':'Utama',          'zh':'首页',            'ta':'முகப்பு',         'ar':'الرئيسية'},
  'feed_following':   {'en':'Following',       'ms':'Mengikuti',      'zh':'关注中',          'ta':'பின்தொடர்வது',   'ar':'المتابَعون'},
  'feed_announcements':{'en':'Announcements',  'ms':'Pengumuman',     'zh':'公告',            'ta':'அறிவிப்புகள்',   'ar':'الإعلانات'},
  'feed_whats_on':    {'en':'What\'s on your mind?','ms':'Apa pendapat anda?','zh':'说点什么吧...','ta':'என்ன நினைக்கிறீர்கள்?','ar':'ما الذي يدور في ذهنك؟'},
  'feed_no_posts':    {'en':'No posts yet',    'ms':'Tiada catatan',  'zh':'还没有帖子',      'ta':'இடுகைகள் இல்லை', 'ar':'لا توجد منشورات'},
  'feed_like':        {'en':'Like',            'ms':'Suka',           'zh':'赞',              'ta':'விரும்பு',        'ar':'إعجاب'},
  'feed_comment':     {'en':'Comment',         'ms':'Komen',          'zh':'评论',            'ta':'கருத்து',         'ar':'تعليق'},
  'feed_share':       {'en':'Share',           'ms':'Kongsi',         'zh':'分享',            'ta':'பகிர்',           'ar':'مشاركة'},
  'feed_bookmark':    {'en':'Bookmark',        'ms':'Tandakan',       'zh':'收藏',            'ta':'புக்மார்க்',      'ar':'حفظ'},

  // ── Groups ───────────────────────────────────────────────
  'groups_title':     {'en':'Groups',          'ms':'Kumpulan',       'zh':'群组',            'ta':'குழுக்கள்',       'ar':'المجموعات'},
  'groups_my':        {'en':'My Groups',       'ms':'Kumpulan Saya',  'zh':'我的群组',        'ta':'என் குழுக்கள்',   'ar':'مجموعاتي'},
  'groups_discover':  {'en':'Discover',        'ms':'Terokai',        'zh':'发现',            'ta':'கண்டுபிடி',       'ar':'اكتشاف'},
  'groups_create':    {'en':'Create Group',    'ms':'Cipta Kumpulan', 'zh':'创建群组',        'ta':'குழு உருவாக்கு',  'ar':'إنشاء مجموعة'},
  'groups_members':   {'en':'members',         'ms':'ahli',           'zh':'成员',            'ta':'உறுப்பினர்கள்',   'ar':'عضو'},
  'groups_study_hub': {'en':'Study Hub',       'ms':'Hab Belajar',    'zh':'学习中心',        'ta':'படிப்பு மையம்',   'ar':'مركز الدراسة'},

  // ── Events ───────────────────────────────────────────────
  'events_title':     {'en':'Events',          'ms':'Acara',          'zh':'活动',            'ta':'நிகழ்வுகள்',      'ar':'الفعاليات'},
  'events_upcoming':  {'en':'Upcoming',        'ms':'Akan Datang',    'zh':'即将举行',        'ta':'வரவிருக்கும்',    'ar':'القادمة'},
  'events_past':      {'en':'Past',            'ms':'Lepas',          'zh':'已结束',          'ta':'கடந்த',           'ar':'السابقة'},
  'events_rsvp':      {'en':'RSVP',            'ms':'Daftar',         'zh':'报名',            'ta':'பதிவு செய்',      'ar':'تسجيل'},
  'events_attending': {'en':'Attending',       'ms':'Menghadiri',     'zh':'已报名',          'ta':'கலந்துகொள்கிறேன்','ar':'حاضر'},
  'events_no_events': {'en':'No events yet',   'ms':'Tiada acara',    'zh':'暂无活动',        'ta':'நிகழ்வுகள் இல்லை','ar':'لا توجد فعاليات'},

  // ── Arcade ───────────────────────────────────────────────
  'arcade_title':      {'en':'Arcade',         'ms':'Arkad',          'zh':'游戏厅',          'ta':'ஆர்கேட்',         'ar':'الألعاب'},
  'arcade_play':       {'en':'Play',           'ms':'Main',           'zh':'开始游戏',        'ta':'விளையாடு',        'ar':'العب'},
  'arcade_leaderboard':{'en':'Leaderboard',    'ms':'Papan Markah',   'zh':'排行榜',          'ta':'தரவரிசை',         'ar':'لوحة المتصدرين'},
  'arcade_tokens':     {'en':'Tokens',         'ms':'Token',          'zh':'代币',            'ta':'டோக்கன்கள்',      'ar':'الرموز'},
  'arcade_challenges': {'en':'Challenges',     'ms':'Cabaran',        'zh':'挑战',            'ta':'சவால்கள்',        'ar':'التحديات'},
  'arcade_gamer_tag':  {'en':'Gamer Tag',      'ms':'Tag Gamer',      'zh':'玩家标签',        'ta':'கேமர் டேக்',       'ar':'علامة اللاعب'},
  'arcade_my_games':   {'en':'My Games',       'ms':'Permainan Saya', 'zh':'我的游戏',        'ta':'என் விளையாட்டுகள்','ar':'ألعابي'},

  // ── Chat ─────────────────────────────────────────────────
  'chat_title':        {'en':'Messages',       'ms':'Mesej',          'zh':'消息',            'ta':'செய்திகள்',        'ar':'الرسائل'},
  'chat_new':          {'en':'New Chat',       'ms':'Chat Baru',      'zh':'新聊天',          'ta':'புதிய அரட்டை',    'ar':'دردشة جديدة'},
  'chat_type_msg':     {'en':'Type a message...','ms':'Taip mesej...','zh':'输入消息...',     'ta':'செய்தி தட்டச்சு செய்...','ar':'اكتب رسالة...'},
  'chat_no_messages':  {'en':'No messages yet','ms':'Tiada mesej',    'zh':'暂无消息',        'ta':'செய்திகள் இல்லை', 'ar':'لا توجد رسائل'},
  'chat_saved':        {'en':'Saved Materials','ms':'Bahan Disimpan', 'zh':'已保存资料',      'ta':'சேமித்த பொருட்கள்','ar':'المواد المحفوظة'},

  // ── Profile ──────────────────────────────────────────────
  'profile_posts':     {'en':'Posts',          'ms':'Catatan',        'zh':'帖子',            'ta':'இடுகைகள்',        'ar':'المنشورات'},
  'profile_followers': {'en':'Followers',      'ms':'Pengikut',       'zh':'粉丝',            'ta':'பின்தொடர்பவர்கள்','ar':'المتابعون'},
  'profile_following': {'en':'Following',      'ms':'Mengikuti',      'zh':'关注',            'ta':'பின்தொடர்வது',    'ar':'يتابع'},
  'profile_activity':  {'en':'Activity',       'ms':'Aktiviti',       'zh':'活动',            'ta':'செயல்பாடு',       'ar':'النشاط'},
  'profile_fweets':    {'en':'Fweets',         'ms':'Fweets',         'zh':'推文',            'ta':'ஃப்வீட்ஸ்',       'ar':'فويتس'},
  'profile_add_bio':   {'en':'Add Bio',        'ms':'Tambah Bio',     'zh':'添加简介',        'ta':'கதை சேர்',         'ar':'إضافة نبذة'},
  'profile_edit_bio':  {'en':'Edit Bio',       'ms':'Edit Bio',       'zh':'编辑简介',        'ta':'திருத்து',         'ar':'تعديل النبذة'},
  'profile_interests': {'en':'Interests',      'ms':'Minat',          'zh':'兴趣',            'ta':'ஆர்வங்கள்',        'ar':'الاهتمامات'},
  'profile_no_posts':  {'en':'No Posts Yet',   'ms':'Tiada Catatan',  'zh':'还没有帖子',      'ta':'இடுகைகள் இல்லை',  'ar':'لا توجد منشورات'},
  'profile_create_post':{'en':'Create First Post','ms':'Cipta Catatan Pertama','zh':'创建第一篇帖子','ta':'முதல் இடுகை உருவாக்கு','ar':'أنشئ أول منشور'},

  // ── Settings ─────────────────────────────────────────────
  'settings_title':        {'en':'Settings',           'ms':'Tetapan',              'zh':'设置',              'ta':'அமைப்புகள்',          'ar':'الإعدادات'},
  'settings_appearance':   {'en':'APPEARANCE',          'ms':'PENAMPILAN',           'zh':'外观',              'ta':'தோற்றம்',             'ar':'المظهر'},
  'settings_language':     {'en':'LANGUAGE',            'ms':'BAHASA',               'zh':'语言',              'ta':'மொழி',                'ar':'اللغة'},
  'settings_notifications':{'en':'NOTIFICATIONS',       'ms':'PEMBERITAHUAN',        'zh':'通知',              'ta':'அறிவிப்புகள்',        'ar':'الإشعارات'},
  'settings_privacy':      {'en':'PRIVACY',             'ms':'PRIVASI',              'zh':'隐私',              'ta':'தனியுரிமை',            'ar':'الخصوصية'},
  'settings_about':        {'en':'ABOUT',               'ms':'TENTANG',              'zh':'关于',              'ta':'பற்றி',                'ar':'عن التطبيق'},
  'settings_dark_mode':    {'en':'Dark Mode',           'ms':'Mod Gelap',            'zh':'深色模式',           'ta':'இருண்ட முறை',          'ar':'الوضع الداكن'},
  'settings_dark_on':      {'en':'Dark theme active',  'ms':'Tema gelap aktif',     'zh':'深色主题已启用',     'ta':'இருண்ட தீம் செயலில்', 'ar':'الوضع الداكن مُفعّل'},
  'settings_dark_off':     {'en':'Light theme active', 'ms':'Tema cerah aktif',     'zh':'浅色主题已启用',     'ta':'ஒளி தீம் செயலில்',    'ar':'الوضع الفاتح مُفعّل'},
  'settings_lang_label':   {'en':'Language',           'ms':'Bahasa',               'zh':'语言',              'ta':'மொழி',                'ar':'اللغة'},
  'settings_push':         {'en':'Push Notifications', 'ms':'Pemberitahuan Tolak',  'zh':'推送通知',           'ta':'புஷ் அறிவிப்புகள்',   'ar':'الإشعارات الفورية'},
  'settings_push_on':      {'en':'All notifications on','ms':'Semua pemberitahuan hidup','zh':'所有通知已开启', 'ta':'அனைத்து அறிவிப்புகளும் இயக்கப்பட்டன','ar':'كل الإشعارات مُفعَّلة'},
  'settings_push_off':     {'en':'All notifications off','ms':'Semua pemberitahuan mati','zh':'所有通知已关闭', 'ta':'அனைத்து அறிவிப்புகளும் அணைக்கப்பட்டன','ar':'كل الإشعارات مُعطَّلة'},
  'settings_announcements':{'en':'Announcements',      'ms':'Pengumuman',           'zh':'公告',              'ta':'அறிவிப்புகள்',         'ar':'الإعلانات'},
  'settings_campus_ann':   {'en':'Campus-wide announcements','ms':'Pengumuman kampus','zh':'校园公告',         'ta':'வளாக அறிவிப்புகள்',   'ar':'إعلانات الحرم الجامعي'},
  'settings_group_act':    {'en':'Group Activity',     'ms':'Aktiviti Kumpulan',    'zh':'群组动态',           'ta':'குழு செயல்பாடு',       'ar':'نشاط المجموعة'},
  'settings_group_sub':    {'en':'New posts in your groups','ms':'Catatan baru dalam kumpulan','zh':'群组中的新帖子','ta':'குழுக்களில் புதிய இடுகைகள்','ar':'منشورات جديدة في مجموعاتك'},
  'settings_online':       {'en':'Show Online Status', 'ms':'Tunjuk Status Dalam Talian','zh':'显示在线状态',   'ta':'ஆன்லைன் நிலை காட்டு', 'ar':'إظهار حالة الاتصال'},
  'settings_online_on':    {'en':'Others can see when you\'re active','ms':'Orang lain boleh lihat status anda','zh':'其他人可以看到你的在线状态','ta':'மற்றவர்கள் உங்கள் நிலையை பார்க்கலாம்','ar':'يمكن للآخرين رؤية حالتك'},
  'settings_online_off':   {'en':'You appear offline','ms':'Anda kelihatan luar talian','zh':'你显示为离线',    'ta':'நீங்கள் ஆஃப்லைனாக தெரிகிறீர்கள்','ar':'تظهر غير متصل'},
  'settings_discoverable': {'en':'Discoverable',       'ms':'Boleh Dijumpai',       'zh':'可被发现',           'ta':'கண்டுபிடிக்கக்கூடியது','ar':'قابل للاكتشاف'},
  'settings_disc_on':      {'en':'You appear in search results','ms':'Anda muncul dalam carian','zh':'你出现在搜索结果中','ta':'நீங்கள் தேடல் முடிவுகளில் தெரிகிறீர்கள்','ar':'تظهر في نتائج البحث'},
  'settings_disc_off':     {'en':'Hidden from search', 'ms':'Tersembunyi dari carian','zh':'对搜索隐藏',        'ta':'தேடலில் இருந்து மறைக்கப்பட்டது','ar':'مخفي من البحث'},
  'settings_version':      {'en':'Version',            'ms':'Versi',                'zh':'版本',              'ta':'பதிப்பு',              'ar':'الإصدار'},
  'settings_institution':  {'en':'Institution',        'ms':'Institusi',            'zh':'学校',              'ta':'நிறுவனம்',             'ar':'المؤسسة'},
  'settings_terms':        {'en':'Terms of Service',   'ms':'Terma Perkhidmatan',   'zh':'服务条款',           'ta':'சேவை விதிமுறைகள்',    'ar':'شروط الخدمة'},
  'settings_privacy_pol':  {'en':'Privacy Policy',     'ms':'Dasar Privasi',        'zh':'隐私政策',           'ta':'தனியுரிமைக் கொள்கை',  'ar':'سياسة الخصوصية'},
  'settings_support':      {'en':'Support',            'ms':'Sokongan',             'zh':'支持',              'ta':'ஆதரவு',               'ar':'الدعم'},
  'settings_view':         {'en':'View ›',             'ms':'Lihat ›',              'zh':'查看 ›',             'ta':'பார் ›',               'ar':'عرض ›'},
};

// ─────────────────────────────────────────────────────────────
// LOCALIZATION CLASS — used throughout the app
// ─────────────────────────────────────────────────────────────

class AppL10n {
  final String languageCode;
  const AppL10n(this.languageCode);

  /// Get a translated string. Falls back to English if key/lang missing.
  String t(String key) {
    final map = _translations[key];
    if (map == null) return key;
    return map[languageCode] ?? map['en'] ?? key;
  }

  static AppL10n of(BuildContext context) {
    final inherited = context
        .dependOnInheritedWidgetOfExactType<_AppL10nInherited>();
    return inherited?.l10n ?? const AppL10n('en');
  }

  // ── Convenience getters ───────────────────────────────────
  String get navFeed           => t('nav_feed');
  String get navGroups         => t('nav_groups');
  String get navEvents         => t('nav_events');
  String get navArcade         => t('nav_arcade');
  String get navChat           => t('nav_chat');
  String get navProfile        => t('nav_profile');
  String get navSettings       => t('nav_settings');

  String get btnSave           => t('btn_save');
  String get btnCancel         => t('btn_cancel');
  String get btnClose          => t('btn_close');
  String get btnBack           => t('btn_back');
  String get btnGotIt          => t('btn_got_it');
  String get btnCreate         => t('btn_create');
  String get btnSearch         => t('btn_search');
  String get btnFollow         => t('btn_follow');
  String get btnJoin           => t('btn_join');
  String get btnLeave          => t('btn_leave');
  String get btnSend           => t('btn_send');
  String get lblLoading        => t('lbl_loading');
  String get lblError          => t('lbl_error');

  String get feedTitle         => t('feed_title');
  String get feedHome          => t('feed_home');
  String get feedFollowing     => t('feed_following');
  String get feedAnnouncements => t('feed_announcements');
  String get feedWhatsOnMind   => t('feed_whats_on');
  String get feedNoPosts       => t('feed_no_posts');
  String get feedLike          => t('feed_like');
  String get feedComment       => t('feed_comment');
  String get feedShare         => t('feed_share');
  String get feedBookmark      => t('feed_bookmark');

  String get groupsTitle       => t('groups_title');
  String get groupsMy          => t('groups_my');
  String get groupsDiscover    => t('groups_discover');
  String get groupsCreate      => t('groups_create');
  String get groupsStudyHub    => t('groups_study_hub');

  String get eventsTitle       => t('events_title');
  String get eventsUpcoming    => t('events_upcoming');
  String get eventsPast        => t('events_past');
  String get eventsRsvp        => t('events_rsvp');
  String get eventsAttending   => t('events_attending');
  String get eventsNone        => t('events_no_events');

  String get arcadeTitle       => t('arcade_title');
  String get arcadePlay        => t('arcade_play');
  String get arcadeLeaderboard => t('arcade_leaderboard');
  String get arcadeTokens      => t('arcade_tokens');
  String get arcadeChallenges  => t('arcade_challenges');
  String get arcadeGamerTag    => t('arcade_gamer_tag');

  String get chatTitle         => t('chat_title');
  String get chatNew           => t('chat_new');
  String get chatTypeMsg       => t('chat_type_msg');
  String get chatNone          => t('chat_no_messages');
  String get chatSaved         => t('chat_saved');

  String get profilePosts      => t('profile_posts');
  String get profileFollowers  => t('profile_followers');
  String get profileFollowing  => t('profile_following');
  String get profileActivity   => t('profile_activity');
  String get profileFweets     => t('profile_fweets');
  String get profileAddBio     => t('profile_add_bio');
  String get profileEditBio    => t('profile_edit_bio');
  String get profileInterests  => t('profile_interests');
  String get profileNoPosts    => t('profile_no_posts');
  String get profileCreatePost => t('profile_create_post');

  String get settingsTitle          => t('settings_title');
  String get settingsAppearance     => t('settings_appearance');
  String get settingsLanguage       => t('settings_language');
  String get settingsNotifications  => t('settings_notifications');
  String get settingsPrivacy        => t('settings_privacy');
  String get settingsAbout          => t('settings_about');
  String get settingsDarkMode       => t('settings_dark_mode');
  String get settingsDarkOn         => t('settings_dark_on');
  String get settingsDarkOff        => t('settings_dark_off');
  String get settingsPush           => t('settings_push');
  String get settingsPushOn         => t('settings_push_on');
  String get settingsPushOff        => t('settings_push_off');
  String get settingsAnnouncements  => t('settings_announcements');
  String get settingsCampusAnn      => t('settings_campus_ann');
  String get settingsGroupAct       => t('settings_group_act');
  String get settingsGroupSub       => t('settings_group_sub');
  String get settingsOnline         => t('settings_online');
  String get settingsOnlineOn       => t('settings_online_on');
  String get settingsOnlineOff      => t('settings_online_off');
  String get settingsDiscoverable   => t('settings_discoverable');
  String get settingsDiscOn         => t('settings_disc_on');
  String get settingsDiscOff        => t('settings_disc_off');
  String get settingsLangLabel      => t('settings_lang_label');
  String get settingsVersion        => t('settings_version');
  String get settingsInstitution    => t('settings_institution');
  String get settingsTerms          => t('settings_terms');
  String get settingsPrivacyPol     => t('settings_privacy_pol');
  String get settingsSupport        => t('settings_support');
  String get settingsView           => t('settings_view');
}

// ─────────────────────────────────────────────────────────────
// INHERITED WIDGET — put at MaterialApp root
// ─────────────────────────────────────────────────────────────

class _AppL10nInherited extends InheritedWidget {
  final AppL10n l10n;
  const _AppL10nInherited({required this.l10n, required super.child});

  @override
  bool updateShouldNotify(_AppL10nInherited old) =>
      l10n.languageCode != old.l10n.languageCode;
}

class AppL10nProvider extends StatelessWidget {
  final String languageCode;
  final Widget child;
  const AppL10nProvider(
      {super.key, required this.languageCode, required this.child});

  @override
  Widget build(BuildContext context) => _AppL10nInherited(
        l10n: AppL10n(languageCode),
        child: child,
      );
}