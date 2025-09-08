import 'dart:io';

/// Basic JavaScript AST node types
abstract class ASTNode {}

class ProgramNode extends ASTNode {
  final List<ASTNode> body;
  ProgramNode(this.body);
}

class ClassDeclaration extends ASTNode {
  final String name;
  final List<MethodDefinition> methods;
  final List<PropertyDefinition> properties;
  final String? superClass;
  
  ClassDeclaration(this.name, this.methods, this.properties, {this.superClass});
}

class MethodDefinition extends ASTNode {
  final String name;
  final List<Parameter> parameters;
  final String body;
  final bool isConstructor;
  final bool isStatic;
  
  MethodDefinition(this.name, this.parameters, this.body, 
      {this.isConstructor = false, this.isStatic = false});
}

class PropertyDefinition extends ASTNode {
  final String name;
  final String? initialValue;
  final bool isStatic;
  
  PropertyDefinition(this.name, {this.initialValue, this.isStatic = false});
}

class Parameter extends ASTNode {
  final String name;
  final String? type;
  final String? defaultValue;
  
  Parameter(this.name, {this.type, this.defaultValue});
}

class ImportDeclaration extends ASTNode {
  final List<String> imports;
  final String source;
  final bool isDefault;
  
  ImportDeclaration(this.imports, this.source, {this.isDefault = false});
}

class ExportDeclaration extends ASTNode {
  final ASTNode declaration;
  final bool isDefault;
  
  ExportDeclaration(this.declaration, {this.isDefault = false});
}

class FunctionDeclaration extends ASTNode {
  final String name;
  final List<Parameter> parameters;
  final String body;
  final bool isAsync;
  
  FunctionDeclaration(this.name, this.parameters, this.body, {this.isAsync = false});
}

class VariableDeclaration extends ASTNode {
  final String name;
  final String? type;
  final String? initialValue;
  final bool isConst;
  
  VariableDeclaration(this.name, {this.type, this.initialValue, this.isConst = false});
}

/// Simple JavaScript AST Parser
/// This is a basic parser for common JavaScript constructs
/// For production use, consider using a proper JavaScript parser library
class JavaScriptASTParser {
  
  /// Parse JavaScript code into an AST
  ProgramNode parseJavaScript(String code) {
    final lines = code.split('\n');
    final nodes = <ASTNode>[];
    
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty || line.startsWith('//')) continue;
      
      // Parse import statements
      if (line.startsWith('import')) {
        nodes.add(_parseImport(line));
        continue;
      }
      
      // Parse export statements
      if (line.startsWith('export')) {
        final exportNode = _parseExport(line, lines, i);
        if (exportNode != null) {
          nodes.add(exportNode);
          // Skip lines that were consumed by the export parsing
          while (i < lines.length - 1 && !_isStatementComplete(lines[i])) {
            i++;
          }
        }
        continue;
      }
      
      // Parse class declarations
      if (line.startsWith('class ')) {
        final classNode = _parseClass(lines, i);
        if (classNode != null) {
          nodes.add(classNode);
          // Skip to end of class
          i = _findClosingBrace(lines, i);
        }
        continue;
      }
      
      // Parse function declarations
      if (line.startsWith('function ') || line.contains('function(')) {
        final functionNode = _parseFunction(lines, i);
        if (functionNode != null) {
          nodes.add(functionNode);
          // Skip to end of function
          i = _findClosingBrace(lines, i);
        }
        continue;
      }
      
