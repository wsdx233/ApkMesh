import 'package:flutter/material.dart';

import '../core/app_state.dart';
import '../core/models.dart';
import '../l10n/app_localizations.dart';
import 'app_result_tile.dart';

class PackageLookupSheet extends StatefulWidget {
  const PackageLookupSheet({
    required this.packageName,
    required this.state,
    this.onAppTap,
    super.key,
  });

  final String packageName;
  final AppState state;
  final ValueChanged<AppListing>? onAppTap;

  @override
  State<PackageLookupSheet> createState() => _PackageLookupSheetState();
}

class _PackageLookupSheetState extends State<PackageLookupSheet> {
  late final Future<List<AppListing>> _lookup;

  @override
  void initState() {
    super.initState();
    _lookup = widget.state.lookupByPackageName(widget.packageName);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: .68,
        minChildSize: .38,
        maxChildSize: .94,
        builder: (context, controller) => FutureBuilder<List<AppListing>>(
          future: _lookup,
          builder: (context, snapshot) {
            final results = snapshot.data ?? const <AppListing>[];
            return ListView(
              controller: controller,
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        AppLocalizations.of(context).lookupPackageTitle,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    IconButton(
                      tooltip: AppLocalizations.of(context).close,
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                SelectableText(
                  widget.packageName,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 20),
                if (snapshot.connectionState == ConnectionState.waiting)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 48),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (snapshot.hasError)
                  _LookupMessage(
                    icon: Icons.error_outline,
                    title: AppLocalizations.of(context).packageLookupFailed,
                    detail: snapshot.error.toString(),
                  )
                else if (results.isEmpty)
                  _emptyLookupMessage(context)
                else
                  ...results.asMap().entries.map(
                    (entry) => AppResultTile(
                      app: entry.value,
                      state: widget.state,
                      onOpen: widget.onAppTap,
                      showDivider: entry.key < results.length - 1,
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _emptyLookupMessage(BuildContext context) {
    final hasPackageSource = widget.state.sources.any(
      (source) =>
          source.status == SourceStatus.enabled && source.supportsPackageLookup,
    );
    return _LookupMessage(
      icon: hasPackageSource ? Icons.search_off : Icons.hub_outlined,
      title: hasPackageSource
          ? AppLocalizations.of(context).noMatchingApps
          : AppLocalizations.of(context).noPackageSources,
      detail: hasPackageSource
          ? AppLocalizations.of(context).packageSearchedHint
          : AppLocalizations.of(context).enablePackageSourceHint,
    );
  }
}

class _LookupMessage extends StatelessWidget {
  const _LookupMessage({
    required this.icon,
    required this.title,
    required this.detail,
  });

  final IconData icon;
  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 48),
    child: Column(
      children: [
        Icon(icon, size: 48, color: Theme.of(context).colorScheme.primary),
        const SizedBox(height: 12),
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 6),
        Text(detail, textAlign: TextAlign.center),
      ],
    ),
  );
}
