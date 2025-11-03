extends Node

# ⚔️ 전투 관련 속성 열거형 (Enum)

# 무기 타입 (사이버펑크 세계관)
enum WeaponType {
	# 기본 무기군
	SWORD,      # 검
	DAGGER,     # 단검
	SPEAR,      # 창
	MACE,       # 메이스
	BOW,        # 활
	STAFF,      # 지팡이
	WRENCH,     # 렌치
	FISTS,      # 주먹
	SMG,        # 기관단총
	
	# 사이버펑크 무기군 (추가 예정)
	PLASMA_RIFLE,    # 플라즈마 라이플
	ENERGY_SWORD,    # 에너지 검
	NEURAL_WHIP,     # 신경 채찍
	QUANTUM_BLADE,   # 양자 블레이드
	CYBER_CLAW,      # 사이버 클로
	HOLOGRAM_BOW,    # 홀로그램 활
	MAGNETIC_HAMMER, # 자기 해머
	SONIC_CANNON,    # 음파 캐논
	LASER_PISTOL,    # 레이저 피스톨
	SHOCK_BATON      # 전기봉
}

# 물리 속성
enum PhysicalAttribute {
	NONE,
	SLASH,  # 베기
	PIERCE, # 찌르기
	BLUNT   # 타격
}

# 원소 속성
enum ElementalAttribute {
	NONE,
	FIRE,   # 화염
	ELEC,   # 전기
	FROST   # 서리
}

# 🔧 다중 속성 지원을 위한 유틸리티 함수들 (하위 호환성 보장)

## 단일 속성을 배열로 변환 (하위 호환성)
func single_to_array_physical(attribute: PhysicalAttribute) -> Array[PhysicalAttribute]:
	if attribute == PhysicalAttribute.NONE:
		return []
	return [attribute]

func single_to_array_elemental(attribute: ElementalAttribute) -> Array[ElementalAttribute]:
	if attribute == ElementalAttribute.NONE:
		return []
	return [attribute]

## 배열을 단일 속성으로 변환 (첫 번째 요소 반환)
func array_to_single_physical(attributes: Array[PhysicalAttribute]) -> PhysicalAttribute:
	if attributes.is_empty():
		return PhysicalAttribute.NONE
	return attributes[0]

func array_to_single_elemental(attributes: Array[ElementalAttribute]) -> ElementalAttribute:
	if attributes.is_empty():
		return ElementalAttribute.NONE
	return attributes[0]

## 공격 객체에서 속성 추출 (다중/단일 모두 지원)
func extract_physical_attributes(attack_object) -> Array[PhysicalAttribute]:
	# 다중 속성 우선 확인
	if "physical_attributes" in attack_object and not attack_object.physical_attributes.is_empty():
		return attack_object.physical_attributes
	
	# 단일 속성 fallback (타입 체크 및 변환)
	if "physical_attribute" in attack_object:
		var phys_attr = attack_object.physical_attribute
		if typeof(phys_attr) == TYPE_STRING:
			phys_attr = string_to_physical_attribute(phys_attr)
		if phys_attr != PhysicalAttribute.NONE:
			return [phys_attr]
	
	return []

func extract_elemental_attributes(attack_object) -> Array[ElementalAttribute]:
	# 다중 속성 우선 확인
	if "elemental_attributes" in attack_object and not attack_object.elemental_attributes.is_empty():
		return attack_object.elemental_attributes
	
	# 단일 속성 fallback (타입 체크 및 변환)
	if "elemental_attribute" in attack_object:
		var elem_attr = attack_object.elemental_attribute
		if typeof(elem_attr) == TYPE_STRING:
			elem_attr = string_to_elemental_attribute(elem_attr)
		if elem_attr != ElementalAttribute.NONE:
			return [elem_attr]
	
	return []

## 속성 이름을 문자열로 변환 (UI 표시용)
func physical_attribute_to_string(attribute: PhysicalAttribute) -> String:
	match attribute:
		PhysicalAttribute.SLASH: return "베기"
		PhysicalAttribute.PIERCE: return "찌르기"
		PhysicalAttribute.BLUNT: return "타격"
		_: return ""

