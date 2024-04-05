// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract MockOracle {
    struct Answer {
        uint80 roundId;
        int256 answer;
        uint256 startedAt;
        uint256 updatedAt;
        uint80 answeredInRound;
    }

    Answer private _latestAnswer;

    function latestRoundData()
        external
        view
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
    {
        Answer storage a = _latestAnswer;

        return (a.roundId, a.answer, a.startedAt, a.updatedAt, a.answeredInRound);
    }

    function setPrice(int256 price) external {
        Answer storage answer = _latestAnswer;

        answer.answeredInRound = answer.roundId++;
        answer.answer = price;
        answer.startedAt = block.timestamp;
        answer.updatedAt = block.timestamp;
    }
}
