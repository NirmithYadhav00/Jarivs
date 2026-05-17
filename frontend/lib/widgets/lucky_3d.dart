import 'package:flutter/material.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';

class Lucky3D extends StatelessWidget {
  const Lucky3D({super.key});

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 350,
      height: 350,

      child: ModelViewer(
        src: 'assets/models/hatsune_miku.glb',

        autoRotate: false,
        cameraControls: false,

        interactionPrompt:
            InteractionPrompt.none,

        disableZoom: true,
        disablePan: true,

        autoPlay: true,

        backgroundColor:
            Colors.transparent,
      ),
    );
  }
}