      // Parse variable declarations
      if (line.startsWith('const ') || line.startsWith('let ') || line.startsWith('var ')) {
        nodes.add(_parseVariable(line));
        continue;
      }
    }
    
    return ProgramNode(nodes);
  }
  
  ImportDeclaration _parseImport(String line) {
    // Handle different import formats:
    // import { foo, bar } from 'module';
    // import foo from 'module';
    // import * as foo from 'module';
    
    final fromMatch = RegExp('from [\'"]([^\'"]+)[\'"]').firstMatch(line);
    final source = fromMatch?.group(1) ?? '';
    
    if (line.contains('{')) {
      // Named imports
      final namedMatch = RegExp(r'\{([^}]+)\}').firstMatch(line);
      final imports = namedMatch?.group(1)
          ?.split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList() ?? [];
      return ImportDeclaration(imports, source);
    } else {
      // Default import
      final defaultMatch = RegExp(r'import\s+(\w+)').firstMatch(line);
      final defaultImport = defaultMatch?.group(1) ?? '';
      return ImportDeclaration([defaultImport], source, isDefault: true);
    }
  }
  
  ExportDeclaration? _parseExport(String line, List<String> lines, int startIndex) {
    if (line.contains('class ')) {
      final classNode = _parseClass(lines, startIndex, isExported: true);
      if (classNode != null) {
        return ExportDeclaration(classNode, isDefault: line.contains('default'));
      }
    } else if (line.contains('function ')) {
      final functionNode = _parseFunction(lines, startIndex, isExported: true);
      if (functionNode != null) {
        return ExportDeclaration(functionNode, isDefault: line.contains('default'));
      }
    }
    return null;
  }
  
  ClassDeclaration? _parseClass(List<String> lines, int startIndex, {bool isExported = false}) {
    final line = lines[startIndex].trim();
    final classMatch = RegExp(r'class\s+(\w+)(?:\s+extends\s+(\w+))?').firstMatch(line);
    if (classMatch == null) return null;
    
    final className = classMatch.group(1)!;
    final superClass = classMatch.group(2);
    final methods = <MethodDefinition>[];
    final properties = <PropertyDefinition>[];
    
    // Parse class body
    int currentIndex = startIndex + 1;
    while (currentIndex < lines.length) {
      final currentLine = lines[currentIndex].trim();
      
      if (currentLine == '}') break;
      if (currentLine.isEmpty || currentLine.startsWith('//')) {
        currentIndex++;
        continue;
      }
      
      // Parse constructor
      if (currentLine.startsWith('constructor')) {
        final constructor = _parseMethod(lines, currentIndex, isConstructor: true);
        if (constructor != null) {
          methods.add(constructor);
          currentIndex = _findClosingBrace(lines, currentIndex);
        }
      }
      // Parse methods
      else if (currentLine.contains('(') && currentLine.contains('{')) {
        final method = _parseMethod(lines, currentIndex);
        if (method != null) {
          methods.add(method);
          currentIndex = _findClosingBrace(lines, currentIndex);
        }
      }
      // Parse properties
      else if (currentLine.contains('=') || currentLine.endsWith(';')) {
        final property = _parseProperty(currentLine);
        if (property != null) {
          properties.add(property);
        }
      }
      
      currentIndex++;
    }
    
    return ClassDeclaration(className, methods, properties, superClass: superClass);
  }
  
  MethodDefinition? _parseMethod(List<String> lines, int startIndex, {bool isConstructor = false}) {
    final line = lines[startIndex].trim();
    
    String methodName = '';
    final parameters = <Parameter>[];
    
    if (isConstructor) {
      methodName = 'constructor';
      final paramMatch = RegExp(r'constructor\s*\(([^)]*)\)').firstMatch(line);
      if (paramMatch != null) {
        _parseParameters(paramMatch.group(1) ?? '', parameters);
      }
    } else {
      final methodMatch = RegExp(r'(\w+)\s*\(([^)]*)\)').firstMatch(line);
      if (methodMatch != null) {
        methodName = methodMatch.group(1)!;
        _parseParameters(methodMatch.group(2) ?? '', parameters);
      }
    }
    
    // Extract method body
    final body = _extractMethodBody(lines, startIndex);
    
    return MethodDefinition(methodName, parameters, body, isConstructor: isConstructor);
  }
  
  void _parseParameters(String paramString, List<Parameter> parameters) {
    if (paramString.trim().isEmpty) return;
    
    final params = paramString.split(',');
    for (final param in params) {
      final trimmed = param.trim();
      if (trimmed.isNotEmpty) {
        // Handle default parameters: param = defaultValue
        if (trimmed.contains('=')) {
          final parts = trimmed.split('=');
          parameters.add(Parameter(parts[0].trim(), defaultValue: parts[1].trim()));
        } else {
          parameters.add(Parameter(trimmed));
        }
      }
    }
  }
  
  PropertyDefinition? _parseProperty(String line) {
    if (line.contains('=')) {
      final parts = line.split('=');
      final name = parts[0].trim();
      final value = parts[1].trim().replaceAll(';', '');
      return PropertyDefinition(name, initialValue: value);
    } else {
      final name = line.replaceAll(';', '').trim();
      if (name.isNotEmpty) {
        return PropertyDefinition(name);
      }
    }
    return null;
  }
  
  FunctionDeclaration? _parseFunction(List<String> lines, int startIndex, {bool isExported = false}) {
    final line = lines[startIndex].trim();
    final functionMatch = RegExp(r'function\s+(\w+)\s*\(([^)]*)\)').firstMatch(line);
    
    if (functionMatch != null) {
      final functionName = functionMatch.group(1)!;
      final parameters = <Parameter>[];
      _parseParameters(functionMatch.group(2) ?? '', parameters);
      
      final body = _extractMethodBody(lines, startIndex);
      final isAsync = line.contains('async');
      
      return FunctionDeclaration(functionName, parameters, body, isAsync: isAsync);
    }
    return null;
  }
  
  VariableDeclaration _parseVariable(String line) {
    final isConst = line.startsWith('const ');
    final variableMatch = RegExp(r'(?:const|let|var)\s+(\w+)(?:\s*=\s*(.+))?').firstMatch(line);
    
    final name = variableMatch?.group(1) ?? '';
    final initialValue = variableMatch?.group(2)?.replaceAll(';', '');
    
    return VariableDeclaration(name, initialValue: initialValue, isConst: isConst);
  }
  
  String _extractMethodBody(List<String> lines, int startIndex) {
    final buffer = StringBuffer();
    int braceCount = 0;
    bool foundOpenBrace = false;
    
    for (int i = startIndex; i < lines.length; i++) {
      final line = lines[i];
      
      for (int j = 0; j < line.length; j++) {
        if (line[j] == '{') {
          braceCount++;
          foundOpenBrace = true;
        } else if (line[j] == '}') {
          braceCount--;
        }
      }
      
      if (foundOpenBrace) {
        buffer.writeln(line);
      }
      
      if (foundOpenBrace && braceCount == 0) {
        break;
      }
    }
    
    return buffer.toString();
  }
  
  int _findClosingBrace(List<String> lines, int startIndex) {
    int braceCount = 0;
    bool foundOpenBrace = false;
    
    for (int i = startIndex; i < lines.length; i++) {
      final line = lines[i];
      
      for (int j = 0; j < line.length; j++) {
        if (line[j] == '{') {
          braceCount++;
          foundOpenBrace = true;
        } else if (line[j] == '}') {
          braceCount--;
        }
      }
      
      if (foundOpenBrace && braceCount == 0) {
        return i;
      }
    }
    
    return lines.length - 1;
  }
  
  bool _isStatementComplete(String line) {
    return line.trim().endsWith(';') || line.trim().endsWith('}');
  }
}