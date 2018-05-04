import 'package:analysis_utils/analysis.dart';
import 'package:test/test.dart';

/// annotation made for testing
class annotationExample {
  ///testing field
  final int number;

  /** some
   * very
   * long
   * doc
   * block
   */
  final String text;
  const annotationExample([this.number, this.text]);
}

class annon {
  final int n;
  final String text;
  const annon(this.n, [this.text]);
}

class ParentClass {
  @annotationExample(1, "text")
  int number;
}

class ChildClass extends ParentClass {
  @annon(1, "sor" + "p")
  @annon(2)
  @annon(3, "lon" "ga")
  @annon(4)
  var annotated;

  @annotationExample()
  String text;

  ChildClass(this.text, [int number]) {
    this.number = number;
  }

  ChildClass.complex();

  ChildClass.moreComplex(String someText) {}

  @annotationExample(7)
  String processText([String addingText = "default"]) {
    this.text = "Number is $number";
    if (addingText != null) text += " and it has $addingText";
    return this.text;
  }
}

void main() {
  ClassAnalysis annonExample = new ClassAnalysis.fromType(annotationExample);
  ClassAnalysis parent = new ClassAnalysis.fromType(ParentClass);
  ChildClass c = new ChildClass("sorp");
  c.number = 2;
  ClassAnalysis child = new ClassAnalysis.fromInstance(c);
  group("Parameters:", () {
    test("methods", () {
      expect(child.methods["processText"].positionalParameters, isNotEmpty);
      expect(child.methods["processText"].optionalParameters, isNotEmpty);
      expect(child.methods["processText"].optionalParameters.first,
          equals(child.methods["processText"].positionalParameters.first));
      expect(child.methods["processText"].positionalOptionalParameters.first,
          equals(child.methods["processText"].positionalParameters.first));
      expect(child.methods["processText"].optionalParameters.first.name,
          equals("addingText"));
      expect(child.methods["processText"].parameters.optionals.first.type,
          equals(String));
      expect(
          child.methods["processText"].parameters.optionals.first.defaultValue,
          equals("default"));
      expect(child.methods["processText"].parameters.named, isEmpty);
    });
    test("constructors", () {
      expect(child.constructors[""].parameters.named, isEmpty);
      expect(
          child.constructors[""].parameters.optionals.first.isThisInitializer,
          isTrue);
      expect(child.constructors[""].parameters.required.first.type,
          equals(String));
      expect(child.constructors[""].parameters.required.first.name,
          equals("text"));
      expect(
          child.constructors[""].parameters.optionals.first.type, equals(int));
      expect(child.constructors[""].parameters.optionals.first.name,
          equals("number"));
    });
    test("metadata", () {
      expect(parent.fields["number"].metadata.first.arguments.positional.first,
          equals(1));
      expect(parent.fields["number"].metadata.first.arguments.positional.first,
          new isInstanceOf<int>());
      expect(child.fields["number"].metadata.first.arguments.positional[1],
          equals("text"));
      expect(child.fields["number"].metadata.first.arguments.positional[1],
          new isInstanceOf<String>());
    });
  });
  group('Class components', () {
    test("Reflects the fields", () {
      expect(annonExample.fields["text"], isNotNull);
      expect(annonExample.fields.length, equals(2));
      //reflects inherited fields:
      expect(child.fields["number"], isNotNull);
    });
    test("Reflects the methods", () {
      expect(annonExample.methods, isEmpty);
      expect(child.methods.length, equals(1));
      child.methods.forEach((String name, MethodAnalysis method) {
        expect(name, equals("processText"));
      });
    });
    test("processes the Documentations", () {
      expect(annonExample.docs, equals("annotation made for testing"));
      expect(annonExample.fields["number"].docs, equals("testing field"));
      expect(
          annonExample.fields["text"].docs, equals("some very long doc block"));
    });
  });
  group("Constructors:", () {
    test('Const constructor', () {
      ConstructorAnalysis constructor = annonExample.constructors.values.first;
      expect(constructor.name, equals(""));
      //The constructor is not default, it exists defined in the code
      expect(constructor.location, isNotNull);
      expect(constructor.isConst, isTrue);
    });
    test("Default constructor", () {
      expect(parent.constructors, isNotEmpty);
      expect(parent.constructors.values.first.location, isNull);
      expect(parent.constructors[""], isNotNull);
    });
    test("Several constructors", () {
      expect(child.constructors[""], isNotNull);
      expect(child.constructors["complex"], isNotNull);
      expect(child.constructors["moreComplex"], isNotNull);
    });
  });
  group("Annotations:", () {
    test("Reflects annotations", () {
      expect(child.fields["number"].metadata, isNotNull);
      expect(child.fields["number"].metadata, isNotEmpty);
      expect(
          (child.fields["number"].metadata.first.instance as annotationExample)
              .text,
          equals("text"));
      expect(
          (child.fields["number"].metadata.first.instance as annotationExample)
              .number,
          equals(1));
    });
    test("Reflects well multiple annotations", () {
      List values = ["sorp", null, "longa", null];
      for (int i = 0; i < 4; i++) {
        expect(child.fields["annotated"].metadata[i].type, equals(annon));
        expect(child.fields["annotated"].metadata[i].instance.text,
            equals(values[i]));
        expect(child.fields["annotated"].metadata[i].instance.n, equals(i + 1));
        expect(
            child.fields["annotated"].metadata[i].mirror
                .getField(new Symbol("n"))
                .reflectee,
            equals(i + 1));
        expect(child.fields["annotated"].metadata[i].arguments.positional[0],
            equals(i + 1));
        expect(
            child.fields["annotated"].metadata[i].node.arguments.arguments.first
                .toString(),
            equals((i + 1).toString()));
      }
    });
  });
}
