# designrules

아래 텍스트를 새 채팅에 그대로 붙여 사용하세요.

---

Stitch로 생성한 UI 디자인(HTML/CSS)을 내 Flutter 앱에 적용해줘.
프로젝트 실정에 맞게 다음 기준을 반드시 지켜줘.
답변은 반드시 한국어(Korean)로 해줘.

[대상 파일]
- 작업 시작 전에 적용할 화면/파일을 먼저 확인하고 진행.
- 홈 탭은 `lib/screens/home_tab.dart`.
- 홈 전용 카드 컴포넌트는 `lib/widgets/product_card.dart`.
- 홈 AppBar 충돌 시에만 `lib/screens/main_screen.dart` 조정.

[데이터/로직 규칙]
- 상품 데이터는 `ProductService` provider 사용.
- 리스트는 `productService.productList`로 렌더링하고, `GridView/SliverGrid` 빌더를 사용.
- 이미지 로딩은 `buildProductImage` (`lib/widgets/product_image.dart`) 사용.
- 상세 페이지 이동은 `DetailScreen(product: product)` 유지.
- 검색바 탭은 `SearchScreen`으로 이동.
- 좋아요는 `productService.isLiked(product.id)`와
  `productService.toggleLike(product.id, currentUser.uid)` 사용.
  로그인 없으면 SnackBar 표시.
- 가격 포맷은 기존 포맷 함수 유지.
- 핵심 로직 변경 금지. 디자인만 변경.

[레이아웃/스타일 규칙]
- 상단 로고가 필요한 화면은 텍스트 대신 `assets/images/logo.png` 사용.
- HTML의 라운드(2xl 느낌), 그림자, 여백을 최대한 유사하게 매핑.
- 색상 톤은 Ice Blue(0xFF00AEEF) + Deep Navy(#101922) 계열 유지.
- 오버플로우 발생 시 카드 비율/텍스트 크기를 조정해 해결.
- 폰트/패키지 추가는 금지(기존 폰트 사용).

[홈 화면 추가 규칙(해당 시)]
- 카테고리는 가로 스크롤, 한 번에 2개 정도 보이게 구성.
- 상품 카드는 3열 그리드로 작게 구성.

[주의]
- 기존 Provider/서비스 로직은 그대로 유지.
- 디자인 충돌이 예상되면 반드시 질문하고 진행.

---
