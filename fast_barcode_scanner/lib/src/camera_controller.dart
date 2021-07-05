import 'dart:async';

import 'package:fast_barcode_scanner_platform_interface/fast_barcode_scanner_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';

class ScannerConfiguration {
  const ScannerConfiguration(
    this.types,
    this.resolution,
    this.framerate,
    this.position,
    this.detectionMode,
  );

  /// The types the scanner should look out for.
  ///
  /// If a barcode type is not in this list, it will not be detected.
  final List<BarcodeType> types;

  /// The target resolution of the camera feed.
  ///
  /// This is experimental, but functional. Should not be set higher
  /// than necessary.
  final Resolution resolution;

  /// The target framerate of the camera feed.
  ///
  /// This is experimental, but functional on iOS. Should not be set higher
  /// than necessary.
  final Framerate framerate;

  /// The physical position of the camera being used.
  final CameraPosition position;

  /// Determines how the camera reacts to detected barcodes.
  final DetectionMode detectionMode;

  ScannerConfiguration copyWith({
    List<BarcodeType>? types,
    Resolution? resolution,
    Framerate? framerate,
    DetectionMode? detectionMode,
    CameraPosition? position,
  }) {
    return ScannerConfiguration(
      types ?? this.types,
      resolution ?? this.resolution,
      framerate ?? this.framerate,
      position ?? this.position,
      detectionMode ?? this.detectionMode,
    );
  }
}

enum CameraEvent { uninitialized, init, paused, resumed, codeFound, error }

class CameraState {
  PreviewConfiguration? _previewConfig;
  ScannerConfiguration? _scannerConfig;
  bool _torchState = false;
  bool _togglingTorch = false;
  bool _configuring = false;
  Object? _error;

  Object? get error => _error;
  PreviewConfiguration? get previewConfig => _previewConfig;
  ScannerConfiguration? get scannerConfig => _scannerConfig;
  bool get torchState => _torchState;
  bool get isInitialized => _previewConfig != null;
  bool get hasError => error != null;

  final eventNotifier = ValueNotifier(CameraEvent.uninitialized);
}

class CameraController {
  CameraController._() : state = CameraState();

  static final _instance = CameraController._();
  static CameraController get instance => _instance;

  /// The cumulated state of the barcode scanner.
  ///
  /// Contains information about the configuration, torch,
  /// errors and events.
  final CameraState state;

  FastBarcodeScannerPlatform get _platform =>
      FastBarcodeScannerPlatform.instance;

  // Intents

  /// Informs the platform to initialize the camera.
  ///
  /// The camera is disposed and reinitialized when calling this
  /// method repeatedly.
  /// Events and errors are received via the current state's eventNotifier.
  Future<void> initialize(
      List<BarcodeType> types,
      Resolution resolution,
      Framerate framerate,
      CameraPosition position,
      DetectionMode detectionMode,
      void Function(Barcode)? onScan) async {
    state.eventNotifier.value = CameraEvent.init;

    try {
      if (state.isInitialized) await _platform.dispose();
      state._previewConfig = await _platform.init(
          types, resolution, framerate, detectionMode, position);

      /// Notify the overlays when a barcode is detected and then call [onDetect].
      _platform.setOnDetectHandler((code) {
        state.eventNotifier.value = CameraEvent.codeFound;
        onScan?.call(code);
      });

      state._scannerConfig = ScannerConfiguration(
          types, resolution, framerate, position, detectionMode);

      state.eventNotifier.value = CameraEvent.resumed;
    } catch (error, stack) {
      state._error = error;
      state.eventNotifier.value = CameraEvent.error;
      debugPrint(error.toString());
      debugPrintStack(stackTrace: stack);
      rethrow;
    }
  }

  /// Disposed the platform camera and resets the whole system.
  ///
  ///
  Future<void> dispose() async {
    try {
      await _platform.dispose();
      state._previewConfig = null;
      state.eventNotifier.value = CameraEvent.uninitialized;
    } catch (error, stack) {
      state._error = error;
      state.eventNotifier.value = CameraEvent.error;
      debugPrint(error.toString());
      debugPrintStack(stackTrace: stack);
      rethrow;
    }
  }

  /// Pauses the scanner and preview on the platform level.
  ///
  ///
  Future<void> pauseDetector() async {
    try {
      await _platform.stop();
      state.eventNotifier.value = CameraEvent.paused;
    } catch (error, stack) {
      state._error = error;
      state.eventNotifier.value = CameraEvent.error;
      debugPrint(error.toString());
      debugPrintStack(stackTrace: stack);
      rethrow;
    }
  }

  /// Resumes the scanner and preview on the platform level.
  ///
  ///
  Future<void> resumeDetector() async {
    try {
      await _platform.start();
      state.eventNotifier.value = CameraEvent.resumed;
    } catch (error, stack) {
      state._error = error;
      state.eventNotifier.value = CameraEvent.error;
      debugPrint(error.toString());
      debugPrintStack(stackTrace: stack);
      rethrow;
    }
  }

  /// Toggles the torch, if available.
  ///
  ///
  Future<bool> toggleTorch() async {
    if (!state._togglingTorch) {
      state._togglingTorch = true;

      try {
        state._torchState = await _platform.toggleTorch();
      } catch (error, stack) {
        state._error = error;
        state.eventNotifier.value = CameraEvent.error;
        debugPrint(error.toString());
        debugPrintStack(stackTrace: stack);
        rethrow;
      }

      state._togglingTorch = false;
    }

    return state._torchState;
  }

  Future<void> changeConfiguration({
    List<BarcodeType>? types,
    Resolution? resolution,
    Framerate? framerate,
    DetectionMode? detectionMode,
    CameraPosition? position,
  }) async {
    final _scannerConfig = state._scannerConfig;

    if (_scannerConfig != null && !state._configuring) {
      state._configuring = true;

      try {
        state._previewConfig = await _platform.changeConfiguration(
          types: types,
          resolution: resolution,
          framerate: framerate,
          detectionMode: detectionMode,
          position: position,
        );

        state._scannerConfig = _scannerConfig.copyWith(
          types: types,
          resolution: resolution,
          framerate: framerate,
          detectionMode: detectionMode,
          position: position,
        );
      } catch (error, stack) {
        state._error = error;
        state.eventNotifier.value = CameraEvent.error;
        debugPrint(error.toString());
        debugPrintStack(stackTrace: stack);
        rethrow;
      }

      state._configuring = false;
    }
  }
}
