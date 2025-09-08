import 'ast_parser.dart';
import 'placeholders.dart';

/// Handles conversion rules from JavaScript AST to Dart-compatible AST
class ConversionRules {
  final PlaceholderGenerator _placeholders = PlaceholderGenerator();
  
  /// Convert JavaScript AST to Dart AST with language-specific transformations
  ProgramNode convertToDart(ProgramNode jsAst) {
    final dartNodes = <ASTNode>[];
    
    for (final node in jsAst.body) {
      final convertedNode = _convertNode(node);
      if (convertedNode != null) {
        dartNodes.add(convertedNode);
      }
    }
    
    return ProgramNode(dartNodes);
  }
  
  ASTNode? _convertNode(ASTNode node) {
    if (node is ImportDeclaration) {
      return _convertImport(node);
    } else if (node is ExportDeclaration) {
      return _convertExport(node);
    } else if (node is ClassDeclaration) {
      return _convertClass(node);
    } else if (node is FunctionDeclaration) {
      return _convertFunction(node);
    } else if (node is VariableDeclaration) {
      return _convertVariable(node);
    }
    
    return node; // Return as-is if no conversion needed
  }
  
  ImportDeclaration _convertImport(ImportDeclaration jsImport) {
    // Check if this is a Node.js built-in or npm package
    if (_isExternalDependency(jsImport.source)) {
      // Add to placeholders for later manual implementation
      _placeholders.addExternalDependency(jsImport.source, jsImport.imports);
      
      // Return placeholder import
      return ImportDeclaration(
        jsImport.imports.map((imp) => '${imp}_PLACEHOLDER').toList(),
        'placeholders.dart'
      );
    }
    
    // Convert relative imports to Dart paths
    return ImportDeclaration(
      jsImport.imports,
      _convertImportPath(jsImport.source),
      isDefault: jsImport.isDefault
    );
  }
  
  ExportDeclaration _convertExport(ExportDeclaration jsExport) {
    // Dart doesn't have export keyword, just convert the declaration
    final convertedDeclaration = _convertNode(jsExport.declaration);
    if (convertedDeclaration != null) {
      return ExportDeclaration(convertedDeclaration, isDefault: jsExport.isDefault);
    }
    return jsExport;
  }
  
  ClassDeclaration _convertClass(ClassDeclaration jsClass) {
    final dartMethods = <MethodDefinition>[];
    final dartProperties = <PropertyDefinition>[];
    
    // Convert methods
    for (final method in jsClass.methods) {
      final convertedMethod = _convertMethod(method);
      dartMethods.add(convertedMethod);
    }
    
    // Convert properties
    for (final property in jsClass.properties) {
      final convertedProperty = _convertProperty(property);
      dartProperties.add(convertedProperty);
    }
    
    return ClassDeclaration(
      jsClass.name,
      dartMethods,
      dartProperties,
      superClass: jsClass.superClass
    );
  }
  
  MethodDefinition _convertMethod(MethodDefinition jsMethod) {
    final dartParameters = jsMethod.parameters.map(_convertParameter).toList();
    final dartBody = _convertMethodBody(jsMethod.body);
    
    return MethodDefinition(
      jsMethod.isConstructor ? jsMethod.name.split('.').last : jsMethod.name,
      dartParameters,
      dartBody,
      isConstructor: jsMethod.isConstructor,
      isStatic: jsMethod.isStatic
    );
  }
  
  Parameter _convertParameter(Parameter jsParam) {
    return Parameter(
      jsParam.name,
      type: jsParam.type ?? _inferDartTypeFromName(jsParam.name),
      defaultValue: jsParam.defaultValue
    );
  }
  
  PropertyDefinition _convertProperty(PropertyDefinition jsProperty) {
    String? convertedValue;
    if (jsProperty.initialValue != null) {
      convertedValue = _convertJavaScriptValue(jsProperty.initialValue!);
    }
    
    return PropertyDefinition(
      jsProperty.name,
      initialValue: convertedValue,
      isStatic: jsProperty.isStatic
    );
  }
  
  FunctionDeclaration _convertFunction(FunctionDeclaration jsFunction) {
    final dartParameters = jsFunction.parameters.map(_convertParameter).toList();
    final dartBody = _convertMethodBody(jsFunction.body);
    
    return FunctionDeclaration(
      jsFunction.name,
      dartParameters,
      dartBody,
      isAsync: jsFunction.isAsync
    );
  }
  
