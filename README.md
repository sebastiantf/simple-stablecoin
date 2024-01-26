## Simple Stablecoin

> ### 🚨 Code is not audited. Do not use in production

**Simple Stablecoin is a simple stablecoin 😆**

Seriously, it's a stablecoin that uses **Collateralized Debt Positions (CDP)** to mint and maintain the peg stability of the stablecoin.

CDPs are essentially similar to a simple lending protocol that allows you to deposit collateral and borrow stablecoins against it. The collateral is **over-collateralized** to ensure that the stablecoin is always backed by more than 100% of the value of the stablecoin in circulation.

A **liquidation threshold** of 80% is set to ensure that the collateral is always over-collateralized. If the value of the loan rises above 80% of the value of the stablecoin borrowed, collateral will be liquidated to repay part of the loan to bring health factor back up.

Simple Stablecoin uses **Chainlink price feeds** to determine the value of the collateral and uses them to stabilize the peg of the stablecoin to USD.
