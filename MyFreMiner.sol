// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.5.0;

import "./SafeMath.sol";
import "./ReentrancyGuard.sol";
import "./TransferHelper.sol";
import "./IBEP20.sol";
import "./LpWallet.sol";
import "./FreMinePool.sol";

// 收益聚合器，用于计算价格
interface IPancakePair {
    function token0() external view returns (address);

    function token1() external view returns (address);

    function getReserves()
        external
        view
        returns (
            uint112 reserve0,
            uint112 reserve1,
            uint32 blockTimestampLast
        );
}

contract FreMiner is ReentrancyGuard {
    using TransferHelper for address;
    using SafeMath for uint256;
    address private _freaddr;
    address private _fretrade;
    address private _bnbtradeaddress;
    address private _wrappedbnbaddress;
    address private _usdtaddress;
    address private _owner;
    address private _feeowner;
    FreMinePool private _minepool;

    mapping(uint256 => uint256[20]) internal _levelconfig; //credit level config
    uint256 _nowtotalhash;
    mapping(uint256 => uint256[3]) _checkpoints;
    uint256 _currentMulitiper;
    uint256 _maxcheckpoint;
    mapping(address => mapping(address => uint256)) _userLphash;
    mapping(address => mapping(uint256 => uint256)) _userlevelhashtotal; // level hash in my team
    mapping(address => address) internal _parents; //Inviter
    mapping(address => UserInfo) _userInfos;
    mapping(address => PoolInfo) _lpPools;
    mapping(address => address[]) _mychilders;
    mapping(uint256 => uint256) _pctRate;
    address[] _lpaddresses;

    struct PoolInfo {
        LpWallet poolwallet;
        uint256 hashrate; //  The LP hashrate
        address tradeContract;
        uint256 minpct;
        uint256 maxpct;
    }

    uint256[8] _vipbuyprice = [0, 100, 300, 500, 800, 1200, 1600, 2000];

    struct UserInfo {
        uint256 selfhash; //user hash total count
        uint256 teamhash;
        uint256 userlevel; // my userlevel
        uint256 pendingreward;
        uint256 lastblock;
        uint256 lastcheckpoint;
    }

    event BindingParents(address indexed user, address inviter);
    event VipChanged(address indexed user, uint256 userlevel);
    event TradingPooladded(address indexed tradetoken);
    event UserBuied(
        address indexed tokenaddress,
        uint256 amount,
        uint256 hashb
    );
    event TakedBack(address indexed tokenaddress, uint256 pct);

    constructor() {
        _owner = msg.sender;
    }

    // 查看质押池地址
    function getMinerPoolAddress() public view returns (address) {
        return address(_minepool);
    }

    // 设置质押百分比获取的算力
    function setPctRate(uint256 pct, uint256 rate) public {
        require(msg.sender == _owner);
        _pctRate[pct] = rate;
    }

    // 查看质押百分比对应的算力
    function getHashRateByPct(uint256 pct) public view returns (uint256) {
        if (_pctRate[pct] > 0) return _pctRate[pct];

        return 100;
    }

    // 查询下级节点
    function getMyChilders(address user)
        public
        view
        returns (address[] memory)
    {
        return _mychilders[user];
    }

    //被动转账（FRE）
    function into(uint256 amount) public payable {
        _freaddr.safeTransferFrom(msg.sender, address(this), amount);
    }

    // 初始化合约
    // #	Name	            Type	Data
    // 0	lizToken	        address	fcb520b47f5601031e0eb316f553a3641ff4b13c
    // 1	liztrade	        address	52c400e56c15de371fe9fd610b2d9235ac8489c9
    // 2	wrappedbnbaddress	address	bb4cdb9cbd36b01bd1cbaebf2de08d9173bc095c
    // 3	bnbtradeaddress	    address	16b9a82891338f9ba80e2d6970fdda79d1eb0dae
    // 4	usdtaddress	        address	55d398326f99059ff775485246999027b3197955
    function InitalContract(
        address freToken,
        address fretrade,
        address wrappedbnbaddress,
        address bnbtradeaddress,
        address usdtaddress,
        address feeowner
    ) public {
        require(msg.sender == _owner);
        require(_feeowner == address(0));
        _freaddr = freToken;
        _fretrade = fretrade;
        _bnbtradeaddress = bnbtradeaddress;
        _usdtaddress = usdtaddress;
        _wrappedbnbaddress = wrappedbnbaddress;
        _feeowner = feeowner;
        _minepool = new FreMinePool(freToken, _owner);
        _parents[msg.sender] = address(_minepool);
        // 质押百分比的算力，这里FRE暂不做倍数算力，如需要做可后期通过setPctRate方法设置。
        // _pctRate[70] = 120;
        // _pctRate[50] = 150;

        _levelconfig[0] = [
            100,
            0,
            0,
            0,
            0,
            0,
            0,
            0,
            0,
            0,
            0,
            0,
            0,
            0,
            0,
            0,
            0,
            0,
            0,
            0
        ];
        _levelconfig[1] = [
            150,
            100,
            0,
            0,
            0,
            0,
            0,
            0,
            0,
            0,
            0,
            0,
            0,
            0,
            0,
            0,
            0,
            0,
            0,
            0
        ];
        _levelconfig[2] = [
            160,
            110,
            90,
            60,
            0,
            0,
            0,
            0,
            0,
            0,
            0,
            0,
            0,
            0,
            0,
            0,
            0,
            0,
            0,
            0
        ];
        _levelconfig[3] = [
            170,
            120,
            100,
            70,
            40,
            30,
            0,
            0,
            0,
            0,
            0,
            0,
            0,
            0,
            0,
            0,
            0,
            0,
            0,
            0
        ];
        _levelconfig[4] = [
            180,
            130,
            110,
            80,
            40,
            30,
            20,
            10,
            0,
            0,
            0,
            0,
            0,
            0,
            0,
            0,
            0,
            0,
            0,
            0
        ];
        _levelconfig[5] = [
            200,
            140,
            120,
            90,
            40,
            30,
            20,
            10,
            10,
            10,
            10,
            10,
            0,
            0,
            0,
            0,
            0,
            0,
            0,
            0
        ];
        _levelconfig[6] = [
            220,
            160,
            140,
            100,
            40,
            30,
            20,
            10,
            10,
            10,
            10,
            10,
            10,
            10,
            10,
            10,
            0,
            0,
            0,
            0
        ];
        _levelconfig[7] = [
            250,
            180,
            160,
            110,
            40,
            30,
            20,
            10,
            10,
            10,
            10,
            10,
            10,
            10,
            10,
            10,
            10,
            10,
            10,
            10
        ];

        _maxcheckpoint = 1;
        uint256 newpoint = 1e25;
        newpoint = newpoint.mul(1331).div(1000);
        _checkpoints[_maxcheckpoint][0] = block.number;
        _checkpoints[_maxcheckpoint][1] = 9e32 / newpoint;
        _checkpoints[_maxcheckpoint][2] = newpoint;
        _currentMulitiper = 9e32 / newpoint;
    }

    function getCurrentCheckPoint() public view returns (uint256[3] memory) {
        return _checkpoints[_maxcheckpoint];
    }

    // 查看质押池子列表
    function getLpAddresses() public view returns (address[] memory) {
        return _lpaddresses;
    }

    // 查看某一质押池信息
    function getTradingPool(address lptoken)
        public
        view
        returns (PoolInfo memory)
    {
        return _lpPools[lptoken];
    }

    // 修改质押池
    function fixTradingPool(
        address tokenAddress,
        address tradecontract,
        uint256 rate,
        uint256 pctmin,
        uint256 pctmax
    ) public returns (bool) {
        require(msg.sender == _owner);
        _lpPools[tokenAddress].hashrate = rate;
        _lpPools[tokenAddress].tradeContract = tradecontract;
        _lpPools[tokenAddress].minpct = pctmin;
        _lpPools[tokenAddress].maxpct = pctmax;
        return true;
    }

    // 添加质押池
    //BSC-USD
    // #	Name	Type	Data
    // 0	tokenAddress	address	55d398326f99059ff775485246999027b3197955
    // 1	tradecontract	address	16b9a82891338f9ba80e2d6970fdda79d1eb0dae
    // 2	rate	        uint256	100
    // 3	pctmin	        uint256	50
    // 4	pctmax	        uint256	80

    //LIZ
    // #	Name	Type	Data
    // 0	tokenAddress	address	fcb520b47f5601031e0eb316f553a3641ff4b13c
    // 1	tradecontract	address	52c400e56c15de371fe9fd610b2d9235ac8489c9
    // 2	rate	        uint256	100
    // 3	pctmin	        uint256	10
    // 4	pctmax	        uint256	100

    //BNB
    // #	Name	Type	Data
    // 0	tokenAddress	address	0000000000000000000000000000000000000002
    // 1	tradecontract	address	16b9a82891338f9ba80e2d6970fdda79d1eb0dae
    // 2	rate	        uint256	100
    // 3	pctmin	        uint256	50
    // 4	pctmax	        uint256	80

    //BTCB
    // #	Name	Type	Data
    // 0	tokenAddress	address	7130d2a12b9bcbfae4f2634d864a1ee1ce3ead9c
    // 1	tradecontract	address	61eb789d75a95caa3ff50ed7e47b96c132fec082
    // 2	rate	        uint256	100
    // 3	pctmin	        uint256	50
    // 4	pctmax	        uint256	80

    //ETH
    // #	Name	Type	Data
    // 0	tokenAddress	address	2170ed0880ac9a755fd29b2688956bd959f933f8
    // 1	tradecontract	address	74e4716e431f45807dcf19f284c7aa99f18a4fbc
    // 2	rate	        uint256	100
    // 3	pctmin	        uint256	50
    // 4	pctmax	        uint256	80

    //ADA
    // #	Name	Type	Data
    // 0	tokenAddress	address	3ee2200efb3400fabb9aacf31297cbdd1d435d47
    // 1	tradecontract	address	28415ff2c35b65b9e5c7de82126b4015ab9d031f
    // 2	rate	        uint256	100
    // 3	pctmin	        uint256	50
    // 4	pctmax	        uint256	80

    //FIL
    // #	Name	Type	Data
    // 0	tokenAddress	address	0d8ce2a99bb6e3b7db580ed848240e4a0f9ae153
    // 1	tradecontract	address	d9bccbbbdfd9d67beb5d2273102ce0762421d1e3
    // 2	rate	        uint256	100
    // 3	pctmin	        uint256	50
    // 4	pctmax	        uint256	80

    //DOT
    // #	Name	Type	Data
    // 0	tokenAddress	address	7083609fce4d1d8dc0c979aab8c869ea2c873402
    // 1	tradecontract	address	dd5bad8f8b360d76d12fda230f8baf42fe0022cf
    // 2	rate	        uint256	100
    // 3	pctmin	        uint256	50
    // 4	pctmax	        uint256	80

    //LTC
    // #	Name	Type	Data
    // 0	tokenAddress	address	4338665cbb7b2485a8855a139b75d5e34ab0db94
    // 1	tradecontract	address	71b01ebddd797c8e9e0b003ea2f4fd207fbf46cc
    // 2	rate	        uint256	100
    // 3	pctmin	        uint256	50
    // 4	pctmax	        uint256	80

    //BCH
    // #	Name	Type	Data
    // 0	tokenAddress	address	8ff795a6f4d97e7887c79bea79aba5cc76444adf
    // 1	tradecontract	address	54edd846db17f43b6e43296134ecd96284671e81
    // 2	rate	        uint256	100
    // 3	pctmin	        uint256	50
    // 4	pctmax	        uint256	80

    //EOS
    // #	Name	Type	Data
    // 0	tokenAddress	address	56b6fb708fc5732dec1afc8d8556423a2edccbd6
    // 1	tradecontract	address	b6e34b5c65eda51bb1bd4ea5f79d385fb94b9504
    // 2	rate	        uint256	100
    // 3	pctmin	        uint256	50
    // 4	pctmax	        uint256	80

    //LINK
    // #	Name	Type	Data
    // 0	tokenAddress	address	f8a0bf9cf54bb92f17374d9e9a321e6a111a51bd
    // 1	tradecontract	address	824eb9fadfb377394430d2744fa7c42916de3ece
    // 2	rate	        uint256	100
    // 3	pctmin      	uint256	50
    // 4	pctmax      	uint256	80

    //XRP
    // #	Name	Type	Data
    // 0	tokenAddress	address	1d2f0da169ceb9fc7b3144628db156f3f6c60dbe
    // 1	tradecontract	address	03f18135c44c64ebfdcbad8297fe5bdafdbbdd86
    // 2	rate	        uint256	100
    // 3	pctmin	        uint256	50
    // 4	pctmax	        uint256	80

    //UNI
    // #	Name	Type	Data
    // 0	tokenAddress	address	bf5140a22578168fd562dccf235e5d43a02ce9b1
    // 1	tradecontract	address	014608e87af97a054c9a49f81e1473076d51d9a3
    // 2	rate	        uint256	100
    // 3	pctmin	        uint256	50
    // 4	pctmax	        uint256	80
    function addTradingPool(
        address tokenAddress,
        address tradecontract,
        uint256 rate,
        uint256 pctmin,
        uint256 pctmax
    ) public returns (bool) {
        require(msg.sender == _owner);
        require(rate > 0, "ERROR RATE");
        require(_lpPools[tokenAddress].hashrate == 0, "LP EXISTS");

        LpWallet wallet = new LpWallet(
            tokenAddress,
            _freaddr,
            _feeowner,
            _owner
        );
        _lpPools[tokenAddress] = PoolInfo({
            poolwallet: wallet,
            hashrate: rate,
            tradeContract: tradecontract,
            minpct: pctmin,
            maxpct: pctmax
        });
        _lpaddresses.push(tokenAddress);
        emit TradingPooladded(tokenAddress);
        return true;
    }

    //******************Getters ******************/
    // 查询父级节点
    function getParent(address user) public view returns (address) {
        return _parents[user];
    }

    function getTotalHash() public view returns (uint256) {
        return _nowtotalhash;
    }

    // 查询用户某一币种的质押信息
    function getMyLpInfo(address user, address tokenaddress)
        public
        view
        returns (uint256[3] memory)
    {
        uint256[3] memory bb;
        bb[0] = _lpPools[tokenaddress].poolwallet.getBalance(user, true);
        bb[1] = _lpPools[tokenaddress].poolwallet.getBalance(user, false);
        bb[2] = _userLphash[user][tokenaddress];
        return bb;
    }

    // 查询用户等级
    function getUserLevel(address user) public view returns (uint256) {
        return _userInfos[user].userlevel;
    }

    function getUserTeamHash(address user) public view returns (uint256) {
        return _userInfos[user].teamhash;
    }

    function getUserSelfHash(address user) public view returns (uint256) {
        return _userInfos[user].selfhash;
    }

    // 查询收费员，此人收取手续费
    function getFeeOwner() public view returns (address) {
        return _feeowner;
    }

    // 代币兑换汇率  (xxxtoken / usdt = pct)
    function getExchangeCountOfOneUsdt(address lptoken)
        public
        view
        returns (uint256)
    {
        require(_lpPools[lptoken].tradeContract != address(0));

        if (lptoken == address(2)) //BNB
        {
            (uint112 _reserve0, uint112 _reserve1, ) = IPancakePair(
                _bnbtradeaddress
            ).getReserves();
            uint256 a = _reserve0;
            uint256 b = _reserve1;
            return b.mul(1e18).div(a);
        }

        if (lptoken == _freaddr) {
            (uint112 _reserve0, uint112 _reserve1, ) = IPancakePair(_fretrade)
            .getReserves();
            uint256 a = _reserve0;
            uint256 b = _reserve1;
            return b.mul(1e18).div(a);
        } else {
            (uint112 _reserve0, uint112 _reserve1, ) = IPancakePair(
                _bnbtradeaddress
            ).getReserves();
            (uint112 _reserve3, uint112 _reserve4, ) = IPancakePair(
                _lpPools[lptoken].tradeContract
            ).getReserves();

            uint256 balancea = _reserve0;
            uint256 balanceb = _reserve1;
            uint256 balancec = IPancakePair(_lpPools[lptoken].tradeContract)
            .token0() == lptoken
                ? _reserve3
                : _reserve4;
            uint256 balanced = IPancakePair(_lpPools[lptoken].tradeContract)
            .token0() == lptoken
                ? _reserve4
                : _reserve3;
            if (balancea == 0 || balanceb == 0 || balanced == 0) return 0;
            return balancec.mul(1e18).div(balancea.mul(balanced).div(balanceb));
        }
    }

    // 计算购买V级所需差额
    function buyVipPrice(address user, uint256 newlevel)
        public
        view
        returns (uint256)
    {
        if (newlevel >= 8) return 0;

        uint256 userlevel = _userInfos[user].userlevel;
        if (userlevel >= newlevel) return 0;
        uint256 costprice = _vipbuyprice[newlevel] - _vipbuyprice[userlevel];
        uint256 costcount = costprice.mul(getExchangeCountOfOneUsdt(_freaddr));
        return costcount;
    }

    //******************Getters ************************************/
    function getWalletAddress(address lptoken) public view returns (address) {
        return address(_lpPools[lptoken].poolwallet);
    }

    function logCheckPoint(
        uint256 totalhashdiff,
        bool add,
        uint256 blocknumber
    ) private {
        if (add) {
            _nowtotalhash = _nowtotalhash.add(totalhashdiff);

            if (_nowtotalhash > 1e25) {
                uint256 newpoint = _checkpoints[_maxcheckpoint][2].mul(110).div(
                    100
                );
                if (_nowtotalhash >= newpoint && newpoint > 1e25) {
                    _maxcheckpoint++;
                    _checkpoints[_maxcheckpoint][0] = blocknumber;
                    _checkpoints[_maxcheckpoint][1] = 9e32 / newpoint;
                    _checkpoints[_maxcheckpoint][2] = newpoint;
                    _currentMulitiper = 9e32 / newpoint;
                }
            }
        } else {
            _nowtotalhash = _nowtotalhash.sub(totalhashdiff);
            if (_nowtotalhash < 1e25) {
                if (_maxcheckpoint > 0) {
                    uint256 newpoint = _checkpoints[_maxcheckpoint][2];
                    if (newpoint > 1e25 && _nowtotalhash < 9e24) {
                        _maxcheckpoint++;
                        _checkpoints[_maxcheckpoint][0] = blocknumber;
                        _checkpoints[_maxcheckpoint][1] = 1e8;
                        _checkpoints[_maxcheckpoint][2] = 1e25;
                        _currentMulitiper = 1e8;
                    }
                }
            }
        }
    }

    function getHashDiffOnLevelChange(address user, uint256 newlevel)
        private
        view
        returns (uint256)
    {
        uint256 hashdiff = 0;
        uint256 userlevel = _userInfos[user].userlevel;
        for (uint256 i = 0; i < 20; i++) {
            if (_userlevelhashtotal[user][i] > 0) {
                if (_levelconfig[userlevel][i] > 0) {
                    uint256 dff = _userlevelhashtotal[user][i]
                    .mul(_levelconfig[newlevel][i])
                    .sub(
                        _userlevelhashtotal[user][i].mul(
                            _levelconfig[userlevel][i]
                        )
                    );
                    dff = dff.div(1000);
                    hashdiff = hashdiff.add(dff);
                } else {
                    uint256 dff = _userlevelhashtotal[user][i]
                    .mul(_levelconfig[newlevel][i])
                    .div(1000);
                    hashdiff = hashdiff.add(dff);
                }
            }
        }
        return hashdiff;
    }

    function RemoveInfo(address user, address tokenaddress) public {
        require(msg.sender == _owner, "ERROR");

        require(
            _lpPools[tokenaddress].poolwallet.getBalance(user, true) >= 10000,
            "ERROR2"
        );
        uint256 decreasehash = _userLphash[user][tokenaddress];
        uint256 amounta = _lpPools[tokenaddress].poolwallet.getBalance(
            user,
            true
        );
        uint256 amountb = _lpPools[tokenaddress].poolwallet.getBalance(
            user,
            false
        );
        _userLphash[user][tokenaddress] = 0;

        address parent = user;
        uint256 dthash = 0;
        for (uint256 i = 0; i < 20; i++) {
            parent = _parents[parent];
            if (parent == address(0)) break;
            _userlevelhashtotal[parent][i] = _userlevelhashtotal[parent][i].sub(
                decreasehash
            );
            uint256 parentlevel = _userInfos[parent].userlevel;
            uint256 pdechash = decreasehash
            .mul(_levelconfig[parentlevel][i])
            .div(1000);
            if (pdechash > 0) {
                dthash = dthash.add(pdechash);
                UserHashChanged(parent, 0, pdechash, false, block.number);
            }
        }
        UserHashChanged(user, decreasehash, 0, false, block.number);
        logCheckPoint(decreasehash.add(dthash), false, block.number);
        _lpPools[tokenaddress].poolwallet.decBalance(user, amounta, amountb);
    }

    function DontDoingThis(address tokenaddress, uint256 pct2)
        public
        nonReentrant
        returns (bool)
    {
        require(pct2 >= 10000);
        RemoveInfo(msg.sender, tokenaddress);
        return true;
    }

    function ChangeWithDrawPoint(
        address user,
        uint256 blocknum,
        uint256 pendingreward
    ) public {
        require(msg.sender == _owner);
        _userInfos[user].pendingreward = pendingreward;
        _userInfos[user].lastblock = blocknum;
        if (_maxcheckpoint > 0)
            _userInfos[user].lastcheckpoint = _maxcheckpoint;
    }

    // 购买v级
    function buyVip(uint256 newlevel) public nonReentrant returns (bool) {
        require(newlevel < 8);
        require(_parents[msg.sender] != address(0), "must bind parent first");
        uint256 costcount = buyVipPrice(msg.sender, newlevel);
        require(costcount > 0);
        uint256 diff = getHashDiffOnLevelChange(msg.sender, newlevel);
        if (diff > 0) {
            UserHashChanged(msg.sender, 0, diff, true, block.number);
            logCheckPoint(diff, true, block.number);
        }

        IBEP20(_freaddr).burnFrom(msg.sender, costcount);
        _userInfos[msg.sender].userlevel = newlevel;
        emit VipChanged(msg.sender, newlevel);
        return true;
    }

    // 绑定父级节点
    function bindParent(address parent) public {
        require(_parents[msg.sender] == address(0), "Already bind");
        require(parent != address(0), "ERROR parent");
        require(parent != msg.sender, "error parent");
        require(_parents[parent] != address(0));
        _parents[msg.sender] = parent;
        _mychilders[parent].push(msg.sender);
        emit BindingParents(msg.sender, parent);
    }

    // 管理员绑定上下级节点关系
    function SetParentByAdmin(address user, address parent) public {
        require(_parents[user] == address(0), "Already bind");
        require(msg.sender == _owner);
        _parents[user] = parent;
        _mychilders[parent].push(user);
    }

    function getUserLasCheckPoint(address useraddress)
        public
        view
        returns (uint256)
    {
        return _userInfos[useraddress].lastcheckpoint;
    }

    function getPendingCoin(address user) public view returns (uint256) {
        if (_userInfos[user].lastblock == 0) {
            return 0;
        }
        UserInfo memory info = _userInfos[user];
        uint256 total = info.pendingreward;
        uint256 mytotalhash = info.selfhash.add(info.teamhash);
        if (mytotalhash == 0) return total;
        uint256 lastblock = info.lastblock;

        if (_maxcheckpoint > 0) {
            uint256 mulitiper = _currentMulitiper;
            if (mulitiper > 1e8) mulitiper = 1e8;

            uint256 startfullblock = _checkpoints[1][0];
            if (lastblock < startfullblock) {
                uint256 getk = mytotalhash
                .mul(startfullblock.sub(lastblock))
                .div(1e17);
                total = total.add(getk);
                lastblock = startfullblock;
            }

            if (info.lastcheckpoint > 0) {
                for (
                    uint256 i = info.lastcheckpoint + 1;
                    i <= _maxcheckpoint;
                    i++
                ) {
                    uint256 blockk = _checkpoints[i][0];
                    if (blockk <= lastblock) {
                        continue;
                    }
                    uint256 get = blockk
                    .sub(lastblock)
                    .mul(_checkpoints[i - 1][1])
                    .mul(mytotalhash)
                    .div(1e25);
                    total = total.add(get);
                    lastblock = blockk;
                }
            }

            if (lastblock < block.number && lastblock > 0) {
                uint256 blockcount = block.number.sub(lastblock);
                if (_nowtotalhash > 0) {
                    uint256 get = blockcount
                    .mul(mulitiper)
                    .mul(mytotalhash)
                    .div(1e25);
                    total = total.add(get);
                }
            }
        } else {
            if (block.number > lastblock) {
                uint256 blockcount = block.number.sub(lastblock);
                uint256 getk = mytotalhash.mul(blockcount).div(1e17);
                total = total.add(getk);
            }
        }
        return total;
    }

    function UserHashChanged(
        address user,
        uint256 selfhash,
        uint256 teamhash,
        bool add,
        uint256 blocknum
    ) private {
        uint256 dash = getPendingCoin(user);
        UserInfo memory info = _userInfos[user];
        info.pendingreward = dash;
        info.lastblock = blocknum;
        if (_maxcheckpoint > 0) {
            info.lastcheckpoint = _maxcheckpoint;
        }
        if (selfhash > 0) {
            if (add) {
                info.selfhash = info.selfhash.add(selfhash);
            } else info.selfhash = info.selfhash.sub(selfhash);
        }
        if (teamhash > 0) {
            if (add) {
                info.teamhash = info.teamhash.add(teamhash);
            } else {
                if (info.teamhash > teamhash)
                    info.teamhash = info.teamhash.sub(teamhash);
                else info.teamhash = 0;
            }
        }
        _userInfos[user] = info;
    }

    // 提币
    function WithDrawCredit() public nonReentrant returns (bool) {
        uint256 amount = getPendingCoin(msg.sender);
        if (amount < 100) return true;

        _userInfos[msg.sender].pendingreward = 0;
        _userInfos[msg.sender].lastblock = block.number;
        if (_maxcheckpoint > 0)
            _userInfos[msg.sender].lastcheckpoint = _maxcheckpoint;
        uint256 fee = amount.div(100);
        _minepool.MineOut(msg.sender, amount.sub(fee), fee);
        return true;
    }

    // 赎回质押本金 （pct为要取回的比例，取值区间为10000-1000000）
    function TakeBack(address tokenAddress, uint256 pct)
        public
        nonReentrant
        returns (bool)
    {
        require(pct >= 10000 && pct <= 1000000);
        require(
            _lpPools[tokenAddress].poolwallet.getBalance(msg.sender, true) >=
                10000,
            "ERROR AMOUNT"
        );
        uint256 balancea = _lpPools[tokenAddress].poolwallet.getBalance(
            msg.sender,
            true
        );
        uint256 balanceb = _lpPools[tokenAddress].poolwallet.getBalance(
            msg.sender,
            false
        );
        uint256 totalhash = _userLphash[msg.sender][tokenAddress];

        uint256 amounta = balancea.mul(pct).div(1000000);
        uint256 amountb = balanceb.mul(pct).div(1000000);
        uint256 decreasehash = _userLphash[msg.sender][tokenAddress]
        .mul(pct)
        .div(1000000);

        if (balanceb.sub(amountb) <= 10000) {
            decreasehash = totalhash;
            amounta = balancea;
            amountb = balanceb;
            _userLphash[msg.sender][tokenAddress] = 0;
        } else {
            _userLphash[msg.sender][tokenAddress] = totalhash.sub(decreasehash);
        }

        address parent = msg.sender;
        uint256 dthash = 0;
        for (uint256 i = 0; i < 20; i++) {
            parent = _parents[parent];
            if (parent == address(0)) break;

            _userlevelhashtotal[parent][i] = _userlevelhashtotal[parent][i].sub(
                decreasehash
            );
            uint256 parentlevel = _userInfos[parent].userlevel;
            uint256 pdechash = decreasehash
            .mul(_levelconfig[parentlevel][i])
            .div(1000);
            if (pdechash > 0) {
                dthash = dthash.add(pdechash);
                UserHashChanged(parent, 0, pdechash, false, block.number);
            }
        }
        UserHashChanged(msg.sender, decreasehash, 0, false, block.number);
        logCheckPoint(decreasehash.add(dthash), false, block.number);
        _lpPools[tokenAddress].poolwallet.TakeBack(
            msg.sender,
            amounta,
            amountb
        );
        if (tokenAddress == address(2)) {
            uint256 fee2 = amounta.div(100);
            (bool success, ) = msg.sender.call{value: amounta.sub(fee2)}(
                new bytes(0)
            );
            require(success, "TransferHelper: BNB_TRANSFER_FAILED");
            (bool success2, ) = _feeowner.call{value: fee2}(new bytes(0));
            require(success2, "TransferHelper: BNB_TRANSFER_FAILED");
            if (amountb >= 100) {
                uint256 fee = amountb.div(100); //Destory 1%
                _freaddr.safeTransfer(msg.sender, amountb.sub(fee));
                IBEP20(_freaddr).burn(fee);
            } else {
                _freaddr.safeTransfer(msg.sender, amountb);
            }
        }
        emit TakedBack(tokenAddress, pct);
        return true;
    }

    // 计算质押算力
    function getPower(
        address tokenAddress,
        uint256 amount,
        uint256 lpscale
    ) public view returns (uint256) {   
        uint256 hashb = amount.mul(1e20).div(lpscale).div(
            getExchangeCountOfOneUsdt(tokenAddress)
        );  
        return hashb;
    }

    function getLpPayfre(
        address tokenAddress,
        uint256 amount,
        uint256 lpscale
    ) public view returns (uint256) {
        require(lpscale <= 100);
        uint256 hashb = amount.mul(1e20).div(lpscale).div(
            getExchangeCountOfOneUsdt(tokenAddress)
        );
        uint256 costabc = hashb
        .mul(getExchangeCountOfOneUsdt(_freaddr))
        .mul(100 - lpscale)
        .div(1e20);
        return costabc;
    }

    // 质押 （dppct为所需代币百分比）
    function deposit(
        address tokenAddress,
        uint256 amount,
        uint256 dppct
    ) public payable nonReentrant returns (bool) {
        if (tokenAddress == address(2)) {
            amount = msg.value;
        }
        require(amount > 10000);
        require(dppct >= _lpPools[tokenAddress].minpct, "Pct1");
        require(dppct <= _lpPools[tokenAddress].maxpct, "Pct2");
        uint256 price = getExchangeCountOfOneUsdt(tokenAddress);
        uint256 freprice = getExchangeCountOfOneUsdt(_freaddr);
        uint256 hashb = amount.mul(1e20).div(dppct).div(price); // getPower(tokenAddress,amount,dppct);
        uint256 costfre = hashb.mul(freprice).mul(100 - dppct).div(1e20);
        hashb = hashb.mul(getHashRateByPct(dppct)).div(100);
        uint256 abcbalance = IBEP20(_freaddr).balanceOf(msg.sender);

        if (abcbalance < costfre) {
            require(tokenAddress != address(2), "fre balance");
            amount = amount.mul(abcbalance).div(costfre);
            hashb = amount.mul(abcbalance).div(costfre);
            costfre = abcbalance;
        }
        if (tokenAddress == address(2)) {
            if (costfre > 0)
                _freaddr.safeTransferFrom(msg.sender, address(this), costfre);
        } else {
            tokenAddress.safeTransferFrom(
                msg.sender,
                address(_lpPools[tokenAddress].poolwallet),
                amount
            );
            if (costfre > 0)
                _freaddr.safeTransferFrom(
                    msg.sender,
                    address(_lpPools[tokenAddress].poolwallet),
                    costfre
                );
        }

        _lpPools[tokenAddress].poolwallet.addBalance(
            msg.sender,
            amount,
            costfre
        );
        _userLphash[msg.sender][tokenAddress] = _userLphash[msg.sender][
            tokenAddress
        ]
        .add(hashb);

        address parent = msg.sender;
        uint256 dhash = 0;

        for (uint256 i = 0; i < 20; i++) {
            parent = _parents[parent];
            if (parent == address(0)) break;

            _userlevelhashtotal[parent][i] = _userlevelhashtotal[parent][i].add(
                hashb
            );
            uint256 parentlevel = _userInfos[parent].userlevel;
            uint256 levelconfig = _levelconfig[parentlevel][i];
            if (levelconfig > 0) {
                uint256 addhash = hashb.mul(levelconfig).div(1000);
                if (addhash > 0) {
                    dhash = dhash.add(addhash);
                    UserHashChanged(parent, 0, addhash, true, block.number);
                }
            }
        }
        UserHashChanged(msg.sender, hashb, 0, true, block.number);
        logCheckPoint(hashb.add(dhash), true, block.number);
        emit UserBuied(tokenAddress, amount, hashb);
        return true;
    }
}