  VariableDeclaration _convertVariable(VariableDeclaration jsVariable) {
    String? convertedValue;
    if (jsVariable.initialValue != null) {
      convertedValue = _convertJavaScriptValue(jsVariable.initialValue!);
    }
    
    return VariableDeclaration(
      jsVariable.name,
      type: jsVariable.type ?? _inferDartTypeFromValue(convertedValue),
      initialValue: convertedValue,
      isConst: jsVariable.isConst
    );
  }
  
  String _convertMethodBody(String jsBody) {
    String dartBody = jsBody;
    
    // Apply JavaScript to Dart conversions
    dartBody = _applyBasicConversions(dartBody);
    dartBody = _convertCollectionOperations(dartBody);
    dartBody = _convertAsyncOperations(dartBody);
    dartBody = _convertBuiltInFunctions(dartBody);
    
    return dartBody;
  }
  
  String _applyBasicConversions(String jsCode) {
    String dartCode = jsCode;
    
    // Convert equality operators
    dartCode = dartCode.replaceAll('===', '==');
    dartCode = dartCode.replaceAll('!==', '!=');
    
    // Convert undefined checks
    dartCode = dartCode.replaceAllMapped(
      RegExp(r'(\w+)\s*===\s*undefined'),
      (match) => '${match.group(1)} == null'
    );
    dartCode = dartCode.replaceAllMapped(
      RegExp(r'(\w+)\s*!==\s*undefined'),
      (match) => '${match.group(1)} != null'
    );
    
    // Convert typeof checks
    dartCode = dartCode.replaceAllMapped(
      RegExp('typeof\\s+(\\w+)\\s*===\\s*[\'"](\w+)[\'"]'),
      (match) => '${match.group(1)} is ${_jsTypeToTypeKeyword(match.group(2)!)}'
    );
    
    return dartCode;
  }
  
  String _convertCollectionOperations(String jsCode) {
    String dartCode = jsCode;
    
    // Convert Map operations
    dartCode = dartCode.replaceAll('new Map()', '<String, dynamic>{}');
    dartCode = dartCode.replaceAllMapped(
      RegExp(r'\.set\(([^,]+),\s*([^)]+)\)'),
      (match) => '[${match.group(1)}] = ${match.group(2)}'
    );
    dartCode = dartCode.replaceAllMapped(
      RegExp(r'\.get\(([^)]+)\)'),
      (match) => '[${match.group(1)}]'
    );
    dartCode = dartCode.replaceAllMapped(
      RegExp(r'\.has\(([^)]+)\)'),
      (match) => '.containsKey(${match.group(1)})'
    );
    dartCode = dartCode.replaceAllMapped(
      RegExp(r'\.delete\(([^)]+)\)'),
      (match) => '.remove(${match.group(1)})'
    );
    
    // Convert Set operations
    dartCode = dartCode.replaceAll('new Set()', '<dynamic>{}');
    dartCode = dartCode.replaceAllMapped(
      RegExp(r'\.add\(([^)]+)\)'),
      (match) => '.add(${match.group(1)})'
    );
    
    // Convert Array operations
    dartCode = dartCode.replaceAllMapped(
      RegExp(r'\.push\(([^)]+)\)'),
      (match) => '.add(${match.group(1)})'
    );
    dartCode = dartCode.replaceAllMapped(
      RegExp(r'\.pop\(\)'),
      (match) => '.removeLast()'
    );
    dartCode = dartCode.replaceAllMapped(
      RegExp(r'\.shift\(\)'),
      (match) => '.removeAt(0)'
    );
    dartCode = dartCode.replaceAllMapped(
      RegExp(r'\.unshift\(([^)]+)\)'),
      (match) => '.insert(0, ${match.group(1)})'
    );
    
    return dartCode;
  }
  
  String _convertAsyncOperations(String jsCode) {
    String dartCode = jsCode;
    
    // Convert Promise to Future
    dartCode = dartCode.replaceAll('Promise', 'Future');
    dartCode = dartCode.replaceAllMapped(
      RegExp(r'\.then\(([^)]+)\)'),
      (match) => '.then((value) => ${match.group(1)})'
    );
    dartCode = dartCode.replaceAllMapped(
      RegExp(r'\.catch\(([^)]+)\)'),
      (match) => '.catchError(${match.group(1)})'
    );
    
    // Convert setTimeout/setInterval to Timer
    if (dartCode.contains('setTimeout') || dartCode.contains('setInterval')) {
      dartCode = '// PLACEHOLDER: Add import \'dart:async\'; for Timer\n$dartCode';
      dartCode = dartCode.replaceAllMapped(
        RegExp(r'setTimeout\(([^,]+),\s*(\d+)\)'),
        (match) => 'Timer(Duration(milliseconds: ${match.group(2)}), ${match.group(1)})'
      );
    }
    
    return dartCode;
  }
  
