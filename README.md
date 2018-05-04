# analysis_utils

A library for facilitating the analysis of code integrating both [dart:mirrors](https://api.dartlang.org/dev/2.0.0-dev.53.0/dart-mirrors/dart-mirrors-library.html) and [analyzer](https://www.dartdocs.org/documentation/analyzer/latest/) packages (in the AST nodes facet)

## Features

So far the library supports:
 - Documentation blocks parsing
 - [source_span](https://www.dartdocs.org/documentation/source_span/latest/)'s in-file source locations
 - Annotations analysis and instantiation
 - Class Analysis
  - Method analysis
  - Field analysis
  - Constructor analysis

## Usage
So far, the usage is ClassAnalysis oriented only:

```
import "package:analysis_utils/analysis.dart";

main(){
  ClassAnalysis typeAnalysis = new ClassAnalysis.fromType(Clazz);
  Clazz c = new Clazz();
  ClassAnalysis instanceAnalysis = new ClassAnalysis.fromInstance(c);
}
```

For more info you can see the [example](https://pub.dartlang.org/packages/analysis_utils#-example-tab-), [test](https://github.com/Rodsevich/analysis_utils/blob/master/test/analysis_utils_test.dart) or [documentation](https://pub.dartlang.org/documentation/analysis_utils/latest/)

Please file feature requests and bugs at the [issue tracker][tracker].

[tracker]: http://github.com/Rodsevich/analysis_utils/issues/
