

import 'dart:io';

///常量类
class Constant{

  static String NOTIY = Platform.isAndroid?"00002902-0000-1000-8000-00805f9b34fb":"0000";
  static String SERVICE_DATA = Platform.isAndroid?"0000fff0-0000-1000-8000-00805f9b34fb":"FFF0";
  static String DATA_CHARACTERISTIC = Platform.isAndroid?"0000fff6-0000-1000-8000-00805f9b34fb":"FFF6";
  static String NOTIY_CHARACTERISTIC = Platform.isAndroid?"0000fff7-0000-1000-8000-00805f9b34fb":"FFF7";


  ///蓝牙状态监听
  static const String BLUEMETHODNAME = "BLUEMETHODNAME";
  ///蓝牙连接中
  static const int BLUECONNECTING = 0;
  ///蓝牙已连接
  static const int BLUECONNECTED = 1;
  ///蓝牙已断开
  static const int BLUEDISCONNECTED = 2;
  ///蓝牙服务已连接
  static const int BLUESERVICECONNECTED = 3;

}