import 'package:flutter/material.dart';
import 'vinkiar_secure_database.dart';
import '../ui/theme.dart';
import '../ui/widgets/contextual_onboarding_modal.dart';

enum OnboardingTopic {
  bovedaSoulSheet,
  tabernaEconomy,
  radarHaptic,
  chatZkaTunnels,
  celulaAlliances,
  tribuBolsaComun,
  armeriaSentinel,
}

class OnboardingGuideSpec {
  final OnboardingTopic topic;
  final String codeTag;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accentColor;
  final List<String> bullets;
  final String footerNote;

  const OnboardingGuideSpec({
    required this.topic,
    required this.codeTag,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accentColor,
    required this.bullets,
    required this.footerNote,
  });
}

class OnboardingGuideService {
  static final OnboardingGuideService _instance = OnboardingGuideService._internal();
  factory OnboardingGuideService() => _instance;
  OnboardingGuideService._internal();

  static const String _prefix = 'onboarding_seen_';
  static const String _mutedKey = 'onboarding_global_muted';

  bool _isDialogVisible = false;

  static const Map<OnboardingTopic, OnboardingGuideSpec> specs = {
    OnboardingTopic.bovedaSoulSheet: OnboardingGuideSpec(
      topic: OnboardingTopic.bovedaSoulSheet,
      codeTag: 'MÓDULO 01 // LA BÓVEDA ZKA',
      title: 'Tu Búnker Criptográfico y Triple Eneagrama',
      subtitle: 'Todo lo que ves aquí vive cifrado exclusivamente en tu dispositivo mediante Argon2id + SQLCipher.',
      icon: Icons.shield_outlined,
      accentColor: VinkiarColors.aegisCyan,
      bullets: [
        'Arquetipo Natural vs. Rol Elegido: Observa tu núcleo somático compilado en La Forja y mide tu alineación cuando adoptas una máscara social.',
        'Triple Eneagrama Vivo: Las 3 ruedas (Ego, Eros y Philia) evolucionan orgánicamente con cada entrada en tu Bitácora Clandestina.',
        'Soberanía Total: Gestiona tus llaves ZKP, tu semilla de 12 palabras y tus límites base SSC sin servidores centrales.',
      ],
      footerNote: 'Ningún dato íntimo o psicométrico abandona tu teléfono sin cifrar.',
    ),
    OnboardingTopic.tabernaEconomy: OnboardingGuideSpec(
      topic: OnboardingTopic.tabernaEconomy,
      codeTag: 'MÓDULO 02 // LA TABERNA PHYGITAL',
      title: 'Economía de Vinks (Ѵ) y Misiones Analógicas',
      subtitle: 'El Ágora donde la tecnología sirve para llevarte al encuentro presencial en el mundo físico.',
      icon: Icons.storefront_outlined,
      accentColor: VinkiarColors.vertigoGold,
      bullets: [
        'Saldo de Vinks (Ѵ): Tu divisa de reciprocidad. Gánala completando retos analógicos o aportando valor a tu Célula.',
        'Oráculo Proactivo RAG: Vinki analiza tus reflexiones recientes para sugerirte misiones que equilibren tus ruedas.',
        'Glifos de Barra B2B: Canjea encuentros en Santuarios físicos acreditados mediante códigos efímeros de 90 segundos sin revelar tu identidad civil.',
      ],
      footerNote: 'Sin scroll infinito ni algoritmos de adicción: entra, pacta y vive fuera de la pantalla.',
    ),
    OnboardingTopic.radarHaptic: OnboardingGuideSpec(
      topic: OnboardingTopic.radarHaptic,
      codeTag: 'MÓDULO 03 // RADAR HÁPTICO ZKA',
      title: 'Proximidad Ofuscada y Sintonía Doble Ciego',
      subtitle: 'Descubre Santuarios B2B y Avatares afines sin exponer jamás tu ubicación exacta.',
      icon: Icons.radar,
      accentColor: VinkiarColors.hackingGreen,
      bullets: [
        'Jitter de Privacidad (±300 m): Los nodos móviles aplican desplazamiento criptográfico aleatorio para impedir cualquier triangulación exacta.',
        'Pings Doble Ciego: Envía un pulso verde de interés; el canal solo se abre si ambas partes coinciden de forma mutua.',
        'Santuarios Neutrales: Localiza cafeterías, espacios culturales y gabinetes acreditados para primeros encuentros seguros.',
      ],
      footerNote: 'Tu GPS real nunca se almacena en historial remoto.',
    ),
    OnboardingTopic.chatZkaTunnels: OnboardingGuideSpec(
      topic: OnboardingTopic.chatZkaTunnels,
      codeTag: 'MÓDULO 04 // CANAL CIFRADO ZKA',
      title: 'Túneles Volátiles, Cápsulas y Mediación @vinki',
      subtitle: 'Comunicación efímera con amnesia programada y contratos notariales en Escrow.',
      icon: Icons.chat_bubble_outline,
      accentColor: VinkiarColors.aegisCyan,
      bullets: [
        'Cápsulas Efímeras: Envía fotos, vídeos o notas de voz de un solo uso que se purgan forensemente tras visualizarse.',
        'Mención @vinki en Hilo: Invoca a Vinki como mediador neutral cuando necesitéis traducir fricciones mediante el protocolo GRIP.',
        'Notaría Escrow 2-de-2: Bloquea Vinks en garantía para citas en Santuarios o subastas de tareas; se liberan con doble firma mutua.',
      ],
      footerNote: 'Alterna el icono del candado superior para auditar el blob cifrado en tiempo real.',
    ),
    OnboardingTopic.celulaAlliances: OnboardingGuideSpec(
      topic: OnboardingTopic.celulaAlliances,
      codeTag: 'MÓDULO 05 // CÉLULA Y ALIANZAS',
      title: 'Doble Semáforo SSC, Tribus y Linaje ZK',
      subtitle: 'Construye vínculos soberanos mediante consentimiento explícito y revelación gradual.',
      icon: Icons.group_outlined,
      accentColor: VinkiarColors.hackingGreen,
      bullets: [
        'Doble Semáforo SSC: Configura tus límites Verdes, Amarillos y Rojos para cada vínculo y desbloquéalos progresivamente.',
        'Tribus Federadas: Crea células comunitarias con tesorería compartida y toma de decisiones sin tiranía de la mayoría.',
        'Red de Avales ZK: Tu reputación lúdica crece al avalar avatares íntegros, conservando siempre el derecho a retirar tu aval.',
      ],
      footerNote: 'Honramos por igual amistades profundas, redes no monógamas, células creativas y vínculos diádicos.',
    ),
    OnboardingTopic.tribuBolsaComun: OnboardingGuideSpec(
      topic: OnboardingTopic.tribuBolsaComun,
      codeTag: 'MÓDULO 06 // TESORERÍA DE TRIBU',
      title: 'Bolsa Común y Gobernanza sin Tiranía',
      subtitle: 'Fondo colectivo de Vinks (Ѵ) auditado por quórum y protegido por Veto Absoluto SSC.',
      icon: Icons.account_balance_wallet_outlined,
      accentColor: VinkiarColors.vertigoGold,
      bullets: [
        'Aportaciones Voluntarias: Transfiere Vinks desde tu Bóveda personal al fondo común para financiar actividades o encuentros de la Tribu.',
        'Propuestas con Quórum: Ningún miembro puede retirar fondos unilateralmente sin alcanzar el umbral de aprobación pactado.',
        'Veto Rojo SSC: Cualquier integrante puede vetar sin penalización una propuesta que vulnere sus límites de seguridad.',
      ],
      footerNote: 'Cada movimiento queda registrado de forma transparente para todos los miembros de la Tribu.',
    ),
    OnboardingTopic.armeriaSentinel: OnboardingGuideSpec(
      topic: OnboardingTopic.armeriaSentinel,
      codeTag: 'MÓDULO 07 // ESCUDO CENTINELA',
      title: 'Suministros, Ancla SOS y PIN de Coacción',
      subtitle: 'Protección física y digital en encuentros presenciales mediante custodia forense WORM.',
      icon: Icons.security,
      accentColor: VinkiarColors.panicRed,
      bullets: [
        'Ancla de Confianza: Designa un contacto que recibirá tu posición GPS y enlace a la Consola Forense si activas una alerta SOS.',
        'PIN de Coacción Silente (Duress): Si alguien te obliga a desactivar una alerta, este PIN simula el apagado mientras sigue grabando audio.',
        'Modo Señuelo: Camufla la interfaz de La Bóveda al instante si necesitas privacidad visual en un espacio público.',
      ],
      footerNote: 'Tus evidencias SOS se sellan con hash SHA-256 inmutable.',
    ),
  };

