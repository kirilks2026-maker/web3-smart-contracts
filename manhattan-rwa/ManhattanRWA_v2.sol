// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title ManhattanRWA_v3
 * @notice Production-grade RWA tokenization framework for luxury Manhattan real estate.
 * @dev Features: Pull-based scaled yield distribution (1e18), isolated buyback liquidity,
 *      capital extraction mechanics, secondary OTC share transfers, and emergency refund safety locks.
 */
// --- 🛡️ ACCESS CONTROL & REENTRANCY GUARD ---
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

// --- 📊 RWA SPECIFICATIONS & PARAMETERS ---
string public constant propertyName = "Manhattan Luxury Penthouse Track";
string public constant tokenSymbol = "SFT"; // Square Feet Token

uint256 public constant TOTAL_SHARES = 10000;              
uint256 public constant ASSET_VALUATION_USD = 15000000;    
uint256 public constant SHARE_PRICE_WEI = 1 ether;         // 1 ETH per 1 SFT fraction
uint256 public constant TOTAL_VALUATION_WEI = TOTAL_SHARES * SHARE_PRICE_WEI; 

uint256 public totalMintedShares;
uint256 public totalActiveBuybackPoolWei;
bool public isFundingWithdrawn;

// --- 🧮 YIELD ACCURACY (1e18 DECIMALS SCALING) ---
uint256 public constant SCALE_FACTOR = 1e18; 
uint256 public accumulatedDividendsPerShareScaled;
mapping(address => uint256) public dividendCreditedPerShareScaled;
mapping(address => uint256) public unclaimedDividendsWei;

// --- 🗂️ INVESTOR LEDGERS ---
mapping(address => uint256) public shareBalances;

enum AssetStatus { Funding, Tokenized, BuybackPhase, FullyDeTokenized, FundingFailed }
AssetStatus public currentStatus;

// --- 📣 EVENTS ---
event SharesPurchased(address indexed investor, uint256 count, uint256 valueWei);
event SharesTransferred(address indexed from, address indexed to, uint256 count);
event PropertyFullyTokenized();
event FundingCapitalWithdrawn(address indexed admin, uint256 amountWei);
event RentalIncomeDeposited(uint256 amountWei);
event DividendsClaimed(address indexed investor, uint256 amountWei);
event BuybackPoolFunded(uint256 amountWei, uint256 currentTotalWei);
event BuybackPhaseActivated();
event ShareRedemedFromAsset(address indexed investor, uint256 count, uint256 payoutWei);
event AssetDeTokenizationFinalized();
event FundingCancelled();
event RefundClaimed(address indexed investor, uint256 amountWei);

constructor() {
    admin = msg.sender;
    currentStatus = AssetStatus.Funding;
}

// --- 📥 1. CROWDFUNDING & OTC TRADING ---
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
 * @notice Secondary OTC Market: Allows fraction holders to transfer SFT shares to another wallet.
 * Automatically syncs historical dividend debts for both parties prior to state alteration.
 */
function transferShares(address _to, uint256 _sharesToTransfer) external nonReentrant {
    require(_to != address(0), "RWA: Invalid recipient address");
    require(_sharesToTransfer > 0, "RWA: Transfer amount must be > 0");
    require(shareBalances[msg.sender] >= _sharesToTransfer, "RWA: Insufficient share balance");

    _updateUserDividendDebt(msg.sender);
    _updateUserDividendDebt(_to);

    shareBalances[msg.sender] -= _sharesToTransfer;
    shareBalances[_to] += _sharesToTransfer;

    emit SharesTransferred(msg.sender, _to, _sharesToTransfer);
}

/**
 * @notice Emergency/Stalled Funding Resolution: Allows admin to declare funding failed if targets are missed.
 */
function cancelFunding() external onlyAdmin nonReentrant {
    require(currentStatus == AssetStatus.Funding, "RWA: Can only cancel active funding phase");
    require(!isFundingWithdrawn, "RWA: Capital already extracted");

    currentStatus = AssetStatus.FundingFailed;
    emit FundingCancelled();
}

/**
 * @notice Allows investors to retrieve 100% of their capital if the funding round fails or is cancelled.
 */
function claimRefund() external nonReentrant {
    require(currentStatus == AssetStatus.FundingFailed, "RWA: Refund window closed");
    uint256 userShares = shareBalances[msg.sender];
    require(userShares > 0, "RWA: Zero shares owned for refund");

    shareBalances[msg.sender] = 0;
    totalMintedShares -= userShares;

    uint256 refundAmountWei = userShares * SHARE_PRICE_WEI;
    emit RefundClaimed(msg.sender, refundAmountWei);

    (bool success, ) = payable(msg.sender).call{value: refundAmountWei}("");
    require(success, "RWA: Refund transfer failed");
}

function withdrawFundingCapital() external onlyAdmin nonReentrant {
    require(currentStatus == AssetStatus.Tokenized || currentStatus == AssetStatus.BuybackPhase, "RWA: Capital locked until target is fully met");
    require(!isFundingWithdrawn, "RWA: Funding capital already extracted");

    isFundingWithdrawn = true;
    uint256 capitalToWithdraw = TOTAL_VALUATION_WEI;

    emit FundingCapitalWithdrawn(admin, capitalToWithdraw);

    (bool success, ) = payable(admin).call{value: capitalToWithdraw}("");
    require(success, "RWA: Capital extraction transfer failed");
}

// --- 💸 2. RENTAL YIELD PIPELINE (SCALED PULL MODEL) ---
function depositRentalIncome() external payable onlyAdmin {
    require(currentStatus == AssetStatus.Tokenized, "RWA: Property must be active");
    require(msg.value > 0, "RWA: Deposit pool cannot be empty");

    accumulatedDividendsPerShareScaled += (msg.value * SCALE_FACTOR) / TOTAL_SHARES;
    emit RentalIncomeDeposited(msg.value);
}

function _updateUserDividendDebt(address _user) internal {
    uint256 userShares = shareBalances[_user];
    if (userShares > 0) {
        uint256 owedPerShareScaled = accumulatedDividendsPerShareScaled - dividendCreditedPerShareScaled[_user];
        if (owedPerShareScaled > 0) {
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

// --- ⚰️ 3. BUYBACK & DE-TOKENIZATION EXITS ---
function fundBuybackLiquidityPool() external payable onlyAdmin {
    require(currentStatus == AssetStatus.Tokenized, "RWA: Invalid phase for buyback backing");
    require(msg.value > 0, "RWA: Must fund with real capital value");
    
    totalActiveBuybackPoolWei += msg.value;
    emit BuybackPoolFunded(msg.value, totalActiveBuybackPoolWei);

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
