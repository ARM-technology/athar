
import 'package:flutter_riverpod/legacy.dart';





final counterProvider = StateProvider<int>((ref) => 0);

final screenWidthProvider = StateProvider<double>((ref) => 0);
final screenHightProvider = StateProvider<double>((ref) => 0);