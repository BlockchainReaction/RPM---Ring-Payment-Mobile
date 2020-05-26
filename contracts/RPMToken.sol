pragma solidity ^0.4.10;
import "./StandardToken.sol";
import "./SafeMath.sol";

contract RPMToken is StandardToken, SafeMath {

    // metadata
    string public constant name = "Ring Payment Mobile";
    string public constant symbol = "RPM";
    uint256 public constant decimals = 18;
    string public version = "1.0";

    // contracts
    address public ethFundDeposit;      // deposit address for ETH for Brave International
    address public rpmFundDeposit;      // deposit address for Brave International use and RPM User Fund

    // crowdsale parameters
    bool public isFinalized;              // switched to true in operational state
    uint256 public fundingStartBlock;
    uint256 public fundingEndBlock;
    uint256 public constant rpmFund = 500 * (10**6) * 10**decimals;   // 500m RPM reserved for Brave Intl use
    uint256 public constant tokenExchangeRate = 6400; // 6400 RPM tokens per 1 ETH
    uint256 public constant tokenCreationCap =  1500 * (10**6) * 10**decimals;
    uint256 public constant tokenCreationMin =  675 * (10**6) * 10**decimals;


    // events
    event LogRefund(address indexed _to, uint256 _value);
    event CreateRPM(address indexed _to, uint256 _value);

    // constructor
    function RPMToken(
        address _ethFundDeposit,
        address _rpmFundDeposit,
        uint256 _fundingStartBlock,
        uint256 _fundingEndBlock)
    {
      isFinalized = false;                   //controls pre through crowdsale state
      ethFundDeposit = _ethFundDeposit;
      rpmFundDeposit = _rpmFundDeposit;
      fundingStartBlock = _fundingStartBlock;
      fundingEndBlock = _fundingEndBlock;
      totalSupply = rpmFund;
      balances[rpmFundDeposit] = rpmFund;    // Deposit Ring Intl share
      CreateRPM(rpmFundDeposit, rpmFund);  // logs Ring Intl fund
    }

    /// @dev Accepts ether and creates new RPM tokens.
    function createTokens() payable external {
      if (isFinalized) throw;
      if (block.number < fundingStartBlock) throw;
      if (block.number > fundingEndBlock) throw;
      if (msg.value == 0) throw;

      uint256 tokens = safeMult(msg.value, tokenExchangeRate); // check that we're not over totals
      uint256 checkedSupply = safeAdd(totalSupply, tokens);

      // return money if something goes wrong
      if (tokenCreationCap < checkedSupply) throw;  // odd fractions won't be found

      totalSupply = checkedSupply;
      balances[msg.sender] += tokens;  // safeAdd not needed; bad semantics to use here
      CreateRPM(msg.sender, tokens);  // logs token creation
    }

    /// @dev Ends the funding period and sends the ETH home
    function finalize() external {
      if (isFinalized) throw;
      if (msg.sender != ethFundDeposit) throw; // locks finalize to the ultimate ETH owner
      if(totalSupply < tokenCreationMin) throw;      // have to sell minimum to move to operational
      if(block.number <= fundingEndBlock && totalSupply != tokenCreationCap) throw;
      // move to operational
      isFinalized = true;
      if(!ethFundDeposit.send(this.balance)) throw;  // send the eth to Ring International
    }

    /// @dev Allows contributors to recover their ether in the case of a failed funding campaign.
    function refund() external {
      if(isFinalized) throw;                       // prevents refund if operational
      if (block.number <= fundingEndBlock) throw; // prevents refund until sale period is over
      if(totalSupply >= tokenCreationMin) throw;  // no refunds if we sold enough
      if(msg.sender == rpmFundDeposit) throw;    // Brave Intl not entitled to a refund
      uint256 rpmVal = balances[msg.sender];
      if (rpmVal == 0) throw;
      balances[msg.sender] = 0;
      totalSupply = safeSubtract(totalSupply, rpmVal); // extra safe
      uint256 ethVal = rpmVal / tokenExchangeRate;     // should be safe; previous throws covers edges
      LogRefund(msg.sender, ethVal);               // log it
      if (!msg.sender.send(ethVal)) throw;       // if you're using a contract; make sure it works with .send gas limits
    }

}
