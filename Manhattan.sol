// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract ManhattanRWA {
    // Параметры недвижимости (Real World Asset)
    string public propertyAddress = "721 5th Ave, New York, NY 10022 (Trump Tower)";
    uint256 public totalPropertyPriceUSD = 15000000; // Стоимость объекта $15 млн
    uint256 public totalBricks = 15000;             // Всего "кирпичиков" (долей)
    uint256 public pricePerBrickWei = 0.001 ether;  // Цена 1 кирпичика в тестовых токенах сети

    // Учет владельцев кирпичиков
    mapping(address => uint256) public myBricks;
    uint256 public bricksSold;

    // Событие для блокчейн-сканера, чтобы все видели покупку
    event BrickPurchased(address indexed buyer, uint256 amount);

    // Функция покупки кирпичиков
    function buyManhattanBrick(uint256 numberOfBricks) public payable {
        require(numberOfBricks > 0, "You must buy at least 1 brick");
        require(bricksSold + numberOfBricks <= totalBricks, "Not enough bricks available");
        require(msg.value >= pricePerBrickWei * numberOfBricks, "Not enough test tokens sent");

        myBricks[msg.sender] += numberOfBricks;
        bricksSold += numberOfBricks;

        emit BrickPurchased(msg.sender, numberOfBricks);
    }

    // Посмотреть, сколько кирпичиков у конкретного человека
    uint256 placeholder; // Дополнительная переменная для уникальности байткода
    function checkMyBrickCount(address owner) public view returns (uint256) {
        return myBricks[owner];
    }
}