  String _convertBuiltInFunctions(String jsCode) {
    String dartCode = jsCode;
    
    // Convert console methods
    dartCode = dartCode.replaceAll('console.log', 'print');
    dartCode = dartCode.replaceAll('console.error', 'print'); // Dart doesn't have stderr print by default
    dartCode = dartCode.replaceAll('console.warn', 'print');
    
    // Convert JSON methods
    if (dartCode.contains('JSON.')) {
      dartCode = '// PLACEHOLDER: Add import \'dart:convert\';\n$dartCode';
      dartCode = dartCode.replaceAll('JSON.stringify', 'jsonEncode');
      dartCode = dartCode.replaceAll('JSON.parse', 'jsonDecode');
    }
    
    // Convert Math methods
    if (dartCode.contains('Math.')) {
      dartCode = '// PLACEHOLDER: Add import \'dart:math\' as math;\n$dartCode';
      dartCode = dartCode.replaceAllMapped(
        RegExp(r'Math\.(\w+)'),
        (match) => 'math.${match.group(1)}'
      );
    }
    
    return dartCode;
  }
  
  String _convertJavaScriptValue(String jsValue) {
    // Convert JavaScript values to Dart equivalents
    if (jsValue == 'new Map()') {
      return '<String, dynamic>{}';
    } else if (jsValue == 'new Set()') {
      return '<dynamic>{}';
    } else if (jsValue.startsWith('new Array(')) {
      return '<dynamic>[]';
    } else if (jsValue == '[]') {
      return '<dynamic>[]';
    } else if (jsValue == '{}') {
      return '<String, dynamic>{}';
    } else if (jsValue.startsWith('new ')) {
      // Constructor call - remove 'new' keyword
      return jsValue.substring(4);
    }
    return jsValue;
  }
  
  bool _isExternalDependency(String source) {
    // Check for Node.js built-ins and npm packages
    final nodeBuiltins = ['fs', 'path', 'crypto', 'util', 'events', 'stream', 'buffer'];
    final npmIndicators = ['@', '/', 'node:'];
    
    return nodeBuiltins.any((builtin) => source == builtin || source == 'node:$builtin') ||
           npmIndicators.any((indicator) => source.contains(indicator)) ||
           (!source.startsWith('./') && !source.startsWith('../') && !source.endsWith('.js'));
  }
  
  String _convertImportPath(String jsPath) {
    if (jsPath.startsWith('./') || jsPath.startsWith('../')) {
      return jsPath.replaceAll('.js', '.dart');
    }
    return jsPath;
  }
  
  String _inferDartTypeFromName(String paramName) {
    final name = paramName.toLowerCase();
    
    if (name.contains('index') || name.contains('count') || name.contains('length') || 
        name.contains('size') || name.contains('pos') || name.contains('offset')) {
      return 'int';
    } else if (name.contains('text') || name.contains('string') || name.contains('name') || 
               name.contains('id') || name.contains('key') || name.contains('message')) {
      return 'String';
    } else if (name.contains('flag') || name.contains('enabled') || name.contains('visible') || 
               name.contains('active') || name.contains('valid')) {
      return 'bool';
    } else if (name.contains('list') || name.contains('array') || name.contains('items')) {
      return 'List<dynamic>';
    } else if (name.contains('map') || name.contains('dict') || name.contains('object')) {
      return 'Map<String, dynamic>';
    }
    
    return 'dynamic';
  }
  
  String? _inferDartTypeFromValue(String? value) {
    if (value == null) return 'dynamic';
    
    if (value.startsWith('"') || value.startsWith("'")) {
      return 'String';
    } else if (value == 'true' || value == 'false') {
      return 'bool';
    } else if (RegExp(r'^\d+$').hasMatch(value)) {
      return 'int';
    } else if (RegExp(r'^\d+\.\d+$').hasMatch(value)) {
      return 'double';
    } else if (value.startsWith('<') && value.contains('>') && value.endsWith('[]')) {
      return 'List<dynamic>';
    } else if (value.startsWith('<') && value.contains('>') && value.endsWith('{}')) {
      return 'Map<String, dynamic>';
    }
    
    return 'dynamic';
  }
  
  String _jsTypeToTypeKeyword(String jsType) {
    switch (jsType) {
      case 'string':
        return 'String';
      case 'number':
        return 'num';
      case 'boolean':
        return 'bool';
      case 'object':
        return 'Object';
      case 'function':
        return 'Function';
      default:
        return 'dynamic';
    }
  }
}