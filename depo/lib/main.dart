import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_core/firebase_core.dart';
import 'core/theme.dart';
import 'screens/barkod_nfc_eslestirme_screen.dart';
import 'screens/nfc_bilgi_screen.dart';
import 'screens/stok_kontrol_screen.dart';
import 'screens/loglar_screen.dart';
import 'screens/nfc_kayit_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const GiygecDepoApp());
}

class GiygecDepoApp extends StatelessWidget {
  const GiygecDepoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GiyGeç Depo',
      debugShowCheckedModeBanner: false,
      theme: DepoTheme.lightTheme,
      home: const DepoHomeScreen(),
    );
  }
}

class DepoHomeScreen extends StatefulWidget {
  const DepoHomeScreen({super.key});

  @override
  State<DepoHomeScreen> createState() => _DepoHomeScreenState();
}

class _DepoHomeScreenState extends State<DepoHomeScreen> {
  int _selectedIndex = 0;

  static const List<_NavItem> _navItems = [
    _NavItem(
      label: 'Eşleştirme',
      icon: Icons.link,
      activeIcon: Icons.link,
    ),
    _NavItem(
      label: 'NFC Bilgi',
      icon: Icons.nfc_outlined,
      activeIcon: Icons.nfc,
    ),
    _NavItem(
      label: 'Stok',
      icon: Icons.inventory_2_outlined,
      activeIcon: Icons.inventory_2,
    ),
    _NavItem(
      label: 'Loglar',
      icon: Icons.receipt_long_outlined,
      activeIcon: Icons.receipt_long,
    ),
    _NavItem(
      label: 'NFC Kayıt',
      icon: Icons.add_card_outlined,
      activeIcon: Icons.add_card,
    ),
  ];

  static const List<Widget> _screens = [
    BarkodNfcEslestirmeScreen(),
    NfcBilgiScreen(),
    StokKontrolScreen(),
    LoglarScreen(),
    NfcKayitScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 12,
              offset: const Offset(0, -2),
            )
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(_navItems.length, (i) {
                final item = _navItems[i];
                final isSelected = _selectedIndex == i;
                return GestureDetector(
                  onTap: () => setState(() => _selectedIndex = i),
                  behavior: HitTestBehavior.opaque,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? DepoTheme.primaryColor.withOpacity(0.1)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isSelected ? item.activeIcon : item.icon,
                          color: isSelected
                              ? DepoTheme.primaryColor
                              : DepoTheme.textSecondary,
                          size: 22,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          item.label,
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                            color: isSelected
                                ? DepoTheme.primaryColor
                                : DepoTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  final String label;
  final IconData icon;
  final IconData activeIcon;

  const _NavItem(
      {required this.label, required this.icon, required this.activeIcon});
}
