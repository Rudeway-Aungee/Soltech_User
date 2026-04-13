import 'package:flutter/material.dart';

class AssociateMethods {
  void showSnackBarMsg(String msg, BuildContext cxt){
    final snackBar = SnackBar(
      content: Text(msg)
    );
    ScaffoldMessenger.of(cxt).showSnackBar(snackBar);
  }
}