import 'dart:developer';
import 'dart:io';
import "dart:mirrors" hide SourceLocation;
import 'package:analysis_utils/src/annotations_intantiator.dart';
import "package:analyzer/analyzer.dart";
import 'package:analyzer/dart/ast/token.dart';
import 'package:source_span/source_span.dart';

/// All what must be parsed with the analysis package should be done with this
class SourceAnalysis {
  static final Map<String, SourceAnalysis> _filesAnalyzedCache = {};

  /// The path in a String manner
  String path;

  /// The result of executing the `parseDartFile()`'s Analysis package method
  CompilationUnit fileParse;

  /// The code of the file
  String code;

  factory SourceAnalysis.forFilePath(String path) {
    if (_filesAnalyzedCache.containsKey(path))
      return _filesAnalyzedCache[path];
    else {
      final SourceAnalysis ret = new SourceAnalysis._(path);
      _filesAnalyzedCache[path] = ret;
      return ret;
    }
  }

  factory SourceAnalysis.forMirror(DeclarationMirror mirror) {
    String path = mirror.location?.sourceUri?.path;
    if (path == null)
      throw new UnsupportedError(
          "The mirror '$mirror' doesn't support the sourceUri property. Try providing a SourceAnalysis instance from another mirror that does.");
    return new SourceAnalysis.forFilePath(path);
  }

  SourceAnalysis._(this.path) {
    if (path.endsWith(".dart")) {
      this.fileParse = parseDartFile(path);
      File file = new File(path);
      this.code = file.readAsStringSync();
    } else
      throw new Exception("You can only parse .dart files");
  }
}

/// base class used for traversing Analysis nodes in oprder to find the needed
/// ones (allocated in `finded`)
abstract class Finder<D> extends SimpleAstVisitor {
  final String name;
  D finded;
  Finder(this.name);
}

class ParameterFinder extends Finder<FormalParameterList> {
  ParameterFinder(String name) : super(name) {}

  // @override
  // visitImportDirective(ImportDirective node) => null;
  // @override
  // visitComment(node) => null;
  // @override
  // visitTypeName(node) => print("TypeName: $node");
  // @override
  // visitSimpleIdentifier(node) => print("SimpleIdentifier: $node");
  // @override
  visitFormalParameterList(FormalParameterList node) {
    if (finded != null)
      throw new Exception("There can't be 2 parametersList, WTF?");
    this.finded = node;
  }
  //
  // @override
  // visitExpressionFunctionBody(node) => print("FunctionBody: $node");
}

class ClassFinder extends Finder<ClassDeclaration> {
  ClassFinder(String name) : super(name);

  @override
  visitClassDeclaration(ClassDeclaration node) {
    if (node.name.toString() == name) {
      this.finded = node;
    }
    return super.visitClassDeclaration(node);
  }
}

class FieldFinder extends Finder<FieldDeclaration> {
  FieldFinder(String name) : super(name);
  @override
  visitFieldDeclaration(FieldDeclaration node) {
    if (node.fields.variables
        .any((VariableDeclaration v) => v.name.toString() == name)) {
      this.finded = node;
    }
    return super.visitFieldDeclaration(node);
  }
}

class ConstructorFinder extends Finder<ConstructorDeclaration> {
  ConstructorFinder(String name)
      : super(name.startsWith(".") ? name.substring(1) : name);
  visitConstructorDeclaration(ConstructorDeclaration node) {
    if ((node.name?.toString() ?? "") == name) {
      this.finded = node;
    }
    return super.visitConstructorDeclaration(node);
  }
}

class MethodFinder extends Finder<MethodDeclaration> {
  MethodFinder(String name) : super(name);
  @override
  visitMethodDeclaration(MethodDeclaration node) {
    if (node.name.toString() == name) this.finded = node;
    return super.visitMethodDeclaration(node);
  }
}

