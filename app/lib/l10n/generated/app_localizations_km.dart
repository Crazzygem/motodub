// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Khmer Central Khmer (`km`).
class AppLocalizationsKm extends AppLocalizations {
  AppLocalizationsKm([String locale = 'km']) : super(locale);

  @override
  String get navDeck => 'អ្នកបើកបរ';

  @override
  String get navHistory => 'ប្រវត្តិ';

  @override
  String get navAccount => 'គណនី';

  @override
  String get navHome => 'ទំព័រដើម';

  @override
  String get retry => 'ព្យាយាមម្តងទៀត';

  @override
  String get refresh => 'ផ្ទុកឡើងវិញ';

  @override
  String get tryAgain => 'ព្យាយាមម្តងទៀត';

  @override
  String get cancel => 'បោះបង់';

  @override
  String get appTagline => 'ធ្វើដំណើរឆ្លាតវៃ។ ទៅបានឆ្ងាយ។';

  @override
  String get emailLabel => 'អ៊ីមែល';

  @override
  String get passwordLabel => 'ពាក្យសម្ងាត់';

  @override
  String get enterEmail => 'សូមបញ្ចូលអ៊ីមែលរបស់អ្នក';

  @override
  String get enterValidEmail => 'សូមបញ្ចូលអ៊ីមែលត្រឹមត្រូវ';

  @override
  String get enterPassword => 'សូមបញ្ចូលពាក្យសម្ងាត់របស់អ្នក';

  @override
  String get logIn => 'ចូល';

  @override
  String get noAccountRegister => 'មិនមានគណនី? ចុះឈ្មោះ';

  @override
  String get createAccountTitle => 'បង្កើតគណនី';

  @override
  String get nameLabel => 'ឈ្មោះ';

  @override
  String get phoneLabel => 'លេខទូរស័ព្ទ';

  @override
  String get passwordMinLabel => 'ពាក្យសម្ងាត់ (យ៉ាងតិច 8 តួ)';

  @override
  String get registerEnterEmail => 'សូមបញ្ចូលអ៊ីមែល';

  @override
  String get enterValidPhone => 'សូមបញ្ចូលលេខទូរស័ព្ទត្រឹមត្រូវ';

  @override
  String get enterName => 'សូមបញ្ចូលឈ្មោះរបស់អ្នក';

  @override
  String get passwordTooShort => 'ពាក្យសម្ងាត់ត្រូវមានយ៉ាងតិច 8 តួ';

  @override
  String get roleCustomer => 'អតិថិជន';

  @override
  String get roleDriver => 'អ្នកបើកបរ';

  @override
  String get roleAdmin => 'អ្នកគ្រប់គ្រង';

  @override
  String get alreadyHaveAccount => 'មានគណនីរួចហើយ? ចូល';

  @override
  String get greetingMorning => 'អរុណសួស្តី';

  @override
  String get greetingAfternoon => 'ទិវាសួស្តី';

  @override
  String get greetingEvening => 'រាត្រីសួស្តី';

  @override
  String greetingWithName(String part, String name) {
    return '$part, $name';
  }

  @override
  String get findYourRide => 'ស្វែងរកដំណើររបស់អ្នកនៅខាងក្រោម';

  @override
  String get noDriversOnlineTitle => 'គ្មានអ្នកបើកបរអនឡាញ';

  @override
  String get noDriversOnlineHint =>
      'ឥឡូវនេះគ្មានអ្នកបើកបរអនឡាញទេ — អូសដើម្បីផ្ទុកឡើងវិញ';

  @override
  String get driverFallback => 'អ្នកបើកបរ';

  @override
  String etaMinutes(int eta) {
    return '$eta នាទី';
  }

  @override
  String pricePerKmShort(String rate) {
    return '$rate /km';
  }

  @override
  String get pickupLabel => 'ចំណុចចាប់ផ្តើម';

  @override
  String get dropoffLabel => 'ចំណុចចុះ';

  @override
  String get pickupAddressLabel => 'អាសយដ្ឋានចាប់ផ្តើម';

  @override
  String get dropoffAddressLabel => 'អាសយដ្ឋានចុះ';

