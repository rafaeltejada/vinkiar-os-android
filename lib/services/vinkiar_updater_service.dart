import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:ota_update/ota_update.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../config/api_config.dart';
import '../ui/theme.dart';

class VinkiarUpdaterService {
  /// Consulta el servidor backend para determinar si hay un APK nativo superior disponible
  static Future<void> checkForUpdates(BuildContext context, {bool silent = true}) async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final String currentVersion = packageInfo.version;

      final url = Uri.parse('${ApiConfig.baseUrl}/api/v1/app/version');
      final response = await http.get(url).timeout(const Duration(seconds: 5));

      if (response.statusCode != 200) return;

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final String latestVersion = data['latest_version'] ?? currentVersion;
      final String apkUrl = data['apk_url'] ?? '';
      final String releaseNotes = data['release_notes'] ?? 'Nueva versión disponible.';
      final bool forceUpdate = data['force_update'] ?? false;

      if (_isVersionHigher(latestVersion, currentVersion)) {
        if (!context.mounted) return;
        _showUpdateModal(
          context,
          latestVersion: latestVersion,
          currentVersion: currentVersion,
          releaseNotes: releaseNotes,
          apkUrl: apkUrl,
          forceUpdate: forceUpdate,
        );
      } else if (!silent && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: VinkiarColors.panelDark,
            content: Text(
              "Vinkiar OS está en su versión nativa más reciente ($currentVersion).",
              style: GoogleFonts.jetBrainsMono(color: VinkiarColors.hackingGreen, fontSize: 11),
            ),
          ),
        );
      }
    } catch (e) {
      print(">>> [VINKIAR_UPDATER_ERROR]: $e");
    }
  }

  /// Compara dos cadenas SemVer (ej. "1.0.1" vs "1.0.0")
  static bool _isVersionHigher(String latest, String current) {
    try {
      List<int> l = latest.split('.').map((e) => int.parse(e.split('+').first)).toList();
      List<int> c = current.split('.').map((e) => int.parse(e.split('+').first)).toList();

      for (int i = 0; i < l.length && i < c.length; i++) {
        if (l[i] > c[i]) return true;
        if (l[i] < c[i]) return false;
      }
      return l.length > c.length;
    } catch (_) {
      return false;
    }
  }

  /// Diálogo estilizado cyberpunk para notificar la descarga
  static void _showUpdateModal(
    BuildContext context, {
    required String latestVersion,
    required String currentVersion,
    required String releaseNotes,
    required String apkUrl,
    required bool forceUpdate,
  }) {
    double downloadProgress = 0.0;
    bool isDownloading = false;

    showDialog(
      context: context,
      barrierDismissible: !forceUpdate,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setStateModal) {
            return AlertDialog(
              backgroundColor: VinkiarColors.abyssBlack,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: VinkiarColors.aegisCyan, width: 1.5),
              ),
              title: Row(
                children: [
                  const Icon(Icons.system_update, color: VinkiarColors.aegisCyan, size: 22),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "ACTUALIZACIÓN NATIVA v$latestVersion",
                      style: GoogleFonts.jetBrainsMono(
                        color: VinkiarColors.aegisCyan,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Versión instalada: v$currentVersion",
                    style: GoogleFonts.jetBrainsMono(color: Colors.grey, fontSize: 10),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: VinkiarColors.panelDark,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: VinkiarColors.aegisCyan.withOpacity(0.3)),
                    ),
                    child: Text(
                      releaseNotes,
                      style: GoogleFonts.outfit(color: Colors.white70, fontSize: 11),
                    ),
                  ),
                  if (isDownloading) ...[
                    const SizedBox(height: 16),
                    LinearProgressIndicator(
                      value: downloadProgress > 0 ? downloadProgress / 100 : null,
                      backgroundColor: VinkiarColors.panelDark,
                      color: VinkiarColors.aegisCyan,
                    ),
                    const SizedBox(height: 6),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        "${downloadProgress.toStringAsFixed(0)}%",
                        style: GoogleFonts.jetBrainsMono(color: VinkiarColors.aegisCyan, fontSize: 10),
                      ),
                    ),
                  ],
                ],
              ),
              actions: [
                if (!forceUpdate && !isDownloading)
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: Text("MÁS TARDE", style: GoogleFonts.jetBrainsMono(color: Colors.grey, fontSize: 11)),
                  ),
                if (!isDownloading)
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: VinkiarColors.aegisCyan,
                      foregroundColor: Colors.black,
                    ),
                    onPressed: () {
                      setStateModal(() {
                        isDownloading = true;
                      });

                      try {
                        OtaUpdate()
                            .execute(apkUrl, destinationFilename: 'vinkiar_update.apk')
                            .listen((OtaEvent event) {
                          if (event.status == OtaStatus.DOWNLOADING) {
                            setStateModal(() {
                              downloadProgress = double.tryParse(event.value ?? '0') ?? 0.0;
                            });
                          } else if (event.status == OtaStatus.INSTALLING) {
                            Navigator.pop(ctx);
                          }
                        }, onError: (e) {
                          setStateModal(() {
                            isDownloading = false;
                          });
                        });
                      } catch (e) {
                        setStateModal(() {
                          isDownloading = false;
                        });
                      }
                    },
                    child: Text(
                      "INSTALAR APK",
                      style: GoogleFonts.jetBrainsMono(fontWeight: FontWeight.bold, fontSize: 11),
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }
}