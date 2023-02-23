// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

contract Wallet {

  address[] public owners;
  uint limit;
  uint balance;

  uint public totTransfers;

  struct Transfer {
    address payable to;
    uint amount;
    address[] signedBy;
    uint uid;
  }

  // transfers (uid) waiting to be signed by the owner
  mapping(address => uint[]) public pending;
  // all transfers that have not yet been approved
  mapping(uint => Transfer) public transfers;

  event TransferRequested(address _by, address _for, uint _amount);
  event TransferSigned(address _by, address _for, uint _amount);
  event TransferApproved(address[] _by, address _for, uint _amount);

  modifier onlyOwners() {
    bool isOwner = false;
    for (uint i = 0; i < owners.length; i++) {
      if (owners[i] == msg.sender) {
        isOwner = true;
      }
    }
    require(isOwner == true);
    _;
  }

  constructor(address[] memory _owners, uint _limit) {
    owners = _owners;
    limit = _limit;
  }

  function deposit() public payable returns(uint) {
    balance += msg.value;
    return balance;
  }

  function requestTransfer(address payable _to, uint _amount) public onlyOwners {
      uint uid = totTransfers++;
      // https://github.com/ethereum/solidity/issues/12401
      address[] memory empty;
      transfers[uid] = Transfer(_to, _amount, empty, uid);

    for (uint i = 0; i < owners.length; i++) {
      pending[owners[i]].push(uid);
    }
  }

  function getMyRequestedTrasfers() public view onlyOwners returns(Transfer[] memory) {
    Transfer[] memory result;
    uint[] memory pendingIds = pending[msg.sender];

    for (uint i = 0; i < pendingIds.length; i++) {
      result[i] = transfers[pendingIds[i]];
    }

    return result;
  }

  function approve(uint _uid) public onlyOwners {
    address signee = msg.sender;
    require(pending[signee][_uid] > 0);

    Transfer storage transfer = transfers[_uid];

    if (transfer.signedBy.length == 0) {
      require(transfer.amount < balance);
      // I'm going to reserve the money in the contract as soon as there's one approval
      balance -= transfer.amount;
    }

    // add signature
    if (transfer.signedBy.length < limit) {
      transfer.signedBy.push(signee);
      emit TransferSigned(signee, transfer.to, transfer.amount);
      // no longer pending for this owner
      delete pending[msg.sender][_uid];
    }

    if (transfer.signedBy.length == limit) {
      transfer.to.transfer(transfer.amount);
      emit TransferApproved(transfer.signedBy, transfer.to, transfer.amount);

      delete transfers[_uid];

      // remove from pending for all owners
      for (uint i = 0; i < owners.length; i++) {
        delete pending[owners[i]][_uid];
      }
    }

  }

}