  @override
  String get enterPickupAddress => 'សូមបញ្ចូលអាសយដ្ឋានចាប់ផ្តើម';

  @override
  String get enterDropoffAddress => 'សូមបញ្ចូលអាសយដ្ឋានចុះ';

  @override
  String get confirmBooking => 'បញ្ជាក់ការកក់';

  @override
  String get payCashNote =>
      'បង់សាច់ប្រាក់ពេលទៅដល់ — ព្រមព្រៀងថ្លៃជាមួយអ្នកបើកបរ។';

  @override
  String get waitingForDriver => 'កំពុងរង់ចាំអ្នកបើកបរឆ្លើយតប…';

  @override
  String get completedEmoji => 'បានបញ្ចប់ 🎉';

  @override
  String get driverPassedNote => 'អ្នកបើកបរបានបដិសេធសំណើរបស់អ្នក';

  @override
  String get rideCancelledNote => 'ដំណើររបស់អ្នកត្រូវបានបោះបង់';

  @override
  String get cancelRide => 'បោះបង់ដំណើរ';

  @override
  String get backToDeck => 'ត្រឡប់ទៅជ្រើសរើសវិញ';

  @override
  String get stepRequested => 'ស្នើសុំ';

  @override
  String get stepAccepted => 'ទទួលយក';

  @override
  String get stepEnRoute => 'កំពុងមកដល់';

  @override
  String get stepRiding => 'កំពុងជិះ';

  @override
  String get stepDone => 'រួចរាល់';

  @override
  String get yourDriverFallback => 'អ្នកបើកបររបស់អ្នក';

  @override
  String kmEtaRow(String km, int min) {
    return '$km km · ប៉ាន់ស្មាន $min នាទី';
  }

  @override
  String get yourRides => 'ដំណើររបស់អ្នក';

  @override
  String get noRidesYetTitle => 'មិនទាន់មានដំណើរ';

  @override
  String get historyEmptyHint =>
      'ដំណើររបស់អ្នកនឹងបង្ហាញនៅទីនេះ បន្ទាប់ពីអ្នកកក់ឬបើកបរមួយ។';

  @override
  String get couldntLoadRides => 'មិនអាចផ្ទុកដំណើររបស់អ្នកបានទេ';

  @override
  String withDriver(String name) {
    return 'ជាមួយ $name';
  }

  @override
  String forCustomer(String name) {
    return 'សម្រាប់ $name';
  }

  @override
  String get statusAll => 'ទាំងអស់';

  @override
  String get statusRequested => 'ស្នើសុំ';

  @override
  String get statusAccepted => 'ទទួលយក';

  @override
  String get statusEnRoute => 'កំពុងមកដល់';

  @override
  String get statusInProgress => 'កំពុងធ្វើដំណើរ';

  @override
  String get statusCompleted => 'បានបញ្ចប់';

  @override
  String get statusCancelled => 'បានបោះបង់';

  @override
  String get statusDeclined => 'បានបដិសេធ';

  @override
  String get rateYourTrip => 'វាយតម្លៃដំណើររបស់អ្នក';

  @override
  String get yourRiderFallback => 'អ្នកដំណើររបស់អ្នក';

  @override
  String get howWasTrip => 'ដំណើររបស់អ្នកយ៉ាងណាដែរ?';

  @override
  String howWasTripWith(String name) {
    return 'ដំណើរជាមួយ $name យ៉ាងណាដែរ?';
  }

  @override
  String get submitRating => 'ដាក់ស្នើ';

  @override
  String get thanksTitle => 'អរគុណ!';

  @override
  String get alreadyRatedNote => 'អ្នកបានវាយតម្លៃដំណើរនេះរួចហើយ។';

  @override
  String get ratingHelpsNote =>
      'ការវាយតម្លៃរបស់អ្នកជួយឱ្យអ្នកទាំងអស់គ្នាធ្វើដំណើរបានសុវត្ថិភាព។';

  @override
  String get doneButton => 'រួចរាល់';

  @override
  String get couldntLoadRide => 'មិនអាចផ្ទុកដំណើរនេះបានទេ';

  @override
  String get motoDubDriverTitle => 'MotoDub អ្នកបើកបរ';

