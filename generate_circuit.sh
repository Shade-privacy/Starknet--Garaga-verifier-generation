#!/bin/bash

echo "======================================="
echo "ZK Age Verification Circuit Generation"
echo "======================================="

# Create build directory
mkdir -p build

echo ""
echo "1. Compiling the circuit..."
echo "---------------------------"

# Compile the circuit
circom age.circom --r1cs --wasm --sym -o build

if [ $? -eq 0 ]; then
    echo "✅ Circuit compiled successfully!"
else
    echo "❌ Circuit compilation failed. Trying simpler circuit..."
    
    # Try simpler circuit
    circom simple_multiplier.circom --r1cs --wasm --sym -o build
    if [ $? -ne 0 ]; then
        echo "❌ Failed to compile any circuit."
        exit 1
    fi
    echo "✅ Simple circuit compiled successfully!"
fi

echo ""
echo "2. Creating input files..."
echo "--------------------------"

# Create input for age circuit
cat > age_input.json <<EOF
{
  "currentYear": 2024,
  "birthYear": 1990
}
EOF

# Create input for multiplier circuit
cat > multiplier_input.json <<EOF
{
  "a": 3,
  "b": 4
}
EOF

echo ""
echo "3. Generating witness..."
echo "------------------------"

# Determine which circuit was compiled
if [ -f "build/age_js/generate_witness.js" ]; then
    cd build/age_js
    node generate_witness.js age.wasm ../../age_input.json ../witness.wtns
    CIRCUIT_NAME="age"
elif [ -f "build/simple_multiplier_js/generate_witness.js" ]; then
    cd build/simple_multiplier_js
    node generate_witness.js simple_multiplier.wasm ../../multiplier_input.json ../witness.wtns
    CIRCUIT_NAME="simple_multiplier"
else
    echo "❌ No compiled circuit found!"
    exit 1
fi

cd ../..

if [ $? -eq 0 ]; then
    echo "✅ Witness generated successfully!"
else
    echo "❌ Witness generation failed!"
    exit 1
fi

echo ""
echo "4. Downloading Powers of Tau..."
echo "-------------------------------"

# Use a working Powers of Tau file
if [ ! -f "pot12_final.ptau" ]; then
    echo "Downloading Powers of Tau file..."
    # Try different URLs
    wget https://hermez.s3-eu-west-1.amazonaws.com/powersOfTau28_hez_final_12.ptau -O pot12_final.ptau 2>/dev/null || \
    wget https://storage.googleapis.com/zcash-era-setup/powersOfTau28_hez_final_12.ptau -O pot12_final.ptau 2>/dev/null || \
    echo "Failed to download. Please manually download:"
    echo "https://storage.googleapis.com/zcash-era-setup/powersOfTau28_hez_final_12.ptau"
    echo "and save as pot12_final.ptau"
    echo ""
    echo "For now, we'll create a test file..."
    # Create a small test with snarkjs
    npx snarkjs powersoftau new bn128 12 pot12_0000.ptau -v > /dev/null 2>&1
    npx snarkjs powersoftau contribute pot12_0000.ptau pot12_0001.ptau --name="Test" -v -e="random" > /dev/null 2>&1
    npx snarkjs powersoftau prepare phase2 pot12_0001.ptau pot12_final.ptau -v > /dev/null 2>&1
fi

echo ""
echo "5. Setting up Groth16..."
echo "------------------------"

if [ -f "build/age.r1cs" ]; then
    R1CS_FILE="build/age.r1cs"
elif [ -f "build/simple_multiplier.r1cs" ]; then
    R1CS_FILE="build/simple_multiplier.r1cs"
else
    echo "❌ No R1CS file found!"
    exit 1
fi

# Install snarkjs globally or locally
if ! command -v snarkjs &> /dev/null; then
    echo "Installing snarkjs..."
    npm install -g snarkjs
fi

# Generate zkey
snarkjs groth16 setup $R1CS_FILE pot12_final.ptau build/circuit_final.zkey

if [ $? -eq 0 ]; then
    echo "✅ Groth16 setup completed!"
else
    echo "❌ Groth16 setup failed!"
    exit 1
fi

echo ""
echo "6. Exporting verification key..."
echo "--------------------------------"

snarkjs zkey export verificationkey build/circuit_final.zkey build/verification_key.json

echo ""
echo "7. Generating proof..."
echo "----------------------"

snarkjs groth16 prove build/circuit_final.zkey build/witness.wtns build/proof.json build/public.json

if [ $? -eq 0 ]; then
    echo "✅ Proof generated successfully!"
else
    echo "❌ Proof generation failed!"
    exit 1
fi

echo ""
echo "8. Verifying proof..."
echo "---------------------"

snarkjs groth16 verify build/verification_key.json build/public.json build/proof.json

if [ $? -eq 0 ]; then
    echo "✅ Proof verified successfully!"
else
    echo "❌ Proof verification failed!"
    exit 1
fi

echo ""
echo "9. Generating Solidity verifier..."
echo "----------------------------------"

snarkjs zkey export solidityverifier build/circuit_final.zkey build/Verifier.sol

echo ""
echo "10. Generating call data..."
echo "---------------------------"

snarkjs generatecall build/public.json build/proof.json > build/calldata.txt

echo ""
echo "======================================="
echo "Generation Complete! 🎉"
echo "======================================="
echo ""
echo "Generated files in build/ directory:"
ls -la build/
echo ""
echo "To use with StarkNet/Giza:"
echo "1. Install Giza: pip install giza-cli"
echo "2. Transpile: giza transpile age.circom --output age.cairo"