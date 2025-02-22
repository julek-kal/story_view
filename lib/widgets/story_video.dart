import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:video_player/video_player.dart';

import '../controller/story_controller.dart';
import '../utils.dart';

class VideoLoader {
  String url;

  File? videoFile;

  Map<String, dynamic>? requestHeaders;

  LoadState state = LoadState.loading;

  VideoLoader(this.url, {this.requestHeaders});

  void loadVideo(VoidCallback onComplete) {
    if (this.videoFile != null) {
      this.state = LoadState.success;
      onComplete();
    }

    final fileStream =
        DefaultCacheManager().getFileStream(this.url, headers: this.requestHeaders as Map<String, String>?);

    fileStream.listen((fileResponse) async {
      if (fileResponse is FileInfo) {
        if (this.videoFile == null) {
          this.state = LoadState.success;
          if (Platform.isIOS) {
            videoFile = await fileResponse.file.rename('${fileResponse.file.path.split(".")[0]}.mp4');
          } else if (Platform.isAndroid) {
            this.videoFile = fileResponse.file;
          } else {
            throw Exception("Not supported platform");
          }
          onComplete();
        }
      }
    });
  }
}

class StoryVideo extends StatefulWidget {
  final StoryController? storyController;
  final VideoLoader videoLoader;
  final bool isHLS;

  StoryVideo(this.videoLoader, {this.storyController, this.isHLS = false, Key? key}) : super(key: key ?? UniqueKey());

  static StoryVideo url(String url,
      {StoryController? controller, bool isHLS = false, Map<String, dynamic>? requestHeaders, Key? key}) {
    return StoryVideo(VideoLoader(url, requestHeaders: requestHeaders),
        storyController: controller, key: key, isHLS: isHLS);
  }

  @override
  State<StatefulWidget> createState() {
    return StoryVideoState();
  }
}

class StoryVideoState extends State<StoryVideo> {
  Future<void>? playerLoader;

  StreamSubscription? _streamSubscription;

  VideoPlayerController? playerController;

  @override
  void initState() {
    super.initState();

    widget.storyController!.pause();

    widget.videoLoader.loadVideo(() {
      if (widget.videoLoader.state == LoadState.success) {
        /// if video is HLS, need to load it from network, if is a downloaded file, need to load it from local cache
        if (widget.isHLS) {
          this.playerController = VideoPlayerController.network(widget.videoLoader.url);
        } else {
          this.playerController = VideoPlayerController.file(widget.videoLoader.videoFile!);
        }
        this.playerController?.initialize().then((v) {
          setState(() {});
          widget.storyController!.play();
        });

        if (widget.storyController != null) {
          _streamSubscription = widget.storyController!.playbackNotifier.listen((playbackState) {
            if (playbackState == PlaybackState.pause) {
              playerController!.pause();
            } else {
              playerController!.play();
            }
          });
        } else {
          setState(() {});
        }
      }
    });
  }

  Widget getContentView() {
    if (widget.videoLoader.state == LoadState.success && playerController!.value.isInitialized) {
      return Center(
        child: AspectRatio(
          aspectRatio: playerController!.value.aspectRatio,
          child: VideoPlayer(playerController!),
        ),
      );
    } else if (widget.videoLoader.state == LoadState.failure || (playerController?.value.hasError ?? false)) {
      return Center(
          child: Text(
        "Media failed to load.",
        style: TextStyle(
          color: Colors.white,
        ),
      ));
    } else {
      return Center(
        child: Container(
          width: 70,
          height: 70,
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            strokeWidth: 3,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      height: double.infinity,
      width: double.infinity,
      child: getContentView(),
    );
  }

  @override
  void deactivate() {
    playerController?.pause();
    super.deactivate();
  }

  @override
  void dispose() {
    playerController?.dispose();
    _streamSubscription?.cancel();
    super.dispose();
  }
}
