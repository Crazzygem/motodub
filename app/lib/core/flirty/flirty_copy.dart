import 'dart:math';
import 'package:flutter/widgets.dart';

// ════════════════════════════════════════════════════════════════════════════
// 1. PASSENGER COPY (Female Browser looking for cute Male Riders / "Bong")
// ════════════════════════════════════════════════════════════════════════════
class PassengerCopy {
  static final _rnd = Random();
  static T _pick<T>(List<T> items) => items[_rnd.nextInt(items.length)];
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

  // ── Hero Taglines ────────────────────────────────────────────────────────
  static const taglinesEn = [
    "Find your ride crush.",
    "Need a ride... or a cute driver?",
    "Where to, Bong?",
    "Who's gonna dub you today?",
    "Swipe right on your ride.",
    "Not just a ride, it's a match.",
    "Hop on with your favorite Bong.",
    "Come pick me up, Bong.",
    "One swipe closer to him.",
    "Catch a ride, catch a feeling.",
  ];

  static const taglinesKm = [
    "បងណាឌុបអូនថ្ងៃនេះ?",
    "ស្វែងរក Crush មកឌុប",
    "ត្រូវការជិះ... ឬត្រូវការបង?",
    "Swipe រកបងៗសង្ហា",
    "មិនត្រឹមតែជិះទេ គឺត្រូវចិត្តហ្មង",
    "លេសល្អបំផុតដើម្បីជិះជាមួយ Crush",
    "មកឌុបអូនមក បង",
    "មួយ Swipe ទៀតជួបបងហើយ",
    "ជិះទៅណាក៏បាន ឱ្យតែជាមួយបង",
    "រកបាន Driver ត្រូវចិត្តនៅ?",
  ];

  static String tagline(BuildContext context) {
    if (_isTest) return "Ride smart. Go far.";
    capture(context);
    return _pick(_isKm ? taglinesKm : taglinesEn);
  }

  // ── Deck Header ──────────────────────────────────────────────────────────
  static const deckTitlesEn = [
    "Find your ride below",
    "Who's catching your eye today?",
    "Choose who gets to dub you",
    "Swipe right on someone cute",
    "Your next ride crush is here",
    "Pick your driver, pick your vibe",
  ];

  static const deckTitlesKm = [
    "ស្វែងរកអ្នកឌុបខាងក្រោម",
    "បងណាត្រូវភ្នែកអូនជាងគេ?",
    "ជ្រើសរើសបងដែលត្រូវឌុបអូន",
    "Swipe Right លើបងៗដែល Cute",
    "Crush បន្ទាប់របស់អ្នកនៅទីនេះហើយ",
    "ជ្រើសរើស Driver ត្រូវ Vibe របស់អ្នក",
  ];

  static String deckTitle(BuildContext context) {
    if (_isTest) return "Find your ride below";
    capture(context);
    return _pick(_isKm ? deckTitlesKm : deckTitlesEn);
  }

  // ── Empty State (No Drivers) ─────────────────────────────────────────────
  static const noDriversTitleEn = [
    "No drivers nearby",
    "Where did all the boys go?",
    "No cuties online right now",
    "Your crush is hiding",
  ];

  static const noDriversTitleKm = [
    "អត់ទាន់មានអ្នកនៅជិតនេះទេ",
    "បងៗទៅណាអស់ហើយ?",
    "គ្មាន Driver សង្ហានៅជិតនេះសោះ",
    "Crush របស់អូនកំពុងពួនហើយ",
  ];

  static const noDriversHintEn = [
    "No drivers online right now — pull to refresh",
    "Everyone's busy on a trip — try again in a sec",
    "So quiet... pull down to find your match",
  ];

  static const noDriversHintKm = [
    "ឥឡូវនេះអត់ទាន់មានអ្នក Online ទេ — អូស Refresh ម្តងទៀតណា",
    "បងៗកំពុងជាប់រវល់ហើយ — សាកម្តងទៀតបន្តិចទៀត",
    "ស្ងាត់ណាស់... អូសចុះក្រោមដើម្បីស្វែងរកម្តងទៀត",
  ];

  static String noDriversTitle(BuildContext context) {
    if (_isTest) return "No drivers online";
    capture(context);
    return _pick(_isKm ? noDriversTitleKm : noDriversTitleEn);
  }

  static String noDriversHint(BuildContext context) {
    if (_isTest) return "No drivers online right now — pull to refresh";
    capture(context);
    return _pick(_isKm ? noDriversHintKm : noDriversHintEn);
  }

