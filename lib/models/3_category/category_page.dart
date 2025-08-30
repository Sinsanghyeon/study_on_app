import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'study_card.dart';
import 'study_creation_page.dart';
import 'category_data.dart';

class CategoryPage extends StatefulWidget {
  final String? initialFirstCategory;
  const CategoryPage({super.key, this.initialFirstCategory});

  @override
  State<CategoryPage> createState() => _CategoryPageState();
}

class _CategoryPageState extends State<CategoryPage> {
  String? _selectedFirstCategory;
  List<String> _selectedSecondCategories = [];
  bool _showOnlyRecruiting = true;

  @override
  void initState() {
    super.initState();
    _selectedFirstCategory = widget.initialFirstCategory;
  }

  void _onSecondCategorySelected(String category) {
    setState(() {
      if (_selectedSecondCategories.contains(category)) {
        _selectedSecondCategories.remove(category);
      } else {
        _selectedSecondCategories.add(category);
      }
    });
  }

  Query _buildQuery() {
    Query query = FirebaseFirestore.instance.collection('studies');

    if (_showOnlyRecruiting) {
      query = query.where('isRecruiting', isEqualTo: true);
    }

    List<String> categoriesToFilter = [];
    if (_selectedFirstCategory != null && _selectedSecondCategories.isEmpty) {
      categoriesToFilter.addAll(studyCategories[_selectedFirstCategory]!);
    } else if (_selectedSecondCategories.isNotEmpty) {
      categoriesToFilter.addAll(_selectedSecondCategories);
    }

    if (categoriesToFilter.isNotEmpty) {
      query = query.where('category', whereIn: categoriesToFilter);
    }

    return query.orderBy('createdAt', descending: true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('탐색'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            tooltip: '스터디 개설',
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const StudyCreationPage()));
            },
          ),
        ],
      ),
      body: Column(
        children: [
          _buildFilterSection(),
          const Divider(height: 1, thickness: 1),
          Expanded(child: _buildStudyList()),
        ],
      ),
    );
  }

  Widget _buildFilterSection() {
    return Container(
      padding: const EdgeInsets.all(12.0),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('필터', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              // [오류 수정] Row 위젯 안에서 무한한 너비 오류를 방지하기 위해 Expanded 위젯으로 감싸줍니다.
              Expanded(
                child: SwitchListTile(
                  title: const Text('모집 중만 보기'),
                  value: _showOnlyRecruiting,
                  onChanged: (val) => setState(() => _showOnlyRecruiting = val),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              )
            ],
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: studyCategories.keys.map((category) {
                final isSelected = _selectedFirstCategory == category;
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: ChoiceChip(
                    label: Text(category),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          _selectedFirstCategory = category;
                        } else {
                          _selectedFirstCategory = null;
                        }
                        _selectedSecondCategories.clear();
                      });
                    },
                    selectedColor: Colors.teal.shade100,
                  ),
                );
              }).toList(),
            ),
          ),
          if (_selectedFirstCategory != null) const Divider(height: 16),
          if (_selectedFirstCategory != null)
            Wrap(
              spacing: 8.0,
              runSpacing: 4.0,
              children: studyCategories[_selectedFirstCategory]!.map((subCategory) {
                return FilterChip(
                  label: Text(subCategory),
                  selected: _selectedSecondCategories.contains(subCategory),
                  onSelected: (_) => _onSecondCategorySelected(subCategory),
                  selectedColor: Colors.teal.shade100,
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildStudyList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _buildQuery().snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('오류가 발생했습니다: ${snapshot.error}'));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('해당 조건의 스터디가 없습니다.'));
        }

        return ListView(
          children: snapshot.data!.docs.map((doc) {
            final studyData = doc.data() as Map<String, dynamic>;
            return StudyCard(
              studyId: doc.id,
              studyData: studyData,
            );
          }).toList(),
        );
      },
    );
  }
}