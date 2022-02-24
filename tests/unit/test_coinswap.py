from brownie import network, exceptions
from scripts.scripts import LOCAL_BLOCKCHAIN_ENVIRONMENTS, get_account, get_contract, INITIAL_PRICE_FEED_VALUE
from scripts.deploy import deploy_CoinSwap_and_MangoToken
import pytest


def test_set_price_feed_contract():
    if network.show_active() not in LOCAL_BLOCKCHAIN_ENVIRONMENTS:
        pytest.skip()

    # Arrange
    account = get_account()
    non_owner = get_account(1)
    coinswap, mangoToken = deploy_CoinSwap_and_MangoToken()
    mangoTokenPriceFeed = get_contract("dai_usd_price_feed")

    # Act
    coinswap.setPriceFeedContract(mangoToken.address, mangoTokenPriceFeed, {"from": account})

    # Assert 
    assert coinswap.tokenPriceFeed(mangoToken.address) == mangoTokenPriceFeed

    with pytest.raises(exceptions.VirtualMachineError):
        coinswap.setPriceFeedContract(mangoToken.address, mangoTokenPriceFeed, {"from": non_owner})


def test_stake_tokens(amount_staked):
    # Arrange
    if network.show_active() not in LOCAL_BLOCKCHAIN_ENVIRONMENTS:
        pytest.skip()
    account = get_account()
    coinswap, mangoToken = deploy_CoinSwap_and_MangoToken()

    # Act
    mangoToken.approve(coinswap.address, amount_staked, {"from": account} )
    coinswap.stakeTokens(amount_staked, mangoToken.address, {"from": account})

    # Assert
    assert (
        coinswap.stakeBalance(mangoToken.address, account.address) == amount_staked
    )
    assert coinswap.uniqueTokensStaked(account.address) == 1
    assert coinswap.stakers(0) == account.address
    return coinswap, mangoToken


def test_issue_tokens(amount_staked):
    # Arrange
    if network.show_active() not in LOCAL_BLOCKCHAIN_ENVIRONMENTS:
        pytest.skip()
    account = get_account()
    coinswap, mangoToken = test_stake_tokens(amount_staked)

    starting_balance = mangoToken.balanceOf(account.address)

    # Act
    coinswap.issueTokens({"from": account})

    # Assert
    assert mangoToken.balanceOf(account.address) == starting_balance + INITIAL_PRICE_FEED_VALUE