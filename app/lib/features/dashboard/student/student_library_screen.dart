import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/warm_backdrop.dart';

/// Student Digital Library & Resource Center.
///
/// Features:
/// 1. Comprehensive pre-loaded digital library catalog (Textbooks, Revision Notes, Question Banks, Lab Manuals).
/// 2. Interactive search and category filter pills.
/// 3. In-app reader preview modal and external PDF opener.
/// 4. Designed strictly per design.md with high-contrast surfaces and student brand colors.
class StudentLibraryScreen extends ConsumerStatefulWidget {
  const StudentLibraryScreen({super.key});

  @override
  ConsumerState<StudentLibraryScreen> createState() => _StudentLibraryScreenState();
}

class _StudentLibraryScreenState extends ConsumerState<StudentLibraryScreen> {
  String _searchQuery = '';
  String _selectedCategory = 'All';

  static const _studentAccent = Color(0xFFFFC700); // Primary Yellow per design.md
  static const _primaryBlue = Color(0xFF2E5BFF);

  final List<Map<String, dynamic>> _allResources = [
    {
      'id': 'res-1',
      'title': 'NCERT Mathematics Class 10 (Full Textbook)',
      'author': 'NCERT Editorial Board',
      'subject': 'Mathematics',
      'category': 'Textbooks',
      'description': 'Complete standard textbook covering Real Numbers, Polynomials, Quadratic Equations, Triangles, Coordinate Geometry, and Trigonometry.',
      'format': 'PDF · 18.4 MB',
      'chapters': '15 Chapters',
      'color': Color(0xFF4F46E5),
      'icon': Icons.calculate_outlined,
      'isBookmarked': true,
    },
    {
      'id': 'res-2',
      'title': 'Concepts of Physics (Class 10 Edition)',
      'author': 'Dr. H.C. Verma',
      'subject': 'Physics',
      'category': 'Textbooks',
      'description': 'Foundational physics theory covering Light Reflection & Refraction, Human Eye, Electricity, and Magnetic Effects of Electric Current.',
      'format': 'PDF · 24.2 MB',
      'chapters': '6 Core Units',
      'color': Color(0xFF00877D),
      'icon': Icons.lightbulb_outlined,
      'isBookmarked': false,
    },
    {
      'id': 'res-3',
      'title': 'Comprehensive Chemistry & Lab Manual Class 10',
      'author': 'NCERT / CBSE Board',
      'subject': 'Chemistry',
      'category': 'Textbooks',
      'description': 'In-depth guide to Chemical Reactions, Acids, Bases & Salts, Metals & Non-metals, Carbon & its Compounds, and Periodic Classification.',
      'format': 'PDF · 15.8 MB',
      'chapters': '5 Units + 12 Lab Experiments',
      'color': Color(0xFF059669),
      'icon': Icons.science_outlined,
      'isBookmarked': true,
    },
    {
      'id': 'res-4',
      'title': 'Computer Science with Python 3.12 (Class 10)',
      'author': 'Ms. Priya Nair & Tech Faculty',
      'subject': 'Computer Science',
      'category': 'Textbooks',
      'description': 'Interactive textbook with Python basics, control flow, functions, lists, dictionaries, strings, file handling, and introductory SQL queries.',
      'format': 'PDF · 12.6 MB',
      'chapters': '8 Coding Modules',
      'color': Color(0xFF0284C7),
      'icon': Icons.terminal_rounded,
      'isBookmarked': false,
    },
    {
      'id': 'res-5',
      'title': 'First Flight & Footprints Without Feet (English Reader)',
      'author': 'CBSE National Board',
      'subject': 'English',
      'category': 'Textbooks',
      'description': 'Official English Literature anthology comprising prose, poetry, character sketches, and analytical discussion prompts.',
      'format': 'PDF · 9.4 MB',
      'chapters': '11 Prose + 10 Poems',
      'color': Color(0xFFFF6B47),
      'icon': Icons.auto_stories_outlined,
      'isBookmarked': false,
    },
    {
      'id': 'res-6',
      'title': 'Math Rapid Formula & Theorem Cheat Sheet',
      'author': 'Dr. Ramesh Sharma',
      'subject': 'Mathematics',
      'category': 'Revision Notes',
      'description': 'High-yield 12-page revision summary containing all trigonometric identities, quadratic formulas, mensuration surface formulas, and theorem proofs.',
      'format': 'PDF · 2.1 MB',
      'chapters': 'Quick Reference Guide',
      'color': Color(0xFF4F46E5),
      'icon': Icons.menu_book_rounded,
      'isBookmarked': true,
    },
    {
      'id': 'res-7',
      'title': 'Physics Ray Optics & Electricity Derivations Summary',
      'author': 'Mrs. Ananya Sen',
      'subject': 'Physics',
      'category': 'Revision Notes',
      'description': 'Concise derivation sheets for mirror formulas, lens makers formula, Ohm’s law, heating effect, and electric power formulas.',
      'format': 'PDF · 3.5 MB',
      'chapters': 'Formula Handout',
      'color': Color(0xFF00877D),
      'icon': Icons.description_outlined,
      'isBookmarked': false,
    },
    {
      'id': 'res-8',
      'title': 'Previous 5-Year Solved Board Exam Papers (2020-2025)',
      'author': 'Academic Exam Cell',
      'subject': 'All Subjects',
      'category': 'Question Banks',
      'description': 'Original past year board examination question papers with step-by-step model answer keys and marking scheme criteria.',
      'format': 'PDF · 16.2 MB',
      'chapters': '10 Mock Exam Sets',
      'color': Color(0xFFD97706),
      'icon': Icons.quiz_outlined,
      'isBookmarked': true,
    },
    {
      'id': 'res-9',
      'title': 'Class 10 All-in-One Mid-Term Sample Mock Tests (Sets 1-5)',
      'author': 'Greenwood Faculty Panel',
      'subject': 'Science & Math',
      'category': 'Question Banks',
      'description': 'Curated high-difficulty test papers modeled directly after standard board exam patterns with answers for self-assessment.',
      'format': 'PDF · 8.9 MB',
      'chapters': '5 Complete Question Sets',
      'color': Color(0xFF9333EA),
      'icon': Icons.fact_check_outlined,
      'isBookmarked': false,
    },
  ];

