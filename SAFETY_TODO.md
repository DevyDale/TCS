# Remaining manual step — EULA gate in your startup routing

The installer wired everything except the one spot whose surrounding
code can't be detected reliably: showing the EULA before login.

In your splash / initial route (the screen that decides where a
logged-out user goes), import the gate and run it before navigating to
role selection / login:

```dart
import 'package:tcs_app/screens/legal/eula_screen.dart';

// before you push RoleSelectionScreen() / the login route:
if (!await EulaGate.isAccepted()) {
  final ok = await Navigator.push<bool>(
    context, MaterialPageRoute(builder: (_) => const EulaScreen()),
  );
  if (ok != true) return;        // declined — stay on the gate
}
// ...then continue to your existing role-selection / login navigation
```

If any line in the run log above shows "!!", that edit needs a manual
touch — the matching patch is in the original package's `_patches/`.
