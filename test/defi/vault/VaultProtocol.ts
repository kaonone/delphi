import { 
    VaultProtocolContract, VaultProtocolInstance 
} from "../../../types/truffle-contracts/index";

// tslint:disable-next-line:no-var-requires
const { BN, constants, expectEvent, shouldFail, time } = require("@openzeppelin/test-helpers");
// tslint:disable-next-line:no-var-requires
import Snapshot from "../../utils/snapshot";
const { expect, should } = require('chai');

const expectRevert= require("../../utils/expectRevert");
const expectEqualBN = require("../../utils/expectEqualBN");
const w3random = require("../../utils/w3random");

const VaultProtocol = artifacts.require("VaultProtocol");

contract("VaultProtocol", async ([_, owner, ...otherAccounts]) => {
    let snap: Snapshot;
    let vaultProtocol: VaultProtocolInstance;


    before(async () => {
        //Save snapshot
        snap = await Snapshot.create(web3.currentProvider);
    });

//    beforeEach(async () => {
//    });
    describe('Deposit into the vault', () => {
        it('Deposit single token into the vault', async () => {
            let res = true;
            expect(res, 'Some message').to.be.true;

            //Deposit record appears in on-hold storage
            //Token is transfered to the VaultProtocol contract
        });

        it('Deposit several tokens into the vault', async () => {
            let res = false;
            expect(res, 'Some message').to.be.false;


            //Deposit records appear in on-hold storage
            //Tokens are transfered to the VaultProtocol contract
        });

        it('Additional deposit (previous is not processed yet)', async () => {
            let res = true;
            expect(res, 'Some message').to.be.true;

            //Deposit record is updated in on-hold storage
            //Token is transfered to the VaultProtocol contract
        });
    });

    describe('Withdraw token not processed by operator from the vault', () => {
        it('Withdraw on-hold token (enough liquidity)', async () => {
            let res = true;
            expect(res, 'Some message').to.be.true;

            //Deposit record is removed from on-hold storage
            //Token is transfered back to the user
        });

        it('Withdraw more on-hold token than deposited', async () => {
            let res = true;
            expect(res, 'Some message').to.be.true;

            //error message returned
        });

        it('Withdraw the part of on-hold tokens (enough liquidity)', async () => {
            let res = true;
            expect(res, 'Some message').to.be.true;

            //Deposit record is updated in the on-hold storage
            //Token is transfered back to the user
        });

        it('Cannot withdraw on-hold tokens if no deposit made', async () => {
            let res = true;
            expect(res, 'Some message').to.be.true;

            //Transaction failed
            //Get error message
        });

        it('Withdraw on-hold token (not enough liquidity)', async () => {
            let res = true;
            expect(res, 'Some message').to.be.true;

            //appears in the moment when someone (with already processed deposit) has withdrawn the liquidity

            //Deposit record is removed from the on-hold storage
            //Withdraw request is created
        });

        it('Withdraw on-hold token (not enough liquidity, not the whole amount)', async () => {
            let res = true;
            expect(res, 'Some message').to.be.true;

            //appears in the moment when someone (with already processed deposit) has withdrawn the liquidity

            //Deposit record is updated in the on-hold storage
            //Withdraw request is created
        });

        it('Withdraw on-hold token (not enough liquidity, liquidity for claim exists)', async () => {
            let res = true;
            expect(res, 'Some message').to.be.true;

            //appears in the moment when someone (with already processed deposit) has withdrawn the free liquidity
            //but there is some liquidity withdrawn by operator from the protocol but not claimed yet

            //Withdraw request is created
            //Deposit record is removed from the on-hold storage
            //Tokens for claim are untouched
        });
    });

    describe('Withdraw token from the protocol', () => {
        it('Withdraw token (enough liquidity)', async () => {
            let res = true;
            expect(res, 'Some message').to.be.true;

            //Token (requested amount) is transfered to the user
        });

        it('Withdraw token (not enough liquidity)', async () => {
            let res = true;
            expect(res, 'Some message').to.be.true;

            //Withdraw request is created
        });

        it('Withdraw token (has on-hold token, enough liquidity)', async () => {
            let res = true;
            expect(res, 'Some message').to.be.true;

            //Deposit record is removed from the on-hold storage
            //Token is transfered to the user
        });

        it('Withdraw token (has on-hold token, not enough liquidity)', async () => {
            let res = true;
            expect(res, 'Some message').to.be.true;

            //Withdraw request is created
            //This situation will be resolved by operator
        });

        it('Quick withdraw (enough liquidity)', async () => {
            let res = true;
            expect(res, 'Some message').to.be.true;

            //Token (requested amount) is transfered to the user
        });

        it('Quick withdraw (has on-hold token, enough liquidity)', async () => {
            let res = true;
            expect(res, 'Some message').to.be.true;

            //Deposit record is removed from the on-hold storage
            //Token is transfered to the user
        });

        it('Quick withdraw (has on-hold token, not enough liquidity)', async () => {
            let res = true;
            expect(res, 'Some message').to.be.true;

            //Deposit record is removed from the on-hold storage
            // (requested amount - on-hold tokens) is returned from the protocol
            //Token is transfered to the user
        });

        it('Quick withdraw (not enough liquidity)', async () => {
            let res = true;
            expect(res, 'Some message').to.be.true;

            // requested amount is returned from the protocol
            //Token is transfered to the user
        });
    });


    describe('Operator resolves withdraw requests', () => {
        // The plan is, that operator is checking the current liquidity, withdraw requests and on-hold deposits
        // before the transactioning, by view methods and matching on the server.
        it('Withdraw request (enough liquidity, no on-hold deposits, no liquidity for claim)', async () => {
            let res = true;
            expect(res, 'Some message').to.be.true;

            // this can occur only in case if Akropolis has transferred some liquidity to the protocol by purpose

            // Tokens are marked as ready for claim by the user
            //Withdraw request is resolved (deleted)
        });

        it('Withdraw request (enough liquidity, no on-hold deposits, there is liquidity for claim)', async () => {
            let res = true;
            expect(res, 'Some message').to.be.true;

            //appears when there is some liquidity withdrawn by operator from the protocol but not claimed yet

            // requested amount is returned from the protocol to the Vault
            // Tokens are marked as ready for claim by the user
            //Withdraw request is resolved (deleted)
            // Existing tokens for claim are untouched
        });

        it('Withdraw request (enough liquidity, there are on-hold deposits)', async () => {
            let res = true;
            expect(res, 'Some message').to.be.true;

            // records for on-hold deposits for matching amount are removed from the storage (or adjusted)
            // Tokens are marked as ready for claim by the user
            //Withdraw request is resolved (deleted)
        });

        it('Withdraw request (enough liquidity, the user has on-hold deposit)', async () => {
            let res = true;
            expect(res, 'Some message').to.be.true;

            // record for on-hold deposit is removed from the storage (or adjusted if requested amount is less than deposited)
            // Tokens are marked as ready for claim by the user
            //Withdraw request is resolved (deleted)
        });

        it('Withdraw request (enough liquidity, the user has on-hold deposit)', async () => {
            let res = true;
            expect(res, 'Some message').to.be.true;

            // record for on-hold deposit is removed from the storage (or adjusted if requested amount is less than deposited)
            // Tokens are marked as ready for claim by the user
            //Withdraw request is resolved (deleted)
        });







    
        it('The user claims the on-hold token', async () => {
            let res = true;
            expect(res, 'Some message').to.be.true;
    
            //the finish of the previous test
    
            //Tokens are transferred from the VaultProtocol to the user
            //claim record is deleted
        });
    });

    describe('Operator resolves on-hold deposits', () => {

    });

    describe('Only defi operator can call the methods', () => {

    });
    
});