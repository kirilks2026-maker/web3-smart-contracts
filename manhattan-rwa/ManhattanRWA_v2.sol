// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title ManhattanRWA_v3
 * @notice Real World Asset (RWA) Tokenization for luxury Manhattan real estate.
 * @dev Upgraded via Kiril's elite audit: Fixed capital lockup, eliminated integer truncation 
 * in dividend formatting via 1e18 scaling, and strictly isolated the asset buyback backing pool.
 */
contract ManhattanRWA_v3 {

    // --- 🛡️ SECURITY & ACCESS CONTROL ---
    address public admin;
    bool private locked;

    modifier onlyAdmin() {
        require(msg.sender == admin, "Auth: Only Admin allowed");
        _;
    }

    modifier nonReentrant() {
        require(!locked, "Security: Reentrancy guard triggered");
        locked = true;
        _;
        locked = false;
    }

    // --- 📊 RWA SPECIFICATIONS ---
    string public constant propertyName = "Manhattan Luxury Penthouse Track";
    string public constant tokenSymbol = "SFT"; 
    
    uint256 public constant TOTAL_SHARES = 10000;              
    uint256 public constant ASSET_VALUATION_USD = 15000000;    
    uint256 public constant SHARE_PRICE_WEI = 1 ether;         // 1 ETH per 1 SFT fraction
    uint256 public constant TOTAL_VALUATION_WEI = TOTAL_SHARES * SHARE_PRICE_WEI; // 10,000 ETH total target

    uint256 public totalMintedShares;
    uint256 public totalActiveBuybackPoolWei;
    bool public isFundingWithdrawn;

    // --- 🧮 MATHEMATICAL ACCURACY (RESOLUTION FOR INTEGER TRUNCATION) ---
    uint256 public constant SCALE_FACTOR = 1e18; // 18-decimal precision multiplier to eliminate division rounding to zero
    uint256 public accumulatedDividendsPerShareScaled;
    mapping(address => uint256) public dividendCreditedPerShareScaled;
    mapping(address => uint256) public unclaimedDividendsWei;

    // --- 🗂️ INVESTOR LEDGERS ---
    mapping(address => uint256) public shareBalances;

    enum AssetStatus { Funding, Tokenized, BuybackPhase, FullyDeTokenized }
    AssetStatus public currentStatus;

    // --- 📣 EVENTS ---
    event SharesPurchased(address indexed investor, uint256 count, uint256 valueWei);
    event PropertyFullyTokenized();
    event FundingCapitalWithdrawn(address indexed admin, uint256 amountWei);
    event RentalIncomeDeposited(uint256 amountWei);
    event DividendsClaimed(address indexed investor, uint256 amountWei);
    event BuybackPoolFunded(uint256 amountWei, uint256 currentTotalWei);
    event BuybackPhaseActivated();
    event ShareRedemedFromAsset(address indexed investor, uint256 count, uint256 payoutWei);
    event AssetDeTokenizationFinalized();

    constructor() {
        admin = msg.sender;
        currentStatus = AssetStatus.Funding;
    }

    // --- 📥 1. INVESTMENT & MINTING LAYER ---
    function purchasePropertyShares(uint256 _sharesToBuy) external payable nonReentrant {
        require(currentStatus == AssetStatus.Funding, "RWA: Funding phase closed");
        require(_sharesToBuy > 0, "RWA: Must purchase at least 1 fraction");
        require(totalMintedShares + _sharesToBuy <= TOTAL_SHARES, "RWA: Exceeds total property pool size");
        require(msg.value == _sharesToBuy * SHARE_PRICE_WEI, "RWA: Incorrect capital provided");

        _updateUserDividendDebt(msg.sender);

        shareBalances[msg.sender] += _sharesToBuy;
        totalMintedShares += _sharesToBuy;

        emit SharesPurchased(msg.sender, _sharesToBuy, msg.value);

        if (totalMintedShares == TOTAL_SHARES) {
            currentStatus = AssetStatus.Tokenized;
            emit PropertyFullyTokenized();
        }
    }

    /**
     * @notice RESOLUTION FOR LOCKUP VULNERABILITY: Allows admin to securely withdraw the $15M 
     * crowdfunding capital to physically acquire the real estate property on the ground.
     */
    function withdrawFundingCapital() external onlyAdmin nonReentrant {
        require(currentStatus == AssetStatus.Tokenized || currentStatus == AssetStatus.BuybackPhase, "RWA: Target capital is locked until funding target is fully met");
        require(!isFundingWithdrawn, "RWA: Funding capital already extracted");

        isFundingWithdrawn = true;
        uint256 capitalToWithdraw = TOTAL_VALUATION_WEI;

        emit FundingCapitalWithdrawn(admin, capitalToWithdraw);

        (bool success, ) = payable(admin).call{value: capitalToWithdraw}("");
        require(success, "RWA: Capital extraction transfer failed");
    }

    // --- 💸 2. ACCURATE RENTAL INCOME PULL PIPELINE ---
    function depositRentalIncome() external payable onlyAdmin {
        require(currentStatus == AssetStatus.Tokenized, "RWA: Property must be tokenized and active");
        require(msg.value > 0, "RWA: Deposit pool cannot be empty");

        // Scale the distribution value by 1e18 prior to division to secure fractions against rounding locks
        accumulatedDividendsPerShareScaled += (msg.value * SCALE_FACTOR) / TOTAL_SHARES;

        emit RentalIncomeDeposited(msg.value);
    }

    function _updateUserDividendDebt(address _user) internal {
        uint256 userShares = shareBalances[_user];
        if (userShares > 0) {
            uint256 owedPerShareScaled = accumulatedDividendsPerShareScaled - dividendCreditedPerShareScaled[_user];
            if (owedPerShareScaled > 0) {
                // Downscale back to Wei units during the final calculation matrix
                unclaimedDividendsWei[_user] += (userShares * owedPerShareScaled) / SCALE_FACTOR;
            }
        }
        dividendCreditedPerShareScaled[_user] = accumulatedDividendsPerShareScaled;
    }

    function claimDividends() external nonReentrant {
        _updateUserDividendDebt(msg.sender);
        uint256 payout = unclaimedDividendsWei[msg.sender];
        require(payout > 0, "RWA: Zero claims available");

        unclaimedDividendsWei[msg.sender] = 0;

        emit DividendsClaimed(msg.sender, payout);

        (bool success, ) = payable(msg.sender).call{value: payout}("");
        require(success, "RWA: Dividend payout execution failed");
    }

    // --- ⚰️ 3. DE-TOKENIZATION & ISOLATED POOL EXITS ---
    /**
     * @notice RESOLUTION FOR BALANCE CONFUSION: Backs buyback liquidity pools into a strict isolated ledger.
     */
    function fundBuybackLiquidityPool() external payable onlyAdmin {
        require(currentStatus == AssetStatus.Tokenized, "RWA: Invalid phase for buyback backing");
        require(msg.value > 0, "RWA: Must fund with real capital value");
        
        totalActiveBuybackPoolWei += msg.value;
        emit BuybackPoolFunded(msg.value, totalActiveBuybackPoolWei);

        // Strict verification: phase triggers ONLY when the isolated pool matches the global valuation target
        if (totalActiveBuybackPoolWei >= TOTAL_VALUATION_WEI) {
            currentStatus = AssetStatus.BuybackPhase;
            emit BuybackPhaseActivated();
        }
    }

    function buybackShare(uint256 _sharesToRedeem) external nonReentrant {
        require(currentStatus == AssetStatus.BuybackPhase, "RWA: Buyback window is locked");
        require(shareBalances[msg.sender] >= _sharesToRedeem, "RWA: Insufficient tokens owned");

        _updateUserDividendDebt(msg.sender);

        shareBalances[msg.sender] -= _sharesToRedeem;
        totalMintedShares -= _sharesToRedeem;
        
        uint256 payoutWei = _sharesToRedeem * SHARE_PRICE_WEI;
        totalActiveBuybackPoolWei -= payoutWei;

        emit ShareRedemedFromAsset(msg.sender, _sharesToRedeem, payoutWei);

        (bool success, ) = payable(msg.sender).call{value: payoutWei}("");
        require(success, "RWA: Buyback execution failed");

        if (totalMintedShares == 0) {
            currentStatus = AssetStatus.FullyDeTokenized;
            emit AssetDeTokenizationFinalized();
        }
    }

    // --- 🔍 4. READ VIEW HELPERS ---
    function checkPendingDividends(address _user) external view returns (uint256) {
        uint256 userShares = shareBalances[_user];
        uint256 owedPerShareScaled = accumulatedDividendsPerShareScaled - dividendCreditedPerShareScaled[_user];
        return unclaimedDividendsWei[_user] + ((userShares * owedPerShareScaled) / SCALE_FACTOR);
    }
}