  Future<bool> isGlobalMuted() async {
    final val = await VinkiarSecureDatabase().getConfigValue(_mutedKey);
    return val == '1';
  }

  Future<void> setGlobalMuted(bool muted) async {
    await VinkiarSecureDatabase().setConfigValue(_mutedKey, muted ? '1' : '0');
  }

  Future<bool> hasSeen(OnboardingTopic topic) async {
    final val = await VinkiarSecureDatabase().getConfigValue('$_prefix${topic.name}');
    return val == '1';
  }

  Future<void> markSeen(OnboardingTopic topic) async {
    await VinkiarSecureDatabase().setConfigValue('$_prefix${topic.name}', '1');
  }

  /// Borra todos los flags de guías vistas para volver a mostrar los popups en cada pantalla
  Future<void> resetAllGuides() async {
    final db = VinkiarSecureDatabase();
    await db.setConfigValue(_mutedKey, '0');
    await db.deleteConfigByPrefix(_prefix);
  }

  /// Muestra el popup contextual si es la primera vez que se visita `topic` (o si `forceShow` es true)
  Future<void> showIfFirstTime(
    BuildContext context,
    OnboardingTopic topic, {
    bool forceShow = false,
  }) async {
    if (_isDialogVisible) return;

    if (!forceShow) {
      if (await isGlobalMuted()) return;
      if (await hasSeen(topic)) return;
    }

    if (!context.mounted) return;
    final spec = specs[topic];
    if (spec == null) return;

    _isDialogVisible = true;
    try {
      await markSeen(topic);
      if (!context.mounted) return;
      await showDialog<void>(
        context: context,
        barrierDismissible: true,
        builder: (ctx) => ContextualOnboardingModal(
          spec: spec,
          onMuteAllChanged: (mute) => setGlobalMuted(mute),
        ),
      );
    } finally {
      _isDialogVisible = false;
    }
  }
}
