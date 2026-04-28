// 지도 화면

import 'package:flutter/material.dart';
import 'package:running/features/map/widgets/map_view.dart';
import 'package:running/features/map/widgets/map_app_bar.dart';
import 'package:running/features/map/widgets/map_fab.dart';
import 'package:running/features/map/widgets/map_bottom_panel.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const MapAppBar(),
      body: const MapView(),
      floatingActionButton: const MapFab(),
      bottomNavigationBar: const MapBottomPanel(),
    );
  }
}