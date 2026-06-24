// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract SergeyPiggyBank {
    address public owner;
    uint256 public unlockTime;

    constructor(uint256 _durationInMinutes) {
        owner = msg.sender;
        unlockTime = block.timestamp + (_durationInMinutes * 1 minute);
    }

    // Функция для депозита через вызов
    function deposit() public payable {}

    function withdraw() public {
        require(msg.sender == owner, "Not an owner");
        require(block.timestamp >= unlockTime, "Too early");
        payable(owner).transfer(address(this).balance);
    }

    function getBalance() public view uint256 {
        return address(this).balance;
    }
}
