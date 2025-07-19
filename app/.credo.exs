# This file contains the configuration for Credo.
%{
  configs: [
    %{
      # Run any config using `mix credo -C <name>`. If no config name is given
      # "default" is used.
      name: "default",
      # These are the files included in the analysis:
      files: %{
        # You can give explicit globs or simply directories. In the latter case
        # `**/*.{ex,exs}` will be used.
        included: [
          "lib/",
          "src/",
          "test/",
          "web/",
          "apps/*/lib/",
          "apps/*/src/",
          "apps/*/test/",
          "apps/*/web/"
        ],
        excluded: [~r"/_build/", ~r"/deps/", ~r"/node_modules/"]
      },
      plugins: [],
      requires: [],
      strict: true,
      # File parsing timeout in milliseconds.
      parse_timeout: 5000,
      color: true,
      checks: %{
        enabled: [
          # Consistency Checks
          {Credo.Check.Consistency.ExceptionNames, []},
          {Credo.Check.Consistency.LineEndings, []},
          {Credo.Check.Consistency.MultiAliasImportRequireUse, []},
          {Credo.Check.Consistency.ParameterPatternMatching, []},
          {Credo.Check.Consistency.SpaceAroundOperators, []},
          {Credo.Check.Consistency.SpaceInParentheses, []},
          {Credo.Check.Consistency.TabsOrSpaces, []},
          {Credo.Check.Consistency.UnusedVariableNames, []},

          # Design Checks
          {Credo.Check.Design.AliasUsage,
           [priority: :low, if_nested_deeper_than: 2, if_called_more_often_than: 0]},
          {Credo.Check.Design.TagFIXME, []},
          {Credo.Check.Design.SkipTestWithoutComment, []},

          # Readability Checks
          {Credo.Check.Readability.AliasAs, []},
          {Credo.Check.Readability.AliasOrder, []},
          {Credo.Check.Readability.BlockPipe, []},
          {Credo.Check.Readability.FunctionNames, []},
          {Credo.Check.Readability.ImplTrue, []},
          {Credo.Check.Readability.LargeNumbers, []},
          {Credo.Check.Readability.MaxLineLength, [priority: :low, max_length: 120]},
          {Credo.Check.Readability.ModuleAttributeNames, []},
          {Credo.Check.Readability.ModuleDoc, []},
          {Credo.Check.Readability.ModuleNames, []},
          {Credo.Check.Readability.MultiAlias, []},
          {Credo.Check.Readability.NestedFunctionCalls, min_pipeline_length: 4},
          {Credo.Check.Readability.OneArityFunctionInPipe, []},
          {Credo.Check.Readability.ParenthesesInCondition, []},
          {Credo.Check.Readability.ParenthesesOnZeroArityDefs, []},
          {Credo.Check.Readability.PipeIntoAnonymousFunctions, []},
          {Credo.Check.Readability.PredicateFunctionNames, []},
          {Credo.Check.Readability.PreferImplicitTry, []},
          {Credo.Check.Readability.RedundantBlankLines, []},
          {Credo.Check.Readability.Semicolons, []},
          {Credo.Check.Readability.SeparateAliasRequire, []},
          {Credo.Check.Readability.SingleFunctionToBlockPipe, []},
          {Credo.Check.Readability.SinglePipe, []},
          {Credo.Check.Readability.SpaceAfterCommas, []},
          {Credo.Check.Readability.Specs, []},
          {Credo.Check.Readability.StrictModuleLayout, []},
          {Credo.Check.Readability.StringSigils, []},
          {Credo.Check.Readability.TrailingBlankLine, []},
          {Credo.Check.Readability.TrailingWhiteSpace, []},
          {Credo.Check.Readability.UnnecessaryAliasExpansion, []},
          {Credo.Check.Readability.VariableNames, []},
          {Credo.Check.Readability.WithCustomTaggedTuple, []},
          {Credo.Check.Readability.WithSingleClause, []},

          # Refactoring Opportunities
          {Credo.Check.Refactor.Apply, []},
          {Credo.Check.Refactor.CondStatements, []},
          {Credo.Check.Refactor.CyclomaticComplexity, []},
          {Credo.Check.Refactor.DoubleBooleanNegation, []},
          {Credo.Check.Refactor.FilterCount, []},
          {Credo.Check.Refactor.FilterFilter, []},
          {Credo.Check.Refactor.FilterReject, []},
          {Credo.Check.Refactor.FunctionArity, []},
          {Credo.Check.Refactor.IoPuts, []},
          {Credo.Check.Refactor.LongQuoteBlocks, []},
          {Credo.Check.Refactor.MapJoin, []},
          {Credo.Check.Refactor.MapMap, []},
          {Credo.Check.Refactor.MatchInCondition, []},
          {Credo.Check.Refactor.NegatedConditionsInUnless, []},
          {Credo.Check.Refactor.NegatedConditionsWithElse, []},
          {Credo.Check.Refactor.NegatedIsNil, []},
          {Credo.Check.Refactor.Nesting, []},
          {Credo.Check.Refactor.PassAsyncInTestCases, []},
          {Credo.Check.Refactor.PipeChainStart, excluded_functions: ["from"]},
          {Credo.Check.Refactor.RedundantWithClauseResult, []},
          {Credo.Check.Refactor.RejectFilter, []},
          {Credo.Check.Refactor.RejectReject, []},
          {Credo.Check.Refactor.UnlessWithElse, []},
          {Credo.Check.Refactor.UtcNowTruncate, []},
          {Credo.Check.Refactor.VariableRebinding, allow_bang: true},
          {Credo.Check.Refactor.WithClauses, []},

          # Warnings
          {Credo.Check.Warning.ApplicationConfigInModuleAttribute, []},
          {Credo.Check.Warning.BoolOperationOnSameValues, []},
          {Credo.Check.Warning.Dbg, []},
          {Credo.Check.Warning.ExpensiveEmptyEnumCheck, []},
          {Credo.Check.Warning.IExPry, []},
          {Credo.Check.Warning.IoInspect, []},
          {Credo.Check.Warning.LeakyEnvironment, []},
          {Credo.Check.Warning.MapGetUnsafePass, []},
          {Credo.Check.Warning.MissedMetadataKeyInLoggerConfig, []},
          {Credo.Check.Warning.MixEnv, []},
          {Credo.Check.Warning.OperationOnSameValues, []},
          {Credo.Check.Warning.OperationWithConstantResult, []},
          {Credo.Check.Warning.RaiseInsideRescue, []},
          {Credo.Check.Warning.SpecWithStruct, []},
          {Credo.Check.Warning.UnsafeExec, []},
          {Credo.Check.Warning.UnsafeToAtom, []},
          {Credo.Check.Warning.UnusedEnumOperation, []},
          {Credo.Check.Warning.UnusedFileOperation, []},
          {Credo.Check.Warning.UnusedKeywordOperation, []},
          {Credo.Check.Warning.UnusedListOperation, []},
          {Credo.Check.Warning.UnusedPathOperation, []},
          {Credo.Check.Warning.UnusedRegexOperation, []},
          {Credo.Check.Warning.UnusedStringOperation, []},
          {Credo.Check.Warning.UnusedTupleOperation, []},
          {Credo.Check.Warning.WrongTestFileExtension, []},

          # https://github.com/xtian/credo_contrib
          {CredoContrib.Check.DocWhitespace, []},
          {CredoContrib.Check.EmptyDocString, []},
          {CredoContrib.Check.EmptyTestBlock, []},
          {CredoContrib.Check.ModuleAlias, []},
          {CredoContrib.Check.ModuleDirectivesOrder, []},
          {CredoContrib.Check.PublicPrivateFunctionName, []},
          {CredoContrib.Check.SingleFunctionPipe, []},

          # https://github.com/mirego/credo_naming
          {CredoNaming.Check.Warning.AvoidSpecificTermsInModuleNames, terms: []},
          {
            CredoNaming.Check.Consistency.ModuleFilename,
            acronyms: [{"ArchiDep", "archidep"}],
            valid_filename_callback: fn filename, module_name, params ->
              root = CredoNaming.Check.Consistency.ModuleFilename.root_path(filename, params)
              parts = module_name |> Macro.underscore() |> Path.split()
              is_test = String.ends_with?(filename, "_test.exs")
              extension = Path.extname(filename)

              case {Path.split(root), parts, extension, is_test} do
                # Special case for "mix.exs"
                {["mix.exs"], ["archidep", "mix_project"], ".exs", false} ->
                  valid_filename = "mix.exs"
                  {filename == valid_filename, [valid_filename]}

                # Special case for the support module
                {["test"], ["archi_dep", "support"], ".ex", false} ->
                  valid_filename = "test/support/support.ex"
                  {filename == valid_filename, [valid_filename]}

                # Special case for other support modules
                {["test"], [base_module, "support" | remaining_parts], _extension, _is_test}
                when base_module in ["archi_dep", "archi_dep_web"] ->
                  valid_filename = Path.join(["test", "support"] ++ remaining_parts) <> extension
                  {filename == valid_filename, [valid_filename]}

                # Otherwise default to original behavior.
                _anything_else ->
                  CredoNaming.Check.Consistency.ModuleFilename.valid_filename?(
                    filename,
                    module_name,
                    params
                  )
              end
            end
          },

          # https://hex.pm/packages/nicene
          {Nicene.AliasImportGrouping, []},
          {Nicene.AvoidImportsFromCurrentApplication, []},
          {Nicene.NoSpecsPrivateFunctions, []},
          {Nicene.TrueFalseCaseStatements, []}
        ],
        disabled: [
          # To enable later
          {Credo.Check.Design.DuplicatedCode, []},
          {Credo.Check.Refactor.ABCSize, []},
          {Credo.Check.Refactor.AppendSingleItem, []},
          {Credo.Check.Refactor.ModuleDependencies, []},
          # Old versions of Elixir
          {Credo.Check.Warning.LazyLogging, []},
          {Credo.Check.Refactor.MapInto, []},
          # Bugged
          {CredoContrib.Check.FunctionBlockSyntax, []},
          # Duplicate, too restrictive or unhelpful
          {Credo.Check.Design.TagTODO, [exit_status: 0]},
          {Credo.Check.Readability.OnePipePerLine, []},
          {CredoContrib.Check.FunctionNameUnderscorePrefix, []},
          {Nicene.AvoidForbiddenNamespaces, []},
          {Nicene.ConsistentFunctionDefinitions, []},
          {Nicene.DocumentGraphqlSchema, []},
          {Nicene.EctoSchemaDirectories, []},
          {Nicene.EnsureTestFilePattern, []},
          {Nicene.FileAndModuleName, []},
          {Nicene.FileTopToBottom, []},
          {Nicene.PublicFunctionsFirst, []},
          {Nicene.TestsInTestFolder, []},
          {Nicene.UnnecessaryPatternMatching, []}
        ]
      }
    }
  ]
}
