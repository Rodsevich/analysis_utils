import 'package:analysis_utils/analysis.dart';

/// The classic documentation
/// comment is supported
class ExampleClass extends ParentClass {
  /** Also
   * this
   * kind
   * of
   * documentation
   * is
   * supported
   */
  int field1;
  String field2;

  void method1() {
    print("method1 executed");
  }

  /// Greet `name`
  String method2(String name) => "Hello $name";

  ExampleClass(String param1, int param2, [this.field1]);

  ExampleClass.withField2(this.field2);
}

//custom annotation, ain't a documentation comment, shouldn't be parsed, so
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

  double var1 = 2.0, initVal = 723 + 123 / 2;
}

main() {
  ClassAnalysis clazz = new ClassAnalysis.fromType(ExampleClass);
  print("The class name is: ${clazz.name}");
  print("The fields are: " + clazz.fields.keys.join(", "));
  print("The initial value of 'initVal' field is:"
      " ${clazz.fields['initVal'].defaultValue}");
  print("The methods are: " + clazz.methods.keys.join(", "));
  print("The constructors are: " + clazz.constructors.keys.join(", "));
  print(
      "  The default constructor has ${clazz.constructors[""].parameters.length}"
      " parameters:\n${clazz.constructors[""].parameters.all.map((Parameter p) => p.name).join(", ")}");
  print("The documentation for method2 is: " + clazz.methods["method2"].docs);
  print("The inherintance preserves even the annotations from the parent"
      "class! (it has ${clazz.fields["sorp"].metadata.length} annotations)");
}
