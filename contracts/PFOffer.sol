/*
This file is part of the DAO.

The DAO is free software: you can redistribute it and/or modify
it under the terms of the GNU lesser General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

The DAO is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU lesser General Public License for more details.

You should have received a copy of the GNU lesser General Public License
along with the DAO.  If not, see <http://www.gnu.org/licenses/>.
*/


/*
  An Offer from a Contractor to the DAO without any reward going back to
  the DAO.

  Feel free to use as a template for your own proposal.

  Actors:
  - Offerer:    the entity that creates the Offer. Usually it is the initial
                Contractor.
  - Contractor: the entity that has rights to withdraw ether to perform
                its project.
  - Client:     the DAO that gives ether to the Contractor. It signs off
                the Offer, can adjust daily withdraw limit or even fire the
                Contractor.

  -- Important Note For Compilation --
  This contract also reads from the DAO's proposal struct array. There used to
  be a solidity bug (https://github.com/ethereum/solidity/issues/598#issuecomment-224015639)
  that is now fixed which would result in wrong values when reading from the
  proposals array.

  Use a solc that includes commit:  0a0fc04641787ce057a9fcc9e366ea898b1fd8d6
  to be sure that the contract is compiled with the fix and that the proposals
  member attributes are read correctly. This comment will be updated as soon
  as the fix makes it into a solc release.
*/

import "./DAO.sol";

// Davy

pragma solidity ^0.8.21;

