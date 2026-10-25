import 'dart:ui';

import '../../theme/app_colors.dart';

/// Capa del loro pirata en un lienzo de 512 x 512. Mismos nombres y trazos que el componente
/// "Mascota" de Figma (página Mascota), para que diseño y código no se separen.
class ParrotLayer {
  const ParrotLayer(this.name, this.color, this.path, this.pivot, {this.stroke});

  final String name;
  final Color color;
  final String path;
  final Offset pivot;

  /// Grosor del trazo; `null` si la capa es de relleno.
  final double? stroke;
}

/// Capas en orden de pintado (de atrás hacia adelante).
const parrotLayers = <ParrotLayer>[
  ParrotLayer(
    'shadow',
    AppColors.tint40,
    'M 250 455 C 315.2 455 368 460.8 368 468 C 368 475.2 315.2 481 250 481 C 184.8 481 132 475.2 132 468 C 132 460.8 184.8 455 250 455 Z',
    Offset(250.0, 468.0),
  ),
  ParrotLayer(
    'tail',
    AppColors.deep,
    'M 196 352 C 168 380 128 420 84 452 C 112 452 132 446 150 436 C 140 452 128 462 112 474 C 150 470 182 446 204 418 C 214 400 214 376 196 352 Z',
    Offset(200.0, 380.0),
  ),
  ParrotLayer(
    'foot_back',
    AppColors.deep,
    'M 290 412 C 290 426 286 436 278 446 L 318 446 C 312 436 308 426 308 412 Z',
    Offset(299.0, 430.0),
  ),
  ParrotLayer(
    'body',
    AppColors.primary,
    'M 262 176 C 342 178 378 254 370 330 C 362 400 312 432 258 428 C 200 424 166 380 170 320 C 174 250 200 176 262 176 Z',
    Offset(262.0, 300.0),
  ),
  ParrotLayer(
    'belly',
    AppColors.surface,
    'M 318 228 C 358 254 366 318 348 364 C 332 400 298 412 274 404 C 304 378 320 318 318 228 Z',
    Offset(320.0, 320.0),
  ),
  ParrotLayer(
    'foot_front',
    AppColors.deep,
    'M 252 414 C 252 428 248 438 240 448 L 282 448 C 276 438 272 428 272 414 Z',
    Offset(262.0, 430.0),
  ),
  ParrotLayer(
    'wing',
    AppColors.deep,
    'M 226 236 C 172 252 150 330 168 392 C 178 426 204 446 226 452 C 214 430 212 404 218 382 C 236 404 246 410 258 412 C 244 388 240 364 244 344 C 262 318 270 278 226 236 Z',
    Offset(226.0, 252.0),
  ),
  ParrotLayer(
    'head',
    AppColors.primary,
    'M 300 80 C 344.2 80 380 115.8 380 160 C 380 204.2 344.2 240 300 240 C 255.8 240 220 204.2 220 160 C 220 115.8 255.8 80 300 80 Z',
    Offset(300.0, 200.0),
  ),
  ParrotLayer(
    'face',
    AppColors.surface,
    'M 324 112 C 347.2 112 366 133.5 366 160 C 366 186.5 347.2 208 324 208 C 300.8 208 282 186.5 282 160 C 282 133.5 300.8 112 324 112 Z',
    Offset(324.0, 160.0),
  ),
  ParrotLayer('eye_happy', AppColors.ink, 'M 306 162 Q 320 144 334 162', Offset(320.0, 156.0), stroke: 8.0),
  ParrotLayer(
    'eye_open',
    AppColors.ink,
    'M 322 144 C 327.5 144 332 148.5 332 154 C 332 159.5 327.5 164 322 164 C 316.5 164 312 159.5 312 154 C 312 148.5 316.5 144 322 144 Z',
    Offset(322.0, 154.0),
  ),
  ParrotLayer(
    'eye_shine',
    AppColors.surface,
    'M 326 146.5 C 327.9 146.5 329.5 148.1 329.5 150 C 329.5 151.9 327.9 153.5 326 153.5 C 324.1 153.5 322.5 151.9 322.5 150 C 322.5 148.1 324.1 146.5 326 146.5 Z',
    Offset(326.0, 150.0),
  ),
  ParrotLayer('eye_sad', AppColors.ink, 'M 306 152 Q 320 168 334 152', Offset(320.0, 158.0), stroke: 8.0),
  ParrotLayer(
    'beak_lower',
    AppColors.action,
    'M 356 182 C 376 180 394 190 392 204 C 382 218 360 214 354 200 Z',
    Offset(356.0, 186.0),
  ),
  ParrotLayer(
    'beak_upper',
    AppColors.deep,
    'M 348 128 C 392 120 426 150 422 196 C 420 210 406 214 400 202 C 396 184 380 176 354 184 C 344 166 342 146 348 128 Z',
    Offset(352.0, 160.0),
  ),
  ParrotLayer(
    'hat_crown',
    AppColors.deep,
    'M 228 112 C 226 74 254 46 294 42 C 334 40 366 62 374 104 C 330 96 272 98 228 112 Z',
    Offset(300.0, 110.0),
  ),
  ParrotLayer(
    'hat_brim',
    AppColors.action,
    'M 194 134 C 190 106 198 82 214 70 C 232 96 262 104 300 102 C 340 100 374 92 400 72 C 412 92 412 116 402 130 C 350 114 250 116 194 134 Z',
    Offset(300.0, 118.0),
  ),
  ParrotLayer('hat_mark', AppColors.surface, 'M 284 58 L 306 80 M 306 58 L 284 80', Offset(295.0, 69.0), stroke: 9.0),
  ParrotLayer('fx_greet', AppColors.deep, 'M 392 64 L 406 42 M 414 92 L 438 80', Offset(410.0, 70.0), stroke: 8.0),
  ParrotLayer(
    'fx_bulb',
    AppColors.deep,
    'M 432 46 C 420 46 410 56 410 68 C 410 78 416 84 420 90 L 444 90 C 448 84 454 78 454 68 C 454 56 444 46 432 46 Z M 422 100 L 442 100',
    Offset(432.0, 70.0),
    stroke: 6.0,
  ),
  ParrotLayer(
    'fx_rays',
    AppColors.deep,
    'M 432 22 L 432 32 M 466 40 L 458 48 M 398 40 L 406 48',
    Offset(432.0, 40.0),
    stroke: 6.0,
  ),
  ParrotLayer(
    'fx_sparkle_a',
    AppColors.tint80,
    'M 148 134 Q 152.5 145.5 164 150 Q 152.5 154.5 148 166 Q 143.5 154.5 132 150 Q 143.5 145.5 148 134 Z',
    Offset(148.0, 150.0),
  ),
  ParrotLayer(
    'fx_sparkle_b',
    AppColors.tint80,
    'M 452 202 Q 455.4 210.6 464 214 Q 455.4 217.4 452 226 Q 448.6 217.4 440 214 Q 448.6 210.6 452 202 Z',
    Offset(452.0, 214.0),
  ),
  ParrotLayer('fx_wave_a', AppColors.deep, 'M 434 168 Q 452 194 434 220', Offset(434.0, 194.0), stroke: 8.0),
  ParrotLayer('fx_wave_b', AppColors.deep, 'M 458 150 Q 486 194 458 238', Offset(458.0, 194.0), stroke: 8.0),
];
