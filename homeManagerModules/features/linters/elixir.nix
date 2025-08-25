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
    # Install Elixir and Credo - versions managed by NixOS packages
    home.packages = with pkgs; [
      elixir
      # Note: Credo is typically installed per-project via mix, not globally
    ];

    # Global Credo configuration using official rrrene/credo recommendations
    home.file.".credo.exs".text = ''
      # Global .credo.exs configuration for Elixir projects
      # This provides sensible defaults that can be overridden by project-specific configs
      %{
        configs: [
          %{
            name: "default",
            files: %{
              included: ["lib/", "src/", "web/", "apps/", "test/", "spec/"],
              excluded: ["deps/", "_build/", "priv/static/"]
            },
            plugins: [],
            requires: [],
            strict: false,
            parse_timeout: 5000,
            color: true,
            checks: %{
              enabled: [
                # Consistency checks
                {Credo.Check.Consistency.ExceptionNames, []},
                {Credo.Check.Consistency.LineEndings, []},
                {Credo.Check.Consistency.ParameterPatternMatching, []},
                {Credo.Check.Consistency.SpaceAroundOperators, []},
                {Credo.Check.Consistency.SpaceInParentheses, []},
                {Credo.Check.Consistency.TabsOrSpaces, []},

                # Design checks  
                {Credo.Check.Design.AliasUsage, [priority: :low, if_nested_deeper_than: 2, if_called_more_often_than: 0]},
                {Credo.Check.Design.TagTODO, [priority: :low]},
                {Credo.Check.Design.TagFIXME, []},

                # Readability checks
                {Credo.Check.Readability.AliasOrder, []},
                {Credo.Check.Readability.FunctionNames, []},
                {Credo.Check.Readability.LargeNumbers, []},
                {Credo.Check.Readability.MaxLineLength, [priority: :low, max_length: 120]},
                {Credo.Check.Readability.ModuleAttributeNames, []},
                {Credo.Check.Readability.ModuleDoc, []},
                {Credo.Check.Readability.ModuleNames, []},
                {Credo.Check.Readability.ParenthesesInCondition, []},
                {Credo.Check.Readability.ParenthesesOnZeroArityDefs, []},
                {Credo.Check.Readability.PipeIntoAnonymousFunctions, []},
                {Credo.Check.Readability.PredicateFunctionNames, []},
                {Credo.Check.Readability.PreferImplicitTry, []},
                {Credo.Check.Readability.RedundantBlankLines, []},
                {Credo.Check.Readability.Semicolons, []},
                {Credo.Check.Readability.SpaceAfterCommas, []},
                {Credo.Check.Readability.StringSigils, []},
                {Credo.Check.Readability.TrailingBlankLine, []},
                {Credo.Check.Readability.TrailingWhiteSpace, []},
                {Credo.Check.Readability.UnnecessaryAliasExpansion, []},
                {Credo.Check.Readability.VariableNames, []},
                {Credo.Check.Readability.WithSingleClause, []},

                # Refactoring opportunities  
                {Credo.Check.Refactor.CondStatements, []},
                {Credo.Check.Refactor.CyclomaticComplexity, []},
                {Credo.Check.Refactor.FunctionArity, []},
                {Credo.Check.Refactor.LongQuoteBlocks, []},
                {Credo.Check.Refactor.MapInto, []},
                {Credo.Check.Refactor.MatchInCondition, []},
                {Credo.Check.Refactor.NegatedConditionsInUnless, []},
                {Credo.Check.Refactor.NegatedConditionsWithElse, []},
                {Credo.Check.Refactor.Nesting, []},
                {Credo.Check.Refactor.UnlessWithElse, []},
                {Credo.Check.Refactor.WithClauses, []},

                # Warnings
                {Credo.Check.Warning.ApplicationConfigInModuleAttribute, []},
                {Credo.Check.Warning.BoolOperationOnSameValues, []},
                {Credo.Check.Warning.ExpensiveEmptyEnumCheck, []},
                {Credo.Check.Warning.IExPry, []},
                {Credo.Check.Warning.IoInspect, []},
                {Credo.Check.Warning.LazyLogging, []},
                {Credo.Check.Warning.OperationOnSameValues, []},
                {Credo.Check.Warning.OperationWithConstantResult, []},
                {Credo.Check.Warning.RaiseInsideRescue, []},
                {Credo.Check.Warning.SpecWithStruct, []},
                {Credo.Check.Warning.WrongTestFileExtension, []},
                {Credo.Check.Warning.UnusedEnumOperation, []},
                {Credo.Check.Warning.UnusedFileOperation, []},
                {Credo.Check.Warning.UnusedKeywordOperation, []},
                {Credo.Check.Warning.UnusedListOperation, []},
                {Credo.Check.Warning.UnusedPathOperation, []},
                {Credo.Check.Warning.UnusedRegexOperation, []},
                {Credo.Check.Warning.UnusedStringOperation, []},
                {Credo.Check.Warning.UnusedTupleOperation, []}
              ]
            }
          }
        ]
      }
    '';
  };
}
