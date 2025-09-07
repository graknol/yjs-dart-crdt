import '../lib/yjs_dart_crdt.dart';

void main() {
  print('=== CRDT Counters Example ===\n');

  // Create a document and shared map
  final doc = Doc(clientID: 1);
  final map = YMap();
  doc.share('counters', map);

  print('Document client ID: ${doc.clientID}\n');

  // Example 1: Using GCounter for tracking progress
  print('--- GCounter Example (Progress Tracking) ---');
  final progressCounter = GCounter();
  
  // Simulate progress updates from this client
  progressCounter.increment(doc.clientID, 25); // 25% progress
  map.set('project_progress', progressCounter);
  
  print('Initial progress: ${progressCounter.value}%');
  
  // Simulate receiving updates from another client
  final otherClientProgress = GCounter();
  otherClientProgress.increment(999, 15); // Another client added 15%
  
  progressCounter.merge(otherClientProgress);
  print('After merging with other client: ${progressCounter.value}%');
  
  // Update our own progress
  progressCounter.increment(doc.clientID, 10);
  print('After adding 10% more: ${progressCounter.value}%\n');

  // Example 2: Using PNCounter for material usage tracking  
  print('--- PNCounter Example (Material Usage) ---');
  final materialCounter = PNCounter();
  
  // Add materials
  materialCounter.increment(doc.clientID, 100); // Added 100 units
  map.set('material_usage', materialCounter);
  print('Added 100 units: ${materialCounter.value} units');
  
  // Use some materials
  materialCounter.decrement(doc.clientID, 25); // Used 25 units
  print('Used 25 units: ${materialCounter.value} units');
  
  // Simulate updates from another client
  final otherMaterialUpdates = PNCounter();
  otherMaterialUpdates.increment(888, 50); // Added 50 units
  otherMaterialUpdates.decrement(888, 20); // Used 20 units
  
  materialCounter.merge(otherMaterialUpdates);
  print('After merging other client updates: ${materialCounter.value} units');
  
  // Demonstrate the add method (can handle positive or negative)
  materialCounter.add(doc.clientID, -15); // Use 15 more units
  materialCounter.add(doc.clientID, 30);  // Add 30 units
  print('After using 15 and adding 30: ${materialCounter.value} units\n');

  // Example 3: Collaborative hours tracking
  print('--- Collaborative Hours Tracking ---');
  final hoursCounter = PNCounter();
  map.set('project_hours', hoursCounter);
  
  // This client logs hours
  hoursCounter.increment(doc.clientID, 8); // 8 hours worked
  print('Logged 8 hours: ${hoursCounter.value} total hours');
  
  // Simulate multiple team members
  final member1Hours = PNCounter();
  member1Hours.increment(101, 6); // Member 1: 6 hours
  
  final member2Hours = PNCounter();  
  member2Hours.increment(102, 4); // Member 2: 4 hours
  member2Hours.decrement(102, 1); // Member 2: correction, -1 hour
  
  // Merge all updates
  hoursCounter.merge(member1Hours);
  hoursCounter.merge(member2Hours);
  print('Total team hours after merging: ${hoursCounter.value} hours');
  
  // Show serialization
  print('\\nSerialized data:');
  print('Progress Counter JSON: ${progressCounter.toJSON()}');
  print('Material Counter JSON: ${materialCounter.toJSON()}');
  
  // Show map contents
  print('\\nMap contents:');
  for (final entry in map.entries) {
    final value = entry.value;
    if (value is GCounter || value is PNCounter) {
      print('${entry.key}: ${value.toString()}');
    }
  }
}