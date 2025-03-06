# อธิบายโค้ดที่ป้องกันการ lock เงินไว้ใน contract
```solidity
function exit() public {
    require(player_not_played[msg.sender] == false, "You must select the action first");
    require(timeUnit.elapsedMinutes() >= 1, "You must wait for at least 1 minute to exit from the contract");
    if (numCommit == 2) {
        require(numReveal == 1, "You must have revealed first");
    }
    
    address payable account0 = payable(msg.sender);
    account0.transfer(reward);

    _resetState();
}

function playerCommit(bytes32 dataHash) public {
    require(numPlayer == 2, "Must have 2 players before playing");
    require(player_not_played[msg.sender], "You have already selected");
    numCommit++;
    player_not_played[msg.sender] = false;
    commitReveal.commit(msg.sender, dataHash);
    timeUnit.setStartTime();
} 
```
- เมื่อผู้เล่นลงเงินใน contract ผู้เล่นจะถูก lock เงินไว้ใน contract ไม่สามารถ exit ได้ จนกว่าจะมีผู้เล่นอีกคนหนึ่งเข้ามา
- สังเกตที่ require() บรรทัดแรกของ exit() ที่จะแจ้งเตือนว่าต้องทำการเลือก action ก่อน และก่อนที่จะเลือก action ได้ ก็จะต้องมีผู้เล่น 2 คนเสียก่อน (ตามที่ require() บรรทัดแรกของ playerCommit() ระบุไว้)
- ดังนั้นจาก code จึงสามารถสรุปได้ว่าผู้เล่นจะถอนเงินออกได้ก็ต่อเมื่อมีผู้เล่นอีกคนเข้ามาใน contract เสียก่อนนั่นเอง

# อธิบายโค้ดส่วนที่ทำการซ่อน choice และ commit
```solidity
function getHash(bytes32 data) public view returns (bytes32) {
    bytes1 lastByte = bytes1(data[31]);
    require(lastByte == 0x00 || lastByte == 0x01 || lastByte == 0x02 || lastByte == 0x03 || lastByte == 0x04, "Invalid choice");       
    return commitReveal.getHash(data);
}

function playerCommit(bytes32 dataHash) public {
    require(numPlayer == 2, "Must have 2 players before playing");
    require(player_not_played[msg.sender], "You have already selected");
    numCommit++;
    player_not_played[msg.sender] = false;
    commitReveal.commit(msg.sender, dataHash);
    timeUnit.setStartTime();
}
```
- getHash() จะทำการ hashing data ที่ได้มาจากการนำ random bits concatenate กับ choice แล้ว return คืนกลับมาให้ผู้เล่น เพื่อนำไปทำการ commit ต่อ
- playerCommit() ก็จะทำการนำ dataHash ที่ได้มาจากการเรียกใช้ getHash() ส่งต่อให้กับ commitReveal.commit() เพื่อทำการ commit และบันทึกไว้ที่ตัวแปร commits (ในส่วนของ CommitReveal.sol) ดังนั้นเมื่อผู้เล่นอีกคนพยายามที่จะทำการ front-running เพื่อดูว่าผู้เล่นออก action อะไร ก็จะเห็นแต่ค่า hash ซึ่ง**ยากมาก ๆ** ที่จะตีความกลับไปเป็น choice ได้

