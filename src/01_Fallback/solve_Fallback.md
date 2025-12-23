## Fallback함수

: fallback 함수는 컨트랙트에 정의되어 있지 않은 함수가 호출될 경우 자동으로 호출되는 함수 입니다. 예를 들어, 계정 간의 이더를 전송하는 transfer 함수를 컨트랙트를 대상으로 실행했을 때 이는 컨트랙트 내부에 정의된 함수가 아닌 외부 함수이기 때문에 fallback 함수가 실행됩니다. 

fallback 함수에는 fallback, receive 두 가지가 존재하는데, 메시지에 데이터(calldata)가 담겨 있으면 fallback이 호출되고, 비어있으면 receive가 호출되는 정도의 차이를 가지고 있습니다. 

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Fallback {
    mapping(address => uint256) public contributions;
    address public owner;

    constructor() {
        owner = msg.sender;
        contributions[msg.sender] = 1000 * (1 ether);
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "caller is not the owner");
        _;
    }

    function contribute() public payable {
        require(msg.value < 0.001 ether);
        contributions[msg.sender] += msg.value;
        if (contributions[msg.sender] > contributions[owner]) {
            owner = msg.sender;
        }
    }

    function getContribution() public view returns (uint256) {
        return contributions[msg.sender];
    }

    function withdraw() public onlyOwner {
        payable(owner).transfer(address(this).balance);
    }

    receive() external payable {
        require(msg.value > 0 && contributions[msg.sender] > 0);
        owner = msg.sender;
    }
}
```

위는 문제 코드이다.

두 가지 조건을 만족하면 클리어.

1. 컨트렉트의 오너가 된다. 
2. 컨트렉트의 잔고를 0으로 만든다.

코드 전체에서 오너쉽을 획득할 수 있는 부분은 2곳입니다. 

첫 번째는 `contribute` 함수에서 `contributions` 수량이 기존의 오너보다 많으면 오너쉽을 획득할 수 있다.

두 번째는 `receive` 함수에서 보면 보낸 사람의 `contributions` 수량이 0보다 크고 보낸 금액이 0보다 크면 `owner`를 넘겨준다.

하지만 아래 생성자에 의해 시작부터 오너는 contribution 수량이 1000 이더이기 때문에 첫번째 방법으로 오너쉽을 획득하는 것은 불가능해보인다.

```solidity
constructor() public {
  owner = msg.sender;
  contributions[msg.sender] = 1000 * (1 ether);
}
```

두 번째 방법을 살펴보자면
1) ABI를 통해 `contributions`가 0보다 크다는 조건을 만족시키고
2) ABI를 거치지 않고 컨트랙트에 송금하면 이 계약의 `owner`가 될 수 있을 것이다.

```solidity
receive() external payable {
  require(msg.value > 0 && contributions[msg.sender] > 0);
  owner = msg.sender;
}
```

이제 오너십을 위해 컨트렉트 인스턴스를 생성하고 `contribute` ABI로 약간의 이더를 보내보자.

코드를 보면 0.001 이더보다 작게 보내야 `require`를 통과한다.

```solidity
function contribute() public payable {
  require(msg.value < 0.001 ether);
  contributions[msg.sender] += msg.value;
  if(contributions[msg.sender] > contributions[owner]) {
    owner = msg.sender;
  }
}
```

Foundry를 이용하기 때문에 Foundry 명령어를 사용해보겠다.

```bash
cast send <CONTRACT_ADDRESS> --rpc-url https://eth-sepolia.g.alchemy.com/v2/<ALCHEMY_KEY> --private-key $PRIVATE_KEY "contribute()" --value 0.0009ether
```

or 콘솔(개발자도구)로 보낸다면 (수수료는 따로 지불됩니다)

```javascript
await contract.contribute({ value: ethers.utils.parseEther("0.0009") })
```

```javascript
await contract.getContribution()
```

이제 첫번째 조건은 만족했다. 그럼 `receive` 함수를 실행시키기 위해 이 컨트랙트에 바로 이더를 송금해보자. 먼저 컨트랙트의 주소를 알아내기 위해 콘솔에 `contract`를 입력한다. 

메타마스크(또는 같은 EOA)로 이 주소에 이더를 보내면 `receive()`가 실행되고, `owner`가 공격자 계정으로 바뀝니다. 예시로 0.001 ETH를 보내면 충분합니다(수수료 별도).

트랜잭션이 컨펌되고 나면 다음과 같이 소유권을 확인합니다.

```javascript
await contract.owner()
```

소유권이 넘어왔다면 `withdraw()` 함수로 이더 잔액을 모두 인출합니다.

문제 클리어.
