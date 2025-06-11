import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_verification_code_field/flutter_verification_code_field.dart';
import '../bloc/auth.dart';

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
  final PageController _pageController = PageController();
  String? _signUpEmail;
  late String _title;

  @override
  void initState() {
    super.initState();
    _title = _getTitle(0);
    _pageController.addListener(() {
      setState(() {
        _title = _getTitle(_pageController.page?.round() ?? 0);
      });
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _goToSignUp() =>
      _pageController.animateToPage(1, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
  void _goToSignIn() =>
      _pageController.animateToPage(0, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
  void _goToConfirmation() =>
      _pageController.animateToPage(2, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AuthCubit, AuthState>(
      listener: (context, state) {
        if (state.status == AuthStatus.pendingConfirmation) {
          _goToConfirmation();
        } else if (state.status == AuthStatus.unauthenticated || state.status == AuthStatus.initiated) {
          _goToSignIn();
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
                SizedBox(
                  height: 400,
                  child: PageView(
                    controller: _pageController,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      _SignInScreen(onSignUpTap: _goToSignUp),
                      _SignUpScreen(
                        onSignInTap: _goToSignIn,
                        onSignUpSuccess: (email) {
                          setState(() => _signUpEmail = email);
                        },
                      ),
                      _ConfirmationCodeScreen(email: _signUpEmail ?? ''),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _getTitle(int page) {
    switch (page) {
      case 0:
        return 'Sign In';
      case 1:
        return 'Sign Up';
      case 2:
        return 'Confirm Code';
      default:
        return '';
    }
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

  @override
  void dispose() {
    userController.dispose();
    passController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AuthCubit>().state;
    final isPending = state.status == AuthStatus.initiated;
    return Column(
      children: [
        TextField(
          controller: userController,
          decoration: const InputDecoration(labelText: 'Email or Username'),
          enabled: !isPending,
        ),
        const SizedBox(height: 16),
        TextField(
          controller: passController,
          decoration: const InputDecoration(labelText: 'Password'),
          obscureText: true,
          enabled: !isPending,
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: isPending
                ? null
                : () {
                    context.read<AuthCubit>().authenticate(
                      username: userController.text,
                      password: passController.text,
                    );
                  },
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
  final void Function(String email)? onSignUpSuccess;
  const _SignUpScreen({required this.onSignInTap, this.onSignUpSuccess});

  @override
  State<_SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<_SignUpScreen> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController userController = TextEditingController();
  final TextEditingController passController = TextEditingController();

  @override
  void dispose() {
    emailController.dispose();
    userController.dispose();
    passController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AuthCubit>().state;
    final isPending = state.status == AuthStatus.initiated;
    return Column(
      children: [
        TextField(
          controller: emailController,
          decoration: const InputDecoration(labelText: 'Email'),
          enabled: !isPending,
        ),
        const SizedBox(height: 16),
        TextField(
          controller: userController,
          decoration: const InputDecoration(labelText: 'Username'),
          enabled: !isPending,
        ),
        const SizedBox(height: 16),
        TextField(
          controller: passController,
          decoration: const InputDecoration(labelText: 'Password'),
          obscureText: true,
          enabled: !isPending,
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: isPending
                ? null
                : () {
                    context.read<AuthCubit>().signUp(
                      email: emailController.text,
                      username: userController.text,
                      password: passController.text,
                    );
                    if (widget.onSignUpSuccess != null) {
                      widget.onSignUpSuccess!(emailController.text);
                    }
                  },
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
  final String email;
  const _ConfirmationCodeScreen({required this.email});

  @override
  State<_ConfirmationCodeScreen> createState() => _ConfirmationCodeScreenState();
}

class _ConfirmationCodeScreenState extends State<_ConfirmationCodeScreen> {
  String code = '';
  bool isSubmitting = false;

  void _submitCode() async {
    setState(() => isSubmitting = true);
    await context.read<AuthCubit>().confirm(email: widget.email, confirmationCode: code);
    setState(() => isSubmitting = false);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('Enter the verification code sent to your email'),
        const SizedBox(height: 24),
        VerificationCodeField(
          length: 6,
          onFilled: (val) => setState(() => code = val),
          size: const Size(40, 56),
          spaceBetween: 12,
          matchingPattern: RegExp(r'^\\d{6}\$'),
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
  }
}
