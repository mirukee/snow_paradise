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

  // 필터 토큰 키 정의 (서버 Query용)
  static const Map<String, String> filterTokenKeyByAttribute = {
    ATTR_BRAND_SKI: 'b',
    ATTR_BRAND_BOARD: 'b',
    ATTR_BRAND_APPAREL: 'b',
    ATTR_BRAND_GEAR: 'b',
    ATTR_LENGTH_SKI: 'l',
    ATTR_LENGTH_BOARD: 'l',
    ATTR_SHAPE_SKI: 's',
    ATTR_SHAPE_BOARD: 's',
    ATTR_SIZE_BOOT: 'sz',
    ATTR_SIZE_APPAREL: 'sz',
    ATTR_SIZE_GEAR: 'sz',
    ATTR_GENDER: 'g',
    ATTR_YEAR: 'y',
  };

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

  // 검색/필터용 핵심 속성 프로파일 (서버 Query용)
  // Key: "$Category/$SubCategory"
  static const Map<String, List<String>> filterProfiles = {
    // 스키
    '스키/스키': [ATTR_BRAND_SKI, ATTR_LENGTH_SKI, ATTR_SHAPE_SKI, ATTR_YEAR],
    '스키/부츠': [ATTR_BRAND_SKI, ATTR_SIZE_BOOT, ATTR_YEAR],

    // 스노우보드
    '스노우보드/데크': [ATTR_BRAND_BOARD, ATTR_LENGTH_BOARD, ATTR_SHAPE_BOARD, ATTR_YEAR],
    '스노우보드/바인딩': [ATTR_BRAND_BOARD, ATTR_SIZE_GEAR, ATTR_YEAR],
    '스노우보드/부츠': [ATTR_BRAND_BOARD, ATTR_SIZE_BOOT, ATTR_YEAR],

    // 의류
    '의류/상의': [ATTR_BRAND_APPAREL, ATTR_SIZE_APPAREL, ATTR_GENDER, ATTR_YEAR],
    '의류/하의': [ATTR_BRAND_APPAREL, ATTR_SIZE_APPAREL, ATTR_GENDER, ATTR_YEAR],
    '의류/일체형': [ATTR_BRAND_APPAREL, ATTR_SIZE_APPAREL, ATTR_GENDER, ATTR_YEAR],

    // 장비/보호대
    '장비/보호대/헬멧': [ATTR_BRAND_GEAR, ATTR_SIZE_GEAR],
    '장비/보호대/고글': [ATTR_BRAND_GEAR],
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
      options: [
        '노르디카 (NORDICA)',
        '다이나스타 (DYNASTAR)',
        '달벨로 (DALBELLO)',
        '랑게 (LANGE)',
        '로시뇰 (ROSSIGNOL)',
        '로체스 (ROCES)',
        '반디어 (VAN DEER)',
        '보그너 (BOGNER)',
        '뵐클 (VOLKL)',
        '블리자드 (BLIZZARD)',
        '살로몬 (SALOMON)',
        '스톡클리 (STOCKLI)',
        '아토믹 (ATOMIC)',
        '엘란 (ELAN)',
        '오가사카 (OGASAKA)',
        '인라인스키 (INLINE SKI)',
        '테크니카 (TECNICA)',
        '피셔 (FISCHER)',
        '헤드 (HEAD)',
        '기타 (ETC)',
      ],
      inputType: AttributeInputType.searchSelect,
    ),
    ATTR_BRAND_BOARD: const AttributeDefinition(
      label: '브랜드',
      options: [
        '공일일 (011)',
        '그레이 (GRAY)',
        '나이트로 (NITRO)',
        '나이트로 스텝온 (NITRO STEP ON)',
        '노벰버 (NOVEMBER)',
        '니데커 (NIDECKER)',
        '데스라벨 (DEATHLABEL)',
        '드레이크 (DRAKE)',
        '라이드 (RIDE)',
        '라이스28 (RICE 28)',
        '롬 (ROME)',
        '바탈레온 (BATALEON)',
        '버튼 (BURTON)',
        '버튼 스텝온 (BURTON STEP-ON)',
        '비씨스트림 (BC STREAM)',
        '살로몬 (SALOMON)',
        '스쿠터 (SCOOTER)',
        '스프레드 (SPREAD)',
        '써리투 페이즈 (32 PHASE)',
        '앰플리드 (AMPLID)',
        '에스피 바인딩 (SP BINDING)',
        '에이벨 (AVEL)',
        '에프투 (F2)',
        '오가사카 (OGASAKA)',
        '요넥스 (YONEX)',
        '유니버설칸트 (UNIVERSAL CANT)',
        '유니온 (UNION)',
        '유니온 스텝온 (UNION STEP-ON)',
        '존스 (JONES)',
        '존스 페이즈 (JONES PHASE)',
        '캐피타 (CAPITA)',
        '케슬러 (KESSLER)',
        '케이투 (K2)',
        '크루자 (CROOJA)',
        '클루 (CLEW)',
        '플럭스 (FLUX)',
        '플럭스 스텝온 (FLUX STEP-ON)',
        '기타 (ETC)',
      ],
      inputType: AttributeInputType.searchSelect,
    ),
    ATTR_BRAND_APPAREL: const AttributeDefinition(
      label: '브랜드',
      options: [
        '골드버그 (GOLDBERGH)',
        '다이네즈 (DAINESE)',
        '데상트 (DESCENTE)',
        '디디디 (D1D1D1)',
        '디미토 (DIMITO)',
        '로시뇰 (ROSSIGNOL)',
        '로이쉬 (REUSCH)',
        '말로야 (MALOJA)',
        '미즈노 (MIZUNO)',
        '밀레 (MILLET)',
        '버튼 (BURTON)',
        '버튼 AK (BURTON[AK])',
        '보그너 (BOGNER)',
        '볼컴 (VOLCOM)',
        '볼컴 고어텍스 (VOLCOM GORE)',
        '블렌트 (BLENT)',
        '비에스래빗 (BSRABBIT)',
        '쁘아블랑 (POIVREBLANC)',
        '스페셜게스트 (SPECIALGUEST)',
        '앤쓰리 (NNN)',
        '어스투 (EARTH TO)',
        '에어블라스터 (AIRBLASTER)',
        '엘나스 (ELNATH)',
        '엘원 (L1)',
        '오비오 (OVYO)',
        '오클리 (OAKLEY)',
        '오클리 스키 (OAKLEY SKI)',
        '온요네 (ONYONE)',
        '요비트 (YOBEAT)',
        '윈 (UYN)',
        '육팔육 (686)',
        '제스트 (XEST)',
        '카레타 (KARETA)',
        '콜마 (COLMAR)',
        '큐마일 (QMILE)',
        '파이어아이스 (FIRE+ICE)',
        '퓨잡 (FUSALP)',
        '피닉스 (PHENIX)',
        '피셔 (FISCHER)',
        '헬로우 (HELLOW)',
        '기타 (ETC)',
      ],
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

  static List<String> getFilterProfile(String category, String subCategory) {
    final key = '$category/$subCategory';
    return filterProfiles[key] ?? const [];
  }

  static String? getTokenKeyForAttribute(String attributeKey) {
    return filterTokenKeyByAttribute[attributeKey];
  }

  static bool isLengthAttribute(String attributeKey) {
    return attributeKey == ATTR_LENGTH_SKI || attributeKey == ATTR_LENGTH_BOARD;
  }
}

class TradeLocationConstants {
  static const List<String> resorts = [
    '하이원',
    '용평',
    '휘닉스',
    '웰리힐리',
    '오투',
    '지산',
    '곤지암',
    '무주',
    '에덴밸리',
    '기타',
  ];
}
