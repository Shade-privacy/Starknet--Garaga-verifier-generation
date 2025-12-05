#!/bin/bash

echo "1. Compiling Circom circuit..."
circom age_verification.circom --r1cs --wasm --sym -o ./build

echo "2. Generating witness..."
node ./build/age_verification_js/generate_witness.js \
    ./build/age_verification_js/age_verification.wasm \
    input.json \
    ./build/witness.wtns

echo "3. Setting up Groth16..."
# Download Powers of Tau if needed
if [ ! -f "./powersOfTau28.ptau" ]; then
    echo "Downloading Powers of Tau..."
    wget https://hermez.s3-eu-west-1.amazonaws.com/powersOfTau28_hez_final_16.ptau \
        -O powersOfTau28.ptau
fi

# Phase 2: Circuit-specific setup
snarkjs groth16 setup ./build/age_verification.r1cs powersOfTau28.ptau ./build/circuit.zkey

echo "4. Generating verification key..."
snarkjs zkey export verificationkey ./build/circuit.zkey ./build/verification_key.json

echo "5. Generating proof..."
snarkjs groth16 prove ./build/circuit.zkey ./build/witness.wtns \
    ./build/proof.json ./build/public.json

echo "6. Verifying proof..."
snarkjs groth16 verify ./build/verification_key.json \
    ./build/public.json ./build/proof.json

echo "7. Generating Solidity verifier..."
snarkjs zkey export solidityverifier ./build/circuit.zkey ./build/Verifier.sol

echo "8. Generating call data (for testing)..."
snarkjs generatecall > ./build/call_data.txt

echo "Done! Files generated in ./build directory:"
ls -la ./build/