  @override
  String get youAreOnline => 'អ្នកលើប្រព័ន្ធហើយ';

  @override
  String get youAreOffline => 'អ្នកចេញពីប្រព័ន្ធ';

  @override
  String get receivingRequests => 'កំពុងទទួលសំណើរដំណើរ';

  @override
  String get goOnlineHint => 'ចូលប្រើប្រព័ន្ធដើម្បីទទួលសំណើ';

  @override
  String get verifiedChip => 'បានផ្ទៀងផ្ទាត់';

  @override
  String get pendingReviewChip => 'កំពុងរង់ចាំការពិនិត្យ';

  @override
  String get setupVehicleTitle => 'រៀបចំយានយន្តរបស់អ្នក';

  @override
  String get setupVehicleSubtitle =>
      'មួយប្រវត្តិរូបក្នុងមួយអ្នកបើកបរ — ការផ្ទៀងផ្ទាត់ដោយអ្នកគ្រប់គ្រងបន្ទាប់។';

  @override
  String get carModelLabel => 'ម៉ូដែលឡាន';

  @override
  String get plateLabel => 'លេខផ្លាក';

  @override
  String get licenseNoLabel => 'លេខអាជ្ញាបណ្ណ';

  @override
  String get pricePerKmLabel => 'តម្លៃក្នុងមួយគម';

  @override
  String get requiredField => 'ចាំបាច់';

  @override
  String get enterNumber => 'សូមបញ្ចូលលេខ';

  @override
  String get saveVehicle => 'រក្សាទុកយានយន្ត';

  @override
  String get todayTitle => 'ថ្ងៃនេះ';

  @override
  String get ridesDoneLabel => 'ដំណើរបានបញ្ចប់';

  @override
  String get avgRatingLabel => 'ពិន្ទុមធ្យម';

  @override
  String get recentActivityTitle => 'សកម្មភាពថ្មីៗ';

  @override
  String get justNow => 'ថ្មីៗនេះ';

  @override
  String minutesAgo(int n) {
    return '$n នាទីមុន';
  }

  @override
  String hoursAgo(int n) {
    return '$n ម៉ោងមុន';
  }

  @override
  String get activityEmptyTitle => 'មិនទាន់មានដំណើរ';

  @override
  String get activityEmptyHint => 'ដំណើរដែលបានបញ្ចប់របស់អ្នកនឹងបង្ហាញនៅទីនេះ។';

  @override
  String get couldntLoadDashboard => 'មិនអាចផ្ទុកផ្ទាំងព័ត៌មានរបស់អ្នកបានទេ';

  @override
  String get couldntLoadActivity => 'មិនអាចផ្ទុកសកម្មភាពរបស់អ្នកបានទេ។';

  @override
  String get customerFallback => 'អតិថិជន';

  @override
  String kmPill(String km) {
    return '$km km';
  }

  @override
  String get acceptButton => 'ទទួលយក';

  @override
  String get declineButton => 'បដិសេធ';

  @override
  String get onMyWayCta => 'កំពុងទៅហើយ';

  @override
  String get startRideCta => 'ចាប់ផ្តើមដំណើរ';

  @override
  String get endRideCta => 'បញ្ចប់ដំណើរ ✓';

  @override
  String get adminTag => 'អ្នកគ្រប់គ្រង';

  @override
  String get navDashboard => 'ផ្ទាំងព័ត៌មាន';

  @override
  String get navDrivers => 'អ្នកបើកបរ';

  @override
  String get navRides => 'ដំណើរ';

  @override
  String get navLiveMap => 'ផែនទីផ្ទាល់';

  @override
  String get kpiLiveRides => 'ដំណើរកំពុងដំណើរ';

  @override
  String get kpiOnlineDrivers => 'អ្នកបើកបរអនឡាញ';

  @override
  String get kpiCompletedToday => 'បានបញ្ចប់ថ្ងៃនេះ';

  @override
  String get kpiAvgRatingCard => 'ពិន្ទុមធ្យម';

  @override
  String get couldntLoadNumbersTitle => 'មិនអាចផ្ទុកលេខសព្វថ្ងៃបានទេ';

