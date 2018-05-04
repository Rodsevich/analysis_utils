import 'dart:mirrors';
import 'package:analyzer/analyzer.dart';

/// Class used to resolve the parameters in compile time. i.e. 1 + 2 will be
/// resolved to 3, without having to execute code. ConstantEvaluator handles it.
class _ArgumentsResolver extends ConstantEvaluator {
  /// resolves the (name: "expression") arguments kind
  NamedExpression visitNamedExpression(NamedExpression node) {
    node.setProperty("resolution", node.expression.accept(this));
    return node;
  }
}

/// Class intended to provide an analysis of analyzed [ArgumentList] or string
/// "(arg1,arg2,argN)" formatted arguments in a way suitable for instantiating
/// from mirrors
class ArgumentsResolution {
  List<dynamic> positional = [];
  Map<Symbol, dynamic> named = {};
  ArgumentsResolution.fromArgumentList(ArgumentList list) {
    _processArgs(list);
  }

  /// Must be provided a `source` in a "(arg1,arg2,argN)" format
  ArgumentsResolution.fromSourceConstants(String source) {
    String funcSrc = "var q = a$source;";
    CompilationUnit c = parseCompilationUnit(funcSrc);
    var t = c.declarations.single as TopLevelVariableDeclaration;
    VariableDeclarationList list = t.childEntities.first;
    VariableDeclaration de = list.variables.first;
    Expression expression = de.initializer;
    ArgumentList args = (expression as MethodInvocation).argumentList;
    _processArgs(args);
  }
  _processArgs(ArgumentList list) {
    _ArgumentsResolver resolver = new _ArgumentsResolver();
    for (AstNode arg in list.arguments) {
      //resolve the constant expressions like "str" "ing" (will resolve to "string")
      var val = arg.accept(resolver);
      // only thing that can't be properly resoolved because of the Label + Expression
      if (val is NamedExpression)
        named[new Symbol(val.name.label.token.value())] =
            val.getProperty("resolution");
      else
        positional.add(val);
    }
  }
}

/// Instnatiate from an analyzer's package's [Annotation] (must provide the type,
/// however)
dynamic instanceFromAnnotation(Type annotationType, Annotation annotation) =>
    instantiate(annotationType, annotation.constructorName ?? '',
        new ArgumentsResolution.fromArgumentList(annotation.arguments));

dynamic instantiate(Type type, constructorName, ArgumentsResolution arguments) {
  ClassMirror annotationMirror = reflectClass(type);
  return annotationMirror
      .newInstance(
          (constructorName is Symbol)
              ? constructorName
              : new Symbol(constructorName),
          arguments.positional,
          arguments.named)
      .reflectee;
}