  // ── Booking Sheet ────────────────────────────────────────────────────────
  static const confirmBookingEn = [
    "Dub Oun?",
    "Come pick me up, Bong",
    "Let's go together",
    "Book this driver",
  ];

  static const confirmBookingKm = [
    "ឌុបអូនទេ បង?",
    "មកឌុបអូនមក",
    "ទៅជាមួយគ្នាណា បង",
    "កក់បងម្នាក់នេះ",
  ];

  static const payCashEn = [
    "Pay cash on arrival — flirt about the fare together.",
    "Cash on arrival — negotiate with a smile.",
    "No wallet needed, just cash + chemistry.",
  ];

  static const payCashKm = [
    "បង់លុយសុទ្ធពេលទៅដល់ — ញញឹមដាក់បងមួយ ចរចាតម្លៃតាមសម្រួល",
    "បង់លុយសុទ្ធពេលជួប — ត្រូវរ៉ូវគ្នាតាមសម្រួលណា",
    "មិនបាច់កាបូបលុយ ត្រូវការតែលុយសុទ្ធ និង Chemistry ត្រូវគ្នា",
  ];

  static String confirmBooking(BuildContext context) {
    if (_isTest) return "Confirm booking";
    capture(context);
    return _pick(_isKm ? confirmBookingKm : confirmBookingEn);
  }

  static String payCashNote(BuildContext context) {
    if (_isTest) return "Pay cash on arrival — agree the fare with your driver.";
    capture(context);
    return _pick(_isKm ? payCashKm : payCashEn);
  }

  // ── Tracking & Status ────────────────────────────────────────────────────
  static const waitingEn = [
    "Shooting your shot... waiting for him to say yes",
    "He's deciding... will he dub you?",
    "Waiting for your crush to answer...",
    "Sent with love, waiting for confirmation",
  ];

  static const waitingKm = [
    "កំពុងបាញ់ Shot ទៅបងហើយ... ចាំមើលគាត់ Say Yes អត់",
    "គាត់កំពុងសម្រេចចិត្ត... តើបងនឹងឌុបអូនទេ?",
    "កំពុងរង់ចាំ Crush ឆ្លើយតប...",
    "ផ្ញើទៅហើយ ចាំបន្តិចណា...",
  ];

  static const driverPassedEn = [
    "He passed... not your Bong today",
    "Ouch — he swiped left on you",
    "He's busy with someone else — try another cutie",
  ];

  static const driverPassedKm = [
    "គាត់រំលងបាត់... មិនទាន់ត្រូវគូគ្នាទេថ្ងៃនេះ",
    "គាត់ Swipe Left លើអូនបាត់...",
    "គាត់រវល់បាត់ហើយ — សាករកបងសង្ហាផ្សេងទៀត",
  ];

  static String waitingForDriver(BuildContext context) {
    if (_isTest) return "Waiting for your driver to respond…";
    capture(context);
    return _pick(_isKm ? waitingKm : waitingEn);
  }

  static String driverPassedNote(BuildContext context) {
    if (_isTest) return "The driver passed on your request";
    capture(context);
    return _pick(_isKm ? driverPassedKm : driverPassedEn);
  }

  // ── Steps (Passenger View) ───────────────────────────────────────────────
  static const stepRequestedKm = ["បានផ្ញើសំណើ", "បាញ់ Shot រួចរាល់", "បានសុំបងឌុបហើយ"];
  static const stepAcceptedKm = ["បង Say Yes ហើយ!", "ត្រូវ Match គ្នាហើយ!", "គាត់យល់ព្រមហើយ"];
  static const stepEnRouteKm = ["បងកំពុងជិះមក", "កំពុងមករកអូនហើយ", "ជិតមកដល់ហើយណា"];
  static const stepRidingKm = ["កំពុងជិះជាមួយបង", "បាននៅជាមួយគ្នាហើយ", "Sweet តាមផ្លូវ"];
  static const stepDoneKm = ["ដល់កន្លែងហើយ", "ដល់ហើយ អរគុណបង ✓", "មកដល់ដោយសុវត្ថិភាព"];

  static const stepRequestedEn = ["Shot your shot", "Requested", "Asked him..."];
  static const stepAcceptedEn = ["He said yes!", "It's a match!", "Ride confirmed!"];
  static const stepEnRouteEn = ["On his way to you", "Coming to you", "He's almost there"];
  static const stepRidingEn = ["Riding together", "Together at last", "Enjoy the ride"];
  static const stepDoneEn = ["Arrived safely ✓", "Made it together ✓", "Done ✓"];

