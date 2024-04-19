// SPDX-License-Identifier: LZBL-1.2
pragma solidity ^0.8.20;

import "forge-std/Test.sol";

struct L2Chain {
    string rpcUrl;
    uint256 forkBlockNumber;
    address L2messenger;
    address L1messenger;
    uint32 originEid;
    address endpoint;
    address send302;
    address receive302;
    address lzDvn;
}

struct L1Chain {
    string rpcUrl;
    uint256 forkBlockNumber;
    uint32 originEid;
    address endpoint;
    address send302;
    address receive302;
    address lzDvn;
}

contract Addresses {
    L2Chain public MODE = L2Chain({
        rpcUrl: "https://mainnet.mode.network",
        forkBlockNumber: 5601591,
        L2messenger: 0x4200000000000000000000000000000000000007,
        L1messenger: 0x95bDCA6c8EdEB69C98Bd5bd17660BaCef1298A6f,
        originEid: 30260,
        endpoint: 0x1a44076050125825900e736c501f859c50fE728c,
        send302: 0x2367325334447C5E1E0f1b3a6fB947b262F58312,
        receive302: 0xc1B621b18187F74c8F6D52a6F709Dd2780C09821,
        lzDvn: 0xce8358bc28dd8296Ce8cAF1CD2b44787abd65887
    });

    L2Chain public LINEA = L2Chain({
        rpcUrl: "https://1rpc.io/linea",
        forkBlockNumber: 3437029,
        L2messenger: 0x508Ca82Df566dCD1B0DE8296e70a96332cD644ec,
        L1messenger: 0xd19d4B5d358258f05D7B411E21A1460D11B0876F,
        originEid: 30183,
        endpoint: 0x1a44076050125825900e736c501f859c50fE728c,
        send302: 0x32042142DD551b4EbE17B6FEd53131dd4b4eEa06,
        receive302: 0xE22ED54177CE1148C557de74E4873619e6c6b205,
        lzDvn: 0x129Ee430Cb2Ff2708CCADDBDb408a88Fe4FFd480
    });

    L1Chain public ETHEREUM = L1Chain({
        rpcUrl: "https://eth-mainnet.alchemyapi.io/v2/pwc5rmJhrdoaSEfimoKEmsvOjKSmPDrP",
        forkBlockNumber: 19512240,
        originEid: 30101,
        endpoint: 0x1a44076050125825900e736c501f859c50fE728c,
        send302: 0xbB2Ea70C9E858123480642Cf96acbcCE1372dCe1,
        receive302: 0xc02Ab410f0734EFa3F14628780e6e695156024C2,
        lzDvn: 0x589dEDbD617e0CBcB916A9223F4d1300c294236b
    });
}
