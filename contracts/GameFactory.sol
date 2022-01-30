//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.4;

import "./GameGuild.sol";

contract GameFactory is Ownable {
    using SafeMath for uint256;

    address public immutable GMON_ADDRESS;
    address public immutable GNRG_ADDRES;
    address public immutable GMON_Z1_ADDRES;
    address public immutable GMONC_ADDRESS;
    address public immutable GMONEC_ADDRESS;
    address public immutable GMONC_Z1_ADDRESS;
    address public immutable GLAND_ADDRESS;

    uint256 public CREATE_GENESIS_MONSTERS_NUM = 2; // Set 2 as test
    uint256 public CREATE_GMON_AMOUNT = 50000 * 10**18;
    uint256 public CREATE_MIN_GMON_LOCKED = 100000 * 10**18;

    uint256 public JOIN_EXPIRED_TIMESTAMP = 60 * 60 * 24 * 7; // 1 week
    uint256 public JOIN_GMON_AMOUNT = 100 * 10**18;
    uint256 public JOIN_GTOKEN_AMOUNT = 900 * 10**18;

    address public GMON_STAKE_ADDRESS;
    address public TREASURY_ADDRESS;

    uint256[] private guildIds;
    mapping(uint256 => address) private _guildAddrs;

    mapping(bytes32 => bool) private _guildNames;
    mapping(bytes32 => bool) private _guildSymbols;

    mapping(address => uint256) private _owners;
    mapping(address => uint256) private _subscribers;

    mapping(address => bytes32) private _waitlist;

    constructor(
        address gmon,
        address gnrg,
        address gmon_z1,
        address gmonc,
        address gmonec,
        address gmonc_z1,
        address gland
    ) {
        GMON_ADDRESS = gmon;
        GNRG_ADDRES = gnrg;
        GMON_Z1_ADDRES = gmon_z1;
        GMONC_ADDRESS = gmonc;
        GMONEC_ADDRESS = gmonec;
        GMONC_Z1_ADDRESS = gmonc_z1;
        GLAND_ADDRESS = gland;
    }

    function createGuild(
        uint256 gmonAmount,
        uint256 landElement,
        string calldata name,
        string calldata symbol,
        string calldata logo,
        uint256[] calldata genesis_monsters
    ) external returns (uint256 guildId, address guildAddress) {
        // Check guild registration
        require(
            genesis_monsters.length < CREATE_GENESIS_MONSTERS_NUM,
            "Founder need to provides more monsters."
        );
        require(
            _subscribers[msg.sender] == 0,
            "You already subscribed in other guild."
        );
        require(
            gmonAmount >= CREATE_MIN_GMON_LOCKED,
            "You need to lock more GMON tokens."
        );
        require(
            gmonAmount + CREATE_GMON_AMOUNT >=
                GMON(GMON_ADDRESS).balanceOf(msg.sender),
            "Your balance is not enough as requested."
        );

        bytes32 _name = keccak256(abi.encodePacked(name));
        bytes32 _symbol = keccak256(abi.encodePacked(symbol));

        // Check name or symbol unique
        require(
            !_guildNames[_name],
            "Current name already used in other guild."
        );
        require(
            !_guildSymbols[_symbol],
            "Current symbol already used in other guild."
        );

        // Check land element validation
        require(
            GameLand(GLAND_ADDRESS).ownerOf(landElement) == msg.sender,
            "You need to own land element."
        );

        // Check genesis monsters validation
        uint256 bannedMonsters = 0;
        for (uint256 idx = 0; idx < genesis_monsters.length; idx++) {
            uint256 monsterId = genesis_monsters[idx];
            require(
                GameGenesis(GMONC_ADDRESS).ownerOf(monsterId) == msg.sender,
                "You not own that monster."
            );

            // Check ban list and burn
            bool isBanned = GameGenesis(GMONC_ADDRESS).isBanned(
                msg.sender,
                address(0),
                monsterId
            );
            if (isBanned) {
                GameGenesis(GMONC_ADDRESS).arrestToken(monsterId);
                bannedMonsters = bannedMonsters + 1;
            }
        }

        // If contains banned monsters, then exit without guild creation
        require(bannedMonsters == 0, "You have banned monsters.");

        bytes memory bytecode = type(GameGuild).creationCode;
        bytes32 salt = keccak256(abi.encodePacked(msg.sender, "Game Guild"));
        assembly {
            guildAddress := create2(0, add(bytecode, 32), mload(bytecode), salt)
            if iszero(extcodesize(guildAddress)) {
                revert(0, 0)
            }
        }

        // Initialize guild contract
        guildId = guildIds.length + 1;
        GameGuildInfo memory info_ = GameGuildInfo(
            guildId,
            landElement,
            name,
            symbol,
            logo
        );
        GameGuild(guildAddress).initialize(
            msg.sender,
            info_,
            genesis_monsters
        );

        // Transfer genesis monsters to factory contract
        for (uint256 idx = 0; idx < genesis_monsters.length; idx++) {
            GameGenesis(GMONC_ADDRESS).transferFrom(
                msg.sender,
                guildAddress,
                genesis_monsters[idx]
            );
        }

        // Transfer guild create payment to factory contract
        GMON(GMON_ADDRESS).transferFrom(
            msg.sender,
            address(this),
            CREATE_GMON_AMOUNT
        );

        // Transfer lock amount to stake contract
        // GMON(GMON_ADDRESS).transferFrom(msg.sender, GMON_STAKE_ADDRESS, gmonAmount);

        _owners[msg.sender] = guildId;
        _subscribers[msg.sender] = guildId;
        _guildAddrs[guildId] = guildAddress;

        _guildNames[_name] = true;
        _guildSymbols[_symbol] = true;
    }

    function getGuildAddress(uint256 guildId) public view returns (address) {
        return _guildAddrs[guildId];
    }

    function requestJoin(
        bytes32 referrer,
        uint256 guildId,
        uint256 monsterId
    ) external {
        require(_waitlist[msg.sender] == 0, "You already request join guild.");

        GameGuild(_guildAddrs[guildId]).requestJoin(
            msg.sender,
            referrer,
            monsterId
        );
        _waitlist[msg.sender] = referrer;
    }

    function revokeJoin(uint256 guildId) external {
        require(_waitlist[msg.sender] > 0, "You need to request join guild.");

        GameGuild(_guildAddrs[guildId]).revokeJoin(msg.sender);
        _waitlist[msg.sender] = 0;
    }

    function claimJoinFee(uint256 guildId) external {
        require(_waitlist[msg.sender] > 0, "You need to request join guild.");

        GameGuild(_guildAddrs[guildId]).claimJoinFee(msg.sender);
        _waitlist[msg.sender] = 0;
    }

    // Set variables related with guild creation functionality
    function setCreateVariables(
        uint256 genesis_monsters,
        uint256 gmon_amount,
        uint256 min_locked_amount
    ) external onlyOwner {
        CREATE_GENESIS_MONSTERS_NUM = genesis_monsters;
        CREATE_GMON_AMOUNT = gmon_amount;
        CREATE_MIN_GMON_LOCKED = min_locked_amount;
    }

    // Set variables related with join functionality
    function setJoinVariables(
        uint256 expired_timestamp,
        uint256 gmon_amount,
        uint256 gtoken_amount
    ) external onlyOwner {
        JOIN_EXPIRED_TIMESTAMP = expired_timestamp;
        JOIN_GMON_AMOUNT = gmon_amount;
        JOIN_GTOKEN_AMOUNT = gtoken_amount;
    }
}
