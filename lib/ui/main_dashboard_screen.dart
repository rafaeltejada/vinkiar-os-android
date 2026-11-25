import 'dart:async';
import 'package:flutter/material.dart';
import '../services/onboarding_guide_service.dart';
import '../services/vinkiar_secure_database.dart';
import '../services/vinkiar_push_service.dart';
import '../services/vinkiar_updater_service.dart';
import 'taberna_screen.dart';
import 'radar_screen.dart';
import 'boveda_screen.dart';
import 'chat_qa_screen.dart';
import 'contacts_screen.dart';
import 'theme.dart';

class MainDashboardScreen extends StatefulWidget {
  const MainDashboardScreen({Key? key}) : super(key: key);

  @override
  State<MainDashboardScreen> createState() => _MainDashboardScreenState();
}

class _MainDashboardScreenState extends State<MainDashboardScreen> {
  int _currentIndex = 2; // Inicia en La Bóveda
  int _tabernaRevision = 0;
  final GlobalKey<BovedaScreenState> _bovedaKey = GlobalKey<BovedaScreenState>();

  @override
  void initState() {
    super.initState();
    VinkiarSecureDatabase.avatarChangeNotifier.addListener(_onAvatarStateChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      VinkiarUpdaterService.checkForUpdates(context, silent: true);
      unawaited(VinkiarPushService().syncDeviceTokenWithBackend());
      await Future.delayed(const Duration(milliseconds: 450));
      if (mounted) {
        _triggerOnboardingForTab(_currentIndex);
      }
    });
  }

  @override
  void dispose() {
    VinkiarSecureDatabase.avatarChangeNotifier.removeListener(_onAvatarStateChanged);
    super.dispose();
  }

  void _onAvatarStateChanged() {
    if (!mounted) return;
    setState(() {
      _tabernaRevision++;
    });
  }

  void _triggerOnboardingForTab(int index) {
    final guide = OnboardingGuideService();
    switch (index) {
      case 0:
        guide.showIfFirstTime(context, OnboardingTopic.tabernaEconomy);
        break;
      case 1:
        guide.showIfFirstTime(context, OnboardingTopic.radarHaptic);
        break;
      case 2:
        guide.showIfFirstTime(context, OnboardingTopic.bovedaSoulSheet);
        break;
      case 3:
        guide.showIfFirstTime(context, OnboardingTopic.chatZkaTunnels);
        break;
      case 4:
        guide.showIfFirstTime(context, OnboardingTopic.celulaAlliances);
        break;
    }
  }

  void _onTabTapped(int index) {
    setState(() {
      _currentIndex = index;
      if (index == 0) {
        _tabernaRevision++;
      }
    });
    if (index == 2) {
      _bovedaKey.currentState?.reload();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _triggerOnboardingForTab(index);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> tabs = [
      KeyedSubtree(
        key: ValueKey('taberna_rev_$_tabernaRevision'),
        child: const TabernaScreen(),
      ),
      const RadarScreen(),
      BovedaScreen(key: _bovedaKey),
      const ChatQAScreen(),
      const ContactsScreen(),
    ];

    return Scaffold(
      backgroundColor: VinkiarColors.abyssBlack,
      body: IndexedStack(
        index: _currentIndex,
        children: tabs,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: _onTabTapped,
        backgroundColor: VinkiarColors.panelDark,
        selectedItemColor: VinkiarColors.aegisCyan,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.storefront), label: "Taberna"),
          BottomNavigationBarItem(icon: Icon(Icons.radar), label: "Radar"),
          BottomNavigationBarItem(icon: Icon(Icons.shield), label: "Bóveda"),
          BottomNavigationBarItem(icon: Icon(Icons.chat_bubble_outline), label: "Chat ZKA"),
          BottomNavigationBarItem(icon: Icon(Icons.group_outlined), label: "Célula"),
        ],
      ),
    );
  }
}
