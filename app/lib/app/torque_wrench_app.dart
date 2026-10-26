import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../domain/models.dart';
import '../ui/forms/form_view_models.dart';
import '../ui/forms/form_views.dart';
import '../ui/garage/garage_views.dart';
import 'composition.dart';

class const TorqueWrenchApp({super.key, required final Composition composition})
    extends StatefulWidget {
  @override
  State<TorqueWrenchApp> createState() => _TorqueWrenchAppState();
}

class _TorqueWrenchAppState() extends State<TorqueWrenchApp> {
  late final router = TorqueRouter(widget.composition);
  @override
  void initState() {
    super.initState();
    widget.composition.session.restore();
  }

  @override
  void dispose() {
    router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp.router(
    title: 'TorqueWrench',
    builder: (context, child) => CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyO, control: true, alt: true):
            widget.composition.toggleOffline,
        const SingleActivator(LogicalKeyboardKey.keyF, control: true, alt: true):
            widget.composition.toggleSaveFailure,
        const SingleActivator(LogicalKeyboardKey.keyE, control: true, alt: true):
            widget.composition.session.expire,
      },
      child: Focus(autofocus: true, child: child!),
    ),
    theme: ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xff38675e)),
    ),
    darkTheme: ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xff38675e),
        brightness: Brightness.dark,
      ),
    ),
    routerDelegate: router,
    routeInformationParser: TorqueRouteParser(),
  );
}

class TorqueRouteParser() extends RouteInformationParser<Uri> {
  @override
  Future<Uri> parseRouteInformation(RouteInformation routeInformation) async =>
      routeInformation.uri;
  @override
  RouteInformation restoreRouteInformation(Uri configuration) =>
      RouteInformation(uri: configuration);
}

class TorqueRouter(final Composition composition) extends RouterDelegate<Uri> with ChangeNotifier {
  this {
    composition.session.addListener(sessionChanged);
  }
  final shell = GlobalKey<_SignedInShellState>();
  final navigator = GlobalKey<NavigatorState>();
  Uri location = Uri(path: '/');
  @override
  Uri get currentConfiguration => location;
  bool wasSignedIn = false;
  void sessionChanged() {
    final signedIn = composition.session.identity != null;
    if (wasSignedIn && !signedIn) location = Uri(path: '/');
    wasSignedIn = signedIn;
    notifyListeners();
  }

  void locationChanged(Uri uri) {
    location = uri;
    notifyListeners();
  }

  @override
  Future<void> setNewRoutePath(Uri configuration) async {
    final state = shell.currentState;
    if (state == null) {
      location = configuration;
    } else if (await state.acceptLocation(configuration)) {
      location = configuration;
    }
    notifyListeners();
  }

  @override
  Future<bool> popRoute() async {
    final state = shell.currentState;
    if (composition.session.expired) return true;
    if (state == null) return false;
    if (navigator.currentState?.canPop() ?? false) {
      navigator.currentState!.pop();
      return true;
    }
    await state.back();
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final session = composition.session;
    return Navigator(
      key: navigator,
      pages: [
        MaterialPage<void>(
          key: ValueKey(session.identity != null && session.restored),
          child: session.identity != null && session.restored
              ? SignedInShell(
                  key: shell,
                  composition: composition,
                  initialLocation: location,
                  onLocation: locationChanged,
                )
              : SignInView(composition: composition),
        ),
        if (session.expired)
          MaterialPage<void>(
            key: const ValueKey('reauth'),
            child: SignInView(composition: composition),
          ),
      ],
      onDidRemovePage: (_) {},
    );
  }

  @override
  void dispose() {
    composition.session.removeListener(sessionChanged);
    super.dispose();
  }
}