abstract class EntityAnalysis<A extends AstNode, F extends Finder> {
  String name;
  String docs;
  SourceSpan location;
  List<MetadataAnalysis> metadata;
  SourceAnalysis source;
  DeclarationMirror mirror;
  A analyzerDeclaration;
  F entityFinder;
  Declaration analyzerContainer;

  List<MetadataAnalysis> _computeMetadata() {
    NodeList<Annotation> annotations =
        (analyzerDeclaration as AnnotatedNode).metadata;
    List<MetadataAnalysis> ret = [];
    for (int i = 0; i < annotations.length; i++) {
      Annotation a = annotations[i];
      ret.add(new MetadataAnalysis(a, mirror.metadata[i]));
    }
    return ret;
  }

  EntityAnalysis(this.mirror, {this.analyzerContainer, this.source}) {
    _computeName();
    this.source ??= new SourceAnalysis.forMirror(mirror);
    _findDeclaration();
    _computeAnalysis();
    this.location = _computeLocation();
  }

  void _computeName() {
    this.name = MirrorSystem.getName(mirror.simpleName);
  }

  String toString() => name;

  _findDeclaration() {
    ClassMirror finderMirror = reflectClass(F);
    this.entityFinder =
        finderMirror.newInstance(new Symbol(""), [name]).reflectee;
    if (analyzerContainer != null)
      analyzerContainer.visitChildren(entityFinder as Finder);
    else
      source.fileParse.visitChildren(entityFinder as Finder);
    this.analyzerDeclaration = (entityFinder as Finder).finded as A;
  }

  _computeAnalysis() {
    if (analyzerDeclaration != null && analyzerDeclaration is AnnotatedNode) {
      this.docs = _computeDocs(analyzerDeclaration as AnnotatedNode);
      this.metadata = _computeMetadata();
    }
  }

  SourceSpan _computeLocation() {
    var node;
    try {
      node = (analyzerDeclaration as AnnotatedNode);
    } catch (e) {
      node = (analyzerDeclaration as AstNode);
    }
    Token startToken = ((node is AnnotatedNode)
                ? node?.documentationComment?.beginToken
                : null) ??
            node?.beginToken,
        endToken = node?.endToken;
    if (startToken == null || endToken == null) return null;
    SourceLocation start =
        new SourceLocation(startToken.offset, sourceUrl: source.path);
    SourceLocation end =
        new SourceLocation(endToken.offset + 1, sourceUrl: source.path);
    String text = source.code.substring(start.offset, end.offset);
    return new SourceSpan(start, end, text);
  }

  String _computeDocs(AnnotatedNode declaration) {
    List<Token> tokens = declaration?.documentationComment?.tokens;
    if (tokens == null || tokens.length == 0) return "";
    if (tokens.length == 1) {
      //Maybe a /** docs */ documentation type?
      String doc = tokens.first.toString();
      if (doc.startsWith("/**"))
        return _computeComplexDocsComment(doc);
      else if (doc.startsWith("///"))
        return _computeNormalDocsComment(tokens);
      else
        throw new UnsupportedError(
            "Don't kwno what to do here. Please make me an issue in analysis_utils package showing the documentation of '$name' entity");
    } else {
      // Must be the classical /// documentation
      return _computeNormalDocsComment(tokens);
    }
  }

  String _computeComplexDocsComment(String docLine) {
    RegExp formatter = new RegExp("\n[ *]*");
    return docLine
        .substring(3, docLine.length - 3) //removes the /** and */
        .replaceAll(formatter, " ")
        .trim();
  }

  String _computeNormalDocsComment(List<Token> tokens) {
    return tokens
        .map((Token t) => t.toString().substring(3).trim())
        .join(" ")
        .trim();
  }
}

class MetadataAnalysis {
  Type type;
  Annotation node;
  InstanceMirror mirror;
  dynamic instance;
  ArgumentsResolution arguments;

