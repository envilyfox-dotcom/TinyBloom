import 'package:flutter/material.dart';
import '../utils/app_theme.dart';

// ── Primary Button ──────────────────────────────────────────────
class TBButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final bool outline;
  final Color? color;
  final double? width;
  final IconData? icon;

  const TBButton({
    super.key, required this.label, this.onPressed,
    this.loading = false, this.outline = false,
    this.color, this.width, this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final btn = outline
        ? OutlinedButton(
            onPressed: loading ? null : onPressed,
            style: OutlinedButton.styleFrom(
              foregroundColor: color ?? AppColors.rose,
              side: BorderSide(color: color ?? AppColors.rose, width: 1.5),
            ),
            child: _child(),
          )
        : ElevatedButton(
            onPressed: loading ? null : onPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: color ?? AppColors.rose,
            ),
            child: _child(),
          );

    return SizedBox(
      width: width ?? double.infinity,
      height: 50,
      child: btn,
    );
  }

  Widget _child() => loading
      ? const SizedBox(
          width: 20, height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2, color: AppColors.white))
      : Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[Icon(icon, size: 18), const SizedBox(width: 6)],
            Text(label),
          ],
        );
}

// ── Card ─────────────────────────────────────────────────────────
class TBCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final Color? color;
  final VoidCallback? onTap;
  final double? borderRadius;

  const TBCard({
    super.key, required this.child,
    this.padding, this.color, this.onTap, this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: color ?? AppColors.white,
          borderRadius: BorderRadius.circular(borderRadius ?? 16),
          boxShadow: [
            BoxShadow(
              color: AppColors.textDark.withValues(alpha: 0.06),
              blurRadius: 12, offset: const Offset(0, 4)),
          ],
        ),
        padding: padding ?? const EdgeInsets.all(16),
        child: child,
      ),
    );
  }
}

// ── Section Title ─────────────────────────────────────────────────
class TBSectionTitle extends StatelessWidget {
  final String title;
  final String? action;
  final VoidCallback? onAction;

  const TBSectionTitle({
    super.key, required this.title, this.action, this.onAction});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(
          fontSize: 17)),
        if (action != null)
          GestureDetector(
            onTap: onAction,
            child: Text(action!,
              style: const TextStyle(
                color: AppColors.teal, fontSize: 13, fontWeight: FontWeight.w600)),
          ),
      ],
    );
  }
}

// ── Blush Header ─────────────────────────────────────────────────
class TBPageHeader extends StatelessWidget {
  final String title;
  final String? subtitle;

  const TBPageHeader({super.key, required this.title, this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      decoration: const BoxDecoration(
        color: AppColors.blush,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontSize: 22)),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(subtitle!,
              style: const TextStyle(
                color: AppColors.textMid, fontSize: 14)),
          ],
        ],
      ),
    );
  }
}

// ── Empty State ───────────────────────────────────────────────────
class TBEmptyState extends StatelessWidget {
  final String emoji;
  final String title;
  final String subtitle;
  final String? buttonLabel;
  final VoidCallback? onButton;

  const TBEmptyState({
    super.key, required this.emoji, required this.title,
    required this.subtitle, this.buttonLabel, this.onButton,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 52)),
            const SizedBox(height: 16),
            Text(title,
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(subtitle,
              style: const TextStyle(color: AppColors.textLight, fontSize: 14),
              textAlign: TextAlign.center),
            if (buttonLabel != null) ...[
              const SizedBox(height: 24),
              TBButton(label: buttonLabel!, onPressed: onButton, width: 180),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Loading Spinner ───────────────────────────────────────────────
class TBLoading extends StatelessWidget {
  const TBLoading({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: CircularProgressIndicator(color: AppColors.rose));
  }
}

// ── Premium Badge ─────────────────────────────────────────────────
class PremiumBadge extends StatelessWidget {
  const PremiumBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.gold.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(50),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.4)),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.star, color: AppColors.gold, size: 13),
          SizedBox(width: 4),
          Text('Premium',
            style: TextStyle(
              color: AppColors.gold, fontSize: 12, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

// ── Premium Gate ──────────────────────────────────────────────────
class PremiumGate extends StatefulWidget {
  final String feature;
  final VoidCallback? onUpgrade;

  const PremiumGate({super.key, required this.feature, this.onUpgrade});

  @override
  State<PremiumGate> createState() => _PremiumGateState();
}

class _PremiumGateState extends State<PremiumGate> {
  bool _navigating = false;

  void _handleUpgrade() {
    if (_navigating) return;
    setState(() => _navigating = true);
    widget.onUpgrade?.call();
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) setState(() => _navigating = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return TBCard(
      color: AppColors.blush,
      child: Column(
        children: [
          const Text('⭐', style: TextStyle(fontSize: 36)),
          const SizedBox(height: 12),
          Text('${widget.feature} is a Premium Feature',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 16),
            textAlign: TextAlign.center),
          const SizedBox(height: 8),
          const Text('Upgrade to Premium to unlock this feature.',
            style: TextStyle(color: AppColors.textMid, fontSize: 13),
            textAlign: TextAlign.center),
          const SizedBox(height: 16),
          TBButton(
            label: 'Upgrade to Premium',
            color: AppColors.gold,
            onPressed: _navigating ? null : _handleUpgrade,
          ),
        ],
      ),
    );
  }
}
