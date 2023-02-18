pragma solidity ^0.4.26;

contract OracleInterface {
    enum MatchStatus {
        Pending, //match has not been fought to decision
        Underway, //match has started & is underway
        Draw, //anything other than a clear winner (e.g. cancelled)
        Decided, //index of participant who is the winner
        Cancelled   //match was cancelled; there's no winner 
    }

    function getPendingMatches() public view returns (bytes32[]);

    function getAllMatches() public view returns (bytes32[]);

    function matchExists(bytes32 _matchId) public view returns (bool);

    function addMatch(string _matchName, string _players, uint _startTime, uint _endTime) public returns (bytes32);

    function setMatchUnderway(bytes32 _matchId) external; 

    function setMatchCancelled(bytes32 _matchId) external; 

    function declareOutcome(bytes32 _matchId, MatchStatus _outcome, string _winner, string _firstScorer, string _scoreline) external; 

    function getMatch(bytes32 _matchId) public view returns (
        bytes32 matchId, //id
        string matchName, //name
        string players, //participants,
        uint256 startTime, //
        uint256 endTime, // date, 
        string winner, //winner
        string firstScorer,
        string scoreline,
        MatchStatus outcome);

    function getMostRecentMatch(bool _pending) public view returns (
        bytes32 matchId,
        string matchName,
        string players,
        uint256 startTime,
        uint256 endTime,
        string winner,
        string firstScorer,
        string scoreline,
        MatchStatus outcome);

    function testConnection() public pure returns (bool);

    function addTest() public;
}