  @override
  String get couldntLoadNumbersBody => 'មិនអាចផ្ទុកលេខសព្វថ្ងៃបានទេ។';

  @override
  String get approveDriverTitle => 'អនុម័តអ្នកបើកបរ';

  @override
  String approveDriverBody(String name) {
    return 'អនុម័ត $name? ពួកគេនឹងចាប់ផ្តើមទទួលសំណើរដំណើរ។';
  }

  @override
  String get suspendDriverTitle => 'ផ្អាកអ្នកបើកបរ';

  @override
  String suspendDriverBody(String name) {
    return 'ផ្អាក $name? គណនីរបស់ពួកគេនឹងត្រូវបានហាមឃាត់ពីការកក់ថ្មី។';
  }

  @override
  String get approveButton => 'អនុម័ត';

  @override
  String get suspendButton => 'ផ្អាក';

  @override
  String get chipPending => 'កំពុងរង់ចាំ';

  @override
  String get chipSuspended => 'បានផ្អាក';

  @override
  String get chipOnline => 'អនឡាញ';

  @override
  String get chipOffline => 'ក្រៅប្រព័ន្ធ';

  @override
  String get noDriversYetTitle => 'មិនទាន់មានអ្នកបើកបរ';

  @override
  String get noDriversHint =>
      'ប្រវត្តិរូបអ្នកបើកបរនឹងបង្ហាញនៅទីនេះ បន្ទាប់ពីពួកគេចុះឈ្មោះ។';

  @override
  String get couldntLoadDrivers => 'មិនអាចផ្ទុកអ្នកបើកបរបានទេ';

  @override
  String get noRidesHereTitle => 'គ្មានដំណើរនៅទីនេះ';

  @override
  String get noRidesFilterHint => 'គ្មានអ្វីត្រូវនឹងតម្រងនេះឥឡូវនេះទេ។';

  @override
  String get couldntLoadFeed => 'មិនអាចផ្ទុកបញ្ជីបានទេ';

  @override
  String get liveMapEmpty => 'ឥឡូវនេះគ្មានអ្នកបើកបរអនឡាញទេ';

  @override
  String get accountTitle => 'គណនី';

  @override
  String get signedInFallback => 'បានចូល';

  @override
  String get editProfileTooltip => 'កែសម្រួលប្រវត្តិរូប';

  @override
  String get changePasswordItem => 'ផ្លាស់ប្តូរពាក្យសម្ងាត់';

  @override
  String get changePasswordSubtitle =>
      'អ្នកនឹងត្រូវចូលម្តងទៀតដោយពាក្យសម្ងាត់ថ្មី';

  @override
  String get logoutButton => 'ចេញ';

  @override
  String get vehicleTitle => 'យានយន្ត';

  @override
  String get editVehicleTooltip => 'កែសម្រួលយានយន្ត';

  @override
  String get updateVehiclePhotoItem => 'បន្ទាន់សម័យរូបភាពយានយន្ត';

  @override
  String get addVehiclePhotosTooltip => 'បន្ថែមរូបភាព';

  @override
  String get licenseRow => 'អាជ្ញាបណ្ណ';

  @override
  String get noVehicleYet => 'មិនទាន់មានយានយន្ត';

  @override
  String get editProfileTitle => 'កែសម្រួលប្រវត្តិរូប';

  @override
  String get atLeast2Chars => 'យ៉ាងតិច 2 តួអក្សរ';

  @override
  String get enterYourPhone => 'សូមបញ្ចូលលេខទូរស័ព្ទរបស់អ្នក';

  @override
  String get saveChanges => 'រក្សាទុកការផ្លាស់ប្តូរ';

  @override
  String get currentPasswordLabel => 'ពាក្យសម្ងាត់បច្ចុប្បន្ន';

  @override
  String get newPasswordLabel => 'ពាក្យសម្ងាត់ថ្មី';

  @override
  String get confirmPasswordLabel => 'បញ្ជាក់ពាក្យសម្ងាត់ថ្មី';

  @override
  String get enterCurrentPassword => 'សូមបញ្ចូលពាក្យសម្ងាត់បច្ចុប្បន្ន';

