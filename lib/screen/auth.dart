import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pinput/pinput.dart';
import '../bloc/user.dart';

class AuthScreen extends StatefulWidget {
  static Route route() {
    if (Platform.isIOS) {
      return CupertinoPageRoute(builder: (_) => const AuthScreen());
    }
    return MaterialPageRoute(builder: (_) => const AuthScreen());
  }

  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  late String _title;
  int _currentPage = 1; // 0: SignIn, 1: SignUp

  @override
  void initState() {
    super.initState();
    _title = 'Sign Up';
  }

  void _goToSignIn() {
    setState(() {
      _currentPage = 0;
      _title = 'Sign In';
    });
  }

  void _goToSignUp() {
    setState(() {
      _currentPage = 1;
      _title = 'Sign Up';
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<UserCubit, UserState>(
      listener: (context, state) {
        if (state.status == AuthStatus.pendingConfirmation) {
          Navigator.of(context).pushAndRemoveUntil(_ConfirmationCodeScreen.route(), (route) => false);
        }
      },
      builder: (context, state) {
        return Scaffold(
          appBar: AppBar(title: Text(_title), automaticallyImplyLeading: false),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (state.error != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.red[100], borderRadius: BorderRadius.circular(8)),
                    child: Row(
                      children: [
                        Icon(Icons.error, color: Colors.red[800]),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(state.error!, style: TextStyle(color: Colors.red[800])),
                        ),
                      ],
                    ),
                  ),
                _currentPage == 0 ? _SignInScreen(onSignUpTap: _goToSignUp) : _SignUpScreen(onSignInTap: _goToSignIn),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SignInScreen extends StatefulWidget {
  final VoidCallback onSignUpTap;
  const _SignInScreen({required this.onSignUpTap});

  @override
  State<_SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<_SignInScreen> {
  final TextEditingController userController = TextEditingController();
  final TextEditingController passController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    userController.dispose();
    passController.dispose();
    super.dispose();
  }

  void _signIn() {
    context.read<UserCubit>().authenticate(username: userController.text, password: passController.text);
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<UserCubit>().state;
    final isPending = state.status == AuthStatus.initiated;
    return Column(
      children: [
        TextField(
          controller: userController,
          decoration: const InputDecoration(labelText: 'Email or Username'),
          autofillHints: const [AutofillHints.email, AutofillHints.username],
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          autocorrect: false,
          inputFormatters: [
            FilteringTextInputFormatter.deny(RegExp(r'\s')), // Prevent spaces
          ],
          enabled: !isPending,
        ),
        const SizedBox(height: 16),
        TextField(
          controller: passController,
          decoration: InputDecoration(
            labelText: 'Password',
            suffixIcon: IconButton(
              icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
              onPressed: isPending
                  ? null
                  : () {
                      setState(() {
                        _obscurePassword = !_obscurePassword;
                      });
                    },
            ),
          ),
          autofillHints: const [AutofillHints.password],
          textInputAction: TextInputAction.done,
          autocorrect: false,
          inputFormatters: [
            FilteringTextInputFormatter.deny(RegExp(r'\s')), // Prevent spaces
          ],
          keyboardType: TextInputType.visiblePassword,
          textCapitalization: TextCapitalization.none,
          obscureText: _obscurePassword,
          enabled: !isPending,
          onSubmitted: isPending ? null : (_) => _signIn(),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: isPending ? null : _signIn,
            child: isPending
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Sign In'),
          ),
        ),
        TextButton(
          onPressed: isPending ? null : widget.onSignUpTap,
          child: const Text("Don't have an account? Sign up"),
        ),
      ],
    );
  }
}

class _SignUpScreen extends StatefulWidget {
  final VoidCallback onSignInTap;
  const _SignUpScreen({required this.onSignInTap});

  @override
  State<_SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<_SignUpScreen> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController userController = TextEditingController();
  final TextEditingController passController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    emailController.dispose();
    userController.dispose();
    passController.dispose();
    super.dispose();
  }

  void _signUp() {
    context.read<UserCubit>().signUp(
      email: emailController.text,
      username: userController.text,
      password: passController.text,
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<UserCubit>().state;
    final isPending = state.status == AuthStatus.initiated;
    return Column(
      children: [
        TextField(
          controller: emailController,
          decoration: const InputDecoration(labelText: 'Email'),
          autofillHints: const [AutofillHints.email],
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          autocorrect: false,
          inputFormatters: [
            FilteringTextInputFormatter.deny(RegExp(r'\s')), // Prevent spaces
          ],
          enabled: !isPending,
        ),
        const SizedBox(height: 16),
        TextField(
          controller: userController,
          decoration: const InputDecoration(labelText: 'Username'),
          autofillHints: const [AutofillHints.username],
          keyboardType: TextInputType.text,
          textInputAction: TextInputAction.next,
          autocorrect: false,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9_.-]')), // Allow common username chars
            FilteringTextInputFormatter.deny(RegExp(r'\s')), // Prevent spaces
          ],
          enabled: !isPending,
        ),
        const SizedBox(height: 16),
        TextField(
          controller: passController,
          decoration: InputDecoration(
            labelText: 'Password',
            suffixIcon: IconButton(
              icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
              onPressed: isPending
                  ? null
                  : () {
                      setState(() {
                        _obscurePassword = !_obscurePassword;
                      });
                    },
            ),
          ),
          autofillHints: const [AutofillHints.newPassword],
          textInputAction: TextInputAction.done,
          autocorrect: false,
          inputFormatters: [
            FilteringTextInputFormatter.deny(RegExp(r'\s')), // Prevent spaces
          ],
          keyboardType: TextInputType.visiblePassword,
          textCapitalization: TextCapitalization.none,
          obscureText: _obscurePassword,
          enabled: !isPending,
          onSubmitted: isPending ? null : (_) => _signUp(),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: isPending ? null : _signUp,
            child: isPending
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Sign Up'),
          ),
        ),
        TextButton(
          onPressed: isPending ? null : widget.onSignInTap,
          child: const Text("Already have an account? Sign in"),
        ),
      ],
    );
  }
}

class _ConfirmationCodeScreen extends StatefulWidget {
  const _ConfirmationCodeScreen();

