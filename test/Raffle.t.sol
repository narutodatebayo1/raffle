// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {LinkToken} from "@chainlink/contracts/src/v0.8/shared/token/ERC677/LinkToken.sol";
import {MockV3Aggregator} from "@chainlink/contracts/src/v0.8/tests/MockV3Aggregator.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {VRFV2PlusWrapper} from "@chainlink/contracts/src/v0.8/vrf/dev/VRFV2PlusWrapper.sol";
import {MyNFT} from "../src/MyNFT.sol";
import {Raffle} from "../src/Raffle.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract RaffleTest is Test {
    LinkToken public linkToken;
    MockV3Aggregator public aggregator;
    VRFCoordinatorV2_5Mock public coordinator;
    VRFV2PlusWrapper public wrapper;

    MyNFT public myNFT;
    Raffle public raffle;

    address public constant OWNER = address(100);
    address public constant PLAYER1 = address(1);
    address public constant PLAYER2 = address(2);
    address public constant PLAYER3 = address(3);
    address public constant PLAYER4 = address(4);
    uint256 public constant STARTING_BALANCE = 10e18;

    uint256 public constant ENTRANCE_FEE = 1e18;
    uint256 public constant NUMBER_OF_PLAYERS = 3;

    uint32 public constant CALLBACK_GAS_LIMIT = 100000;
    uint32 public constant NUM_WORDS = 1;
    uint256 public constant RANDOM_WORD = 12345;

    function setUp() public {
        linkToken = new LinkToken();
        aggregator = new MockV3Aggregator(18, 3000000000000000);
        coordinator = new VRFCoordinatorV2_5Mock(
            100000000000000000,
            1000000000,
            1
        );

        uint256 subId = coordinator.createSubscription();
        wrapper = new VRFV2PlusWrapper(
            address(linkToken),
            address(aggregator),
            address(coordinator),
            subId
        );

        wrapper.setConfig(
            30_000,
            90_000,
            112_000,
            500,
            25,
            20,
            0x6c3699283bda56ad74f6b855546325b68d482e983852a6c9b88f9a54d78d57b2,
            10,
            600,
            10 ** 16,
            1000,
            5
        );

        coordinator.addConsumer(subId, address(wrapper));

        vm.prank(OWNER);
        myNFT = new MyNFT();
        vm.prank(OWNER);
        raffle = new Raffle(
            address(wrapper),
            ENTRANCE_FEE,
            NUMBER_OF_PLAYERS,
            address(myNFT)
        );

        vm.deal(PLAYER1, STARTING_BALANCE);
        vm.deal(PLAYER2, STARTING_BALANCE);
        vm.deal(PLAYER3, STARTING_BALANCE);
        vm.deal(PLAYER4, STARTING_BALANCE);
    }

    modifier open() {
        vm.prank(OWNER);
        uint256 tokenId = myNFT.mint();
        vm.prank(OWNER);
        myNFT.transferFrom(OWNER, address(raffle), tokenId);
        vm.prank(OWNER);
        raffle.openRaffle(tokenId);
        _;
    }

    modifier enter() {
        vm.prank(PLAYER1);
        raffle.enterRaffle{value: ENTRANCE_FEE}();
        vm.prank(PLAYER2);
        raffle.enterRaffle{value: ENTRANCE_FEE}();
        vm.prank(PLAYER3);
        raffle.enterRaffle{value: ENTRANCE_FEE}();
        _;
    }

    modifier request() {
        vm.prank(PLAYER3);
        raffle.requestWinner();
        uint256 requestId = raffle.currentRequestId();
        uint256[] memory randomWords = new uint256[](1);
        randomWords[0] = RANDOM_WORD;
        vm.prank(address(wrapper));
        raffle.rawFulfillRandomWords(requestId, randomWords);
        _;
    }

    function test_openRaffle() public {
        vm.prank(OWNER);
        uint256 tokenId = myNFT.mint();
        vm.prank(OWNER);
        myNFT.transferFrom(OWNER, address(raffle), tokenId);
        vm.expectEmit(true, false, false, false);
        emit Raffle.RaffleIsOpen(tokenId);
        vm.prank(OWNER);
        raffle.openRaffle(tokenId);

        assertEq(uint256(raffle.state()), uint256(Raffle.RaffleState.Open));
        assertEq(raffle.priceTokenId(), tokenId);
    }

    function test_openRaffle_RevertIf_NotOwner() public {
        vm.prank(OWNER);
        uint256 tokenId = myNFT.mint();
        vm.prank(OWNER);
        myNFT.transferFrom(OWNER, address(raffle), tokenId);

        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, PLAYER1));
        vm.prank(PLAYER1);
        raffle.openRaffle(tokenId);
    }

    function test_openRaffle_RevertIf_NotClosed() public open {
        vm.prank(OWNER);
        uint256 tokenId = myNFT.mint();
        vm.prank(OWNER);
        myNFT.transferFrom(OWNER, address(raffle), tokenId);

        vm.expectRevert(Raffle.Raffle_StateMustBeClosed.selector);
        vm.prank(OWNER);
        raffle.openRaffle(tokenId);
    }

    function test_openRaffle_RevertIf_NFTNotAssigned() public {
        vm.prank(OWNER);
        uint256 tokenId = myNFT.mint();

        vm.expectRevert(Raffle.Raffle_NFTRewardNotAssigned.selector);
        vm.prank(OWNER);
        raffle.openRaffle(tokenId);
    }

    function test_enterRaffle() public open {
        uint256 previousRaffleBalance = address(raffle).balance;
        vm.expectEmit(true, false, false, false);
        emit Raffle.NewPlayerEntered(PLAYER1);
        vm.prank(PLAYER1);
        raffle.enterRaffle{value: ENTRANCE_FEE}();
        uint256 currentRaffleBalance = address(raffle).balance;

        assertEq(raffle.player(0), PLAYER1);
        assertEq(currentRaffleBalance - previousRaffleBalance, ENTRANCE_FEE);
    }

    function test_enterRaffle_RevertIf_NotOpen() public {
        vm.expectRevert(Raffle.Raffle_StateMustBeOpen.selector);
        vm.prank(PLAYER1);
        raffle.enterRaffle{value: ENTRANCE_FEE}();
    }

    function test_enterRaffle_RevertIf_InsufficientBalance() public open {
        vm.expectRevert(abi.encodeWithSelector(Raffle.Raffle_PlayerInsufficientBalance.selector, PLAYER1, ENTRANCE_FEE / 2));
        vm.prank(PLAYER1);
        raffle.enterRaffle{value: ENTRANCE_FEE / 2}();
    }

    function test_enterRaffle_RevertIf_CapacityIsFull() public open enter {
        vm.expectRevert(Raffle.Raffle_PlayerCapacityIsFull.selector);
        vm.prank(PLAYER4);
        raffle.enterRaffle{value: ENTRANCE_FEE}();
    }

    function test_receive() public open {
        uint256 previousRaffleBalance = address(raffle).balance;
        vm.expectEmit(true, false, false, false);
        emit Raffle.NewPlayerEntered(PLAYER1);
        vm.prank(PLAYER1);
        (bool success, ) = address(raffle).call{value: ENTRANCE_FEE}("");
        assertTrue(success);
        uint256 currentRaffleBalance = address(raffle).balance;

        assertEq(raffle.player(0), PLAYER1);
        assertEq(currentRaffleBalance - previousRaffleBalance, ENTRANCE_FEE);
    }

    function test_receive_RevertIf_NotOpen() public {
        vm.expectRevert(Raffle.Raffle_StateMustBeOpen.selector);
        vm.prank(PLAYER1);
        (bool success, ) = address(raffle).call{value: ENTRANCE_FEE}("");
        assertTrue(success);
    }

    function test_pickWinner() public open enter {
        vm.prank(PLAYER3);
        raffle.requestWinner();
        uint256 requestId = raffle.currentRequestId();
        uint256[] memory randomWords = new uint256[](1);
        randomWords[0] = RANDOM_WORD;
        vm.expectEmit(true, false, false, false);
        emit Raffle.WinnerIsPicked(raffle.player(RANDOM_WORD % NUMBER_OF_PLAYERS));
        vm.prank(address(wrapper));
        raffle.rawFulfillRandomWords(requestId, randomWords);

        assertEq(raffle.numberOfPlayers(), 0);
        assertEq(uint256(raffle.state()), uint256(Raffle.RaffleState.Closed));
        assertEq(uint256(raffle.priceTokenId()), 0);
        assertEq(uint256(raffle.currentRequestId()), 0);
    }

    function test_requestWinner() public open enter {
        vm.prank(PLAYER3);
        raffle.requestWinner();

        uint256 requestId = raffle.currentRequestId();
        (address callbackAddress, , ) = wrapper.s_callbacks(requestId);
        assertEq(callbackAddress, address(raffle));
    }

    function test_requestWinner_RevertIf_NotOpen() public {
        vm.expectRevert(Raffle.Raffle_StateMustBeOpen.selector);
        vm.prank(PLAYER1);
        raffle.requestWinner();
    }

    function test_requestWinner_RevertIf_NotEnoughPlayer() public open {
        vm.prank(PLAYER1);
        raffle.enterRaffle{value: ENTRANCE_FEE}();
        vm.prank(PLAYER2);
        raffle.enterRaffle{value: ENTRANCE_FEE}();

        vm.expectRevert(Raffle.Raffle_NotEnoughPlayer.selector);
        vm.prank(PLAYER3);
        raffle.requestWinner();
    }

    function test_withdraw() public open enter request {
        uint256 amountFromEntrance = ENTRANCE_FEE * NUMBER_OF_PLAYERS;
        uint256 requestPrice = wrapper.calculateRequestPriceNative(
            CALLBACK_GAS_LIMIT,
            NUM_WORDS
        );
        uint256 remainingAmount = amountFromEntrance - requestPrice;

        uint256 previousOwnerBalance = address(OWNER).balance;
        vm.expectEmit(true, false, false, false);
        emit Raffle.OwnerWithdraw(remainingAmount);
        vm.prank(OWNER);
        raffle.withdraw();
        uint256 currentOwnerBalance = address(OWNER).balance;
        assertEq(
            currentOwnerBalance - previousOwnerBalance,
            remainingAmount
        );
    }

    function test_withdraw_RevertIf_NotOwner() public open enter request {
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, PLAYER1));
        vm.prank(PLAYER1);
        raffle.withdraw();
    }

    function test_withdraw_RevertIf_NotClosed() public open enter {
        vm.expectRevert(Raffle.Raffle_StateMustBeClosed.selector);
        vm.prank(OWNER);
        raffle.withdraw();
    }

    function test_withdraw_RevertIf_ContractInsufficientBalance() public {
        vm.expectRevert(Raffle.Raffle_ContractInsufficientBalance.selector);
        vm.prank(OWNER);
        raffle.withdraw();
    }
}
