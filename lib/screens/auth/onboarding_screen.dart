import 'package:flutter/material.dart';
import '../../app/theme.dart';
import 'role_select_screen.dart';

class _Slide {
  final String image;
  final IconData icon;
  final String title;
  final String body;
  const _Slide(this.image, this.icon, this.title, this.body);
}

const _slides = [
  _Slide(
    'https://images.unsplash.com/photo-1517836357463-d25dfeac3438?auto=format&fit=crop&w=1200&q=80',
    Icons.center_focus_strong_rounded,
    'Form corrected in\nreal time.',
    'Point your camera at yourself and get live posture feedback, powered by on-device pose tracking — no coach required for every session.',
  ),
  _Slide(
    'https://images.unsplash.com/photo-1534438327276-14e5300c3a48?auto=format&fit=crop&w=1200&q=80',
    Icons.insights_rounded,
    'Progress you can\nactually see.',
    'Every rep, streak, and personal best rolls up into reports and rewards, so the work you put in never goes unnoticed.',
  ),
  _Slide(
    'https://images.unsplash.com/photo-1571731956672-f2b94d7dd0cb?auto=format&fit=crop&w=1200&q=80',
    Icons.groups_rounded,
    'Certified coaches,\non your schedule.',
    'Book a session with a coach at your gym in a couple of taps whenever you want a human in the loop.',
  ),
];

/// Pre-authentication onboarding carousel. Shown once, before the role
/// select / login flow, so first-time visitors understand what GainPath
/// does before being asked to commit to an account.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _index = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _next() {
    if (_index == _slides.length - 1) {
      _done();
      return;
    }
    _controller.nextPage(duration: const Duration(milliseconds: 320), curve: Curves.easeOutCubic);
  }

  void _done() {
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const RoleSelectScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final isLast = _index == _slides.length - 1;
    return Scaffold(
      backgroundColor: AppColors.ink,
      body: Stack(
        fit: StackFit.expand,
        children: [
          PageView.builder(
            controller: _controller,
            itemCount: _slides.length,
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (context, i) => _SlideView(slide: _slides[i]),
          ),
          SafeArea(
            child: Column(
              children: [
                Align(
                  alignment: Alignment.topRight,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: TextButton(
                      onPressed: _done,
                      style: TextButton.styleFrom(foregroundColor: Colors.white.withValues(alpha: 0.85)),
                      child: const Text('Skip'),
                    ),
                  ),
                ),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(28, 0, 28, 28),
                  child: Row(
                    children: [
                      Row(
                        children: List.generate(
                          _slides.length,
                          (i) => AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            margin: const EdgeInsets.only(right: 6),
                            width: i == _index ? 22 : 7,
                            height: 7,
                            decoration: BoxDecoration(
                              color: i == _index ? Colors.white : Colors.white.withValues(alpha: 0.35),
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                        ),
                      ),
                      const Spacer(),
                      SizedBox(
                        height: 52,
                        child: FilledButton.icon(
                          onPressed: _next,
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: AppColors.primaryDark,
                            padding: const EdgeInsets.symmetric(horizontal: 22),
                          ),
                          icon: Icon(isLast ? Icons.arrow_forward_rounded : Icons.arrow_forward_ios_rounded,
                              size: isLast ? 20 : 15),
                          label: Text(isLast ? 'Get started' : 'Next'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SlideView extends StatelessWidget {
  final _Slide slide;
  const _SlideView({required this.slide});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.network(
          slide.image,
          fit: BoxFit.cover,
          loadingBuilder: (context, child, progress) =>
              progress == null ? child : Container(color: AppColors.ink),
          errorBuilder: (context, error, stack) => const DecoratedBox(
            decoration: BoxDecoration(gradient: AppColors.heroGradient),
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                AppColors.primaryDark.withValues(alpha: 0.55),
                AppColors.primaryDark.withValues(alpha: 0.35),
                AppColors.ink.withValues(alpha: 0.92),
              ],
              stops: const [0.0, 0.45, 1.0],
            ),
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(28, 90, 28, 130),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                  ),
                  child: Icon(slide.icon, color: AppColors.overlay, size: 26),
                ),
                const SizedBox(height: 24),
                Text(
                  slide.title,
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                        color: Colors.white,
                        fontSize: 30,
                        height: 1.15,
                      ),
                ),
                const SizedBox(height: 14),
                Text(
                  slide.body,
                  style: TextStyle(fontSize: 15, height: 1.5, color: Colors.white.withValues(alpha: 0.85)),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
