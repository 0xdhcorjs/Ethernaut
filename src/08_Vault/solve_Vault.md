# Vault 컨트랙트 취약점 분석 및 풀이

## 개요

이 레벨은 배포된 `Vault` 컨트랙트의 `locked` 상태를 `false`로 바꿔 금고를 열어야 합니다. 컨트랙트는 생성자에서 `bytes32 password`를 받아 `password`에 저장하고, 외부에서 `unlock(bytes32)` 호출로 전달된 값과 동일하면 `locked = false`로 바뀝니다.

문제 포인트는 `password`가 `private`로 선언되어 있어도 블록체인에 평문으로 저장되므로, 컨트랙트 생성 트랜잭션(또는 스토리지 상태)을 통해 누구나 확인할 수 있다는 점입니다. 따라서 생성자 인자(또는 스토리지)를 확인하여 `password`를 찾아 `unlock`에 전달하면 문제를 풀 수 있습니다.

---

## 대상 코드

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Vault {
    bool public locked;
    bytes32 private password;

    constructor(bytes32 _password) {
        locked = true;
        password = _password;
    }

    function unlock(bytes32 _password) public {
        if (password == _password) {
            locked = false;
        }
    }
}
```

---

## 취약점 요약

* `password`는 `private`로 선언되어 있지만, 이 값은 컨트랙트 배포 시 블록체인에 저장된다.
* 블록 익스플로러(Etherscan 등)에서 해당 컨트랙트의 생성 트랜잭션이나 State 탭을 보면 생성자에 전달된 `_password` 값을 확인할 수 있다.
* 이 값을 그대로 `unlock(bytes32)`에 전달하면 `locked`가 `false`가 되어 금고가 열린다.

---

## 해결(공격) 절차

1. **컨트랙트 주소 확인**: 문제 인스턴스(배포된 컨트랙트) 주소를 확보합니다.
2. **Etherscan에서 생성 트랜잭션 조회**: 컨트랙트 페이지에서 생성 트랜잭션(Contract Creation)을 클릭합니다.
3. **State 또는 Input 확인**: 트랜잭션 상세의 `State` 탭이나 생성자 `Input`에서 `_password`에 해당하는 값(예: `0x41207665...`)을 찾습니다.
4. **unlock 호출**: 찾은 `bytes32` 값을 `unlock`의 인자로 보내는 트랜잭션을 날립니다.

예시(Foundry `cast` 사용):

```bash
cast send <VAULT_ADDRESS> \
  --rpc-url <RPC_URL> \
  --private-key $PRIVATE_KEY \
  "unlock(bytes32)" 0x412076657279207374726f6e67207365637265742070617373776f7264203a29
```

위 예시에서 마지막 인자가 생성 트랜잭션에서 확인한 `_password`입니다.

---

## 실습 시 주의사항

* `unlock` 인자는 `bytes32` 타입이므로, 입력 형식이 정확해야 합니다. 문자열을 직접 넣을 경우 적절히 `bytes32`로 인코딩해야 합니다.
* 트랜잭션 전송 후 Etherscan에서 `locked` 상태(`locked()` 호출 결과)를 확인하여 `false`로 변경되었는지 검증하세요.

---

## 보안적 고찰

* `private` 키워드는 외부 컨트랙트로부터의 접근을 제한할 뿐, 블록체인에 저장된 상태는 누구나 읽을 수 있습니다. 따라서 비밀(plain-secret)을 온체인에 그대로 저장하면 안 됩니다.
* 민감한 데이터는 **온체인에 저장하기 전에 암호화**하거나, 온체인에 전혀 노출하지 않는 설계를 사용해야 합니다. 예: 해시(해시 비교)로 검증하거나, 영지식증명(zk-SNARKs) 등 오프체인 비밀을 드러내지 않는 방법을 고려해야 합니다.

---

## 요약

* 취약점 원인: 생성자 인자로 들어간 `password`가 블록체인 스토리지에 평문으로 남아 누구나 열람 가능함.
* 해결법: 컨트랙트 생성 트랜잭션에서 `_password`를 확인 → `unlock(bytes32)`로 전달 → `locked = false`로 변경.
* 보안 권고: 비밀값은 온체인에 그대로 남기지 말고 암호화/오프체인 검증 방법을 사용하라.


