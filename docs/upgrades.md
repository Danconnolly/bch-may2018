# BCH May 2018 Upgrade Notes

A collection of notes on testing and preparing test environments for the
Bitcoin Cash May 2018 upgrade.

## Forced versus unforced upgrades

When preparing a test environment its important to consider the upgrade mechanism
and we can distinguish two types of upgrades, forced and unforced.

A *forced* upgrade is where up-to-date implementations will check for a certain condition
in the block produced after the upgrade time and reject any blocks that do not meet
this condition. An example of a forced upgrade was the fork which created BCH
on August 1st 2017: the first block was required to be larger than 1MB,
cleanly separating the BCH chain from the BTC chain.

In the case of a forced upgrade, up-to-date implementations will ignore blocks
produced by out-of-date implementations. If multiple blocks are produced which
meet the condition then the normal rules apply regarding following the
chain with the highest proof of work.

An *unforced* upgrade is where a condition on a block as described above
is not required. This may be the case when a new block configuration is
possible but not required.

In the case of an unforced upgrade, up-to-date implementations will follow the
chain with the highest proof of work, regardless of whether the blocks in
this chain were produced by up-to-date implementations or out-of-date implementations.
If a block is produced with a new configuration by an up-to-date implementation,
then this block may be rejected by the out-of-date implementations and a fork
will occur. Both chains of this fork will be valid for the up-to-date
implementations.

The BCH May 2018 upgrade is an unforced upgrade.

## Consequences for testing

The requirements for properly testing the BCH May 2018 upgrade are:

* to establish a test network where the upgrade occurs at a pre-determined time
* to ensure that the upgraded test network chain survives in a potentially hostile environment
* to provide full and unfettered access to the public to this test network

In the case of a forced upgrade, this is relatively simple. One of more nodes
are set up on the public testnet with a pre-configure upgrade time and at least one
miner. The node details are publicized so that other nodes can connect to them.
When the upgrade occurs, the miner will produce a block which matches the
required conditions and up-to-date implementations will follow this chain.
Out-of-date implementations on the test network will continue with their own fork.

However, with an unforced upgrade there is a problem: the upgraded
fork may lose in the contest for most proof of work. Any test transactions
or test blocks that were submitted would be lost during a chain re-organization.
We need to avoid this issue because it will interfere with test plans.

The problem occurs because nodes connect to both up-to-date and out-of-date
peers and follow the chain with the most work.

One option is to completely isolate the upgrade test network, to only allow
updated implementations to connect to it. However, this solution reduces
the 'unfettered access' requirement and is also not resilient to attacks
because it is not possible to completely control the configuration of all peers.

Another option is:

* start a new node, the "root" node, and sync to the existing testnet
* add a miner to this node
* publicize this node and the parameters (`monolithactivationtime`)
* before the activation time, disconnect the root node from the network
* continue mining until after the activation time
* whitelist the first block produced after the activation time
* re-connect the root node to the network
* publicize the hash of the whitelisted block

Other nodes that wish to join the upgraded test network can connect to the
"root" node and also whitelist the upgraded block. Note that nodes joining
this network may become banned by the rest of the testnet.

One disadvantage of this method is that the changeover during the actual
upgrade is not tested.