  static String stepRequested(BuildContext context) {
    if (_isTest) return "Requested";
    capture(context);
    return _pick(_isKm ? stepRequestedKm : stepRequestedEn);
  }

  static String stepAccepted(BuildContext context) {
    if (_isTest) return "Accepted";
    capture(context);
    return _pick(_isKm ? stepAcceptedKm : stepAcceptedEn);
  }

  static String stepEnRoute(BuildContext context) {
    if (_isTest) return "En route";
    capture(context);
    return _pick(_isKm ? stepEnRouteKm : stepEnRouteEn);
  }

  static String stepRiding(BuildContext context) {
    if (_isTest) return "Riding";
    capture(context);
    return _pick(_isKm ? stepRidingKm : stepRidingEn);
  }

  static String stepDone(BuildContext context) {
    if (_isTest) return "Done";
    capture(context);
    return _pick(_isKm ? stepDoneKm : stepDoneEn);
  }
  // ── Rating (Passenger rating the Driver) ─────────────────────────────────
  static const rateYourTripEn = [
    "Rate your Bong",
    "How was he, Oun?",
    "Spill the tea — how was the ride?",
    "Vibe check: how was your driver?",
  ];

  static const rateYourTripKm = [
    "Rate ឱ្យបងបន្តិចមក អូន",
    "គាត់យ៉ាងណាដែរ?",
    "Spill the tea មើល៍ — គាត់ Cute អត់?",
    "ជិះជាមួយគាត់មិញ Vibe អត់?",
  ];

  static String rateYourTrip(BuildContext context) {
    if (_isTest) return "Rate your trip";
    capture(context);
    return _pick(_isKm ? rateYourTripKm : rateYourTripEn);
  }
}

// ════════════════════════════════════════════════════════════════════════════
// 2. DRIVER COPY (Male Moto Dub Rider picking up female passengers / "Oun")
// ════════════════════════════════════════════════════════════════════════════
class DriverCopy {
  static final _rnd = Random();
  static T _pick<T>(List<T> items) => items[_rnd.nextInt(items.length)];
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

  // ── Online / Presence ────────────────────────────────────────────────────
  static const youAreOnlineEn = [
    "You're online — Ouns can see you",
    "Live and ready to dub",
    "Online — waiting for cuties to request",
  ];

  static const youAreOnlineKm = [
    "Online ហើយ — ចាំមើលអូនណា Request មក",
    "កំពុង Live — អូនៗឃើញបងហើយ",
    "Online រួចរាល់ — ត្រៀមខ្លួនឌុប Crush",
  ];

  static const youAreOfflineEn = [
    "You're offline — no Ouns can see you",
    "Taking a break, handsome?",
    "Offline — rest up for the next ride",
  ];

  static const youAreOfflineKm = [
    "Offline ហើយ — អត់ទាន់មានអ្នកណាឃើញបងទេ",
    "សម្រាកសិនមែនទេ Bong?",
    "Offline ហើយ — ទុកកម្លាំងចាំឌុបអូនៗលើកក្រោយ",
  ];

  static const goOnlineHintEn = [
    "Go online — cuties are waiting for a ride",
    "Tap online — someone cute needs a lift",
  ];

  static const goOnlineHintKm = [
    "បើក Online មក — មានអូន Cute Cute កំពុងរង់ចាំ",
    "ចុច Online មក — ចាំមើលអូនណាត្រូវគូជាមួយបង",
  ];

  static String youAreOnline(BuildContext context) {
    if (_isTest) return "You're online";
    capture(context);
    return _pick(_isKm ? youAreOnlineKm : youAreOnlineEn);
  }

  static String youAreOffline(BuildContext context) {
    if (_isTest) return "You're offline";
    capture(context);
    return _pick(_isKm ? youAreOfflineKm : youAreOfflineEn);
  }

  static String goOnlineHint(BuildContext context) {
    if (_isTest) return "Go online to receive requests";
    capture(context);
    return _pick(_isKm ? goOnlineHintKm : goOnlineHintEn);
  }

  // ── Incoming Requests & CTAs ─────────────────────────────────────────────
  static const incomingRequestEn = [
    "Oun requested to ride with you!",
    "Someone cute wants you to dub her",
    "New ride match incoming!",
  ];

  static const incomingRequestKm = [
    "មានអូន Cute សុំជិះជាមួយបង!",
    "អូនបានផ្ញើសំណើមកហើយ — ចង់ឱ្យបងឌុប!",
    "Crush ចង់ជិះជាមួយបង — ទទួលអត់?",
  ];