contract PFOffer {

    // Period of time after which money can be withdrawn from this contract
    uint constant payoutFreezePeriod = 18 days;
    // Time before the end of the voting period after which
    // checkVoteStatus() can no longer be called
    uint constant voteStatusDeadline = 48 hours;
    // Time before the proposal can get executed. This allows token holders
    // to split after they have voted.
    uint constant splitGracePeriod = 8 days;

    // The total cost of the Offer for the Client. Exactly this amount is
    // transfered from the Client to the Offer contract when the Offer is
    // accepted by the Client. Set once by the Offerer.
    uint totalCost;

    // Initial withdrawal to the Contractor. It is done the moment the
    // Offer is accepted. Set once by the Offerer.
    uint initialWithdrawal;
    bool initialWithdrawalDone;

    // The minimum daily withdrawal limit that the Contractor accepts.
    // Set once by the Offerer.
    uint128 minDailyWithdrawalLimit;

    // The amount of wei the Contractor has right to withdraw daily above the
    // initial withdrawal. The Contractor does not have to perform the
    // withdrawals every day as this amount accumulates.
    uint128 dailyWithdrawalLimit;

    // The address of the Contractor.
    address contractor;

    // The hash of the Proposal/Offer document.
    bytes32 hashOfTheProposalDocument;

    // The time of the last withdrawal to the Contractor.
    uint lastWithdrawal;

    // The timestamp when the offer contract was accepted.
    uint dateOfSignature;
    // The address of the current Client.
    DAO client;
    // The address of the Client who accepted the Offer.
    DAO originalClient;
    bool isContractValid;
    // The ID of the proposal that represents this contract in the DAO
    uint proposalID;
    bool wasApprovedBeforeDeadline;

    modifier onlyClient {
        assert(! (msg.sender != address(client))); 
            
        _;
    }
    modifier onlyContractor {
        assert(! (msg.sender != address(contractor))); 
           
        _;
    }

    // Prevents methods from perfoming any value transfer
    modifier noEther() {assert(! (msg.value > 0));  _;}

   constructor(
        address _contractor,
        address _client,
        bytes32 _hashOfTheProposalDocument,
        uint _totalCost,
        uint _initialWithdrawal,
        uint128 _minDailyWithdrawalLimit
    ) {
        contractor = _contractor;
        originalClient = DAO(_client);
        client = DAO(_client);
        hashOfTheProposalDocument = _hashOfTheProposalDocument;
        totalCost = _totalCost;
        initialWithdrawal = _initialWithdrawal;
        minDailyWithdrawalLimit = _minDailyWithdrawalLimit;
        dailyWithdrawalLimit = _minDailyWithdrawalLimit;
    }

    // non-value-transfer getters
    function getTotalCost() noEther public view returns (uint) {
        return totalCost;
    }

    function getInitialWithdrawal() noEther public view returns (uint) {
        return initialWithdrawal;
    }

    function getMinDailyWithdrawalLimit() noEther public view returns (uint128) {
        return minDailyWithdrawalLimit;
    }

    function getDailyWithdrawalLimit() noEther public view returns (uint128) {
        return dailyWithdrawalLimit;
    }

    function getContractor() noEther public view returns (address) {
        return contractor;
    }

    function getHashOfTheProposalDocument() noEther public view returns (bytes32) {
        return hashOfTheProposalDocument;
    }

    function getLastWithdrawal() noEther public view returns (uint) {
        return lastWithdrawal;
    }

    function getDateOfSignature() noEther public view returns (uint) {
        return dateOfSignature;
    }

    function getClient() noEther public view returns (DAO) {
        return client;
    }

    function getOriginalClient() noEther public view returns (DAO) {
        return originalClient;
    }

    function getIsContractValid() noEther public view returns (bool) {
        return isContractValid;
    }

    function getInitialWithdrawalDone() noEther public view returns (bool) {
        return initialWithdrawalDone;
    }

    function getWasApprovedBeforeDeadline() noEther public view returns (bool) {
        return wasApprovedBeforeDeadline;
    }

    function getProposalID() noEther public view returns (uint) {
        return proposalID;
    }

    function sign() public {
        (address _unused,,,uint votingDeadline,,) = client.proposals(proposalID);
        assert(!  (msg.sender != address(originalClient) // no good samaritans give us ether
            || msg.value != totalCost    // no under/over payment
            || dateOfSignature != 0       // don't sign twice
            || !wasApprovedBeforeDeadline // fail if the voteStatusCheck was not done
            || now < votingDeadline + splitGracePeriod) // allow splitting within the split grace period
             );
            

        dateOfSignature = now;
        isContractValid = true;
        lastWithdrawal = now + payoutFreezePeriod;
    }

    function setDailyWithdrawLimit(uint128 _dailyWithdrawalLimit) onlyClient noEther public {
        if (_dailyWithdrawalLimit >= minDailyWithdrawalLimit)
            dailyWithdrawalLimit = _dailyWithdrawalLimit;
    }

    // Terminate the ongoing Offer.
    //
    // The Client can terminate the ongoing Offer using this method. Using it
    // on an invalid (balance 0) Offer has no effect. The Contractor loses
    // right to any ether left in the Offer.
    function terminate() noEther onlyClient public {
        if (originalClient.DAOrewardAccount().call.value(this.balance)())
            isContractValid = false;
    }

    // Withdraw to the Contractor.
    //
    // Withdraw the amount of ether the Contractor has right to according to
    // the current withdraw limit.
    // Executing this function before the Offer is signed off by the Client
    // makes no sense as this contract has no ether.
    function withdraw() noEther public {
        assert(! (msg.sender != contractor || now < dateOfSignature + payoutFreezePeriod)); 
           
        uint timeSinceLastPayment = now - lastWithdrawal;
        // Calculate the amount using 1 second precision.
        uint amount = (timeSinceLastPayment * dailyWithdrawalLimit) / (1 days);
        if (amount > this.balance) {
            amount = this.balance;
        }
        uint lastWithdrawalReset = lastWithdrawal;
        lastWithdrawal = now;
        if (!contractor.send(amount))
            lastWithdrawal = lastWithdrawalReset;
    }

    // Perform the withdrawal of the initial sum of money to the contractor
    function performInitialWithdrawal() noEther public {
        assert(! (msg.sender != contractor
            || now < dateOfSignature + payoutFreezePeriod
            || initialWithdrawalDone ));  

        initialWithdrawalDone = true;
        assert(! (!contractor.send(initialWithdrawal))); 
            
    }

    // Once a proposal is submitted, the Contractor should call this
    // function to register its proposal ID with the offer contract
    // so that the vote can be watched and checked with `checkVoteStatus()`
    function watchProposal(uint _proposalID) noEther onlyContractor public {
        ( address recipient,,, uint votingDeadline, bool open,) = client.proposals(_proposalID);
        if (recipient == address(this)
            && votingDeadline > now
            && open
            && proposalID == 0) {
            proposalID =  _proposalID;
        }
    }

    // The proposal will not accept the results of the vote if it wasn't able
    // to be sure that YEA was able to succeed 48 hours before the deadline
    function checkVoteStatus() noEther public {
         (,,,uint votingDeadline,,,,,,uint yea,uint nay,) = client.proposals(proposalID);
        uint quorum = yea * 100 / client.totalSupply();

        // Only execute until 48 hours before the deadline
         assert(! (now > votingDeadline - voteStatusDeadline));
        // If quorum is met and majority is for it then the prevote
        // check can be considered as succesfull
        wasApprovedBeforeDeadline = (quorum >= 100 / client.minQuorumDivisor() && yea > nay);
    }

    // Change the client DAO by giving the new DAO's address
    // warning: The new DAO must come either from a split of the original
    // DAO or an update via `newContract()` so that it can claim rewards
    function updateClientAddress(DAO _newClient) onlyClient noEther public {
        client = _newClient;
    }

    fallback () public {
        assert(); // this is a business contract, no donations
    }
}