func elemental_attribute_to_string(attribute: ElementalAttribute) -> String:
	match attribute:
		ElementalAttribute.FIRE: return "화염"
		ElementalAttribute.ELEC: return "전기"
		ElementalAttribute.FROST: return "서리"
		_: return ""

## 속성 배열을 문자열로 변환 (UI 표시용)
func attributes_to_string(physical_attrs: Array[PhysicalAttribute], elemental_attrs: Array[ElementalAttribute]) -> String:
	var result_parts: Array[String] = []
	
	for attr in physical_attrs:
		var attr_str = physical_attribute_to_string(attr)
		if attr_str != "":
			result_parts.append(attr_str)
	
	for attr in elemental_attrs:
		var attr_str = elemental_attribute_to_string(attr)
		if attr_str != "":
			result_parts.append(attr_str)
	
	return ", ".join(result_parts)

## 문자열을 enum으로 변환하는 유틸리티 함수들
func string_to_physical_attribute(attr_string: String) -> PhysicalAttribute:
	match attr_string.to_upper():
		"SLASH": return PhysicalAttribute.SLASH
		"PIERCE": return PhysicalAttribute.PIERCE
		"BLUNT": return PhysicalAttribute.BLUNT
		_: return PhysicalAttribute.NONE

func string_to_elemental_attribute(attr_string: String) -> ElementalAttribute:
	match attr_string.to_upper():
		"FIRE": return ElementalAttribute.FIRE
		"ELEC": return ElementalAttribute.ELEC
		"FROST": return ElementalAttribute.FROST
		_: return ElementalAttribute.NONE

## 무기 타입 관련 유틸리티 함수들
func get_weapon_type(weapon_name: String) -> WeaponType:
	"""무기 이름을 WeaponType enum으로 변환"""
	match weapon_name.to_lower():
		# 기본 무기군
		"sword", "검", "blade":
			return WeaponType.SWORD
		"dagger", "단검", "knife":
			return WeaponType.DAGGER
		"spear", "창", "lance":
			return WeaponType.SPEAR
		"mace", "메이스", "hammer":
			return WeaponType.MACE
		"bow", "활", "archery":
			return WeaponType.BOW
		"staff", "지팡이", "wand":
			return WeaponType.STAFF
		"wrench", "렌치", "spanner":
			return WeaponType.WRENCH
		"fists", "주먹", "unarmed", "맨손":
			return WeaponType.FISTS
		"smg", "기관단총", "submachine_gun", "machine_pistol":
			return WeaponType.SMG
		
		# 사이버펑크 무기군
		"plasma_rifle", "플라즈마라이플", "플라즈마_라이플":
			return WeaponType.PLASMA_RIFLE
		"energy_sword", "에너지검", "에너지_검":
			return WeaponType.ENERGY_SWORD
		"neural_whip", "신경채찍", "신경_채찍":
			return WeaponType.NEURAL_WHIP
		"quantum_blade", "양자블레이드", "양자_블레이드":
			return WeaponType.QUANTUM_BLADE
		"cyber_claw", "사이버클로", "사이버_클로":
			return WeaponType.CYBER_CLAW
		"hologram_bow", "홀로그램활", "홀로그램_활":
			return WeaponType.HOLOGRAM_BOW
		"magnetic_hammer", "자기해머", "자기_해머":
			return WeaponType.MAGNETIC_HAMMER
		"sonic_cannon", "음파캐논", "음파_캐논":
			return WeaponType.SONIC_CANNON
		"laser_pistol", "레이저피스톨", "레이저_피스톨":
			return WeaponType.LASER_PISTOL
		"shock_baton", "전기봉", "전기_봉":
			return WeaponType.SHOCK_BATON
		
		_:
			return WeaponType.FISTS  # 기본값

