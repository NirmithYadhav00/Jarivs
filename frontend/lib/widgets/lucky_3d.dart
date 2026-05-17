import 'package:flutter/material.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';
import '../models/lucky_state.dart';

class Lucky3D extends StatelessWidget {
  final LuckyState state;

  const Lucky3D({
    super.key,
    required this.state,
  });

  @override
  Widget build(BuildContext context) {
    double scale = 1;

    // Slight pulse while talking
    if (state == LuckyState.talking) {
      scale = 1.08;
    }

    // Tiny scale while listening
    if (state == LuckyState.listening) {
      scale = 1.03;
    }

    return Center(
      child: AnimatedScale(
        duration: const Duration(
          milliseconds: 400,
        ),

        scale: scale,

        child: const SizedBox(
          width: 280,
          height: 280,

          child: ModelViewer(
            src: 'assets/models/hatsune_miku.glb',

            interactionPrompt:
                InteractionPrompt.none,

            cameraControls: false,

            disableZoom: true,

            disablePan: true,

            autoRotate: false,

            autoPlay: true,

            backgroundColor:
                Colors.transparent,
          ),
        ),
      ),
    );
  }
}