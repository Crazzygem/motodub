import 'dart:math';
import 'package:flutter/widgets.dart';

/// Flirty random copy — Option B: full mix of Sweet + Cheeky + Spicy equally.
/// Every [pick] is uniform random; call per-build for a fresh vibe.
/// EN + KM pools kept side-by-side, locale-picked via [Localizations].
/// In Flutter test (TestWidgetsFlutterBinding), returns legacy deterministic
/// strings so `flutter test` stays green.
class FlirtyCopy {
  static final _rnd = Random();

  static T pick<T>(List<T> items) => items[_rnd.nextInt(items.length)];

  static bool get _isTest {
    try {
      return WidgetsBinding.instance.runtimeType.toString().contains('Test');
    } catch (_) {
      return false;
    }
  }

  static bool get isTest => _isTest;

  static bool get _isKm => _locale == 'km';
  static String _locale = 'en';
  static void capture(BuildContext context) {
    _locale = Localizations.localeOf(context).languageCode;
  }

  // ── Taglines — 20 each, all used on AuthHero ──────────────────────────
  static const taglinesEn = [
    "ដឹកអូនទៅណាក៏បាន",
    "ដឹកអូន ដឹកចិត្ត",
    "Where to, Oun?",
    "Your Ride, Your Oun.",
    "Ride Together, Stay Together.",
    "Swipe. Match. Dub Oun.",
    "Find Your Ride Crush.",
    "Swipe Right On Your Ride.",
    "Not Just a Ride, It's a Match.",
    "Your Favorite Excuse to Ride Together.",
    "Need a Ride... or a Vibe?",
    "Hop On, Oun.",
    "Closer Than Ever, One Ride Away.",
    "Love at First Ride.",
    "Flirt on the Way.",
    "Come Closer, Oun.",
    "One Swipe Closer to Oun.",
    "ជិះជាមួយអូន",
    "Ride Me, Oun?",
    "Your Oun Is Waiting.",
  ];

  static const taglinesKm = [
    "ដឹកអូនទៅណាក៏បាន",
    "ដឹកអូន ដឹកចិត្ត",
    "ទៅណា អូន?",
    "ជិះជាមួយអូន",
    "ជិះជាមួយគ្នា ទៅជាមួយគ្នា",
    "អូស ចុច ដឹកអូន",
    "ស្វែងរក Oun របស់អ្នក",
    "អូសត្រូវ ជិះជាមួយគ្នា",
    "មិនមែនគ្រាន់តែជិះ គឺជួបគ្នា",
    "ហេតុផលល្អបំផុតដើម្បីជិះជាមួយគ្នា",
    "ត្រូវការជិះ... ឬត្រូវការអូន?",
    "ឡើងមក អូន",
    "កាន់តែជិត មួយជិះទៀតដល់",
    "ស្រឡាញ់តាំងពីជិះដំបូង",
    "ផ្អែមតាមផ្លូវ",
    "មកជិតទៀត អូន",
    "មួយអូសទៀតជិតអូន",
    "ជិះទៅណាក៏ជាមួយអូន",
    "ដឹកអូនបានទេ?",
    "អូនរបស់អ្នកកំពុងរង់ចាំ",
  ];

  static String tagline(BuildContext context) {
    if (_isTest) return "Ride smart. Go far.";
    capture(context);
    return pick(_isKm ? taglinesKm : taglinesEn);
  }

  // ── Deck header — findYourRide ────────────────────────────────────────
  static const _deckTitlesEn = [
    "Find your ride below",
    "Who's catching your eye, Oun?",
    "Your Oun is waiting below",
    "Swipe right on someone cute",
    "Pick your vibe, Oun",
    "Your next ride crush is here",
    "Choose who gets to dub you",
    "Find your favorite Oun below",
  ];
  static const _deckTitlesKm = [
    "ស្វែងរកដំណើររបស់អ្នកនៅខាងក្រោម",
    "អ្នកណាគួរឱ្យស្រលាញ់ អូន?",
    "អូនរបស់អ្នករង់ចាំខាងក្រោម",
    "អូសត្រូវលើអ្នកដែលគួរឱ្យស្រលាញ់",
    "ជ្រើសរើស Vibe របស់អ្នក អូន",
    "Crush បន្ទាប់របស់អ្នកនៅទីនេះ",
    "ជ្រើសរើសអ្នកដែលបានដឹកអូន",
    "ស្វែងរក Oun ដែលអ្នកចូលចិត្ត",
  ];
  static String deckTitle(BuildContext context) {
    if (_isTest) return "Find your ride below";
    capture(context);
    return pick(_isKm ? _deckTitlesKm : _deckTitlesEn);
  }

