pragma circom 2.1.6;

// Start with a simple multiplier circuit to test
template Multiplier() {
    signal input a;
    signal input b;
    signal output c;
    
    c <== a * b;
}

component main = Multiplier();