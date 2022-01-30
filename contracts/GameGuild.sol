//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "./GMON.sol";
import "./GameCollectionV2.sol";
import "./GameFactory.sol";

struct GameGuildInfo {
    uint256 id;
    uint256 land;
    string name;
    string symbol;
    string logo;
}
struct GuildRequest {
    bytes32 referrer;
    uint256 monsterId;
    uint256 timestamp;
}

contract GameGuild is Ownable {
    using SafeMath for uint256;

    address public Game_FACTORY;
    address public GUILD_TOKEN_ADDRESS;

    address public founder;
    address[] private _members;
    mapping(bytes32 => address) private _referrers;

    mapping(uint256 => address) private _genesisMonstersOwners;
    mapping(uint256 => address) private _z1MonsterOwners;
    mapping(uint256 => address) private _z1MonsterPlayers;

    address[] private _joinRequesters;
    mapping(address => GuildRequest) private _joinRequests;

    GameGuildInfo private _info;

    modifier onlyMember() {
        for (uint256 i = 0; i < _members.length; i++) {
            if (_members[i] == msg.sender) {
                _;
                return;
            }
        }

        revert("You needs be member of guild.");
    }

    constructor() {
        Game_FACTORY = msg.sender;
    }

    function initialize(
        address founder_,
        GameGuildInfo memory info,
        uint256[] calldata monsters
    ) public returns (bytes32 defaultReferrer) {
        require(msg.sender == Game_FACTORY, "Game guild: FORBIDDEN"); // sufficient check

        founder = founder_;
        _info = info;

        for (uint256 idx = 0; idx < monsters.length; idx++) {
            _genesisMonstersOwners[monsters[idx]] = founder_;
        }

        _members.push(founder_);

        defaultReferrer = generateReferrCode(founder_);
        _referrers[defaultReferrer] = founder_;
    }

    function getInfo()
        external
        view
        returns (
            uint256,
            uint256,
            string memory,
            string memory,
            string memory
        )
    {
        return (_info.id, _info.land, _info.name, _info.symbol, _info.logo);
    }

    function requestDetails(uint256 monsterId)
        external
        view
        returns (GuildRequest memory)
    {
        GuildRequest memory request;

        for (uint256 i = 0; i < _joinRequesters.length; i++) {
            if (_joinRequests[_joinRequesters[i]].monsterId == monsterId) {
                return _joinRequests[_joinRequesters[i]];
            }
        }

        return request;
    }

    function requestJoin(
        address requester,
        bytes32 referrer,
        uint256 monsterId
    ) public {
        require(msg.sender == Game_FACTORY, "Game guild: FORBIDDEN"); // sufficient check
        require(_joinRequests[requester].referrer == 0, "Already requested.");

        // Transfer GMON token as join fee
        address gmon_address = GameFactory(Game_FACTORY).GMON_ADDRESS();
        address treasury_address = GameFactory(Game_FACTORY).TREASURY_ADDRESS();
        uint256 gmon_amount = GameFactory(Game_FACTORY)
            .JOIN_GMON_AMOUNT();

        GMON(gmon_address).transferFrom(requester, treasury_address, gmon_amount);

        // Transfer guild token as join fee
        // GMON_GUILD(GUILD_TOKEN_ADDRESS).transferFrom(requester, address(this), JOIN_GTOKEN_AMOUNT);

        _joinRequesters.push(requester);
        _joinRequests[requester] = GuildRequest(
            referrer,
            monsterId,
            block.timestamp
        );
    }

    function acceptJoin(address requester, uint256 monsterId)
        public
        onlyMember
        returns (bytes32 referrer)
    {
        require(
            _z1MonsterOwners[monsterId] == msg.sender,
            "You need to own monster."
        ); // z1 monster owner check
        
        require(
            _z1MonsterPlayers[monsterId] == msg.sender,
            "You already assigned that monster to other member."
        ); // z1 monster player check

        if (_joinRequests[requester].monsterId > 0) {
            require(
                monsterId == _joinRequests[requester].monsterId,
                "Your monster not matched with requested."
            ); // specify monster id check
        }

        // Assign monster to requester
        _z1MonsterPlayers[monsterId] = requester;

        referrer = generateReferrCode(requester);
        _referrers[referrer] = requester;

        _members.push(requester);
    }

    function revokeJoin(address requester) public {
        require(msg.sender == Game_FACTORY, "Game guild: FORBIDDEN"); // sufficient check
        require(
            _joinRequests[requester].referrer > 0,
            "You have no join request."
        );


        // Revert guild token
        // GMON_GUILD(GUILD_TOKEN_ADDRESS).transfer(requester, JOIN_GTOKEN_AMOUNT);

        // Set empty value for request
        _joinRequests[requester] = GuildRequest(0, 0, 0);
    }

    function claimJoinFee(address requester) public {
        require(msg.sender == Game_FACTORY, "Game guild: FORBIDDEN"); // sufficient check
        require(
            _joinRequests[requester].referrer > 0,
            "You have no join request."
        );

        uint256 expired_timestamp = GameFactory(Game_FACTORY)
            .JOIN_EXPIRED_TIMESTAMP();

        // Check expired
        require(
            _joinRequests[requester].timestamp + expired_timestamp <
                block.timestamp,
            "Your request not expired yet."
        );

        // Revert guild token
        // uint256 gtoken_amount = GameFactory(Game_FACTORY).JOIN_GTOKEN_AMOUNT();
        // GMON_GUILD(GUILD_TOKEN_ADDRESS).transfer(requester, gtoken_amount);

        // Set empty value for request
        _joinRequests[requester] = GuildRequest(0, 0, 0);
    }

    function addMonsters(uint256[] memory monsterIds) external onlyMember {
        address gmonc_z1_address = GameFactory(Game_FACTORY)
            .GMONC_Z1_ADDRESS();

        for (uint256 i = 0; i < monsterIds.length; i++) {
            uint256 monsterId = monsterIds[i];
            require(
                GameZ1(gmonc_z1_address).ownerOf(monsterId) == msg.sender,
                "You not own that monster."
            );

            _z1MonsterOwners[monsterId] = msg.sender;
            _z1MonsterPlayers[monsterId] = msg.sender;
        }

        // Reward guild token 
        // GMON_GUILD(GUILD_TOKEN_ADDRESS).transfer(requester, reward_amount);
    }

    // Generate referrer code with address and guild id
    function generateReferrCode(address user)
        private
        view
        returns (bytes32 referrerCode)
    {
        referrerCode = keccak256(
            abi.encodePacked(user, _info.name, block.number)
        );
    }
}
