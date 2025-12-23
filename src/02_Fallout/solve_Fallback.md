# 문제 확인 — 소유권 획득(요점 정리)

목표

1. 컨트랙트의 오너쉽(소유권)을 가져오면 성공

설명

함수 코드를 보면 함수가 여러 개 있는데 그 중 `collectAllocations`는 `onlyOwner`를 걸고 있고 나머지 함수는 그렇진 않다. 이 문제의 요점은 컨트랙트의 소유권을 가져오는 것인데

현재 컨트랙트의 소유권을 불러오는 곳은 `Fal1out`이라는 함수를 호출하면 자동으로 `owner`에 트랜잭션 호출자(`msg.sender`)가 대입되어 트랜잭션 호출자가 오너가 되는 구조다.

`Fal1out`을 부르기만 하면 되고 아무런 제약 조건이 없기 때문에 foundry를 사용해 바로 보내보겠다.

```bash
cast send 0x37a3D3a978bd6fe4Db71e3b012B416d2402B4A1b \
  --rpc-url https://eth-sepolia.g.alchemy.com/v2/JRwGoQDFFeWbOe5_V5Ryk0XKPdavMRUA \
  --private-key $PRIVATE_KEY "Fal1out()"
```

설명(이 커맨드의 의미)

이렇게 보내게 되면 `contract` 인스턴스 주소인 `0x37a3D3a978bd6fe4Db71e3b012B416d2402B4A1b`에 나의 `PRIVATE_KEY`를 사용해 가스비를 내며 상태를 변경시키게 된다. 마지막은 해당 인스턴스에 `Fal1out` 함수를 호출하겠다는 명령어이고, 이것을 하면 `owner` 변수에 나의 EOA가 들어가게 된다. (해당 컨트랙트를 호출한 주체가 나의 EOA이기 때문 — 나의 private key로 서명했으므로 트랜잭션의 `msg.sender`는 내 EOA가 됨)

호출이 되면 곧바로 이더넛 페이지(콘솔)로 돌아와서

```javascript
await contract.owner()
```

를 치게 되면 나의 EOA가 해당 컨트랙트의 오너가 된 것을 알 수 있다.

포인트 1

`Fal1out`을 매개변수 없이 호출만 하는 것이라 해도 어쨌든 `owner`가 변경되는 해당 컨트랙트에 상태가 변경되는 것이다. 즉, `cast call`로 호출만 하면 안 되고, `cast send`를 통해 가스비를 내고 직접 트랜잭션을 날려야 한다.

포인트 2

`await contract.owner()`라는 개발자도구 console에서 확인하는 방법 말고 foundry로 보고 싶다면 아래처럼 실행할 수 있다:

```bash
cast call $INSTANCE_ADDR "owner()(address)" --rpc-url $RPC_URL
```

이때 `INSTANCE_ADDR`은 내가 call 하려는 컨트랙트 인스턴스 주소 그 자체이며, `owner()(address)`는 해당 컨트랙트의 `owner()` getter를 호출해 주소를 반환한다.

포인트 3 — owner() 함수는 컨트랙트에 항상 내장되어 있나?

`owner()`는 솔리디티 내장 함수가 아니다. 직접 정의해야 한다. 일반적으로는 OpenZeppelin의 `Ownable`을 상속하면 `owner()` getter가 자동으로 제공된다.

예시:

```solidity
import "@openzeppelin/contracts/access/Ownable.sol";

contract MyLevel is Ownable {
    // Ownable 로부터 상속된 owner 주소는 배포 시점에 msg.sender로 자동 설정됨
    // 그리고 owner() 라는 getter 함수(읽기 전용)가 자동으로 제공됨
}
```

이렇게 정의하면 `cast call $INSTANCE_ADDR "owner()(address)" --rpc-url $RPC_URL`로 호출했을 때 `owner()`가 반환된다.

<!-- Removed informal closing per request -->