  MetadataAnalysis(this.node, this.mirror) {
    this.instance = mirror.reflectee;
    this.type = mirror.type.reflectedType;
    this.arguments = new ArgumentsResolution.fromArgumentList(node.arguments);
  }
}

class ClassAnalysis extends EntityAnalysis<ClassDeclaration, ClassFinder> {
  ClassAnalysis superclass;
  Map<String, FieldAnalysis> fields = {};
  Map<String, MethodAnalysis> methods = {};
  Map<String, ConstructorAnalysis> constructors = {};

  factory ClassAnalysis.fromInstance(Object instance) {
    InstanceMirror mirror = reflect(instance);
    return new ClassAnalysis.fromMirror(mirror.type);
  }

  factory ClassAnalysis.fromType(Type type) {
    ClassMirror mirror = reflectClass(type);
    return new ClassAnalysis.fromMirror(mirror);
  }

  ClassAnalysis.fromMirror(ObjectMirror mirror) : super(mirror as ClassMirror) {
    ClassMirror classMirror = (mirror as ClassMirror);
    this.superclass = classMirror.superclass == null ||
            classMirror.superclass.reflectedType == Object
        ? null
        : new ClassAnalysis.fromMirror(classMirror.superclass);
    Map<String, FieldAnalysis> fields = {};
    Map<String, MethodAnalysis> methods = {};
    classMirror.declarations.forEach((Symbol name, DeclarationMirror d) {
      // if (d is VariableMirror) this.fields.add(new FieldAnalysis.fromMirror(d));
      // if (d is MethodMirror) this.methods.add(new MethodAnalysis.fromMirror(d));
      if (d is VariableMirror) {
        FieldAnalysis analysis = new FieldAnalysis(this, d);
        fields[analysis.name] = analysis;
      }
      if (d is MethodMirror) {
        if (d.isConstructor) {
          var analysis = new ConstructorAnalysis(this, d);
          this.constructors[analysis.name] = analysis;
        } else {
          var analysis = new MethodAnalysis(this, d);
          methods[analysis.name] = analysis;
        }
      }
    });
    if (superclass != null) {
      this.fields = new Map.fromEntries(superclass.fields.entries);
      this.methods = new Map.fromEntries(superclass.methods.entries);
    }
    this.fields.addAll(fields);
    this.methods.addAll(methods);
  }
}

class ClassMemberAnalysis<D extends Declaration, F extends Finder>
    extends EntityAnalysis<D, F> {
  ClassAnalysis container;
  ClassMemberAnalysis(
      DeclarationMirror mirror, this.container, SourceAnalysis sourceAnalysis)
      : super(mirror,
            analyzerContainer: container.analyzerDeclaration,
            source: sourceAnalysis);
}

class FieldAnalysis extends ClassMemberAnalysis<FieldDeclaration, FieldFinder> {
  TypeMirror type;

  FieldAnalysis(ClassAnalysis container, VariableMirror declaration)
      : super(declaration, container, container.source);
}

class ConstructorAnalysis
    extends ClassMemberAnalysis<ConstructorDeclaration, ConstructorFinder>
    with ParametersInterface {
  ConstructorDeclaration analyzerDeclaration;
  ConstructorAnalysis(ClassAnalysis container, MethodMirror declaration)
      : super(declaration, container, container.source) {
    this.parameters = new ParametersAnalysis(this, declaration);
  }

  bool get isConst => analyzerDeclaration.constKeyword != null;
  bool get isExternal => analyzerDeclaration.externalKeyword != null;
  bool get isFactory => analyzerDeclaration.factoryKeyword != null;

  _computeName() {
    String str = MirrorSystem.getName(this.mirror.simpleName);
    int index = str.indexOf(r".");
    this.name = index == -1 ? "" : str.substring(index + 1);
  }
}

