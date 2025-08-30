import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'study_detail_page.dart';
import '../3_category//study_card.dart';

class CategoryPage extends StatefulWidget {
  final String? initialFirstCategory;
  const CategoryPage({super.key, this.initialFirstCategory});
  @override
  State<CategoryPage> createState() => _CategoryPageState();
}

class _CategoryPageState extends State<CategoryPage> {
  final _searchController = TextEditingController();

  String _selectedSort = '최근등록순';
  DateTimeRange? _dateRange;
  List<String> _selectedSubCategories = [];
  Set<String> _selectedLocations = {};

  bool _isLoadingFilters = true;
  final List<String> sortOptions = ['인기순', '최근등록순', '마감임박순'];
  Map<String, dynamic> categoryMap = {};
  Map<String, dynamic> locationMap = {};

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() => setState(() {}));
    _loadFilterDataFromFirebase();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<DropdownMenuItem<String>> _buildUniqueDropdownItems(List<String> items) {
    final Set<String> uniqueValues = <String>{};
    final List<DropdownMenuItem<String>> uniqueItems = [];
    for (final itemValue in items) {
      if (uniqueValues.add(itemValue)) {
        uniqueItems.add(
          DropdownMenuItem(
            value: itemValue,
            child: Text(itemValue),
          ),
        );
      }
    }
    return uniqueItems;
  }

  void _applyInitialCategoryFilter(String firstCategory) {
    if (!categoryMap.containsKey(firstCategory)) return;
    List<String> initialSubs = [];
    final secondCatMap = categoryMap[firstCategory] as Map<String, dynamic>;
    secondCatMap.forEach((secondCat, thirdCats) {
      if (thirdCats is List) {
        initialSubs.addAll(thirdCats.map((e) => e.toString()));
      }
    });
    setState(() {
      _selectedSubCategories = initialSubs;
    });
  }

  Future<void> _loadFilterDataFromFirebase() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('app_config')
          .doc('filter_options')
          .get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        categoryMap = data['categoryMap'] as Map<String, dynamic>? ?? {};
        locationMap = data['locationMap'] as Map<String, dynamic>? ?? {};
        if (widget.initialFirstCategory != null) {
          _applyInitialCategoryFilter(widget.initialFirstCategory!);
        }
        if (mounted) setState(() {});
      }
    } catch (e) {
      print("필터 데이터 로딩 실패: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('필터 정보를 불러오는 데 실패했습니다.')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingFilters = false;
        });
      }
    }
  }

  void _showFilterBottomSheet() {
    List<String> tempSelectedSubCategories = List.from(_selectedSubCategories);
    Set<String> tempSelectedLocations = Set.from(_selectedLocations);
    DateTimeRange? tempDateRange = _dateRange;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setStateBottom) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.8,
              padding: const EdgeInsets.only(top: 16.0),
              child: Column(
                children: [
                  const Text('필터',
                      style:
                      TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('카테고리',
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          _buildCategoryFilter(
                              setStateBottom, tempSelectedSubCategories),
                          const SizedBox(height: 24),
                          const Text('지역',
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          _buildLocationFilter(
                              setStateBottom, tempSelectedLocations),
                          const SizedBox(height: 24),
                          const Text('기간별',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 16)),
                          const SizedBox(height: 8),
                          _buildDateFilter(setStateBottom, tempDateRange,
                                  (range) => tempDateRange = range),
                        ],
                      ),
                    ),
                  ),
                  const Divider(height: 1),
                  _buildSelectedFilters(
                    setStateBottom,
                    tempSelectedSubCategories,
                    tempSelectedLocations,
                    tempDateRange,
                        () => tempSelectedSubCategories.clear(),
                        () => tempSelectedLocations.clear(),
                        () => tempDateRange = null,
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _selectedSubCategories = tempSelectedSubCategories;
                          _selectedLocations = tempSelectedLocations;
                          _dateRange = tempDateRange;
                        });
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 48),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12))),
                      child: const Text('필터 적용'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildCategoryFilter(void Function(void Function()) setState, List<String> selectedSubs) {
    if (categoryMap.isEmpty) {
      return const SizedBox(height: 300, child: Center(child: Text("카테고리 정보가 없습니다.")));
    }

    List<String> firstCats = categoryMap.keys.toList()..sort();
    String activeFirstCat = firstCats.first;

    Map<String, dynamic> secondCatMap = categoryMap[activeFirstCat] as Map<String, dynamic>;
    List<String> secondCats = secondCatMap.keys.toList()..sort();
    String activeSecondCat = secondCats.isNotEmpty ? secondCats.first : '';


    return StatefulBuilder(
      builder: (context, setPanelState) {
        firstCats = categoryMap.keys.toList()..sort();
        secondCatMap = categoryMap[activeFirstCat] as Map<String, dynamic>;
        secondCats = secondCatMap.keys.toList()..sort();

        return Column(
          children: [
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<String>(
                style: SegmentedButton.styleFrom(
                  selectedBackgroundColor: Colors.teal.shade50,
                  selectedForegroundColor: Colors.teal.shade900,
                  side: BorderSide(color: Colors.grey.shade300),
                ),
                segments: firstCats.map((cat) => ButtonSegment<String>(value: cat, label: Text(cat, style: const TextStyle(fontSize: 12)))).toList(),
                selected: {activeFirstCat},
                onSelectionChanged: (newSelection) {
                  setPanelState(() {
                    activeFirstCat = newSelection.first;
                    secondCatMap = categoryMap[activeFirstCat] as Map<String, dynamic>;
                    secondCats = secondCatMap.keys.toList()..sort();
                    activeSecondCat = secondCats.isNotEmpty ? secondCats[0] : '';
                  });
                },
              ),
            ),
            const SizedBox(height: 8),
            Container(
              height: 250,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: Container(
                      color: Colors.grey[100],
                      child: ListView.builder(
                        itemCount: secondCats.length,
                        itemBuilder: (context, index) {
                          final cat = secondCats[index];
                          return ListTile(
                            title: Text(cat, style: TextStyle(fontWeight: cat == activeSecondCat ? FontWeight.bold : FontWeight.normal, fontSize: 14)),
                            selected: cat == activeSecondCat,
                            selectedTileColor: Colors.white,
                            onTap: () => setPanelState(() => activeSecondCat = cat),
                          );
                        },
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: (secondCats.isEmpty || (secondCatMap[activeSecondCat] as List<dynamic>).isEmpty)
                        ? const Center(child: Text("세부 항목 없음"))
                        : ListView(
                      children: ((secondCatMap[activeSecondCat] as List<dynamic>).cast<String>().toList()..sort()).map((third) {
                        return CheckboxListTile(
                          title: Text(third),
                          value: selectedSubs.contains(third),
                          onChanged: (checked) {
                            setState(() {
                              if (checked ?? false) {
                                selectedSubs.add(third);
                              } else {
                                selectedSubs.remove(third);
                              }
                            });
                          },
                          dense: true,
                          controlAffinity: ListTileControlAffinity.leading,
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildLocationFilter(void Function(void Function()) setState, Set<String> selectedLocs) {
    if (locationMap.isEmpty) {
      return const SizedBox(height: 200, child: Center(child: Text("지역 정보가 없습니다.")));
    }

    List<String> sidoList = locationMap.keys.toList()..sort();
    String activeSido = sidoList.first;

    return StatefulBuilder(
      builder: (context, setPanelState) {
        List<String> sigunguList = List<String>.from(locationMap[activeSido] as List)..sort();

        return Container(
          height: 200,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Expanded(
                flex: 2,
                child: Container(
                  color: Colors.grey[100],
                  child: ListView.builder(
                    itemCount: sidoList.length,
                    itemBuilder: (context, index) {
                      final sido = sidoList[index];
                      return ListTile(
                        title: Text(sido, style: TextStyle(fontWeight: sido == activeSido ? FontWeight.bold : FontWeight.normal, fontSize: 14)),
                        selected: sido == activeSido,
                        selectedTileColor: Colors.white,
                        onTap: () {
                          setPanelState(() {
                            activeSido = sido;
                          });
                        },
                      );
                    },
                  ),
                ),
              ),
              Expanded(
                flex: 3,
                child: sigunguList.isEmpty
                    ? const Center(child: Text("세부 지역 없음"))
                    : ListView(
                  children: sigunguList.map((sigungu) {
                    final uniqueLocationId = '$activeSido>$sigungu';
                    final isSelected = selectedLocs.contains(uniqueLocationId);
                    return CheckboxListTile(
                      title: Text(sigungu),
                      value: isSelected,
                      onChanged: (checked) {
                        setState(() {
                          if (checked ?? false) {
                            selectedLocs.add(uniqueLocationId);
                          } else {
                            selectedLocs.remove(uniqueLocationId);
                          }
                        });
                      },
                      dense: true,
                      controlAffinity: ListTileControlAffinity.leading,
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDateFilter(void Function(void Function()) setState, DateTimeRange? dateRange, Function(DateTimeRange) onDateChanged) {
    return InkWell(
      onTap: () async {
        final picked = await showDateRangePicker(context: context, firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 365)));
        if (picked != null) setState(() => onDateChanged(picked));
      },
      child: InputDecorator(
        decoration: const InputDecoration(border: OutlineInputBorder(), labelText: '스터디 기간'),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(dateRange == null ? '날짜를 선택하세요' : '${DateFormat('yy/MM/dd').format(dateRange.start)} ~ ${DateFormat('yy/MM/dd').format(dateRange.end)}'),
            const Icon(Icons.calendar_today)
          ],
        ),
      ),
    );
  }

  Widget _buildSelectedFilters(
      void Function(void Function()) setState,
      List<String> selectedSubs, Set<String> selectedLocs, DateTimeRange? dateRange,
      VoidCallback onSubsClear, VoidCallback onLocsClear, VoidCallback onDateClear
      ) {
    bool hasFilters = selectedSubs.isNotEmpty || selectedLocs.isNotEmpty || dateRange != null;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('선택된 필터', style: TextStyle(fontWeight: FontWeight.bold)),
              if(hasFilters) TextButton(onPressed: () => setState(() { onSubsClear(); onLocsClear(); onDateClear(); }), child: const Text('초기화'))
            ],
          ),
          const SizedBox(height: 8),
          if (!hasFilters) const Text('선택된 필터가 없습니다.', style: TextStyle(color: Colors.grey)),
          if (hasFilters)
            Wrap(
              spacing: 8.0,
              runSpacing: 4.0,
              children: [
                ...selectedSubs.map((sub) => Chip(
                  label: Text(sub),
                  onDeleted: () => setState(() => selectedSubs.remove(sub)),
                )),
                ...selectedLocs.map((uniqueId) => Chip(
                  label: Text(uniqueId.replaceAll('>', ' ')),
                  onDeleted: () => setState(() => selectedLocs.remove(uniqueId)),
                )),
                if (dateRange != null)
                  Chip(
                    label: Text('${DateFormat('yy/MM/dd').format(dateRange.start)}-${DateFormat('yy/MM/dd').format(dateRange.end)}'),
                    onDeleted: () => setState(onDateClear),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  Stream<QuerySnapshot> _buildStudyStream() {
    Query query = FirebaseFirestore.instance.collection('studies');

    if (_selectedSubCategories.isNotEmpty) {
      query = query.where('category', whereIn: _selectedSubCategories);
    }

    if (_selectedLocations.isNotEmpty) {
      query = query.where('location_id', whereIn: _selectedLocations.toList());
    }

    if (_dateRange != null) {
      query = query.where('studyPeriodStart', isGreaterThanOrEqualTo: _dateRange!.start).where('studyPeriodStart', isLessThanOrEqualTo: _dateRange!.end);
    }

    switch (_selectedSort) {
      case '인기순':
        query = query.orderBy('memberCount', descending: true);
        break;
      case '마감임박순':
        query = query.orderBy('deadline', descending: false);
        break;
      case '최근등록순':
      default:
        query = query.orderBy('createdAt', descending: true);
        break;
    }
    return query.snapshots();
  }

  void _showAddStudySheet() {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final maxCtrl = TextEditingController(text: '5');
    final scheduleCtrl = TextEditingController();

    String? selectedSido;
    String? selectedSigungu;

    String? selectedMainCat, selectedSecondCat, selectedThirdCat;
    String studyType = '온라인';
    DateTime? deadline;
    DateTimeRange? studyPeriod;

    bool isCreating = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        maxChildSize: 0.9,
        expand: false,
        builder: (_, scrollController) => StatefulBuilder(
          builder: (context, setStateModal) {
            return Scaffold(
              appBar: AppBar(
                title: const Text('새 스터디 만들기', style: TextStyle(fontSize: 18, color: Colors.black87)),
                automaticallyImplyLeading: false,
                backgroundColor: Colors.transparent,
                elevation: 0,
                centerTitle: true,
                actions: [
                  IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
                ],
              ),
              body: SingleChildScrollView(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: '모임명', hintText: '예: 함께 성장하는 플러터 스터디')),
                    TextField(controller: descCtrl, decoration: const InputDecoration(labelText: '소개', alignLabelWithHint: true, hintText: '예: 초보자도 환영해요! 매주 온라인으로 만나 진행 상황을 공유하고, 막히는 부분을 함께 해결해요.'), maxLines: 3),
                    const SizedBox(height: 24),
                    const Text('카테고리', style: TextStyle(fontWeight: FontWeight.bold)),
                    DropdownButton<String>(
                      isExpanded: true, hint: const Text('1차 선택'), value: selectedMainCat,
                      items: _buildUniqueDropdownItems(categoryMap.keys.toList()..sort()),
                      onChanged: (val) => setStateModal(() { selectedMainCat = val; selectedSecondCat = null; selectedThirdCat = null; }),
                    ),
                    if (selectedMainCat != null && categoryMap.containsKey(selectedMainCat))
                      DropdownButton<String>(
                        isExpanded: true, hint: const Text('2차 선택'), value: selectedSecondCat,
                        items: _buildUniqueDropdownItems((categoryMap[selectedMainCat] as Map<String, dynamic>).keys.toList()..sort()),
                        onChanged: (val) => setStateModal(() { selectedSecondCat = val; selectedThirdCat = null; }),
                      ),
                    if (selectedMainCat != null && selectedSecondCat != null && (categoryMap[selectedMainCat] as Map<String, dynamic>).containsKey(selectedSecondCat))
                      DropdownButton<String>(
                        isExpanded: true, hint: const Text('3차 선택'), value: selectedThirdCat,
                        items: _buildUniqueDropdownItems(((categoryMap[selectedMainCat] as Map<String, dynamic>)[selectedSecondCat] as List<dynamic>).cast<String>().toList()..sort()),
                        onChanged: (val) => setStateModal(() => selectedThirdCat = val),
                      ),
                    const SizedBox(height: 24),
                    const Text('모집 정보', style: TextStyle(fontWeight: FontWeight.bold)),
                    Row(children: [
                      Expanded(child: TextField(controller: maxCtrl, decoration: const InputDecoration(labelText: '모집인원'), keyboardType: TextInputType.number)),
                      const SizedBox(width: 16),
                      Expanded(
                        child: InkWell(
                          onTap: () async {
                            final pickedDate = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 90)));
                            if(pickedDate != null) setStateModal(() => deadline = pickedDate);
                          },
                          child: InputDecorator(
                            decoration: const InputDecoration(labelText: '모집 마감일'),
                            child: Text(deadline == null ? '날짜 선택' : DateFormat('yyyy-MM-dd').format(deadline!)),
                          ),
                        ),
                      )
                    ]),
                    const SizedBox(height: 16),
                    InkWell(
                      onTap: () async {
                        final pickedRange = await showDateRangePicker(context: context, firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 365)));
                        if (pickedRange != null) setStateModal(() => studyPeriod = pickedRange);
                      },
                      child: InputDecorator(
                        decoration: const InputDecoration(labelText: '스터디 기간'),
                        child: Text(studyPeriod == null ? '스터디 시작일 ~ 종료일 선택' : '${DateFormat('yy/MM/dd').format(studyPeriod!.start)} ~ ${DateFormat('yy/MM/dd').format(studyPeriod!.end)}'),
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text('진행 방식', style: TextStyle(fontWeight: FontWeight.bold)),
                    Row(
                      children: [
                        Expanded(child: RadioListTile(title: const Text('오프라인'), value: '오프라인', groupValue: studyType, onChanged: (v) => setStateModal(() => studyType = v!))),
                        Expanded(child: RadioListTile(title: const Text('온라인'), value: '온라인', groupValue: studyType, onChanged: (v) => setStateModal(() => studyType = v!)))
                      ],
                    ),
                    TextField(controller: scheduleCtrl, decoration: const InputDecoration(labelText: '스터디 시간', hintText: '예: 매주 토요일 오후 2시')),

                    if (studyType == '오프라인')
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 24),
                          const Text('주요 활동 지역', style: TextStyle(fontWeight: FontWeight.bold)),
                          DropdownButton<String>(
                            isExpanded: true,
                            hint: const Text('시/도 선택'),
                            value: selectedSido,
                            items: (locationMap.keys.toList()..sort()).map((sido) => DropdownMenuItem(value: sido, child: Text(sido))).toList(),
                            onChanged: (val) => setStateModal(() {
                              selectedSido = val;
                              selectedSigungu = null;
                            }),
                          ),
                          if(selectedSido != null)
                            DropdownButton<String>(
                              isExpanded: true,
                              hint: const Text('시/군/구 선택'),
                              value: selectedSigungu,
                              items: ((locationMap[selectedSido] as List<dynamic>).cast<String>().toList()..sort()).map((sigungu) => DropdownMenuItem(value: sigungu, child: Text(sigungu))).toList(),
                              onChanged: (val) => setStateModal(() => selectedSigungu = val),
                            ),
                        ],
                      ),

                    const SizedBox(height: 32),
                    ElevatedButton(
                      onPressed: isCreating ? null : () async {
                        setStateModal(() => isCreating = true);

                        try {
                          final currentUser = FirebaseAuth.instance.currentUser;
                          if (currentUser == null) {
                            if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('로그인이 필요합니다.')));
                            setStateModal(() => isCreating = false);
                            return;
                          }
                          if (titleCtrl.text.isEmpty || selectedThirdCat == null) {
                            if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('모임명과 카테고리는 필수 입력 항목입니다.')));
                            setStateModal(() => isCreating = false);
                            return;
                          }
                          if (studyType == '오프라인' && selectedSigungu == null) {
                            if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('오프라인 스터디는 지역을 선택해야 합니다.')));
                            setStateModal(() => isCreating = false);
                            return;
                          }

                          final userDoc = await FirebaseFirestore.instance.collection('users').doc(currentUser.uid).get();
                          final nickname = userDoc.data()?['displayName'] as String? ?? currentUser.email?.split('@')[0];

                          final String? locationId = (studyType == '오프라인' && selectedSido != null && selectedSigungu != null)
                              ? '$selectedSido>$selectedSigungu'
                              : null;

                          final studyData = {
                            'title': titleCtrl.text,
                            'desc': descCtrl.text,
                            'maxMembers': int.tryParse(maxCtrl.text) ?? 5,
                            'leaderId': currentUser.uid,
                            'leaderEmail': currentUser.email,
                            'leaderNickname': nickname,
                            'members': [currentUser.uid],
                            'memberEmails': [currentUser.email],
                            'memberNicknames': [nickname],
                            'memberCount': 1,
                            'isRecruiting': true,
                            'createdAt': FieldValue.serverTimestamp(),
                            'category': selectedThirdCat,
                            'type': studyType,
                            'deadline': deadline,
                            'schedule': scheduleCtrl.text,
                            'location_id': locationId,
                            'location_sigungu': studyType == '오프라인' ? selectedSigungu : null,
                            'studyPeriodStart': studyPeriod?.start,
                            'studyPeriodEnd': studyPeriod?.end,
                          };

                          await FirebaseFirestore.instance.collection('studies').add(studyData);

                          if(mounted) Navigator.pop(context);

                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('스터디 생성 실패: $e')));
                          }
                        } finally {
                          if (mounted) {
                            setStateModal(() => isCreating = false);
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 48)),
                      child: isCreating ? const CircularProgressIndicator(color: Colors.white) : const Text('스터디 생성'),
                    )
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingFilters) {
      return Scaffold(
        appBar: AppBar(title: const Text('스터디 탐색')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('스터디 탐색')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: '스터디 제목으로 검색...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    filled: true,
                    fillColor: Colors.grey[200],
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    DropdownButton<String>(
                      value: _selectedSort,
                      onChanged: (val) => setState(() => _selectedSort = val!),
                      items: sortOptions.map((opt) => DropdownMenuItem(value: opt, child: Text(opt))).toList(),
                    ),
                    TextButton.icon(
                      onPressed: (_isLoadingFilters || categoryMap.isEmpty || locationMap.isEmpty) ? null : _showFilterBottomSheet,
                      icon: const Icon(Icons.filter_list),
                      label: const Text('필터', style: TextStyle(fontSize: 16)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _buildStudyStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                if (snapshot.hasError) return Center(child: Text('오류가 발생했습니다.\n${snapshot.error}'));

                final allDocs = snapshot.data?.docs ?? [];

                final searchText = _searchController.text.trim().toLowerCase();
                final filteredDocs = searchText.isEmpty
                    ? allDocs
                    : allDocs.where((doc) {
                  final title = (doc.data() as Map<String, dynamic>)['title']?.toString().toLowerCase() ?? '';
                  return title.contains(searchText);
                }).toList();

                if (filteredDocs.isEmpty) {
                  return const Center(child: Text("조건에 맞는 스터디가 없습니다."));
                }

                // [오류 수정] .map의 결과를 <Widget>[] 또는 toList()를 통해 명시적으로 List<Widget>으로 변환
                return ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: filteredDocs.map<Widget>((doc) {
                    final studyData = doc.data() as Map<String, dynamic>;
                    return StudyCard(
                      studyId: doc.id,
                      // [오류 수정] study -> studyData 로 매개변수 이름 변경
                      studyData: studyData,
                    );
                  }).toList(),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddStudySheet,
        backgroundColor: Colors.teal,
        child: const Icon(Icons.add),
      ),
    );
  }
}