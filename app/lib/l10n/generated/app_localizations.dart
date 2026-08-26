import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_km.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('km'),
  ];

  /// No description provided for @navDeck.
  ///
  /// In en, this message translates to:
  /// **'Deck'**
  String get navDeck;

  /// No description provided for @navHistory.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get navHistory;

  /// No description provided for @navAccount.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get navAccount;

  /// No description provided for @navHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get navHome;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @refresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get refresh;

  /// No description provided for @tryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get tryAgain;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @appTagline.
  ///
  /// In en, this message translates to:
  /// **'Ride smart. Go far.'**
  String get appTagline;

  /// No description provided for @emailLabel.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get emailLabel;

  /// No description provided for @passwordLabel.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get passwordLabel;

  /// No description provided for @enterEmail.
  ///
  /// In en, this message translates to:
  /// **'Enter your email'**
  String get enterEmail;

  /// No description provided for @enterValidEmail.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid email'**
  String get enterValidEmail;

  /// No description provided for @enterPassword.
  ///
  /// In en, this message translates to:
  /// **'Enter your password'**
  String get enterPassword;

  /// No description provided for @logIn.
  ///
  /// In en, this message translates to:
  /// **'Log in'**
  String get logIn;

  /// No description provided for @noAccountRegister.
  ///
  /// In en, this message translates to:
  /// **'No account? Register'**
  String get noAccountRegister;

  /// No description provided for @createAccountTitle.
  ///
  /// In en, this message translates to:
  /// **'Create account'**
  String get createAccountTitle;

  /// No description provided for @nameLabel.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get nameLabel;

  /// No description provided for @phoneLabel.
  ///
  /// In en, this message translates to:
  /// **'Phone'**
  String get phoneLabel;

  /// No description provided for @passwordMinLabel.
  ///
  /// In en, this message translates to:
  /// **'Password (min. 8 characters)'**
  String get passwordMinLabel;

  /// No description provided for @registerEnterEmail.
  ///
  /// In en, this message translates to:
  /// **'Enter an email'**
  String get registerEnterEmail;

  /// No description provided for @enterValidPhone.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid phone number'**
  String get enterValidPhone;

  /// No description provided for @enterName.
  ///
  /// In en, this message translates to:
  /// **'Enter your name'**
  String get enterName;

  /// No description provided for @passwordTooShort.
  ///
  /// In en, this message translates to:
  /// **'Password must be at least 8 characters'**
  String get passwordTooShort;

  /// No description provided for @roleCustomer.
  ///
  /// In en, this message translates to:
  /// **'Customer'**
  String get roleCustomer;

  /// No description provided for @roleDriver.
  ///
  /// In en, this message translates to:
  /// **'Driver'**
  String get roleDriver;

  /// No description provided for @roleAdmin.
  ///
  /// In en, this message translates to:
  /// **'Admin'**
  String get roleAdmin;

  /// No description provided for @alreadyHaveAccount.
  ///
  /// In en, this message translates to:
  /// **'Already have an account? Log in'**
  String get alreadyHaveAccount;

  /// No description provided for @greetingMorning.
  ///
  /// In en, this message translates to:
  /// **'Good morning'**
  String get greetingMorning;

  /// No description provided for @greetingAfternoon.
  ///
  /// In en, this message translates to:
  /// **'Good afternoon'**
  String get greetingAfternoon;

  /// No description provided for @greetingEvening.
  ///
  /// In en, this message translates to:
  /// **'Good evening'**
  String get greetingEvening;

  /// No description provided for @greetingWithName.
  ///
  /// In en, this message translates to:
  /// **'{part}, {name}'**
  String greetingWithName(String part, String name);

  /// No description provided for @findYourRide.
  ///
  /// In en, this message translates to:
  /// **'Find your ride below'**
  String get findYourRide;

  /// No description provided for @noDriversOnlineTitle.
  ///
  /// In en, this message translates to:
  /// **'No drivers online'**
  String get noDriversOnlineTitle;

  /// No description provided for @noDriversOnlineHint.
  ///
  /// In en, this message translates to:
  /// **'No drivers online right now — pull to refresh'**
  String get noDriversOnlineHint;

  /// No description provided for @driverFallback.
  ///
  /// In en, this message translates to:
  /// **'Driver'**
  String get driverFallback;

  /// No description provided for @etaMinutes.
  ///
  /// In en, this message translates to:
  /// **'{eta} min'**
  String etaMinutes(int eta);

  /// No description provided for @pricePerKmShort.
  ///
  /// In en, this message translates to:
  /// **'{rate} /km'**
  String pricePerKmShort(String rate);

  /// No description provided for @pickupLabel.
  ///
  /// In en, this message translates to:
  /// **'Pickup'**
  String get pickupLabel;

  /// No description provided for @dropoffLabel.
  ///
  /// In en, this message translates to:
  /// **'Dropoff'**
  String get dropoffLabel;

  /// No description provided for @pickupAddressLabel.
  ///
  /// In en, this message translates to:
  /// **'Pickup address'**
  String get pickupAddressLabel;

  /// No description provided for @dropoffAddressLabel.
  ///
  /// In en, this message translates to:
  /// **'Dropoff address'**
  String get dropoffAddressLabel;

  /// No description provided for @enterPickupAddress.
  ///
  /// In en, this message translates to:
  /// **'Enter a pickup address'**
  String get enterPickupAddress;

  /// No description provided for @enterDropoffAddress.
  ///
  /// In en, this message translates to:
  /// **'Enter a dropoff address'**
  String get enterDropoffAddress;

  /// No description provided for @confirmBooking.
  ///
  /// In en, this message translates to:
  /// **'Confirm booking'**
  String get confirmBooking;

  /// No description provided for @payCashNote.
  ///
  /// In en, this message translates to:
  /// **'Pay cash on arrival — agree the fare with your driver.'**
  String get payCashNote;

  /// No description provided for @waitingForDriver.
  ///
  /// In en, this message translates to:
  /// **'Waiting for your driver to respond…'**
  String get waitingForDriver;

  /// No description provided for @completedEmoji.
  ///
  /// In en, this message translates to:
  /// **'Completed 🎉'**
  String get completedEmoji;

  /// No description provided for @driverPassedNote.
  ///
  /// In en, this message translates to:
  /// **'The driver passed on your request'**
  String get driverPassedNote;

  /// No description provided for @rideCancelledNote.
  ///
  /// In en, this message translates to:
  /// **'Your ride was cancelled'**
  String get rideCancelledNote;

  /// No description provided for @cancelRide.
  ///
  /// In en, this message translates to:
  /// **'Cancel ride'**
  String get cancelRide;

  /// No description provided for @backToDeck.
  ///
  /// In en, this message translates to:
  /// **'Back to deck'**
  String get backToDeck;

  /// No description provided for @stepRequested.
  ///
  /// In en, this message translates to:
  /// **'Requested'**
  String get stepRequested;

  /// No description provided for @stepAccepted.
  ///
  /// In en, this message translates to:
  /// **'Accepted'**
  String get stepAccepted;

  /// No description provided for @stepEnRoute.
  ///
  /// In en, this message translates to:
  /// **'En route'**
  String get stepEnRoute;

  /// No description provided for @stepRiding.
  ///
  /// In en, this message translates to:
  /// **'Riding'**
  String get stepRiding;

  /// No description provided for @stepDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get stepDone;

  /// No description provided for @yourDriverFallback.
  ///
  /// In en, this message translates to:
  /// **'Your driver'**
  String get yourDriverFallback;

  /// No description provided for @kmEtaRow.
  ///
  /// In en, this message translates to:
  /// **'{km} km · {min} min ETA'**
  String kmEtaRow(String km, int min);

  /// No description provided for @yourRides.
  ///
  /// In en, this message translates to:
  /// **'Your rides'**
  String get yourRides;

  /// No description provided for @noRidesYetTitle.
  ///
  /// In en, this message translates to:
  /// **'No rides yet'**
  String get noRidesYetTitle;

  /// No description provided for @historyEmptyHint.
  ///
  /// In en, this message translates to:
  /// **'Your trips will show up here once you book or drive one.'**
  String get historyEmptyHint;

  /// No description provided for @couldntLoadRides.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load your rides'**
  String get couldntLoadRides;

  /// No description provided for @withDriver.
  ///
  /// In en, this message translates to:
  /// **'with {name}'**
  String withDriver(String name);

  /// No description provided for @forCustomer.
  ///
  /// In en, this message translates to:
  /// **'for {name}'**
  String forCustomer(String name);

  /// No description provided for @statusAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get statusAll;

  /// No description provided for @statusRequested.
  ///
  /// In en, this message translates to:
  /// **'Requested'**
  String get statusRequested;

  /// No description provided for @statusAccepted.
  ///
  /// In en, this message translates to:
  /// **'Accepted'**
  String get statusAccepted;

  /// No description provided for @statusEnRoute.
  ///
  /// In en, this message translates to:
  /// **'En Route'**
  String get statusEnRoute;

  /// No description provided for @statusInProgress.
  ///
  /// In en, this message translates to:
  /// **'In Progress'**
  String get statusInProgress;

  /// No description provided for @statusCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get statusCompleted;

  /// No description provided for @statusCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get statusCancelled;

  /// No description provided for @statusDeclined.
  ///
  /// In en, this message translates to:
  /// **'Declined'**
  String get statusDeclined;

  /// No description provided for @rateYourTrip.
  ///
  /// In en, this message translates to:
  /// **'Rate your trip'**
  String get rateYourTrip;

  /// No description provided for @yourRiderFallback.
  ///
  /// In en, this message translates to:
  /// **'Your rider'**
  String get yourRiderFallback;

  /// No description provided for @howWasTrip.
  ///
  /// In en, this message translates to:
  /// **'How was your trip?'**
  String get howWasTrip;

  /// No description provided for @howWasTripWith.
  ///
  /// In en, this message translates to:
  /// **'How was your trip with {name}?'**
  String howWasTripWith(String name);

  /// No description provided for @submitRating.
  ///
  /// In en, this message translates to:
  /// **'Submit'**
  String get submitRating;

  /// No description provided for @thanksTitle.
  ///
  /// In en, this message translates to:
  /// **'Thanks!'**
  String get thanksTitle;

  /// No description provided for @alreadyRatedNote.
  ///
  /// In en, this message translates to:
  /// **'You already rated this ride.'**
  String get alreadyRatedNote;

  /// No description provided for @ratingHelpsNote.
  ///
  /// In en, this message translates to:
  /// **'Your rating helps everyone ride safer.'**
  String get ratingHelpsNote;

  /// No description provided for @doneButton.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get doneButton;

  /// No description provided for @couldntLoadRide.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load this ride'**
  String get couldntLoadRide;

  /// No description provided for @motoDubDriverTitle.
  ///
  /// In en, this message translates to:
  /// **'MotoDub Driver'**
  String get motoDubDriverTitle;

  /// No description provided for @youAreOnline.
  ///
  /// In en, this message translates to:
  /// **'You\'re online'**
  String get youAreOnline;

  /// No description provided for @youAreOffline.
  ///
  /// In en, this message translates to:
  /// **'You\'re offline'**
  String get youAreOffline;

  /// No description provided for @receivingRequests.
  ///
  /// In en, this message translates to:
  /// **'Receiving ride requests'**
  String get receivingRequests;

  /// No description provided for @goOnlineHint.
  ///
  /// In en, this message translates to:
  /// **'Go online to receive requests'**
  String get goOnlineHint;

  /// No description provided for @verifiedChip.
  ///
  /// In en, this message translates to:
  /// **'Verified'**
  String get verifiedChip;

  /// No description provided for @pendingReviewChip.
  ///
  /// In en, this message translates to:
  /// **'Pending review'**
  String get pendingReviewChip;

  /// No description provided for @setupVehicleTitle.
  ///
  /// In en, this message translates to:
  /// **'Set up your vehicle'**
  String get setupVehicleTitle;

  /// No description provided for @setupVehicleSubtitle.
  ///
  /// In en, this message translates to:
  /// **'One profile per driver — admin review follows.'**
  String get setupVehicleSubtitle;

  /// No description provided for @carModelLabel.
  ///
  /// In en, this message translates to:
  /// **'Car model'**
  String get carModelLabel;

  /// No description provided for @plateLabel.
  ///
  /// In en, this message translates to:
  /// **'Plate'**
  String get plateLabel;

  /// No description provided for @licenseNoLabel.
  ///
  /// In en, this message translates to:
  /// **'License no'**
  String get licenseNoLabel;

  /// No description provided for @pricePerKmLabel.
  ///
  /// In en, this message translates to:
  /// **'Price per km'**
  String get pricePerKmLabel;

  /// No description provided for @requiredField.
  ///
  /// In en, this message translates to:
  /// **'Required'**
  String get requiredField;

  /// No description provided for @enterNumber.
  ///
  /// In en, this message translates to:
  /// **'Enter a number'**
  String get enterNumber;

  /// No description provided for @saveVehicle.
  ///
  /// In en, this message translates to:
  /// **'Save vehicle'**
  String get saveVehicle;

  /// No description provided for @todayTitle.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get todayTitle;

  /// No description provided for @ridesDoneLabel.
  ///
  /// In en, this message translates to:
  /// **'Rides done'**
  String get ridesDoneLabel;

  /// No description provided for @avgRatingLabel.
  ///
  /// In en, this message translates to:
  /// **'Avg rating'**
  String get avgRatingLabel;

  /// No description provided for @recentActivityTitle.
  ///
  /// In en, this message translates to:
  /// **'Recent activity'**
  String get recentActivityTitle;

  /// No description provided for @justNow.
  ///
  /// In en, this message translates to:
  /// **'just now'**
  String get justNow;

  /// No description provided for @minutesAgo.
  ///
  /// In en, this message translates to:
  /// **'{n}m ago'**
  String minutesAgo(int n);

  /// No description provided for @hoursAgo.
  ///
  /// In en, this message translates to:
  /// **'{n}h ago'**
  String hoursAgo(int n);

  /// No description provided for @activityEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No rides yet'**
  String get activityEmptyTitle;

  /// No description provided for @activityEmptyHint.
  ///
  /// In en, this message translates to:
  /// **'Your completed trips will show up here.'**
  String get activityEmptyHint;

  /// No description provided for @couldntLoadDashboard.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load your dashboard'**
  String get couldntLoadDashboard;

  /// No description provided for @couldntLoadActivity.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load your activity.'**
  String get couldntLoadActivity;

  /// No description provided for @customerFallback.
  ///
  /// In en, this message translates to:
  /// **'Customer'**
  String get customerFallback;

  /// No description provided for @kmPill.
  ///
  /// In en, this message translates to:
  /// **'{km} km'**
  String kmPill(String km);

  /// No description provided for @acceptButton.
  ///
  /// In en, this message translates to:
  /// **'Accept'**
  String get acceptButton;

  /// No description provided for @declineButton.
  ///
  /// In en, this message translates to:
  /// **'Decline'**
  String get declineButton;

  /// No description provided for @onMyWayCta.
  ///
  /// In en, this message translates to:
  /// **'On my way'**
  String get onMyWayCta;

  /// No description provided for @startRideCta.
  ///
  /// In en, this message translates to:
  /// **'Start ride'**
  String get startRideCta;

  /// No description provided for @endRideCta.
  ///
  /// In en, this message translates to:
  /// **'End ride ✓'**
  String get endRideCta;

  /// No description provided for @adminTag.
  ///
  /// In en, this message translates to:
  /// **'ADMIN'**
  String get adminTag;

  /// No description provided for @navDashboard.
  ///
  /// In en, this message translates to:
  /// **'Dashboard'**
  String get navDashboard;

  /// No description provided for @navDrivers.
  ///
  /// In en, this message translates to:
  /// **'Drivers'**
  String get navDrivers;

  /// No description provided for @navRides.
  ///
  /// In en, this message translates to:
  /// **'Rides'**
  String get navRides;

  /// No description provided for @navLiveMap.
  ///
  /// In en, this message translates to:
  /// **'Live Map'**
  String get navLiveMap;

  /// No description provided for @kpiLiveRides.
  ///
  /// In en, this message translates to:
  /// **'Live rides'**
  String get kpiLiveRides;

  /// No description provided for @kpiOnlineDrivers.
  ///
  /// In en, this message translates to:
  /// **'Online drivers'**
  String get kpiOnlineDrivers;

  /// No description provided for @kpiCompletedToday.
  ///
  /// In en, this message translates to:
  /// **'Completed today'**
  String get kpiCompletedToday;

  /// No description provided for @kpiAvgRatingCard.
  ///
  /// In en, this message translates to:
  /// **'Avg rating'**
  String get kpiAvgRatingCard;

  /// No description provided for @couldntLoadNumbersTitle.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load today\'s numbers'**
  String get couldntLoadNumbersTitle;

  /// No description provided for @couldntLoadNumbersBody.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load today\'s numbers.'**
  String get couldntLoadNumbersBody;

  /// No description provided for @approveDriverTitle.
  ///
  /// In en, this message translates to:
  /// **'Approve driver'**
  String get approveDriverTitle;

  /// No description provided for @approveDriverBody.
  ///
  /// In en, this message translates to:
  /// **'Approve {name}? They will start receiving ride requests.'**
  String approveDriverBody(String name);

  /// No description provided for @suspendDriverTitle.
  ///
  /// In en, this message translates to:
  /// **'Suspend driver'**
  String get suspendDriverTitle;

  /// No description provided for @suspendDriverBody.
  ///
  /// In en, this message translates to:
  /// **'Suspend {name}? Their account will be blocked from new bookings.'**
  String suspendDriverBody(String name);

  /// No description provided for @approveButton.
  ///
  /// In en, this message translates to:
  /// **'Approve'**
  String get approveButton;

  /// No description provided for @suspendButton.
  ///
  /// In en, this message translates to:
  /// **'Suspend'**
  String get suspendButton;

  /// No description provided for @chipPending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get chipPending;

  /// No description provided for @chipSuspended.
  ///
  /// In en, this message translates to:
  /// **'Suspended'**
  String get chipSuspended;

  /// No description provided for @chipOnline.
  ///
  /// In en, this message translates to:
  /// **'Online'**
  String get chipOnline;

  /// No description provided for @chipOffline.
  ///
  /// In en, this message translates to:
  /// **'Offline'**
  String get chipOffline;

  /// No description provided for @noDriversYetTitle.
  ///
  /// In en, this message translates to:
  /// **'No drivers yet'**
  String get noDriversYetTitle;

  /// No description provided for @noDriversHint.
  ///
  /// In en, this message translates to:
  /// **'Driver profiles will show up here once they sign up.'**
  String get noDriversHint;

  /// No description provided for @couldntLoadDrivers.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load drivers'**
  String get couldntLoadDrivers;

  /// No description provided for @noRidesHereTitle.
  ///
  /// In en, this message translates to:
  /// **'No rides here'**
  String get noRidesHereTitle;

  /// No description provided for @noRidesFilterHint.
  ///
  /// In en, this message translates to:
  /// **'Nothing matches this filter right now.'**
  String get noRidesFilterHint;

  /// No description provided for @couldntLoadFeed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load the feed'**
  String get couldntLoadFeed;

  /// No description provided for @liveMapEmpty.
  ///
  /// In en, this message translates to:
  /// **'No online drivers right now'**
  String get liveMapEmpty;

  /// No description provided for @accountTitle.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get accountTitle;

  /// No description provided for @signedInFallback.
  ///
  /// In en, this message translates to:
  /// **'Signed in'**
  String get signedInFallback;

  /// No description provided for @editProfileTooltip.
  ///
  /// In en, this message translates to:
  /// **'Edit profile'**
  String get editProfileTooltip;

  /// No description provided for @changePasswordItem.
  ///
  /// In en, this message translates to:
  /// **'Change password'**
  String get changePasswordItem;

  /// No description provided for @changePasswordSubtitle.
  ///
  /// In en, this message translates to:
  /// **'You\'ll log in again with the new one'**
  String get changePasswordSubtitle;

  /// No description provided for @logoutButton.
  ///
  /// In en, this message translates to:
  /// **'Log out'**
  String get logoutButton;

  /// No description provided for @vehicleTitle.
  ///
  /// In en, this message translates to:
  /// **'Vehicle'**
  String get vehicleTitle;

  /// No description provided for @editVehicleTooltip.
  ///
  /// In en, this message translates to:
  /// **'Edit vehicle'**
  String get editVehicleTooltip;

  /// No description provided for @updateVehiclePhotoItem.
  ///
  /// In en, this message translates to:
  /// **'Update vehicle photo'**
  String get updateVehiclePhotoItem;

  /// No description provided for @addVehiclePhotosTooltip.
  ///
  /// In en, this message translates to:
  /// **'Add photos'**
  String get addVehiclePhotosTooltip;

  /// No description provided for @licenseRow.
  ///
  /// In en, this message translates to:
  /// **'License'**
  String get licenseRow;

  /// No description provided for @noVehicleYet.
  ///
  /// In en, this message translates to:
  /// **'No vehicle yet'**
  String get noVehicleYet;

  /// No description provided for @editProfileTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit profile'**
  String get editProfileTitle;

  /// No description provided for @atLeast2Chars.
  ///
  /// In en, this message translates to:
  /// **'At least 2 characters'**
  String get atLeast2Chars;

  /// No description provided for @enterYourPhone.
  ///
  /// In en, this message translates to:
  /// **'Enter your phone number'**
  String get enterYourPhone;

  /// No description provided for @saveChanges.
  ///
  /// In en, this message translates to:
  /// **'Save changes'**
  String get saveChanges;

  /// No description provided for @currentPasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'Current password'**
  String get currentPasswordLabel;

  /// No description provided for @newPasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'New password'**
  String get newPasswordLabel;

  /// No description provided for @confirmPasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'Confirm new password'**
  String get confirmPasswordLabel;

  /// No description provided for @enterCurrentPassword.
  ///
  /// In en, this message translates to:
  /// **'Enter your current password'**
  String get enterCurrentPassword;

  /// No description provided for @enterNewPassword.
  ///
  /// In en, this message translates to:
  /// **'Enter a new password'**
  String get enterNewPassword;

  /// No description provided for @atLeast8Chars.
  ///
  /// In en, this message translates to:
  /// **'At least 8 characters'**
  String get atLeast8Chars;

  /// No description provided for @passwordsDontMatch.
  ///
  /// In en, this message translates to:
  /// **'Passwords don\'t match'**
  String get passwordsDontMatch;

  /// No description provided for @updatePassword.
  ///
  /// In en, this message translates to:
  /// **'Update password'**
  String get updatePassword;

  /// No description provided for @currentPasswordIncorrect.
  ///
  /// In en, this message translates to:
  /// **'Your current password is incorrect.'**
  String get currentPasswordIncorrect;

  /// No description provided for @passwordChangedRelogin.
  ///
  /// In en, this message translates to:
  /// **'Password changed. Please log in again.'**
  String get passwordChangedRelogin;

  /// No description provided for @preferencesTitle.
  ///
  /// In en, this message translates to:
  /// **'Preferences'**
  String get preferencesTitle;

  /// No description provided for @darkModeLabel.
  ///
  /// In en, this message translates to:
  /// **'Dark mode'**
  String get darkModeLabel;

  /// No description provided for @languageLabel.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get languageLabel;

  /// No description provided for @languageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @languageKhmer.
  ///
  /// In en, this message translates to:
  /// **'ខ្មែរ'**
  String get languageKhmer;

  /// No description provided for @errValidation.
  ///
  /// In en, this message translates to:
  /// **'Please check your details and try again.'**
  String get errValidation;

  /// No description provided for @errUnauthorized.
  ///
  /// In en, this message translates to:
  /// **'Please log in again.'**
  String get errUnauthorized;

  /// No description provided for @errForbidden.
  ///
  /// In en, this message translates to:
  /// **'You don\'t have permission to do that.'**
  String get errForbidden;

  /// No description provided for @errNotFound.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t find that.'**
  String get errNotFound;

  /// No description provided for @errRideInvalidTransition.
  ///
  /// In en, this message translates to:
  /// **'That ride can\'t be updated from its current state.'**
  String get errRideInvalidTransition;

  /// No description provided for @errBusyDriver.
  ///
  /// In en, this message translates to:
  /// **'This driver is busy right now. Try another one.'**
  String get errBusyDriver;

  /// No description provided for @errBusyCustomer.
  ///
  /// In en, this message translates to:
  /// **'You already have an active ride.'**
  String get errBusyCustomer;

  /// No description provided for @errNotVerified.
  ///
  /// In en, this message translates to:
  /// **'Your account isn\'t verified yet. Please wait for approval.'**
  String get errNotVerified;

  /// No description provided for @errNetwork.
  ///
  /// In en, this message translates to:
  /// **'Cannot reach server. Is the backend running?'**
  String get errNetwork;

  /// No description provided for @errGeneric.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again.'**
  String get errGeneric;

  /// No description provided for @etaRow.
  ///
  /// In en, this message translates to:
  /// **'ETA {value}'**
  String etaRow(String value);

  /// No description provided for @enterCarModel.
  ///
  /// In en, this message translates to:
  /// **'Enter your car model'**
  String get enterCarModel;

  /// No description provided for @enterPlate.
  ///
  /// In en, this message translates to:
  /// **'Enter your plate'**
  String get enterPlate;

  /// No description provided for @enterLicense.
  ///
  /// In en, this message translates to:
  /// **'Enter your license'**
  String get enterLicense;

  /// No description provided for @pricePerKmDollarLabel.
  ///
  /// In en, this message translates to:
  /// **'Price per km (\$)'**
  String get pricePerKmDollarLabel;

  /// No description provided for @enterValidPricePerKm.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid price per km'**
  String get enterValidPricePerKm;

  /// No description provided for @updateVehicleButton.
  ///
  /// In en, this message translates to:
  /// **'Update vehicle'**
  String get updateVehicleButton;

  /// No description provided for @vehiclePriceRow.
  ///
  /// In en, this message translates to:
  /// **'\${rate} / km'**
  String vehiclePriceRow(String rate);

  /// No description provided for @botsCardTitle.
  ///
  /// In en, this message translates to:
  /// **'Bot fleet'**
  String get botsCardTitle;

  /// No description provided for @botsRunning.
  ///
  /// In en, this message translates to:
  /// **'Running'**
  String get botsRunning;

  /// No description provided for @botsStopped.
  ///
  /// In en, this message translates to:
  /// **'Stopped'**
  String get botsStopped;

  /// No description provided for @botsPairsLabel.
  ///
  /// In en, this message translates to:
  /// **'Bot pairs'**
  String get botsPairsLabel;

  /// No description provided for @botsStartButton.
  ///
  /// In en, this message translates to:
  /// **'Start bots'**
  String get botsStartButton;

  /// No description provided for @botsStopButton.
  ///
  /// In en, this message translates to:
  /// **'Stop bots'**
  String get botsStopButton;

  /// No description provided for @botsUptimeLabel.
  ///
  /// In en, this message translates to:
  /// **'Uptime'**
  String get botsUptimeLabel;

  /// No description provided for @botsRidesLabel.
  ///
  /// In en, this message translates to:
  /// **'Rides spawned'**
  String get botsRidesLabel;

  /// No description provided for @botsLastRideLabel.
  ///
  /// In en, this message translates to:
  /// **'Last ride'**
  String get botsLastRideLabel;

  /// No description provided for @editDriverTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit driver'**
  String get editDriverTitle;

  /// No description provided for @month1.
  ///
  /// In en, this message translates to:
  /// **'Jan'**
  String get month1;

  /// No description provided for @month2.
  ///
  /// In en, this message translates to:
  /// **'Feb'**
  String get month2;

  /// No description provided for @month3.
  ///
  /// In en, this message translates to:
  /// **'Mar'**
  String get month3;

  /// No description provided for @month4.
  ///
  /// In en, this message translates to:
  /// **'Apr'**
  String get month4;

  /// No description provided for @month5.
  ///
  /// In en, this message translates to:
  /// **'May'**
  String get month5;

  /// No description provided for @month6.
  ///
  /// In en, this message translates to:
  /// **'Jun'**
  String get month6;

  /// No description provided for @month7.
  ///
  /// In en, this message translates to:
  /// **'Jul'**
  String get month7;

  /// No description provided for @month8.
  ///
  /// In en, this message translates to:
  /// **'Aug'**
  String get month8;

  /// No description provided for @month9.
  ///
  /// In en, this message translates to:
  /// **'Sep'**
  String get month9;

  /// No description provided for @month10.
  ///
  /// In en, this message translates to:
  /// **'Oct'**
  String get month10;

  /// No description provided for @month11.
  ///
  /// In en, this message translates to:
  /// **'Nov'**
  String get month11;

  /// No description provided for @month12.
  ///
  /// In en, this message translates to:
  /// **'Dec'**
  String get month12;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'km'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'km':
      return AppLocalizationsKm();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
