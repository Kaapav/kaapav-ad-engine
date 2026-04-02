import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/theme.dart';
import '../core/constants.dart';
import '../core/utils.dart';
import '../widgets/glass_card.dart';
import '../widgets/buttons.dart';
import '../widgets/search_filter.dart';
import '../widgets/inputs.dart';

class CreateCampaignScreen extends StatefulWidget {
  const CreateCampaignScreen({super.key});
  @override
  State<CreateCampaignScreen> createState() => _CreateCampaignScreenState();
}

class _CreateCampaignScreenState extends State<CreateCampaignScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _bgC;
  int _step = 0; // 0=Objective, 1=Budget, 2=Targeting, 3=Review
  final _steps = ['Objective', 'Budget', 'Targeting', 'Review'];

  // FORM STATE
  String? _objective;
  String _bidStrategy = 'LOWEST_COST_WITHOUT_CAP';
  final _nameCtrl = TextEditingController();
  final _budgetCtrl = TextEditingController(text: '1000');
  String _budgetType = 'daily'; // daily / lifetime
  int _ageMin = 25;
  int _ageMax = 45;
  final _selectedGenders = <String>{'Female'};
  final _selectedLocations = <String>{'Mumbai', 'Delhi'};
  final _selectedInterests = <String>{'Fashion jewellery'};
  String _platform = 'Facebook';

  final _allLocations = [
    'Mumbai', 'Delhi', 'Bangalore', 'Pune', 'Ahmedabad', 'Surat',
    'Chennai', 'Kolkata', 'Hyderabad', 'Jaipur', 'Lucknow', 'Vadodara',
    'Maharashtra', 'Gujarat', 'Delhi NCR', 'India - Tier 1', 'India - All',
  ];

  final _allInterests = [
    'Fashion jewellery', 'Gold jewellery', 'Bridal jewellery', 'Online shopping',
    'Navratri', 'Diwali', 'Festival shopping', 'Kundan jewellery',
    'Temple jewellery', 'Oxidized jewellery', 'Diamond jewellery',
    'Wedding planning', 'Bridal makeup', 'Garba', 'Ethnic wear',
    'Sarees', 'Lehengas', 'Women fashion',
  ];

  @override
  void initState() {
    super.initState();
    _bgC = AnimationController(vsync: this, duration: const Duration(seconds: 8))..repeat(reverse: true);
  }

  @override
  void dispose() { _bgC.dispose(); _nameCtrl.dispose(); _budgetCtrl.dispose(); super.dispose(); }

  bool get _canProceed => switch (_step) {
        0 => _objective != null && _nameCtrl.text.isNotEmpty,
        1 => _budgetCtrl.text.isNotEmpty && (double.tryParse(_budgetCtrl.text) ?? 0) > 0,
        2 => _selectedLocations.isNotEmpty,
        3 => true,
        _ => false,
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.bgDeep,
      body: Stack(
        children: [
          AnimatedBuilder(
            animation: _bgC,
            builder: (_, __) => Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(0.3 - _bgC.value * 0.6, -0.5 + _bgC.value * 0.3),
                  radius: 1.5,
                  colors: [C.primary.withValues(alpha: 0.06), C.purple.withValues(alpha: 0.03), C.bgDeep],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                _header(),
                _stepper(),
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: _buildStep(),
                    ),
                  ),
                ),
                _bottomBar(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Row(
        children: [
          GestureDetector(
            onTap: () {
              if (_step > 0) {
                setState(() => _step--);
              } else {
                Navigator.pop(context);
              }
            },
            child: Container(
              width: 38, height: 38,
              decoration: Glass.card(radius: 12),
              child: const Icon(Icons.arrow_back_ios_new_rounded, color: C.textPrimary, size: 16),
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Create Campaign', style: TextStyle(color: C.textPrimary, fontSize: 18, fontWeight: FontWeight.w700)),
                Text('Kaapav Fashion Jewellery', style: TextStyle(color: C.textSecondary, fontSize: 11)),
              ],
            ),
          ),
          Text('${_step + 1}/${_steps.length}', style: const TextStyle(color: C.primary, fontSize: 13, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _stepper() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Row(
        children: List.generate(_steps.length, (i) {
          final active = i == _step;
          final done = i < _step;
          return Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: i < _steps.length - 1 ? 4 : 0),
              child: Column(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    height: 3,
                    decoration: BoxDecoration(
                      gradient: done || active ? C.primaryGrad : null,
                      color: done || active ? null : C.glassWhite,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _steps[i],
                    style: TextStyle(
                      color: active ? C.primary : done ? C.textSecondary : C.textMuted,
                      fontSize: 10,
                      fontWeight: active ? FontWeight.w700 : FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }

  // ═══ STEP BUILDER ═══
  Widget _buildStep() {
    return switch (_step) {
      0 => _stepObjective(),
      1 => _stepBudget(),
      2 => _stepTargeting(),
      3 => _stepReview(),
      _ => const SizedBox.shrink(),
    };
  }

  // ═══ STEP 1: OBJECTIVE ═══
  Widget _stepObjective() {
    return Column(
      key: const ValueKey('step0'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Choose Campaign Objective', style: TextStyle(color: C.textPrimary, fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        const Text('What result do you want from this campaign?', style: TextStyle(color: C.textMuted, fontSize: 12)),
        const SizedBox(height: 16),
        ...K.objectives.entries.map((e) {
          final sel = _objective == e.key;
          final icon = switch (e.key) {
            'OUTCOME_SALES' => Icons.shopping_bag_rounded,
            'OUTCOME_LEADS' => Icons.person_add_rounded,
            'OUTCOME_TRAFFIC' => Icons.language_rounded,
            'OUTCOME_AWARENESS' => Icons.visibility_rounded,
            'OUTCOME_ENGAGEMENT' => Icons.favorite_rounded,
            _ => Icons.campaign_rounded,
          };
          final desc = switch (e.key) {
            'OUTCOME_SALES' => 'Drive purchases on your website or app',
            'OUTCOME_LEADS' => 'Collect leads for your bridal collection',
            'OUTCOME_TRAFFIC' => 'Drive visitors to your Kaapav website',
            'OUTCOME_AWARENESS' => 'Reach new audiences with your jewellery',
            'OUTCOME_ENGAGEMENT' => 'Get more likes, comments & WhatsApp messages',
            _ => '',
          };
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: GestureDetector(
              onTap: () { HapticFeedback.lightImpact(); setState(() => _objective = e.key); },
              child: GlassCard(
                radius: 16,
                turquoise: sel,
                glow: sel,
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      width: 44, height: 44,
                      decoration: BoxDecoration(
                        color: (sel ? C.primary : C.textMuted).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: Icon(icon, color: sel ? C.primary : C.textMuted, size: 22),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(e.value, style: TextStyle(color: sel ? C.primary : C.textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 2),
                          Text(desc, style: const TextStyle(color: C.textMuted, fontSize: 11)),
                        ],
                      ),
                    ),
                    if (sel)
                      Container(
                        width: 22, height: 22,
                        decoration: BoxDecoration(gradient: C.primaryGrad, shape: BoxShape.circle),
                        child: const Icon(Icons.check_rounded, color: Colors.black, size: 14),
                      ),
                  ],
                ),
              ),
            ),
          );
        }),
        const SizedBox(height: 16),
        GlassInput(
          label: 'Campaign Name',
          hint: 'e.g. Navratri Gold Plated Sale',
          controller: _nameCtrl,
          prefixIcon: Icons.campaign_rounded,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 12),
        GlassCard(
          radius: 14,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              const Text('Platform', style: TextStyle(color: C.textSecondary, fontSize: 12)),
              const Spacer(),
              ...['Facebook', 'Instagram'].map((p) {
                final sel = _platform == p;
                final isFb = p == 'Facebook';
                return Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: GestureDetector(
                    onTap: () => setState(() => _platform = p),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: sel ? (isFb ? C.facebook : C.instagram).withValues(alpha: 0.15) : C.glassWhite,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: sel ? (isFb ? C.facebook : C.instagram).withValues(alpha: 0.5) : C.glassBorder),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(isFb ? Icons.facebook_rounded : Icons.camera_alt_rounded, color: sel ? (isFb ? C.facebook : C.instagram) : C.textMuted, size: 14),
                          const SizedBox(width: 4),
                          Text(p, style: TextStyle(color: sel ? (isFb ? C.facebook : C.instagram) : C.textMuted, fontSize: 11, fontWeight: sel ? FontWeight.w600 : FontWeight.w400)),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      ],
    );
  }

  // ═══ STEP 2: BUDGET ═══
  Widget _stepBudget() {
    final budget = double.tryParse(_budgetCtrl.text) ?? 0;

    return Column(
      key: const ValueKey('step1'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Set Your Budget', style: TextStyle(color: C.textPrimary, fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        const Text('How much do you want to spend?', style: TextStyle(color: C.textMuted, fontSize: 12)),
        const SizedBox(height: 16),

        // BUDGET TYPE
        GlassCard(
          radius: 14,
          padding: const EdgeInsets.all(4),
          child: Row(
            children: ['daily', 'lifetime'].map((t) {
              final sel = _budgetType == t;
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _budgetType = t),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      gradient: sel ? C.primaryGrad : null,
                      borderRadius: BorderRadius.circular(11),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      t == 'daily' ? 'Daily Budget' : 'Lifetime Budget',
                      style: TextStyle(color: sel ? Colors.black : C.textMuted, fontSize: 13, fontWeight: sel ? FontWeight.w700 : FontWeight.w400),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 16),

        // BUDGET INPUT
        GlassInput(
          label: _budgetType == 'daily' ? 'Daily Budget (₹)' : 'Lifetime Budget (₹)',
          hint: '1000',
          controller: _budgetCtrl,
          keyboardType: TextInputType.number,
          prefixIcon: Icons.currency_rupee_rounded,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 12),

        // QUICK AMOUNTS
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [500, 1000, 2000, 3000, 5000, 10000].map((a) {
            final sel = _budgetCtrl.text == '$a';
            return GestureDetector(
              onTap: () => setState(() => _budgetCtrl.text = '$a'),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: sel ? C.primary.withValues(alpha: 0.15) : C.glassWhite,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: sel ? C.primary.withValues(alpha: 0.5) : C.glassBorder),
                ),
                child: Text('₹${U.num(a.toDouble())}', style: TextStyle(
                  color: sel ? C.primary : C.textPrimary,
                  fontSize: 13,
                  fontWeight: sel ? FontWeight.w700 : FontWeight.w400,
                )),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 20),

        // BID STRATEGY
        const Text('Bid Strategy', style: TextStyle(color: C.textSecondary, fontSize: 12, fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        ...K.bidStrategies.entries.map((e) {
          final sel = _bidStrategy == e.key;
          final desc = switch (e.key) {
            'LOWEST_COST_WITHOUT_CAP' => 'Get the most results for your budget',
            'COST_CAP' => 'Keep average cost below your target',
            'MINIMUM_ROAS' => 'Maintain minimum return on ad spend',
            _ => '',
          };
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: GestureDetector(
              onTap: () => setState(() => _bidStrategy = e.key),
              child: GlassCard(
                radius: 12,
                turquoise: sel,
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Container(
                      width: 18, height: 18,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: sel ? C.primaryGrad : null,
                        border: sel ? null : Border.all(color: C.glassBorder, width: 2),
                      ),
                      child: sel ? const Icon(Icons.check_rounded, color: Colors.black, size: 12) : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(e.value, style: TextStyle(color: sel ? C.primary : C.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
                          Text(desc, style: const TextStyle(color: C.textMuted, fontSize: 10)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),

        // ESTIMATED RESULTS
        if (budget > 0) ...[
          const SizedBox(height: 12),
          GlassCard(
            radius: 14,
            turquoise: true,
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Estimated Results', style: TextStyle(color: C.primary, fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _estimateItem('Reach', U.num(budget * 30), Icons.people_outline),
                    _estimateItem('Clicks', U.num(budget * 3.5), Icons.touch_app_rounded),
                    _estimateItem('Conv.', U.num(budget * 0.15), Icons.shopping_bag_rounded),
                    _estimateItem('Est. CPA', '₹${(budget / (budget * 0.15)).toStringAsFixed(0)}', Icons.ads_click),
                  ],
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _estimateItem(String label, String value, IconData icon) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: C.primary.withValues(alpha: 0.6), size: 15),
          const SizedBox(height: 3),
          Text(value, style: const TextStyle(color: C.textPrimary, fontSize: 13, fontWeight: FontWeight.w700)),
          Text(label, style: const TextStyle(color: C.textMuted, fontSize: 10)),
        ],
      ),
    );
  }

  // ═══ STEP 3: TARGETING ═══
  Widget _stepTargeting() {
    return Column(
      key: const ValueKey('step2'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Target Audience', style: TextStyle(color: C.textPrimary, fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        const Text('Who should see your Kaapav jewellery ads?', style: TextStyle(color: C.textMuted, fontSize: 12)),
        const SizedBox(height: 16),

        // GENDER
        const Text('Gender', style: TextStyle(color: C.textSecondary, fontSize: 12, fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: ['All', 'Female', 'Male'].map((g) {
            final sel = _selectedGenders.contains(g);
            return FilterChip2(label: g, selected: sel, onTap: () {
              setState(() {
                if (g == 'All') {
                  _selectedGenders.clear();
                  _selectedGenders.add('All');
                } else {
                  _selectedGenders.remove('All');
                  sel ? _selectedGenders.remove(g) : _selectedGenders.add(g);
                  if (_selectedGenders.isEmpty) _selectedGenders.add('All');
                }
              });
            });
          }).toList(),
        ),
        const SizedBox(height: 16),

        // AGE RANGE
        const Text('Age Range', style: TextStyle(color: C.textSecondary, fontSize: 12, fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        GlassCard(
          radius: 14,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('$_ageMin', style: const TextStyle(color: C.primary, fontSize: 16, fontWeight: FontWeight.w700)),
                  const Text('to', style: TextStyle(color: C.textMuted, fontSize: 12)),
                  Text('$_ageMax', style: const TextStyle(color: C.primary, fontSize: 16, fontWeight: FontWeight.w700)),
                ],
              ),
              RangeSlider(
                values: RangeValues(_ageMin.toDouble(), _ageMax.toDouble()),
                min: 18,
                max: 65,
                divisions: 47,
                activeColor: C.primary,
                inactiveColor: C.glassBorder,
                onChanged: (v) => setState(() {
                  _ageMin = v.start.round();
                  _ageMax = v.end.round();
                }),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // LOCATIONS
        const Text('Locations', style: TextStyle(color: C.textSecondary, fontSize: 12, fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: _allLocations.map((loc) {
            final sel = _selectedLocations.contains(loc);
            return FilterChip2(label: loc, selected: sel, onTap: () {
              setState(() => sel ? _selectedLocations.remove(loc) : _selectedLocations.add(loc));
            });
          }).toList(),
        ),
        const SizedBox(height: 16),

        // INTERESTS
        const Text('Interests', style: TextStyle(color: C.textSecondary, fontSize: 12, fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: _allInterests.map((int_) {
            final sel = _selectedInterests.contains(int_);
            return FilterChip2(label: int_, selected: sel, onTap: () {
              setState(() => sel ? _selectedInterests.remove(int_) : _selectedInterests.add(int_));
            });
          }).toList(),
        ),
        const SizedBox(height: 16),

        // ESTIMATED REACH
        GlassCard(
          radius: 14,
          turquoise: true,
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(color: C.primary.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.people_alt_rounded, color: C.primary, size: 18),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Estimated Audience Size', style: TextStyle(color: C.textSecondary, fontSize: 11)),
                  Text('${U.num((_selectedLocations.length * 850000 + _selectedInterests.length * 120000).toDouble())} people', style: const TextStyle(color: C.primary, fontSize: 16, fontWeight: FontWeight.w700)),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ═══ STEP 4: REVIEW ═══
  Widget _stepReview() {
    final budget = double.tryParse(_budgetCtrl.text) ?? 0;

    return Column(
      key: const ValueKey('step3'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Review Campaign', style: TextStyle(color: C.textPrimary, fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        const Text('Confirm everything looks good', style: TextStyle(color: C.textMuted, fontSize: 12)),
        const SizedBox(height: 16),

        // CAMPAIGN OVERVIEW
        GlassCard(
          radius: 18,
          turquoise: true,
          glow: true,
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(gradient: C.primaryGrad, borderRadius: BorderRadius.circular(13)),
                    child: const Icon(Icons.campaign_rounded, color: Colors.black, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_nameCtrl.text.isEmpty ? 'Campaign Name' : _nameCtrl.text, style: const TextStyle(color: C.textPrimary, fontSize: 16, fontWeight: FontWeight.w700)),
                        Text(_platform, style: const TextStyle(color: C.textSecondary, fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(color: C.glassBorder, height: 1),
              const SizedBox(height: 14),
              _reviewRow('Objective', K.objectives[_objective] ?? '—'),
              _reviewRow('Bid Strategy', K.bidStrategies[_bidStrategy] ?? '—'),
              _reviewRow('Budget', '${U.money(budget)}/${_budgetType == "daily" ? "day" : "total"}'),
              _reviewRow('Gender', _selectedGenders.join(', ')),
              _reviewRow('Age', '$_ageMin - $_ageMax'),
              _reviewRow('Locations', _selectedLocations.join(', ')),
              _reviewRow('Interests', _selectedInterests.join(', ')),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // AI SUGGESTIONS
        GlassCard(
          radius: 14,
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(color: C.success.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.auto_awesome, color: C.success, size: 18),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('AI Suggestion', style: TextStyle(color: C.success, fontSize: 12, fontWeight: FontWeight.w600)),
                    SizedBox(height: 2),
                    Text('Based on Kaapav\'s past performance, Women 25-40 in Maharashtra deliver the best ROAS', style: TextStyle(color: C.textSecondary, fontSize: 11)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _reviewRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 90, child: Text(label, style: const TextStyle(color: C.textMuted, fontSize: 12))),
          Expanded(child: Text(value, style: const TextStyle(color: C.textPrimary, fontSize: 12, fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }

  // ═══ BOTTOM BAR ═══
  Widget _bottomBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Row(
        children: [
          if (_step > 0)
            Expanded(
              child: OutlineBtn(
                label: 'Back',
                icon: Icons.arrow_back_rounded,
                onTap: () => setState(() => _step--),
              ),
            ),
          if (_step > 0) const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: PrimaryBtn(
              label: _step == 3 ? '🚀 Launch Campaign' : 'Continue',
              icon: _step == 3 ? Icons.rocket_launch_rounded : Icons.arrow_forward_rounded,
              onTap: _canProceed
                  ? () {
                      HapticFeedback.mediumImpact();
                      if (_step < 3) {
                        setState(() => _step++);
                      } else {
                        _launchCampaign();
                      }
                    }
                  : null,
            ),
          ),
        ],
      ),
    );
  }

  void _launchCampaign() {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: Glass.blur,
            child: Container(
              padding: const EdgeInsets.all(28),
              decoration: Glass.card(radius: 24, turquoise: true, glow: true),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 64, height: 64,
                    decoration: BoxDecoration(gradient: C.successGrad, shape: BoxShape.circle, boxShadow: [BoxShadow(color: C.success.withValues(alpha: 0.4), blurRadius: 20)]),
                    child: const Icon(Icons.check_rounded, color: Colors.white, size: 32),
                  ),
                  const SizedBox(height: 18),
                  const Text('Campaign Created! 🎉', style: TextStyle(color: C.textPrimary, fontSize: 18, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  Text('"${_nameCtrl.text}" is now live', style: const TextStyle(color: C.textSecondary, fontSize: 13)),
                  const SizedBox(height: 8),
                  const Text('Meta will review your ad within 24 hours', style: TextStyle(color: C.textMuted, fontSize: 11)),
                  const SizedBox(height: 20),
                  PrimaryBtn(label: 'Done', onTap: () {
                    Navigator.pop(context); // Close dialog
                    Navigator.pop(context); // Go back
                  }),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}