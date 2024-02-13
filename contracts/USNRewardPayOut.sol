import "./RewardOffer.sol";

// Davy

pragma solidity ^0.8.21;
contract USNRewardPayOut {

     RewardOffer public usnContract;

     constructor(RewardOffer _usnContract) {
          usnContract = _usnContract;
     }

     // interface for USN
     function payOneTimeReward() public returns(bool) {
         assert(! (msg.value < usnContract.getDeploymentReward())); 
            

        bool success = usnContract.getOriginalClient().DAOrewardAccount().call.value(msg.value)();
        assert(success);
        return true;

     }

     // pay reward
     function payReward() public returns(bool) {
        bool success = usnContract.getOriginalClient().DAOrewardAccount().call.value(msg.value)();
        assert(success);
        return true;

     }
}