  static Route route() {
    if (Platform.isIOS) {
      return CupertinoPageRoute(builder: (_) => const _ConfirmationCodeScreen());
    }
    return MaterialPageRoute(builder: (_) => const _ConfirmationCodeScreen());
  }

  @override
  State<_ConfirmationCodeScreen> createState() => _ConfirmationCodeScreenState();
}

class _ConfirmationCodeScreenState extends State<_ConfirmationCodeScreen> {
  String code = '';
  bool isSubmitting = false;
  final TextEditingController _pinController = TextEditingController();

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  void _submitCode() async {
    setState(() => isSubmitting = true);
    await context.read<UserCubit>().confirm(confirmationCode: code);
    setState(() => isSubmitting = false);
  }

  Future<void> _checkClipboardForCode() async {
    final clipboardData = await Clipboard.getData('text/plain');
    final text = clipboardData?.text ?? '';
    final match = RegExp(r'\b(\d{6})\b').firstMatch(text);
    if (match != null) {
      final pastedCode = match.group(1)!;
      if (pastedCode != code) {
        setState(() {
          code = pastedCode;
          _pinController.text = pastedCode;
        });
        _submitCode();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Confirm Email'), automaticallyImplyLeading: false),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: BlocBuilder<UserCubit, UserState>(
          builder: (context, state) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (state.error != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.red[100], borderRadius: BorderRadius.circular(8)),
                    child: Row(
                      children: [
                        Icon(Icons.error, color: Colors.red[800]),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(state.error!, style: TextStyle(color: Colors.red[800])),
                        ),
                      ],
                    ),
                  ),
                const Text('Enter the verification code sent to your email'),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Pinput(
                      length: 6,
                      controller: _pinController,
                      onCompleted: (val) {
                        setState(() {
                          code = val;
                        });
                        _submitCode();
                      },
                      onTap: () {
                        _checkClipboardForCode();
                      },
                      defaultPinTheme: PinTheme(
                        width: 40,
                        height: 56,
                        textStyle: const TextStyle(fontSize: 20),
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade400),
                        ),
                      ),
                      separatorBuilder: (context) => const SizedBox(width: 12),
                      keyboardType: TextInputType.number,
                      validator: (val) => val != null && RegExp(r'^\d{6}$').hasMatch(val) ? null : '',
                      autofocus: true,
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: code.length == 6 && !isSubmitting ? _submitCode : null,
                    child: isSubmitting
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Confirm'),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
