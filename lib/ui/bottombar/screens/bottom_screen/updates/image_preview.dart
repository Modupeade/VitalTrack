import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

class ImagePreview extends StatelessWidget {
  final String imageUrl;

  const ImagePreview({super.key, required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.black),
      ),
      body: Center(
        child: CachedNetworkImage(
          memCacheWidth: 512,
          fit: BoxFit.cover,
          imageUrl: imageUrl,
          progressIndicatorBuilder: (context, url, downloadProgress) =>
              Container(
                  width: 50,
                  height: 50,
                  child: Center(
                    child: CircularProgressIndicator(
                      value: downloadProgress.progress,
                    ),
                  )),
        ),
      ),
    );
  }
}