  static const acceptCtaEn = ["Say Yes", "Dub her", "Accept, let's go", "I'm on my way"];
  static const acceptCtaKm = ["Say Yes ឌុបអូន", "ទទួលឌុប", "តោះទៅឌុបអូន", "យល់ព្រម"];

  static const declineCtaEn = ["Pass", "Not right now", "Decline"];
  static const declineCtaKm = ["រំលងសិន", "មិនទាន់ទំនេរទេ", "បដិសេធ"];

  static const onMyWayCtaEn = ["On my way, Oun", "Coming to pick you up", "Heading over"];
  static const onMyWayCtaKm = ["កំពុងទៅរកអូនហើយ", "ចាំបងបន្តិចណា អូន", "On the way ទៅរកអូន"];

  static const startRideCtaEn = ["Hop on, Oun", "Let's roll", "Start ride"];
  static const startRideCtaKm = ["ឡើងមក អូន", "តោះចេញដំណើរ អូន", "តោះទៅជាមួយបង"];

  static const endRideCtaEn = ["Dubbed safely ✓", "Arrived with Oun ✓", "End ride ✓"];
  static const endRideCtaKm = ["ឌុបអូនដល់កន្លែងហើយ ✓", "ដល់គោលដៅដោយសុវត្ថិភាព ✓", "បញ្ចប់ដំណើរ ✓"];

  static String incomingRequest(BuildContext context) {
    capture(context);
    return _pick(_isKm ? incomingRequestKm : incomingRequestEn);
  }

  static String acceptCta(BuildContext context) {
    if (_isTest) return "Accept";
    capture(context);
    return _pick(_isKm ? acceptCtaKm : acceptCtaEn);
  }

  static String declineCta(BuildContext context) {
    if (_isTest) return "Decline";
    capture(context);
    return _pick(_isKm ? declineCtaKm : declineCtaEn);
  }

  static String onMyWayCta(BuildContext context) {
    if (_isTest) return "On my way";
    capture(context);
    return _pick(_isKm ? onMyWayCtaKm : onMyWayCtaEn);
  }

  static String startRideCta(BuildContext context) {
    if (_isTest) return "Start ride";
    capture(context);
    return _pick(_isKm ? startRideCtaKm : startRideCtaEn);
  }

  static String endRideCta(BuildContext context) {
    if (_isTest) return "End ride ✓";
    capture(context);
    return _pick(_isKm ? endRideCtaKm : endRideCtaEn);
  }

  // ── Driver Vehicle Setup & Activity ──────────────────────────────────────
  static const setupVehicleTitleEn = ["Set up your ride", "Show off your wheels, handsome"];
  static const setupVehicleTitleKm = ["រៀបចំម៉ូតូ/ឡានរបស់អ្នក", "បង្ហាញម៉ូតូសង្ហារបស់បងមក"];

  static const setupVehicleSubtitleEn = [
    "Make your ride look irresistible — admin will review.",
    "One profile per rider — get verified and start dubbing.",
  ];
  static const setupVehicleSubtitleKm = [
    "រៀបចំ Profile ឱ្យឡូយមក — Admin នឹង Review ឱ្យភ្លាម។",
    "គណនីមួយ ម៉ូតូមួយ — ផ្ទៀងផ្ទាត់រួចចាំចេញឌុបអូនៗ។",
  ];

  static const activityEmptyTitleEn = ["No rides completed yet", "Still waiting for your first Oun"];
  static const activityEmptyTitleKm = ["មិនទាន់មានប្រវត្តិឌុបទេ", "កំពុងរង់ចាំឌុប Oun ដំបូងរបស់អ្នក"];

  static String setupVehicleTitle(BuildContext context) {
    if (_isTest) return "Set up your vehicle";
    capture(context);
    return _pick(_isKm ? setupVehicleTitleKm : setupVehicleTitleEn);
  }

  static String setupVehicleSubtitle(BuildContext context) {
    if (_isTest) return "One profile per driver — admin review follows.";
    capture(context);
    return _pick(_isKm ? setupVehicleSubtitleKm : setupVehicleSubtitleEn);
  }

  static String activityEmptyTitle(BuildContext context) {
    if (_isTest) return "No rides yet";
    capture(context);
    return _pick(_isKm ? activityEmptyTitleKm : activityEmptyTitleEn);
  }
}

