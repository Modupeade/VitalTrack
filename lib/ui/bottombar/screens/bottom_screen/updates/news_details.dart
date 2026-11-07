import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:vitals_10/navigation/navigation_helper.dart';
import 'package:vitals_10/ui/bottombar/screens/bottom_screen/updates/image_preview.dart';
import 'package:vitals_10/utils/constants.dart';

import '../../../../../widgets/custom_image_container.dart';
import '../../../../../widgets/custom_text.dart';

class NewsDetails extends StatefulWidget {
  final newsData;

  const NewsDetails({super.key, this.newsData});

  @override
  State<NewsDetails> createState() => _NewsDetailsState();
}

class _NewsDetailsState extends State<NewsDetails> {
  late VideoPlayerController _videoPlayerController1;
  ChewieController? _chewieController;
  int? bufferDelay;

  @override
  void initState() {
    super.initState();
    if (widget.newsData["fileType"] == "VIDEO") {
      _videoPlayerController1 =
          VideoPlayerController.network("${widget.newsData["file"]}");
      //videoPlayerController.initialize();
      _chewieController = ChewieController(
        fullScreenByDefault: false,
        videoPlayerController: _videoPlayerController1,
        autoPlay: true,
        looping: false,
      );
      _chewieController!.play();

    }
  }

  @override
  void dispose() {
    _videoPlayerController1.dispose();
    _chewieController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.black),
      ),
      body: SingleChildScrollView(child: _getUI(context)),
    );
  }

  Widget _getUI(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          widget.newsData["fileType"] == "IMAGE"
              ? InkWell(
                  onTap: () {
                    NavigationHelper.navPush(context,
                        ImagePreview(imageUrl: widget.newsData["file"]));
                  },
                  child: Stack(
                    children: [
                      CustomImageContainer(
                          height: 200,
                          wight: double.infinity,
                          radius: 12,
                          image: widget.newsData["file"]),
                      Positioned(
                        bottom: 10,
                        right: 10,
                        child: Chip(
                            backgroundColor: primaryColor.withOpacity(0.3),
                            label: CustomText(
                                text: "View",
                                fontSize: 14,
                                fontWeight: FontWeight.normal,
                                textColor: Colors.black)),
                      )
                    ],
                  ),
                )
              : SizedBox(
                  height: 200,
                  width: double.infinity,
                  child: Chewie(
                    controller: _chewieController!,
                  )),
          10.height,
          CustomText(
              text: "Title",
              fontSize: 12,
              fontWeight: FontWeight.bold,
              textColor: Colors.grey.shade600),
          5.height,
          CustomText(
            text: widget.newsData["title"],
            fontSize: 14,
            fontWeight: FontWeight.bold,
            textColor: Colors.black,
            overflow: TextOverflow.ellipsis,
          ),
          10.height,
          CustomText(
              text: "Description",
              fontSize: 12,
              fontWeight: FontWeight.bold,
              textColor: Colors.grey.shade600),
          5.height,
          CustomText(
              text: widget.newsData["description"],
              fontSize: 14,
              overflow: TextOverflow.fade,
              fontWeight: FontWeight.normal,
              textColor: Colors.black),
        ],
      ),
    );
  }
}