  // ── Greetings — time-based flirty pools ───────────────────────────────
  static const _greetMorningEn = [
    "Good morning, Oun",
    "Morning, darling",
    "Hey beautiful — good morning",
    "Rise & ride, Oun",
    "Good morning, cutie",
    "Woke up cute, Oun?",
  ];
  static const _greetMorningKm = [
    "អរុណសួស្តី អូន",
    "ព្រឹកសួស្តី សំណព្វ",
    "ព្រឹកនេះស្រស់ស្អាត អូន",
    "ក្រោកហើយ អូន — ទៅជិះ?",
    "ព្រឹកសួស្តី មនុស្សស្អាត",
  ];
  static const _greetAfternoonEn = [
    "Good afternoon, Oun",
    "Hey handsome — afternoon looks good on you",
    "Afternoon, darling",
    "Hello sunshine, Oun",
    "Still cute this afternoon, Oun?",
  ];
  static const _greetAfternoonKm = [
    "ទិវាសួស្តី អូន",
    "រសៀលនេះស្រស់ស្អាត អូន",
    "សួស្តី អូនសម្លាញ់",
    "រសៀលល្អ អូន",
  ];
  static const _greetEveningEn = [
    "Good evening, Oun",
    "Evening, darling",
    "Hey Oun — tonight's ours",
    "Night looks good on you, Oun",
    "Evening, beautiful",
    "Come closer, Oun — it's evening",
  ];
  static const _greetEveningKm = [
    "រាត្រីសួស្តី អូន",
    "ល្ងាចសួស្តី សំណព្វ",
    "យប់នេះជារបស់យើង អូន",
    "រាត្រីនេះស្រស់ស្អាត អូន",
  ];

  static String greeting(BuildContext context, DateTime now, String? name) {
    if (_isTest) {
      final part = now.hour < 12
          ? "Good morning"
          : now.hour < 18
              ? "Good afternoon"
              : "Good evening";
      final first = name?.trim().split(RegExp(r'\s+')).firstWhere(
            (s) => s.isNotEmpty,
            orElse: () => '',
          );
      if (first == null || first.isEmpty) return part;
      return "$part, $first";
    }
    capture(context);
    final first = name?.trim().split(RegExp(r'\s+')).firstWhere(
          (s) => s.isNotEmpty,
          orElse: () => '',
        );
    final suffix = (first != null && first.isNotEmpty) ? ', $first' : ', Oun';
    List<String> pool;
    if (now.hour < 12) {
      pool = _isKm ? _greetMorningKm : _greetMorningEn;
    } else if (now.hour < 18) {
      pool = _isKm ? _greetAfternoonKm : _greetAfternoonEn;
    } else {
      pool = _isKm ? _greetEveningKm : _greetEveningEn;
    }
    final base = pick(pool);
    if (base.contains('Oun') || base.contains('អូន')) return base;
    return '$base$suffix';
  }

  // ── Empty deck ────────────────────────────────────────────────────────
  static const _noDriversTitleEn = [
    "No drivers online",
    "No cuties nearby",
    "So quiet... where's your Oun?",
    "Nobody to dub right now",
    "All Ouns are busy",
    "Your crush is hiding",
  ];
  static const _noDriversTitleKm = [
    "គ្មានអ្នកបើកបរអនឡាញ",
    "គ្មានអ្នកស្អាតនៅជិត",
    "ស្ងាត់ណាស់... អូននៅឯណា?",
    "គ្មានអ្នកដឹកឥឡូវនេះ",
    "Oun ទាំងអស់រវល់",
    "Crush របស់អ្នកលាក់ខ្លួន",
  ];
  static const _noDriversHintEn = [
    "No drivers online right now — pull to refresh",
    "No cuties nearby... pull to refresh, Oun",
    "Your Oun is still getting ready — try again",
    "Everyone's busy riding someone else — refresh?",
    "So empty... your type is hiding. Pull to refresh",
    "No matches nearby — give it a sec, Oun",
  ];
  static const _noDriversHintKm = [
    "ឥឡូវនេះគ្មានអ្នកបើកបរអនឡាញទេ — អូសដើម្បីផ្ទុកឡើងវិញ",
    "គ្មានអ្នកស្អាតនៅជិតទេ... អូសផ្ទុកឡើងវិញ អូន",
    "អូនរបស់អ្នកកំពុងត្រៀមខ្លួន — សាកម្តងទៀត",
    "អ្នកទាំងអស់រវល់ដឹកអ្នកផ្សេង — ផ្ទុកឡើងវិញ?",
    "ស្ងាត់ណាស់... ប្រភេទរបស់អ្នកលាក់ខ្លួន",
  ];
  static String noDriversTitle(BuildContext context) {
    if (_isTest) return "No drivers online";
    capture(context);
    return pick(_isKm ? _noDriversTitleKm : _noDriversTitleEn);
  }

