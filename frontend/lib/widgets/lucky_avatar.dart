import 'package:flutter/material.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';
import '../models/lucky_state.dart';

class LuckyAvatar extends StatelessWidget {
  final LuckyState state;

  const LuckyAvatar({
    super.key,
    required this.state,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: double.infinity,

      child: ModelViewer(
        src: 'assets/avatar/Lucky.vrm',

        alt: "Lucky AI",

        backgroundColor: Colors.transparent,

        autoRotate: false,

        cameraControls: false,

        disableZoom: true,

        ar: false,

        // rotate toward front
        cameraOrbit: "180deg 75deg 2.5m",

        // zoom upper body
        fieldOfView: "30deg",
      ),
    );
  }
}