// ════════════════════════════════════════════════════════════════════════════
// 3. LEGACY FLIRTY COPY (Unified facade — kept for existing widgets)
//    Delegates to PassengerCopy/DriverCopy where new Bong/Oun pools exist,
//    keeps old pools for missing methods so the app never breaks.
// ════════════════════════════════════════════════════════════════════════════
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

  // ── Delegated to new Bong/Oun pools ──────────────────────────────────────
  static String tagline(BuildContext context) => PassengerCopy.tagline(context);
  static String deckTitle(BuildContext context) => PassengerCopy.deckTitle(context);
  static String noDriversTitle(BuildContext context) => PassengerCopy.noDriversTitle(context);
  static String noDriversHint(BuildContext context) => PassengerCopy.noDriversHint(context);
  static String confirmBooking(BuildContext context) => PassengerCopy.confirmBooking(context);
  static String payCashNote(BuildContext context) => PassengerCopy.payCashNote(context);
  static String waitingForDriver(BuildContext context) => PassengerCopy.waitingForDriver(context);
  static String driverPassedNote(BuildContext context) => PassengerCopy.driverPassedNote(context);
  static String stepRequested(BuildContext context) => PassengerCopy.stepRequested(context);
  static String stepAccepted(BuildContext context) => PassengerCopy.stepAccepted(context);
  static String stepEnRoute(BuildContext context) => PassengerCopy.stepEnRoute(context);
  static String stepRiding(BuildContext context) => PassengerCopy.stepRiding(context);
  static String stepDone(BuildContext context) => PassengerCopy.stepDone(context);
  static String rateYourTrip(BuildContext context) => PassengerCopy.rateYourTrip(context);
  static String youAreOnline(BuildContext context) => DriverCopy.youAreOnline(context);
  static String youAreOffline(BuildContext context) => DriverCopy.youAreOffline(context);
  static String goOnlineHint(BuildContext context) => DriverCopy.goOnlineHint(context);
  static String setupVehicleTitle(BuildContext context) => DriverCopy.setupVehicleTitle(context);
  static String setupVehicleSubtitle(BuildContext context) => DriverCopy.setupVehicleSubtitle(context);
  static String activityEmptyTitle(BuildContext context) => DriverCopy.activityEmptyTitle(context);
  static String acceptButton(BuildContext context) => DriverCopy.acceptCta(context);
  static String declineButton(BuildContext context) => DriverCopy.declineCta(context);
  static String onMyWayCta(BuildContext context) => DriverCopy.onMyWayCta(context);
  static String startRideCta(BuildContext context) => DriverCopy.startRideCta(context);
  static String endRideCta(BuildContext context) => DriverCopy.endRideCta(context);

  // ── Kept from previous version (missing in new Bong/Oun spec) ───────────
  // Greeting (time-based)
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

  static const _receivingEn = ["Receiving ride requests", "Ouns can request you", "Waiting for your next match", "Ready for your next Oun"];
  static const _receivingKm = ["កំពុងទទួលសំណើរដំណើរ", "អូនអាចស្នើសុំអ្នក", "រង់ចាំ Match បន្ទាប់", "ត្រៀមសម្រាប់ Oun បន្ទាប់"];
  static String receivingRequests(BuildContext context) {
    if (_isTest) return "Receiving ride requests";
    capture(context);
    return pick(_isKm ? _receivingKm : _receivingEn);
  }

  static const _noRidesYetEn = ["No rides yet", "No rides yet, Oun", "No love stories yet", "Your story hasn't started"];
  static const _noRidesYetKm = ["មិនទាន់មានដំណើរ", "មិនទាន់មានដំណើរ អូន", "មិនទាន់មានរឿងស្នេហា"];
  static const _historyHintEn = [
    "Your trips will show up here once you book or drive one.",
    "Swipe right and your love stories will show up here.",
    "Book a cutie and your history will bloom here.",
    "No trips yet — your next Oun is waiting.",
  ];
  static const _historyHintKm = [
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
    return pick(_isKm ? _historyHintKm : _historyHintEn);
  }

  static const _activityHintEn = [
    "Your completed trips will show up here.",
    "Your love stories will show up here after you ride.",
    "Finish a ride and your story starts here.",
  ];
  static const _activityHintKm = [
    "ដំណើរដែលបានបញ្ចប់របស់អ្នកនឹងបង្ហាញនៅទីនេះ។",
    "រឿងស្នេហារបស់អ្នកនឹងបង្ហាញនៅទីនេះ",
  ];
  static String activityEmptyHint(BuildContext context) {
    if (_isTest) return "Your completed trips will show up here.";
    capture(context);
    return pick(_isKm ? _activityHintKm : _activityHintEn);
  }
}
