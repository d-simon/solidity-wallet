rep = ReputationToken.at(ReputationToken.address);
w = Wallet.at(Wallet.address);
const [owner, creator, guest1, guest2, maliciousGuest] = web3.eth.accounts;
w.sendTransaction({ value: web3.toWei(10) });
w.spend(guest1, web3.toWei(1));

web3.fromWei(web3.eth.getBalance(w.address));
rep.balanceOf(w.address);

w.setWhitelisted(guest1, true, { from: owner })
w.setWhitelisted(guest2, true, { from: owner })

// Approved Executes Should Succeed (If enough balance is there)

w.request(guest2, 1, { from: guest1 })
w.approve(0, guest2, 1)
w.execute(0, { from: guest1 });

w.sendTransaction({ value: web3.toWei(10), from: guest1 });
w.execute(0, { from: guest1 });

// After Tokens are implemented:
w.request(guest2, 1, 1517300134, rep.address, { from: guest1 })
w.approve(0, guest2, 1, 1517300134, rep.address)
w.execute(0, { from: guest1 });
rep.balanceOf(guest2);


// Rejected Executes Should Fail

w.request(guest2, 1, { from: guest1 })
w.reject(0, guest2, 1)
w.execute(0, { from: guest1 });


// non-whitelisted should NOT be able to make requests
w.request(maliciousGuest, 10, { from: maliciousGuest })
