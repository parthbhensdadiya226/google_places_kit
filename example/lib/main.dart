import 'package:flutter/material.dart';
import 'package:google_places_kit/google_places_kit.dart';

import 'address_tab.dart';
import 'nearby_tab.dart';
import 'search_tab.dart';

/// Run with your key:
/// flutter run --dart-define=PLACES_API_KEY=your-api-key
const apiKey = String.fromEnvironment('PLACES_API_KEY');

void main() {
  // Once for the whole app. Every screen then uses GooglePlaces.instance,
  // and the widgets pick it up without a `places:` argument.
  if (apiKey.isNotEmpty) GooglePlaces.initialize(apiKey: apiKey);
  runApp(const PlacesKitApp());
}

class PlacesKitApp extends StatelessWidget {
  const PlacesKitApp({super.key});

  @override
  Widget build(BuildContext context) {
    ThemeData theme(Brightness brightness) => ThemeData(
      colorSchemeSeed: const Color(0xFF1A73E8),
      brightness: brightness,
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(),
      ),
    );
    return MaterialApp(
      title: 'Google Places Kit',
      debugShowCheckedModeBanner: false,
      theme: theme(Brightness.light),
      darkTheme: theme(Brightness.dark),
      home: apiKey.isEmpty ? const MissingKeyPage() : const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  var _tab = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Google Places Kit')),
      body: IndexedStack(
        index: _tab,
        children: const [SearchTab(), NearbyTab(), AddressTab()],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (tab) => setState(() => _tab = tab),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.search), label: 'Search'),
          NavigationDestination(
            icon: Icon(Icons.near_me_outlined),
            selectedIcon: Icon(Icons.near_me),
            label: 'Nearby',
          ),
          NavigationDestination(
            icon: Icon(Icons.pin_drop_outlined),
            selectedIcon: Icon(Icons.pin_drop),
            label: 'Address',
          ),
        ],
      ),
    );
  }
}

class MissingKeyPage extends StatelessWidget {
  const MissingKeyPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Google Places Kit')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Icon(
            Icons.key_off_outlined,
            size: 48,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(height: 16),
          Text('Add your API key', style: theme.textTheme.headlineSmall),
          const SizedBox(height: 8),
          const Text(
            'Create a key in Google Cloud Console with "Places API (New)" and '
            '"Geocoding API" enabled, then run the example with it:',
          ),
          const SizedBox(height: 12),
          const SelectableText(
            'flutter run --dart-define=PLACES_API_KEY=your-api-key',
            style: TextStyle(fontFamily: 'monospace'),
          ),
        ],
      ),
    );
  }
}