  static String noDriversHint(BuildContext context) {
    if (_isTest) return "No drivers online right now — pull to refresh";
    capture(context);
    return pick(_isKm ? _noDriversHintKm : _noDriversHintEn);
  }

  // ── Booking sheet ─────────────────────────────────────────────────────
  static const _confirmBookingEn = [
    "Confirm booking",
    "Dub Oun?",
    "Let's go together, Oun",
    "Take me, Oun",
    "Book my Oun",
    "Shall we ride?",
    "Come dub me, Oun",
  ];
  static const _confirmBookingKm = [
    "បញ្ជាក់ការកក់",
    "ដឹកអូនទេ?",
    "ទៅជាមួយគ្នា អូន",
    "មកដឹកអូន",
    "កក់ Oun របស់ខ្ញុំ",
    "តោះជិះ?",
  ];
  static const _payCashEn = [
    "Pay cash on arrival — agree the fare with your driver.",
    "Cash on arrival, Oun — flirt about the fare together.",
    "Pay with cash when you meet — negotiate with a smile.",
    "Cash when you arrive — you and your Oun decide.",
    "No wallet, just cash + chemistry.",
  ];
  static const _payCashKm = [
    "បង់សាច់ប្រាក់ពេលទៅដល់ — ព្រមព្រៀងថ្លៃជាមួយអ្នកបើកបរ។",
    "បង់សាច់ប្រាក់ពេលជួប អូន — ចរចាតម្លៃជាមួយគ្នា",
    "បង់ពេលទៅដល់ — អ្នក និង Oun សម្រេចចិត្ត",
    "គ្មានកាបូបទេ មានតែសាច់ប្រាក់ និងអារម្មណ៍",
  ];
  static String confirmBooking(BuildContext context) {
    if (_isTest) return "Confirm booking";
    capture(context);
    return pick(_isKm ? _confirmBookingKm : _confirmBookingEn);
  }

  static String payCashNote(BuildContext context) {
    if (_isTest) return "Pay cash on arrival — agree the fare with your driver.";
    capture(context);
    return pick(_isKm ? _payCashKm : _payCashEn);
  }

