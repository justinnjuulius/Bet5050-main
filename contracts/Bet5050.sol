pragma solidity ^0.4.17;

import "./House.sol";
import "./SafeMath.sol";
import "./OracleInterface.sol";

contract Bet5050 is House {
    using SafeMath for uint256;

    //constants
    uint256 housePercentage = 1;
    uint256 multFactor = 1000000;

    event WinnerOutcome();
    event ScorelineOutcome();
    event FirstscorerOutcome();

    /// @notice pays out winnings to a user
    /// @param _user the user to whom to pay out
    /// @param _amount the amount to pay out
    function _payOutWinnings(address _user, uint256 _amount) private {
        _user.transfer(_amount);
    }

    /// @notice transfers any remaining to the house (the house's cut)
    function _transferToHouse() private {
        owner.transfer(address(this).balance);
    }

    /// @notice determines whether or not the given bet is a winner
    /// @param _status the match's actual outcome
    /// @param _chosenWinner the participant chosen by the bettor as the winner
    /// @param _actualWinner the actual winner
    /// @return true if the bet was a winner
    function _isWinningBet(
        OracleInterface.MatchStatus _status,
        string _chosenWinner,
        string _actualWinner
    ) private pure returns (bool) {
        return
            _status == OracleInterface.MatchStatus.Decided &&
            keccak256(abi.encodePacked(_chosenWinner)) ==
            keccak256(abi.encodePacked(_actualWinner));
    }

    /// @notice calculates the amount to be paid out for a bet of the given amount, under the given circumstances
    /// @param _winningTotal the total monetary amount of winning bets
    /// @param _totalPot the total amount in the pot for the match
    /// @param _betAmount the amount of this particular bet
    /// @return an amount in wei
    function _calculatePayout(
        uint256 _winningTotal,
        uint256 _totalPot,
        uint256 _betAmount
    ) private view returns (uint256) {
        //calculate proportion
        uint256 proportion = (_betAmount.mul(multFactor)).div(_winningTotal);

        //calculate raw share
        uint256 rawShare = _totalPot.mul(proportion).div(multFactor);

        //if share has been rounded down to zero, fix that
        if (rawShare == 0) rawShare = minimumBet;

        //take out house's cut
        rawShare = rawShare.sub(rawShare.div(100 * housePercentage));
        return rawShare;
    }

    /* 
        TODO: _winner is changed from uint to string, check the logic of related functions
    */
    /// @notice calculates how much to pay out to each winner, then pays each winner the appropriate amount
    /// @param _matchId the unique id of the match
    /// @param _status the match's outcome
    /// @param _winner the index of the winner of the match (if not a draw)
    function _payOutForMatchWinner(
        bytes32 _matchId,
        OracleInterface.MatchStatus _status,
        string _winner
    ) private {
        bytes32[] memory betIds = matchIdToBetIds_winner[_matchId];

        uint256 losingTotal = 0;
        uint256 winningTotal = 0;
        uint256 totalPot = 0;
        uint256[] memory payouts = new uint256[](betIds.length);

        //count winning bets & get total
        uint256 n;
        for (n = 0; n < betIds.length; n++) {
            uint256 amount = betIdToBets[betIds[n]].amount;
            if (
                _isWinningBet(_status, betIdToBets[betIds[n]].betItem, _winner)
            ) {
                winningTotal = winningTotal.add(amount);
            } else {
                losingTotal = losingTotal.add(amount);
            }
        }
        totalPot = (losingTotal.add(winningTotal));

        //calculate payouts per bet
        for (n = 0; n < betIds.length; n++) {
            if (_status == OracleInterface.MatchStatus.Draw) {
                payouts[n] = betIdToBets[betIds[n]].amount;
            } else {
                if (
                    _isWinningBet(
                        _status,
                        betIdToBets[betIds[n]].betItem,
                        _winner
                    )
                ) {
                    payouts[n] = _calculatePayout(
                        winningTotal,
                        totalPot,
                        betIdToBets[betIds[n]].amount
                    );
                } else {
                    payouts[n] = 0;
                }
            }
        }

        //pay out the payouts
        for (n = 0; n < payouts.length; n++) {
            _payOutWinnings(betIdToBets[betIds[n]].owner, payouts[n]);
        }

        //transfer the remainder to the owner
        _transferToHouse();
    }

    function _payOutForMatchFirstScorer(
        bytes32 _matchId,
        OracleInterface.MatchStatus _status,
        string _firstScorer
    ) private {
        bytes32[] memory betIds = matchIdToBetIds_firstScorer[_matchId];
        uint256 losingTotal = 0;
        uint256 winningTotal = 0;
        uint256 totalPot = 0;
        uint256[] memory payouts = new uint256[](betIds.length);

        //count winning bets & get total
        uint256 n;
        for (n = 0; n < betIds.length; n++) {
            uint256 amount = betIdToBets[betIds[n]].amount;
            if (
                _isWinningBet(
                    _status,
                    betIdToBets[betIds[n]].betItem,
                    _firstScorer
                )
            ) {
                winningTotal = winningTotal.add(amount);
            } else {
                losingTotal = losingTotal.add(amount);
            }
        }
        totalPot = (losingTotal.add(winningTotal));

        //calculate payouts per bet
        for (n = 0; n < betIds.length; n++) {
            if (
                _isWinningBet(
                    _status,
                    betIdToBets[betIds[n]].betItem,
                    _firstScorer
                )
            ) {
                payouts[n] = _calculatePayout(
                    winningTotal,
                    totalPot,
                    betIdToBets[betIds[n]].amount
                );
            } else {
                payouts[n] = 0;
            }
        }

        //pay out the payouts
        for (n = 0; n < payouts.length; n++) {
            _payOutWinnings(betIdToBets[betIds[n]].owner, payouts[n]);
        }

        //transfer the remainder to the owner
        _transferToHouse();
    }

    function _payOutForMatchScoreline(
        bytes32 _matchId,
        OracleInterface.MatchStatus _status,
        string _scoreline
    ) private {
        bytes32[] memory betIds = matchIdToBetIds_scoreline[_matchId];
        uint256 losingTotal = 0;
        uint256 winningTotal = 0;
        uint256 totalPot = 0;
        uint256[] memory payouts = new uint256[](betIds.length);

        //count winning bets & get total
        uint256 n;
        for (n = 0; n < betIds.length; n++) {
            uint256 amount = betIdToBets[betIds[n]].amount;
            if (
                _isWinningBet(
                    _status,
                    betIdToBets[betIds[n]].betItem,
                    _scoreline
                )
            ) {
                winningTotal = winningTotal.add(amount);
            } else {
                losingTotal = losingTotal.add(amount);
            }
        }
        totalPot = (losingTotal.add(winningTotal));

        //calculate payouts per bet
        for (n = 0; n < betIds.length; n++) {
            if (
                _isWinningBet(
                    _status,
                    betIdToBets[betIds[n]].betItem,
                    _scoreline
                )
            ) {
                payouts[n] = _calculatePayout(
                    winningTotal,
                    totalPot,
                    betIdToBets[betIds[n]].amount
                );
            } else {
                payouts[n] = 0;
            }
        }

        //pay out the payouts
        for (n = 0; n < payouts.length; n++) {
            _payOutWinnings(betIdToBets[betIds[n]].owner, payouts[n]);
        }

        //transfer the remainder to the owner
        _transferToHouse();
    }

    /// @notice check the outcome of the given match; if ready, will trigger calculation of payout, and actual payout to winners
    /// @param _matchId the id of the match to check
    /// @return the outcome of the given match
    function checkOutcome(bytes32 _matchId)
        public
        notDisabled
        returns (OracleInterface.MatchStatus)
    {
        //get match
        (
            , //id
            , //name
            , //participants,
            , //
            , // date,
            string memory winner,
            string memory firstScorer,
            string memory scoreline,
            OracleInterface.MatchStatus outcome
        ) = matchOracle.getMatch(_matchId);

        if (
            outcome == OracleInterface.MatchStatus.Decided &&
            !matchPaidOut[_matchId]
        ) {
            matchPaidOut[_matchId] = true;
            //payout for each type of bet
            if (matchIdToBetIds_winner[_matchId].length != 0) {
                emit WinnerOutcome();
                _payOutForMatchWinner(_matchId, outcome, winner);
            }
            if (matchIdToBetIds_firstScorer[_matchId].length != 0) {
                emit FirstscorerOutcome();

                _payOutForMatchFirstScorer(_matchId, outcome, firstScorer);
            }
            if (matchIdToBetIds_scoreline[_matchId].length != 0) {
                emit ScorelineOutcome();

                _payOutForMatchScoreline(_matchId, outcome, scoreline);
            }
        }

        return outcome;
    }
}
