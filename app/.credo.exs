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
          # {Credo.Check.Design.TagTODO, [exit_status: 0]},
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
          {Credo.Check.Readability.NestedFunctionCalls, min_pipeline_length: 4},
          {Credo.Check.Readability.OneArityFunctionInPipe, []},
          {Credo.Check.Readability.OnePipePerLine, false},
          {Credo.Check.Readability.SeparateAliasRequire, []},
          {Credo.Check.Readability.SingleFunctionToBlockPipe, []},
          {Credo.Check.Readability.SinglePipe, []},
          {Credo.Check.Readability.Specs, []},
          # {Credo.Check.Readability.StrictModuleLayout, []},
          # {Credo.Check.Readability.WithCustomTaggedTuple, []},

          # Refactoring Opportunities
          {Credo.Check.Refactor.Apply, []},
          {Credo.Check.Refactor.CondStatements, []},
          {Credo.Check.Refactor.CyclomaticComplexity, []},
          {Credo.Check.Refactor.FilterCount, []},
          {Credo.Check.Refactor.FilterFilter, []},
          {Credo.Check.Refactor.FunctionArity, []},
          {Credo.Check.Refactor.LongQuoteBlocks, []},
          {Credo.Check.Refactor.MapJoin, []},
          {Credo.Check.Refactor.MatchInCondition, []},
          {Credo.Check.Refactor.NegatedConditionsInUnless, []},
          {Credo.Check.Refactor.NegatedConditionsWithElse, []},
          {Credo.Check.Refactor.Nesting, []},
          {Credo.Check.Refactor.RedundantWithClauseResult, []},
          {Credo.Check.Refactor.RejectReject, []},
          {Credo.Check.Refactor.UnlessWithElse, []},
          {Credo.Check.Refactor.WithClauses, []},
          {Credo.Check.Refactor.UtcNowTruncate, []},
          # {Credo.Check.Refactor.ABCSize, []},
          # {Credo.Check.Refactor.AppendSingleItem, []},
          # {Credo.Check.Refactor.DoubleBooleanNegation, []},
          # {Credo.Check.Refactor.FilterReject, []},
          # {Credo.Check.Refactor.IoPuts, []},
          # {Credo.Check.Refactor.MapMap, []},
          # {Credo.Check.Refactor.ModuleDependencies, []},
          # {Credo.Check.Refactor.NegatedIsNil, []},
          # {Credo.Check.Refactor.PassAsyncInTestCases, []},
          # {Credo.Check.Refactor.PipeChainStart, []},
          # {Credo.Check.Refactor.RejectFilter, []},
          # {Credo.Check.Refactor.VariableRebinding, []},

          # Warnings
          {Credo.Check.Warning.ApplicationConfigInModuleAttribute, []},
          {Credo.Check.Warning.BoolOperationOnSameValues, []},
          {Credo.Check.Warning.Dbg, []},
          {Credo.Check.Warning.ExpensiveEmptyEnumCheck, []},
          {Credo.Check.Warning.IExPry, []},
          {Credo.Check.Warning.IoInspect, []},
          {Credo.Check.Warning.MissedMetadataKeyInLoggerConfig, []},
          {Credo.Check.Warning.OperationOnSameValues, []},
          {Credo.Check.Warning.OperationWithConstantResult, []},
          {Credo.Check.Warning.RaiseInsideRescue, []},
          {Credo.Check.Warning.SpecWithStruct, []},
          {Credo.Check.Warning.UnsafeExec, []},
          {Credo.Check.Warning.UnusedEnumOperation, []},
          {Credo.Check.Warning.UnusedFileOperation, []},
          {Credo.Check.Warning.UnusedKeywordOperation, []},
          {Credo.Check.Warning.UnusedListOperation, []},
          {Credo.Check.Warning.UnusedPathOperation, []},
          {Credo.Check.Warning.UnusedRegexOperation, []},
          {Credo.Check.Warning.UnusedStringOperation, []},
          {Credo.Check.Warning.UnusedTupleOperation, []},
          {Credo.Check.Warning.WrongTestFileExtension, []},
          # {Credo.Check.Warning.LazyLogging, []},
          # {Credo.Check.Warning.LeakyEnvironment, []},
          # {Credo.Check.Warning.MapGetUnsafePass, []},
          # {Credo.Check.Warning.MixEnv, []},
          # {Credo.Check.Warning.UnsafeToAtom, []},

          # https://github.com/xtian/credo_contrib
          {CredoContrib.Check.DocWhitespace, []},
          {CredoContrib.Check.EmptyDocString, []},
          {CredoContrib.Check.EmptyTestBlock, []},
          {CredoContrib.Check.FunctionBlockSyntax, false},
          {CredoContrib.Check.FunctionNameUnderscorePrefix, false},
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
                # Special naming for the "mix.exs" file which contains the module "ArchiDep.MixProject".
                {["mix.exs"], ["archidep", "mix_project"], ".exs", false} ->
                  valid_filename = "mix.exs"
                  {filename == valid_filename, [valid_filename]}

                {["test"], [base_module, "support" | remaining_parts], _extension, _is_test}
                when base_module in ["archi_dep", "archi_dep_web"] ->
                  # Special case for support files, which can have any name.
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
          {Nicene.AvoidForbiddenNamespaces, false},
          {Nicene.AvoidImportsFromCurrentApplication, []},
          {Nicene.ConsistentFunctionDefinitions, false},
          {Nicene.DocumentGraphqlSchema, false},
          {Nicene.EctoSchemaDirectories, false},
          {Nicene.EnsureTestFilePattern, false},
          {Nicene.FileAndModuleName, false},
          {Nicene.FileTopToBottom, false},
          {Nicene.NoSpecsPrivateFunctions, false},
          {Nicene.PublicFunctionsFirst, false},
          {Nicene.TestsInTestFolder, false},
          {Nicene.TrueFalseCaseStatements, []},
          {Nicene.UnnecessaryPatternMatching, false}
        ],
        disabled: [
          {Credo.Check.Design.DuplicatedCode, []},
          {Credo.Check.Refactor.MapInto, []}
        ]
      }
    }
  ]
}