class MethodAnalysis
    extends ClassMemberAnalysis<MethodDeclaration, MethodFinder>
    with ParametersInterface {
  MethodAnalysis(ClassAnalysis container, MethodMirror declaration)
      : super(declaration, container, container.source) {
    this.parameters = new ParametersAnalysis(this, declaration);
  }
}

class ParametersInterface {
  ParametersAnalysis parameters;

  /// Syntactic sugar for the set of always optional parameters that need a name
  /// to be invoked in arguments
  Set<Parameter> get namedParameters => parameters.named;

  /// Syntactic sugar for the always required, ordered, positional parameters
  List<Parameter> get requiredParameters => parameters.ordinary;

  /// Syntactic sugar for the optionals (both named as positional) parameters
  List<Parameter> get optionalParameters => parameters.optionals;

  /// Same as `requiredParameters`, the normal old school lifelonging parameters
  List<Parameter> get ordinaryParameters => parameters.ordinary;

  /// Syntactic sugar for the List of parameters that should (or could) be
  /// invoked (both the types of required and the optionals)
  List<Parameter> get positionalParameters => parameters.positionals;

  /// Syntactic sugar for the List of positional optional parameters (those
  /// defined between square brackets)
  List<Parameter> get positionalOptionalParameters =>
      parameters.positionalOptionals;
}

class Parameter {
  var defaultValue;
  Type type;
  String name;
  ParameterMirror mirror;
  FormalParameter node;

  Parameter(FormalParameterList container, this.mirror) {
    this.type = mirror.type.reflectedType;
    this.name = MirrorSystem.getName(mirror.simpleName);
    this.defaultValue =
        mirror.hasDefaultValue ? mirror.defaultValue.reflectee : null;
    try {
      this.node = container.parameters
          .singleWhere((q) => q.identifier.toString() == this.name);
    } catch (e) {
      throw new Exception(
          "Weird error... there seems to not exist a parameter node for a mirror of itself");
    }
  }

  bool get isOptional => node.kind.isOptional;
  bool get isNamed => node.kind == ParameterKind.NAMED;
  bool get isOrdinary => node.kind == ParameterKind.REQUIRED;
  bool get isPositionalOptional => node.kind == ParameterKind.POSITIONAL;
  bool get isThisInitializer => true;
}

class ParametersAnalysis
    extends EntityAnalysis<FormalParameterList, ParameterFinder> {
  ClassMemberAnalysis container;
  List<Parameter> _parameters = [];

  ParametersAnalysis(this.container, MethodMirror mirror)
      : super(mirror,
            source: container.source,
            analyzerContainer: container.analyzerDeclaration) {
    if (analyzerDeclaration != null) {
      mirror.parameters.forEach((ParameterMirror m) {
        this._parameters.add(new Parameter(analyzerDeclaration, m));
      });
    }
  }

  /// All the parameters, simple as they are
  List<Parameter> get all => _parameters;

  /// Always required, ordered, positional parameters
  List<Parameter> get required =>
      _parameters.where((p) => p.isOrdinary).toList();

  /// Optional parameters (both positional and named)
  List<Parameter> get optionals =>
      _parameters.where((p) => p.isOptional).toList();

  /// Set of always optional parameters that need a name to be invoked in
  /// arguments
  Set<Parameter> get named => _parameters.where((p) => p.isNamed).toSet();

  /// The normal old school lifelonging parameters (required positionals)
  List<Parameter> get ordinary =>
      _parameters.where((p) => p.isOrdinary).toList();

  /// List of parameters that should (or could) be invoked in a stablished order
  /// (both the required and the optionals types)
  List<Parameter> get positionals =>
      _parameters.where((p) => p.isOrdinary || p.isPositionalOptional).toList();

  /// The positional optional parameters (those defined betwenn square brackets)
  List<Parameter> get positionalOptionals =>
      _parameters.where((p) => p.isPositionalOptional).toList();

  get length => _parameters.length;

  operator [](String name) =>
      _parameters.singleWhere((Parameter p) => p.name == name, orElse: null);
}
