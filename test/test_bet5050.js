const _deploy_contracts = require("../migrations/2_deploy_contracts");
const truffleAssert = require("truffle-assertions");
var assert = require("assert");

var Oracle = artifacts.require("../contracts/Oracle.sol");
var bet5050 = artifacts.require("../contracts/Bet5050.sol");

contract("Bet5050", function (accounts) {
  before(async () => {
    oracleInstance = await Oracle.deployed();
    bet5050Instance = await bet5050.deployed();
  });
  console.log("Testing Oracle Contract");

  it("1: Check address", async () => {
    let getAddress = await oracleInstance.getOwner();
    assert.strictEqual(getAddress, accounts[0]);

    let testConnection = await oracleInstance.testConnection();
    assert.strictEqual(testConnection, true);
  });

  it("2: Check dummy data is added", async () => {
    // non-owner attempt to add
    let checkMatchesArray = await oracleInstance.getAllMatches();
    assert.strictEqual(checkMatchesArray.length, 0);

    try {
      let nonOwnerAddData = await oracleInstance.addTest({ from: accounts[1] });
      assert.fail("should have thrown an error");
    } catch (error) {
      assert.equal(error.data.name, "RuntimeError");
    }
    checkMatchesArray = await oracleInstance.getAllMatches();
    assert.strictEqual(checkMatchesArray.length, 0);

    // owner attempt to add
    let addTest = await oracleInstance.addTest({ from: accounts[0] });
    truffleAssert.eventEmitted(addTest, "addedTest");
    truffleAssert.eventEmitted(addTest, "matchAdded");

    checkMatchesArray = await oracleInstance.getAllMatches();
    assert.strictEqual(checkMatchesArray.length, 2);

    let match1Data = await oracleInstance.getMatch(checkMatchesArray[0]);
    assert.strictEqual(match1Data.matchName, "Macquiao vs Payweather");
    assert.strictEqual(match1Data.players, "playerD, playerE, playerF");

    let match2Data = await oracleInstance.getMatch(checkMatchesArray[1]);
    assert.strictEqual(match2Data.matchName, "Team A vs Team B");
    assert.strictEqual(match2Data.players, "playerA, playerB, playerC");
  });

  it("3: Misc. functions", async () => {
    checkMatchesArray = await oracleInstance.getAllMatches();
    assert.strictEqual(checkMatchesArray.length, 2);

    let checkMatch1 = await oracleInstance.matchExists(checkMatchesArray[0]);
    assert.strictEqual(checkMatch1, true);

    let checkMatch2 = await oracleInstance.matchExists(checkMatchesArray[1]);
    assert.strictEqual(checkMatch2, true);

    // getMostRecentMatch gets the latest added match
    let recentMatchData = await oracleInstance.getMostRecentMatch(true);
    assert.strictEqual(recentMatchData.matchName, "Macquiao vs Payweather");
    assert.strictEqual(recentMatchData.players, "playerD, playerE, playerF");
  });

  it("4: Adjusting match statuses", async () => {
    checkMatchesArray = await oracleInstance.getAllMatches();
    assert.strictEqual(checkMatchesArray.length, 2);

    let setMatch1 = await oracleInstance.setMatchUnderway(checkMatchesArray[0]);
    truffleAssert.eventEmitted(setMatch1, "matchUnderway");

    try {
      setMatch1 = await oracleInstance.setMatchCancelled(checkMatchesArray[0]);
      assert.fail("should have thrown an error");
    } catch (error) {
      assert.strictEqual(
        error.reason,
        "addMatch() not executed for the Match or Match already underway"
      );
    }

    let checkMatchesArrayPending = await oracleInstance.getPendingMatches();
    assert.strictEqual(checkMatchesArrayPending.length, 1);

    let setMatch2 = await oracleInstance.setMatchCancelled(
      checkMatchesArray[1]
    );
    truffleAssert.eventEmitted(setMatch2, "matchCancelled");

    checkMatchesArrayPending = await oracleInstance.getPendingMatches();
    assert.strictEqual(checkMatchesArrayPending.length, 0);

    checkMatchesArray = await oracleInstance.getAllMatches();
    assert.strictEqual(checkMatchesArray.length, 2);
    // at this point, checkMatchesArray[0] is underway and checkMatchesArray[1] is cancelled
  });

  it("5: Test outcome", async () => {
    try {
      setMatch2 = await oracleInstance.declareOutcome(
        checkMatchesArray[1],
        3,
        "Team A",
        "playerA",
        "1-3"
      );
      assert.fail("should have thrown an error");
    } catch (error) {
      assert.strictEqual(error.reason, "Match is not underway");
    }

    setMatch1 = await oracleInstance.declareOutcome(
      checkMatchesArray[0],
      3,
      "Macquiao",
      "playerE",
      "1-3"
    );
    match1Data = await oracleInstance.getMatch(checkMatchesArray[0]);
    assert.strictEqual(match1Data.winner, "Macquiao");
    assert.strictEqual(match1Data.firstScorer, "playerE");
    assert.strictEqual(match1Data.scoreline, "1-3");
  });

  it("6: Test add time and match status update", async () => {
    let addtime = await oracleInstance.setCurrentTime(2018, 8, 15, 5, 5); //before start time
    truffleAssert.eventEmitted(addtime, "addedTime");
  });

  it("7: Test update match status on time", async () => {
    let match1Data = await oracleInstance.updateMatchStatus(
      checkMatchesArray[0]
    ); //start time : (2018, 8, 15, 6, 6, 0, 0, 0). endtime: (2018, 8, 15, 8, 6, 0, 0, 0)
    truffleAssert.eventEmitted(match1Data, "matchPending");
    //       assert.strictEqual(match1Data.MatchStatus, oracleInstance.MatchStatus.Pending);
  });

  it("8: test address", async () => {
    let oracleAddress = await oracleInstance.getAddress();
    let result = await bet5050Instance.setOracleAddress(oracleAddress);
    let checkAddress = await bet5050Instance.getOracleAddress();
    assert.strictEqual(oracleAddress, checkAddress, "Wrong Oracle Address");
  });

  // 2. Test getMatches. Call oracle addMatch, record the returned matchId and match information. Compare the result of getMatch with match information recorded.
  //returns matchid
  it("9: test getMatches", async () => {
    // let a = await oracleInstance.addMatch("Team A vs Team B",
    // "playerA, playerB, playerC",
    // 1649413857,
    // 1649413857);
    let match1Data = await bet5050Instance.getMatch(checkMatchesArray[0]);
    assert.strictEqual(match1Data.matchName, "Macquiao vs Payweather");
    assert.strictEqual(match1Data.players, "playerD, playerE, playerF");

    let match2Data = await bet5050Instance.getMatch(checkMatchesArray[1]);
    assert.strictEqual(match2Data.matchName, "Team A vs Team B");
    assert.strictEqual(match2Data.players, "playerA, playerB, playerC");
  });

  it("10: Test placeBet on a match that has not started", async () => {
    //test placebet
    try {
      await bet5050Instance.placeBet(0, "Winner", "Team A");
      assert.fail("Should have error msg");
    } catch (error) {
      error.reason, "Match does not exist", "Wrong error msg";
    }
  });

  //truffleAssert.eventEmitted(placedBet, "betPlaced");

  it("11: Test placeBet on a match that has already started", async () => {
    //test placebet
    let setMatch1 = await oracleInstance.setMatchUnderway(checkMatchesArray[0]);
    truffleAssert.eventEmitted(setMatch1, "matchUnderway");

    try {
      await bet5050Instance.placeBet(0, "Winner", "Team A");
      assert.fail("Should have error msg");
    } catch (error) {
      error.reason, "Match is underway", "Wrong error msg";
    }
  });

  it("12: Test placeBet on a match that dont exist", async () => {
    //test placebet
    try {
      await bet5050Instance.placeBet(55, "Winner", "Team A");
      assert.fail("Should have error msg");
    } catch (error) {
      error.reason, "Match does not exist", "Wrong error msg";
    }
  });

  it("13: Test placeBet on a match type that dont exist", async () => {
    //test placebet
    try {
      await bet5050Instance.placeBet(0, "Most Yellow Card", "Team A");
      assert.fail("Should have error msg");
    } catch (error) {
      ("Bet item invalid");
      "Bet item", "Wrong error msg";
    }
  });

  it("14: Test add match", async () => {
    let newMatch = await oracleInstance.addMatch(
      "Liverpool vs Chelsea",
      "MoSalah,SadioMane,Lukaku,Kante",
      1650638882,
      1650646082,
      { from: accounts[0] }
    );
    truffleAssert.eventEmitted(newMatch, "matchAdded");

    let checkMatchesArray = await oracleInstance.getAllMatches();
    let liverpoolvschelseaData = await oracleInstance.getMatch(
      checkMatchesArray[0]
    );

    assert.equal(liverpoolvschelseaData.matchName, "Liverpool vs Chelsea");
  });

  //get all matches -> get matchId of liverpoolvschelsea -> place bet on winner
  it("15: Test placebet on winner type", async () => {
    //get all matches
    let checkMatchesArray = await oracleInstance.getAllMatches();

    let liverpoolvschelseaData = await oracleInstance.getMatch(
      checkMatchesArray[0]
    );
    // console.log(liverpoolvschelseaData)
    let account2Bet = await bet5050Instance.placeBet(
      liverpoolvschelseaData.matchId,
      "Winner",
      "Liverpool",
      { from: accounts[1], value: 2e18 }
    );
    truffleAssert.eventEmitted(account2Bet, "betPlaced");

    let account3Bet = await bet5050Instance.placeBet(
      liverpoolvschelseaData.matchId,
      "Winner",
      "Chelsea",
      { from: accounts[2], value: 2e18 }
    );
    truffleAssert.eventEmitted(account3Bet, "betPlaced");
  });

  it("16: Test check outcome of winner type - Liverpool", async () => {
    let checkMatchesArray = await oracleInstance.getAllMatches();
    let liverpoolvschelseaData = await oracleInstance.getMatch(
      checkMatchesArray[0]
    );
    assert.equal(liverpoolvschelseaData.matchName, "Liverpool vs Chelsea");

    let setMatch1 = await oracleInstance.setMatchUnderway(checkMatchesArray[0]);
    truffleAssert.eventEmitted(setMatch1, "matchUnderway");

    let setMatch1Outcome = await oracleInstance.declareOutcome(
      checkMatchesArray[0],
      3,
      "Liverpool",
      "MoSalah",
      "2-1"
    );

    checkMatchesArray = await oracleInstance.getAllMatches();
    liverpoolvschelseaData = await oracleInstance.getMatch(
      checkMatchesArray[0]
    );
    assert.equal(liverpoolvschelseaData.winner, "Liverpool");

    let balance1 = await web3.eth.getBalance(accounts[1]);
    let balance2 = await web3.eth.getBalance(accounts[2]);

    let outcome = await bet5050Instance.checkOutcome(
      liverpoolvschelseaData.matchId,
      { from: accounts[0] }
    );
    truffleAssert.eventEmitted(outcome, "WinnerOutcome");

    let newBalance1 = await web3.eth.getBalance(accounts[1]);
    let newBalance2 = await web3.eth.getBalance(accounts[2]);
    assert.notEqual(newBalance1, balance1);
    assert.equal(newBalance2, balance2);

  });


  //test outcome and payout for scoreline type
  //bettor 3 wins - account[2]
  it("17: Test check outcome of scoreline type - 1-1", async () => {
    let newMatch = await oracleInstance.addMatch(
      "Liverpool vs ManU",
      "MoSalah,SadioMane,Ronaldo,Maguire",
      1650638882,
      1650646082,
      { from: accounts[0] }
    );

    let checkMatchesArray = await oracleInstance.getAllMatches();

    let liverpoolvsmanuData = await oracleInstance.getMatch(
      checkMatchesArray[0]
    );

    let account2Bet = await bet5050Instance.placeBet(
      liverpoolvsmanuData.matchId,
      "Scoreline",
      "1-0",
      { from: accounts[1], value: 2e18 }
    );
    truffleAssert.eventEmitted(account2Bet, "betPlaced");

    let account3Bet = await bet5050Instance.placeBet(
      liverpoolvsmanuData.matchId,
      "Scoreline",
      "0-1",
      { from: accounts[2], value: 2e18 }
    );

    let account4Bet = await bet5050Instance.placeBet(
      liverpoolvsmanuData.matchId,
      "Scoreline",
      "0-2",
      { from: accounts[3], value: 2e18 }
    );

    truffleAssert.eventEmitted(account3Bet, "betPlaced");

    let setMatch1 = await oracleInstance.setMatchUnderway(checkMatchesArray[0]);
    truffleAssert.eventEmitted(setMatch1, "matchUnderway");

    let setMatch2Outcome = await oracleInstance.declareOutcome(
      checkMatchesArray[0],
      3,
      "manU",
      "Ronaldo",
      "0-1"
    );

    checkMatchesArray = await oracleInstance.getAllMatches();
    liverpoolvsmanuData = await oracleInstance.getMatch(checkMatchesArray[0]);

    assert.equal(liverpoolvsmanuData.winner, "manU");

    let balance1 = await web3.eth.getBalance(accounts[1]);
    let balance2 = await web3.eth.getBalance(accounts[2]);
    let balance3 = await web3.eth.getBalance(accounts[3]);

    let outcome = await bet5050Instance.checkOutcome(
      liverpoolvsmanuData.matchId,
      { from: accounts[0] }
    );
    truffleAssert.eventEmitted(outcome, "ScorelineOutcome");
    let newBalance1 = await web3.eth.getBalance(accounts[1]);
    let newBalance2 = await web3.eth.getBalance(accounts[2]);
    let newBalance3 = await web3.eth.getBalance(accounts[3]);
    assert.notEqual(newBalance2, balance2);
    assert.equal(newBalance1, balance1);
    assert.equal(newBalance3, balance3);

  });


  //test outcome and payout for firstscorer type
  //bettor 4 wins - account[3]
  it("18: Test check outcome of firstScorer type - messi", async () => {
    let newMatch = await oracleInstance.addMatch(
      "Liverpool vs PSG",
      "MoSalah,SadioMane,Messi,Neymar",
      1650638882,
      1650646082,
      { from: accounts[0] }
    );

    let checkMatchesArray = await oracleInstance.getAllMatches();

    let liverpoolvspsgData = await oracleInstance.getMatch(
      checkMatchesArray[0]
    );

    let account2Bet = await bet5050Instance.placeBet(
      liverpoolvspsgData.matchId,
      "FirstScorer",
      "Neymar",
      { from: accounts[1], value: 2e18 }
    );
    truffleAssert.eventEmitted(account2Bet, "betPlaced");

    let account3Bet = await bet5050Instance.placeBet(
      liverpoolvspsgData.matchId,
      "FirstScorer",
      "Neymar",
      { from: accounts[2], value: 2e18 }
    );

    let account4Bet = await bet5050Instance.placeBet(
      liverpoolvspsgData.matchId,
      "FirstScorer",
      "Messi",
      { from: accounts[3], value: 2e18 }
    );

    truffleAssert.eventEmitted(account3Bet, "betPlaced");

    let setMatch1 = await oracleInstance.setMatchUnderway(checkMatchesArray[0]);
    truffleAssert.eventEmitted(setMatch1, "matchUnderway");

    let setMatch2Outcome = await oracleInstance.declareOutcome(
      checkMatchesArray[0],
      3,
      "PSG",
      "Messi",
      "0-1"
    );

    checkMatchesArray = await oracleInstance.getAllMatches();
    liverpoolvspsgData = await oracleInstance.getMatch(checkMatchesArray[0]);

    assert.equal(liverpoolvspsgData.winner, "PSG");

    let balance1 = await web3.eth.getBalance(accounts[1]);
    let balance2 = await web3.eth.getBalance(accounts[2]);
    let balance3 = await web3.eth.getBalance(accounts[3]);

    let outcome = await bet5050Instance.checkOutcome(
      liverpoolvspsgData.matchId,
      { from: accounts[0] }
    );
    truffleAssert.eventEmitted(outcome, "FirstscorerOutcome");
    let newBalance1 = await web3.eth.getBalance(accounts[1]);
    let newBalance2 = await web3.eth.getBalance(accounts[2]);
    let newBalance3 = await web3.eth.getBalance(accounts[3]);
    assert.equal(newBalance1, balance1);
    assert.equal(newBalance2, balance2);
    assert.notEqual(newBalance3, balance3);
  });
});
