import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:vitals_10/utils/constants.dart';

import 'custom_text.dart';

class CustomTextField extends StatelessWidget {
  final String title;
  final String hint;
  final TextEditingController controller;
  final Function(String) validator;
  final bool? isEnabled;
  final TextInputType? inputType;
  final bool? isPassword;
  final Function? onEyeTapped;
  final bool? onShow;

  const CustomTextField(
      {super.key,
      required this.title,
      required this.controller,
      required this.validator,
      required this.hint,
      this.isEnabled = true,
      this.inputType = TextInputType.text,
      this.isPassword = false,
      this.onEyeTapped,
      this.onShow = false});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CustomText(
            text: title,
            fontSize: 14,
            fontWeight: FontWeight.normal,
            textColor: Colors.black),
        5.height,
        TextFormField(
          cursorColor: primaryColor,
          enabled: isEnabled,
          obscureText: onShow!,
          controller: controller,
          keyboardType: inputType,
          validator: (val) => validator(val!),
          decoration: InputDecoration(

            hintText: hint,
            fillColor: Colors.grey.shade50,
            filled: true,
            hintStyle: const TextStyle(fontSize: 14, color: Colors.grey),
            suffixIcon: isPassword!
                ? InkWell(
                    onTap: () => onEyeTapped!(),
                    child: onShow!
                        ? Icon(CupertinoIcons.eye_slash_fill , color: Colors.grey,)
                        : Icon(Icons.remove_red_eye,color: Colors.grey,))
                : null,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide:
                BorderSide(color: Colors.grey.shade300, width: 2)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide:
                     BorderSide(color: Colors.transparent, width: 2)),

            errorBorder: OutlineInputBorder(
                borderSide: const BorderSide(color: Colors.red, width: 2),
                borderRadius: BorderRadius.circular(12)),
            focusedErrorBorder: OutlineInputBorder(
                borderSide: BorderSide(color: Colors.red, width: 2),
                borderRadius: BorderRadius.circular(8)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: primaryColor, width: 2)),
          ),
        ),
      ],
    );
  }
}
