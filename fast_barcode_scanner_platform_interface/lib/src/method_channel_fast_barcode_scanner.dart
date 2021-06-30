import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'types/barcode.dart';
import 'types/barcode_type.dart';
import 'types/preview_configuration.dart';
import 'fast_barcode_scanner_platform_interface.dart';

class MethodChannelFastBarcodeScanner extends FastBarcodeScannerPlatform {
  static const MethodChannel _channel =
      MethodChannel('com.jhoogstraat/fast_barcode_scanner');

  void Function(Barcode)? _onDetectHandler;

  @override
  Future<PreviewConfiguration> init(
      List<BarcodeType> types,
      Resolution resolution,
      Framerate framerate,
      DetectionMode detectionMode,
      CameraPosition position) async {
    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'r':
          // This might fail if the code type is not present in the list of available code types.
          // Barcode init will throw in this case.
          final barcode = Barcode(call.arguments);
          _onDetectHandler?.call(barcode);
          break;
        default:
          assert(true,
              "FastBarcodeScanner: Unknown method call received: ${call.method}");
      }
    });

    final response = await _channel.invokeMethod('start', {
      'types': types.map((e) => describeEnum(e)).toList(growable: false),
      'mode': describeEnum(detectionMode),
      'res': describeEnum(resolution),
      'fps': describeEnum(framerate),
      'pos': describeEnum(position)
    });

    return PreviewConfiguration(response);
  }

  @override
  Future<void> pause() => _channel.invokeMethod('pause');

  @override
  Future<void> resume() => _channel.invokeMethod('resume');

  @override
  Future<void> dispose() {
    _channel.setMethodCallHandler(null);
    _onDetectHandler = null;
    return _channel.invokeMethod('stop');
  }

  @override
  Future<bool> toggleTorch() =>
      _channel.invokeMethod('toggleTorch').then<bool>((isOn) => isOn);

  @override
  Future<PreviewConfiguration> changeConfiguration({
    List<BarcodeType>? types,
    Resolution? resolution,
    Framerate? framerate,
    DetectionMode? detectionMode,
    CameraPosition? position,
  }) async {
    final response = await _channel.invokeMethod('config', {
      if (types != null) 'types': types.map((e) => describeEnum(e)).toList(),
      if (detectionMode != null) 'mode': describeEnum(detectionMode),
      if (resolution != null) 'res': describeEnum(resolution),
      if (framerate != null) 'fps': describeEnum(framerate),
      if (position != null) 'pos': describeEnum(position),
    });
    print(response);
    return PreviewConfiguration(response);
  }

  @override
  void setOnDetectHandler(void Function(Barcode) handler) =>
      _onDetectHandler = handler;
}
