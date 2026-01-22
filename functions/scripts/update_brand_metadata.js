const admin = require("firebase-admin");

admin.initializeApp();

const db = admin.firestore();

const boardBrands = [
  "공일일 (011)",
  "그레이 (GRAY)",
  "나이트로 (NITRO)",
  "나이트로 스텝온 (NITRO STEP ON)",
  "노벰버 (NOVEMBER)",
  "니데커 (NIDECKER)",
  "데스라벨 (DEATHLABEL)",
  "드레이크 (DRAKE)",
  "라이드 (RIDE)",
  "라이스28 (RICE 28)",
  "롬 (ROME)",
  "바탈레온 (BATALEON)",
  "버튼 (BURTON)",
  "버튼 스텝온 (BURTON STEP-ON)",
  "비씨스트림 (BC STREAM)",
  "살로몬 (SALOMON)",
  "스쿠터 (SCOOTER)",
  "스프레드 (SPREAD)",
  "써리투 페이즈 (32 PHASE)",
  "앰플리드 (AMPLID)",
  "에스피 바인딩 (SP BINDING)",
  "에이벨 (AVEL)",
  "에프투 (F2)",
  "오가사카 (OGASAKA)",
  "요넥스 (YONEX)",
  "유니버설칸트 (UNIVERSAL CANT)",
  "유니온 (UNION)",
  "유니온 스텝온 (UNION STEP-ON)",
  "존스 (JONES)",
  "존스 페이즈 (JONES PHASE)",
  "캐피타 (CAPITA)",
  "케슬러 (KESSLER)",
  "케이투 (K2)",
  "크루자 (CROOJA)",
  "클루 (CLEW)",
  "플럭스 (FLUX)",
  "플럭스 스텝온 (FLUX STEP-ON)",
  "기타 (ETC)",
];

const skiBrands = [
  "노르디카 (NORDICA)",
  "다이나스타 (DYNASTAR)",
  "달벨로 (DALBELLO)",
  "랑게 (LANGE)",
  "로시뇰 (ROSSIGNOL)",
  "로체스 (ROCES)",
  "반디어 (VAN DEER)",
  "보그너 (BOGNER)",
  "뵐클 (VOLKL)",
  "블리자드 (BLIZZARD)",
  "살로몬 (SALOMON)",
  "스톡클리 (STOCKLI)",
  "아토믹 (ATOMIC)",
  "엘란 (ELAN)",
  "오가사카 (OGASAKA)",
  "인라인스키 (INLINE SKI)",
  "테크니카 (TECNICA)",
  "피셔 (FISCHER)",
  "헤드 (HEAD)",
  "기타 (ETC)",
];

const apparelBrands = [
  "골드버그 (GOLDBERGH)",
  "다이네즈 (DAINESE)",
  "데상트 (DESCENTE)",
  "디디디 (D1D1D1)",
  "디미토 (DIMITO)",
  "로시뇰 (ROSSIGNOL)",
  "로이쉬 (REUSCH)",
  "말로야 (MALOJA)",
  "미즈노 (MIZUNO)",
  "밀레 (MILLET)",
  "버튼 (BURTON)",
  "버튼 AK (BURTON[AK])",
  "보그너 (BOGNER)",
  "볼컴 (VOLCOM)",
  "볼컴 고어텍스 (VOLCOM GORE)",
  "블렌트 (BLENT)",
  "비에스래빗 (BSRABBIT)",
  "쁘아블랑 (POIVREBLANC)",
  "스페셜게스트 (SPECIALGUEST)",
  "앤쓰리 (NNN)",
  "어스투 (EARTH TO)",
  "에어블라스터 (AIRBLASTER)",
  "엘나스 (ELNATH)",
  "엘원 (L1)",
  "오비오 (OVYO)",
  "오클리 (OAKLEY)",
  "오클리 스키 (OAKLEY SKI)",
  "온요네 (ONYONE)",
  "요비트 (YOBEAT)",
  "윈 (UYN)",
  "육팔육 (686)",
  "제스트 (XEST)",
  "카레타 (KARETA)",
  "콜마 (COLMAR)",
  "큐마일 (QMILE)",
  "파이어아이스 (FIRE+ICE)",
  "퓨잡 (FUSALP)",
  "피닉스 (PHENIX)",
  "피셔 (FISCHER)",
  "헬로우 (HELLOW)",
  "기타 (ETC)",
];

async function updateBrandMetadata() {
  const docRef = db.collection("metadata").doc("brands");
  const snapshot = await docRef.get();
  const data = snapshot.exists ? snapshot.data() : {};
  const version = typeof data.version === "number" ? data.version : 0;

  await docRef.set(
    {
      version: version + 1,
      brand_ski: skiBrands,
      brand_board: boardBrands,
      brand_apparel: apparelBrands,
    },
    { merge: true }
  );

  console.log(`브랜드 데이터 업데이트 완료 (version: ${version + 1}).`);
}

updateBrandMetadata().catch((error) => {
  console.error("브랜드 데이터 업데이트 실패:", error);
  process.exit(1);
});