# อธิบายโค้ดส่วนที่จัดการกับความล่าช้าที่ผู้เล่นไม่ครบทั้งสองคนเสียที
```solidity
function playerCommit(bytes32 dataHash) public {
    require(numPlayer == 2, "Must have 2 players before playing");
    require(player_not_played[msg.sender], "You have already selected");
    numCommit++;
    player_not_played[msg.sender] = false;
    commitReveal.commit(msg.sender, dataHash);
    timeUnit.setStartTime();
}

function playerReveal(bytes32 revealHash) public {
    require(numCommit == 2, "2 players must have commited first");
    commitReveal.reveal(msg.sender, revealHash);
    uint choice = uint8(revealHash[31]);
    player_choice[msg.sender] = choice;
    numReveal++;
    timeUnit.setStartTime();
    if (numReveal == 2) {
        _checkWinnerAndPay();
    }
}

function exit() public {
    require(player_not_played[msg.sender] == false, "You must select the action first");
    require(timeUnit.elapsedMinutes() >= 1, "You must wait for at least 1 minute to exit from the contract");
    if (numCommit == 2) {
        require(numReveal == 1, "You must have revealed first");
    }
    
    address payable account0 = payable(msg.sender);
    account0.transfer(reward);

    _resetState();
}
```
- ผู้เล่นจะ exit ได้นั้นมีทั้งหมด 2 กรณี นั่นคือ 1. ผู้เล่นทำการ commit แล้ว แต่ผู้เล่นอีกคนไม่ยอมทำการ commit เสียที 2. ผู้เล่นทำการ reveal แล้ว แต่ผู้เล่นอีกคนไม่ยอมทำการ reveal เสียที โดยจะให้ผู้เล่นรอเป็นเวลา 1 นาที ก่อนจะ exit จาก contract ได้
- timeUnit.setStartTime() ที่อยู่ใน playerCommit() และ playerReveal() มีไว้เพื่อทำการ reset countdown เพราะว่าเมื่อผู้เล่นทำการ commit หรือ reveal ก็จะทำการนับเวลาถอยหลังใหม่
- สำหรับใน exit(): require() แรกทำการบอกว่าผู้เล่นต้องเลือก action ก่อน (ทำการ commit) ส่วน require() ถัดมาบอกว่าต้องรอเป็นเวลาอย่างน้อย 1 นาทีก่อน แต่ถ้าหากผู้เล่นอีกคนทำการ commit หรือ reveal ก็จะ reset countdown สำหรับกรณีแรก (commit phase) หากผ่าน 2 เงื่อนไขนี้ก็จะ exit ได้ ส่วนกรณีที่ 2 (reveal phase) require() นั้นบอกว่า ผู้เล่นต้องทำการ reveal ก่อนถึงจะ exit ได้
  
# อธิบายโค้ดส่วนทำการ reveal และนำ choice มาตัดสินผู้ชนะ 
```solidity
function playerReveal(bytes32 revealHash) public {
    require(numCommit == 2, "2 players must have commited first");
    commitReveal.reveal(msg.sender, revealHash);
    uint choice = uint8(revealHash[31]);
    player_choice[msg.sender] = choice;
    numReveal++;
    timeUnit.setStartTime();
    if (numReveal == 2) {
        _checkWinnerAndPay();
    }
}

function _checkWinnerAndPay() private {
    uint p0Choice = player_choice[players[0]];
    uint p1Choice = player_choice[players[1]];
    address payable account0 = payable(players[0]);
    address payable account1 = payable(players[1]);
    if ((p0Choice + 1) % 5 == p1Choice || (p0Choice + 2) % 5 == p1Choice) {
        // to pay player[1]
        account1.transfer(reward);
    }
    else if ((p1Choice + 1) % 5 == p0Choice || (p1Choice + 2) % 5 == p0Choice) {
        // to pay player[0]
        account0.transfer(reward);    
    }
    else {
        // to split reward
        account0.transfer(reward / 2);
        account1.transfer(reward / 2);
    }
    _resetState();
}
```
- ในส่วนของ playerReveal() ผู้เล่นจะทำการส่ง revealHash (random bits concatenate กับ choice) มาให้ตรวจสอบ และ commitReveal.reveal() จะทำการตรวจสอบว่าเมื่อ hash มาแล้ว ได้ค่าที่ตรงกับค่าที่ commit ไปก่อนหน้านี้หรือเปล่า หากตรงก็จะทำการดึงตัวเลขตัวสุดท้ายของ revealHash ซึ่ง represent ถึง choice ที่ผู้เล่นได้เลือกในตอนแรก มาเก็บไว้ในตัวแปร player_choice
- ในส่วนของ _checkWinnerAndPay() ทำการดัดแปลงเล็กน้อย เนื่องจากมี choice เพิ่มขึ้นเป็น 5 choices ซึ่งจากเกม RPS version ใหม่: https://bigbangtheory.fandom.com/wiki/Rock,_Paper,_Scissors,_Lizard,_Spock จะได้ลำดับของ action 0 - Rock, 1 - Spock, 2 - Paper, 3 - Lizard, 4 - Scissors และ action ที่นำหน้าอยู่ 2 ลำดับจะเป็นฝ่ายชนะ จึงได้ if else condition ตาม code ที่แนบมา