class const SignInView({super.key, required final Composition composition})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final session = composition.session;
    return Scaffold(
      appBar: AppBar(automaticallyImplyLeading: false, title: const Text('TorqueWrench')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.build_circle_outlined, size: 72),
                const SizedBox(height: 24),
                Text(
                  'Keep track of your car’s maintenance',
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                const Text('See what’s due and record the work you perform.'),
                const SizedBox(height: 24),
                if (session.busy)
                  const CircularProgressIndicator()
                else
                  FilledButton(
                    onPressed: () async {
                      if (!session.restored) {
                        await session.restore();
                      } else {
                        await session.signIn();
                      }
                    },
                    child: Text(session.restored ? 'Continue with Google' : 'Retry'),
                  ),
                if (session.failure != null)
                  Padding(padding: const EdgeInsets.all(16), child: Text(session.failure!.message)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Screen(
  final String title,
  final Widget body, {
  final DraftViewModel? draft,
  var String location = '/',
}) {}

class const SignedInShell({
  super.key,
  required final Composition composition,
  required final Uri initialLocation,
  required final ValueChanged<Uri> onLocation,
}) extends StatefulWidget {
  @override
  State<SignedInShell> createState() => _SignedInShellState();
}

class _SignedInShellState() extends State<SignedInShell> {
  final _screens = <_Screen>[];
  final _retiredDrafts = <DraftViewModel>[];
  int destination = 0;
  Composition get c => widget.composition;
  @override
  void initState() {
    super.initState();
    c.garage.addListener(dataChanged);
    _screens.add(garageScreen());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.initialLocation.path != '/') acceptLocation(widget.initialLocation);
    });
  }

  String get currentTitle {
    final screen = _screens.last;
    final parts = Uri.parse(screen.location).pathSegments;
    if (screen.draft == null &&
        parts.length == 2 &&
        parts[0] == 'vehicle' &&
        c.garage.data.vehicles.any((v) => v.id == parts[1])) {
      return c.garage.data.vehicle(parts[1]).name;
    }
    return screen.title;
  }

  void dataChanged() {
    if (mounted) setState(() {});
  }

  _Screen garageScreen() => _Screen(
    'Vehicles',
    GarageView(model: c.garage, openVehicle: openVehicle, addVehicle: () => vehicleForm()),
  );
  bool applyingLocation = false;
  void report() {
    if (!applyingLocation) {
      Router.navigate(context, () => widget.onLocation(Uri.parse(_screens.last.location)));
    }
  }

  void push(_Screen screen) {
    setState(() => _screens.add(screen));
    report();
  }

  Future<bool> acceptLocation(Uri uri) async {
    if (!await mayLeave() || !mounted) return false;
    applyingLocation = true;
    setState(() {
      for (final s in _screens) {
        retire(s);
      }
      _screens
        ..clear()
        ..add(garageScreen());
      destination = 0;
    });
    try {
      final parts = uri.pathSegments;
      if (uri.path == '/settings') {
        setState(() {
          destination = 1;
          _screens[0] = settingsScreen();
        });
      } else if (parts.length == 2 && parts[0] == 'vehicle') {
        openVehicle(
          parts[1],
          tab: (int.tryParse(uri.queryParameters['tab'] ?? '') ?? 0).clamp(0, 2),
        );
      } else if (parts.length == 2 && parts[0] == 'item') {
        final item = c.garage.data.item(parts[1]);
        openVehicle(item.vehicleId);
        openItem(item.id);
      } else if (parts.length == 2 && parts[0] == 'service') {
        final service = c.garage.data.service(parts[1]);
        openVehicle(service.vehicleId, tab: 2);
        openService(service.id);
      } else if (uri.path != '/') {
        throw const AppFailure(FailureKind.missing, 'Not found or unavailable.');
      }
    } on AppFailure {
      push(
        _Screen(
          'Not found',
          Center(
            child: TextButton(
              onPressed: () => navigate(0),
              child: const Text('Not found or unavailable. Back to vehicles'),
            ),
          ),
          location: uri.toString(),
        ),
      );
    }
    applyingLocation = false;
    report();
    return true;
  }

  void retire(_Screen screen) {
    final draft = screen.draft;
    if (draft == null) return;
    _retiredDrafts.add(draft);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_retiredDrafts.remove(draft)) draft.dispose();
    });
  }

  Future<bool> confirm(String title, String message, {String action = 'Confirm'}) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(title == 'Discard changes?' ? 'Keep editing' : 'Cancel'),
            ),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(action)),
          ],
        ),
      ) ??
      false;
  Future<bool> mayLeave() async {
    if (_screens.last.draft?.busy ?? false) return false;
    return !(_screens.last.draft?.dirty ?? false) ||
        await confirm('Discard changes?', 'Your unsaved changes will be lost.', action: 'Discard');
  }

  Future<void> back() async {
    if (_screens.length > 1 && await mayLeave() && mounted) {
      setState(() => retire(_screens.removeLast()));
    }
    report();
  }

  Future<void> navigate(int index) async {
    if (!await mayLeave() || !mounted) return;
    final screen = index == 0 ? garageScreen() : settingsScreen();
    setState(() {
      for (final s in _screens) {
        retire(s);
      }
      _screens
        ..clear()
        ..add(screen);
      destination = index;
    });
    report();
  }

  void saved(String message) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  void replace(_Screen screen) {
    if (mounted) {
      setState(() {
        retire(_screens.removeLast());
        _screens.add(screen);
      });
      report();
    }
  }

  void openVehicle(String id, {int tab = 0}) {
    final vehicle = c.garage.data.vehicle(id);
    push(
      _Screen(
        vehicle.name,
        DefaultTabController(
          length: 3,
          initialIndex: tab,
          child: VehicleView(
            model: c.garage,
            vehicleId: id,
            initialTab: tab,
            onTabChanged: (value) {
              final route = _screens.lastWhere(
                (s) => s.draft == null && s.location.startsWith('/vehicle/$id?'),
              );
              route.location = '/vehicle/$id?tab=$value';
              report();
            },
            openItem: openItem,
            openService: openService,
            addItem: () => itemForm(vehicle),
            logService: () => serviceForm(vehicle),
            editVehicle: () => vehicleForm(vehicle),
          ),
        ),
        location: '/vehicle/$id?tab=$tab',
      ),
    );
  }

  void vehicleForm([Vehicle? original]) {
    final vm = c.vehicleForm(original);
    push(
      _Screen(
        original == null ? 'Add vehicle' : 'Edit vehicle',
        VehicleFormView(
          model: vm,
          onSave: () async {
            if (await vm.save() && mounted) {
              setState(() => retire(_screens.removeLast()));
              if (original == null) openVehicle(vm.id, tab: 1);
              saved(original == null ? 'Vehicle added. Add maintenance item.' : 'Vehicle updated');
            }
          },
        ),
        draft: vm,
        location: _screens.last.location,
      ),
    );
  }

  void itemForm(Vehicle vehicle, [MaintenanceItem? original]) {
    final vm = c.itemForm(vehicle, original);
    push(
      _Screen(
        original == null ? 'Add maintenance item' : 'Edit maintenance item',
        ItemFormView(
          model: vm,
          onSave: () async {
            if (await vm.save() && mounted) {
              replace(itemScreen(vm.id));
              saved('Schedule item saved');
            }
          },
        ),
        draft: vm,
        location: _screens.last.location,
      ),
    );
  }

  void serviceForm(Vehicle vehicle, [ServiceRecord? original]) {
    final vm = c.serviceForm(vehicle, original);
    push(
      _Screen(
        original == null ? 'Log service' : 'Edit service',
        ServiceFormView(
          model: vm,
          onSave: () async {
            if (await vm.save() && mounted) {
              replace(serviceScreen(vm.id));
              saved('Saved');
            }
          },
        ),
        draft: vm,
        location: _screens.last.location,
      ),
    );
  }

  void openItem(String id) => push(itemScreen(id));
  _Screen itemScreen(String id) => _Screen(
    'Maintenance item',
    ItemDetailView(
      model: c.garage,
      id: id,
      openService: openService,
      edit: () {
        final item = c.garage.data.item(id);
        itemForm(c.garage.data.vehicle(item.vehicleId), item);
      },
      archive: () async {
        final item = c.garage.data.item(id);
        if (item.archived ||
            await confirm(
              'Stop tracking this item?',
              'Its service history will be kept.',
              action: 'Archive',
            )) {
          if (await c.garage.archive(item)) {
            saved(item.archived ? 'Item restored' : 'Item archived');
          }
        }
      },
    ),
    location: '/item/$id',
  );
  void openService(String id) => push(serviceScreen(id));
  _Screen serviceScreen(String id) => _Screen(
    'Service detail',
    ServiceDetailView(
      model: c.garage,
      id: id,
      openItem: openItem,
      edit: () {
        final s = c.garage.data.service(id);
        serviceForm(c.garage.data.vehicle(s.vehicleId), s);
      },
      delete: () async {
        final s = c.garage.data.service(id);
        if (await confirm(
          'Delete service?',
          '${dateText(s.date)} · ${s.mileage} ${c.garage.data.vehicle(s.vehicleId).unit}. Due dates and estimated mileage will be recalculated.',
          action: 'Delete',
        )) {
          // Missing-record presentation makes publication safe before navigation settles.
          final success = await c.garage.delete(id);
          if (success && mounted) {
            setState(() {
              while (_screens.length > 1) {
                retire(_screens.removeLast());
              }
            });
            openVehicle(s.vehicleId, tab: 2);
            saved('Service deleted');
          }
        }
      },
    ),
    location: '/service/$id',
  );
  _Screen settingsScreen() {
    final vm = c.settingsForm();
    vm.load();
    return _Screen(
      'Settings',
      SettingsView(
        model: vm,
        onSave: () async {
          if (await vm.save()) saved('Server address saved');
        },
      ),
      draft: vm,
      location: '/settings',
    );
  }

  @override
  void dispose() {
    c.garage.removeListener(dataChanged);
    for (final s in _screens) {
      s.draft?.dispose();
    }
    for (final d in _retiredDrafts) {
      d.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    onPopInvokedWithResult: (didPop, result) {
      if (!didPop) back();
    },
    child: Scaffold(
      appBar: AppBar(
        leading: _screens.length > 1
            ? IconButton(tooltip: 'Back', icon: const Icon(Icons.arrow_back), onPressed: back)
            : null,
        title: Text(currentTitle),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Account',
            onSelected: (value) async {
              if (value == 'out' && await mayLeave()) await c.session.signOut();
            },
            itemBuilder: (context) => [
              PopupMenuItem<String>(enabled: false, child: Text(c.session.identity ?? '')),
              const PopupMenuItem(value: 'out', child: Text('Sign out')),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (c.garage.offline)
              Material(
                color: Theme.of(context).colorScheme.secondaryContainer,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    'Offline · showing saved data · last updated ${dateText(c.garage.data.asOf)}. Connection required for writes.',
                  ),
                ),
              ),
            if (c.session.failure != null || c.garage.failure != null)
              MaterialBanner(
                content: Text(
                  '${c.session.failure?.message ?? c.garage.failure!.message}${c.garage.hasData ? ' · Showing saved data as of ${dateText(c.garage.data.asOf)}' : ''}',
                ),
                actions: [
                  TextButton(
                    onPressed: () async {
                      if (c.session.failure != null) {
                        await c.session.restore();
                      } else {
                        await c.garage.refresh();
                      }
                    },
                    child: const Text('Retry'),
                  ),
                ],
              ),
            Expanded(
              child: !c.garage.hasData
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('Could not load vehicles. No saved data available.'),
                          TextButton(
                            onPressed: () => c.session.restore(),
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    )
                  : IndexedStack(
                      index: _screens.length - 1,
                      children: [
                        for (var i = 0; i < _screens.length; i++)
                          KeyedSubtree(key: ObjectKey(_screens[i]), child: _screens[i].body),
                      ],
                    ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: destination,
        onDestinationSelected: navigate,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.directions_car_outlined),
            selectedIcon: Icon(Icons.directions_car),
            label: 'Vehicles',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    ),
  );
}