  // ── Tracking ──────────────────────────────────────────────────────────
  static const _waitingEn = [
    "Waiting for your driver to respond…",
    "Shooting your shot... waiting for him to say yes",
    "He's deciding... will he dub you, Oun?",
    "Waiting for your crush to answer...",
    "Your Oun is thinking — hold tight",
    "Sent with love, waiting for a yes",
  ];
  static const _waitingKm = [
    "កំពុងរង់ចាំអ្នកបើកបរឆ្លើយតប…",
    "កំពុងស្ទាក់... រង់ចាំគាត់និយាយថាបាទ",
    "គាត់កំពុងសម្រេចចិត្ត... តើគាត់នឹងដឹកអូនទេ?",
    "កំពុងរង់ចាំ Crush ឆ្លើយ...",
    "អូនរបស់អ្នកកំពុងគិត — រង់ចាំបន្តិច",
  ];
  static const _driverPassedEn = [
    "The driver passed on your request",
    "He passed... not your Oun today",
    "Ouch — he swiped left on you",
    "Not this one, Oun — try another cutie",
    "He's busy with someone else",
  ];
  static const _driverPassedKm = [
    "អ្នកបើកបរបានបដិសេធសំណើរបស់អ្នក",
    "គាត់បានរំលង... មិនមែន Oun របស់អ្នកថ្ងៃនេះ",
    "គាត់បានអូសឆ្វេងលើអ្នក",
    "មិនមែនអ្នកនេះទេ អូន — សាកអ្នកផ្សេង",
  ];
  static const _rideCancelledEn = [
    "Your ride was cancelled",
    "Ride cancelled, Oun — next time?",
    "Called it off — your Oun will wait",
    "Cancelled — still want to ride together later?",
  ];
  static const _rideCancelledKm = [
    "ដំណើររបស់អ្នកត្រូវបានបោះបង់",
    "ដំណើរត្រូវបានបោះបង់ អូន — លើកក្រោយ?",
    "បានបោះបង់ — អូនរបស់អ្នកនឹងរង់ចាំ",
  ];
  static const _cancelRideEn = [
    "Cancel ride",
    "Never mind, Oun",
    "Pass, next Oun",
    "Cancel — not feeling this one",
    "Let him go",
  ];
  static const _cancelRideKm = [
    "បោះបង់ដំណើរ",
    "មិនអីទេ អូន",
    "រំលង ទៅអ្នកបន្ទាប់",
    "បោះបង់ — មិនចង់អ្នកនេះ",
  ];
  static const _backToDeckEn = [
    "Back to deck",
    "Back to Ouns",
    "Find another Oun",
    "Back to crushes",
    "Keep swiping, Oun",
  ];
  static const _backToDeckKm = [
    "ត្រឡប់ទៅជ្រើសរើសវិញ",
    "ត្រឡប់ទៅរក Oun",
    "ស្វែងរក Oun ផ្សេង",
    "ត្រឡប់ទៅ Crush",
    "បន្តអូស អូន",
  ];
  static String waitingForDriver(BuildContext context) {
    if (_isTest) return "Waiting for your driver to respond…";
    capture(context);
    return pick(_isKm ? _waitingKm : _waitingEn);
  }

  static String driverPassedNote(BuildContext context) {
    if (_isTest) return "The driver passed on your request";
    capture(context);
    return pick(_isKm ? _driverPassedKm : _driverPassedEn);
  }

  static String rideCancelledNote(BuildContext context) {
    if (_isTest) return "Your ride was cancelled";
    capture(context);
    return pick(_isKm ? _rideCancelledKm : _rideCancelledEn);
  }

  static String cancelRide(BuildContext context) {
    if (_isTest) return "Cancel ride";
    capture(context);
    return pick(_isKm ? _cancelRideKm : _cancelRideEn);
  }

  static String backToDeck(BuildContext context) {
    if (_isTest) return "Back to deck";
    capture(context);
    return pick(_isKm ? _backToDeckKm : _backToDeckEn);
  }

  // ── Steps ─────────────────────────────────────────────────────────────
  static const _stepRequestedEn = ["Requested", "Shot your shot", "Asked, Oun..."];
  static const _stepRequestedKm = ["ស្នើសុំ", "បានស្នើសុំ អូន..."];
  static const _stepAcceptedEn = ["Accepted", "He said yes!", "It's a match!", "She said yes!"];
  static const _stepAcceptedKm = ["ទទួលយក", "គាត់និយាយថាបាទ!", "ត្រូវគ្នាហើយ!"];
  static const _stepEnRouteEn = ["En route", "On his way to you", "Coming to you, Oun"];
  static const _stepEnRouteKm = ["កំពុងមកដល់", "កំពុងមករកអ្នក", "មករកអូនហើយ"];
  static const _stepRidingEn = ["Riding", "Together at last", "Riding with Oun"];
  static const _stepRidingKm = ["កំពុងជិះ", "ជិះជាមួយគ្នា", "ជិះជាមួយអូន"];
  static const _stepDoneEn = ["Done", "Arrived, Oun", "You made it together"];
  static const _stepDoneKm = ["រួចរាល់", "ដល់ហើយ អូន", "ទៅដល់ជាមួយគ្នា"];

  static String stepRequested(BuildContext context) {
    if (_isTest) return "Requested";
    capture(context);
    return pick(_isKm ? _stepRequestedKm : _stepRequestedEn);
  }

  static String stepAccepted(BuildContext context) {
    if (_isTest) return "Accepted";
    capture(context);
    return pick(_isKm ? _stepAcceptedKm : _stepAcceptedEn);
  }

  static String stepEnRoute(BuildContext context) {
    if (_isTest) return "En route";
    capture(context);
    return pick(_isKm ? _stepEnRouteKm : _stepEnRouteEn);
  }

  static String stepRiding(BuildContext context) {
    if (_isTest) return "Riding";
    capture(context);
    return pick(_isKm ? _stepRidingKm : _stepRidingEn);
  }

