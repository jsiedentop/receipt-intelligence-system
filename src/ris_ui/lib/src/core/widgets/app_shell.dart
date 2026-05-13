import 'package:flutter/material.dart';

import '../../app/router.dart';

enum AppSection { receipts, merchants }

class AppShell extends StatelessWidget {
  const AppShell({
    super.key,
    required this.title,
    required this.body,
    this.currentSection = AppSection.receipts,
    this.actions = const <Widget>[],
  });

  final String title;
  final Widget body;
  final AppSection currentSection;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title), actions: actions),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _SectionChip(
                        label: 'Receipts',
                        selected: currentSection == AppSection.receipts,
                        onTap: () {
                          if (ModalRoute.of(context)?.settings.name !=
                              AppRoutePaths.receipts) {
                            Navigator.of(context).pushNamedAndRemoveUntil(
                              AppRoutePaths.receipts,
                              (route) => route.isFirst,
                            );
                          }
                        },
                      ),
                      _SectionChip(
                        label: 'Merchants',
                        selected: currentSection == AppSection.merchants,
                        onTap: () {
                          if (ModalRoute.of(context)?.settings.name !=
                              AppRoutePaths.merchants) {
                            Navigator.of(context).pushNamedAndRemoveUntil(
                              AppRoutePaths.merchants,
                              (route) => route.isFirst,
                            );
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Expanded(child: body),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionChip extends StatelessWidget {
  const _SectionChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      decoration: BoxDecoration(
        color: selected
            ? Theme.of(context).colorScheme.primary
            : Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(999),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: selected
                  ? Theme.of(context).colorScheme.onPrimary
                  : Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ),
      ),
    );
  }
}
