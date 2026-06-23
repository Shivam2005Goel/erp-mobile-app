import 'package:flutter/material.dart';

class LandingScreen extends StatelessWidget {
  const LandingScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Spacer(),
              Text(
                'Argmac ERP',
                style: theme.textTheme.headlineLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Elevate your enterprise operations with a beautifully designed workflow hub for HR, inventory, sales, and production.',
                style: theme.textTheme.titleMedium?.copyWith(height: 1.5),
              ),
              const SizedBox(height: 32),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  ElevatedButton(
                    onPressed: () => Navigator.pushNamed(context, '/login'),
                    child: const Text('Access Dashboard'),
                  ),
                  OutlinedButton(
                    onPressed: () => Navigator.pushNamed(context, '/register'),
                    child: const Text('Register Department'),
                  ),
                ],
              ),
              const SizedBox(height: 36),
              Text(
                'Core Modules',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: GridView.count(
                  crossAxisCount: MediaQuery.of(context).size.width > 760
                      ? 3
                      : 1,
                  childAspectRatio: 2.8,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  children: const [
                    _FeatureTile(
                      title: 'Bespoke Modules',
                      description:
                          'Tailored dashboards for every department from HR to Production.',
                    ),
                    _FeatureTile(
                      title: 'Premium UI',
                      description:
                          'A rich polish layer inspired by luxury workspaces and modern corporate design.',
                    ),
                    _FeatureTile(
                      title: 'Role-based Access',
                      description:
                          'Secure role gating and personalized department portals.',
                    ),
                    _FeatureTile(
                      title: 'Analytics Ready',
                      description:
                          'Launch with charts, inventory, CRM, and ticket insights.',
                    ),
                    _FeatureTile(
                      title: 'Supabase-ready',
                      description:
                          'A stack design that adapts to PostgreSQL, auth, and storage backends.',
                    ),
                    _FeatureTile(
                      title: 'Workflow Transparency',
                      description:
                          'Monitor tasks, approvals, attendance, and orders from one place.',
                    ),
                  ],
                ),
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeatureTile extends StatelessWidget {
  final String title;
  final String description;
  const _FeatureTile({required this.title, required this.description});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).textTheme.bodySmall?.color,
            ),
          ),
        ],
      ),
    );
  }
}
