import 'package:analysis_utils/analysis_utils.dart';
import 'package:meta/meta.dart';

/// aca tené
/// la clásica,
/// amewo
class ExampleClass extends ParentClass {
  int field1;
  String field2;

  void method1() {
    print("method1 executed");
  }

  /// Greet `name`
  String method2(String name) => "Hello $name";

  ExampleClass(String param1, int param2, [this.field1]);

  ExampleClass.withField2(this.field2);
  //
  // ///Tiene docs, viteh?
  // ExampleClass.withField2final(this.field2);
  //
  // @visibleForTesting
  // ExampleClass.withField2const(this.field2);
}

class annon {
  final int n;
  final String text;
  const annon(this.n, [this.text]);
}

class ParentClass {
  @annon(1, "sorp")
  @annon(2)
  @annon(3, "longa")
  @annon(4)
  List<int> sorp = [];
}

main() {
  ClassAnalysis clazz = new ClassAnalysis.fromType(ParentClass);
  print("The class name is: ${clazz.name}");
  print("The fields are: " + clazz.fields.keys.join(", "));
  print("The methods are: " + clazz.methods.keys.join(", "));
  print("The constructors are: " + clazz.constructors.keys.join(", "));
  print("The documentation for metho2 is: " + clazz.methods["method2"].docs);
}
