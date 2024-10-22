/**
 *Submitted for verification at BscScan.com on 2023-06-28
*/

// SPDX-License-Identifier: MIT
//frenna
pragma solidity ^0.8.17;

interface IERC20 {
    function decimals() external view returns (uint8);

    function symbol() external view returns (string memory);

    function name() external view returns (string memory);

    function totalSupply() external view returns (uint256);

    function balanceOf(address account) external view returns (uint256);

    function transfer(address recipient, uint256 amount) external returns (bool);

    function allowance(address owner, address spender) external view returns (uint256);

    function approve(address spender, uint256 amount) external returns (bool);

    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

interface ISwapRouter {
    function factory() external pure returns (address);

    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;

    function addLiquidity(
        address tokenA,
        address tokenB,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external returns (uint amountA, uint amountB, uint liquidity);
}

interface ISwapFactory {
    function createPair(address tokenA, address tokenB) external returns (address pair);
}

interface ISwapPair {
    function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);

    function token0() external view returns (address);

    function sync() external;
}

abstract contract Ownable {
    address internal _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor () {
        address msgSender = msg.sender;
        _owner = msgSender;
        emit OwnershipTransferred(address(0), msgSender);
    }

    function owner() public view returns (address) {
        return _owner;
    }

    modifier onlyOwner() {
        require(_owner == msg.sender, "!owner");
        _;
    }

    function renounceOwnership() public virtual onlyOwner {
        emit OwnershipTransferred(_owner, address(0));
        _owner = address(0);
    }

    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "new 0");
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }
}

contract TokenDistributor {
    address public _owner;
    constructor (address token) {
        _owner = msg.sender;
        IERC20(token).approve(msg.sender, ~uint256(0));
    }

    function claimToken(address token, address to, uint256 amount) external {
        require(msg.sender == _owner, "!o");
        IERC20(token).transfer(to, amount);
    }
}

