// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {VRFV2PlusWrapperConsumerBase} from "@chainlink/contracts/src/v0.8/vrf/dev/VRFV2PlusWrapperConsumerBase.sol";
import {VRFV2PlusClient} from "@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";

contract Raffle is Ownable, ReentrancyGuard, VRFV2PlusWrapperConsumerBase {
    enum RaffleState {
        Open,
        Closed
    }

    uint32 private constant CALLBACK_GAS_LIMIT = 100000;
    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint32 private constant NUM_WORDS = 1;

    address private immutable i_owner;
    uint256 private immutable i_entranceFee;
    uint256 private immutable i_numberOfPlayers;
    address private immutable i_nftAddress;
    uint256 private immutable i_rewardPercentage;

    address[] private s_players;
    RaffleState private s_state;
    uint256 private s_priceTokenId;
    uint256 private s_currentRequestId;

    event RaffleIsOpen(uint256 indexed tokenId);
    event NewPlayerEntered(address indexed player);
    event WinnerIsPicked(address indexed winner);
    event OwnerWithdraw(uint256 indexed amount);

    error Raffle_AddressCantBeZero();
    error Raffle_EntranceFeeCantBeZero();
    error Raffle_NumberOfPlayerCantBeZero();
    error Raffle_StateMustBeOpen();
    error Raffle_StateMustBeClosed();
    error Raffle_NFTRewardNotAssigned();
    error Raffle_PlayerInsufficientBalance(
        address player,
        uint256 amountTransferred
    );
    error Raffle_PlayerCapacityIsFull();
    error Raffle_NotEnoughPlayer();
    error Raffle_TransferBalanceFailed();
    error Raffle_ContractInsufficientBalance();

    constructor(
        address _vrfWrapperAddress,
        uint256 _entranceFee,
        uint256 _numberOfPlayers,
        address _nftAddress
    ) Ownable(msg.sender) VRFV2PlusWrapperConsumerBase(_vrfWrapperAddress) {
        require(_entranceFee != 0, Raffle_EntranceFeeCantBeZero());
        require(_numberOfPlayers != 0, Raffle_NumberOfPlayerCantBeZero());
        require(_nftAddress != address(0), Raffle_AddressCantBeZero());

        i_owner = msg.sender;
        i_entranceFee = _entranceFee;
        i_numberOfPlayers = _numberOfPlayers;
        i_nftAddress = _nftAddress;
        s_state = RaffleState.Closed;
    }

    receive() external payable open {
        _enterRaffle();
    }

    modifier open() {
        require(s_state == RaffleState.Open, Raffle_StateMustBeOpen());
        _;
    }

    modifier closed() {
        require(s_state == RaffleState.Closed, Raffle_StateMustBeClosed());
        _;
    }

    function openRaffle(uint256 _tokenId) external onlyOwner closed {
        require(
            IERC721(i_nftAddress).ownerOf(_tokenId) == address(this),
            Raffle_NFTRewardNotAssigned()
        );

        s_state = RaffleState.Open;
        s_priceTokenId = _tokenId;

        emit RaffleIsOpen(_tokenId);
    }

    function _enterRaffle() internal {
        require(
            msg.value == i_entranceFee,
            Raffle_PlayerInsufficientBalance(msg.sender, msg.value)
        );
        require(
            s_players.length < i_numberOfPlayers,
            Raffle_PlayerCapacityIsFull()
        );

        s_players.push(msg.sender);

        emit NewPlayerEntered(msg.sender);
    }

    function enterRaffle() external payable open {
        _enterRaffle();
    }

    function pickWinner(uint256 _randomNumber) internal {
        address[] memory players = s_players;

        uint256 winnerIndex = _randomNumber % players.length;
        address winnerAddress = players[winnerIndex];
        uint256 tempPriceTokenId = s_priceTokenId;

        delete s_players;
        s_state = RaffleState.Closed;
        s_priceTokenId = 0;
        s_currentRequestId = 0;
        emit WinnerIsPicked(winnerAddress);

        IERC721(i_nftAddress).transferFrom(
            address(this),
            winnerAddress,
            tempPriceTokenId
        );
    }

    function requestWinner() external nonReentrant open {
        require(
            s_players.length == i_numberOfPlayers,
            Raffle_NotEnoughPlayer()
        );

        bytes memory extraArgs = VRFV2PlusClient._argsToBytes(
            VRFV2PlusClient.ExtraArgsV1({nativePayment: true})
        );
        (uint256 requestId, ) = requestRandomnessPayInNative(
            CALLBACK_GAS_LIMIT,
            REQUEST_CONFIRMATIONS,
            NUM_WORDS,
            extraArgs
        );
        s_currentRequestId = requestId;
    }

    function fulfillRandomWords(
        uint256,
        /* _requestId */ uint256[] memory _randomWords
    ) internal override {
        pickWinner(_randomWords[0]);
    }

    function withdraw() external onlyOwner closed {
        uint256 contractBalance = address(this).balance;
        require(contractBalance > 0, Raffle_ContractInsufficientBalance());

        emit OwnerWithdraw(contractBalance);

        (bool success, ) = address(msg.sender).call{value: contractBalance}("");
        require(success, Raffle_TransferBalanceFailed());
    }

    function player(uint256 _index) public view returns (address) {
        return s_players[_index];
    }

    function numberOfPlayers() public view returns (uint256) {
        return s_players.length;
    }

    function state() public view returns (RaffleState) {
        return s_state;
    }

    function priceTokenId() public view returns (uint256) {
        return s_priceTokenId;
    }

    function currentRequestId() public view returns (uint256) {
        return s_currentRequestId;
    }
}
