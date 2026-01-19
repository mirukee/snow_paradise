class CategoryConstants {
  static const Map<String, List<String>> subCategories = {
    '스키': ['스키', '부츠', '폴', '세트'],
    '스노우보드': ['데크', '바인딩', '부츠', '세트'],
    '의류': ['상의', '하의', '일체형'],
    '장비/보호대': ['헬멧', '고글', '보호대', '장갑'],
    '시즌권': ['통합', '하이원', '용평', '휘닉스', '웰리힐리', '오투', '지산', '곤지암', '무주', '에덴밸리', '기타'],
    '시즌방': ['하이원', '용평', '휘닉스', '웰리힐리', '오투', '지산', '곤지암', '무주', '에덴밸리', '기타'],
    '강습': ['하이원', '용평', '휘닉스', '웰리힐리', '오투', '지산', '곤지암', '무주', '에덴밸리', '기타'],
    '기타': [],
  };

  static List<String> getSubCategories(String category) {
    return subCategories[category] ?? [];
  }
}

/// 속성 입력 방식
enum AttributeInputType {
  chip, // 칩 선택 (기본)
  text, // 텍스트 입력 (숫자 키패드 등)
  searchSelect, // 검색 가능한 선택창 (바텀시트)
}

/// 속성 정의 클래스
class AttributeDefinition {
  final String label;
  final List<String> options;
  final bool allowCustomInput; // '직접 입력' 허용 여부 (Chip 타입일 때 유효)
  final AttributeInputType inputType;

  const AttributeDefinition({
    required this.label,
    required this.options,
    this.allowCustomInput = false,
    this.inputType = AttributeInputType.chip,
  });
}

/// 카테고리별 속성 스키마 및 데이터
class CategoryAttributes {
  // 속성 키 정의
  static const String ATTR_LENGTH_SKI = 'length_ski';
  static const String ATTR_LENGTH_BOARD = 'length_board';
  static const String ATTR_YEAR = 'year';
  static const String ATTR_BRAND_SKI = 'brand_ski';
  static const String ATTR_BRAND_BOARD = 'brand_board';
  static const String ATTR_BRAND_APPAREL = 'brand_apparel';
  static const String ATTR_BRAND_GEAR = 'brand_gear';
  static const String ATTR_SHAPE_SKI = 'shape_ski'; // 스키 쉐입? (스타일로 해석)
  static const String ATTR_SHAPE_BOARD = 'shape_board';
  static const String ATTR_SIZE_BOOT = 'size_boot';
  static const String ATTR_SIZE_APPAREL = 'size_apparel';
  static const String ATTR_SIZE_GEAR = 'size_gear'; // S M L
  static const String ATTR_GENDER = 'gender';

  // 카테고리/소분류별 필요한 속성 목록 매핑
  // Key: "$Category/$SubCategory"
  static const Map<String, List<String>> requiredAttributes = {
    // 스키
    '스키/스키': [ATTR_LENGTH_SKI, ATTR_YEAR, ATTR_BRAND_SKI, ATTR_SHAPE_SKI],
    '스키/부츠': [ATTR_YEAR, ATTR_BRAND_SKI, ATTR_SIZE_BOOT],
    
    // 스노우보드
    '스노우보드/데크': [ATTR_LENGTH_BOARD, ATTR_YEAR, ATTR_BRAND_BOARD, ATTR_SHAPE_BOARD],
    '스노우보드/바인딩': [ATTR_YEAR, ATTR_BRAND_BOARD, ATTR_SIZE_GEAR], // 바인딩 사이즈 S M L
    '스노우보드/부츠': [ATTR_YEAR, ATTR_BRAND_BOARD, ATTR_SIZE_BOOT],
    
    // 의류
    '의류/상의': [ATTR_GENDER, ATTR_BRAND_APPAREL, ATTR_YEAR, ATTR_SIZE_APPAREL],
    '의류/하의': [ATTR_GENDER, ATTR_BRAND_APPAREL, ATTR_YEAR, ATTR_SIZE_APPAREL],
    '의류/일체형': [ATTR_GENDER, ATTR_BRAND_APPAREL, ATTR_YEAR, ATTR_SIZE_APPAREL],

    // 장비/보호대
    '장비/보호대/헬멧': [ATTR_BRAND_GEAR, ATTR_SIZE_GEAR],
    '장비/보호대/고글': [ATTR_BRAND_GEAR], // 고글은 보통 프리사이즈이나 모델명 중요
    '장비/보호대/보호대': [ATTR_BRAND_GEAR, ATTR_SIZE_GEAR],
    '장비/보호대/장갑': [ATTR_BRAND_GEAR, ATTR_SIZE_GEAR],
  };

