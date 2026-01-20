# Snow Paradise 보안 및 성능 개선 계획

분석된 보안 이슈와 서버 부하 위험 요소를 해결하기 위한 구현 계획입니다.

## User Review Required

> [!CAUTION]
> **Firestore Security Rules가 존재하지 않습니다.** 현재 상태에서는 모든 사용자가 모든 데이터에 접근할 수 있습니다. 즉시 조치가 필요합니다.

> [!WARNING]
> **관리자 비밀번호가 클라이언트에 노출됩니다.** `admin/settings` 문서를 읽을 수 있는 사용자는 비밀번호를 볼 수 있습니다.

**결정이 필요한 사항:**
1. Cloud Functions 도입 여부 (관리자 인증 서버사이드 이전)
2. 보안 규칙만 먼저 적용할지, 전체 리팩토링을 진행할지

---

## Phase 1: Firestore Security Rules (Critical - 즉시 적용)

### [NEW] [firestore.rules](file:///Users/gimdoyun/Documents/snow_paradise/firestore.rules)

Firestore 보안 규칙을 생성하여 다음을 적용합니다:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    
    // 헬퍼 함수
    function isAuthenticated() {
      return request.auth != null;
    }
    
    function isOwner(uid) {
      return isAuthenticated() && request.auth.uid == uid;
    }
    
    // 1. users 컬렉션
    match /users/{userId} {
      allow read: if isAuthenticated();
      allow create: if isOwner(userId);
      allow update: if isOwner(userId) || 
                      (isAuthenticated() && request.resource.data.diff(resource.data).affectedKeys().hasOnly(['isBanned']));
      allow delete: if isOwner(userId);
      
      // 사용자별 서브컬렉션
      match /likes/{productId} {
        allow read, write: if isOwner(userId);
      }
      
      match /blocked_users/{blockedId} {
        allow read, write: if isOwner(userId);
      }
      
      match /notifications/{notificationId} {
        allow read, write: if isOwner(userId);
      }
    }
    
    // 2. products 컬렉션
    match /products/{productId} {
      allow read: if true;  // 상품은 누구나 조회 가능
      allow create: if isAuthenticated();
      allow update: if isAuthenticated() && 
                      (resource.data.sellerId == request.auth.uid || 
                       request.resource.data.diff(resource.data).affectedKeys().hasOnly(['likeCount', 'chatCount']));
      allow delete: if isAuthenticated() && resource.data.sellerId == request.auth.uid;
    }
    
    // 3. chat_rooms 컬렉션
    match /chat_rooms/{roomId} {
      allow read: if isAuthenticated() && 
                    (resource.data.sellerId == request.auth.uid || 
                     resource.data.buyerId == request.auth.uid);
      allow create: if isAuthenticated();
      allow update: if isAuthenticated() && 
                      request.auth.uid in resource.data.participants;
      
      match /messages/{messageId} {
        allow read, write: if isAuthenticated() && 
                             request.auth.uid in get(/databases/$(database)/documents/chat_rooms/$(roomId)).data.participants;
      }
    }
    
    // 4. admin 컬렉션 - Critical Security Fix
    match /admin/{document=**} {
      allow read: if false;  // 클라이언트에서 절대 읽기 금지!
      allow write: if false; // 클라이언트에서 절대 쓰기 금지!
    }
    
    // 5. reports 컬렉션
    match /reports/{reportId} {
      allow read: if false;  // 관리자만 (Cloud Functions 또는 Admin SDK)
      allow create: if isAuthenticated();
      allow update, delete: if false;
    }
    
    // 6. search_keywords 컬렉션
    match /search_keywords/{keyword} {
      allow read: if true;
      allow write: if isAuthenticated();
    }
    
    // 7. metadata 컬렉션 (브랜드 등)
    match /metadata/{docId} {
      allow read: if true;
      allow write: if false;  // 관리자만 (Cloud Functions)
    }
    
    // 8. notices, terms 컬렉션
    match /notices/{noticeId} {
      allow read: if true;
      allow write: if false;  // 관리자만
    }
    
    match /terms/{termId} {
      allow read: if true;
      allow write: if false;  // 관리자만
    }
  }
}
```

**배포 방법:**
```bash
firebase deploy --only firestore:rules
```

---

## Phase 2: 관리자 인증 서버사이드 이전 (High Priority)

현재 클라이언트에서 비밀번호를 비교하는 방식을 Cloud Functions로 이전합니다.

### [NEW] [functions/src/admin.ts](file:///Users/gimdoyun/Documents/snow_paradise/functions/src/admin.ts)

```typescript
import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';
import * as crypto from 'crypto';

