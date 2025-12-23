# Signature Spoofing 수학적 증명

## 🧮 핵심 수학 원리

### ECDSA 검증 공식

```
u1 = e / s mod n
u2 = r / s mod n
P = u1 * G + u2 * Q

검증 성공: P의 x좌표 mod n == r
```

### 우리의 공격: 역으로 계산하기

#### 1. 랜덤 값 선택
```
u1 = 랜덤 스칼라 (1 ~ n-1)
u2 = 랜덤 스칼라 (1 ~ n-1, 0이 아님)
```

#### 2. 점 P 계산
```
P = u1 * G + u2 * Q
r = P의 x좌표 mod n
```

#### 3. s 계산
```
u2Inv = u2의 역원 mod n
s = r * u2Inv mod n
```

#### 4. 해시 e 계산 (핵심!)
```
e = r * u1 * u2Inv mod n
```

### 증명: 왜 검증이 통과하는가?

컨트랙트가 실행하는 검증:

```
u1' = e / s mod n
u2' = r / s mod n
P' = u1' * G + u2' * Q
```

우리가 만든 값들을 대입해보면:

#### u1' 계산
```
u1' = e / s mod n
    = (r * u1 * u2Inv) / (r * u2Inv) mod n
    = (r * u1 * u2Inv) * (r * u2Inv)^(-1) mod n
    = (r * u1 * u2Inv) * (r^(-1) * u2) mod n
    = u1 * u2Inv * u2 mod n
    = u1 mod n
```

#### u2' 계산
```
u2' = r / s mod n
    = r / (r * u2Inv) mod n
    = r * (r * u2Inv)^(-1) mod n
    = r * (r^(-1) * u2) mod n
    = u2 mod n
```

#### P' 계산
```
P' = u1' * G + u2' * Q
   = u1 * G + u2 * Q
   = P
```

#### 최종 검증
```
P'의 x좌표 = P의 x좌표 = r
→ 검증 통과! ✅
```

## 📊 시각적 이해

```
정상적인 서명 생성:
[메시지] → [해시 e] → [비밀키 d] → [서명 (r, s)]
                              ↓
                         [공개키 Q]

공격 (역으로 계산):
[공개키 Q] → [랜덤 u1, u2] → [점 P] → [r, s] → [해시 e]
                                              ↓
                                         [amount로 사용]
```

## 🔑 핵심 포인트

1. **공개키만 알면 서명을 만들 수 있다?**
   - 일반적으로는 불가능 (비밀키 필요)
   - 하지만 **검증할 해시를 우리가 선택할 수 있으면** 가능!

2. **왜 해시를 선택할 수 있는가?**
   - `permit` 함수가 `bytes32(amount)`를 그대로 해시로 사용
   - `keccak256` 같은 추가 해싱이 없음
   - 따라서 `amount`를 조작하면 해시도 조작 가능

3. **수학적으로 가능한 이유**
   - ECDSA 검증 공식이 대칭적 구조
   - `u1`, `u2`를 먼저 선택하면 `e`, `r`, `s`를 계산 가능
   - 단, 검증할 해시(`e`)를 우리가 선택할 수 있어야 함

## ⚠️ 왜 일반적으로는 불가능한가?

일반적인 ECDSA 사용:
```solidity
bytes32 hash = keccak256(abi.encodePacked(message));
address signer = ECDSA.recover(hash, signature);
```

이 경우:
- `hash`는 `keccak256`의 결과 (예측 불가능)
- 우리가 원하는 해시를 만들 수 없음
- 따라서 공격 불가능

하지만 이 컨트랙트:
```solidity
address tokenOwner = ECDSA.recover(bytes32(amount), tokenOwnerSignature);
```

이 경우:
- `bytes32(amount)`는 단순 타입 변환
- `amount`를 조작하면 해시도 조작 가능
- 따라서 공격 가능!

