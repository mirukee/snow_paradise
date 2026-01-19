import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/categories.dart';

class BrandService {
  static const String _collection = 'metadata';
  static const String _documentId = 'brands';
  static const String _prefKeyVersion = 'brand_metadata_version';
  static const String _prefKeyData = 'brand_metadata_data';

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// 앱 시작 시 호출하여 브랜드 데이터 동기화
  Future<void> initialize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final localVersion = prefs.getInt(_prefKeyVersion) ?? 0;

      // 1. Firestore에서 버전 확인
      final docSnapshot = await _firestore.collection(_collection).doc(_documentId).get();
      
      if (!docSnapshot.exists) {
        // 문서가 없으면 생성 (초기 데이터 업로드)
        await _initializeFirestoreData();
        return;
      }

      final data = docSnapshot.data()!;
      final remoteVersion = data['version'] as int? ?? 0;

      // 2. 버전 비교
      if (remoteVersion > localVersion) {
        print('BrandService: Found new version ($remoteVersion > $localVersion). Updating...');
        _updateLocalData(prefs, data);
      } else {
        print('BrandService: Local data is up to date (v$localVersion).');
        _loadLocalData(prefs);
      }
    } catch (e) {
      print('BrandService: Initialization failed: $e');
      // 실패 시 기본값 사용 (아무것도 하지 않음)
    }
  }

  /// 로컬 데이터를 메모리(CategoryAttributes)에 반영
  void _loadLocalData(SharedPreferences prefs) {
    final jsonString = prefs.getString(_prefKeyData);
    if (jsonString != null) {
      final data = json.decode(jsonString) as Map<String, dynamic>;
      _applyToCategoryAttributes(data);
    }
  }

  /// Firestore 데이터를 로컬에 저장하고 메모리에 반영
  Future<void> _updateLocalData(SharedPreferences prefs, Map<String, dynamic> data) async {
    await prefs.setInt(_prefKeyVersion, data['version'] as int? ?? 0);
    await prefs.setString(_prefKeyData, json.encode(data));
    _applyToCategoryAttributes(data);
  }

  /// 데이터를 CategoryAttributes에 적용
  void _applyToCategoryAttributes(Map<String, dynamic> data) {
    _updateIfPresent(CategoryAttributes.ATTR_BRAND_SKI, data['brand_ski']);
    _updateIfPresent(CategoryAttributes.ATTR_BRAND_BOARD, data['brand_board']);
    _updateIfPresent(CategoryAttributes.ATTR_BRAND_APPAREL, data['brand_apparel']);
    _updateIfPresent(CategoryAttributes.ATTR_BRAND_GEAR, data['brand_gear']);
  }

  void _updateIfPresent(String key, dynamic value) {
    if (value is List) {
      final options = value.map((e) => e.toString()).toList();
      CategoryAttributes.updateOptions(key, options);
    }
  }

  /// 초기 데이터를 Firestore에 업로드 (최초 1회 실행용)
  Future<void> _initializeFirestoreData() async {
    final initialData = {
      'version': 1,
      'brand_ski': CategoryAttributes.definitions[CategoryAttributes.ATTR_BRAND_SKI]?.options ?? [],
      'brand_board': CategoryAttributes.definitions[CategoryAttributes.ATTR_BRAND_BOARD]?.options ?? [],
      'brand_apparel': CategoryAttributes.definitions[CategoryAttributes.ATTR_BRAND_APPAREL]?.options ?? [],
      'brand_gear': CategoryAttributes.definitions[CategoryAttributes.ATTR_BRAND_GEAR]?.options ?? [],
    };

    await _firestore.collection(_collection).doc(_documentId).set(initialData);
    print('BrandService: Initialized Firestore data.');
  }

  /// 관리자용: 브랜드 목록 업데이트 및 버전 증가
  Future<void> updateBrands({
    List<String>? ski,
    List<String>? board,
    List<String>? apparel,
    List<String>? gear,
  }) async {
    final docRef = _firestore.collection(_collection).doc(_documentId);
    
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);
      if (!snapshot.exists) return;

      final currentVersion = snapshot.data()?['version'] as int? ?? 0;
      final updates = <String, dynamic>{
        'version': currentVersion + 1,
      };

      if (ski != null) updates['brand_ski'] = ski;
      if (board != null) updates['brand_board'] = board;
      if (apparel != null) updates['brand_apparel'] = apparel;
      if (gear != null) updates['brand_gear'] = gear;

      transaction.update(docRef, updates);
    });
    
    // 로컬에도 즉시 반영을 위해 재초기화 호출
    await initialize();
  }
}