export const verifyAdminPassword = functions.https.onCall(async (data, context) => {
  const { password } = data;
  
  if (!password || typeof password !== 'string') {
    throw new functions.https.HttpsError('invalid-argument', '비밀번호가 필요합니다.');
  }
  
  const settingsDoc = await admin.firestore().collection('admin').doc('settings').get();
  
  if (!settingsDoc.exists) {
    throw new functions.https.HttpsError('not-found', '관리자 설정을 찾을 수 없습니다.');
  }
  
  const storedHash = settingsDoc.data()?.passwordHash;
  const inputHash = crypto.createHash('sha256').update(password).digest('hex');
  
  if (storedHash !== inputHash) {
    throw new functions.https.HttpsError('permission-denied', '비밀번호가 일치하지 않습니다.');
  }
  
  // Custom Claim 설정 (선택사항)
  if (context.auth?.uid) {
    await admin.auth().setCustomUserClaims(context.auth.uid, { admin: true });
  }
  
  return { success: true };
});
```

### [MODIFY] [admin_auth_provider.dart](file:///Users/gimdoyun/Documents/snow_paradise/lib/providers/admin_auth_provider.dart)

```dart
// Cloud Functions 호출 방식으로 변경
Future<bool> login(String password) async {
  _isLoading = true;
  notifyListeners();
  
  try {
    final callable = FirebaseFunctions.instance.httpsCallable('verifyAdminPassword');
    final result = await callable.call({'password': password});
    
    if (result.data['success'] == true) {
      _isLoggedIn = true;
      notifyListeners();
      return true;
    }
    return false;
  } catch (e) {
    debugPrint('Admin login error: $e');
    return false;
  } finally {
    _isLoading = false;
    notifyListeners();
  }
}
```

---

## Phase 3: 성능 개선 (Medium Priority)

### 3.1 Wishlist N+1 쿼리 개선

#### [MODIFY] [product_service.dart](file:///Users/gimdoyun/Documents/snow_paradise/lib/providers/product_service.dart)

`getWishlistProducts` 메서드를 배치 쿼리 방식으로 개선:

```dart
Future<List<Product>> getWishlistProducts(String uid) async {
  // ... 기존 likes 조회 코드 ...
  
  // N+1 쿼리 대신 배치 조회 (10개씩)
  final products = <Product>[];
  for (var i = 0; i < productIds.length; i += 10) {
    final batchIds = productIds.skip(i).take(10).toList();
    final snapshot = await _firestore
        .collection('products')
        .where('id', whereIn: batchIds)
        .get();
    products.addAll(snapshot.docs.map(_productFromDoc));
  }
  
  return _filterBlockedProducts(products)
      .where((p) => p.status != ProductStatus.hidden)
      .toList();
}
```

### 3.2 알림 일괄 처리 개선

#### [MODIFY] [notification_provider.dart](file:///Users/gimdoyun/Documents/snow_paradise/lib/providers/notification_provider.dart)

Batch 500개 제한 고려 및 분할 처리:

```dart
Future<void> deleteAllNotifications() async {
  // 450개씩 분할 처리 (500개 제한 고려)
  final chunks = _splitIntoChunks(_notifications, 450);
  
  for (final chunk in chunks) {
    final batch = _firestore.batch();
    for (final notification in chunk) {
      batch.delete(_firestore
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .doc(notification.id));
    }
    await batch.commit();
  }
}

List<List<T>> _splitIntoChunks<T>(List<T> list, int chunkSize) {
  final chunks = <List<T>>[];
  for (var i = 0; i < list.length; i += chunkSize) {
    chunks.add(list.skip(i).take(chunkSize).toList());
  }
  return chunks;
}
```

### 3.3 자동완성 로컬 순회 개선

#### [MODIFY] [product_service.dart](file:///Users/gimdoyun/Documents/snow_paradise/lib/providers/product_service.dart)

현재 `getSearchSuggestionsWithType`는 매 키 입력마다 브랜드 목록 + _productList(최대 200개)를 순회합니다.

**문제점:**
- 빠른 타이핑 시 CPU 스파이크
- 브랜드 4개 카테고리 × N개 브랜드 + 200개 상품 이중 루프

**개선 방안:**

```dart
// 1. Debounce 적용 (UI 레벨에서)
Timer? _searchDebounceTimer;

void onSearchQueryChanged(String query) {
  _searchDebounceTimer?.cancel();
  _searchDebounceTimer = Timer(const Duration(milliseconds: 300), () {
    final suggestions = productService.getSearchSuggestionsWithType(query);
    // UI 업데이트
  });
}

