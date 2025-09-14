// lib/services/printer_check.dart

import 'dart:ffi';
import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';

bool isPrinterAvailable() {
  final pcbNeeded = calloc<Uint32>();
  final pcReturned = calloc<Uint32>();

  EnumPrinters(
    PRINTER_ENUM_LOCAL | PRINTER_ENUM_CONNECTIONS,
    nullptr,
    2,
    nullptr,
    0,
    pcbNeeded,
    pcReturned,
  );

  final connected = pcReturned.value > 0;

  calloc.free(pcbNeeded);
  calloc.free(pcReturned);

  return connected;
}
