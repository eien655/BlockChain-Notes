// SPDX-License-Identifier: MIT
// SPDX (Software Package Data Exchange) license identifier.
// This line specifies that the contract is released under the MIT License,
// which is a permissive open-source license allowing reuse with minimal restrictions.

pragma solidity ^0.8.20;
// Pragma directive tells the Solidity compiler which version of Solidity to use.
// Here, we're specifying version 0.8.20, ensuring compatibility and enabling
// features and safety checks introduced in this version.

// Importing Chainlink's AggregatorV3Interface.
// Chainlink provides decentralized oracle services, allowing smart contracts to
// interact with real-world data (like ETH/USD prices) securely.
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

/*
    Contract Overview:
    1. Allow users to contribute funds by sending ETH.
    2. Keep track of each contributor's total contributions.
    3. After a specified lock period:
        a. If the funding goal is met or exceeded, the owner can withdraw all funds.
        b. If the funding goal is not met, contributors can claim refunds of their contributions.
*/
contract SimpleFundraiser {
    // Mapping to track the amount contributed by each address.
    // 'address' represents an Ethereum address.
    // 'uint256' is an unsigned integer type that can store large numbers.
    // 'public' makes the mapping accessible from outside the contract.
    mapping(address => uint256) public contributorBalances;

    // Constant variable representing the minimum contribution amount required (in USD).
    // Constants cannot be changed once set, providing immutability.
    // '100 * 10 ** 18' scales the value by 10^18 to handle decimals, as Ethereum uses wei (1 ETH = 10^18 wei).
    uint256 constant MIN_CONTRIBUTION_USD = 100 * 10 ** 18; // USD

    // Instance of the AggregatorV3Interface to interact with Chainlink's price feeds.
    // 'internal' means it can only be accessed within this contract and contracts deriving from it.
    AggregatorV3Interface internal priceFeed;

    // Constant variable representing the funding goal (in USD).
    uint256 constant FUNDING_GOAL_USD = 1000 * 10 ** 18;

    // Address of the contract owner.
    // 'public' allows external access to this variable.
    address public owner;

    // Timestamp when the contract was deployed.
    uint256 public deploymentTime;

    // Duration (in seconds) for which the fundraising is active.
    uint256 public fundraisingDuration;

    // Address of an ERC20 token contract, if applicable.
    // ERC20 is a standard interface for fungible tokens on Ethereum.
    address public erc20TokenAddress;

    // Boolean flag indicating whether the owner has successfully withdrawn the funds.
    bool public fundsWithdrawn = false;

    /*
        Constructor:
        - Runs once when the contract is deployed.
        - Initializes the contract's state variables.
        - Sets the contract deployer as the owner.
        - Initializes the Chainlink price feed.
    */
    constructor(uint256 _fundraisingDuration) {
        // Setting the Chainlink price feed address.
        // This address is specific to the Sepolia testnet.
        // Each network (Mainnet, Ropsten, etc.) has its own price feed addresses.
        priceFeed = AggregatorV3Interface(0x694AA1769357215DE4FAC081bf1f309aDC325306);

        // 'msg.sender' refers to the address that deploys the contract.
        owner = msg.sender;

        // 'block.timestamp' gives the current block's timestamp (in seconds since Unix epoch).
        deploymentTime = block.timestamp;

        // Setting the fundraising duration based on the constructor argument.
        fundraisingDuration = _fundraisingDuration;
    }

    /*
        contribute Function:
        - Allows users to send ETH to the contract as contributions.
        - Ensures the sent ETH meets the minimum contribution requirement.
        - Ensures contributions are only possible during the fundraising period.
        - Records the contributor's address and the amount contributed.
    */
    function contribute() external payable {
        /*
            'external' means this function can be called from outside the contract.
            'payable' allows the function to receive ETH.
        */

        // Converts the sent ETH amount to USD and checks if it meets the minimum requirement.
        require(
            convertEthToUsd(msg.value) >= MIN_CONTRIBUTION_USD,
            "Minimum contribution is 100 USD worth of ETH."
        );
        // 'msg.value' is the amount of wei sent with the transaction.
        // 'require' ensures that a condition is met; otherwise, it reverts the transaction with an error message.

        // Ensures that the current time is before the end of the fundraising period.
        require(
            block.timestamp < deploymentTime + fundraisingDuration,
            "Fundraising period has ended."
        );

        // Records the contributor's address and the amount they sent.
        // If a contributor sends multiple transactions, this will accumulate their contributions.
        contributorBalances[msg.sender] += msg.value;
        // 'msg.sender' is the address calling the function.
    }

    /*
        getLatestEthPrice Function:
        - Fetches the latest ETH/USD price from the Chainlink price feed.
        - Returns the latest ETH/USD price.
    */
    function getLatestEthPrice() public view returns (int) {
        /*
            'public' allows external access to this function.
            'view' indicates that this function does not modify the state.
            'returns (int)' specifies that the function returns an integer.
        */

        // Fetches the latest round data from the price feed.
        (
            /* uint80 roundID */,
            int price,
            /* uint startedAt */,
            /* uint timeStamp */,
            /* uint80 answeredInRound */
        ) = priceFeed.latestRoundData();
        /*
            'latestRoundData' returns multiple values:
            - roundID: The round identifier.
            - price: The latest ETH/USD price.
            - startedAt: Timestamp when the round started.
            - timeStamp: Timestamp when the round was updated.
            - answeredInRound: The round in which the answer was computed.
            We only need the 'price', so the rest are commented out.
        */

        return price;
        // Returns the latest ETH/USD price as an integer.
    }

    /*
        convertEthToUsd Function:
        - Converts a given amount of ETH (in wei) to its equivalent USD value.
        - Uses the latest ETH/USD price from Chainlink.
    */
    function convertEthToUsd(uint256 ethAmount) internal view returns (uint256) {
        /*
            'internal' means this function can only be called within this contract or derived contracts.
            'view' indicates that this function does not modify the state.
            'returns (uint256)' specifies that the function returns an unsigned integer.
        */

        // Fetches the current ETH price in USD.
        uint256 ethPrice = uint256(getLatestEthPrice());
        /*
            Converts the returned 'int' from 'getLatestEthPrice' to 'uint256'.
            This is safe assuming the price is always positive.
        */

        // Calculates the USD value of the given ETH amount.
        // Divides by 10^8 to adjust for the price feed's decimal places (Chainlink price feeds typically have 8 decimals).
        return (ethAmount * ethPrice) / (10 ** 8);
    }

    /*
        transferOwnership Function:
        - Allows the current owner to transfer ownership to a new owner.
        - Only callable by the current owner.
    */
    function transferOwnership(address newOwner) public onlyOwner {
        /*
            'public' allows external access to this function.
            'onlyOwner' is a modifier that restricts access to the contract owner.
        */

        require(newOwner != address(0), "New owner cannot be the zero address.");
        // Ensures the new owner's address is valid and not the zero address.

        owner = newOwner;
        // Updates the 'owner' variable to the new owner's address.
    }

    /*
        withdrawFunds Function:
        - Allows the contract owner to withdraw all funds if the funding goal is met or exceeded.
        - Only callable after the fundraising period has ended and by the owner.
    */
    function withdrawFunds() external fundraisingEnded onlyOwner {
        /*
            'external' means this function can be called from outside the contract.
            'fundraisingEnded' is a modifier ensuring the fundraising period has ended.
            'onlyOwner' restricts access to the contract owner.
        */

        // Checks if the contract's balance meets or exceeds the funding goal.
        require(
            convertEthToUsd(address(this).balance) >= FUNDING_GOAL_USD,
            "Funding goal has not been reached."
        );
        /*
            'address(this).balance' gives the current ETH balance of the contract.
            Converts this balance to USD and ensures it meets the target.
        */

        /*
            ETH Transfer Methods:
            - transfer: Sends ETH and reverts on failure.
            - send: Sends ETH and returns a boolean indicating success.
            - call: Sends ETH and returns a boolean and data.
            Using 'call' is recommended for flexibility and gas considerations.
        */

        bool success;
        (success, ) = payable(msg.sender).call{value: address(this).balance}("");
        /*
            Attempts to transfer the entire contract balance to the owner.
            'payable(msg.sender)' makes the owner's address payable.
            '.call{value: ...}("")' sends ETH without calling any specific function.
            Returns a boolean indicating success and data (ignored here).
        */

        require(success, "ETH transfer failed.");
        // Ensures that the transfer was successful; otherwise, reverts the transaction.

        fundsWithdrawn = true;
        // Sets the 'fundsWithdrawn' flag to true, indicating funds have been successfully withdrawn.
    }

    /*
        claimRefund Function:
        - Allows contributors to withdraw their contributions if the funding goal is not met after the fundraising period.
        - Only callable after the fundraising period has ended.
    */
    function claimRefund() external fundraisingEnded {
        /*
            'external' allows this function to be called from outside the contract.
            'fundraisingEnded' ensures the fundraising period has ended.
        */

        // Ensures the funding goal was not met.
        require(
            convertEthToUsd(address(this).balance) < FUNDING_GOAL_USD,
            "Funding goal was met; refunds are not available."
        );
        /*
            If the contract's balance is equal to or exceeds the target, refunds are not allowed.
        */

        // Ensures that the caller has a non-zero contributed amount.
        require(
            contributorBalances[msg.sender] > 0,
            "You have not contributed any funds."
        );
        /*
            Prevents users who haven't contributed from attempting to withdraw.
        */

        // Retrieves the contributor's balance.
        uint256 contributedAmount = contributorBalances[msg.sender];

        // Resets the contributor's balance before transferring to prevent reentrancy attacks.
        contributorBalances[msg.sender] = 0;

        // Attempts to refund the exact amount the contributor contributed.
        bool success;
        (success, ) = payable(msg.sender).call{value: contributedAmount}("");
        /*
            Sends the contributed ETH back to the contributor.
            Uses '.call' for flexibility and to handle dynamic gas costs.
        */

        require(success, "ETH refund failed.");
        // Ensures the refund was successful; otherwise, reverts the transaction.
    }

    /*
        updateContributorBalance Function:
        - Allows an authorized ERC20 contract to update a contributor's balance.
        - Useful for integrations with token contracts or other systems.
    */
    function updateContributorBalance(address contributor, uint256 newBalance) external {
        /*
            'external' means this function can be called from outside the contract.
            No access restriction except checking the caller's address.
        */

        require(
            msg.sender == erc20TokenAddress,
            "Only the authorized ERC20 contract can update balances."
        );
        /*
            Ensures that only the authorized ERC20 contract (set in 'erc20TokenAddress') can call this function.
            Protects against unauthorized modifications.
        */

        contributorBalances[contributor] = newBalance;
        // Updates the specified contributor's contributed amount to 'newBalance'.
    }

    /*
        setErc20TokenAddress Function:
        - Allows the contract owner to set or update the address of the ERC20 token contract.
        - Useful for integrating with token systems or managing permissions.
    */
    function setErc20TokenAddress(address _erc20TokenAddress) public onlyOwner {
        /*
            'public' allows external access to this function.
            'onlyOwner' restricts access to the contract owner.
        */

        require(
            _erc20TokenAddress != address(0),
            "ERC20 token address cannot be the zero address."
        );
        // Ensures the ERC20 token address is valid and not the zero address.

        erc20TokenAddress = _erc20TokenAddress;
        // Updates the 'erc20TokenAddress' variable with the new ERC20 token contract address.
    }

    /*
        fundraisingEnded Modifier:
        - A custom modifier to ensure that certain functions can only be called after the fundraising period has ended.
        - Enhances code reusability and enforces access control.
    */
    modifier fundraisingEnded() {
        /*
            'modifier' allows you to define custom rules that can be applied to functions.
            It can check conditions before executing the function's main logic.
        */

        require(
            block.timestamp >= deploymentTime + fundraisingDuration,
            "Fundraising period is still active."
        );
        /*
            Checks if the current time is equal to or greater than the end of the fundraising period.
            If not, it reverts the transaction with the message "Fundraising period is still active."
        */

        _; // Placeholder for the function's body.
        /*
            The '_' symbol represents where the function's main code will be inserted.
            After the require statement passes, the function's code executes.
        */
    }

    /*
        onlyOwner Modifier:
        - A custom modifier to restrict function access to the contract owner.
        - Prevents unauthorized users from executing sensitive functions.
    */
    modifier onlyOwner() {
        /*
            'modifier' defines a reusable piece of code that can enforce access restrictions.
        */

        require(
            msg.sender == owner,
            "Only the contract owner can perform this action."
        );
        /*
            Checks if the caller ('msg.sender') is the contract owner.
            If not, it reverts the transaction with the message "Only the contract owner can perform this action."
        */

        _; // Placeholder for the function's body.
        /*
            After the require statement passes, the function's main code executes.
        */
    }
}
