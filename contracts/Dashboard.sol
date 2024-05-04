// SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;
import "./dev/functions/FunctionsClient.sol";



contract Dashboard is FunctionsClient {
    using Functions for Functions.Request;

    bytes32 public latestRequestId;
    bytes public latestResponse;
    bytes public latestError;
    event OCRResponse(bytes32 indexed requestId, bytes result, bytes err);

    constructor(address oracle) payable FunctionsClient(oracle) {
        maintainer = msg.sender;
    }

    struct Task {
        string description; // Task description
        uint256 issueId; // Github Issue number / Task ID
        uint256 taskAmount; // Amount of USDC Reward  available
        string repo; // Repository from Organization
        bool complete; // Task is complete or not
        string username;
    }

    Task[] public tasks;
    address public maintainer;
    mapping(address => string) public contributorUsernames;
    mapping(address => bool) public contributors;
    mapping(address => bool) public submittedContributors;
    uint256 public tasksCount;

    modifier restricted() {
        require(msg.sender == maintainer, "Restricted to maintainer");
        _;
    }

    function applyTask(string memory githubUsername, address walletAddress)
        public
    {
        require(
            contributors[msg.sender] == false,
            "You have already applied to this task"
        );
        require(walletAddress != address(0), "Wallet address is required");
        require(
            bytes(githubUsername).length > 0,
            "GitHub username is required"
        );

        contributors[msg.sender] = true;
        contributorUsernames[msg.sender] = githubUsername;
    }

    function createTask(
        string memory description,
        uint256 issueId,
        uint256 taskAmount,
        string memory repo,
        string memory username
    ) public payable restricted {
        require(
            msg.value >= taskAmount,
            "Payment amount must be equal to the bounty amount"
        );

        Task memory newtask = Task({
            description: description,
            issueId: issueId,
            taskAmount: taskAmount,
            repo: repo,
            username: username,
            complete: false
        });
        tasks.push(newtask);
        tasksCount++;
    }

    function executeRequest(
        string calldata source,
        bytes calldata secrets,
        string[] calldata args,
        uint64 subscriptionId,
        uint32 gasLimit
    ) external returns (bytes32) {
        Functions.Request memory req;
        req.initializeRequest(
            Functions.Location.Inline,
            Functions.CodeLanguage.JavaScript,
            source
        );
        if (secrets.length > 0) {
            req.addRemoteSecrets(secrets);
        }
        if (args.length > 0) {
            req.addArgs(args);
        }

        bytes32 assignedReqID = sendRequest(req, subscriptionId, gasLimit);
        latestRequestId = assignedReqID;
        return assignedReqID;
    }

    function fulfillRequest(
        bytes32 requestId,
        bytes memory response,
        bytes memory err
    ) internal override {
        latestResponse = response;
        latestError = err;
        emit OCRResponse(requestId, response, err);

        if (uint256(bytes32(response)) == 1) {
            getTasksCount();
        } else {
            revert("No contribution found");
        }
    }

    function getTasksCount() public view returns (uint256) {
        return tasks.length;
    }
}

