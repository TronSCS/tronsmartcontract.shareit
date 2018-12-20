pragma solidity ^0.4.23;




contract EtherKnight
{
  
  
  using SafeMath for uint256;
  using SafeMath128 for uint128;
  
  /*==============================
  = EVENTS =
  ==============================*/
  event OwnershipTransferred(
  
  address previousOwner,
  address nextOwner,
  uint256 timeStamp
  );
  
  event HDXcontractChanged(
  
  address previous,
  address next,
  uint256 timeStamp
  );
  
  
  
  event onWithdrawGains(
  address customerAddress,
  uint256 ethereumWithdrawn,
  uint256 timeStamp
  );
  
  event onNewRound(
  uint256 gRND,
  uint32 turnRound,
  uint32 eventType,
  uint32 eventTarget,
  uint32[4] persoEnergy,
  uint32[4] persoDistance,
  uint32[4] powerUpSpeed,
  uint32[4] powerUpShield,
  uint256 blockNumberTimeout,
  uint256 treasureAmountFind,
  address customerAddress
  
  
  
  );
  
  
  event onNewRace(
  
  uint256 gRND,
  uint8[4] persoType,
  uint256 blockNumber
  
  );
  
  event onBuyShare(
  address customerAddress,
  uint256 gRND,
  uint32 perso,
  uint256 nbToken,
  uint32 actionType,
  uint32 actionValue
  );
  
  
  event onMaintenance(
  bool mode,
  uint256 timeStamp
  
  );
  
  event onRefund(
  address indexed customerAddress,
  uint256 eth,
  uint256 timeStamp
  
  );
  
  event onCloseEntry(
  
  uint256 gRND
  
  );
  
  event onChangeBlockTimeAverage(
  
  uint256 blocktimeavg
  
  );
  
  /*==============================
  = MODIFIERS =
  ==============================*/
  modifier onlyOwner
  {
    require (msg.sender == owner );
    _;
  }
  
  
  
  modifier onlyDirectTransaction
  {
    require (msg.sender == tx.origin);
    _;
  }
  
  
  modifier isPlayer
  {
    require (PlayerData[ msg.sender].gRND !=0);
    _;
  }
  
  modifier isMaintenance
  {
    require (maintenanceMode==true);
    _;
  }
  
  modifier isNotMaintenance
  {
    require (maintenanceMode==false);
    _;
  }
  
  // Changing ownership of the contract safely
  address public owner;
  
  
  
  
  /// Contract governance.
  
  constructor () public
  {
    owner = msg.sender;
    
    
    if ( address(this).balance > 0)
    {
      owner.transfer( address(this).balance );
    }
  }
  
  function changeOwner(address _nextOwner) public
  onlyOwner
  {
    require (_nextOwner != owner);
    require(_nextOwner != address(0));
    
    emit OwnershipTransferred(owner, _nextOwner , now);
    
    owner = _nextOwner;
  }
  
  
  
  
  
  function changeBlockTimeAverage( uint256 blocktimeavg) public
  onlyOwner
  {
    require ( blocktimeavg>0 );
    
    
    blockTimeAverage = blocktimeavg;
    
    emit onChangeBlockTimeAverage( blockTimeAverage );
    
  }
  
  
  
  
  /*================================
  = GAMES VARIABLES =
  ================================*/
  
  struct PlayerData_s
  {
    
    uint256 chest;
    uint256 payoutsTo;
    uint256 gRND;
    
  }
  
  struct PlayerGameRound_s
  {
    uint256[4] shares;
    uint128 treasure_payoutsTo;
    uint128 token;
    
    
  }
  
  struct GameRoundData_s
  {
    uint256 blockNumber;
    uint256 blockNumberTimeout;
    uint256 sharePrice;
    uint256[4] sharePots;
    uint256 shareEthBalance;
    uint256 shareSupply;
    uint256 treasureSupply;
    
    
    //this time we want to stream the HDX20 apprecition and dev fees on the way
    uint256 allFeeSupply; //to separate the fees from the actual treasure
    
    uint256 devAppreciationPayout;
    //
    
    uint256 totalTreasureFound;
    uint256[6] actionBlockNumber;
    
    uint128[4] treasurePerShare;
    uint32[8] persoData; //energy[4] distance[4]
    uint32[8] powerUpData; //Speed[4] Shield[4]
    
    uint32[6] actionValue;
    
    uint32[6] extraData;//[0]==this_TurnRound , [1]==winner , [2-5] totalPlayers
    
  }
  
  
  
  
  
  
  
  mapping (address => PlayerData_s) private PlayerData;
  
  
  mapping (address => mapping (uint256 => PlayerGameRound_s)) private PlayerGameRound;
  
  
  mapping (uint256 => GameRoundData_s) private GameRoundData;
  
  
  bool private maintenanceMode=false;
  
  uint256 private this_gRND =0;
  
  
  
  
  //85 , missing 15% for shares appreciation eg:share price increase
  
  uint8 constant private TREASUREBuyFees = 45;
  uint8 constant private BUYPercentage = 40;
  
  
  //the part to keep from the treasure for next round treasure + hdx20 appreciation + dev
  uint8 constant private DevFees = 5;
  uint8 constant private TreasureFees = 35;
  
  uint8 constant private AddedFees = DevFees+TreasureFees;
  
  
  uint256 constant internal magnitude = 1e18;
  
  uint256 private genTreasure = 0;
  
  uint256 constant private minimumSharePrice = 0.001 * 1000000;
  
  uint256 private blockTimeAverage = 4; //seconds per block
  
  
  uint8[4] private this_Perso_Type;
  
  
  
  /*================================
  = PUBLIC FUNCTIONS =
  ================================*/
  
  //fallback will be called only from the HDX token contract to fund the game from customers's HDX20
  
  function()
  payable
  public
  
  {
    
    genTreasure = SafeMath.add( genTreasure , msg.value);
    
    
  }
  
  
  function ChargeTreasure() public payable
  {
    genTreasure = SafeMath.add( genTreasure , msg.value);
  }
  
  
  function buyTreasureShares(GameRoundData_s storage _GameRoundData , uint256 _eth ) private
  returns( uint256)
  {
    uint256 _nbshares = (_eth.mul( magnitude)) / _GameRoundData.sharePrice;
    uint256 _nbsharesForTreasure = (_nbshares.mul( 100-DevFees-TreasureFees)) / 100;
    
    //now we do separate for streamline payment
    _GameRoundData.treasureSupply = _GameRoundData.treasureSupply.add( _nbsharesForTreasure );
    //the difference is for the allFeeSupply
    _GameRoundData.allFeeSupply = _GameRoundData.allFeeSupply.add( _nbshares - _nbsharesForTreasure);
    
    
    _GameRoundData.shareSupply = _GameRoundData.shareSupply.add( _nbshares );
    
    return( _nbshares);
  }
  
  
  function initRace( uint8[4] p ) public
  onlyOwner
  isNotMaintenance
  {
    
    
    this_gRND++;
    
    GameRoundData_s storage _GameRoundData = GameRoundData[ this_gRND ];
    
    for( uint i=0;i<4;i++)
    {
      this_Perso_Type[i] = p[i];
      
      _GameRoundData.persoData[i] = 100;
      _GameRoundData.persoData[4+i] = 25;
      
    }
    
    _GameRoundData.blockNumber = block.number;
    
    _GameRoundData.blockNumberTimeout = block.number + (360*10*24*3600);
    
    uint256 _sharePrice = 0.001 * 1000000; // minimumSharePrice;
    
    _GameRoundData.sharePrice = _sharePrice;
    
    uint256 _nbshares = buyTreasureShares(_GameRoundData, genTreasure );
    
    //convert into ETH
    _nbshares = _nbshares.mul( _sharePrice ) / magnitude;
    
    //start balance
    _GameRoundData.shareEthBalance = _nbshares;
    
    genTreasure = genTreasure.sub( _nbshares);
    
    
    emit onNewRace( this_gRND , p , block.number);
    
  }
  
  
  
  function get_TotalPayout( GameRoundData_s storage _GameRoundData ) private view
  returns( uint256)
  {
    
    uint256 _payout = 0;
    
    uint256 _sharePrice = _GameRoundData.sharePrice;
    
    for(uint i=0;i<4;i++)
    {
      uint256 _bet = _GameRoundData.sharePots[i];
      
      _payout = _payout.add( _bet.mul (_sharePrice) / magnitude );
    }
    
    //from the whole treasure now since new version
    uint256 _potValue = (_GameRoundData.treasureSupply.mul( _sharePrice )) / magnitude;
    
    
    _payout = _payout.add( _potValue ).add(_GameRoundData.totalTreasureFound );
    
    
    return( _payout );
    
  }
  
  
  
  function get_PendingGains( address _player_address , uint256 _gRND) private view
  returns( uint256)
  {
    
    //did not play
    if (PlayerData[ _player_address].gRND != _gRND || _gRND==0) return( 0 );
    
    GameRoundData_s storage _GameRoundData = GameRoundData[ _gRND ];
    
    
    uint32 _winner = _GameRoundData.extraData[1];
    
    uint256 _gains = 0;
    uint256 _treasure = 0;
    uint256 _sharePrice = _GameRoundData.sharePrice;
    uint256 _shares;
    
    PlayerGameRound_s storage _PlayerGameRound = PlayerGameRound[ _player_address][_gRND];
    
    for(uint i=0;i<4;i++)
    {
      _shares = _PlayerGameRound.shares[ i ];
      
      _gains = _gains.add( _shares.mul( _sharePrice) / magnitude );
      
      
      _treasure = _treasure.add(_shares.mul( _GameRoundData.treasurePerShare[ i ] ) / magnitude);
      
    }
    
    if (_treasure >= _PlayerGameRound.treasure_payoutsTo) _treasure = _treasure.sub(_PlayerGameRound.treasure_payoutsTo );
    else _treasure = 0;
    
    _gains = _gains.add(_treasure );
    
    //if the race payment is made (race is over) then we add also the winner prize
    if (_winner>0 && _GameRoundData.extraData[0] >= (1<<30))
    {
      _shares = _PlayerGameRound.shares[ _winner-1 ];
      
      if (_shares>0)
      {
        //from the whole treasure now since new version
        _treasure = (_GameRoundData.treasureSupply.mul( _sharePrice )) / magnitude;
        
        
        _gains = _gains.add( _treasure.mul( _shares ) / _GameRoundData.sharePots[ _winner-1] );
        
      }
      
    }
    
    
    return( _gains );
    
  }
  
  
  //only for the Result Data Screen on the game not used for the payout
  
  function get_PendingGainsAll( address _player_address , uint256 _gRND) private view
  returns( uint256)
  {
    
    //did not play
    if (PlayerData[ _player_address].gRND != _gRND || _gRND==0) return( 0 );
    
    GameRoundData_s storage _GameRoundData = GameRoundData[ _gRND ];
    
    
    uint32 _winner = _GameRoundData.extraData[1];
    
    uint256 _gains = 0;
    uint256 _treasure = 0;
    uint256 _sharePrice = _GameRoundData.sharePrice;
    uint256 _shares;
    
    PlayerGameRound_s storage _PlayerGameRound = PlayerGameRound[ _player_address][_gRND];
    
    for(uint i=0;i<4;i++)
    {
      _shares = _PlayerGameRound.shares[ i ];
      
      _gains = _gains.add( _shares.mul( _sharePrice) / magnitude );
      
      
      _treasure = _treasure.add(_shares.mul( _GameRoundData.treasurePerShare[ i ] ) / magnitude);
      
    }
    
    if (_treasure >= _PlayerGameRound.treasure_payoutsTo) _treasure = _treasure.sub(_PlayerGameRound.treasure_payoutsTo );
    else _treasure = 0;
    
    _gains = _gains.add(_treasure );
    
    
    if (_winner>0)
    {
      _shares = _PlayerGameRound.shares[ _winner-1 ];
      
      if (_shares>0)
      {
        //from the whole treasure now since new version
        _treasure = (_GameRoundData.treasureSupply.mul( _sharePrice )) / magnitude;
        
        
        _gains = _gains.add( _treasure.mul( _shares ) / _GameRoundData.sharePots[ _winner-1] );
        
      }
      
    }
    
    
    return( _gains );
    
  }
  
  
  function process_sub_Taxes( GameRoundData_s storage _GameRoundData , uint256 minimum) private
  {
    uint256 _sharePrice = _GameRoundData.sharePrice;
    
    uint256 _potValue = _GameRoundData.allFeeSupply.mul( _sharePrice ) / magnitude;
    
    uint256 _dev = SafeMath.mul( _potValue , DevFees) / AddedFees;
    
    if (_dev > _GameRoundData.devAppreciationPayout)
    {
      _dev -= _GameRoundData.devAppreciationPayout;
      
      if (_dev>minimum)
      {
        _GameRoundData.devAppreciationPayout = _GameRoundData.devAppreciationPayout.add( _dev );
        
        owner.transfer( _dev );
        
      }
    }
    
    
    
  }
  
  //process the fees, hdx20 appreciation, calcul results at the end of the race
  function process_Taxes( GameRoundData_s storage _GameRoundData ) private
  {
    uint32 turnround = _GameRoundData.extraData[0];
    
    if (turnround>0 && turnround<(1<<30))
    {
      _GameRoundData.extraData[0] = turnround | (1<<30);
      
      uint256 _sharePrice = _GameRoundData.sharePrice;
      
      uint256 _potValue = _GameRoundData.allFeeSupply.mul( _sharePrice ) / magnitude;
      
      
      uint256 _treasure = SafeMath.mul( _potValue , TreasureFees) / AddedFees;
      
      
      genTreasure = genTreasure.add( _treasure );
      
      //take care of any left over
      process_sub_Taxes( _GameRoundData , 0);
      
      
    }
    
  }
  
  
  
  function BuyShare( uint32 perso , uint32 action ) public payable
  onlyDirectTransaction
  {
    
    
    address _customer_address = msg.sender;
    uint256 eth = msg.value;
    
    require( maintenanceMode==false && this_gRND>0 && (eth>=minimumSharePrice) &&(eth <=100*1000000) && perso<=3 && action <=5 && block.number <GameRoundData[ this_gRND ].blockNumberTimeout);
    
    
    CoreBuyShare( _customer_address , perso , eth , action );
    
  }
  
  /*================================
  = CORE BUY FUNCTIONS =
  ================================*/
  
  function CoreBuyShare( address _player_address , uint32 perso , uint256 eth , uint32 action ) private
  {
    
    PlayerGameRound_s storage _PlayerGameRound = PlayerGameRound[ _player_address][ this_gRND];
    
    GameRoundData_s storage _GameRoundData = GameRoundData[ this_gRND ];
    
    
    if (PlayerData[ _player_address].gRND != this_gRND)
    {
      
      if (PlayerData[_player_address].gRND !=0)
      {
        uint256 _gains = get_PendingGains( _player_address , PlayerData[ _player_address].gRND );
        
        PlayerData[ _player_address].chest = PlayerData[ _player_address].chest.add( _gains);
      }
      
      
      PlayerData[ _player_address ].gRND = this_gRND;
      
      
    }
    
    
    _GameRoundData.shareEthBalance = _GameRoundData.shareEthBalance.add( eth ); //minus the hdx20 fees
    
    //increase the treasure shares
    buyTreasureShares(_GameRoundData , (eth.mul(TREASUREBuyFees)) / 100 );
    
    //what is left for the player
    eth = eth.mul( BUYPercentage) / 100;
    
    uint256 _nbshare = (eth.mul( magnitude)) / _GameRoundData.sharePrice;
    
    _GameRoundData.shareSupply = _GameRoundData.shareSupply.add( _nbshare );
    _GameRoundData.sharePots[ perso ] = _GameRoundData.sharePots[ perso ].add( _nbshare);
    
    uint256 _tempo = _PlayerGameRound.shares[ perso ];
    
    if (_tempo==0)
    {
      _GameRoundData.extraData[ 2+perso ]++;
    }
    
    _PlayerGameRound.shares[ perso ] = _tempo.add( _nbshare);
    
    //this will always raise the price after 1 share
    if (_GameRoundData.shareSupply>magnitude)
    {
      _GameRoundData.sharePrice = (_GameRoundData.shareEthBalance.mul( magnitude)) / _GameRoundData.shareSupply;
    }
    
    
    _PlayerGameRound.treasure_payoutsTo = _PlayerGameRound.treasure_payoutsTo.add( uint128(_nbshare.mul( _GameRoundData.treasurePerShare[ perso ] ) / magnitude) );
    
    process_sub_Taxes( _GameRoundData , 0.2*1000000);
    
    uint32 actionValue = ApplyAction( perso , action , _nbshare , _player_address);
    
    _GameRoundData.actionValue[ action] = actionValue;
    
    emit onBuyShare( _player_address , this_gRND , perso , 0 , action, actionValue );
    
    
  }
  
  struct GameVar_s
  {
    uint32[4] perso_energy;
    uint32[4] perso_distance;
    uint32[4] powerUpShield;
    uint32[4] powerUpSpeed;
    
    uint32 event_type;
    uint32 event_target;
    
    uint32 winner;
    
    uint256 this_gRND;
    
    uint256 treasureAmountFind;
    
    bytes32 seed;
    
    uint256 blockNumberTimeout;
    
    uint32 turnround;
    
  }
  
  function actionPowerUpShield( uint32 perso , GameVar_s gamevar) pure private
  {
    
    gamevar.powerUpShield[ perso ] = 100;
    
  }
  
  function actionPowerUpSpeed( uint32 perso , GameVar_s gamevar) pure private
  {
    
    gamevar.powerUpSpeed[ perso ] = 100;
    
  }
  
  
  
  function actionApple( uint32 perso , GameVar_s gamevar) pure private
  {
    
    gamevar.event_type = 6; //apple / banana etc...
    
    gamevar.event_target = uint32(1)<<(perso*3);
    
    gamevar.perso_energy[ perso ] += 20;
    
    if (gamevar.perso_energy[ perso] > 150) gamevar.perso_energy[ perso ] = 150;
    
  }
  
  function actionBanana( GameVar_s gamevar ) pure private
  {
    
    gamevar.event_type = 6; //apple / banana etc...
    
    uint32 result = 2;
    
    uint32 target = get_modulo_value(gamevar.seed,18, 4);
    
    if (gamevar.winner>0) target = gamevar.winner-1;
    
    
    uint32 shield = uint32(gamevar.powerUpShield[ target ]);
    
    if (shield>20) result = 5; //jumping banana
    else
    {
      uint32 dd = 4 * (101 - shield);
      
      
      
      if (gamevar.perso_distance[ target ]>=dd) gamevar.perso_distance[ target ] -= dd;
      else gamevar.perso_distance[ target ] = 0;
      
    }
    
    gamevar.event_target = result<<(target*3);
    
    
    
  }
  
  function getTreasureProbabilityType( bytes32 seed ) private pure
  returns( uint32 )
  {
    uint8[22] memory this_TreasureProbability =[
    
    1,1,1,1,1,1,1,1,1,1,1,1, //12 chances to have 10%
    2,2,2,2,2,2, //6 chances to have 15%
    3,3,3, //3 chances to have 20%
    4 //1 chance to have 25%
    
    ];
    
    return( this_TreasureProbability[ get_modulo_value(seed,24, 22) ] );
  }
  
  
  
  function distribute_treasure( uint32 type2 , uint32 target , GameVar_s gamevar) private
  {
    uint8[5] memory this_TreasureValue =[
    
    1,
    10,
    15,
    20,
    25
    
    ];
    
    //from the whole treasure now since new version
    uint256 _treasureSupply = GameRoundData[ gamevar.this_gRND].treasureSupply;
    
    
    uint256 _sharePrice = GameRoundData[ gamevar.this_gRND].sharePrice;
    uint256 _shareSupply = GameRoundData[ gamevar.this_gRND].shareSupply;
    
    //how many shares to sell
    uint256 _amount = _treasureSupply.mul(this_TreasureValue[ type2 ] ) / 100;
    
    GameRoundData[ gamevar.this_gRND].treasureSupply = _treasureSupply.sub( _amount );
    GameRoundData[ gamevar.this_gRND].shareSupply = _shareSupply.sub( _amount );
    
    //in eth
    _amount = _amount.mul( _sharePrice ) / magnitude;
    
    //price of shares should not change
    GameRoundData[ gamevar.this_gRND].shareEthBalance = GameRoundData[ gamevar.this_gRND].shareEthBalance.sub( _amount );
    
    gamevar.treasureAmountFind = _amount;
    
    GameRoundData[ gamevar.this_gRND].totalTreasureFound = GameRoundData[ gamevar.this_gRND].totalTreasureFound.add( _amount );
    
    uint256 _shares = GameRoundData[ gamevar.this_gRND].sharePots[ target ];
    
    if (_shares>0)
    {
      
      GameRoundData[ gamevar.this_gRND].treasurePerShare[ target ] = GameRoundData[ gamevar.this_gRND].treasurePerShare[ target ].add( uint128(((_amount.mul(magnitude)) / _shares)));
    }
    
  }
  
  function actionTreasure( uint32 perso, GameVar_s gamevar ) private
  {
    gamevar.event_target = get_modulo_value(gamevar.seed,18, 14);
    gamevar.event_type = getTreasureProbabilityType( gamevar.seed );
    
    if (gamevar.event_target==perso)
    {
      
      distribute_treasure( gamevar.event_type , gamevar.event_target, gamevar);
    }
    
    
  }
  
  function apply_attack( uint32 perso, uint32 target , GameVar_s gamevar) pure private
  {
    for(uint i=0;i<4;i++)
    {
      uint32 damage = (1+(target % 3)) * 10;
      
      uint32 shield = uint32( gamevar.powerUpShield[i] );
      
      if (damage<= shield || i==perso) damage = 0;
      else damage -= shield;
      
      if (damage<gamevar.perso_energy[i]) gamevar.perso_energy[i] -= damage;
      else gamevar.perso_energy[i] = 1; //minimum
      
      target >>= 2;
      
    }
    
  }
  
  
  function actionAttack( uint32 perso , GameVar_s gamevar ) pure private
  {
    gamevar.event_type = 5;
    gamevar.event_target = get_modulo_value(gamevar.seed,24,256); //8 bits 4x2
    
    apply_attack( perso , gamevar.event_target , gamevar);
  }
  
  function ApplyAction( uint32 perso , uint32 action , uint256 nbshare , address _player_address) private
  returns( uint32)
  {
    uint32 actionValue = GameRoundData[ this_gRND].actionValue[ action ];
    
    //only the last one is activating within the same block
    if (block.number<= GameRoundData[ this_gRND].actionBlockNumber[ action]) return( actionValue);
    
    GameVar_s memory gamevar;
    
    gamevar.turnround = GameRoundData[ this_gRND ].extraData[0];
    
    //now we introduce a new price increase for the items
    nbshare = nbshare.mul(100*100);
    nbshare /= (100+(gamevar.turnround/6));
    
    nbshare /= magnitude;
    
    nbshare += 10;
    
    if (nbshare>5000) nbshare = 5000;
    
    actionValue += uint32( nbshare );
    
    
    uint16[6] memory actionPrice =[
    
    1000, //apple
    4000, //powerup shield
    5000, //powerup speed
    2000, //chest
    1000, //banana action
    3000 //attack
    
    ];
    
    if (actionValue<actionPrice[action] && gamevar.turnround>0)
    {
      
      return( actionValue );
    }
    
    if (actionValue>=actionPrice[action])
    {
      GameRoundData[ this_gRND].actionBlockNumber[ action] = block.number;
      
      actionValue = 0;
    }
    else action = 100; //this is the first action
    
    gamevar.turnround++;
    
    
    
    
    gamevar.this_gRND = this_gRND;
    gamevar.winner = GameRoundData[ gamevar.this_gRND].extraData[1];
    
    
    uint i;
    
    for( i=0;i<4;i++)
    {
      gamevar.perso_energy[i] = GameRoundData[ gamevar.this_gRND].persoData[i];
      gamevar.perso_distance[i] = GameRoundData[ gamevar.this_gRND].persoData[4+i];
      gamevar.powerUpSpeed[i] = GameRoundData[ gamevar.this_gRND].powerUpData[i] / 2;
      gamevar.powerUpShield[i] = GameRoundData[ gamevar.this_gRND].powerUpData[4+i] / 2;
      
    }
    
    
    
    //a little boost for the fist action maker
    if (gamevar.turnround==1) gamevar.perso_energy[ perso ] += 5;
    
    getSeed( gamevar);
    
    
    if (action==0) actionApple( perso , gamevar );
    if (action==1) actionPowerUpShield( perso , gamevar);
    if (action==2) actionPowerUpSpeed( perso , gamevar );
    if (action==3) actionTreasure( perso, gamevar);
    if (action==4) actionBanana( gamevar);
    if (action==5) actionAttack( perso , gamevar);
    
    gamevar.event_type |= (perso<<16);
    
    uint32 CurrentWinnerXpos = 0; //gamevar.perso_distance[0]; //this.Racers[n].perso_distance;
    
    for( i=0; i<4;i++)
    {
      
      //tiredness
      gamevar.perso_energy[ i ] *= 95;
      gamevar.perso_energy[ i ] /= 100;
      
      
      uint32 spd1 = (gamevar.perso_energy[ i ]*10) + (gamevar.powerUpSpeed[ i ]*10);
      
      gamevar.perso_distance[ i ] = ( (gamevar.perso_distance[ i ]*95) + (spd1*100) )/100;
      
      if (gamevar.perso_distance[i] > CurrentWinnerXpos)
      {
        CurrentWinnerXpos = gamevar.perso_distance[i];
        gamevar.winner = uint8(i);
      }
      
      GameRoundData[ gamevar.this_gRND].persoData[i] = gamevar.perso_energy[i];
      GameRoundData[ gamevar.this_gRND].persoData[4+i] = gamevar.perso_distance[i];
      GameRoundData[ gamevar.this_gRND].powerUpData[i] = gamevar.powerUpSpeed[i];
      GameRoundData[ gamevar.this_gRND].powerUpData[4+i] = gamevar.powerUpShield[i];
      
    }
    
    GameRoundData[ gamevar.this_gRND ].extraData[0] = gamevar.turnround;
    
    GameRoundData[ gamevar.this_gRND].extraData[1] = 1+gamevar.winner;
    
    gamevar.blockNumberTimeout = block.number + ((24*3600) / blockTimeAverage);
    
    GameRoundData[ gamevar.this_gRND].blockNumberTimeout = gamevar.blockNumberTimeout;
    
    
    
    emitRound( gamevar , _player_address);
    
    return( actionValue );
  }
  
  function emitRound(GameVar_s gamevar , address _player_address) private
  {
    emit onNewRound(
    gamevar.this_gRND,
    gamevar.turnround,
    gamevar.event_type,
    gamevar.event_target,
    gamevar.perso_energy,
    gamevar.perso_distance,
    gamevar.powerUpSpeed,
    gamevar.powerUpShield,
    gamevar.blockNumberTimeout,
    gamevar.treasureAmountFind,
    _player_address
    
    );
    
  }
  
  
  function get_Gains(address _player_address) private view
  returns( uint256)
  {
    
    uint256 _gains = PlayerData[ _player_address ].chest.add( get_PendingGains( _player_address , PlayerData[ _player_address].gRND ) );
    
    if (_gains > PlayerData[ _player_address].payoutsTo)
    {
      _gains -= PlayerData[ _player_address].payoutsTo;
    }
    else _gains = 0;
    
    
    return( _gains );
    
  }
  
  
  function WithdrawGains() public
  isPlayer
  {
    address _customer_address = msg.sender;
    
    uint256 _gains = get_Gains( _customer_address );
    
    require( _gains>0);
    
    PlayerData[ _customer_address ].payoutsTo = PlayerData[ _customer_address ].payoutsTo.add( _gains );
    
    
    emit onWithdrawGains( _customer_address , _gains , now);
    
    _customer_address.transfer( _gains );
    
    
  }
  
  function getSeed(GameVar_s gamevar) private view
  
  {
    uint256 _seed = uint256( blockhash( block.number-1) );
    _seed ^= uint256( blockhash( block.number-2) );
    _seed ^= uint256(block.coinbase) / now;
    _seed += gamevar.perso_distance[0];
    _seed += gamevar.perso_distance[1];
    _seed += gamevar.perso_distance[2];
    _seed += gamevar.perso_distance[3];
    
    _seed += gasleft();
    
    gamevar.seed = keccak256(abi.encodePacked( _seed));
    
    
  }
  
  function CloseEntry() public
  onlyOwner
  isNotMaintenance
  {
    
    GameRoundData_s storage _GameRoundData = GameRoundData[ this_gRND ];
    
    process_Taxes( _GameRoundData);
    
    emit onCloseEntry( this_gRND );
    
  }
  
  
  
  
  function get_probability( bytes32 seed , uint32 bytepos , uint32 percentage) pure private
  returns( bool )
  {
    uint32 v = uint32(seed[bytepos]);
    
    if (v<= ((255*percentage)/100)) return( true );
    else return( false );
    
  }
  
  function get_modulo_value( bytes32 seed , uint32 bytepos, uint32 mod) pure private
  returns( uint32 )
  {
    
    return( ((uint32(seed[ bytepos])*256)+(uint32(seed[ bytepos+1]))) % mod);
  }
  
  
  
  
  
  
  /*================================
  = VIEW AND HELPERS FUNCTIONS =
  ================================*/
  
  
  function view_get_Treasure() public
  view
  returns(uint256)
  {
    
    return( genTreasure);
  }
  
  function view_get_allFees() public
  view
  returns(uint256)
  {
    
    return( (GameRoundData[ this_gRND].allFeeSupply * GameRoundData[ this_gRND].sharePrice) / magnitude);
  }
  
  function view_get_gameData() public
  view
  returns( uint256 sharePrice, uint256[4] sharePots, uint256 shareSupply , uint256 shareEthBalance, uint128[4] treasurePerShare, uint32[4] totalPlayers , uint32[6] actionValue , uint256[4] shares , uint256 treasure_payoutsTo ,uint256 treasureSupply )
  {
    address _player_address = msg.sender;
    
    sharePrice = GameRoundData[ this_gRND].sharePrice;
    sharePots = GameRoundData[ this_gRND].sharePots;
    shareSupply = GameRoundData[ this_gRND].shareSupply;
    shareEthBalance = GameRoundData[ this_gRND].shareEthBalance;
    treasurePerShare = GameRoundData[ this_gRND].treasurePerShare;
    
    treasureSupply = GameRoundData[ this_gRND].treasureSupply;
    
    uint32[4] memory totalPlayersm;
    
    totalPlayersm[0] = GameRoundData[ this_gRND].extraData[2];
    totalPlayersm[1] = GameRoundData[ this_gRND].extraData[3];
    totalPlayersm[2] = GameRoundData[ this_gRND].extraData[4];
    totalPlayersm[3] = GameRoundData[ this_gRND].extraData[5];
    
    
    totalPlayers = totalPlayersm;
    actionValue = GameRoundData[ this_gRND].actionValue;
    
    shares = PlayerGameRound[_player_address][this_gRND].shares;
    
    treasure_payoutsTo = PlayerGameRound[_player_address][this_gRND].treasure_payoutsTo;
  }
  
  
  function view_get_Gains()
  public
  view
  returns( uint256 gains)
  {
    
    address _player_address = msg.sender;
    
    
    uint256 _gains = PlayerData[ _player_address ].chest.add( get_PendingGains( _player_address , PlayerData[ _player_address].gRND) );
    
    if (_gains > PlayerData[ _player_address].payoutsTo)
    {
      _gains -= PlayerData[ _player_address].payoutsTo;
    }
    else _gains = 0;
    
    
    return( _gains );
    
  }
  
  
  
  function view_get_gameStates() public
  view
  returns(uint8[4] types, uint256 grnd, uint32 turnround, uint256 minimumshare , uint256 blockNumber , uint256 blockNumberTimeout, uint32[6] actionValue , uint32[8] persoData , uint32[8] powerUpData , uint256 blockNumberCurrent , uint256 blockTimeAvg)
  {
    return( this_Perso_Type, this_gRND , GameRoundData[ this_gRND].extraData[0] , minimumSharePrice , GameRoundData[ this_gRND].blockNumber,GameRoundData[ this_gRND].blockNumberTimeout, GameRoundData[ this_gRND].actionValue , GameRoundData[ this_gRND].persoData , GameRoundData[ this_gRND].powerUpData, block.number , blockTimeAverage /*, view_get_MyRacer()*/);
  }
  
  function view_get_ResultData() public
  view
  returns(uint32 TotalPlayer, uint256 TotalPayout ,uint256 MyTokenValue, uint256 MyToken, uint256 MyGains , uint256 MyTreasureFound )
  {
    address _player_address = msg.sender;
    
    GameRoundData_s storage _GameRoundData = GameRoundData[ this_gRND ];
    
    TotalPlayer = _GameRoundData.extraData[2]+_GameRoundData.extraData[3]+_GameRoundData.extraData[4]+_GameRoundData.extraData[5];
    
    TotalPayout = get_TotalPayout( _GameRoundData );
    
    MyToken = PlayerGameRound[ _player_address][ this_gRND].token;
    
    MyTokenValue = 0;
    
    MyGains = 0;
    MyTreasureFound = 0;
    
    if (PlayerData[ _player_address].gRND == this_gRND)
    {
      
      MyGains = get_PendingGainsAll( _player_address , this_gRND ); //just here for the view function so not used for any payout
      
      
      for(uint i=0;i<4;i++)
      {
        MyTreasureFound += PlayerGameRound[_player_address][ this_gRND].shares[ i ].mul( _GameRoundData.treasurePerShare[ i ] ) / magnitude;
      }
      
      
      if (MyTreasureFound >= PlayerGameRound[_player_address][this_gRND].treasure_payoutsTo) MyTreasureFound = MyTreasureFound.sub( PlayerGameRound[_player_address][this_gRND].treasure_payoutsTo );
      else MyTreasureFound = 0;
      
      
      
    }
    
    
  }
  
  
  function totalEthereumBalance()
  public
  view
  returns(uint256)
  {
    return address(this).balance;
  }
  
  function view_get_maintenanceMode()
  public
  view
  returns(bool)
  {
    return( maintenanceMode);
  }
  
  function view_get_blockNumbers()
  public
  view
  returns( uint256 b1 , uint256 b2 )
  {
    return( block.number , GameRoundData[ this_gRND ].blockNumberTimeout);
    
  }
  
  
}


library SafeMath {
  
  
  function mul(uint256 a, uint256 b)
  internal
  pure
  returns (uint256 c)
  {
    if (a == 0) {
      return 0;
    }
    c = a * b;
    require(c / a == b);
    return c;
  }
  
  
  function sub(uint256 a, uint256 b)
  internal
  pure
  returns (uint256)
  {
    require(b <= a);
    return a - b;
  }
  
  
  function add(uint256 a, uint256 b)
  internal
  pure
  returns (uint256 c)
  {
    c = a + b;
    require(c >= a);
    return c;
  }
  
  
  
  
  
  
}


library SafeMath128 {
  
  
  function mul(uint128 a, uint128 b)
  internal
  pure
  returns (uint128 c)
  {
    if (a == 0) {
      return 0;
    }
    c = a * b;
    require(c / a == b);
    return c;
  }
  
  
  function sub(uint128 a, uint128 b)
  internal
  pure
  returns (uint128)
  {
    require(b <= a);
    return a - b;
  }
  
  
  function add(uint128 a, uint128 b)
  internal
  pure
  returns (uint128 c)
  {
    c = a + b;
    require(c >= a);
    return c;
  }
  
  
  
  
  
  
}
