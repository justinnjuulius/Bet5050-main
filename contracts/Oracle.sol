pragma solidity ^0.4.17;

import "./Ownable.sol";
import "./DateLib.sol";
import "./OracleInterface.sol";

contract Oracle is Ownable, OracleInterface {
    Match[] matches;
    mapping(bytes32 => uint256) matchIdToIndex;

    using DateLib for DateLib.DateTime;

    uint256 public currentTime; //state variable to handle time

    event matchAdded(bytes32 matchId);
    event addedTest();
    event matchUnderway();
    event matchCancelled();
    event matchPending();
    event matchDecided();
    event addedTime();

    //defines a match along with its outcome
    struct Match {
        bytes32 matchId;
        string matchName;
        string players;
        uint256 startTime;
        uint256 endTime;
        string winner;
        string firstScorer;
        string scoreline;
        MatchStatus outcome;
    }

    /// @notice returns the array index of the match with the given id
    /// @dev if the match id is invalid, then the return value will be incorrect and may cause error; you must call matchExists(_matchId) first!
    /// @param _matchId the match id to get
    /// @return an array index
    function _getMatchIndex(bytes32 _matchId) private view returns (uint256) {
        return matchIdToIndex[_matchId] - 1;
    }

    /// @notice determines whether a match exists with the given id
    /// @param _matchId the match id to test
    /// @return true if match exists and id is valid
    function matchExists(bytes32 _matchId) public view returns (bool) {
        if (matches.length == 0) return false;
        uint256 index = matchIdToIndex[_matchId];
        return (index > 0);
    }

    /// @notice puts a new pending match into the blockchain
    /// @param _matchName descriptive name for the match (e.g. Pac vs. Mayweather 2016)
    /// @param _players |-delimited string of participants names (e.g. "Manny Pac|Floyd May")
    /// @param _startTime startTime set for the match
    /// @param _endTime endTime set for the match
    /// @return matchId the unique id of the newly created match
    function addMatch(
        string _matchName,
        string _players,
        uint256 _startTime,
        uint256 _endTime
    ) public onlyOwner returns (bytes32) {
        //hash the crucial info to get a unique id
        bytes32 matchId = keccak256(abi.encodePacked(_matchName, _startTime));

        //require that the match be unique (not already added)
        require(!matchExists(matchId), "matchId already exists");

        //add the match (winner, firstScorer and scoreline are NIL because match has not even commenced)
        uint256 newIndex = matches.push(
            Match(
                matchId,
                _matchName,
                _players,
                _startTime,
                _endTime,
                "NIL",
                "NIL",
                "NIL",
                MatchStatus.Pending
            )
        ) - 1;
        matchIdToIndex[matchId] = newIndex + 1;
        emit matchAdded(matchId);
        //return the unique id of the new match
        return matchId;
    }

    /// @notice sets the match outcome to 'underway', only if the outcome is currently pending
    /// @param _matchId unique match id
    function setMatchUnderway(bytes32 _matchId) external onlyOwner {
        require(matchExists(_matchId), "matchId does not exist");
        uint256 index = _getMatchIndex(_matchId);
        Match storage theMatch = matches[index];
        require(
            theMatch.outcome == MatchStatus.Pending,
            "addMatch() not executed for the Match"
        );
        theMatch.outcome = MatchStatus.Underway;
        if (theMatch.outcome == MatchStatus.Underway) {
            emit matchUnderway();
        }
    }

    /// @notice sets the match outcome to 'cancelled', only if the outcome is currently pending
    /// @param _matchId unique match id
    function setMatchCancelled(bytes32 _matchId) external onlyOwner {
        require(matchExists(_matchId), "matchId does not exist");
        uint256 index = _getMatchIndex(_matchId);
        Match storage theMatch = matches[index];
        require(
            theMatch.outcome == MatchStatus.Pending,
            "addMatch() not executed for the Match or Match already underway"
        );
        theMatch.outcome = MatchStatus.Cancelled;
        if (theMatch.outcome == MatchStatus.Cancelled) {
            emit matchCancelled();
        }
    }

    /// @notice sets the outcome of a predefined match, permanently on the blockchain
    /// @param _matchId unique id of the match to modify
    /// @param _outcome outcome of the match
    /// @param _winner string of the team who won (if there is a winner). Match must be decided
    /// @param _firstScorer string of the first scorer (if there is a scorer). Match must be decided
    /// @param _scoreline string of the score line. Macth must be decided
    function declareOutcome(
        bytes32 _matchId,
        MatchStatus _outcome,
        string _winner,
        string _firstScorer,
        string _scoreline
    ) external onlyOwner {
        //require that it exists
        require(matchExists(_matchId), "matchId does not exist");
        //get the match
        uint256 index = _getMatchIndex(_matchId);
        Match storage theMatch = matches[index];
        //make sure that match is pending (outcome not already declared)
        require(
            theMatch.outcome == MatchStatus.Underway,
            "Match is not underway"
        );
        // if (_outcome == MatchStatus.Decided)
        //     require(_winner >= 0 && theMatch.teamCount > uint8(_winner));

        //set the outcome (other outcomes other than Decided can occur)
        theMatch.outcome = _outcome;
        //set the winner (if there is one)

        if (_outcome == MatchStatus.Decided) {
            theMatch.winner = _winner;
            theMatch.firstScorer = _firstScorer;
            theMatch.scoreline = _scoreline;
        }
    }

    /// @notice gets the unique ids of all pending matches, in reverse chronological order
    /// @return an array of unique match ids
    function getPendingMatches() public view returns (bytes32[]) {
        uint256 count = 0;

        //get count of pending matches
        for (uint256 i = 0; i < matches.length; i++) {
            if (matches[i].outcome == MatchStatus.Pending) count++;
        }

        //collect up all the pending matches
        bytes32[] memory output = new bytes32[](count);

        if (count > 0) {
            uint256 index = 0;
            for (uint256 n = matches.length; n > 0; n--) {
                if (matches[n - 1].outcome == MatchStatus.Pending)
                    output[index++] = matches[n - 1].matchId;
            }
        }

        return output;
    }

    /// @notice gets the unique ids of matches, pending and decided, in reverse chronological order
    /// @return an array of unique match ids
    function getAllMatches() public view returns (bytes32[]) {
        bytes32[] memory output = new bytes32[](matches.length);

        //get all ids
        if (matches.length > 0) {
            uint256 index = 0;
            for (uint256 n = matches.length; n > 0; n--) {
                output[index++] = matches[n - 1].matchId;
            }
        }

        return output;
    }

    /// @notice gets the specified match
    /// @param _matchId the unique id of the desired match
    /// @return match data
    function getMatch(bytes32 _matchId)
        public
        view
        returns (
            bytes32 matchId,
            string matchName,
            string players,
            uint256 startTime,
            uint256 endTime,
            string winner,
            string firstScorer,
            string scoreline,
            MatchStatus outcome
        )
    {
        //get the match
        if (matchExists(_matchId)) {
            Match storage theMatch = matches[_getMatchIndex(_matchId)];
            return (
                theMatch.matchId,
                theMatch.matchName,
                theMatch.players,
                theMatch.startTime,
                theMatch.endTime,
                theMatch.winner,
                theMatch.firstScorer,
                theMatch.scoreline,
                theMatch.outcome
            );
        } else {
            //match does not exist
            return (_matchId, "", "", 0, 0, "", "", "", MatchStatus.Pending);
        } //function addMatch(string _matchName, string _players, uint _startTime, uint _endTime, string _firstScorer, string _scoreline)
    }

    /// @notice gets the most recent match or pending match
    /// @param _pending if true, will return only the most recent pending match; otherwise, returns the most recent match either pending or completed
    /// @return match data
    function getMostRecentMatch(bool _pending)
        public
        view
        returns (
            bytes32 matchId,
            string matchName,
            string players,
            uint256 startTime,
            uint256 endTime,
            string winner,
            string firstScorer,
            string scoreline,
            MatchStatus outcome
        )
    {
        bytes32 requestedMatchId = 0;
        bytes32[] memory ids;

        if (_pending) {
            ids = getPendingMatches();
        } else {
            ids = getAllMatches();
        }
        if (ids.length > 0) {
            requestedMatchId = ids[0];
        }

        //by default, return a null match
        return getMatch(requestedMatchId);
    }

    /// @notice can be used by a client contract to ensure that they've connected to this contract interface successfully
    /// @return true, unconditionally
    function testConnection() public pure returns (bool) {
        return true;
    }

    /// @notice gets the address of this contract
    /// @return address
    function getAddress() public view returns (address) {
        return this;
    }

    /// @notice for testing
    function addTest() public onlyOwner {
        // Note that results are not determined yet when addMatch() is done
        addMatch(
            "Team A vs Team B",
            "playerA, playerB, playerC",
            DateLib.DateTime(2018, 8, 16, 5, 5, 0, 0, 0).toUnixTimestamp(),
            DateLib.DateTime(2018, 8, 16, 7, 5, 0, 0, 0).toUnixTimestamp()
        );
        addMatch(
            "Macquiao vs Payweather",
            "playerD, playerE, playerF",
            DateLib.DateTime(2018, 8, 15, 6, 6, 0, 0, 0).toUnixTimestamp(),
            DateLib.DateTime(2018, 8, 15, 8, 6, 0, 0, 0).toUnixTimestamp()
        );
        emit addedTest();
    }

    function getOwner() public view returns (address) {
        return owner;
    }

    //setter: new function to manually input current time
    //getter: returns current time

    //setter: add another function to update matchstatus based on endtime
    function setCurrentTime(uint16 _yyyy, uint8 _mnth, uint8 _day, uint8 _hr, uint8 _min) external onlyOwner {
        currentTime = DateLib.DateTime(_yyyy, _mnth, _day, _hr, _min, 0, 0, 0).toUnixTimestamp();
        emit addedTime();
    }

    function getCurrentTime() public view returns (uint) {
        return currentTime;
    }

    function updateMatchStatus(bytes32 _matchId) external onlyOwner{
        //require that it exists
        require(matchExists(_matchId), "matchId does not exist"); 
        //get the match 
        uint index = _getMatchIndex(_matchId);
        Match storage theMatch = matches[index]; 
        //Update matchstatus based on current time and start/end times
        if(currentTime < theMatch.startTime){
            theMatch.outcome = MatchStatus.Pending;
            emit matchPending();
        }else if(currentTime > theMatch.endTime){
            theMatch.outcome = MatchStatus.Decided;
            emit matchDecided();
        }else {
            theMatch.outcome = MatchStatus.Underway;
            emit matchUnderway();
        }
    }
}

//function addMatch(string _matchName, string _players, uint _startTime, uint _endTime, string _firstScorer, string _scoreline)
