import 'package:flutter/material.dart';
import '../models/lucky_state.dart';

class AvatarController extends ChangeNotifier {

  LuckyState currentState = LuckyState.idle;

  void setState(LuckyState state){

    currentState=state;

    notifyListeners();

  }

}