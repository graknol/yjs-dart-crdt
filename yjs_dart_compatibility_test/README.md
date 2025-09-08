# Y.js and Dart CRDT Compatibility Test

This directory contains comprehensive tests to validate that the Y.js JavaScript implementation and the Dart CRDT implementation can communicate and collaborate on the same documents using the binary protocol.

## Test Overview

The compatibility test validates:

1. **All 3 Core CRDTs**:
   - **YMap**: Key-value collaborative maps with conflict resolution
   - **YArray**: Collaborative arrays with insertion-order preservation  
   - **YText**: Collaborative text with YATA algorithm for conflict resolution

2. **Binary Protocol Compatibility**:
   - Update encoding/decoding between Y.js and Dart
   - State vector synchronization
   - Cross-platform operation exchange

3. **Convergence Validation**:
   - Both implementations reach identical final states
   - Proper conflict resolution for concurrent operations
   - No text interleaving during concurrent text editing

## Running the Tests

### Prerequisites

1. **Install Node.js** (for Y.js testing):
   ```bash
   # On Ubuntu/Debian
   curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
   sudo apt-get install -y nodejs
   ```

2. **Install Dart SDK** (should already be available):
   ```bash
   dart --version
   ```

### Step 1: Install Y.js and Run JavaScript Tests

```bash
cd yjs_dart_compatibility_test
npm install
npm test
```

This will:
- Install Y.js from npm
- Run the JavaScript compatibility tests
- Generate `yjs_test_results.json` with Y.js operation results

### Step 2: Run Dart Compatibility Tests

```bash
cd ..
dart test yjs_dart_compatibility_test/dart_compatibility_test.dart
```

This will:
- Run equivalent operations in Dart CRDT implementation
- Generate `dart_test_results.json` with Dart operation results  
- Compare results with Y.js results (if available)
- Validate binary protocol compatibility

## Test Scenarios

### YMap Test
```javascript
// Y.js side
map1.set('name', 'Alice');
map1.set('age', 30);
map2.set('age', 31);  // Concurrent conflict
```

```dart
// Dart side (identical operations)
map1.set('name', 'Alice');
map1.set('age', 30);
map2.set('age', 31);  // Same concurrent conflict
```

**Expected Result**: Both implementations converge to identical final state using last-write-wins semantics.

### YArray Test
```javascript
// Y.js side
array1.push(['apple', 'banana', 'cherry']);
array1.insert(1, ['date']);    // Concurrent insertion
array2.delete(2, 1);           // Concurrent deletion
```

**Expected Result**: Proper insertion/deletion ordering preserved across both implementations.

### YText Test (Critical YATA Validation)
```javascript
// Y.js side
text1.insert(5, ' Beautiful'); // Concurrent edit at position 5
text2.insert(5, ' Amazing');   // Concurrent edit at same position
```

**Expected Result**: 
- No character interleaving 
- Consistent conflict resolution using YATA algorithm
- Both implementations reach identical final text state

## Expected Output

### Successful Test Run
```
Starting Y.js compatibility tests...
Testing YMap...
YMap final state (should be identical): {name: Alice, age: 31, occupation: Engineer, hobby: Reading}
Testing YArray...
YArray final state (should be identical): [apple, date, elderberry]
Testing YText...
YText final state (should be identical):
Doc1: " Amazing Beautiful World!"
Doc2: " Amazing Beautiful World!"
✅ YATA algorithm working - no text interleaving
✅ Y.js tests completed successfully!

Starting Dart compatibility tests...
Testing Dart YMap...
Dart YMap final state (should be identical): {name: Alice, age: 31, occupation: Engineer, hobby: Reading}
Testing Dart YArray...
Dart YArray final state (should be identical): [apple, date, elderberry]
Testing Dart YText...
Dart YText final state (should be identical):
Doc1: " Amazing Beautiful World!"
Doc2: " Amazing Beautiful World!"
✅ Dart YATA algorithm working - no text interleaving

🔄 Comparing Y.js and Dart results...
✅ YMap compatibility: PASSED
✅ YArray compatibility: PASSED  
✅ YText compatibility: PASSED
✅ YATA algorithm working correctly in both implementations
📦 Y.js binary update size: 87 bytes
✅ Binary protocol structure readable

🎉 ALL COMPATIBILITY TESTS PASSED!
   Y.js and Dart implementations can collaborate successfully
```

## Troubleshooting

### Y.js Installation Issues
```bash
# Clear npm cache
npm cache clean --force
# Reinstall
rm -rf node_modules package-lock.json
npm install
```

### Dart Test Issues
```bash
# Install Dart dependencies
cd ../dart
dart pub get
cd ../yjs_dart_compatibility_test
```

### Expected Issues (Currently)

Due to the missing 5% functionality (primarily YATA algorithm integration), you may see:

```
❌ YText compatibility: FAILED
   Y.js result: " Amazing Beautiful World!"
   Dart result: " Beautiful Amazing World!" 
```

This indicates that the YATA conflict resolution algorithm needs full implementation in the Dart port.

## Files Generated

- `yjs_test_results.json`: Y.js operation results and binary updates
- `dart_test_results.json`: Dart operation results and binary updates
- Test output showing compatibility status for all CRDTs

## Next Steps

If tests fail, focus on implementing the missing YATA algorithm integration identified in `MISSING_FUNCTIONALITY.md` to achieve full Y.js compatibility.