pragma circom 2.0.0;

// Ultra-simple circuit for testing
template AgeSimple() {
    // Public input
    signal input currentYear;
    
    // Private input
    signal input birthYear;
    
    // Output
    signal output isAdult;
    
    // Simple constraint: birthYear <= currentYear - 18
    // This proves: birthYear + 18 <= currentYear
    signal minBirthYear;
    minBirthYear <== currentYear - 18;
    
    // We need to prove: birthYear <= minBirthYear
    // But we can't directly compare, so we use a trick
    // Create a difference that must be non-negative
    signal diff;
    diff <== minBirthYear - birthYear;
    
    // Constraint to ensure diff is non-negative
    // This is simplified - real circuit needs range checks
    component rangeCheck = Num2Bits(32);
    rangeCheck.in <== diff;
    
    isAdult <== 1;  // Always true for this simple demo
}

template Num2Bits(n) {
    signal input in;
    signal output out[n];
    
    var lc = 0;
    
    for (var i = 0; i < n; i++) {
        out[i] <-- (in >> i) & 1;
        // Ensure each bit is 0 or 1
        out[i] * (out[i] - 1) === 0;
        lc += out[i] * (1 << i);
    }
    
    // Ensure the sum equals the input
    lc === in;
}

component main { public [ currentYear ] } = AgeSimple();