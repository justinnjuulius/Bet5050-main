pragma solidity ^0.4.26;

import "./Disableable.sol";
import "./OracleInterface.sol";
import "./strings.sol";

contract House is Disableable {
    using strings for *;

    OracleInterface internal matchOracle;
    address internal matchOracleAddr;

    uint256 internal minimumBet = 1000000000000;

    
    event betPlaced(address bettor, bytes32 matchId, string betType);
    event oracleSet(address oracleAddress);

    struct bet {
        bytes32 betId;
        address owner;
        bytes32 matchId;
        uint256 amount;
        string betType;
        string betItem;
    }

    mapping(bytes32 => bet) internal betIdToBets; // mapping betId => bet
    mapping(address => mapping(bytes32 => mapping(string => bytes32)))
        internal userToBetIds; // mapping userAddress => matchId => betType (FirstScorer, Scoreline, Winner) => betId
    mapping(address => bytes32[]) internal userToMatchIds; // mapping user => matchId[]
    mapping(bytes32 => bool) internal matchPaidOut;
    mapping(address => uint8) internal userBetted;

    mapping(bytes32 => bytes32[]) internal matchIdToBetIds_winner; // mapping matchId => betId[]
    mapping(bytes32 => bytes32[]) internal matchIdToBetIds_firstScorer; // mapping matchId => betId[]
    mapping(bytes32 => bytes32[]) internal matchIdToBetIds_scoreline; // mapping matchId => betId[]

    /// @notice sets the address of the match oracle contract to use
    /// @dev setting a wrong address may result in false return value, or error
    /// @param _oracleAddress the address of the match oracle
    /// @return true if connection to the new oracle address was successful
    function setOracleAddress(address _oracleAddress)
        external
        onlyOwner
        returns (bool)
    {
        matchOracleAddr = _oracleAddress;
        matchOracle = OracleInterface(matchOracleAddr);
        emit oracleSet(matchOracleAddr);
        return matchOracle.testConnection();
    }

    /// @notice gets the address of the boxing oracle being used
    /// @return the address of the currently set oracle
    function getOracleAddress() external view returns (address) {
        return matchOracleAddr;
    }

    /*---------------------------Start of checkers---------------------------*/

    /// @notice determines whether or not the user has already bet on the given match
    /// @param _user address of a user
    /// @param _matchId id of a match
    /// @param _betItem the index of the participant to bet on (to win)
    /// @return true if the given user has already placed a bet on the given match
    function _betIsValid(
        address _user,
        bytes32 _matchId,
        string memory _betType,
        string memory _betItem
    ) private view returns (bool) {
        bytes32 betId = userToBetIds[_user][_matchId][_betType];
        require(betId == 0, "Can not place two bets on same item");

        strings.slice memory betType = _betType.toSlice();
        strings.slice memory betItem = _betItem.toSlice();
        //ensure that bet is valid for the match
        if (betType.equals("Winner")) {
            return _teamValid(_matchId, betItem);
        }
        if (betType.equals("FirstScorer")) {
            return _palyerValid(_matchId, betItem);
        }
        if (betType.equals("Scoreline")) {
            return _scorelineValid(betItem);
        }
        return false;
    }

    function _teamValid(bytes32 _matchId, strings.slice memory betItem)
        internal
        view
        returns (bool)
    {
        uint256 i;
        (, string memory matchName, , , , , , , ) = matchOracle.getMatch(
            _matchId
        );
        strings.slice memory s = matchName.toSlice();
        strings.slice memory delim = " vs ".toSlice();
        strings.slice[] memory teams = new strings.slice[](2);
        for (i = 0; i < teams.length; i++) {
            if (betItem.equals(s.split(delim))) {
                return true;
            }
        }
        return false;
    }

    function _palyerValid(bytes32 _matchId, strings.slice memory betItem)
        internal
        view
        returns (bool)
    {
        uint256 i;
        (, , string memory players, , , , , , ) = matchOracle.getMatch(
            _matchId
        );
        strings.slice memory s = players.toSlice();
        strings.slice memory delim = ",".toSlice();
        strings.slice[] memory bettingItemsArray = new strings.slice[](
            s.count(delim) + 1
        );
        for (i = 0; i < bettingItemsArray.length; i++) {
            if (betItem.equals(s.split(delim))) {
                return true;
            }
        }
        return false;
    }

    function _scorelineValid(strings.slice memory betItem)
        internal
        pure
        returns (bool)
    {
        if (
            betItem.equals("0-0") ||
            betItem.equals("0-1") ||
            betItem.equals("1-0") ||
            betItem.equals("1-1") ||
            betItem.equals("0-2") ||
            betItem.equals("2-0") ||
            betItem.equals("1-2") ||
            betItem.equals("2-1") ||
            betItem.equals("2-2") ||
            betItem.equals("other socreline")
        ) {
            return true;
        }
        return false;
    }

    /// @notice determines whether or not bets may still be accepted for the given match
    /// @param _matchId id of a match
    /// @return true if the match is bettable
    function _matchOpenForBetting(bytes32 _matchId)
        private
        view
        returns (bool)
    {
        OracleInterface.MatchStatus status;
        (, , , , , , , , status) = getMatch(_matchId);
        return status == OracleInterface.MatchStatus.Pending;
    }

    /// @notice tests that we are connected to a valid oracle for match results
    /// @return true if valid connection
    function testOracleConnection() public view returns (bool) {
        return matchOracle.testConnection();
    }

    /*---------------------------End of checkers---------------------------*/

    /*---------------------------Start of getters---------------------------*/

    /// @notice gets a list ids of all currently bettable matches
    /// @return array of match ids
    function getBettableMatches() public view returns (bytes32[] memory) {
        return matchOracle.getPendingMatches();
    }

    /// @notice gets a list ids of all matches
    /// @return array of match ids
    function getAllMatches() public view returns (bytes32[] memory) {
        return matchOracle.getAllMatches();
    }

    /// @notice returns the full data of the specified match
    /// @param _matchId the id of the desired match
    /// @return match data
    function getMatch(bytes32 _matchId)
        public
        view
        returns (
            bytes32 matchId,
            string memory matchName,
            string memory players,
            uint256 startTime,
            uint256 endTime,
            string memory winner,
            string memory firstScorer,
            string memory scoreline,
            OracleInterface.MatchStatus outcome
        )
    {
        return matchOracle.getMatch(_matchId);
    }

    /// @notice gets the current matches on which the user has bet
    /// @return array of match ids
    // function getUserBets(bytes32 _matchId) public view returns (bytes32[]) {
    //     /* TODO: EXTEND to three types */
    //     bytes32[] storage res;

    //     return res; //betType (FirstScorer, Scoreline, Winner) => betId[]
    // }

    /// @notice returns the full data of the most recent bettable match
    /// @return match data
    function getMostRecentMatch()
        public
        view
        returns (
            bytes32 matchId,
            string memory matchName,
            string memory players,
            uint256 startTime,
            uint256 endTime,
            string memory winner,
            string memory firstScorer,
            string memory scoreline,
            OracleInterface.MatchStatus outcome
        )
    {
        return matchOracle.getMostRecentMatch(true);
    }

    /*---------------------------End of getters---------------------------*/

    /// @notice gets a user's bet on a given match
    /// @param _matchId the id of the desired match
    /// @return tuple containing the bet amount, and the index of the chosen winner (or (0,0) if no bet found)
    function getUserBet(bytes32 _matchId, string memory _betType)
        public
        view
        returns (uint256 amount, string memory betItem)
    {
        /* 
        TODO: use the 'amount' list to store the amount of each bet (up to 3), assemble the betItem string, e.g. "Manchester United,Cristiano Ronaldo,1-1" 
        */
        require(userBetted[msg.sender] != 0, "User has not placed any bet");
        bool userBetMatch = false;
        for (uint256 i = 0; i < userToMatchIds[msg.sender].length; i++) {
            if (userToMatchIds[msg.sender][i] == _matchId) {
                userBetMatch = true;
            }
        }
        require(userBetMatch, "User has not placed a bet on this game");
        bytes32 betId = userToBetIds[msg.sender][_matchId][_betType];
        require(betId != 0, "Bet does not exist");
        return (betIdToBets[betId].amount, betIdToBets[betId].betItem);
    }

    /// @notice places a non-rescindable bet on the given match
    /// @param _matchId the id of the match on which to bet
    function placeBet(
        bytes32 _matchId,
        string memory _betType,
        string memory _betItem
    ) public payable notDisabled {
        //bet must be above a certain minimum
        require(msg.value >= minimumBet, "Must place bet larger that 0.01 ETH");

        //make sure that match exists
        require(matchOracle.matchExists(_matchId), "Match does not exist");

        //require that chosen winner falls within the defined number of participants for match
        require(
            _betIsValid(msg.sender, _matchId, _betType, _betItem),
            "Bet item invalid"
        );

        //match must still be open for betting
        require(_matchOpenForBetting(_matchId), "Match closed for betting");

        matchPaidOut[_matchId] = false;
        /* 
        TODO:
        1. transfer money to the bet5050 contract address
        2. assemble bet struct
        3. add bet and betId to three mappings ("FirstScorer", Scoreline, Winner) => (winner, firstScorer, scoreline)
        4. make sure the match is not paid out yet
        */
        // address(this).transfer(msg.value);
        // address payable payable_this = address(
        //     uint160(address(this))
        // );

        bytes32 _betId = keccak256(abi.encodePacked(_matchId, msg.sender));

        bet memory _bet = bet(
            _betId,
            msg.sender,
            _matchId,
            msg.value,
            _betType,
            _betItem
        );

        betIdToBets[_betId] = _bet;
        userToBetIds[msg.sender][_matchId][_betType] = _betId;
        userToMatchIds[msg.sender].push(_matchId);

        strings.slice memory betType = _betType.toSlice();

        //ensure that bet is valid for the match
        if (betType.equals("Winner")) {
            matchIdToBetIds_winner[_matchId].push(_betId);
        }
        if (betType.equals("FirstScorer")) {
            matchIdToBetIds_firstScorer[_matchId].push(_betId);
        }
        if (betType.equals("Scoreline")) {
            matchIdToBetIds_scoreline[_matchId].push(_betId);
        }
        userBetted[msg.sender] = 1;
        emit betPlaced(msg.sender, _matchId, _betType);
    }
}