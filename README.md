# locale_lens_core

Shared translation tooling core for catalog-based localization workflows.

`locale_lens_core` contains the reusable logic behind the DevTools extension:

- translation catalog models
- catalog validation reports
- locale JSON importers
- generated export builders
- localization system detection
- hardcoded string scanning
- selective auto-fix helpers

It is intended for tooling and automation code, not for direct runtime i18n inside a Flutter app.

## Features

- Validate translation catalogs and locale file layouts
- Import flat or nested JSON locale files into a shared catalog model
- Export nested locale JSON payloads and generated Dart translation data
- Detect common localization setups in a workspace
- Scan Dart files for hardcoded UI strings
- Apply safe auto-fixes for simple translation extractions

## Installation

```yaml
dependencies:
  locale_lens_core: ^0.1.0
```

## Example

```dart
import 'package:locale_lens_core/locale_lens_core.dart';

void main() {
  const catalog = TranslationCatalog(
    version: 1,
    sourceLanguageCode: 'en',
    languages: <TranslationLanguage>[
      TranslationLanguage(
        code: 'en',
        nativeName: 'English',
        englishName: 'English',
        flag: 'GB',
        removable: false,
      ),
      TranslationLanguage(
        code: 'pl',
        nativeName: 'Polski',
        englishName: 'Polish',
        flag: 'PL',
        removable: true,
      ),
    ],
    entries: <TranslationEntry>[
      TranslationEntry(
        key: 'settings.title',
        translations: <String, String>{
          'en': 'Settings',
          'pl': 'Ustawienia',
        },
      ),
    ],
  );

  final export = const TranslationProjectExporter().build(catalog);
  print(export.filesByPath.keys);
}
```

## Scope

This package focuses on tooling primitives. If you want the ready-to-use Flutter DevTools UI on top of it, use [`locale_lens`](https://pub.dev/packages/locale_lens).