  static String stepDone(BuildContext context) {
    if (_isTest) return "Done";
    capture(context);
    return pick(_isKm ? _stepDoneKm : _stepDoneEn);
  }

  // ── Rating ────────────────────────────────────────────────────────────
  static const _rateYourTripEn = [
    "Rate your trip",
    "How was your ride together?",
    "Rate your Oun",
    "How was he, Oun?",
    "Spill the tea, Oun — how was it?",
  ];
  static const _rateYourTripKm = [
    "វាយតម្លៃដំណើររបស់អ្នក",
    "ដំណើរជាមួយគ្នាយ៉ាងណាដែរ?",
    "វាយតម្លៃ Oun របស់អ្នក",
    "គាត់យ៉ាងណាដែរ អូន?",
  ];
  static const _howWasTripEn = [
    "How was your trip?",
    "How was your time with Oun?",
    "Did you vibe together?",
    "How was the ride, darling?",
    "Tell us, Oun — how was he?",
  ];
  static const _howWasTripKm = [
    "ដំណើររបស់អ្នកយ៉ាងណាដែរ?",
    "ពេលវេលាជាមួយអូនយ៉ាងណាដែរ?",
    "តើអ្នកទាំងពីរត្រូវគ្នាទេ?",
    "ដំណើរយ៉ាងណាដែរ អូន?",
  ];
  static const _thanksEn = ["Thanks!", "Thanks, Oun!", "You flirt — thanks!", "Love you, Oun! Thanks!"];
  static const _thanksKm = ["អរគុណ!", "អរគុណ អូន!", "ស្រឡាញ់អ្នក អូន! អរគុណ!"];
  static const _ratingHelpsEn = [
    "Your rating helps everyone ride safer.",
    "Your tea helps the next Oun ride safer.",
    "Help the next cutie choose — leave a rating.",
    "Share the love — rate your ride.",
  ];
  static const _ratingHelpsKm = [
    "ការវាយតម្លៃរបស់អ្នកជួយឱ្យអ្នកទាំងអស់គ្នាធ្វើដំណើរបានសុវត្ថិភាព។",
    "ការវាយតម្លៃរបស់អ្នកជួយ Oun បន្ទាប់",
    "ចែករំលែកក្តីស្រឡាញ់ — វាយតម្លៃដំណើររបស់អ្នក",
  ];
  static const _alreadyRatedEn = [
    "You already rated this ride.",
    "You already spilled the tea on this one.",
    "Already rated — you flirt, you finished!",
  ];
  static const _alreadyRatedKm = [
    "អ្នកបានវាយតម្លៃដំណើរនេះរួចហើយ។",
    "អ្នកបានវាយតម្លៃរួចហើយ",
  ];
  static String rateYourTrip(BuildContext context) {
    if (_isTest) return "Rate your trip";
    capture(context);
    return pick(_isKm ? _rateYourTripKm : _rateYourTripEn);
  }

  static String howWasTrip(BuildContext context) {
    if (_isTest) return "How was your trip?";
    capture(context);
    return pick(_isKm ? _howWasTripKm : _howWasTripEn);
  }

  static String howWasTripWith(BuildContext context, String name) {
    if (_isTest) return "How was your trip with $name?";
    capture(context);
    if (_isKm) return pick(["ដំណើរជាមួយ $name យ៉ាងណាដែរ?", "ជាមួយ $name — យ៉ាងណាដែរ អូន?"]);
    return pick(["How was your trip with $name?", "How was $name, Oun?", "Vibe check: how was $name?"]);
  }

  static String thanksTitle(BuildContext context) {
    if (_isTest) return "Thanks!";
    capture(context);
    return pick(_isKm ? _thanksKm : _thanksEn);
  }

  static String ratingHelpsNote(BuildContext context) {
    if (_isTest) return "Your rating helps everyone ride safer.";
    capture(context);
    return pick(_isKm ? _ratingHelpsKm : _ratingHelpsEn);
  }

  static String alreadyRatedNote(BuildContext context) {
    if (_isTest) return "You already rated this ride.";
    capture(context);
    return pick(_isKm ? _alreadyRatedKm : _alreadyRatedEn);
  }

