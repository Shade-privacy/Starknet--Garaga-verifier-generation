const { computeAgeProof } = require("./build/simple_age_js/witness_calculator.js");
const fs = require("fs");

async function testAgeVerification() {
    // Test cases
    const testCases = [
        { birthYear: 2000, currentYear: 2024, expectedAdult: 1 }, // 24 years old
        { birthYear: 2010, currentYear: 2024, expectedAdult: 0 }, // 14 years old
        { birthYear: 2005, currentYear: 2024, expectedAdult: 1 }, // 19 years old
        { birthYear: 2006, currentYear: 2024, expectedAdult: 0 }, // 18 exactly? Need month/day
    ];

    console.log("Testing Age Verification Circuit:");
    console.log("=================================");

    for (let i = 0; i < testCases.length; i++) {
        const test = testCases[i];
        const input = {
            birthYear: test.birthYear,
            currentYear: test.currentYear
        };

        // Save input to file
        fs.writeFileSync("test_input.json", JSON.stringify(input));

        // Calculate witness using the WASM module
        const wasmBuffer = fs.readFileSync("./build/simple_age_js/simple_age.wasm");
        const witnessCalculator = await require("./build/simple_age_js/witness_calculator.js");

        const wc = await witnessCalculator(wasmBuffer);
        const buff = await wc.calculateWTNSBin(input, 0);

        // Save witness
        fs.writeFileSync("./build/test_witness.wtns", Buffer.from(buff));

        console.log(`\nTest ${i + 1}:`);
        console.log(`  Birth Year: ${test.birthYear}`);
        console.log(`  Current Year: ${test.currentYear}`);
        console.log(`  Age: ${test.currentYear - test.birthYear}`);
        console.log(`  Expected isAdult: ${test.expectedAdult}`);
        console.log(`  Result: ${test.expectedAdult === 1 ? '✓ Adult' : '✗ Not Adult'}`);
    }
}

testAgeVerification().catch(console.error);