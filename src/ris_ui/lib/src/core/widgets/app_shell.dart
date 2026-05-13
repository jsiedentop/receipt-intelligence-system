import 'package:flutter/material.dart';

import '../../app/router.dart';

enum AppSection { receipts, merchants }

class AppShellHost extends StatefulWidget {
  const AppShellHost({super.key, this.initialRoute = AppRoutePaths.receipts});

  final String initialRoute;

  @override
  State<AppShellHost> createState() => _AppShellHostState();
}

class _AppShellHostState extends State<AppShellHost> {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  final RouteObserver<ModalRoute<dynamic>> _routeObserver =
      RouteObserver<ModalRoute<dynamic>>();

  _AppShellConfig _config = const _AppShellConfig(
    title: 'Receipts',
    currentSection: AppSection.receipts,
    actions: <Widget>[],
  );
  bool _canPop = false;

  void updateConfig(_AppShellConfig config) {
    if (!mounted) {
      return;
    }

    setState(() {
      _config = config;
    });
  }

  void _syncNavigatorState() {
    if (!mounted) {
      return;
    }

    final canPop = _navigatorKey.currentState?.canPop() ?? false;
    if (canPop != _canPop) {
      setState(() {
        _canPop = canPop;
      });
    }
  }

  Future<bool> _handleWillPop() async {
    final navigator = _navigatorKey.currentState;
    if (navigator != null && navigator.canPop()) {
      navigator.pop();
      return false;
    }

    return true;
  }

  void _selectSection(int index) {
    final targetSection = switch (index) {
      0 => AppSection.receipts,
      1 => AppSection.merchants,
      _ => AppSection.receipts,
    };

    if (targetSection == _config.currentSection) {
      return;
    }

    final targetPath = switch (targetSection) {
      AppSection.receipts => AppRoutePaths.receipts,
      AppSection.merchants => AppRoutePaths.merchants,
    };

    _navigatorKey.currentState?.pushAndRemoveUntil<void>(
      buildNamedPageRoute(targetPath, animated: false),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedIndex = switch (_config.currentSection) {
      AppSection.receipts => 0,
      AppSection.merchants => 1,
    };

    return _AppShellScope(
      state: this,
      child: PopScope(
        canPop: !_canPop,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop) {
            _handleWillPop();
          }
        },
        child: Scaffold(
          appBar: AppBar(
            automaticallyImplyLeading: false,
            leading: _canPop
                ? BackButton(
                    onPressed: () => _navigatorKey.currentState?.maybePop(),
                  )
                : null,
            title: Text(_config.title),
            actions: _config.actions,
          ),
          floatingActionButton: _config.floatingActionButton,
          bottomNavigationBar: NavigationBar(
            selectedIndex: selectedIndex,
            onDestinationSelected: _selectSection,
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.receipt_long_outlined),
                selectedIcon: Icon(Icons.receipt_long),
                label: 'Receipts',
              ),
              NavigationDestination(
                icon: Icon(Icons.storefront_outlined),
                selectedIcon: Icon(Icons.storefront),
                label: 'Merchants',
              ),
            ],
          ),
          body: Navigator(
            key: _navigatorKey,
            initialRoute: widget.initialRoute,
            observers: [_routeObserver, _ShellNavigatorObserver(_syncNavigatorState)],
            onGenerateRoute: generateRoute,
          ),
        ),
      ),
    );
  }
}

class AppShell extends StatefulWidget {
  const AppShell({
    super.key,
    required this.title,
    required this.body,
    this.currentSection = AppSection.receipts,
    this.actions = const <Widget>[],
    this.floatingActionButton,
  });

  final String title;
  final Widget body;
  final AppSection currentSection;
  final List<Widget> actions;
  final Widget? floatingActionButton;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> with RouteAware {
  ModalRoute<dynamic>? _route;
  _AppShellHostState? _shellHostState;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    final scope = _AppShellScope.of(context);
    _shellHostState = scope.state;

    if (_route != route && route != null) {
      if (_route != null) {
        _shellHostState!._routeObserver.unsubscribe(this);
      }
      _route = route;
      _shellHostState!._routeObserver.subscribe(this, route);
    }

    _scheduleConfigUpdate();
  }

  @override
  void didUpdateWidget(covariant AppShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    _scheduleConfigUpdate();
  }

  @override
  void didPush() {
    _scheduleConfigUpdate();
  }

  @override
  void didPopNext() {
    _scheduleConfigUpdate();
  }

  @override
  void dispose() {
    final route = _route;
    final shellHostState = _shellHostState;
    if (route != null && shellHostState != null) {
      shellHostState._routeObserver.unsubscribe(this);
    }
    super.dispose();
  }

  void _scheduleConfigUpdate() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      _shellHostState?.updateConfig(
        _AppShellConfig(
          title: widget.title,
          currentSection: widget.currentSection,
          actions: widget.actions,
          floatingActionButton: widget.floatingActionButton,
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [Expanded(child: widget.body)],
            ),
          ),
        ),
      ),
    );
  }
}

class _ShellNavigatorObserver extends NavigatorObserver {
  _ShellNavigatorObserver(this.onChanged);

  final VoidCallback onChanged;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    onChanged();
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    onChanged();
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    onChanged();
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    onChanged();
  }
}

class _AppShellScope extends InheritedWidget {
  const _AppShellScope({required this.state, required super.child});

  final _AppShellHostState state;

  static _AppShellScope of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<_AppShellScope>();
    assert(scope != null, 'AppShellHost is missing above AppShell.');
    return scope!;
  }

  @override
  bool updateShouldNotify(_AppShellScope oldWidget) => state != oldWidget.state;
}

class _AppShellConfig {
  const _AppShellConfig({
    required this.title,
    required this.currentSection,
    required this.actions,
    this.floatingActionButton,
  });

  final String title;
  final AppSection currentSection;
  final List<Widget> actions;
  final Widget? floatingActionButton;
}
