import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:loading_overlay/loading_overlay.dart';

import '../utils/constants.dart';

class CustomLoader extends StatelessWidget {
  final bool isLoading;
  final Widget child;

  const CustomLoader({Key? key, required this.isLoading, required this.child})
      : super(key: key);

  @override
  Widget build(BuildContext context) { 
    return LoadingOverlay(
      isLoading: isLoading,
      color: primaryColor.withOpacity(0.2),
      progressIndicator: SpinKitWaveSpinner(
        waveColor: primaryColor,
        color: primaryColor,
        duration: Duration(seconds: 3),
        size: 60,
      ),
      child: child,
    );
  }
}
