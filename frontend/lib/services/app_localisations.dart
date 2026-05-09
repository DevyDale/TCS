// lib/services/app_localisations.dart
// Translations for EN / MS / ZH / JA / KO / AR
// Access via: AppL10n.of(context).key

import 'package:flutter/material.dart';

const _translations = {
  // ── Navigation ──────────────────────────────────────────
  'nav_feed':     {'en':'Feed','ms':'Suapan','zh':'动态','ja':'フィード','ko':'피드','ar':'الموجز'},
  'nav_groups':   {'en':'Groups','ms':'Kumpulan','zh':'群组','ja':'グループ','ko':'그룹','ar':'المجموعات'},
  'nav_events':   {'en':'Events','ms':'Acara','zh':'活动','ja':'イベント','ko':'이벤트','ar':'الفعاليات'},
  'nav_arcade':   {'en':'Arcade','ms':'Arkad','zh':'游戏厅','ja':'アーケード','ko':'아케이드','ar':'الألعاب'},
  'nav_chat':     {'en':'Chat','ms':'Chat','zh':'聊天','ja':'チャット','ko':'채팅','ar':'الدردشة'},
  'nav_profile':  {'en':'Profile','ms':'Profil','zh':'我的','ja':'プロフィール','ko':'프로필','ar':'الملف'},
  'nav_settings': {'en':'Settings','ms':'Tetapan','zh':'设置','ja':'設定','ko':'설정','ar':'الإعدادات'},

  // ── Common ───────────────────────────────────────────────
  'btn_save':      {'en':'Save','ms':'Simpan','zh':'保存','ja':'保存','ko':'저장','ar':'حفظ'},
  'btn_cancel':    {'en':'Cancel','ms':'Batal','zh':'取消','ja':'キャンセル','ko':'취소','ar':'إلغاء'},
  'btn_close':     {'en':'Close','ms':'Tutup','zh':'关闭','ja':'閉じる','ko':'닫기','ar':'إغلاق'},
  'btn_confirm':   {'en':'Confirm','ms':'Sahkan','zh':'确认','ja':'確認','ko':'확인','ar':'تأكيد'},
  'btn_edit':      {'en':'Edit','ms':'Edit','zh':'编辑','ja':'編集','ko':'편집','ar':'تعديل'},
  'btn_delete':    {'en':'Delete','ms':'Padam','zh':'删除','ja':'削除','ko':'삭제','ar':'حذف'},
  'btn_follow':    {'en':'Follow','ms':'Ikuti','zh':'关注','ja':'フォロー','ko':'팔로우','ar':'متابعة'},
  'btn_unfollow':  {'en':'Unfollow','ms':'Berhenti','zh':'取消关注','ja':'フォロー解除','ko':'언팔로우','ar':'إلغاء المتابعة'},
  'btn_join':      {'en':'Join','ms':'Sertai','zh':'加入','ja':'参加','ko':'참여','ar':'انضم'},
  'btn_leave':     {'en':'Leave','ms':'Keluar','zh':'退出','ja':'退出','ko':'나가기','ar':'مغادرة'},
  'btn_send':      {'en':'Send','ms':'Hantar','zh':'发送','ja':'送信','ko':'보내기','ar':'إرسال'},
  'btn_search':    {'en':'Search','ms':'Cari','zh':'搜索','ja':'検索','ko':'검색','ar':'بحث'},
  'btn_create':    {'en':'Create','ms':'Cipta','zh':'创建','ja':'作成','ko':'만들기','ar':'إنشاء'},
  'btn_back':      {'en':'Back','ms':'Kembali','zh':'返回','ja':'戻る','ko':'뒤로','ar':'رجوع'},
  'btn_got_it':    {'en':'Got it','ms':'Faham','zh':'明白了','ja':'了解','ko':'확인','ar':'حسناً'},
  'lbl_loading':   {'en':'Loading...','ms':'Memuatkan...','zh':'加载中...','ja':'読み込み中...','ko':'로딩 중...','ar':'جاري التحميل...'},
  'lbl_error':     {'en':'Something went wrong','ms':'Ralat berlaku','zh':'出错了','ja':'エラーが発生しました','ko':'오류가 발생했습니다','ar':'حدث خطأ'},
  'lbl_no_results':{'en':'No results','ms':'Tiada keputusan','zh':'无结果','ja':'結果がありません','ko':'결과 없음','ar':'لا توجد نتائج'},

  // ── Feed ─────────────────────────────────────────────────
  'feed_title':       {'en':'Feed','ms':'Suapan','zh':'动态','ja':'フィード','ko':'피드','ar':'الموجز'},
  'feed_home':        {'en':'Home','ms':'Utama','zh':'首页','ja':'ホーム','ko':'홈','ar':'الرئيسية'},
  'feed_following':   {'en':'Following','ms':'Mengikuti','zh':'关注中','ja':'フォロー中','ko':'팔로잉','ar':'المتابَعون'},
  'feed_announcements':{'en':'Announcements','ms':'Pengumuman','zh':'公告','ja':'お知らせ','ko':'공지사항','ar':'الإعلانات'},
  'feed_whats_on':    {'en':'What\'s on your mind?','ms':'Apa pendapat anda?','zh':'说点什么吧...','ja':'何を考えていますか?','ko':'무슨 생각을 하고 있나요?','ar':'ما الذي يدور في ذهنك؟'},
  'feed_no_posts':    {'en':'No posts yet','ms':'Tiada catatan','zh':'还没有帖子','ja':'投稿がありません','ko':'게시물 없음','ar':'لا توجد منشورات'},
  'feed_like':        {'en':'Like','ms':'Suka','zh':'赞','ja':'いいね','ko':'좋아요','ar':'إعجاب'},
  'feed_comment':     {'en':'Comment','ms':'Komen','zh':'评论','ja':'コメント','ko':'댓글','ar':'تعليق'},
  'feed_share':       {'en':'Share','ms':'Kongsi','zh':'分享','ja':'シェア','ko':'공유','ar':'مشاركة'},
  'feed_bookmark':    {'en':'Bookmark','ms':'Tandakan','zh':'收藏','ja':'ブックマーク','ko':'북마크','ar':'حفظ'},

  // ── Groups ───────────────────────────────────────────────
  'groups_title':     {'en':'Groups','ms':'Kumpulan','zh':'群组','ja':'グループ','ko':'그룹','ar':'المجموعات'},
  'groups_my':        {'en':'My Groups','ms':'Kumpulan Saya','zh':'我的群组','ja':'マイグループ','ko':'내 그룹','ar':'مجموعاتي'},
  'groups_discover':  {'en':'Discover','ms':'Terokai','zh':'发现','ja':'見つける','ko':'둘러보기','ar':'اكتشاف'},
  'groups_create':    {'en':'Create Group','ms':'Cipta Kumpulan','zh':'创建群组','ja':'グループ作成','ko':'그룹 만들기','ar':'إنشاء مجموعة'},
  'groups_members':   {'en':'members','ms':'ahli','zh':'成员','ja':'メンバー','ko':'멤버','ar':'عضو'},
  'groups_study_hub': {'en':'Study Hub','ms':'Hab Belajar','zh':'学习中心','ja':'学習ハブ','ko':'스터디 허브','ar':'مركز الدراسة'},

  // ── Events ───────────────────────────────────────────────
  'events_title':     {'en':'Events','ms':'Acara','zh':'活动','ja':'イベント','ko':'이벤트','ar':'الفعاليات'},
  'events_upcoming':  {'en':'Upcoming','ms':'Akan Datang','zh':'即将举行','ja':'今後の予定','ko':'예정','ar':'القادمة'},
  'events_past':      {'en':'Past','ms':'Lepas','zh':'已结束','ja':'過去','ko':'지난','ar':'السابقة'},
  'events_rsvp':      {'en':'RSVP','ms':'Daftar','zh':'报名','ja':'参加登録','ko':'참가 신청','ar':'تسجيل'},
  'events_attending': {'en':'Attending','ms':'Menghadiri','zh':'已报名','ja':'参加予定','ko':'참석 예정','ar':'حاضر'},
  'events_no_events': {'en':'No events yet','ms':'Tiada acara','zh':'暂无活动','ja':'イベントはありません','ko':'이벤트 없음','ar':'لا توجد فعاليات'},

  // ── Arcade ───────────────────────────────────────────────
  'arcade_title':      {'en':'Arcade','ms':'Arkad','zh':'游戏厅','ja':'アーケード','ko':'아케이드','ar':'الألعاب'},
  'arcade_play':       {'en':'Play','ms':'Main','zh':'开始游戏','ja':'プレイ','ko':'플레이','ar':'العب'},
  'arcade_leaderboard':{'en':'Leaderboard','ms':'Papan Markah','zh':'排行榜','ja':'リーダーボード','ko':'리더보드','ar':'لوحة المتصدرين'},
  'arcade_tokens':     {'en':'Tokens','ms':'Token','zh':'代币','ja':'トークン','ko':'토큰','ar':'الرموز'},
  'arcade_challenges': {'en':'Challenges','ms':'Cabaran','zh':'挑战','ja':'チャレンジ','ko':'도전과제','ar':'التحديات'},
  'arcade_gamer_tag':  {'en':'Gamer Tag','ms':'Tag Gamer','zh':'玩家标签','ja':'ゲーマータグ','ko':'게이머 태그','ar':'علامة اللاعب'},
  'arcade_my_games':   {'en':'My Games','ms':'Permainan Saya','zh':'我的游戏','ja':'マイゲーム','ko':'내 게임','ar':'ألعابي'},

  // ── Chat ─────────────────────────────────────────────────
  'chat_title':        {'en':'Messages','ms':'Mesej','zh':'消息','ja':'メッセージ','ko':'메시지','ar':'الرسائل'},
  'chat_new':          {'en':'New Chat','ms':'Chat Baru','zh':'新聊天','ja':'新規チャット','ko':'새 채팅','ar':'دردشة جديدة'},
  'chat_type_msg':     {'en':'Type a message...','ms':'Taip mesej...','zh':'输入消息...','ja':'メッセージを入力...','ko':'메시지 입력...','ar':'اكتب رسالة...'},
  'chat_no_messages':  {'en':'No messages yet','ms':'Tiada mesej','zh':'暂无消息','ja':'メッセージはありません','ko':'메시지 없음','ar':'لا توجد رسائل'},
  'chat_saved':        {'en':'Saved Materials','ms':'Bahan Disimpan','zh':'已保存资料','ja':'保存済み資料','ko':'저장된 자료','ar':'المواد المحفوظة'},

  // ── Profile ──────────────────────────────────────────────
  'profile_posts':     {'en':'Posts','ms':'Catatan','zh':'帖子','ja':'投稿','ko':'게시물','ar':'المنشورات'},
  'profile_followers': {'en':'Followers','ms':'Pengikut','zh':'粉丝','ja':'フォロワー','ko':'팔로워','ar':'المتابعون'},
  'profile_following': {'en':'Following','ms':'Mengikuti','zh':'关注','ja':'フォロー中','ko':'팔로잉','ar':'يتابع'},
  'profile_activity':  {'en':'Activity','ms':'Aktiviti','zh':'活动','ja':'アクティビティ','ko':'활동','ar':'النشاط'},
  'profile_fweets':    {'en':'Fweets','ms':'Fweets','zh':'推文','ja':'フウィート','ko':'프윗','ar':'فويتس'},
  'profile_add_bio':   {'en':'Add Bio','ms':'Tambah Bio','zh':'添加简介','ja':'自己紹介を追加','ko':'소개 추가','ar':'إضافة نبذة'},
  'profile_edit_bio':  {'en':'Edit Bio','ms':'Edit Bio','zh':'编辑简介','ja':'自己紹介を編集','ko':'소개 편집','ar':'تعديل النبذة'},
  'profile_interests': {'en':'Interests','ms':'Minat','zh':'兴趣','ja':'興味','ko':'관심사','ar':'الاهتمامات'},
  'profile_no_posts':  {'en':'No Posts Yet','ms':'Tiada Catatan','zh':'还没有帖子','ja':'投稿がありません','ko':'게시물 없음','ar':'لا توجد منشورات'},
  'profile_create_post':{'en':'Create First Post','ms':'Cipta Catatan Pertama','zh':'创建第一篇帖子','ja':'最初の投稿を作成','ko':'첫 게시물 만들기','ar':'أنشئ أول منشور'},

  // ── Settings ─────────────────────────────────────────────
  'settings_title':        {'en':'Settings','ms':'Tetapan','zh':'设置','ja':'設定','ko':'설정','ar':'الإعدادات'},
  'settings_appearance':   {'en':'APPEARANCE','ms':'PENAMPILAN','zh':'外观','ja':'外観','ko':'화면','ar':'المظهر'},
  'settings_language':     {'en':'LANGUAGE','ms':'BAHASA','zh':'语言','ja':'言語','ko':'언어','ar':'اللغة'},
  'settings_notifications':{'en':'NOTIFICATIONS','ms':'PEMBERITAHUAN','zh':'通知','ja':'通知','ko':'알림','ar':'الإشعارات'},
  'settings_privacy':      {'en':'PRIVACY','ms':'PRIVASI','zh':'隐私','ja':'プライバシー','ko':'개인정보','ar':'الخصوصية'},
  'settings_about':        {'en':'ABOUT','ms':'TENTANG','zh':'关于','ja':'情報','ko':'정보','ar':'عن التطبيق'},
  'settings_dark_mode':    {'en':'Dark Mode','ms':'Mod Gelap','zh':'深色模式','ja':'ダークモード','ko':'다크 모드','ar':'الوضع الداكن'},
  'settings_dark_on':      {'en':'Dark theme active','ms':'Tema gelap aktif','zh':'深色主题已启用','ja':'ダークテーマ有効','ko':'다크 테마 활성','ar':'الوضع الداكن مُفعّل'},
  'settings_dark_off':     {'en':'Light theme active','ms':'Tema cerah aktif','zh':'浅色主题已启用','ja':'ライトテーマ有効','ko':'라이트 테마 활성','ar':'الوضع الفاتح مُفعّل'},
  'settings_lang_label':   {'en':'Language','ms':'Bahasa','zh':'语言','ja':'言語','ko':'언어','ar':'اللغة'},
  'settings_push':         {'en':'Push Notifications','ms':'Pemberitahuan Tolak','zh':'推送通知','ja':'プッシュ通知','ko':'푸시 알림','ar':'الإشعارات الفورية'},
  'settings_push_on':      {'en':'All notifications on','ms':'Semua pemberitahuan hidup','zh':'所有通知已开启','ja':'すべての通知が有効','ko':'모든 알림 활성','ar':'كل الإشعارات مُفعَّلة'},
  'settings_push_off':     {'en':'All notifications off','ms':'Semua pemberitahuan mati','zh':'所有通知已关闭','ja':'すべての通知が無効','ko':'모든 알림 비활성','ar':'كل الإشعارات مُعطَّلة'},
  'settings_announcements':{'en':'Announcements','ms':'Pengumuman','zh':'公告','ja':'お知らせ','ko':'공지사항','ar':'الإعلانات'},
  'settings_campus_ann':   {'en':'Campus-wide announcements','ms':'Pengumuman kampus','zh':'校园公告','ja':'キャンパス全体のお知らせ','ko':'캠퍼스 전체 공지','ar':'إعلانات الحرم الجامعي'},
  'settings_group_act':    {'en':'Group Activity','ms':'Aktiviti Kumpulan','zh':'群组动态','ja':'グループ活動','ko':'그룹 활동','ar':'نشاط المجموعة'},
  'settings_group_sub':    {'en':'New posts in your groups','ms':'Catatan baru dalam kumpulan','zh':'群组中的新帖子','ja':'グループの新しい投稿','ko':'그룹의 새 게시물','ar':'منشورات جديدة في مجموعاتك'},
  'settings_online':       {'en':'Show Online Status','ms':'Tunjuk Status Dalam Talian','zh':'显示在线状态','ja':'オンライン状態を表示','ko':'온라인 상태 표시','ar':'إظهار حالة الاتصال'},
  'settings_online_on':    {'en':'Others can see when you\'re active','ms':'Orang lain boleh lihat status anda','zh':'其他人可以看到你的在线状态','ja':'他の人があなたの状態を見られます','ko':'다른 사람이 내 상태를 볼 수 있음','ar':'يمكن للآخرين رؤية حالتك'},
  'settings_online_off':   {'en':'You appear offline','ms':'Anda kelihatan luar talian','zh':'你显示为离线','ja':'オフラインとして表示','ko':'오프라인으로 표시','ar':'تظهر غير متصل'},
  'settings_discoverable': {'en':'Discoverable','ms':'Boleh Dijumpai','zh':'可被发现','ja':'検索可能','ko':'검색 가능','ar':'قابل للاكتشاف'},
  'settings_disc_on':      {'en':'You appear in search results','ms':'Anda muncul dalam carian','zh':'你出现在搜索结果中','ja':'検索結果に表示されます','ko':'검색 결과에 표시','ar':'تظهر في نتائج البحث'},
  'settings_disc_off':     {'en':'Hidden from search','ms':'Tersembunyi dari carian','zh':'对搜索隐藏','ja':'検索から非表示','ko':'검색에서 숨김','ar':'مخفي من البحث'},
  'settings_version':      {'en':'Version','ms':'Versi','zh':'版本','ja':'バージョン','ko':'버전','ar':'الإصدار'},
  'settings_institution':  {'en':'Institution','ms':'Institusi','zh':'学校','ja':'機関','ko':'기관','ar':'المؤسسة'},
  'settings_terms':        {'en':'Terms of Service','ms':'Terma Perkhidmatan','zh':'服务条款','ja':'利用規約','ko':'이용약관','ar':'شروط الخدمة'},
  'settings_privacy_pol':  {'en':'Privacy Policy','ms':'Dasar Privasi','zh':'隐私政策','ja':'プライバシーポリシー','ko':'개인정보처리방침','ar':'سياسة الخصوصية'},
  'settings_support':      {'en':'Support','ms':'Sokongan','zh':'支持','ja':'サポート','ko':'지원','ar':'الدعم'},
  'settings_view':         {'en':'View ›','ms':'Lihat ›','zh':'查看 ›','ja':'表示 ›','ko':'보기 ›','ar':'عرض ›'},
};

// ─────────────────────────────────────────────────────────────
// LOCALIZATION CLASS
// ─────────────────────────────────────────────────────────────

class AppL10n {
  final String languageCode;
  const AppL10n(this.languageCode);

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

  // Convenience getters (unchanged from your existing file)
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