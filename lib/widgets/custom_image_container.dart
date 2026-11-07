import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

class CustomImageContainer extends StatefulWidget {
  final double height;
  final double wight;
  final double radius;
  final String image;

  const CustomImageContainer(
      {super.key,
      required this.height,
      required this.wight,
      required this.radius,
      required this.image});

  @override
  State<CustomImageContainer> createState() => _CustomImageContainerState();
}

class _CustomImageContainerState extends State<CustomImageContainer> {
  @override
  Widget build(BuildContext context) {
    return Container(
        height: widget.height,
        width: widget.wight,
        decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(500)),
        child: ClipRRect(
            borderRadius: BorderRadius.circular(widget.radius),
            child: widget.image == ""
                ? const Icon(Icons.person_outline_rounded)
                : CachedNetworkImage(
                    fit: BoxFit.cover,
                    imageUrl: widget.image,
                    progressIndicatorBuilder:
                        (context, url, downloadProgress) => Container(
                            width: 50,
                            height: 50,
                            child: Center(
                              child: CircularProgressIndicator(
                                value: downloadProgress.progress,
                              ),
                            )),
                  )));
  }
}
