%lang starknet

@contract_interface
namespace IAccount{
    //
    // Getters
    //

    func get_nonce() -> (res : felt){
    }

    //
    // Business logic
    //

    func is_valid_signature(
            hash: felt,
            signature_len: felt,
            signature: felt*
        ){
    }

    func execute(
            to: felt,
            selector: felt,
            calldata_len: felt,
            calldata: felt*,
            nonce: felt
        ) -> (response_len: felt, response: felt*){
    }
}
