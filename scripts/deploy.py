import json
from web3 import Web3
from brownie import network, config, MangoToken, CoinSwap
from scripts.scripts import get_account, get_contract
import yaml, os, shutil

KEPT_BALANCE = Web3.toWei(100, "ether")

# MGO Token, WETH, FAU, 
def add_allowed_tokens(coinswap, dict_of_allowed_tokens: dict, account):
    for token, _priceFeed in dict_of_allowed_tokens.items():
        add_tx = coinswap.addAllowedTokens(token.address, {"from": account})
        add_tx.wait(1)
        pf_tx = coinswap.setPriceFeedContract(token.address, _priceFeed, {"from": account})
        pf_tx.wait(1)
    return coinswap

def update_front_end():
    copy_folders_to_front_end("./build", "./front_end/src/chain-info")

    with open ("brownie-config.yaml", "r") as brownie_config:
        config_dict = yaml.load(brownie_config, Loader=yaml.FullLoader) 
        with open("./front_end/src/brownie-config.json", "w") as brownie_json:
            json.dump(config_dict, brownie_json)
    print("front End updated")

def copy_folders_to_front_end(src, dest):
    if os.path.exists(dest):
        shutil.rmtree(dest)
    shutil.copytree(src, dest)

def stake_tokens(account, mangoToken, coinswap, amount_staked ):
    approve_tx = mangoToken.approve(coinswap.address, amount_staked, {"from": account} )
    approve_tx.wait(1)
    stake_ts = coinswap.stakeTokens(amount_staked, mangoToken.address, {"from": account})
    stake_ts.wait(1)
    print("1 MGO Staked.")

def deploy_CoinSwap_and_MangoToken(update_frontend=False):
    account = get_account()
    mangoToken = MangoToken.deploy({"from": account})
    coinSwap = CoinSwap.deploy(mangoToken.address, {"from": account}, publish_source=config["networks"][network.show_active()].get("verify", False))

    mgo_to_coinswap_tx = mangoToken.transfer(coinSwap.address, mangoToken.totalSupply() - KEPT_BALANCE, {"from": account})
    mgo_to_coinswap_tx.wait(1)

    weth_token = get_contract("weth_token")
    fau_token = get_contract("fau_token")
    dict_of_allowed_tokens = {
        mangoToken: get_contract("dai_usd_price_feed"),
        fau_token: get_contract("dai_usd_price_feed"),
        weth_token: get_contract("eth_usd_price_feed"),
    }
    if update_frontend: update_front_end()
    add_allowed_tokens(coinSwap, dict_of_allowed_tokens, account)
    stake_tokens(account, mangoToken, coinSwap, Web3.toWei(1, "ether"))
    return coinSwap, mangoToken


def main():
    deploy_CoinSwap_and_MangoToken(update_frontend=True)