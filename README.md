# RideLog - Bike Tracker App

A Flutter app to track daily bike odometer readings, fuel entries, and maintenance costs with automatic mileage calculation and detailed analytics.

## Features

### Core Tracking
- **Odometer Readings** - Add daily readings with auto-prefix calculation (enter last 4 digits, prefix auto-detected from current odometer)
- **Fuel Entries** - Enter amount paid + petrol rate, liters auto-calculated. Rate remembers last used value
- **Maintenance Logging** - Track service costs with categories (General Service, Washing, Other)
- **Edit & Delete** - Tap any entry to edit, swipe left to delete with confirmation

### Home Dashboard
- Current odometer with today's distance
- Distance stats: Today, Week, Month, Total
- Fuel efficiency: This Month + Overall (km/l)
- Fuel cost summary with cost per km
- Maintenance cost breakdown by category
- Service due reminder (>90 days or >3000 km)
- Monthly spending chart (last 6 months)
- Recent entries with "View All" link

### Analytics
- **Period Selector** - Week/Month toggle with navigation arrows
- **Distance Tab** - Daily bar chart, ride summary, comparison with previous period (% change)
- **Fuel Tab** - Mileage display (total km / total liters), fuel summary, fill-up history
- **Expenses Tab** - Pie chart (Fuel vs Maintenance), expense summary, all-time totals
- **Insights** - Best day, ride streak, longest streak, most active weekday, avg fuel price

### History
- Filter tabs: All / Odometer / Fuel / Service (with count badges)
- Entries grouped by date with daily distance totals
- Swipe to delete, tap to edit
- Each entry shows time, reading, notes

### Other Features
- **Dark Mode** - Follows system theme automatically
- **CSV Export** - Export all data as CSV with Share option
- **Note Suggestions** - Autocomplete from previous notes
- **Duplicate Warning** - Alerts if same reading exists for the same day
- **Auto-fill** - First entry of the day pre-fills previous day's last reading
- **Success Feedback** - Green snackbar on every save/update
- **Help Tooltip** - Explains the auto-prefix logic for odometer input

## Mileage Calculation

```
Month Mileage = Total distance in month / Total liters in month
Overall Mileage = Total distance (all time) / Total liters (all time)
```

## Tech Stack

- **Flutter** (Dart)
- **SQLite** (sqflite) - Local database
- **Provider** - State management
- **fl_chart** - Charts and graphs
- **share_plus** - CSV export sharing

## Project Structure

```
lib/
  main.dart                        # App entry, theme, navigation, FAB
  models/
    odometer_entry.dart            # Odometer reading model
    fuel_entry.dart                # Fuel entry model
    maintenance_entry.dart         # Maintenance entry model + categories
  services/
    database_service.dart          # SQLite CRUD operations
  providers/
    bike_provider.dart             # State management + computed analytics
  screens/
    home_screen.dart               # Dashboard
    analytics_screen.dart          # Charts + reports
    history_screen.dart            # Entry list with filters
  widgets/
    stat_card.dart                 # Reusable metric card
    add_odometer_sheet.dart        # Odometer entry form
    add_fuel_sheet.dart            # Fuel entry form
    add_maintenance_sheet.dart     # Maintenance entry form
  utils/
    app_colors.dart                # Theme-aware color system
```

## Build

```bash
# Debug
flutter run

# Release APK
flutter build apk --release
# Output: build/app/outputs/flutter-apk/app-release.apk

# Install on connected device
adb install -r build/app/outputs/flutter-apk/app-release.apk
```

## Version History

| Version | Description |
|---------|-------------|
| v1.0.0  | Initial release with CSV data import |
| v1.1.0  | Removed import logic, production ready |
