import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme.dart';
import '../providers/auth_provider.dart';
import '../providers/receipt_provider.dart';
import '../providers/language_provider.dart';
import '../providers/outfit_provider.dart';
import '../widgets/receipt_card.dart';
import '../widgets/product_card.dart';
import 'splash_screen.dart';

final _viewModeProvider = StateProvider.autoDispose<String>((ref) => 'receipts');

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final receiptsAsync = ref.watch(userReceiptsProvider);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0D0D12), Color(0xFF12121C)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Profile Header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                child: Row(
                  children: [
                    // Avatar
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: AppTheme.primaryGradient,
                        boxShadow: AppTheme.glowShadow,
                      ),
                      child: user?.photoURL != null
                          ? ClipOval(
                              child: Image.network(
                                user!.photoURL!,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => const Icon(
                                  Icons.person,
                                  color: Colors.white,
                                  size: 28,
                                ),
                              ),
                            )
                          : const Icon(
                              Icons.person,
                              color: Colors.white,
                              size: 28,
                            ),
                    ),
                    const SizedBox(width: 14),

                    // User info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user?.displayName ?? 'Kullanıcı',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            user?.email ?? '',
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppTheme.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Logout button
                    GestureDetector(
                      onTap: () async {
                        final authService = ref.read(authServiceProvider);
                        await authService.signOut();
                        if (context.mounted) {
                          Navigator.of(context).pushAndRemoveUntil(
                            MaterialPageRoute(
                              builder: (_) => const SplashScreen(),
                            ),
                            (route) => false,
                          );
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppTheme.cardBg,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppTheme.dividerColor.withOpacity(0.5),
                          ),
                        ),
                        child: const Icon(
                          Icons.logout_rounded,
                          color: AppTheme.accentColor,
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const Divider(height: 1, indent: 20, endIndent: 20),
              const SizedBox(height: 16),


              // Header is handled above

              // Custom Tabs
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => ref.read(_viewModeProvider.notifier).state = 'receipts',
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(
                                color: ref.watch(_viewModeProvider) == 'receipts' ? AppTheme.primaryLight : Colors.transparent,
                                width: 2,
                              ),
                            ),
                          ),
                          child: Text(
                            'Faturalarım',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: ref.watch(_viewModeProvider) == 'receipts' ? AppTheme.primaryLight : AppTheme.textMuted,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => ref.read(_viewModeProvider.notifier).state = 'outfits',
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(
                                color: ref.watch(_viewModeProvider) == 'outfits' ? AppTheme.primaryLight : Colors.transparent,
                                width: 2,
                              ),
                            ),
                          ),
                          child: Text(
                            'Kombinlerim',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: ref.watch(_viewModeProvider) == 'outfits' ? AppTheme.primaryLight : AppTheme.textMuted,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // Content
              Expanded(
                child: ref.watch(_viewModeProvider) == 'receipts'
                    ? _buildReceiptsList(receiptsAsync)
                    : _buildOutfitsList(ref),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReceiptsList(AsyncValue<List<dynamic>> receiptsAsync) {
    return receiptsAsync.when(
      data: (receipts) {
        if (receipts.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: AppTheme.cardBg,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppTheme.dividerColor),
                  ),
                  child: const Icon(Icons.receipt_long_outlined, size: 36, color: AppTheme.textMuted),
                ),
                const SizedBox(height: 16),
                Text(
                  'Henüz faturanız yok',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 6),
                Text(
                  'Alışveriş yaptıkça faturalarınız\nburada görünecek',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 13, color: AppTheme.textMuted, height: 1.5),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.only(bottom: 20),
          itemCount: receipts.length,
          itemBuilder: (context, index) {
            return ReceiptCard(receipt: receipts[index]);
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor)),
      error: (error, _) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: AppTheme.accentColor, size: 48),
            const SizedBox(height: 12),
            Text('Error: ${error.toString()}', textAlign: TextAlign.center, style: const TextStyle(color: AppTheme.textSecondary)),
          ],
        ),
      ),
    );
  }

  Widget _buildOutfitsList(WidgetRef ref) {
    final outfits = ref.watch(outfitProvider);
    if (outfits.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(color: AppTheme.cardBg, shape: BoxShape.circle, border: Border.all(color: AppTheme.dividerColor)),
              child: const Icon(Icons.checkroom_outlined, size: 36, color: AppTheme.textMuted),
            ),
            const SizedBox(height: 16),
            const Text(
              'Henüz kaydedilmiş kombin yok',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: AppTheme.textSecondary),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 20, top: 10),
      itemCount: outfits.length,
      itemBuilder: (context, index) {
        final outfit = outfits[index];
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.dividerColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.star, color: AppTheme.accentColor, size: 18),
                      const SizedBox(width: 6),
                      Text(
                        'Kombin #${outfits.length - index}',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Text(
                        '${outfit.date.day}/${outfit.date.month}/${outfit.date.year}',
                        style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                      ),
                      const SizedBox(width: 8),
                      // FIX #11: Silme butonu
                      GestureDetector(
                        onTap: () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (_) => AlertDialog(
                              backgroundColor: AppTheme.cardBg,
                              title: const Text('Kombini Sil', style: TextStyle(color: Colors.white)),
                              content: const Text(
                                'Bu kombinasyonu kaydetmekten çıkarmak istediğinize emin misiniz?',
                                style: TextStyle(color: AppTheme.textSecondary),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context, false),
                                  child: const Text('Hayır', style: TextStyle(color: AppTheme.textMuted)),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  child: const Text('Evet, Sil', style: TextStyle(color: Colors.redAccent)),
                                ),
                              ],
                            ),
                          );
                          if (confirm == true) {
                            ref.read(outfitProvider.notifier).deleteOutfit(outfit.id);
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.close, color: Colors.redAccent, size: 18),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 180,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: outfit.products.length,
                  itemBuilder: (context, pIndex) {
                    final product = outfit.products[pIndex];
                    return Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: GestureDetector(
                        onTap: product.imageUrl.isNotEmpty
                            ? () => showDialog(
                                  context: context,
                                  barrierColor: Colors.black.withOpacity(0.92),
                                  builder: (_) => GestureDetector(
                                    onTap: () => Navigator.of(context).pop(),
                                    child: SafeArea(
                                      child: Center(
                                        child: InteractiveViewer(
                                          child: Image.network(
                                            product.imageUrl,
                                            fit: BoxFit.contain,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                )
                            : null,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Stack(
                            children: [
                              SizedBox(
                                width: 120,
                                height: 180,
                                child: product.imageUrl.isNotEmpty
                                    ? Image.network(
                                        product.imageUrl,
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) => Container(
                                          color: AppTheme.cardBgLight,
                                          child: const Icon(Icons.broken_image, color: AppTheme.textMuted),
                                        ),
                                      )
                                    : Container(color: AppTheme.cardBgLight, child: const Icon(Icons.checkroom, color: AppTheme.textMuted)),
                              ),
                              // Büyüteç ikonu
                              if (product.imageUrl.isNotEmpty)
                                Positioned(
                                  top: 6,
                                  right: 6,
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.5),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.zoom_in, color: Colors.white, size: 14),
                                  ),
                                ),
                              Positioned(
                                bottom: 0,
                                left: 0,
                                right: 0,
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.bottomCenter,
                                      end: Alignment.topCenter,
                                      colors: [Colors.black.withOpacity(0.9), Colors.transparent],
                                    ),
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        product.name,
                                        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 2),
                                      if (product.size.isNotEmpty || product.color.isNotEmpty)
                                        Text(
                                          [if (product.color.isNotEmpty) product.color, if (product.size.isNotEmpty) 'Beden: ${product.size}'].join(' | '),
                                          style: const TextStyle(color: AppTheme.primaryLight, fontSize: 9, fontWeight: FontWeight.bold),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      if (product.barcode.isNotEmpty)
                                        Text(
                                          'Barkod: ${product.barcode}',
                                          style: const TextStyle(color: AppTheme.textMuted, fontSize: 9),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                    ],
                                  ),
                                ),
                              )
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
