{
  config,
  lib,
  pkgs,
  ...
}:
with lib;
let cfg = config.myHomeManager.linters;
in {
  config = mkIf cfg.enable {
    # Install C++ linting and formatting tools
    home.packages = with pkgs; [
      clang-tools    # clang-tidy, clang-format from LLVM
      cppcheck       # Static analysis tool for C/C++
    ];

    # Global clang-format configuration
    home.file.".clang-format".text = ''
      ---
      BasedOnStyle: Google
      AccessModifierOffset: -2
      AlignAfterOpenBracket: Align
      AlignConsecutiveAssignments: false
      AlignConsecutiveDeclarations: false
      AlignEscapedNewlines: Left
      AlignOperands: true
      AlignTrailingComments: true
      AllowAllParametersOfDeclarationOnNextLine: true
      AllowShortBlocksOnASingleLine: false
      AllowShortCaseLabelsOnASingleLine: false
      AllowShortFunctionsOnASingleLine: All
      AllowShortIfStatementsOnASingleLine: true
      AllowShortLoopsOnASingleLine: true
      AlwaysBreakAfterDefinitionReturnType: None
      AlwaysBreakAfterReturnType: None
      AlwaysBreakBeforeMultilineStrings: true
      AlwaysBreakTemplateDeclarations: true
      BinPackArguments: true
      BinPackParameters: true
      BreakBeforeBraces: Attach
      BreakBeforeBinaryOperators: None
      BreakBeforeTernaryOperators: true
      BreakConstructorInitializersBeforeComma: false
      BreakAfterJavaFieldAnnotations: false
      BreakStringLiterals: true
      ColumnLimit: 120
      CommentPragmas: '^ IWYU pragma:'
      ConstructorInitializerAllOnOneLineOrOnePerLine: true
      ConstructorInitializerIndentWidth: 4
      ContinuationIndentWidth: 4
      Cpp11BracedListStyle: true
      DerivePointerAlignment: true
      DisableFormat: false
      ExperimentalAutoDetectBinPacking: false
      ForEachMacros: [ foreach, Q_FOREACH, BOOST_FOREACH ]
      IncludeCategories:
        - Regex: '^<.*\.h>'
          Priority: 1
        - Regex: '^<.*'
          Priority: 2
        - Regex: '.*'
          Priority: 3
      IncludeIsMainRegex: '([-_](test|unittest))?$'
      IndentCaseLabels: true
      IndentWidth: 2
      IndentWrappedFunctionNames: false
      JavaScriptQuotes: Leave
      JavaScriptWrapImports: true
      KeepEmptyLinesAtTheStartOfBlocks: false
      MacroBlockBegin: ''
      MacroBlockEnd: ''
      MaxEmptyLinesToKeep: 1
      NamespaceIndentation: None
      ObjCBlockIndentWidth: 2
      ObjCSpaceAfterProperty: false
      ObjCSpaceBeforeProtocolList: false
      PenaltyBreakBeforeFirstCallParameter: 1
      PenaltyBreakComment: 300
      PenaltyBreakFirstLessLess: 120
      PenaltyBreakString: 1000
      PenaltyExcessCharacter: 1000000
      PenaltyReturnTypeOnItsOwnLine: 200
      PointerAlignment: Left
      ReflowComments: true
      SortIncludes: true
      SpaceAfterCStyleCast: false
      SpaceAfterTemplateKeyword: true
      SpaceBeforeAssignmentOperators: true
      SpaceBeforeParens: ControlStatements
      SpaceInEmptyParentheses: false
      SpacesBeforeTrailingComments: 2
      SpacesInAngles: false
      SpacesInContainerLiterals: true
      SpacesInCStyleCastParentheses: false
      SpacesInParentheses: false
      SpacesInSquareBrackets: false
      Standard: Auto
      TabWidth: 8
      UseTab: Never
    '';

    # Global clang-tidy configuration  
    home.file.".clang-tidy".text = ''
      ---
      Checks: >
        *,
        -abseil-*,
        -android-*,
        -fuchsia-*,
        -google-*,
        -llvm*,
        -objc-*,
        -readability-else-after-return,
        -readability-static-accessed-through-instance,
        -readability-avoid-const-params-in-decls,
        -cppcoreguidelines-non-private-member-variables-in-classes,
        -misc-non-private-member-variables-in-classes,
      WarningsAsErrors: ""
      HeaderFilterRegex: ""
      FormatStyle: none
      CheckOptions:
        - key: readability-identifier-naming.NamespaceCase
          value: lower_case
        - key: readability-identifier-naming.ClassCase
          value: CamelCase
        - key: readability-identifier-naming.StructCase
          value: CamelCase
        - key: readability-identifier-naming.TemplateParameterCase
          value: CamelCase
        - key: readability-identifier-naming.FunctionCase
          value: lower_case
        - key: readability-identifier-naming.VariableCase
          value: lower_case
        - key: readability-identifier-naming.ClassMemberCase
          value: lower_case
        - key: readability-identifier-naming.ClassMemberSuffix
          value: _
        - key: readability-identifier-naming.PrivateMemberSuffix
          value: _
        - key: readability-identifier-naming.ProtectedMemberSuffix
          value: _
        - key: readability-identifier-naming.EnumConstantCase
          value: CamelCase
        - key: readability-identifier-naming.ConstantCase
          value: UPPER_CASE
        - key: readability-identifier-naming.StaticConstantCase
          value: UPPER_CASE
        - key: readability-identifier-naming.GlobalConstantCase
          value: UPPER_CASE
    '';
  };
}
