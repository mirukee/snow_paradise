# Snow Paradise 보안 및 성능 개선 계획

분석된 보안 이슈와 서버 부하 위험 요소를 해결하기 위한 구현 계획입니다.

## 현황 요약 (업데이트)

- [DONE] `firestore.rules` 작성 및 배포 완료 (users 제한, public_profiles 공개 분리, admin 차단 포함).
- [DONE] 공개 프로필 분리 및 백필 스크립트 완료 (`public_profiles`).
- [DONE] `likeCount`/`chatCount` 업데이트를 Cloud Functions로 전환.
- [DONE] Wishlist N+1 배치 조회, 알림 일괄 삭제 분할 처리, 검색 debounce + 인기 검색어 캐싱.
- [DONE] 관리자 상품 목록 페이징 적용.
- [DONE] 검색/카테고리/홈 전환 시 페이징 리스트 소실 이슈 수정 (라우트 복귀 리프레시, 검색 자동 추가 로드).
- [DONE] Firestore Web `onSnapshot` 취소 오류 완화 (채팅 스트림 재사용).

**미해결/결정 필요:**
1. Storage Rules 점검 및 배포 경로 정리 (현재 repo에 rules 파일 없음).

---

## Phase 1: Firestore Security Rules (Completed)

### [DONE] `firestore.rules` 작성 및 배포

적용 내용 요약:
- `users`: 본인만 read/write, `isAdmin`/`isBanned` 변경 제한.
- `public_profiles`: 누구나 read, 본인만 create/update, 허용 필드 제한.
- `products`: create 시 `sellerId == auth.uid`, update는 seller(카운트 변경 금지) 또는 admin.
- `admin`: read/write 전면 차단.
- `reports`: create만 허용.
- `search_keywords`, `metadata`, `notices`, `terms`는 read 중심.

**배포 방법 (완료됨):**
```bash
firebase deploy --only firestore:rules
```

---

## Phase 2: 관리자 인증 서버사이드 이전 (Completed)

클라이언트에서 `admin/settings`를 읽어 비밀번호를 비교하던 방식을 Cloud Functions로 이전했습니다.

### [DONE] `functions/index.js` - `verifyAdminPassword`

- `admin/settings`의 `passwordHash`(sha256) 비교
- 기존 `password`(평문)가 남아있으면 **성공 시 해시로 마이그레이션**하고 평문 삭제
- 성공 시 `Custom Claims`에 `admin: true` 설정
- **Firebase Auth 로그인 상태 필요**

### [DONE] `lib/providers/admin_auth_provider.dart`

- `httpsCallable('verifyAdminPassword')` 호출
- 성공 시 `getIdToken(true)`로 토큰/클레임 갱신
- 에러 메시지 노출 및 로딩 상태 유지

### [DONE] `firestore.rules`

- `isAdmin()`에 `request.auth.token.admin == true` 조건 추가

---

## Phase 3: 성능 개선 (Completed)

### 3.1 Wishlist N+1 쿼리 개선 (DONE)

#### [MODIFY] `lib/providers/product_service.dart`

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

### 3.2 알림 일괄 처리 개선 (DONE)

#### [MODIFY] `lib/providers/notification_provider.dart`

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

### 3.3 자동완성 로컬 순회 개선 (DONE)

#### [MODIFY] `lib/providers/product_service.dart`

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

### 3.4 관리자 전체 상품 구독 개선 (DONE)

#### [MODIFY] `lib/providers/product_service.dart`

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

### 3.5 좋아요/채팅 카운트 업데이트 전환 (DONE)

- `likeCount`, `chatCount`는 Cloud Functions에서 증감 처리.
- 클라이언트는 카운트 직접 업데이트를 수행하지 않음.

### 3.6 검색/카테고리/홈 페이징 동기화 이슈 보완 (DONE)

- 라우트 복귀 시 홈 페이징 리프레시.
- 검색 결과가 비어있을 때 자동으로 추가 페이지 로드.
- Firestore Web `onSnapshot` 오류 완화를 위해 채팅 스트림 재사용.

### 3.7 채팅 메시지 로딩 최적화 (DONE)

- `sendMessage`/`markAsRead`에서 불필요한 `roomRef.get()` 제거.
- 메시지 로딩을 `startAfterDocument` 기반 페이지네이션으로 전환.

### 3.8 채팅 미읽음 총합 집계 (DONE)

- `users.unreadTotal`을 Cloud Functions에서 증감.
- 클라이언트는 사용자 문서 스트림으로 뱃지 표시.

---

## 이슈 기록: 채팅방 생성 Permission Denied (DONE)

### 증상
- 게스트/구글 로그인 모두에서 채팅방 생성 실패.
- 콘솔 로그:  
  - `채팅방 조회 실패: [cloud_firestore/permission-denied] Missing or insufficient permissions.`
  - `채팅방 생성 실패: [cloud_firestore/permission-denied] Missing or insufficient permissions.`

### 원인
**`firestore.rules`의 `chat_rooms` list 규칙에서 잘못된 구문 사용:**

```javascript
// ❌ 잘못된 코드 - Firestore Rules에서 지원하지 않는 구문
allow list: if isAuthenticated() &&
    request.query.where('participants', 'array-contains', request.auth.uid);
```

`request.query.where(...)`는 **Firestore Security Rules에서 지원하지 않는 문법**입니다.
지원되는 쿼리 검증 속성: `request.query.limit`, `request.query.offset`, `request.query.orderBy` 등.
`where` 절의 내용을 직접 검증하는 것은 불가능하며, 이 잘못된 구문으로 인해 모든 list 쿼리가 거부되었습니다.

### 해결
```javascript
// ✅ 수정된 코드
allow list: if isAuthenticated();
```

**보안 유지:**
- `get` 규칙에서 `isChatParticipant(resource.data)`로 실제 문서 접근 시 참가자 검증 수행.
- 앱 코드에서 `where('participants', arrayContains: buyerId)` 쿼리 사용으로 자신의 채팅방만 조회됨.

### 배포
```bash
firebase deploy --only firestore:rules
# ✔ Deploy complete! (2026-01-22)

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
4. 검색/카테고리 전환 후 홈 복귀 시 상품 리스트 유지 확인

---

## 우선순위 정리 (현행)

| 순서 | 작업 | 상태 | 위험도 |
|------|------|------|--------|
| 1 | Firestore Security Rules 생성 및 배포 | DONE | Critical |
| 2 | 관리자 비밀번호 해시화 | DONE | Critical |
| 3 | Cloud Functions 관리자 인증 | DONE | High |
| 4 | Wishlist 쿼리 최적화 | DONE | Medium |
| 5 | 알림 Batch 분할 처리 | DONE | Medium |
| 6 | 자동완성 Debounce + 인기검색어 캐싱 | DONE | Medium |
| 7 | 관리자 상품 목록 페이징 적용 | DONE | Medium |
| 8 | 검색/홈 페이징 동기화 보완 | DONE | Medium |