  // 속성 상세 정의 (옵션 데이터) - 동적 업데이트를 위해 const 제거 및 Map으로 변경
  static Map<String, AttributeDefinition> definitions = {
    ATTR_LENGTH_SKI: const AttributeDefinition(
      label: '길이',
      options: [], // Text 입력이므로 옵션 불필요
      inputType: AttributeInputType.text,
    ),
    ATTR_LENGTH_BOARD: const AttributeDefinition(
      label: '길이',
      options: [],
      inputType: AttributeInputType.text,
    ),
    ATTR_YEAR: const AttributeDefinition(
      label: '연식',
      options: ['24/25', '23/24', '22/23', '21/22', '20/21', '19/20', '이전'],
    ),
    ATTR_BRAND_SKI: const AttributeDefinition(
      label: '브랜드',
      options: ['살로몬', '아토믹', '로시뇰', '헤드', '피셔', '노르디카', '뵐클', '오가사카', '기타'],
      inputType: AttributeInputType.searchSelect,
    ),
    ATTR_BRAND_BOARD: const AttributeDefinition(
      label: '브랜드',
      options: ['버튼', '캐피타', '존스', '라이드', 'K2', '살로몬', '나이트로', '요넥스', '오가사카', '기타'],
      inputType: AttributeInputType.searchSelect,
    ),
    ATTR_BRAND_APPAREL: const AttributeDefinition(
      label: '브랜드',
      options: ['디미토', '686', '볼컴', '버튼', '어스투', '스페셜게스트', '엘나스', '기타'],
      inputType: AttributeInputType.searchSelect,
    ),
    ATTR_BRAND_GEAR: const AttributeDefinition(
      label: '브랜드',
      options: ['오클리', '스미스', '번', 'POC', '지로', '살로몬', '기타'],
      inputType: AttributeInputType.searchSelect,
    ),
    ATTR_SHAPE_SKI: const AttributeDefinition(
      label: '쉐입(스타일)',
      options: ['레이싱', '데모', '올라운드', '프리스타일'],
    ),
    ATTR_SHAPE_BOARD: const AttributeDefinition(
      label: '쉐입',
      options: ['디렉셔널', '트윈', '디렉셔널 트윈', '해머헤드'],
    ),
    ATTR_SIZE_BOOT: const AttributeDefinition(
      label: '사이즈',
      options: ['220', '225', '230', '235', '240', '245', '250', '255', '260', '265', '270', '275', '280', '285', '290'],
      allowCustomInput: true,
    ),
    ATTR_SIZE_APPAREL: const AttributeDefinition(
      label: '사이즈',
      options: ['XS 이하', 'S', 'M', 'L', 'XL 이상'],
    ),
    ATTR_SIZE_GEAR: const AttributeDefinition(
      label: '사이즈',
      options: ['XS 이하', 'S', 'M', 'L', 'XL 이상'],
    ),
    ATTR_GENDER: const AttributeDefinition(
      label: '성별',
      options: ['남여공용', '남성용', '여성용', '키즈'],
    ),
  };

  /// 특정 키의 옵션 목록 업데이트 (동적 브랜드 관리용)
  static void updateOptions(String key, List<String> newOptions) {
    if (newOptions.isEmpty) return;
    
    final oldDef = definitions[key];
    if (oldDef != null) {
      definitions[key] = AttributeDefinition(
        label: oldDef.label,
        options: newOptions,
        inputType: oldDef.inputType,
        allowCustomInput: oldDef.allowCustomInput,
      );
    }
  }
}
