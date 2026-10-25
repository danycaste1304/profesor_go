import 'package:flutter/material.dart';

import '../../../../app/theme.dart';
import 'map_label.dart';

/// The labels of the fair, in map units (720 x 1290 canvas).
///
/// The department codes follow the Politécnico tent floor plan on a grid of
/// 3 columns (x = 136, 221, 305) and 5 rows (y = 806 ... 1002, every 49 map
/// units): FIS, IME and ICV on the top row; MAT, AGE, ALI, INQ down the left
/// side; IIN, IEL, MAC, CMP down the right. POLI and ENTRADA LAB are free.
/// Every position is final and no label is draggable. To move one again, give
/// it `draggable: MapLabel.dragEnabled` (see [MapLabel]) and paste the logged
/// `Offset(x, y)`.
abstract final class FairMapLabels {
  /// Size of every pill on the map, relative to a normal `PixelPill`. Change
  /// it here to resize all the labels at once.
  static const double globalPillScale = 1.1;

  static const List<MapLabel> all = [
    // The tent itself: picture + pill.
    MapLabel(
      id: 'poli',
      position: Offset(220, 975),
      label: 'Poli',
      tinted: true,
      color: AppColors.danger,
      image: AssetImage('assets/map/tent.png'),
      imageHeight: 100,
      pillScale: 1.5,
    ),

    // Direction of the laboratory entrance; replaces the painted sign.
    MapLabel(
      id: 'entrada-lab',
      // Final position: pinned, so it cannot be dragged by accident.
      position: Offset(598, 510),
      label: 'Entrada Lab ->',
      tinted: true,
      color: AppColors.danger,
      pillScale: 1.5,
    ),

    // Department booths: Computación and MAC stand out in yellow, the rest are
    // a muted dark blue. Left column first, then right.
    MapLabel(
      id: 'inq',
      position: Offset(136, 1002),
      label: 'INQ',
      color: AppColors.text,
      pillScale: globalPillScale,
    ),
    MapLabel(
      id: 'ali',
      position: Offset(136, 953),
      label: 'ALI',
      color: AppColors.text,
      pillScale: globalPillScale,
    ),
    MapLabel(
      id: 'age',
      position: Offset(136, 904),
      label: 'AGE',
      color: AppColors.text,
      pillScale: globalPillScale,
    ),
    MapLabel(
      id: 'mat',
      position: Offset(136, 855),
      label: 'MAT',
      color: AppColors.text,
      pillScale: globalPillScale,
    ),
    MapLabel(
      id: 'ime',
      position: Offset(221, 806),
      label: 'IME',
      color: AppColors.text,
      pillScale: globalPillScale,
    ),
    MapLabel(
      id: 'icv',
      position: Offset(305, 806),
      label: 'ICV',
      color: AppColors.text,
      pillScale: globalPillScale,
    ),
    MapLabel(
      id: 'iin',
      position: Offset(305, 855),
      label: 'IIN',
      color: AppColors.text,
      pillScale: globalPillScale,
    ),
    MapLabel(
      id: 'iel',
      position: Offset(305, 904),
      label: 'IEL',
      color: AppColors.text,
      pillScale: globalPillScale,
    ),
    MapLabel(
      id: 'cmp',
      position: Offset(305, 1002),
      label: 'CMP',
      // Same yellow as the tertiary button, with its dark text.
      color: AppColors.accent,
      foreground: AppColors.text,
      pillScale: globalPillScale,
    ),
    MapLabel(
      id: 'mac',
      position: Offset(305, 953),
      label: 'MAC',
      // Same yellow as the tertiary button, with its dark text.
      color: AppColors.accent,
      foreground: AppColors.text,
      pillScale: globalPillScale,
    ),
    // Física, added after the two columns: it sits above them, centered.
    MapLabel(
      id: 'fis',
      position: Offset(136, 806),
      label: 'FIS',
      color: AppColors.text,
      pillScale: globalPillScale,
    ),

    // Five more tents, picture only (no pill), in their final spots.
    MapLabel(
      id: 'carpa-1',
      semanticLabel: 'Carpa',
      position: Offset(263, 650),
      image: AssetImage('assets/map/tent.png'),
      imageHeight: 100,
    ),
    MapLabel(
      id: 'carpa-2',
      semanticLabel: 'Carpa',
      position: Offset(238, 760),
      image: AssetImage('assets/map/tent.png'),
      imageHeight: 100,
    ),
    MapLabel(
      id: 'carpa-3',
      semanticLabel: 'Carpa',
      position: Offset(458, 623),
      image: AssetImage('assets/map/tent.png'),
      imageHeight: 100,
    ),
    MapLabel(
      id: 'carpa-4',
      semanticLabel: 'Carpa',
      position: Offset(519, 720),
      image: AssetImage('assets/map/tent.png'),
      imageHeight: 100,
    ),
    MapLabel(
      id: 'carpa-5',
      semanticLabel: 'Carpa',
      position: Offset(586, 828),
      image: AssetImage('assets/map/tent.png'),
      imageHeight: 100,
    ),
  ];
}
