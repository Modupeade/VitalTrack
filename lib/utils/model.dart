

import 'dart:collection';

class DataModel{
  bool dataEnd = false;
  int dataType = 0;
  String dicData = "";

  String toContentString(){
    return "{dataEnd=$dataEnd,dataType=$dataType,dicData=$dicData}";
  }
}

class GetDeviceTimeData{
  int year = 2000;
  int month = 12;
  int day = 12;
  int hour = 12;
  int minute = 12;
  int second = 12;

}

final class BlueOffData extends LinkedListEntry<BlueOffData>{
  final List<int> data;
  BlueOffData(this.data);

  @override
  String toString() {
    return '$data';
  }
}