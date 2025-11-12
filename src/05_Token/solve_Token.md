# Token Contract 취약점 분석 (Underflow / Integer Wrap)

## 개요

이 레벨의 목표는 기본 토큰 계약에서 **주어진 20 토큰보다 더 많은 토큰을 손에 넣어 레벨을 달성**하는 것입니다. 본 문서는 문제 원리(언더플로우/정수 랩), 재현 절차(명령 예시 포함), 결과와 간단한 완화책을 이해하기 쉽게 정리한 요약입니다.

---

## 취약점 핵심 요약

* Solidity 0.6.0 환경의 토큰 컨트랙트는 `balances[msg.sender]`와 `_value`를 `uint256`으로 사용합니다.
* `transfer` 함수의 `require(balances[msg.sender] - _value >= 0)` 체크는 의미가 없습니다. `uint256`은 음수를 표현하지 못하므로 `balances[msg.sender] - _value`가 음수가 될 경우 **언더플로우(underflow)** 가 발생해 큰 양수로 래핑됩니다.
* 결과적으로 `_value`가 현재 잔고보다 클 때에도 `require`는 True가 되고, 실제로는 `balances[msg.sender]`가 큰 값(2^256 - 1 등)으로 바뀌어 잔고를 마음대로 증가시킬 수 있습니다.

---

## 취약점 동작 원리 (간단 예)

1. 초기 잔고: `balances[msg.sender] = 20`.
2. `_value = 21`로 `transfer` 호출 시 `balances[msg.sender] - _value`는 언더플로우하여 `2^256 - 1`(최대값)로 변합니다.
3. `balances[msg.sender] -= _value` 실행 뒤, `balances[msg.sender]`는 매우 큰 수가 되어 해당 계정이 대량의 토큰을 보유하게 됩니다.

---

## 재현(실제 사용한 명령 예시)

Foundry의 `cast`를 이용한 전송 예:

```bash
cast send <TOKEN_ADDRESS> \
  --rpc-url <RPC_URL> \
  --private-key $PRIVATE_KEY \
  "transfer(address,uint256)" <MY_ADDRESS> 21
```

트랜잭션이 성공하면 `balanceOf`를 호출해 잔고가 `0xffff...ffff`(uint256 최대값)으로 바뀐 것을 확인할 수 있습니다.

---

## 결과와 의의

* 공격자는 아주 작은 값(예: 21)을 전송했을 뿐인데 계정의 잔고가 엄청나게 증가합니다. 이로써 문제 레벨을 달성할 수 있으며, 실제 환경에서는 토큰 공급 불균형, 부정 이득 등의 심각한 문제를 초래합니다.

---

## 완화책(권장)

1. **Solidity 0.8.0 이상으로 컴파일**: 산술 오버플로/언더플로에 대해 자동으로 체크되어 revert됩니다.
2. **SafeMath 사용**(구버전 사용 시): 덧셈/뺄셈 시 체크를 추가합니다.
3. `require(balances[msg.sender] >= _value)` 형태로 의미있는 조건문 작성.
4. 추가 검사: 전송 시 0값/초과값 처리 로직 강화, 단위 테스트에 언더플로·오버플로 케이스 포함.

---

## 참고

* 언더플로/오버플로 취약점은 스마트컨트랙트에서 매우 흔한 실수이며, 작은 실수 하나로도 심각한 자금 손실로 이어질 수 있습니다.

---