  @override
  String get enterNewPassword => 'សូមបញ្ចូលពាក្យសម្ងាត់ថ្មី';

  @override
  String get atLeast8Chars => 'យ៉ាងតិច 8 តួអក្សរ';

  @override
  String get passwordsDontMatch => 'ពាក្យសម្ងាត់មិនត្រូវគ្នា';

  @override
  String get updatePassword => 'ធ្វើបច្ចុប្បន្នភាពពាក្យសម្ងាត់';

  @override
  String get currentPasswordIncorrect =>
      'ពាក្យសម្ងាត់បច្ចុប្បន្នរបស់អ្នកមិនត្រឹមត្រូវ។';

  @override
  String get passwordChangedRelogin =>
      'បានផ្លាស់ប្តូរពាក្យសម្ងាត់។ សូមចូលម្តងទៀត។';

  @override
  String get preferencesTitle => 'ចំណូលចិត្ត';

  @override
  String get darkModeLabel => 'រចនាបថងងឹត';

  @override
  String get languageLabel => 'ភាសា';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageKhmer => 'ខ្មែរ';

  @override
  String get errValidation => 'សូមពិនិត្យព័ត៌មានរបស់អ្នកម្តងទៀត។';

  @override
  String get errUnauthorized => 'សូមចូលម្តងទៀត។';

  @override
  String get errForbidden => 'អ្នកមិនមានសិទ្ធិធ្វើបែបនោះទេ។';

  @override
  String get errNotFound => 'យើងរកមិនឃើញទេ។';

  @override
  String get errRideInvalidTransition =>
      'ដំណើរនេះមិនអាចធ្វើបច្ចុប្បន្នភាពពីស្ថានភាពបច្ចុប្បន្នបានទេ។';

  @override
  String get errBusyDriver => 'អ្នកបើកបរនេះកំពុងរវលើ។ សូមសាកល្បងអ្នកផ្សេងទៀត។';

  @override
  String get errBusyCustomer => 'អ្នកមានដំណើរសកម្មរួចហើយ។';

  @override
  String get errNotVerified =>
      'គណនីរបស់អ្នកមិនទាន់ត្រូវបានផ្ទៀងផ្ទាត់ទេ។ សូមរង់ចាំការអនុម័ត។';

  @override
  String get errNetwork =>
      'មិនអាចទៅដល់ម៉ាស៊ីនមេបានទេ។ ម៉ាស៊ីនមេកំពុងដំណើរការឬ?';

  @override
  String get errGeneric => 'មានអ្វីមួយខុសប្រក្រតី។ សូមព្យាយាមម្តងទៀត។';

  @override
  String etaRow(String value) {
    return 'មកដល់ $value';
  }

  @override
  String get enterCarModel => 'សូមបញ្ចូលម៉ូដែលឡានរបស់អ្នក';

  @override
  String get enterPlate => 'សូមបញ្ចូលលេខផ្លាករបស់អ្នក';

  @override
  String get enterLicense => 'សូមបញ្ចូលអាជ្ញាបណ្ណរបស់អ្នក';

  @override
  String get pricePerKmDollarLabel => 'តម្លៃក្នុងមួយគម (\$)';

  @override
  String get enterValidPricePerKm => 'សូមបញ្ចូលតម្លៃក្នុងមួយគមត្រឹមត្រូវ';

  @override
  String get updateVehicleButton => 'ធ្វើបច្ចុប្បន្នភាពយានយន្ត';

  @override
  String vehiclePriceRow(String rate) {
    return '\$$rate / km';
  }

  @override
  String get month1 => 'មករា';

  @override
  String get month2 => 'កុម្ភៈ';

  @override
  String get month3 => 'មីនា';

  @override
  String get month4 => 'មេសា';

  @override
  String get month5 => 'ឧសភា';

  @override
  String get month6 => 'មិថុនា';

  @override
  String get month7 => 'កក្កដា';

  @override
  String get month8 => 'សីហា';

  @override
  String get month9 => 'កញ្ញា';

  @override
  String get month10 => 'តុលា';

  @override
  String get month11 => 'វិច្ឆិកា';

  @override
  String get month12 => 'ធ្នូ';
}
