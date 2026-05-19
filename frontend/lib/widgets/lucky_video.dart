import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
class LuckyVideo extends StatefulWidget {
  const LuckyVideo({super.key});

  @override
  State<LuckyVideo> createState() =>
      _LuckyVideoState();
}

class _LuckyVideoState
    extends State<LuckyVideo> {

  late VideoPlayerController controller;

  @override
  void initState() {
    super.initState();

    controller =
      VideoPlayerController.asset(
        'assets/videos/lucky.mp4',
      )
      ..initialize().then((_) {

        controller.setLooping(true);

        controller.play();

        setState(() {});
      });
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {

    if(!controller.value.isInitialized){
      return const CircularProgressIndicator();
    }

    return ClipRRect(
      borderRadius:
          BorderRadius.circular(20),

      child: SizedBox(
        width:300,
        height:400,

        child: VideoPlayer(
          controller,
        ),
      ),
    );
  }
}