
// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.7.0 <0.9.0;

import "./CommitReveal.sol";
import "./TimeUnit.sol";

contract RPS {

    TimeUnit public timeUnit;
    CommitReveal public commitReveal;

    address public constant ADDRESS_1 = 0x5B38Da6a701c568545dCfcB03FcB875f56beddC4;
    address public constant ADDRESS_2 = 0xAb8483F64d9C6d1EcF9b849Ae677dD3315835cb2;
    address public constant ADDRESS_3 = 0x4B20993Bc481177ec7E8f571ceCaE8A9e22C02db;
    address public constant ADDRESS_4 = 0x78731D3Ca6b7E34aC0F824c42a7cC18A495cabaB;

    uint public numPlayer = 0;
    uint public reward = 0;
    uint public numCommit = 0;
    uint public numReveal = 0;

    mapping (address => uint) public player_choice; // 0 - Rock, 1 - Spock, 2 - Paper, 3 - Lizard, 4 - Scissors
    mapping (address => bool) public player_not_played;

    address[] public players;

    constructor(address _timeUnit, address _commitReveal) {
        timeUnit = TimeUnit(_timeUnit);
        commitReveal = CommitReveal(_commitReveal);
    }

    modifier onlyValidAddress() {
        require(
            msg.sender == ADDRESS_1 || 
            msg.sender == ADDRESS_2 || 
            msg.sender == ADDRESS_3 || 
            msg.sender == ADDRESS_4,
            "You are not allowed to perform this transaction"
        );
        _;
    }

    function addPlayer() public payable onlyValidAddress {
        require(numPlayer < 2);
        if (numPlayer > 0) {
            require(msg.sender != players[0]);
        }
        require(msg.value == 1 ether, "You need to pay 1 ether");
        reward += msg.value;
        player_not_played[msg.sender] = true;
        players.push(msg.sender);
        numPlayer++;
    }

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

    function getPlayerCommit(address player) public view returns (bytes32, uint64, bool) {
        return commitReveal.commits(player);
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

    function getElaspedSeconds() public view returns (uint256) {
        return timeUnit.elapsedSeconds();
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

    function _resetState() private {
        numPlayer = 0;     
        numCommit = 0;
        numReveal = 0;
        reward = 0;

        for (uint i = 0 ; i < players.length ; i++) {
            player_not_played[players[i]] = false;
            player_choice[players[i]] = 0;
        }

        delete players;
    }
}