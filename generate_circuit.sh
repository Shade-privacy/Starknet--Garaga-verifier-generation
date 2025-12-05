#!/bin/bash

echo "======================================="
echo "ZK Age Verification Circuit with Garaga"
echo "======================================="

# 0. Ensure Garaga is installed
if ! command -v garaga &> /dev/null; then
    echo "Installing Garaga CLI..."
    pip install garaga
fi

# Create build directory
mkdir -p build

# 1. Compile the circuit
if [ ! -f "age.circom" ]; then
cat > age.circom << 'EOF'
pragma circom 2.1.6;

template AgeVerification() {
    signal input birthYear;      // Private
    signal input currentYear;    // Public
    signal output isAdult;
    signal age;
    age <== currentYear - birthYear;
    signal diff;
    diff <== age - 18;
    component rangeCheck = Num2Bits(32);
    rangeCheck.in <== diff;
    isAdult <== 1;
}

template Num2Bits(n) {
    signal input in;
    signal output out[n];
    var lc = 0;
    for (var i = 0; i < n; i++) {
        out[i] <-- (in >> i) & 1;
        out[i] * (out[i] - 1) === 0;
        lc += out[i] * (1 << i);
    }
    lc === in;
}

component main { public [ currentYear ] } = AgeVerification();
EOF
    echo "✅ Created age.circom"
fi

circom age.circom --r1cs --wasm --sym -o build

# 2. Generate input file
cat > input.json <<EOF
{
  "currentYear": 2024,
  "birthYear": 1990
}
EOF

# 3. Generate witness
cd build/age_js
node generate_witness.js age.wasm ../../input.json ../witness.wtns
cd ../..

# 4. Powers of Tau
if [ ! -f "pot10_final.ptau" ]; then
    snarkjs powersoftau new bn128 10 pot10_0000.ptau -v
    snarkjs powersoftau contribute pot10_0000.ptau pot10_0001.ptau --name="Test" -v -e="random"
    snarkjs powersoftau prepare phase2 pot10_0001.ptau pot10_final.ptau -v
fi

# 5. Groth16 setup
snarkjs groth16 setup build/age.r1cs pot10_final.ptau build/circuit_0000.zkey
snarkjs zkey contribute build/circuit_0000.zkey build/circuit_0001.zkey --name="First contribution" -v -e="random text"
snarkjs zkey beacon build/circuit_0001.zkey build/circuit_final.zkey \
    0102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f 10 -n="Final Beacon"

# 6. Generate proof with snarkjs
snarkjs groth16 prove build/circuit_final.zkey build/witness.wtns build/proof.json build/public.json

# 7. Generate Garaga Cairo verifier


garaga gen --zkey build/circuit_final.zkey --output garaga_verifier
garaga gen --system groth16 --vk build/verification_key.json --project-name groth16_age_verification
# 8. Convert snarkjs proof → Starknet-compatible proof
garaga calldata \
    --proof build/proof.json \
    --public build/public.json \
    --config garaga_verifier/verifier_config.json \
    --output garaga_proof.json

echo "======================================="
echo "✅ Garaga verifier Cairo contract: garaga_verifier/verifier.cairo"
echo "✅ Starknet-compatible proof: garaga_proof.json"
echo "Next steps:"
echo "1. Deploy garaga_verifier/verifier.cairo to Starknet"
echo "2. Call verifyProof with garaga_proof.json as calldata"
echo "======================================="
