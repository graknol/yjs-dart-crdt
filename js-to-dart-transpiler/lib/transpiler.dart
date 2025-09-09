import 'dart:io';
import 'ast_parser.dart';
import 'dart_generator.dart';
import 'conversion_rules.dart';

/// Main transpiler class that orchestrates the JavaScript to Dart conversion
class JavaScriptToDartTranspiler {
  final JavaScriptASTParser _parser = JavaScriptASTParser();
  final DartCodeGenerator _generator = DartCodeGenerator();
  final ConversionRules _rules = ConversionRules();

  /// Transpile a JavaScript file to Dart
  Future<void> transpileFile(String inputPath, String outputPath) async {
    print('Reading JavaScript file: $inputPath');
    final jsContent = await File(inputPath).readAsString();
    
    print('Parsing JavaScript AST...');
    final ast = _parser.parseJavaScript(jsContent);
    
    print('Converting to Dart AST...');
    final dartAst = _rules.convertToDart(ast);
    
    print('Generating Dart code...');
    final dartCode = _generator.generateDart(dartAst);
    
    print('Writing Dart file: $outputPath');
    await File(outputPath).writeAsString(dartCode);
  }

  /// Transpile JavaScript code string directly to Dart code string
  String transpileCode(String jsCode) {
    final ast = _parser.parseJavaScript(jsCode);
    final dartAst = _rules.convertToDart(ast);
    return _generator.generateDart(dartAst);
  }
}