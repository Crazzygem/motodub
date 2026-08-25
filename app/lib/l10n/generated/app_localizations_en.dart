// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get navDeck => 'Deck';

  @override
  String get navHistory => 'History';

  @override
  String get navAccount => 'Account';

  @override
  String get navHome => 'Home';

  @override
  String get retry => 'Retry';

  @override
  String get refresh => 'Refresh';

  @override
  String get tryAgain => 'Try again';

  @override
  String get cancel => 'Cancel';

  @override
  String get appTagline => 'Ride smart. Go far.';

  @override
  String get emailLabel => 'Email';

  @override
  String get passwordLabel => 'Password';

  @override
  String get enterEmail => 'Enter your email';

  @override
  String get enterValidEmail => 'Enter a valid email';

  @override
  String get enterPassword => 'Enter your password';

  @override
  String get logIn => 'Log in';

  @override
  String get noAccountRegister => 'No account? Register';

  @override
  String get createAccountTitle => 'Create account';

  @override
  String get nameLabel => 'Name';

  @override
  String get phoneLabel => 'Phone';

  @override
  String get passwordMinLabel => 'Password (min. 8 characters)';

  @override
  String get registerEnterEmail => 'Enter an email';

  @override
  String get enterValidPhone => 'Enter a valid phone number';

  @override
  String get enterName => 'Enter your name';

  @override
  String get passwordTooShort => 'Password must be at least 8 characters';

  @override
  String get roleCustomer => 'Customer';

  @override
  String get roleDriver => 'Driver';

  @override
  String get roleAdmin => 'Admin';

  @override
  String get alreadyHaveAccount => 'Already have an account? Log in';

  @override
  String get greetingMorning => 'Good morning';

  @override
  String get greetingAfternoon => 'Good afternoon';

  @override
  String get greetingEvening => 'Good evening';

  @override
  String greetingWithName(String part, String name) {
    return '$part, $name';
  }

  @override
  String get findYourRide => 'Find your ride below';

  @override
  String get hintSwipeRightBook => 'Swipe right to book';

  @override
  String get hintLeftPass => 'Left to pass';

  @override
  String get bookStamp => 'BOOK';

  @override
  String get passStamp => 'PASS';

  @override
  String get noDriversOnlineTitle => 'No drivers online';

  @override
  String get noDriversOnlineHint =>
      'No drivers online right now — pull to refresh';

  @override
  String get driverFallback => 'Driver';

  @override
  String etaMinutes(int eta) {
    return '$eta min';
  }

  @override
  String pricePerKmShort(String rate) {
    return '$rate /km';
  }

  @override
  String get pickupLabel => 'Pickup';

  @override
  String get dropoffLabel => 'Dropoff';

  @override
  String get pickupAddressLabel => 'Pickup address';

  @override
  String get dropoffAddressLabel => 'Dropoff address';

  @override
  String get enterPickupAddress => 'Enter a pickup address';

  @override
  String get enterDropoffAddress => 'Enter a dropoff address';

  @override
  String get confirmBooking => 'Confirm booking';

  @override
  String get payCashNote =>
      'Pay cash on arrival — agree the fare with your driver.';

  @override
  String get waitingForDriver => 'Waiting for your driver to respond…';

  @override
  String get completedEmoji => 'Completed 🎉';

  @override
  String get driverPassedNote => 'The driver passed on your request';

  @override
  String get rideCancelledNote => 'Your ride was cancelled';

  @override
  String get cancelRide => 'Cancel ride';

  @override
  String get backToDeck => 'Back to deck';

  @override
  String get stepRequested => 'Requested';

  @override
  String get stepAccepted => 'Accepted';

  @override
  String get stepEnRoute => 'En route';

  @override
  String get stepRiding => 'Riding';

  @override
  String get stepDone => 'Done';

  @override
  String get yourDriverFallback => 'Your driver';

  @override
  String kmEtaRow(String km, int min) {
    return '$km km · $min min ETA';
  }

  @override
  String get yourRides => 'Your rides';

  @override
  String get noRidesYetTitle => 'No rides yet';

  @override
  String get historyEmptyHint =>
      'Your trips will show up here once you book or drive one.';

  @override
  String get couldntLoadRides => 'Couldn\'t load your rides';

  @override
  String withDriver(String name) {
    return 'with $name';
  }

  @override
  String forCustomer(String name) {
    return 'for $name';
  }

  @override
  String get statusAll => 'All';

  @override
  String get statusRequested => 'Requested';

  @override
  String get statusAccepted => 'Accepted';

  @override
  String get statusEnRoute => 'En Route';

  @override
  String get statusInProgress => 'In Progress';

  @override
  String get statusCompleted => 'Completed';

  @override
  String get statusCancelled => 'Cancelled';

  @override
  String get statusDeclined => 'Declined';

  @override
  String get rateYourTrip => 'Rate your trip';

  @override
  String get yourRiderFallback => 'Your rider';

  @override
  String get howWasTrip => 'How was your trip?';

  @override
  String howWasTripWith(String name) {
    return 'How was your trip with $name?';
  }

  @override
  String get submitRating => 'Submit';

  @override
  String get thanksTitle => 'Thanks!';

  @override
  String get alreadyRatedNote => 'You already rated this ride.';

  @override
  String get ratingHelpsNote => 'Your rating helps everyone ride safer.';

  @override
  String get doneButton => 'Done';

  @override
  String get couldntLoadRide => 'Couldn\'t load this ride';

  @override
  String get motoDubDriverTitle => 'MotoDub Driver';

  @override
  String get youAreOnline => 'You\'re online';

  @override
  String get youAreOffline => 'You\'re offline';

  @override
  String get receivingRequests => 'Receiving ride requests';

  @override
  String get goOnlineHint => 'Go online to receive requests';

  @override
  String get verifiedChip => 'Verified';

  @override
  String get pendingReviewChip => 'Pending review';

  @override
  String get setupVehicleTitle => 'Set up your vehicle';

  @override
  String get setupVehicleSubtitle =>
      'One profile per driver — admin review follows.';

  @override
  String get carModelLabel => 'Car model';

  @override
  String get plateLabel => 'Plate';

  @override
  String get licenseNoLabel => 'License no';

  @override
  String get pricePerKmLabel => 'Price per km';

  @override
  String get requiredField => 'Required';

  @override
  String get enterNumber => 'Enter a number';

  @override
  String get saveVehicle => 'Save vehicle';

  @override
  String get todayTitle => 'Today';

  @override
  String get ridesDoneLabel => 'Rides done';

  @override
  String get avgRatingLabel => 'Avg rating';

  @override
  String get recentActivityTitle => 'Recent activity';

  @override
  String get justNow => 'just now';

  @override
  String minutesAgo(int n) {
    return '${n}m ago';
  }

  @override
  String hoursAgo(int n) {
    return '${n}h ago';
  }

  @override
  String get activityEmptyTitle => 'No rides yet';

  @override
  String get activityEmptyHint => 'Your completed trips will show up here.';

  @override
  String get couldntLoadDashboard => 'Couldn\'t load your dashboard';

  @override
  String get couldntLoadActivity => 'Couldn\'t load your activity.';

  @override
  String get customerFallback => 'Customer';

  @override
  String kmPill(String km) {
    return '$km km';
  }

  @override
  String get acceptButton => 'Accept';

  @override
  String get declineButton => 'Decline';

  @override
  String get onMyWayCta => 'On my way';

  @override
  String get startRideCta => 'Start ride';

  @override
  String get endRideCta => 'End ride ✓';

  @override
  String get adminTag => 'ADMIN';

  @override
  String get navDashboard => 'Dashboard';

  @override
  String get navDrivers => 'Drivers';

  @override
  String get navRides => 'Rides';

  @override
  String get navLiveMap => 'Live Map';

  @override
  String get kpiLiveRides => 'Live rides';

  @override
  String get kpiOnlineDrivers => 'Online drivers';

  @override
  String get kpiCompletedToday => 'Completed today';

  @override
  String get kpiAvgRatingCard => 'Avg rating';

  @override
  String get couldntLoadNumbersTitle => 'Couldn\'t load today\'s numbers';

  @override
  String get couldntLoadNumbersBody => 'Couldn\'t load today\'s numbers.';

  @override
  String get approveDriverTitle => 'Approve driver';

  @override
  String approveDriverBody(String name) {
    return 'Approve $name? They will start receiving ride requests.';
  }

  @override
  String get suspendDriverTitle => 'Suspend driver';

  @override
  String suspendDriverBody(String name) {
    return 'Suspend $name? Their account will be blocked from new bookings.';
  }

  @override
  String get approveButton => 'Approve';

  @override
  String get suspendButton => 'Suspend';

  @override
  String get chipPending => 'Pending';

  @override
  String get chipSuspended => 'Suspended';

  @override
  String get chipOnline => 'Online';

  @override
  String get chipOffline => 'Offline';

  @override
  String get noDriversYetTitle => 'No drivers yet';

  @override
  String get noDriversHint =>
      'Driver profiles will show up here once they sign up.';

  @override
  String get couldntLoadDrivers => 'Couldn\'t load drivers';

  @override
  String get noRidesHereTitle => 'No rides here';

  @override
  String get noRidesFilterHint => 'Nothing matches this filter right now.';

  @override
  String get couldntLoadFeed => 'Couldn\'t load the feed';

  @override
  String get liveMapEmpty => 'No online drivers right now';

  @override
  String get accountTitle => 'Account';

  @override
  String get signedInFallback => 'Signed in';

  @override
  String get editProfileTooltip => 'Edit profile';

  @override
  String get changePasswordItem => 'Change password';

  @override
  String get changePasswordSubtitle => 'You\'ll log in again with the new one';

  @override
  String get logoutButton => 'Log out';

  @override
  String get vehicleTitle => 'Vehicle';

  @override
  String get editVehicleTooltip => 'Edit vehicle';

  @override
  String get updateVehiclePhotoItem => 'Update vehicle photo';

  @override
  String get addVehiclePhotosTooltip => 'Add photos';

  @override
  String get licenseRow => 'License';

  @override
  String get noVehicleYet => 'No vehicle yet';

  @override
  String get editProfileTitle => 'Edit profile';

  @override
  String get atLeast2Chars => 'At least 2 characters';

  @override
  String get enterYourPhone => 'Enter your phone number';

  @override
  String get saveChanges => 'Save changes';

  @override
  String get currentPasswordLabel => 'Current password';

  @override
  String get newPasswordLabel => 'New password';

  @override
  String get confirmPasswordLabel => 'Confirm new password';

  @override
  String get enterCurrentPassword => 'Enter your current password';

  @override
  String get enterNewPassword => 'Enter a new password';

  @override
  String get atLeast8Chars => 'At least 8 characters';

  @override
  String get passwordsDontMatch => 'Passwords don\'t match';

  @override
  String get updatePassword => 'Update password';

  @override
  String get currentPasswordIncorrect => 'Your current password is incorrect.';

  @override
  String get passwordChangedRelogin => 'Password changed. Please log in again.';

  @override
  String get preferencesTitle => 'Preferences';

  @override
  String get darkModeLabel => 'Dark mode';

  @override
  String get languageLabel => 'Language';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageKhmer => 'ខ្មែរ';

  @override
  String get errValidation => 'Please check your details and try again.';

  @override
  String get errUnauthorized => 'Please log in again.';

  @override
  String get errForbidden => 'You don\'t have permission to do that.';

  @override
  String get errNotFound => 'We couldn\'t find that.';

  @override
  String get errRideInvalidTransition =>
      'That ride can\'t be updated from its current state.';

  @override
  String get errBusyDriver => 'This driver is busy right now. Try another one.';

  @override
  String get errBusyCustomer => 'You already have an active ride.';

  @override
  String get errNotVerified =>
      'Your account isn\'t verified yet. Please wait for approval.';

  @override
  String get errNetwork => 'Cannot reach server. Is the backend running?';

  @override
  String get errGeneric => 'Something went wrong. Please try again.';

  @override
  String etaRow(String value) {
    return 'ETA $value';
  }

  @override
  String get enterCarModel => 'Enter your car model';

  @override
  String get enterPlate => 'Enter your plate';

  @override
  String get enterLicense => 'Enter your license';

  @override
  String get pricePerKmDollarLabel => 'Price per km (\$)';

  @override
  String get enterValidPricePerKm => 'Enter a valid price per km';

  @override
  String get updateVehicleButton => 'Update vehicle';

  @override
  String vehiclePriceRow(String rate) {
    return '\$$rate / km';
  }

  @override
  String get month1 => 'Jan';

  @override
  String get month2 => 'Feb';

  @override
  String get month3 => 'Mar';

  @override
  String get month4 => 'Apr';

  @override
  String get month5 => 'May';

  @override
  String get month6 => 'Jun';

  @override
  String get month7 => 'Jul';

  @override
  String get month8 => 'Aug';

  @override
  String get month9 => 'Sep';

  @override
  String get month10 => 'Oct';

  @override
  String get month11 => 'Nov';

  @override
  String get month12 => 'Dec';
}