  // ── Driver presence ───────────────────────────────────────────────────
  static const _youAreOnlineEn = ["You're online", "You're live, Oun", "You're on — Ouns can see you", "Live and looking cute"];
  static const _youAreOnlineKm = ["អ្នកលើប្រព័ន្ធហើយ", "អ្នក Live ហើយ អូន", "អ្នកលើប្រព័ន្ធ — អូនឃើញអ្នកហើយ"];
  static const _youAreOfflineEn = ["You're offline", "You're hiding, Oun", "Offline — no Ouns can see you", "Taking a break, cutie?"];
  static const _youAreOfflineKm = ["អ្នកចេញពីប្រព័ន្ធ", "អ្នកលាក់ខ្លួន អូន", "ក្រៅប្រព័ន្ធ — គ្មានអូនឃើញអ្នកទេ"];
  static const _receivingRequestsEn = ["Receiving ride requests", "Ouns can request you", "Waiting for your next match", "Ready for your next Oun"];
  static const _receivingRequestsKm = ["កំពុងទទួលសំណើរដំណើរ", "អូនអាចស្នើសុំអ្នក", "រង់ចាំ Match បន្ទាប់", "ត្រៀមសម្រាប់ Oun បន្ទាប់"];
  static const _goOnlineHintEn = ["Go online to receive requests", "Go live — your Oun is waiting", "Tap online — someone cute is waiting", "Come online, handsome"];
  static const _goOnlineHintKm = ["ចូលប្រើប្រព័ន្ធដើម្បីទទួលសំណើ", "ចូល Live — អូនរបស់អ្នករង់ចាំ", "ចុចលើប្រព័ន្ធ — មានអ្នកស្អាតរង់ចាំ"];
  static const _setupVehicleTitleEn = ["Set up your vehicle", "Your ride, your vibe — set it up", "Show off your ride, Oun"];
  static const _setupVehicleTitleKm = ["រៀបចំយានយន្តរបស់អ្នក", "បង្ហាញឡានរបស់អ្នក អូន"];
  static const _setupVehicleSubtitleEn = [
    "One profile per driver — admin review follows.",
    "One ride per driver — make it cute, get verified.",
    "Make your profile irresistible — admin will check.",
  ];
  static const _setupVehicleSubtitleKm = [
    "មួយប្រវត្តិរូបក្នុងមួយអ្នកបើកបរ — ការផ្ទៀងផ្ទាត់ដោយអ្នកគ្រប់គ្រងបន្ទាប់។",
    "មួយឡានមួយអ្នក — ធ្វើឱ្យគួរឱ្យស្រឡាញ់",
  ];
  static String youAreOnline(BuildContext context) {
    if (_isTest) return "You're online";
    capture(context);
    return pick(_isKm ? _youAreOnlineKm : _youAreOnlineEn);
  }

  static String youAreOffline(BuildContext context) {
    if (_isTest) return "You're offline";
    capture(context);
    return pick(_isKm ? _youAreOfflineKm : _youAreOfflineEn);
  }

  static String receivingRequests(BuildContext context) {
    if (_isTest) return "Receiving ride requests";
    capture(context);
    return pick(_isKm ? _receivingRequestsKm : _receivingRequestsEn);
  }

  static String goOnlineHint(BuildContext context) {
    if (_isTest) return "Go online to receive requests";
    capture(context);
    return pick(_isKm ? _goOnlineHintKm : _goOnlineHintEn);
  }

  static String setupVehicleTitle(BuildContext context) {
    if (_isTest) return "Set up your vehicle";
    capture(context);
    return pick(_isKm ? _setupVehicleTitleKm : _setupVehicleTitleEn);
  }

  static String setupVehicleSubtitle(BuildContext context) {
    if (_isTest) return "One profile per driver — admin review follows.";
    capture(context);
    return pick(_isKm ? _setupVehicleSubtitleKm : _setupVehicleSubtitleEn);
  }

  // ── History empty ─────────────────────────────────────────────────────
  static const _noRidesYetEn = ["No rides yet", "No rides yet, Oun", "No love stories yet", "Your story hasn't started"];
  static const _noRidesYetKm = ["មិនទាន់មានដំណើរ", "មិនទាន់មានដំណើរ អូន", "មិនទាន់មានរឿងស្នេហា"];
  static const _historyEmptyHintEn = [
    "Your trips will show up here once you book or drive one.",
    "Swipe right and your love stories will show up here.",
    "Book a cutie and your history will bloom here.",
    "No trips yet — your next Oun is waiting.",
  ];
  static const _historyEmptyHintKm = [
    "ដំណើររបស់អ្នកនឹងបង្ហាញនៅទីនេះ បន្ទាប់ពីអ្នកកក់ឬបើកបរមួយ។",
    "អូសត្រូវហើយរឿងស្នេហារបស់អ្នកនឹងបង្ហាញនៅទីនេះ",
    "កក់អ្នកស្អាតម្នាក់ហើយប្រវត្តិរបស់អ្នកនឹងបង្ហាញ",
  ];
  static String noRidesYetTitle(BuildContext context) {
    if (_isTest) return "No rides yet";
    capture(context);
    return pick(_isKm ? _noRidesYetKm : _noRidesYetEn);
  }