func weapon_type_to_string(weapon_type: WeaponType) -> String:
	"""무기 타입을 문자열로 변환 (UI 표시용)"""
	match weapon_type:
		# 기본 무기군
		WeaponType.SWORD: return "검"
		WeaponType.DAGGER: return "단검"
		WeaponType.SPEAR: return "창"
		WeaponType.MACE: return "메이스"
		WeaponType.BOW: return "활"
		WeaponType.STAFF: return "지팡이"
		WeaponType.WRENCH: return "렌치"
		WeaponType.FISTS: return "주먹"
		WeaponType.SMG: return "기관단총"
		
		# 사이버펑크 무기군
		WeaponType.PLASMA_RIFLE: return "플라즈마 라이플"
		WeaponType.ENERGY_SWORD: return "에너지 검"
		WeaponType.NEURAL_WHIP: return "신경 채찍"
		WeaponType.QUANTUM_BLADE: return "양자 블레이드"
		WeaponType.CYBER_CLAW: return "사이버 클로"
		WeaponType.HOLOGRAM_BOW: return "홀로그램 활"
		WeaponType.MAGNETIC_HAMMER: return "자기 해머"
		WeaponType.SONIC_CANNON: return "음파 캐논"
		WeaponType.LASER_PISTOL: return "레이저 피스톨"
		WeaponType.SHOCK_BATON: return "전기봉"
		
		_: return "알 수 없음"

func get_weapon_category(weapon_type: WeaponType) -> String:
	"""무기 타입을 카테고리로 분류"""
	match weapon_type:
		# 근접 무기
		WeaponType.SWORD, WeaponType.DAGGER, WeaponType.SPEAR, WeaponType.MACE, WeaponType.WRENCH, WeaponType.FISTS:
			return "근접"
		WeaponType.ENERGY_SWORD, WeaponType.NEURAL_WHIP, WeaponType.QUANTUM_BLADE, WeaponType.CYBER_CLAW, WeaponType.MAGNETIC_HAMMER, WeaponType.SHOCK_BATON:
			return "사이버 근접"
		
		# 원거리 무기
		WeaponType.BOW, WeaponType.SMG:
			return "원거리"
		WeaponType.PLASMA_RIFLE, WeaponType.HOLOGRAM_BOW, WeaponType.SONIC_CANNON, WeaponType.LASER_PISTOL:
			return "사이버 원거리"
		
		# 마법 무기
		WeaponType.STAFF:
			return "마법"
		
		_: return "기타"


# 📊 충돌 레이어 및 마스크 상수
# 출처: COLLISION_SYSTEM_DOCUMENTATION.md

# Collision Layers
const LAYER_WORLD = 1          # 2^0
const LAYER_PLAYER = 2         # 2^1
const LAYER_ENEMY = 4          # 2^2
const LAYER_PLAYER_ATTACK = 8  # 2^3
const LAYER_ENEMY_ATTACK = 16  # 2^4
const LAYER_PLAYER_HURTBOX = 32 # 2^5
const LAYER_ENEMY_HURTBOX = 64  # 2^6
const LAYER_DETECTION = 128     # 2^7
const LAYER_COLLECTIBLE = 256   # 2^8
const LAYER_PROJECTILE = 512    # 2^9

# Collision Masks (자주 사용하는 조합)
const MASK_PLAYER_VS_WORLD = LAYER_WORLD
const MASK_ENEMY_VS_WORLD_AND_ENEMY = LAYER_WORLD | LAYER_ENEMY
const MASK_PLAYER_ATTACK_VS_ENEMY = LAYER_ENEMY_HURTBOX
const MASK_ENEMY_ATTACK_VS_PLAYER = LAYER_PLAYER_HURTBOX
const MASK_PLAYER_HURTBOX_VS_ENEMY = LAYER_ENEMY_ATTACK
const MASK_ENEMY_HURTBOX_VS_PLAYER = LAYER_PLAYER_ATTACK
const MASK_DETECTION_VS_CHARS = LAYER_PLAYER | LAYER_ENEMY
const MASK_COLLECTIBLE_VS_PLAYER = LAYER_PLAYER
const MASK_PROJECTILE_VS_WORLD = LAYER_WORLD 
