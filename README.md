# Proxy Trading Pattern

The **proxy trading pattern** is a common development approach in Sui. Users often deposit some coins in a smart contract and request that these coins be traded according to specific requirements at a particular time. However, the Sui Move smart contract itself can't initiate transactions. It needs an external address to trigger transaction requests.  In terms of security, the addresses that can initiate transactions need to be restricted. This is what the proxy trading pattern is about. This design pattern is often seen in scenarios such as DCA (Dollar-Cost Averaging), limit orders, quantitative trading, and arbitrage trading between DEX and CEX.  

This tutorial will show you how to implement the proxy trading pattern.