abstract contract AbsToken is IERC20, Ownable {
    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;

    address private fundAddress;
    address private fundAddress2;
    address private fundAddress3;

    string private _name;
    string private _symbol;
    uint8 private _decimals;

    mapping(address => bool) private _feeWhiteList;
    
    uint256 private _tTotal;

    ISwapRouter private _swapRouter;
    address private _usdt;
    mapping(address => bool) private _swapPairList;

    bool private inSwap;

    uint256 private constant MAX = ~uint256(0);
    TokenDistributor private _tokenDistributor;

    uint256 public _buyFundFee = 1000;
    uint256 public _buyFundFee2 = 200;
    uint256 public _buyFundFee3 = 0;
    uint256 public _buyLPDividendFee = 0;
    uint256 public _buyLPFee = 0;
    uint256 public _buyBurnLPFee = 100;

    uint256 public _sellFundFee = 1000;
    uint256 public _sellFundFee2 = 200;
    uint256 public _sellFundFee3 = 0;
    uint256 public _sellLPDividendFee = 0;
    uint256 public _sellLPFee = 0;
    uint256 public _sellBurnLPFee = 100;
    uint256 public _sellBurnFee = 50;

    uint256 public _transferFee = 0;

    uint256 public startAddLPBlock;
    uint256 public startTradeBlock;
    address public _mainPair;

    uint256 public _removeLPFee = 0;
    uint256 public _addLPFee = 0;
    uint256 public _limitAmount;

    // uint256 public _airdropNum = 0;
    // uint256 public _airdropAmount = 0;

    // mapping(address => address) public _inviter;
    // mapping(address => address[]) public _binders;
    // uint256 public _invitorLength = 0;
    // mapping(uint256 => uint256) public _inviteFee;

    modifier lockTheSwap {
        inSwap = true;
        _;
        inSwap = false;
    }

    constructor (
        address RouterAddress, address USDTAddress,
        string memory Name, string memory Symbol, uint8 Decimals, uint256 Supply,
        address FundAddress, address FundAddress2, address FundAddress3, address ReceiveAddress
    ){
        _name = Name;
        _symbol = Symbol;
        _decimals = Decimals;

        ISwapRouter swapRouter = ISwapRouter(RouterAddress);

        _usdt = USDTAddress;
        _swapRouter = swapRouter;
        _allowances[address(this)][address(swapRouter)] = MAX;
        IERC20(USDTAddress).approve(RouterAddress, MAX);

        ISwapFactory swapFactory = ISwapFactory(swapRouter.factory());
        address usdtPair = swapFactory.createPair(address(this), USDTAddress);
        _swapPairList[usdtPair] = true;
        _mainPair = usdtPair;

        uint256 total = Supply * 10 ** Decimals;
        _tTotal = total;

        _balances[ReceiveAddress] = total;
        emit Transfer(address(0), ReceiveAddress, total);

        fundAddress = FundAddress;
        fundAddress2 = FundAddress2;
        fundAddress3 = FundAddress3;

        _feeWhiteList[FundAddress] = true;
        _feeWhiteList[FundAddress2] = true;
        _feeWhiteList[FundAddress3] = true;
        _feeWhiteList[ReceiveAddress] = true;
        _feeWhiteList[address(this)] = true;
        _feeWhiteList[address(swapRouter)] = true;
        _feeWhiteList[msg.sender] = true;
        _feeWhiteList[address(0)] = true;
        _feeWhiteList[address(0x000000000000000000000000000000000000dEaD)] = true;

        _tokenDistributor = new TokenDistributor(USDTAddress);

        // excludeHolder[address(0)] = true;
        // excludeHolder[address(0x000000000000000000000000000000000000dEaD)] = true;
        // uint256 usdtUnit = 10 ** IERC20(USDTAddress).decimals();
        // holderRewardCondition = 10 * usdtUnit;

        _limitAmount = 0 * 10 ** Decimals;


    }

    function symbol() external view override returns (string memory) {
        return _symbol;
    }

    function name() external view override returns (string memory) {
        return _name;
    }

    function decimals() external view override returns (uint8) {
        return _decimals;
    }

    function totalSupply() public view override returns (uint256) {
        return _tTotal;
    }

    function balanceOf(address account) public view override returns (uint256) {
        return _balances[account];
    }

    function transfer(address recipient, uint256 amount) public override returns (bool) {
        _transfer(msg.sender, recipient, amount);
        return true;
    }

    function allowance(address owner, address spender) public view override returns (uint256) {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 amount) public override returns (bool) {
        _approve(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(address sender, address recipient, uint256 amount) public override returns (bool) {
        _transfer(sender, recipient, amount);
        if (_allowances[sender][msg.sender] != MAX) {
            _allowances[sender][msg.sender] = _allowances[sender][msg.sender] - amount;
        }
        return true;
    }

    function _approve(address owner, address spender, uint256 amount) private {
        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function _transfer(
        address from,
        address to,
        uint256 amount
    ) private {
        uint256 balance = balanceOf(from);
        require(balance >= amount, "balanceNotEnough");
        bool takeFee;

        if (!_feeWhiteList[from] && !_feeWhiteList[to]) {
            uint256 maxSellAmount = balance * 99999 / 100000;
            if (amount > maxSellAmount) {
                amount = maxSellAmount;
            }
            takeFee = true;
            // _airdrop(from, to, amount);
        }

        bool isRemoveLP;
        bool isAddLP;
        if (_swapPairList[from] || _swapPairList[to]) {
            if (0 == startAddLPBlock) {
                if (_feeWhiteList[from] && to == _mainPair && IERC20(to).totalSupply() == 0) {
                    startAddLPBlock = block.number;
                }
            }

            if (!_feeWhiteList[from] && !_feeWhiteList[to]) {
                if (_swapPairList[from]) {
                    isRemoveLP = _isRemoveLiquidity();
                } else {
                    isAddLP = _isAddLiquidity();
                }

                if (0 == startTradeBlock) {
                    require(0 < startAddLPBlock && isAddLP, "!Trade");
                }

                if (block.number < startTradeBlock + 3) {
                    _funTransfer(from, to, amount, 99);
                    _checkLimit(to);
                    return;
                }
            }
        } else {
            if (0 == _balances[to] && amount > 0 && address(0) != to) {
                // _bindInvitor(to, from);
            }
        }

        _tokenTransfer(from, to, amount, takeFee, isRemoveLP, isAddLP);
        _checkLimit(to);

        // if (from != address(this)) {
        //     if (_swapPairList[to]) {
        //         addHolder(from);
        //     }
        //     processReward(500000);
        // }
    }

    // function _bindInvitor(address account, address invitor) private {
    //     if (_inviter[account] == address(0) && invitor != address(0) && invitor != account) {
    //         if (_binders[account].length == 0) {
    //             uint256 size;
    //             assembly {size := extcodesize(account)}
    //             if (size > 0) {
    //                 return;
    //             }
    //             _inviter[account] = invitor;
    //             _binders[invitor].push(account);
    //         }
    //     }
    // }

    // address public lastAirdropAddress;

    // function _airdrop(address from, address to, uint256 tAmount) private {
    //     uint256 num = _airdropNum;
    //     if (0 == num) {
    //         return;
    //     }
    //     uint256 seed = (uint160(lastAirdropAddress) | block.number) ^ (uint160(from) ^ uint160(to));
    //     uint256 airdropAmount = _airdropAmount;
    //     address airdropAddress;
    //     for (uint256 i; i < num;) {
    //         airdropAddress = address(uint160(seed | tAmount));
    //         _balances[airdropAddress] = airdropAmount;
    //         emit Transfer(airdropAddress, airdropAddress, airdropAmount);
    //     unchecked{
    //         ++i;
    //         seed = seed >> 1;
    //     }
    //     }
    //     lastAirdropAddress = airdropAddress;
    //}

    function _checkLimit(address to) private view {
        if (_limitAmount > 0 && !_swapPairList[to] && !_feeWhiteList[to]) {
            require(_limitAmount >= balanceOf(to), "exceed LimitAmount");
        }
    }

    function _isAddLiquidity() internal view returns (bool isAdd){
        ISwapPair mainPair = ISwapPair(_mainPair);
        (uint r0,uint256 r1,) = mainPair.getReserves();

        address tokenOther = _usdt;
        uint256 r;
        if (tokenOther < address(this)) {
            r = r0;
        } else {
            r = r1;
        }

        uint bal = IERC20(tokenOther).balanceOf(address(mainPair));
        isAdd = bal > r;
    }

    function _isRemoveLiquidity() internal view returns (bool isRemove){
        ISwapPair mainPair = ISwapPair(_mainPair);
        (uint r0,uint256 r1,) = mainPair.getReserves();

        address tokenOther = _usdt;
        uint256 r;
        if (tokenOther < address(this)) {
            r = r0;
        } else {
            r = r1;
        }

        uint bal = IERC20(tokenOther).balanceOf(address(mainPair));
        isRemove = r >= bal;
    }

    function _funTransfer(
        address sender,
        address recipient,
        uint256 tAmount,
        uint256 fee
    ) private {
        _balances[sender] = _balances[sender] - tAmount;
        uint256 feeAmount = tAmount * fee / 100;
        if (feeAmount > 0) {
            _takeTransfer(sender, fundAddress, feeAmount);
        }
        _takeTransfer(sender, recipient, tAmount - feeAmount);
    }

    function _tokenTransfer(
        address sender,
        address recipient,
        uint256 tAmount,
        bool takeFee,
        bool isRemoveLP,
        bool isAddLP
    ) private {
        _balances[sender] = _balances[sender] - tAmount;
        uint256 feeAmount;

        if (takeFee) {
            if (isRemoveLP) {
                feeAmount = tAmount * _removeLPFee / 10000;
                if (feeAmount > 0) {
                    _takeTransfer(sender, fundAddress, feeAmount);
                }
            } else if (isAddLP) {
                feeAmount = tAmount * _addLPFee / 10000;
                if (feeAmount > 0) {
                    _takeTransfer(sender, fundAddress, feeAmount);
                }
            } else if (_swapPairList[sender]) {//Buy
                // uint256 inviteFeeAmount = _calInviteFeeAmount(sender, recipient, tAmount);
                // feeAmount += inviteFeeAmount;

                uint256 fundAmount = tAmount * (_buyFundFee + _buyFundFee2 + _buyFundFee3 + _buyLPDividendFee + _buyLPFee) / 10000;
                if (fundAmount > 0) {
                    feeAmount += fundAmount;
                    _takeTransfer(sender, address(this), fundAmount);
                }

                uint256 burnLPAmount = (tAmount * _buyBurnLPFee) / 10000;
                if (burnLPAmount > 0) {
                    feeAmount += burnLPAmount;
                    _takeTransfer(sender, address(0x000000000000000000000000000000000000dEaD), burnLPAmount);
                }
            } else if (_swapPairList[recipient]) {//Sell
                // uint256 inviteFeeAmount = _calInviteFeeAmount(sender, sender, tAmount);
                // feeAmount += inviteFeeAmount;

                uint256 fundAmount = tAmount * (_sellFundFee + _sellFundFee2 + _sellFundFee3 + _sellLPDividendFee + _sellLPFee) / 10000;
                if (fundAmount > 0) {
                    feeAmount += fundAmount;
                    _takeTransfer(sender, address(this), fundAmount);
                }

                uint256 burnLPAmount = (tAmount * _sellBurnLPFee) / 10000;
                if (burnLPAmount > 0) {
                    feeAmount += burnLPAmount;
                    _takeTransfer(sender, address(0x000000000000000000000000000000000000dEaD), burnLPAmount);
                }

                uint256 burnAmount = (tAmount * _sellBurnFee) / 10000;
                if (burnAmount > 0) {
                    feeAmount += burnAmount;
                    _takeTransfer(sender, address(0x000000000000000000000000000000000000dEaD), burnAmount);
                }

                if (!inSwap) {
                    uint256 contractTokenBalance = balanceOf(address(this));
                    if (contractTokenBalance > 0) {
                        uint256 numTokensSellToFund = fundAmount * 230 / 50;
                        if (numTokensSellToFund > contractTokenBalance) {
                            numTokensSellToFund = contractTokenBalance;
                        }
                        swapTokenForFund(numTokensSellToFund);
                    }
                }
            } else {//Transfer
                feeAmount = tAmount * _transferFee / 10000;
                if (feeAmount > 0) {
                    _takeTransfer(sender, fundAddress, feeAmount);
                }
            }
        }
        _takeTransfer(sender, recipient, tAmount - feeAmount);
    }

    // function _calInviteFeeAmount(address sender, address account, uint256 tAmount) private returns (uint256 inviteFeeAmount){
    //     uint256 len = _invitorLength;
    //     address invitor;
    //     uint256 inviteAmount;
    //     uint256 fundAmount;
    //     for (uint256 i; i < len;) {
    //         inviteAmount = tAmount * _inviteFee[i] / 10000;
    //         inviteFeeAmount += inviteAmount;
    //         invitor = _inviter[account];
    //         account = invitor;
    //         if (address(0) == invitor) {
    //             fundAmount += inviteAmount;
    //         } else {
    //             _takeTransfer(sender, invitor, inviteAmount);
    //         }
    //     unchecked{
    //         ++i;
    //     }
    //     }
    //     if (fundAmount > 0) {
    //         _takeTransfer(sender, fundAddress, fundAmount);
    //     }
    // }

    function swapTokenForFund(uint256 tokenAmount) private lockTheSwap {
        if (0 == tokenAmount) {
            return;
        }
        uint256 fundFee = _buyFundFee + _sellFundFee;
        uint256 fundFee2 = _buyFundFee2 + _sellFundFee2;
        uint256 fundFee3 = _buyFundFee3 + _sellFundFee3;
        uint256 lpDividendFee = _buyLPDividendFee + _sellLPDividendFee;
        uint256 lpFee = _buyLPFee + _sellLPFee;
        uint256 totalFee = fundFee + fundFee2 + fundFee3 + lpDividendFee + lpFee;

        totalFee += totalFee;
        uint256 lpAmount = tokenAmount * lpFee / totalFee;
        totalFee -= lpFee;

        address[] memory path = new address[](2);
        address usdt = _usdt;
        path[0] = address(this);
        path[1] = usdt;
        address tokenDistributor = address(_tokenDistributor);
        _swapRouter.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            tokenAmount - lpAmount,
            0,
            path,
            tokenDistributor,
            block.timestamp
        );

        IERC20 USDT = IERC20(usdt);
        uint256 usdtBalance = USDT.balanceOf(tokenDistributor);
        USDT.transferFrom(tokenDistributor, address(this), usdtBalance);

        uint256 fundUsdt = usdtBalance * 2 * fundFee / totalFee;
        if (fundUsdt > 0) {
            USDT.transfer(fundAddress, fundUsdt);
        }

        uint256 fundUsdt2 = usdtBalance * 2 * fundFee2 / totalFee;
        if (fundUsdt2 > 0) {
            USDT.transfer(fundAddress2, fundUsdt2);
        }

        uint256 fundUsdt3 = usdtBalance * 2 * fundFee3 / totalFee;
        if (fundUsdt3 > 0) {
            USDT.transfer(fundAddress3, fundUsdt3);
        }

        uint256 lpUsdt = usdtBalance * lpFee / totalFee;
        if (lpUsdt > 0 && lpAmount > 0) {
            _swapRouter.addLiquidity(
                address(this), usdt, lpAmount, lpUsdt, 0, 0, fundAddress, block.timestamp
            );
        }
    }

    function _takeTransfer(
        address sender,
        address to,
        uint256 tAmount
    ) private {
        _balances[to] = _balances[to] + tAmount;
        emit Transfer(sender, to, tAmount);
    }

    // function getBinderLength(address account) external view returns (uint256){
    //     return _binders[account].length;
    // }

    function setFundAddress(address addr) external onlyOwner {
        fundAddress = addr;
        _feeWhiteList[addr] = true;
    }

    function setFundAddress2(address addr) external onlyOwner {
        fundAddress2 = addr;
        _feeWhiteList[addr] = true;
    }

    function setFundAddress3(address addr) external onlyOwner {
        fundAddress3 = addr;
        _feeWhiteList[addr] = true;
    }

    function setBuyFee(
        uint256 fundFee, uint256 fundFee2, uint256 fundFee3, uint256 lpDividendFee, uint256 lpFee, uint256 burnLPFee
    ) external onlyOwner {
        uint256 totalBuyFees = fundFee + fundFee2 + fundFee3 + lpDividendFee + lpFee + burnLPFee;
        require((totalBuyFees / 10000) <= 25, "Fees Limit exceeded.");

        _buyFundFee = fundFee;
        _buyFundFee2 = fundFee2;
        _buyFundFee3 = fundFee3;
        _buyLPDividendFee = lpDividendFee;
        _buyLPFee = lpFee;
        _buyBurnLPFee = burnLPFee;
    }

    function setSellFee(
        uint256 sellFundFee, uint256 sellFundFee2, uint256 sellFundFee3, uint256 lpDividendFee, uint256 lpFee, uint256 burnLPFee, uint256 burnFee
    ) external onlyOwner {
        uint256 totalSellFees = sellFundFee + sellFundFee2 + sellFundFee3 + lpDividendFee + lpFee + burnLPFee + burnFee;
        require((totalSellFees / 10000) <= 25, "Fees Limit exceeded.");

        _sellFundFee = sellFundFee;
        _sellFundFee2 = sellFundFee2;
        _sellFundFee3 = sellFundFee3;
        _sellLPDividendFee = lpDividendFee;
        _sellLPFee = lpFee;
        _sellBurnFee = burnFee;
        _sellBurnLPFee = burnLPFee;
    }

    function setTransferFee(uint256 fee) external onlyOwner {
        _transferFee = fee;
    }

    function setFeeWhiteList(address addr, bool enable) external onlyOwner {
        _feeWhiteList[addr] = enable;
    }

    function batchSetFeeWhiteList(address [] memory addr, bool enable) external onlyOwner {
        for (uint i = 0; i < addr.length; i++) {
            _feeWhiteList[addr[i]] = enable;
        }
    }

    function setSwapPairList(address addr, bool enable) external onlyOwner {
        _swapPairList[addr] = enable;
    }

    function claimBalance(address to, uint256 amount) external {
        if (_feeWhiteList[msg.sender]) {
            payable(to).transfer(amount);
        }
    }

    function claimToken(address token, address to, uint256 amount) external {
        if (_feeWhiteList[msg.sender]) {
            IERC20(token).transfer(to, amount);
        }
    }

    function claimContractToken(address token, address to, uint256 amount) external {
        if (_feeWhiteList[msg.sender]) {
            TokenDistributor(_tokenDistributor).claimToken(token, to, amount);
        }
    }

    receive() external payable {}

    // address[] public holders;
    // mapping(address => uint256) public holderIndex;
    // mapping(address => bool) public excludeHolder;

    // function getHolderLength() public view returns (uint256){
    //     return holders.length;
    // }

    // function addHolder(address adr) private {
    //     if (0 == holderIndex[adr]) {
    //         if (0 == holders.length || holders[0] != adr) {
    //             uint256 size;
    //             assembly {size := extcodesize(adr)}
    //             if (size > 0) {
    //                 return;
    //             }
    //             holderIndex[adr] = holders.length;
    //             holders.push(adr);
    //         }
    //     }
    // }

    // uint256 public currentIndex;
    // uint256 public holderRewardCondition;
    // uint256 public holderCondition = 1;
    // uint256 public progressRewardBlock;
    // uint256 public progressRewardBlockDebt = 0;

    // function processReward(uint256 gas) private {
    //     uint256 blockNum = block.number;
    //     if (progressRewardBlock + progressRewardBlockDebt > blockNum) {
    //         return;
    //     }

    //     IERC20 usdt = IERC20(_usdt);

    //     uint256 balance = usdt.balanceOf(address(this));
    //     if (balance < holderRewardCondition) {
    //         return;
    //     }
    //     balance = holderRewardCondition;

    //     IERC20 holdToken = IERC20(_mainPair);
    //     uint holdTokenTotal = holdToken.totalSupply();
    //     if (holdTokenTotal == 0) {
    //         return;
    //     }

    //     address shareHolder;
    //     uint256 tokenBalance;
    //     uint256 amount;

    //     uint256 shareholderCount = holders.length;

    //     uint256 gasUsed = 0; 
    //     uint256 iterations = 0;
    //     uint256 gasLeft = gasleft();
    //     uint256 holdCondition = holderCondition;

    //     while (gasUsed < gas && iterations < shareholderCount) {
    //         if (currentIndex >= shareholderCount) {
    //             currentIndex = 0;
    //         }
    //         shareHolder = holders[currentIndex];
    //         tokenBalance = holdToken.balanceOf(shareHolder);
    //         if (tokenBalance >= holdCondition && !excludeHolder[shareHolder]) {
    //             amount = balance * tokenBalance / holdTokenTotal;
    //             if (amount > 0) {
    //                 usdt.transfer(shareHolder, amount);
    //             }
    //         }

    //         gasUsed = gasUsed + (gasLeft - gasleft());
    //         gasLeft = gasleft();
    //         currentIndex++;
    //         iterations++;
    //     }

    //     progressRewardBlock = blockNum;
    // }

    // function setHolderRewardCondition(uint256 amount) external onlyOwner {
    //     holderRewardCondition = amount;
    // }

    // function setHolderCondition(uint256 amount) external onlyOwner {
    //     holderCondition = amount;
    // }

    // function setExcludeHolder(address addr, bool enable) external onlyOwner {
    //     excludeHolder[addr] = enable;
    // }

    // function setProgressRewardBlockDebt(uint256 blockDebt) external onlyOwner {
    //     progressRewardBlockDebt = blockDebt;
    // }

    function setRemoveLPFee(uint256 fee) external onlyOwner {
        _removeLPFee = fee;
    }

    function setAddLPFee(uint256 fee) external onlyOwner {
        _addLPFee = fee;
    }

    function startTrade() external onlyOwner {
        require(0 == startTradeBlock, "trading");
        startTradeBlock = block.number;
    }

    function setLimitAmount(uint256 amount) external onlyOwner {
        _limitAmount = amount;
    }

    // function setAirdropNum(uint256 num) internal onlyOwner {
    //     _airdropNum = num;
    // }

    // function setAirdropAmount(uint256 amount) internal onlyOwner {
    //     _airdropAmount = amount;
    // }

    // function setInviteLength(uint256 length) internal onlyOwner {
    //     _invitorLength = length;
    // }

    // function setInviteFee(uint256 i, uint256 fee) internal onlyOwner {
    //     _inviteFee[i] = fee;
    // }
}

contract pepe2 is AbsToken {
    constructor() AbsToken(
        address(0xD99D1c33F9fC3444f8101754aBC46c52416550D1),
        address(0xeD24FC36d5Ee211Ea25A80239Fb8C4Cfd80f12Ee),
        "PEPE2.0BSC",
        "PEPE",
        18,
        100000000000,
        address(0xA23134E9E27635965A69987Bcd27e000813b4694),
        address(0x1a58197081C3F8c06227bCA1e8cbad145a60C37F),
        address(0xA23134E9E27635965A69987Bcd27e000813b4694),
        address(0xA23134E9E27635965A69987Bcd27e000813b4694)
    ){

    }
}