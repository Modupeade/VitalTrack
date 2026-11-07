import 'package:flutter/material.dart';

import 'custom_text.dart';

class CustomAlertDialog extends StatelessWidget {
  final String title;
  final String subTitle;
  final String buttonText;
  final Function onPress;

  const CustomAlertDialog(
      {super.key,
      required this.title,
      required this.subTitle,
      required this.buttonText,
      required this.onPress});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title:  Text(title),
      content:  Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(subTitle),
        ],
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => onPress(),
          child: CustomText(
              text: buttonText,
              fontSize: 16,
              fontWeight: FontWeight.normal,
              textColor: Colors.black),
        ),
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: CustomText(
              text: "Cancel",
              fontSize: 14,
              fontWeight: FontWeight.normal,
              textColor: Colors.black),
        ),
      ],
    );
  }
}
