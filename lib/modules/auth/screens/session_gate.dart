import 'dart:async';

import 'package:crm_interface/modules/auth/repos/auth.dart';
import 'package:crm_interface/modules/auth/screens/auth_screen.dart';
import 'package:flutter/material.dart';
import 'package:fresh_dio/fresh_dio.dart';

/// Единственное место, которое выбирает между входом и CRM.
class SessionGate extends StatefulWidget {
  const SessionGate({
    super.key,
    required this.authRepository,
    required this.authenticatedBuilder,
  });

  final AuthRepository authRepository;
  final WidgetBuilder authenticatedBuilder;

  @override
  State<SessionGate> createState() => _SessionGateState();
}

class _SessionGateState extends State<SessionGate> {
  late final StreamSubscription<AuthenticationStatus> _authSubscription;
  bool _crmOpen = false;

  @override
  void initState() {
    super.initState();
    _authSubscription = widget
        .authRepository
        .apiClient
        .fresh
        .authenticationStatus
        .listen((status) {
          if (!mounted) return;
          if (status == AuthenticationStatus.unauthenticated && _crmOpen) {
            setState(() => _crmOpen = false);
          }
        });
  }

  @override
  void dispose() {
    _authSubscription.cancel();
    super.dispose();
  }

  void _openCrm() {
    setState(() => _crmOpen = true);
  }

  @override
  Widget build(BuildContext context) {
    if (_crmOpen) {
      return widget.authenticatedBuilder(context);
    }
    return AuthScreen(
      authRepository: widget.authRepository,
      onAuthenticated: _openCrm,
    );
  }
}
