# portfolio-tinkerbolt
TinkerB0lt - Game System Architecture Portfolio

## 프로젝트 개요
Godot 4.4 기반 2D 액션 게임의 시스템 아키텍처 포트폴리오

**주의**: 이 레포지토리는 포트폴리오 목적이며, 전체 소스코드는 포함되어 있지 않습니다.


## 주요 시스템 설계

### 1. 상태 머신 시스템
- **설계 패턴**: State Machine Pattern
- **적용 범위**: 플레이어, 동료, 적 캐릭터
- **주요 특징**: 확장 가능한 구조, 명확한 상태 전환
- **예시 코드**: `examples/state_machine/`
- **상세 문서**: `docs/STATE_MACHINE_DESIGN.md`

### 2. 월드 관리 시스템
- **설계 패턴**: Factory Pattern, Registry Pattern
- **구성 요소**: WorldManager, WorldFactory, WorldRegistry
- **주요 특징**: 프로시저럴 생성 지원, 동적 로딩
- **예시 코드**: `examples/world_system/`
- **상세 문서**: `docs/WORLD_SYSTEM_ARCHITECTURE.md`

### 3. 동료 AI 시스템
- **AI 구조**: 행동 트리 + 상태 머신 하이브리드
- **주요 특징**: 실시간 상태 추적, 시그널 기반 통신
- **예시 코드**: `examples/companion_ai/`
- **상세 문서**: `docs/AI_SYSTEM_DESIGN.md`

### 4. 커스텀 에디터 플러그인
- **기술**: GraphEdit API, EditorPlugin
- **기능**: 노드 기반 다이얼로그 에디터
- **예시 코드**: `examples/dialogue_editor/`

## 📊 프로젝트 통계

- **총 코드 라인**: 10,000+ 줄 (전체 프로젝트)
- **커스텀 클래스**: 197개
- **에디터 플러그인**: 33개
- **주요 시스템**: 10+ 개
- **문서**: 30+ 개

## 🔧 기술 스택

- **엔진**: Godot 4.4
- **언어**: GDScript (strict typing)
- **패턴**: State Machine, Factory, Registry, Component-based
- **도구**: MCP, Cursor AI

## 📚 문서 구조

```
docs/
├── SPAWN_POINT_SYSTEM_GUIDE.md      # 스폰 포인트 시스템 설명
├── WORLD_SYSTEM_ARCHITECTURE.md # 월드 시스템 아키텍처
├── STATE_MACHINE_DESIGN.md #상태 머신 디자인
├── DIALOGUE_EDITOR_DESIGN.md # 다이얼로그 에디터 디자인
├── AI_SYSTEM_DESIGN.md # AI 시스템 디자인
```

## 🎯 주요 설계 원칙

1. **확장 가능성**: 새로운 기능 추가가 쉬운 구조
2. **유지보수성**: 명확한 책임 분리
3. **성능**: 효율적인 자원 관리
4. **테스트 용이성**: 모듈화된 설계

## ⚠️ 주의사항

이 레포지토리는 **포트폴리오 목적**입니다:
- 전체 소스코드는 포함되어 있지 않습니다
- 예시 코드의 일부만 제공됩니다
- 상업적 사용을 위한 완전한 구현은 아닙니다

전체 프로젝트는 Private 레포지토리에서 관리됩니다.

## 📄 License

포트폴리오 레포지토리의 예시 코드와 문서는 다음 라이선스로 제공됩니다:

```
Copyright (c) 2024 [Ikju Kwon]

이 레포지토리의 내용은 포트폴리오 목적으로만 제공됩니다.
코드 사용이나 참고 시 출처를 명시해주세요.
상업적 사용은 제한될 수 있습니다.
```

## 📞 연락처

포트폴리오 관련 문의나 질문이 있으시면 GitHub Issues를 통해 연락해주세요.

---

**포트폴리오 레포지토리** | 전체 프로젝트는 Private 레포지토리에서 관리됩니다.
```