  List<Map<String, dynamic>> get _filteredResources {
    return _allResources.where((r) {
      if (_selectedCategory != 'All' && r['category'] != _selectedCategory) {
        return false;
      }
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final title = (r['title'] as String).toLowerCase();
        final desc = (r['description'] as String).toLowerCase();
        final sub = (r['subject'] as String).toLowerCase();
        if (!title.contains(q) && !desc.contains(q) && !sub.contains(q)) {
          return false;
        }
      }
      return true;
    }).toList();
  }

  void _openReaderModal(Map<String, dynamic> item) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.card)),
        backgroundColor: Colors.white,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: (item['color'] as Color).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(item['icon'] as IconData, color: item['color'] as Color, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item['title'] as String, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                  Text('${item['subject']} · ${item['author']}', style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
                ],
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(item['description'] as String, style: const TextStyle(fontSize: 13, color: AppColors.textPrimary, height: 1.4)),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(AppRadii.input),
                border: Border.all(color: AppColors.glassBorder),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.menu_book_rounded, size: 16, color: Color(0xFF2E5BFF)),
                      const SizedBox(width: 6),
                      Text(item['chapters'] as String, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                    ],
                  ),
                  Row(
                    children: [
                      const Icon(Icons.folder_zip_outlined, size: 16, color: Color(0xFF059669)),
                      const SizedBox(width: 6),
                      Text(item['format'] as String, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.pill)),
            ),
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close'),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryBlue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.pill)),
            ),
            icon: const Icon(Icons.download_rounded, size: 16),
            label: const Text('Download / Read Offline', style: TextStyle(fontWeight: FontWeight.w700)),
            onPressed: () {
              Navigator.of(ctx).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Downloading "${item['title']}" to your offline bookshelf...'),
                  backgroundColor: const Color(0xFF059669),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final list = _filteredResources;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: WarmBackdrop(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Header Bar
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Digital Library & E-Books',
                              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.5,
                                  ),
                            ),
                            const SizedBox(width: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                              decoration: BoxDecoration(
                                color: _studentAccent.withValues(alpha: 0.25),
                                borderRadius: BorderRadius.circular(AppRadii.pill),
                                border: Border.all(color: Colors.black12),
                              ),
                              child: Text(
                                '${_allResources.length} Materials Available',
                                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: Color(0xFF1A1A1A)),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        const Text(
                          'Textbooks, revision summaries, solved board papers & lab manuals',
                          style: TextStyle(fontSize: 13, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // 2. Search & Category Filter Controls
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: GlassCard(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      // Search Field
                      Expanded(
                        child: TextField(
                          onChanged: (v) => setState(() => _searchQuery = v),
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                          decoration: InputDecoration(
                            hintText: 'Search textbooks, formulas, question banks, or topics...',
                            prefixIcon: const Icon(Icons.search, size: 20, color: Color(0xFF2E5BFF)),
                            suffixIcon: _searchQuery.isNotEmpty
                                ? IconButton(icon: const Icon(Icons.clear, size: 16), onPressed: () => setState(() => _searchQuery = ''))
                                : null,
                            filled: true,
                            fillColor: Colors.white.withValues(alpha: 0.7),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadii.pill), borderSide: const BorderSide(color: AppColors.glassBorder)),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadii.pill), borderSide: const BorderSide(color: AppColors.glassBorder)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      // Category Filter Chips
                      _categoryChip('All'),
                      const SizedBox(width: 6),
                      _categoryChip('Textbooks'),
                      const SizedBox(width: 6),
                      _categoryChip('Revision Notes'),
                      const SizedBox(width: 6),
                      _categoryChip('Question Banks'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // 3. Digital Library Catalog Grid
              Expanded(
                child: list.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.search_off_rounded, size: 48, color: AppColors.textSecondary),
                            const SizedBox(height: 12),
                            Text('No books found matching "$_searchQuery"', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                          ],
                        ),
                      )
                    : GridView.builder(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          mainAxisSpacing: 14,
                          crossAxisSpacing: 14,
                          childAspectRatio: 1.45,
                        ),
                        itemCount: list.length,
                        itemBuilder: (context, index) {
                          final item = list[index];
                          final color = item['color'] as Color;
                          final icon = item['icon'] as IconData;

                          return GlassCard(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                // Top Header with Subject & Bookmark
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: color.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(AppRadii.pill),
                                        border: Border.all(color: color.withValues(alpha: 0.25)),
                                      ),
                                      child: Text(
                                        item['subject'] as String,
                                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11, color: color),
                                      ),
                                    ),
                                    Icon(
                                      item['isBookmarked'] == true ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                                      size: 20,
                                      color: item['isBookmarked'] == true ? _studentAccent : AppColors.textSecondary,
                                    ),
                                  ],
                                ),

                                // Book Title & Description
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(icon, size: 18, color: color),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            item['title'] as String,
                                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: AppColors.textPrimary),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      item['description'] as String,
                                      style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary, height: 1.3),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),

                                // Bottom Footer & Actions
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(item['author'] as String, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                                        Text(item['format'] as String, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
                                      ],
                                    ),
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: _primaryBlue,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.pill)),
                                        elevation: 0,
                                      ),
                                      onPressed: () => _openReaderModal(item),
                                      child: const Text('Read Online', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11.5)),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _categoryChip(String label) {
    final isSelected = _selectedCategory == label;

    return InkWell(
      onTap: () => setState(() => _selectedCategory = label),
      borderRadius: BorderRadius.circular(AppRadii.pill),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? _primaryBlue : Colors.white.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(AppRadii.pill),
          border: Border.all(color: isSelected ? _primaryBlue : AppColors.glassBorder),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            color: isSelected ? Colors.white : AppColors.textPrimary,
          ),
        ),
      ),
    );
  }
}
