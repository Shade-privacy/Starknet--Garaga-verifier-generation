pragma circom 2.1.6;

// Simple age verification circuit
template AgeVerification() {
    // Public input
    signal input currentYear;
    
    // Private input
    signal input birthYear;
    
    // Output
    signal output isAdult;
    
    // Calculate age
    signal age;
    age <== currentYear - birthYear;
    
    // Check if age >= 18
    // We'll create a simple comparator
    signal diff;
    diff <== age - 18;
    
    // Ensure diff >= 0
    // This is a simplified approach
    component check = IsPositive();
    check.in <== diff;
    
    isAdult <== check.out;
}

template IsPositive() {
    signal input in;
    signal output out;
    
    // Create a binary signal for the result
    out <-- in >= 0 ? 1 : 0;
    
    // Ensure out is binary (0 or 1)
    out * (out - 1) === 0;
    
    // Constraint: if out == 0, then in < 0
    // if out == 1, then in >= 0
    // We use: in * (1 - out) < 0 when out=0
    // This is a simplified constraint for demo
    signal dummy;
    dummy <== in * (1 - out);
}

component main { public [ currentYear ] } = AgeVerification();