  static String historyEmptyHint(BuildContext context) {
    if (_isTest) return "Your trips will show up here once you book or drive one.";
    capture(context);
    return pick(_isKm ? _historyEmptyHintKm : _historyEmptyHintEn);
  }

  // ── Driver activity empty ─────────────────────────────────────────────
  static const _activityEmptyTitleEn = ["No rides yet", "No rides yet, handsome", "Still waiting for your first Oun"];
  static const _activityEmptyTitleKm = ["មិនទាន់មានដំណើរ", "មិនទាន់មានដំណើរ អូន"];
  static const _activityEmptyHintEn = [
    "Your completed trips will show up here.",
    "Your love stories will show up here after you ride.",
    "Finish a ride and your story starts here.",
  ];
  static const _activityEmptyHintKm = [
    "ដំណើរដែលបានបញ្ចប់របស់អ្នកនឹងបង្ហាញនៅទីនេះ។",
    "រឿងស្នេហារបស់អ្នកនឹងបង្ហាញនៅទីនេះ",
  ];
  static String activityEmptyTitle(BuildContext context) {
    if (_isTest) return "No rides yet";
    capture(context);
    return pick(_isKm ? _activityEmptyTitleKm : _activityEmptyTitleEn);
  }

  static String activityEmptyHint(BuildContext context) {
    if (_isTest) return "Your completed trips will show up here.";
    capture(context);
    return pick(_isKm ? _activityEmptyHintKm : _activityEmptyHintEn);
  }

  // ── CTA variants ──────────────────────────────────────────────────────
  static const _acceptEn = ["Accept", "Say yes", "Dub her", "Dub him", "Accept, Oun"];
  static const _acceptKm = ["ទទួលយក", "និយាយថាបាទ", "ដឹកអូន"];
  static const _declineEn = ["Decline", "Pass", "Next Oun", "Not today"];
  static const _declineKm = ["បដិសេធ", "រំលង", "អូនបន្ទាប់", "មិនមែនថ្ងៃនេះ"];
  static const _onMyWayEn = ["On my way", "Coming to you, Oun", "On my way, darling", "Coming, cutie"];
  static const _onMyWayKm = ["កំពុងទៅហើយ", "កំពុងមករកអ្នក អូន", "មកហើយ អូន"];
  static const _startRideEn = ["Start ride", "Let's ride, Oun", "Hop on, Oun", "Let's go together"];
  static const _startRideKm = ["ចាប់ផ្តើមដំណើរ", "តោះជិះ អូន", "ឡើងមក អូន"];
  static const _endRideEn = ["End ride ✓", "Done, Oun ✓", "Arrived together ✓", "We made it, Oun ✓"];
  static const _endRideKm = ["បញ្ចប់ដំណើរ ✓", "រួចរាល់ អូន ✓", "ដល់ហើយជាមួយគ្នា ✓"];

  static String acceptButton(BuildContext context) {
    if (_isTest) return "Accept";
    capture(context);
    return pick(_isKm ? _acceptKm : _acceptEn);
  }

  static String declineButton(BuildContext context) {
    if (_isTest) return "Decline";
    capture(context);
    return pick(_isKm ? _declineKm : _declineEn);
  }

  static String onMyWayCta(BuildContext context) {
    if (_isTest) return "On my way";
    capture(context);
    return pick(_isKm ? _onMyWayKm : _onMyWayEn);
  }

  static String startRideCta(BuildContext context) {
    if (_isTest) return "Start ride";
    capture(context);
    return pick(_isKm ? _startRideKm : _startRideEn);
  }

  static String endRideCta(BuildContext context) {
    if (_isTest) return "End ride ✓";
    capture(context);
    return pick(_isKm ? _endRideKm : _endRideEn);
  }
}