// 2. 캐싱된 브랜드 목록 사용 (CategoryAttributes에서 미리 로드)
// 3. search_keywords 컬렉션 기반 인기 검색어 우선 표시
List<SearchSuggestion> getSearchSuggestionsWithType(String query) async {
  final normalizedQuery = query.trim().toLowerCase();
  if (normalizedQuery.isEmpty) return [];
  
  // 인기 검색어에서 먼저 매칭 (Firestore 쿼리 - 캐싱됨)
  final popularKeywords = await _getCachedPopularKeywords();
  final matched = popularKeywords
      .where((k) => k.contains(normalizedQuery))
      .take(5)
      .map((k) => SearchSuggestion(value: k, type: SuggestionType.title))
      .toList();
      
  if (matched.length >= 5) return matched;  // 충분하면 로컬 순회 생략
  
  // 부족하면 브랜드 + 로컬 상품에서 보완
  // ... 기존 로직 (이미 5개가 찼으면 early return)
}

// 인기 검색어 캐싱 (5분 TTL)
List<String>? _cachedPopularKeywords;
DateTime? _popularKeywordsCacheTime;

Future<List<String>> _getCachedPopularKeywords() async {
  final now = DateTime.now();
  if (_cachedPopularKeywords != null && 
      _popularKeywordsCacheTime != null &&
      now.difference(_popularKeywordsCacheTime!).inMinutes < 5) {
    return _cachedPopularKeywords!;
  }
  
  _cachedPopularKeywords = await getPopularKeywords(limit: 20);
  _popularKeywordsCacheTime = now;
  return _cachedPopularKeywords!;
}
```

---

### 3.4 관리자 전체 상품 구독 개선

#### [MODIFY] [product_service.dart](file:///Users/gimdoyun/Documents/snow_paradise/lib/providers/product_service.dart)

현재 관리자 모드는 `limit` 없이 전체 상품을 실시간 구독합니다.

**문제점:**
- 상품 10,000개 = 10,000개 읽기 비용
- 메모리 사용량 증가
- 실시간 구독으로 인한 지속적 비용

**개선 방안:**

```dart
class ProductService extends ChangeNotifier {
  // 관리자도 페이징 적용
  static const int _adminPageSize = 50;  // 관리자용 페이지 크기
  
  void fetchProducts() {
    _productsSubscription?.cancel();
    Query<Map<String, dynamic>> query = _firestore
        .collection('products')
        .orderBy('createdAt', descending: true);

    // 관리자도 제한 적용 (다만 일반 사용자보다 많은 양)
    if (_isAdmin) {
      query = query.limit(_adminPageSize);  // 기존: 제한 없음
    } else {
      query = query.limit(_latestLimit);  // 200개
    }

    _productsSubscription = query.snapshots().listen((snapshot) {
      _allProductList = snapshot.docs.map(_productFromDoc).toList();
      _applyBlockedFilter();
    });
  }
  
  // 관리자용 추가 로드 메서드
  Future<void> loadMoreAdminProducts() async {
    if (!_isAdmin || _allProductList.isEmpty) return;
    
    final lastDoc = await _firestore
        .collection('products')
        .doc(_allProductList.last.docId)
        .get();
    
    final snapshot = await _firestore
        .collection('products')
        .orderBy('createdAt', descending: true)
        .startAfterDocument(lastDoc)
        .limit(_adminPageSize)
        .get();
    
    final newProducts = snapshot.docs.map(_productFromDoc).toList();
    _allProductList.addAll(newProducts);
    _applyBlockedFilter();
  }
}
```

**관리자 화면 수정 (AdminProductListScreen):**
```dart
// 무한 스크롤 또는 "더 보기" 버튼 추가
NotificationListener<ScrollNotification>(
  onNotification: (notification) {
    if (notification is ScrollEndNotification &&
        notification.metrics.extentAfter < 200) {
      productService.loadMoreAdminProducts();
    }
    return false;
  },
  child: ListView.builder(...),
)
```

---

## Verification Plan

### 자동 테스트
```bash
# 보안 규칙 테스트
firebase emulators:start --only firestore
npm test  # firestore rules unit tests

# 앱 빌드 테스트
flutter analyze
flutter build web
```

### 수동 검증
1. 보안 규칙 배포 후 일반 사용자가 `admin/settings` 접근 시 **Permission Denied** 확인
2. 관리자 로그인 기능 정상 작동 확인
3. 채팅/좋아요/알림 기능 정상 작동 확인

---

## 우선순위 정리

| 순서 | 작업 | 예상 시간 | 위험도 |
|------|------|----------|--------|
| 1 | Firestore Security Rules 생성 및 배포 | 30분 | Critical |
| 2 | 관리자 비밀번호 해시화 | 15분 | Critical |
| 3 | Cloud Functions 관리자 인증 | 1시간 | High |
| 4 | Wishlist 쿼리 최적화 | 30분 | Medium |
| 5 | 알림 Batch 분할 처리 | 20분 | Medium |
| 6 | 자동완성 Debounce + 인기검색어 캐싱 | 40분 | Medium |
| 7 | 관리자 상품 목록 페이징 적용 | 30분 | Medium |

