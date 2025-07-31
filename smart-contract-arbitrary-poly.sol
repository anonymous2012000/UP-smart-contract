// SPDX-License-Identifier: MIT
// when the modulous q is 64 bits
pragma solidity ^0.8.20;

contract FlexibleTagVerifier {
    uint64 public constant PRIME = 18446744073709551557;// 2^{64}
    //uint64 public constant PRIME = 1099511627689; // 2^40 - 87 ---- uncomment it if you need smaller size PRIME

    // Packed arithmetic operations (unchanged)
    function modAdd(uint64 a, uint64 b) internal pure returns (uint64) {
        unchecked {
            uint64 res = a + b;
            return res >= PRIME ? res - PRIME : res;
        }
    }

    function modSub(uint64 a, uint64 b) internal pure returns (uint64) {
        unchecked {
            return a >= b ? a - b : PRIME - (b - a);
        }
    }

    function modMul(uint64 a, uint64 b) internal pure returns (uint64) {
        unchecked {
            return uint64((uint256(a) * uint256(b)) % PRIME);
        }
    }

    // Now works with dynamic arrays
    function polySub(uint64[] memory a, uint64[] memory b) internal pure returns (uint64[] memory) {
        require(a.length == b.length, "Polynomials must have same length");
        uint64[] memory res = new uint64[](a.length);
        for (uint i = 0; i < a.length; i++) {
            res[i] = modSub(a[i], b[i]);
        }
        return res;
    }

    // Updated divisibility check for dynamic sizes
    function isDivisible(uint64[] memory dividend, uint64[] memory divisor) internal pure returns (bool) {
        require(divisor.length > 0, "Divisor polynomial cannot be empty");
        require(divisor[divisor.length - 1] != 0, "Leading coefficient cannot be zero");

        uint m = dividend.length;
        uint n = divisor.length;
        uint64[] memory rem = new uint64[](m);
        for (uint i = 0; i < m; i++) rem[i] = dividend[i];

        for (uint i = m; i-- > 0;) {
            if (i + 1 < n) break;

            if (rem[i] == 0) continue;

            uint64 invLead = modInverse(divisor[n - 1]);
            uint64 factor = modMul(rem[i], invLead);

            for (uint j = 0; j < n; j++) {
                uint idx = i - n + 1 + j;
                rem[idx] = modSub(rem[idx], modMul(factor, divisor[j]));
            }
        }

        for (uint i = 0; i < n - 1; i++) {
            if (rem[i] != 0) return false;
        }
        return true;
    }

    // Modular inverse (unchanged)
    function modInverse(uint64 a) internal pure returns (uint64) {
        require(a != 0, "modInverse: zero input");
        return modExp(a, PRIME - 2);
    }

    // Modular exponentiation (unchanged)
    function modExp(uint64 base, uint64 exp) internal pure returns (uint64 result) {
        result = 1;
        uint256 b = base;
        while (exp > 0) {
            if (exp & 1 == 1) {
                result = uint64((uint256(result) * b) % PRIME);
            }
            b = (b * b) % PRIME;
            exp >>= 1;
        }
    }


    // Helper function to verify with fixed degree but variable number of polynomials
    function verifyDegree3(
        uint64[4][] calldata tags,  // Array of degree-3 polynomials
        uint64[4] calldata gammaSum,
        uint64[2] calldata zeta
    ) external pure returns (bool) {
        require(zeta[1] != 0, "Zeta must be degree 1");

        uint64[4] memory tagSum;
        for (uint i = 0; i < tags.length; i++) {
            for (uint j = 0; j < 4; j++) {
                tagSum[j] = modAdd(tagSum[j], tags[i][j]);
            }
        }

        uint64[4] memory delta;
        for (uint j = 0; j < 4; j++) {
            delta[j] = modSub(tagSum[j], gammaSum[j]);
        }

        uint64[4] memory rem;
        for (uint j = 0; j < 4; j++) rem[j] = delta[j];

        // Optimized divisibility check for degree 3
        for (uint i = 3; i >= 1; i--) {
            if (rem[i] == 0) continue;

            uint64 invLead = modInverse(zeta[1]);
            uint64 factor = modMul(rem[i], invLead);

            rem[i-1] = modSub(rem[i-1], modMul(factor, zeta[0]));
            rem[i] = 0;
        }

        return rem[0] == 0;
    }
}
