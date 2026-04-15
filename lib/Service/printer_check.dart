import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 🖨️ Data Model for Saved Printers
class PrinterConfig {
  final String osPrinterName;
  final bool isColor;
  final bool supportsDuplex;
  final int speedPpm;

  PrinterConfig({
    required this.osPrinterName,
    required this.isColor,
    required this.supportsDuplex,
    required this.speedPpm,
  });

  Map<String, dynamic> toJson() => {
        'osPrinterName': osPrinterName,
        'isColor': isColor,
        'supportsDuplex': supportsDuplex,
        'speedPpm': speedPpm,
      };

  factory PrinterConfig.fromJson(Map<String, dynamic> json) => PrinterConfig(
        osPrinterName: json['osPrinterName'],
        isColor: json['isColor'],
        supportsDuplex: json['supportsDuplex'],
        speedPpm: json['speedPpm'],
      );
}

class PrinterChecker {
  // In-memory tracker for load balancing during the current app session
  static final Map<String, int> _sessionLoads = {};

  /// 💾 SAVE config to local DB
  static Future<void> saveConfig(PrinterConfig config) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> savedList = prefs.getStringList('printer_configs') ?? [];
    savedList.removeWhere((item) => PrinterConfig.fromJson(jsonDecode(item)).osPrinterName == config.osPrinterName);
    savedList.add(jsonEncode(config.toJson()));
    await prefs.setStringList('printer_configs', savedList);
  }

  /// 💾 LOAD configs from local DB
  static Future<List<PrinterConfig>> loadConfigs() async {
    final prefs = await SharedPreferences.getInstance();
    List<String> savedList = prefs.getStringList('printer_configs') ?? [];
    return savedList.map((item) => PrinterConfig.fromJson(jsonDecode(item))).toList();
  }

  /// 🗑️ DELETE config
  static Future<void> deleteConfig(String osPrinterName) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> savedList = prefs.getStringList('printer_configs') ?? [];
    savedList.removeWhere((item) => PrinterConfig.fromJson(jsonDecode(item)).osPrinterName == osPrinterName);
    await prefs.setStringList('printer_configs', savedList);
  }

  /// 🧠 SMART ROUTER: Find the best printer based on order specs & load
  static Future<Printer> _getBestPrinter({
    required bool needsColor,
    required bool needsDuplex,
    required int jobTotalPages,
  }) async {
    List<PrinterConfig> configuredPrinters = await loadConfigs();
    if (configuredPrinters.isEmpty) throw Exception("No printers configured! Click the Settings icon to map printers.");

    final systemPrinters = await Printing.listPrinters();
    final onlinePrinters = systemPrinters.where((p) => p.isAvailable).toList();

    List<PrinterConfig> activeAndConfigured = configuredPrinters.where((config) => 
      onlinePrinters.any((p) => p.name == config.osPrinterName)
    ).toList();

    if (activeAndConfigured.isEmpty) throw Exception("Configured printers are currently offline.");

    List<PrinterConfig> capablePrinters = activeAndConfigured.where((p) {
      if (needsColor && !p.isColor) return false;
      if (needsDuplex && !p.supportsDuplex) return false; 
      return true;
    }).toList();

    if (capablePrinters.isEmpty) {
      throw Exception("No online printer supports Color: $needsColor, Duplex: $needsDuplex.");
    }

    // WEIGHTED ROUND ROBIN Load Balancing
    capablePrinters.sort((a, b) {
      int loadA = _sessionLoads[a.osPrinterName] ?? 0;
      int loadB = _sessionLoads[b.osPrinterName] ?? 0;
      return (loadA / a.speedPpm).compareTo(loadB / b.speedPpm);
    });

    PrinterConfig winnerConfig = capablePrinters.first;
    _sessionLoads[winnerConfig.osPrinterName] = (_sessionLoads[winnerConfig.osPrinterName] ?? 0) + jobTotalPages;
    debugPrint("⚖️ Routed to: ${winnerConfig.osPrinterName}");

    return onlinePrinters.firstWhere((p) => p.name == winnerConfig.osPrinterName);
  }

  /// 🚀 Execute Print
  static Future<int> printJobAutomated({
    required Uint8List bytes,
    required bool isColor,
    required bool isDuplex,
    required int copies,
    required int documentPages,
    required String jobNamePrefix,
  }) async {
    int jobsSent = 0;
    try {
      Printer targetPrinter = await _getBestPrinter(
        needsColor: isColor, needsDuplex: isDuplex, jobTotalPages: documentPages * copies,
      );

      for (int c = 0; c < copies; c++) {
        await Printing.directPrintPdf(
          printer: targetPrinter, 
          onLayout: (PdfPageFormat format) async => bytes,
          name: '${jobNamePrefix}_Copy_${c+1}',
          usePrinterSettings: true, 
        );
        jobsSent++;
        if (copies > 1 && c < copies - 1) await Future.delayed(const Duration(milliseconds: 1500));
      }
    } catch (e) { rethrow; }
    return jobsSent;
  }
}