


import 'package:flutter/material.dart';
import 'package:vitals_10/ui/devices/dashboard/constants/page_colors.dart';

class baseWidget extends StatelessWidget{
    
    @override
    Widget build(BuildContext context){
        return Text("");
    }
}


class StartCol extends StatelessWidget{
    
    final value;
    final label;

    const StartCol({
        super.key,
        required this.value,
        required this.label
    });
    
    @override
    Widget build(BuildContext context){
       return Expanded(
          child: Column(
            children: [
              Text(value,
                  style: const TextStyle(
                      color: cWhite, fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(label,
                  style: const TextStyle(color: cGray, fontSize: 12)),
            ],
          ),
        );
    }
}


class VDivider extends StatelessWidget{
    
    @override
    Widget build(BuildContext context){
      return Container(
            width: 1,
            height: 30,
            color: cBorder,
      );
    }
}

