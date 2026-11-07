import 'package:flutter/material.dart';

import 'custom_text.dart';

class CustomButton extends StatelessWidget {
  final double hight;
  final double width;
  final double radius;
  final Function onTap;
  final String text;
  final double size;
  final Color textColor;
  final Color buttonColor;
  final FontWeight fontWeight;
  final double padding;

  const CustomButton(
      {super.key,
      required this.hight,
      required this.width,
      required this.radius,
      required this.text,
      required this.size,
      required this.textColor,
      required this.fontWeight,
      required this.buttonColor,
      required this.onTap,
      required this.padding});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onTap(),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: padding),
        child: PhysicalModel(
          borderRadius: BorderRadius.circular(radius),
          color: Colors.white,
          elevation: 15.0,
          shadowColor: Colors.black,
          child: Container(
            height: hight,
            width: width,
            decoration: BoxDecoration(
                color: buttonColor,
                borderRadius: BorderRadius.circular(radius)),
            child: Center(
              child: CustomText(
                  text: text,
                  fontSize: size,
                  fontWeight: fontWeight,
                  textColor: textColor),
            ),
          ),
        ),
      ),
    );
  }
}
