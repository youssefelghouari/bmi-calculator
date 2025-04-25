import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class AuthPage extends StatefulWidget {
  final Function(Locale) onLocaleChanged;

  AuthPage({required this.onLocaleChanged});

  @override
  _AuthPageState createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController usernameController = TextEditingController();

  String errorMessage = '';
  bool isRegisterMode = false;

  Future<void> signInWithEmailPassword() async {
    final loc = AppLocalizations.of(context)!;
    if (emailController.text.isEmpty || passwordController.text.isEmpty) {
      setState(() {
        errorMessage = loc.pleaseFillFields;
      });
      return;
    }

    try {
      await _auth.signInWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );
      Navigator.pushReplacementNamed(context, '/home');
    } catch (e) {
      setState(() {
        errorMessage = e is FirebaseAuthException
            ? e.message ?? loc.signInFailed
            : loc.unexpectedError;
      });
    }
  }

  Future<void> registerWithEmailPassword() async {
    final loc = AppLocalizations.of(context)!;
    if (emailController.text.isEmpty ||
        passwordController.text.isEmpty ||
        usernameController.text.isEmpty) {
      setState(() {
        errorMessage = loc.pleaseFillFields;
      });
      return;
    }

    try {
      UserCredential userCredential =
      await _auth.createUserWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );

      String username = usernameController.text.trim();

      // Ajouter le username dans Firestore
      await _firestore
          .collection('users')
          .doc(userCredential.user!.uid)
          .set({
        'username': username,
        'email': emailController.text.trim(),
      });

      // Mettre à jour le displayName dans FirebaseAuth
      await userCredential.user!.updateDisplayName(username);

      Navigator.pushReplacementNamed(context, '/home');
    } catch (e) {
      setState(() {
        errorMessage = e is FirebaseAuthException
            ? e.message ?? loc.registerFailed
            : loc.unexpectedError;
      });
    }
  }

  void _changeLanguage(String? languageCode) {
    if (languageCode == null) return;
    final locale = Locale(languageCode);
    widget.onLocaleChanged(locale);
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: StreamBuilder<User?>(
          stream: _auth.authStateChanges(),
          builder: (context, snapshot) {
            final user = snapshot.data;
            if (user != null && user.displayName != null) {
              return Text('${loc.loginRegisterTitle} - ${user.displayName}');
            }
            return Text(loc.loginRegisterTitle);
          },
        ),
        actions: [
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: Localizations.localeOf(context).languageCode,
              icon: const Icon(Icons.language, color: Colors.white),
              dropdownColor: Colors.white,
              onChanged: _changeLanguage,
              items: const [
                DropdownMenuItem(value: 'en', child: Text('English')),
                DropdownMenuItem(value: 'ar', child: Text('العربية')),
                DropdownMenuItem(value: 'fr', child: Text('Français')),
                DropdownMenuItem(value: 'es', child: Text('Español')),
              ],
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isRegisterMode)
              TextField(
                controller: usernameController,
                decoration: InputDecoration(labelText: loc.username),
              ),
            const SizedBox(height: 10),
            TextField(
              controller: emailController,
              decoration: InputDecoration(labelText: loc.email),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 10),
            TextField(
              controller: passwordController,
              decoration: InputDecoration(labelText: loc.password),
              obscureText: true,
              keyboardType: TextInputType.visiblePassword,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: isRegisterMode
                  ? registerWithEmailPassword
                  : signInWithEmailPassword,
              child: Text(
                  isRegisterMode ? loc.register : loc.signIn),
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: () {
                setState(() {
                  isRegisterMode = !isRegisterMode;
                  errorMessage = '';
                });
              },
              child: Text(isRegisterMode
                  ? loc.alreadyHaveAccount
                  : loc.noAccountYet),
            ),
            const SizedBox(height: 20),
            if (errorMessage.isNotEmpty)
              Text(
                errorMessage,
                style: const TextStyle(color: Colors.red),
              ),
          ],
        ),
      ),
    );
  }
}
